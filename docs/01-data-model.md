# Phase 1 and 2 — Data Model, Tabs and App

## Developer org

1. <https://developer.salesforce.com/signup>
2. First name, last name, email, Job Title `Developer`, Company = college name, Country = India.
3. Sign up, then confirm through the verification email (5–10 minutes).
4. Set a password and a security question. You land in your Dev Org.

## Build order

Lookups and master-details need the parent object to exist first:

```
Client__c  ->  Vendor__c  ->  Venue__c  ->  Event__c  ->  Feedback__c  ->  EventVendor__c
```

For each object: Setup → Object Manager → Create → Custom Object. Fill Label, Plural Label and Record Name, tick **Launch New Custom Tab Wizard**, Save. Then add fields under Fields & Relationships → New.

## Objects and fields

### 1. `Client__c`

Label `Client`, plural `Clients`, record name **Client Name** (Text).

| Field Label | API Name | Type | Detail |
|---|---|---|---|
| Email | `Email__c` | Email | Email type, not Text — see the trade-off note below |
| Phone | `Phone__c` | Phone | |
| Address | `Address__c` | Text Area | |
| Country | `Country__c` | Text(80) | |
| City | `City__c` | Text(80) | |

### 2. `Vendor__c`

Label `Vendor`, plural `Vendors`, record name **Vendor Name** (Text).

| Field Label | API Name | Type | Detail |
|---|---|---|---|
| Email | `Email__c` | Email | |
| Phone | `Phone__c` | Phone | |
| Service Type | `Service_Type__c` | Picklist | Catering, Decor, Logistics, Photography, Music/DJ, Lighting, Transport |
| Status | `Status__c` | Picklist | Active, Inactive — default `Active` |

### 3. `Venue__c`

Label `Venue`, plural `Venues`, record name **Venue Name** (Text).

| Field Label | API Name | Type | Detail |
|---|---|---|---|
| Address | `Address__c` | Text Area | |
| Location | `Location__c` | URL | |
| Capacity | `Capacity__c` | Number(6,0) | |
| Availability Status | `Availability_Status__c` | Picklist | `Available`, `Reserved` — default `Available`. Written by `EventTrigger`. |

### 4. `Event__c`

Label `Event`, plural `Events`, record name **Event Name** (Text).

| Field Label | API Name | Type | Detail |
|---|---|---|---|
| Event Date | `Event_Date__c` | Date | |
| Event Type | `Event_Type__c` | Picklist | Corporate, Wedding, Birthday, Conference, Seminar, Concert, Exhibition |
| Event Status | `Event_Status__c` | Picklist | `Planned`, `Pending Cancellation`, `Canceled`, `Rejected`, `Completed` — default `Planned` |
| Event Budget | `Event_Budget__c` | Currency | Editable. The derived values are formulas. |
| Client | `Client__c` | Lookup → Client | |
| Venue | `Venue__c` | Lookup → Venue | Must be `Venue__c` — referenced by the trigger |
| Vendor Cost | `Vendor_Cost__c` | Roll-Up Summary | Created in Phase 3 |
| Budget Balance | `Budget_Balance__c` | Formula (Currency) | Created in Phase 3 |
| Budget Utilization | `Budget_Utilization__c` | Formula (Percent) | Created in Phase 3 |
| Days Until Event | `Days_Until_Event__c` | Formula (Number) | Created in Phase 3 |

**Picklist spelling is load-bearing.** `Canceled` has one L. If your org uses `Cancelled`, edit the constants at the top of `VenueAvailabilityHandler.cls` and the status list in the `BatchCompleteEvents` query.

### 5. `Feedback__c`

Label `Feedback`, plural `Feedbacks`, record name **Feedback ID** — **Auto Number**, format `FB-{0000}`.

| Field Label | API Name | Type | Detail |
|---|---|---|---|
| Rating | `Rating__c` | Number(2,0) | 1–5 |
| Comments | `Comments__c` | Long Text Area | |
| Event | `Event__c` | Lookup → Event | |
| Client | `Client__c` | Lookup → Client | |

### 6. `EventVendor__c` (junction)

Label `Event Vendor`, plural `Event Vendors`, record name **Event Vendor** — **Auto Number**, format `EV-{0000}`.

| Field Label | API Name | Type | Detail |
|---|---|---|---|
| Event | `Event__c` | **Master-Detail** → Event | Create first |
| Vendor | `Vendor__c` | **Master-Detail** → Vendor | Second MD on one object is what makes it a junction |
| Estimated Cost | `Estimated_Cost__c` | Currency(16,2) | Aggregated by the roll-up on Event |

