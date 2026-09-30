# Demo Script, Debugging and Viva Preparation

## Recorded demo

Target 5–10 minutes, HD screen, low background noise. Follow this order — it moves from what the system is, to what it does, to who can see it.

| # | Segment | Time | What to show |
|---|---|---|---|
| 1 | Introduction | 0:30 | Name, project title, one sentence on the problem: event companies juggle clients, venues, vendors and coordinators across spreadsheets and email. |
| 2 | App overview | 1:00 | App Launcher → open **Event Planner Management System**. Point at the six-object nav bar. Open one Event record and walk the related lists: Client, Venue, Event Vendors, Feedbacks, Approval History. |
| 3 | UI and data integrity | 1:30 | Create a Client with email `john@college` → show the validation error → fix to `john@college.edu` → saves. Create an Event, set budget 500000, add a vendor assignment → Budget Balance and Utilisation update live. |
| 4 | Apex: venue integrity | 1:30 | Create a Venue as `Available`. Attach it to an Event → venue flips to `Reserved`. Try to attach the **same venue on the same date** to a second event → blocked with the double-booking error. Change the second event's date by one day → it saves. This single sequence proves the trigger, the date-aware rule and the bulk logic. |
| 5 | Automation: approval process | 1:30 | Submit an event for cancellation → status becomes `Pending Cancellation`, record locks, approver email arrives. Approve from the email link → status `Canceled`, client email arrives, **venue flips back to `Available`**. Then reject a second request → status `Rejected` and the venue **stays `Reserved`**. That contrast is the highlight. |
| 6 | Automation: reminder flow | 0:45 | Setup → Paused and Waiting Interviews → show the `3 Days Before Event` path queued against the event dated today+3, with its next-run timestamp. Show the received reminder email. |
| 7 | Automation: batch | 0:45 | Show the three past events still `Planned`. Setup → Scheduled Jobs → `Daily Event Completion` at 20:00. Run once from Execute Anonymous → the three flip to `Completed` and the canceled one stays `Canceled`. |
| 8 | Security | 1:30 | Setup → Sharing Settings → show Private OWD on Event and Client. Show the role tree. Then **Login As** the Vendor Manager and open the same event: budget fields blank, Client tab gone, no Edit button. Log back in as admin and show the same record fully populated. |
| 9 | Reports and dashboard | 1:00 | Open the three reports briefly, then the **EventForce Dashboard** — upcoming events by month, events by status, spend by vendor, events over budget (Winter Music Festival at 107%). |
| 10 | Conclusion | 0:30 | What the system automates, what it replaced, what you learned. |

**Recording tips.** Have every record pre-created except the ones you create live; dead air while you type names kills pacing. Keep one browser tab per area. Zoom to 125% so field values are legible. Narrate the *why*, not the clicks — "the venue releases itself because the trigger listens for the status change" is worth more than "now I click Save".

---

## Debugging and fixes

Real issues encountered during the build, and how each was diagnosed. This is segment 7 of the demo outline and a near-certain viva question.

| Symptom | Cause | Diagnosis | Fix |
|---|---|---|---|
| Venue never changes to `Reserved` | Trigger inactive, or picklist value mismatch | Setup → Apex Triggers → check Status; compare the picklist value against the constants in `VenueAvailabilityHandler` | Activate the trigger; align `Available`/`Reserved` spelling |
| Sample data insert fails with "cannot be double booked" | The original rule blocked any two live events on the same venue | Read the `addError` message and trace which records collide | Made the rule date-aware — a venue can host many events, just not two on one day |
| Past events reappear as `Completed` after being `Canceled` | Batch query `Event_Status__c != 'Completed'` also matches `Canceled` and `Pending Cancellation` | Ran the batch against seeded data and diffed the statuses before and after | Excluded all three statuses from the query |
| Blank status events silently skipped by the batch | `null NOT IN (...)` evaluates to null, not true | Wrote a unit test with a null status | Added an explicit `Event_Status__c = null OR ...` clause |
| Flow runs, no error, no email | Org email deliverability set to *System email only* | Setup → Email → Deliverability | Set Access Level to **All email** |
| Reminder never fires | Flow saved but not activated; or path added to the main branch instead of the scheduled branch | Setup → Flows → check for an Active version; open the flow and confirm the elements hang off the path node | Activate; move elements onto the scheduled path |
| No `Submit for Approval` button in Lightning | The action is not on the page layout | Object Manager → Event → Page Layouts → Mobile & Lightning Experience Actions | Override predefined actions and drag the button in |
| `Client: Email` missing from the Email Alert recipient list | `Client__c.Email__c` was a Text field | Email Alerts can only address Email-type fields | Converted the field to Email type |
| Custom email validation rule never shows its own message | The field is Email type, so Salesforce's native check fires first | Tried `abc@` and got the platform error instead | Test with `john@college` — no dot, no TLD — which the native check accepts and the regex rejects |
| Restricted profiles see everything | Testing while logged in as System Administrator, which has `View All Data` | Every record visible regardless of OWD | Use **Login As** to test as the target user |
| Report returns no rows although records exist | *Show Me* filter set to **My** records | Compare the row count against the tab's record count | Set the filter to **All** |
| Dashboard shows stale numbers after the batch runs | Dashboard components cache their results | Refresh the browser — values unchanged | Click **Refresh** on the dashboard |
| Coordinator or Client user sees no events at all | Event OWD is Private and they own no records | Check the Owner field on the events | Change Owner on two or three records, or add a sharing rule |

