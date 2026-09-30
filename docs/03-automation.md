# Phase 4 — Automation

Four mechanisms: a scheduled-path flow for reminders, a second flow for feedback requests, an approval process for cancellations, and Apex for venue integrity.

---

## 4a. Apex

Six files in `apex/`. See the README for the deploy order and the field API names they depend on. What each one guarantees:

| Component | Guarantees |
|---|---|
| `EventTrigger` | Thin dispatcher — routes before-events to `preventDoubleBooking` and after-events to `updateVenueAvailability`. No logic in the trigger body, so it can be disabled by deactivating one class. |
| `VenueAvailabilityHandler.preventDoubleBooking` | Two live events cannot share a venue **on the same date**. Also catches two records in one save claiming the same venue and date, which a plain SOQL check misses because neither row is committed yet. |
| `VenueAvailabilityHandler.updateVenueAvailability` | Venue is `Reserved` while it has at least one live booking, `Available` when it has none. Releases the venue on cancellation, on completion, and when an event moves to a different venue. |
| `BatchCompleteEvents` | Past events become `Completed`. Excludes `Canceled` and `Pending Cancellation`. |
| `ScheduleCompleteEvents` | Runs the batch with a scope of 200. |

**Bulk safety.** Both handler methods collect IDs into sets and issue one SOQL and one DML per trigger invocation, regardless of how many records the batch contains. No queries or DML inside loops.

**Null-safety.** `Event_Status__c` may be blank. The SOQL uses `(Event_Status__c = null OR Event_Status__c NOT IN :FREEING_STATUSES)` because `null NOT IN (...)` evaluates to null, which would silently drop those rows.

**Statuses that free a venue** are `Canceled` and `Completed`. Notably `Pending Cancellation` and `Rejected` do **not** free it — a cancellation under review or a refused cancellation means the event is still going ahead, so the venue stays reserved. This is what makes the approval process and the trigger agree.

**Interaction with the batch.** When `BatchCompleteEvents` sets an event to `Completed`, that update fires `EventTrigger`, which releases the venue. The two components chain without any extra configuration.

**Interaction with record locking.** An approval process locks the Event record while pending. The trigger writes to `Venue__c`, not `Event__c`, so locking does not interfere with venue maintenance.

Run the tests: Setup → Apex Classes → `VenueAvailabilityHandlerTest` → Run. 12 tests.

---

## 4b. Three-day reminder flow

### Design decision

This is a **Record-Triggered Flow with a Scheduled Path**, not a plain after-save flow. A normal record-triggered flow only runs when someone saves a record, so it would never notice three days passing. A scheduled path lets the platform wake the flow up at a time computed from a date field on the record.

Two properties worth stating in a viva: the path runs **once per record**, so there is no duplicate-email problem, and if `Event_Date__c` is edited the platform **cancels the old path and reschedules** automatically.

### Step 1 — email deliverability

Setup → Email → **Deliverability** → *Access to Salesforce Email* → **All email** → Save.

Dev orgs are sometimes set to *System email only*, in which case the flow runs, logs no error, and nothing arrives. Check this before blaming the flow.

### Step 2 — create the flow

Setup → Process Automation → **Flows** → New Flow → **Record-Triggered Flow**.

| Setting | Value |
|---|---|
| Object | Event (`Event__c`) |
| Trigger the Flow When | A record is created or updated |
| When to Run the Flow | **Run after the record is saved** (after-save) |
| Optimize the Flow For | **Actions and Related Records** |
| Set Entry Conditions | Conditions are met → `Event Date` **Is Null** = `False` |

After-save is mandatory. Scheduled paths do not exist on before-save flows — if you choose *Run immediately*, the "Add Scheduled Path" link never appears.

### Step 3 — scheduled path

In the Start element, under **Add Scheduled Path**, click **+**.

| Setting | Value |
|---|---|
| Path Name | `3 Days Before Event` |
| When to Run Path | `Event Date` · **Before** · `3` · `Days` |

Everything below goes **on that branch**, not the main one.

### Step 4 — elements on the path

**4a. Get Records** — label `Get Event`

| Setting | Value |
|---|---|
| Object | Event |
| Condition | `Event ID` Equals `{!$Record.Id}` |
| Store | Automatically store all fields · First record only → `{!Get_Event}` |

Re-reading the record matters: the path fires days after it was scheduled and the status may have changed.

**4b. Decision** — label `Should We Send`, single outcome `Send`, all conditions met (AND):

| Resource | Operator | Value |
|---|---|---|
| `{!Get_Event.Event_Status__c}` | Does Not Equal | `Canceled` |
| `{!Get_Event.Event_Status__c}` | Does Not Equal | `Completed` |
| `{!Get_Event.Event_Status__c}` | Does Not Equal | `Rejected` |
| `{!Get_Event.Client__c}` | Is Null | `False` |