Leave *Allow Reparenting* unticked. Set the related-list labels to `Event Vendors` on Event and `Vendors Assigned` on Vendor.

## Relationships

| From | To | Type | Effect |
|---|---|---|---|
| `Event__c` | `Client__c` | Lookup | Event survives client deletion; client is optional |
| `Event__c` | `Venue__c` | Lookup | Enables an event with no venue |
| `Feedback__c` | `Event__c` | Lookup | |
| `Feedback__c` | `Client__c` | Lookup | |
| `EventVendor__c` | `Event__c` | **Master-Detail** | Junction row dies with the event; sharing is *Controlled by Parent* |
| `EventVendor__c` | `Vendor__c` | **Master-Detail** | Junction row dies with the vendor |

The many-to-many between Event and Vendor is realised through `EventVendor__c`. Master-detail is required here, not optional: the roll-up summary field on `Event__c` only aggregates across a master-detail child.

### Lookup filter

Apply the Lookup Filter subtask to **`EventVendor__c.Vendor__c`** with criteria `Vendor: Status equals Active`.

Do **not** put a lookup filter on `Event__c.Venue__c` restricting it to `Available` venues. Once `EventTrigger` marks a venue `Reserved`, editing that same event would fail the filter and the record could not be saved.

## Field-level notes

In the field wizard's final step, tick the page layouts to add the field to. Fields that exist but are not on a layout are invisible, and screenshots come out empty.

### Why `Email__c` is an Email field

Email Alert recipients can only be Email-type fields, and the approval process must notify the client directly. With a Text field there is no way to address an alert to `Client__c.Email__c`.

The cost is that Salesforce's own format validation runs before the custom `Email_Valid_Address` rule. To demo the custom rule, use `john@college` — no dot and no TLD, which the native check accepts but the regex rejects, so the custom message appears.

## Phase 2 — Custom tabs

Setup → User Interface → **Tabs** → under *Custom Object Tabs* → **New**.

| Object | Tab Label | Tab Name | Default On |
|---|---|---|---|
| `Event__c` | Event | `Event` | System Administrator |
| `Client__c` | Client | `Client` | System Administrator |
| `Vendor__c` | Vendor | `Vendor` | System Administrator |
| `Venue__c` | Venue | `Venue` | System Administrator |
| `Feedback__c` | Feedback | `Feedback` | System Administrator |

Wizard per tab: Object → Tab Label (Tab Name auto-fills) → Tab Style icon → Add to Custom Apps → Apply to Profiles → Add to Lightning Experience Apps → Save.

- `Event` may be rejected as a Tab Name because Salesforce has a standard Event object. If so use `Event_Planner`; the Tab Label is what users see.
- **No tab for `EventVendor__c`.** Junction rows are managed from the Event's related list. A tab would allow orphan rows and is not how many-to-many relationships are meant to be used.
- If you ticked *Launch New Custom Tab Wizard* in Phase 1 these already exist — verify the icon and profile visibility rather than recreating them.

## Phase 2 — Lightning app

Setup → **App Manager** → New Lightning App.

| Setting | Value |
|---|---|
| App Name | `Event Planner Management System` |
| API Name | `Event_Planner_Management_System` |
| Description | Cloud CRM for managing the full event lifecycle — clients, venues, vendors, coordinators and post-event feedback. |
| Contact Email | your dev org email |

**App Options** — choose an icon and header colour; leave Pinning off.

**Navigation Items** — in this order, because the order *is* the nav bar:

```
Home   Event   Client   Vendor   Venue   Feedback
```

Add `Home` only if it appears in Available Items.

**Utility Items** — `Notes` and `Recent Items`. These appear on the utility bar.

**Profiles** — `System Administrator` for now. The four custom profiles are added in Phase 6; return to this screen then.

Save.

## Verify Phase 1 and 2

1. App Launcher → search `Event` → open **Event Planner Management System**. If it is missing, click *All Items*; if still missing, the profile was not enabled.
2. Nav bar reads Home · Event · Client · Vendor · Venue · Feedback.
3. Venue → New → create one with Availability Status `Available`.
4. Event → New → select that venue → Save.
5. Reopen the venue: Availability Status reads `Reserved`. That is `EventTrigger` working.

If step 5 still shows `Available`, Setup → Apex Triggers → `EventTrigger` → confirm Status is *Active*.

Screenshot for the report: the App Launcher tile, and the nav bar with a record open.