---

## Viva questions

**Data model**

- *Why is `EventVendor__c` master-detail rather than lookup?* Because the roll-up summary field on Event only aggregates across a master-detail child. Master-detail also gives cascade delete — removing an event removes its vendor assignments — and sharing is automatically *Controlled by Parent*.
- *Why does the junction have two master-details?* That is what makes it a junction. One object with two master-detail parents implements a many-to-many relationship; the first master-detail determines the owner and the sharing parent.
- *What happens to a junction row if you delete the vendor?* It is deleted. Both parents are master-detail, so either deletion cascades.
- *Why no tab on `EventVendor__c`?* Junction rows are managed from the Event's related list. A tab would allow orphan rows and bypasses the intended navigation.

**Apex**

- *Why is the logic in a handler class and not in the trigger?* One trigger per object is the standard pattern. Keeping the body to two lines means the logic can be unit-tested by calling the class, and behaviour can be disabled without editing the trigger.
- *How do you know it is bulk-safe?* Both methods collect IDs into sets and issue a single SOQL and a single DML per invocation. No queries or DML inside loops. The seeder inserts ten events in one transaction and the handler still uses one query and one update.
- *Why does the SOQL say `Event_Status__c = null OR ... NOT IN`?* Because `null NOT IN ('Canceled','Completed')` evaluates to null, not true, so events with a blank status would be silently excluded from the conflict check.
- *What is the double-booking rule exactly?* Two events whose status is neither `Canceled` nor `Completed` cannot share a venue **on the same date**. Different dates are fine, which is why four venues can carry ten events.
- *Why also check for duplicates within the trigger batch?* Records in the same DML are not committed yet, so the SOQL cannot see them. Two rows claiming the same venue and date in one insert would both pass the query. A `Set.add()` return value catches it.
- *Why is a venue not released when a cancellation is merely requested?* `Pending Cancellation` is not a venue-freeing status. The event is still scheduled until an approver agrees otherwise. Releasing early would let another event book a venue that might still be needed.
- *Before or after trigger — why both?* `addError` only works in a before trigger, so the double-booking check runs before. The venue update touches a different object, so it runs after, once the event record definitely exists.
- *What is the difference between the batch and the schedulable class?* The batch does the work in chunks of 200 to stay inside governor limits. The schedulable class only exists so Setup → Schedule Apex has something to run on a timer; it calls `Database.executeBatch`.
- *Why does the batch exclude `Canceled`?* The specified query matched canceled and pending records too, so the nightly job would have overwritten the approval process outcome and destroyed the audit trail.

**Automation**

- *Why a scheduled path instead of a normal record-triggered flow?* A record-triggered flow only runs when a record is saved. Nothing saves an event three days before it happens. The scheduled path lets the platform compute a wake-up time from `Event_Date__c`.
- *What stops the reminder being sent twice?* A scheduled path runs once per record. If the date changes the platform cancels the pending path and reschedules it.
- *Why two Get Records elements in the flow?* `$Record` only exposes fields on the triggering object, so the client's email needs a separate query. The first Get re-reads the event because the path fires days after it was scheduled and the status may have changed.
- *Why does the approval process need a field update rather than just an email?* The status change is the business outcome — it drives the venue release, the reports and the batch exclusion. The email is only the notification.
- *What locks the record during approval?* The approval process's record-locking setting. The trigger still maintains the venue because it writes to `Venue__c`, not to the locked `Event__c`.
- *What happens on recall?* The record unlocks but the status stays `Pending Cancellation`. Approval processes have no recall action, so it needs a manual change back to `Planned`. A known limitation.

**Security**

- *Walk through what happens when a Vendor Manager opens an event owned by a Coordinator.* OWD Private denies access; the role hierarchy grants nothing because they are siblings; sharing rule 2 grants Read Only; the profile permits Read but not Edit; FLS hides the three budget fields. Access is the intersection of all layers.
- *Why OWD Private on Event but Public Read Only on Venue?* Events carry budgets and client relationships. Venues are shared reference data everyone needs in order to plan, but only admins and venue managers should edit them.
- *Why a permission set instead of editing the profile?* The profile change would apply to every vendor manager permanently. The permission set targets one named user and can be revoked without touching the profile.
- *What is the formula field security problem?* `Budget_Balance__c` derives from `Event_Budget__c`, and FLS is not propagated through formula evaluation. Hiding the source but showing the formula lets a user recover the hidden value by subtracting `Vendor_Cost__c`. Both derived fields must be hidden with their source.
- *Why can't you test security as the admin?* System Administrator has `View All Data`, which overrides OWD, sharing rules and ownership. Every test must use Login As.
- *Why do clients have a profile but no role?* The role hierarchy models an internal reporting structure. Clients are not staff; their visibility comes from record ownership and OWD.

**General**

- *Which part was hardest and why?* Expected answer with substance: reconciling the batch, the trigger and the approval process around one status field, since all three write to `Event_Status__c` and each had to agree on which values free a venue and which do not.
- *What would you add if this went to production?* Multi-day events with a start and end date so the double-booking check tests overlap rather than equality; a custom metadata type for the status constants so they are configurable without a deploy; and a proper test suite running in CI against a scratch org.