Leave the Default Outcome unconnected — a canceled event, or one with no client, ends the path silently.

**4c. Get Records** (on the `Send` outcome) — label `Get Client`

| Setting | Value |
|---|---|
| Object | Client |
| Condition | `Client ID` Equals `{!Get_Event.Client__c}` |
| Store | Automatically store all fields · First record only → `{!Get_Client}` |

`$Record` only exposes fields on the triggering object, so the client's email cannot be reached without this second query.

**4d. Action** — search **Send Email**, label `Send Reminder Email`

| Setting | Value |
|---|---|
| Recipient Email Addresses | `{!Get_Client.Email__c}` |
| Email Subject | `Reminder: {!Get_Event.Name} is in 3 days` |
| Sender Type | **Default Workflow Email Address** |

Do not pick *Current User* — a scheduled path executes as the Automated Process user, which has no mailbox.

Under **See advanced options**, set Email Body to:

```html
<p>Dear {!Get_Client.Name},</p>

<p>This is a reminder that your event <b>{!Get_Event.Name}</b> is scheduled in 3 days.</p>

<p>
Date: {!Get_Event.Event_Date__c}<br/>
Type: {!Get_Event.Event_Type__c}<br/>
Status: {!Get_Event.Event_Status__c}
</p>

<p>If anything needs to change, please contact your event coordinator as soon as possible.</p>

<p>Regards,<br/>EventForce Management Team</p>
```

To show the venue name rather than omitting it, add one more Get Records on Venue filtered by `{!Get_Event.Venue__c}` and reference `{!Get_Venue.Name}`.

### Step 5 — save and activate

Flow Label `Event 3-Day Reminder` → API Name `Event_3_Day_Reminder` → Save → **Activate**. An inactive flow never runs.

### Testing

1. Create a Client whose email is your own address.
2. Create an Event with that client and `Event_Date__c` = today + 3 days, status `Planned`.
3. Because the offset is "3 days before", the path is due today and fires in the next scheduled sweep, usually within the hour.
4. Proof it is queued right now: Setup → quick find `Flows` → **Paused and Waiting Interviews**. An interview appears with Path = `3 Days Before Event` and a next-run timestamp. In some orgs this is under *Flow Interviews*, and the same jobs appear in Setup → **Scheduled Jobs** with Type = Flow. This is the only visible evidence the automation exists before the email lands — screenshot it.
5. Negative test: another event dated three days out with status `Canceled`. The interview exists but the Decision's default outcome swallows it and no email is sent.

For an instant live demo, temporarily set the offset to `0 Days Before`, create an event dated today, and the reminder fires within the hour. Set it back afterwards.

**Known limits.** Scheduled paths run on the platform's own schedule, so delivery is "within the hour", not at an exact minute. And the path is only created when the record is saved, so an event created with a date already inside three days gets no reminder.

---

## 4c. Cancellation approval process

Build order matters: field updates and templates must exist before the approval process references them.

### Field updates (3)

Setup → Process Automation → **Field Updates** → New Field Update.

| Name | Object | Field to Update | New Value |
|---|---|---|---|
| `Set Status Pending Cancellation` | Event | Event Status | A specific value → `Pending Cancellation` |
| `Set Status Canceled` | Event | Event Status | A specific value → `Canceled` |
| `Set Status Rejected` | Event | Event Status | A specific value → `Rejected` |

Leave **Re-evaluate Workflow Rules after Field Change** unticked on all three.

`Pending Cancellation` and `Rejected` are not venue-freeing statuses, so the venue stays `Reserved` while the request is pending or if it is refused. `Canceled` is venue-freeing, so the final approval field update fires `EventTrigger` and releases the venue with no extra configuration.

### Classic email templates (3)

Setup → Email → **Classic Email Templates** → New Template → type **Custom (without using Letterhead)** → tick *Available For Use* → Save → Edit to paste the body.

**Template 1** — Unique Name `Cancellation_Request_Approver`
Subject: `Approval Required: Cancellation request for {!Event__c.Name}`

```html
<html>
<body style="font-family:Arial,sans-serif;font-size:14px;color:#222;">
  <p>Hello,</p>
  <p>A cancellation request has been submitted for the event below and is waiting for your approval.</p>
  <table cellpadding="6" cellspacing="0" border="1" style="border-collapse:collapse;">
    <tr><td><b>Event</b></td><td>{!Event__c.Name}</td></tr>
    <tr><td><b>Event Date</b></td><td>{!Event__c.Event_Date__c}</td></tr>
    <tr><td><b>Event Type</b></td><td>{!Event__c.Event_Type__c}</td></tr>
    <tr><td><b>Client</b></td><td>{!Event__c.Client__r.Name}</td></tr>
    <tr><td><b>Budget</b></td><td>{!Event__c.Event_Budget__c}</td></tr>
    <tr><td><b>Submitted By</b></td><td>{!Event__c.OwnerFullName}</td></tr>
  </table>
  <p>Open the request in Salesforce to approve or reject it:</p>
  <p>{!ApprovalRequest.Process_Url}</p>
  <p>Regards,<br/>EventForce Management System</p>
</body>
</html>
```

`{!ApprovalRequest.Process_Url}` renders a direct link to the approval page, so the approver can act from the email.

**Template 2** — Unique Name `Cancellation_Approved_Client`
Subject: `Your event {!Event__c.Name} has been canceled`

```html
<html>
<body style="font-family:Arial,sans-serif;font-size:14px;color:#222;">
  <p>Dear {!Event__c.Client__r.Name},</p>
  <p>Your cancellation request for <b>{!Event__c.Name}</b> scheduled on {!Event__c.Event_Date__c} has been <b>approved</b>. The event status is now Canceled.</p>
  <p>The venue reserved for this event has been released and no further charges will apply.</p>
  <p>Regards,<br/>EventForce Management Team</p>
</body>
</html>
```

**Template 3** — Unique Name `Cancellation_Rejected_Client`
Subject: `Cancellation request rejected for {!Event__c.Name}`

```html
<html>
<body style="font-family:Arial,sans-serif;font-size:14px;color:#222;">
  <p>Dear {!Event__c.Client__r.Name},</p>
  <p>Your cancellation request for <b>{!Event__c.Name}</b> scheduled on {!Event__c.Event_Date__c} has been <b>rejected</b>. The event remains confirmed and the venue stays reserved.</p>
  <p>Please contact your event coordinator to discuss the reason.</p>
  <p>Regards,<br/>EventForce Management Team</p>
</body>
</html>
```

If `{!Event__c.Client__r.Name}` renders blank, use the **Insert Merge Field** dropdown to pick the exact relationship path — the lookup's relationship name is `Client`.

### Email alerts (3)

Setup → Process Automation → **Email Alerts** → New Email Alert.

| Description | Unique Name | Object | Template | Recipients |
|---|---|---|---|---|
| `Notify Approver - Cancellation Request` | `Notify_Approver_Cancellation` | Event | Template 1 | **Users** → the approver |
| `Notify Client - Cancellation Approved` | `Notify_Client_Approved` | Event | Template 2 | **Email Field** → `Client: Email` |
| `Notify Client - Cancellation Rejected` | `Notify_Client_Rejected` | Event | Template 3 | **Email Field** → `Client: Email` |

Sender: *Default Workflow Email Address*. If `Client: Email` is absent from the Email Field picklist, `Client__c.Email__c` is still a Text field.

### The approval process

Setup → Process Automation → **Approval Processes** → *Create New Approval Process* → **Event** → Create → use the **Standard Setup Wizard**.

**Step 1 — name and approver**

| Setting | Value |
|---|---|
| Name | `Event Cancellation Approval` |
| Unique Name | `Event_Cancellation_Approval` |
| Approver | **Automatically assign approver(s)** → Approver: **User** → the coordinator user |

**Step 2 — entry criteria**

Conditions are met: `Event Status` **equals** `Planned`.

Only live events can request cancellation. Because submission immediately moves the status to `Pending Cancellation`, a record cannot be submitted twice.

**Step 3 — notification templates**

Email template for approver notification → `Notify Approver - Cancellation Request`. Skip delegated approvers.

**Step 4 — initial submission actions**

Add → New Field Update → `Set Status Pending Cancellation`. The email alert from Step 3 attaches automatically.

**Step 5 — approval step and reject behaviour**

| Setting | Value |
|---|---|
| Step Name | `Event Coordinator Review` |
| Step Number | 1 |
| Assigned Approver | User → the coordinator user |
| If a record is rejected | **Unlock record for changes to the owner** |

Final rejection actions: Field Update `Set Status Rejected` + Email Alert `Notify Client - Cancellation Rejected`.

**Step 6 — final approval actions and locking**

| Setting | Value |
|---|---|
| Final Approval Actions | Field Update `Set Status Canceled` |
| Final Approval Actions | Email Alert `Notify Client - Cancellation Approved` |
| Record locking | **Lock the record for editing** |
| Recall behaviour | **Unlock records for changes** |
| Allow submitters to recall | **Yes** |

Save, then confirm the four action groups on the detail page. That page is the best single report screenshot for this phase.

### Put the button on the layout

Without this, nothing can be submitted in Lightning.

Object Manager → Event → **Page Layouts** → Event Layout → palette → **Salesforce Mobile and Lightning Experience Actions** → if it says *override the predefined actions*, click that link → drag **Submit for Approval** in → Save.

Also add the **Approval History** related list — it shows the pending step and the approve/reject buttons on the record itself.

### Testing

Set the Client email to your own address first.

1. Create an Event: status `Planned`, date a month out, that client, a venue currently `Available`. Save → the venue becomes `Reserved`.
2. **Submit for Approval** → status `Pending Cancellation`, record locks (Edit greyed out), approver email arrives with a working link. Venue still `Reserved`.
3. Approve from the email link → status `Canceled`, client email arrives, venue flips to `Available` via `EventTrigger`.
4. Repeat on a second event and **reject** → status `Rejected`, client gets the rejection email, venue stays `Reserved`. That contrast is the strongest single demo in the project.

### Known limitations

- **Recall does not revert the status.** Approval processes have no recall action, so after a recall the event sits at `Pending Cancellation` and needs a manual change back to `Planned`.
- **A rejected event can never re-request cancellation**, because entry criteria require `Planned` and rejection sets `Rejected`. This follows the specification. To allow re-submission, set the rejection field update back to `Planned`.
- **Submitter and approver should not be the same user.** Salesforce permits it, but it does not prove routing works. Create the second user in Phase 6 and reassign the approver.

---

## 4d. Feedback notification flow

The project description promises automation for reminders, **feedback notifications** and approval updates. The reminder flow and the approval process cover two of those; this flow covers the third.

### Why it belongs here

The nightly batch already sets past events to `Completed`. Hooking a flow onto that status change means feedback requests are sent **with no manual step at all** — the batch marks the event finished, the flow notices, the client is emailed. That chain is the strongest argument in the project that the components were designed as one system rather than five separate features.

### Design decision

A **Record-Triggered Flow on `Event__c`, after-save**, with entry conditions:

| Condition | Value |
|---|---|
| Field | `Event Status` |
| Operator | Equals |
| Value | `Completed` |

Run the flow for updated records: **Only when a change is made in the record**.

That last setting is the whole design. Without it, *every* save of an already-completed event — adding a note, correcting a budget — sends the client another email. With it, the flow fires exactly once, on the transition into `Completed`. After-save (not before-save) is required because a before-save flow cannot reliably read the old value, and Send Email should not be part of a record's transaction.

### Step 1 — Get Records (Client)

`$Record` exposes only fields on the triggering object, so the client's email must be fetched.

- Object: **Client**
- Filter: `Client ID` Equals `{!$Record.Client__c}`
- How Many: **Only the first record**
- Store automatically: **Automatically store all fields**

Add a guard so a blank client does not throw: on the following Decision element, one outcome `Client Found` with `{!Get_Client.Id}` Is Null → False, and a Default Outcome that does nothing.

### Step 2 — Send Email

Connect it to the `Client Found` outcome.

- Subject: `How was your event, {!$Record.Name}?`
- Rich Text Body:

```html
<p>Dear {!Get_Client.Name},</p>
<p>Thank you for choosing EventForce. Your event <b>{!$Record.Name}</b> has been marked as completed.</p>
<p>We would be grateful if you could share a few minutes of feedback with your coordinator. Your comments help us improve future events.</p>
<p>Regards,<br/>EventForce Management Team</p>
```

### Step 3 — save and activate

Flow Label `Client Feedback Request` → API Name `Client_Feedback_Request` → Save → **Activate**.

Same Deliverability prerequisite as the reminder flow: Setup → **Email Deliverability** → Access Level = **All email**, otherwise nothing sends in a dev org.

### Testing

1. Set a Client's email to your own address.
2. Create an Event for that client with status `Planned` and any date.
3. Change `Event Status` to `Completed` and save → the email arrives.
4. Edit something unrelated on that event and save again → **no second email**. That negative test is what proves the "only when a change is made" setting works, and it is worth showing on camera.

To demo the full chain without waiting for 20:00, run the batch manually: Developer Console → Debug → Open Execute Anonymous Window →

```apex
Database.executeBatch(new BatchCompleteEvents(), 200);
```

Because the sample data leaves three past events at `Planned`, that single line marks all three `Completed`, releases their venues through `EventTrigger`, and sends three feedback requests — the batch, the trigger and both flows all firing from one command.

### Known limitations

- An event that goes `Completed` → `Planned` → `Completed` sends a second request. The flow does not check whether a `Feedback__c` already exists; adding a Get Records on Feedback as a second guard outcome would close that.
- The email is sent by the Automated Process / system user, not by the event coordinator, so replies will not reach a coordinator inbox unless a reply-to is configured.
