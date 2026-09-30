# EventForce — Event Management System on Salesforce

A cloud CRM for event management companies, built on the Salesforce platform. It connects clients, venues, vendors and event coordinators in one system and automates the event lifecycle: client onboarding, event planning, vendor coordination, venue booking, cancellation approvals and post-event feedback.

Built in a free **Salesforce Developer Org** as an academic project.

## Important: most of this project lives in the org, not in this repo

Salesforce is a configuration-first platform. Objects, fields, relationships, flows, validation rules, approval processes, profiles, roles, permission sets, sharing rules, reports and dashboards are all stored as metadata **inside the org** and are built through the Setup UI. They are not source files you can commit.

So this repository contains two things:

1. **`apex/`** — the actual code. Six files, ready to paste into Developer Console.
2. **`docs/`** — the exact configuration of every org-side component, written as a reproducible build guide, so the whole org can be rebuilt from scratch.

If you want org metadata as deployable source instead, retrieve it with `sf project retrieve start` against a DX project — that is a packaging decision, not part of this build.

## Repository layout

```
apex/
  VenueAvailabilityHandler.cls        Trigger handler: venue availability + double-booking prevention
  EventTrigger.trigger                Trigger on Event__c (before/after insert, before/after update)
  BatchCompleteEvents.cls             Nightly batch: past events -> Completed
  ScheduleCompleteEvents.cls          Schedulable wrapper that runs the batch
  VenueAvailabilityHandlerTest.cls    12 unit tests covering trigger, batch and scheduler
  SeedEventForceData.cls              One-shot sample-data seeder (47 records)

docs/
  01-data-model.md                    Objects, fields, relationships, tabs, app
  02-validation-and-formulas.md       Validation rules, formula and roll-up fields
  03-automation.md                    3-day reminder flow, cancellation approval process, Apex behaviour
  04-analytics-and-sample-data.md     Seeding, report types, three reports, dashboard
  05-security.md                      OWD, profiles, role hierarchy, permission set, sharing rules, users
  06-demo-and-viva.md                 Recorded-demo script and expected viva questions

PROJECT_REPORT.md                     Formal report in the required submission format
```

## Apex components

| File | Type | Purpose |
|---|---|---|
| `VenueAvailabilityHandler` | Apex class | Two entry points: `preventDoubleBooking` (before) blocks two live events on the same venue **on the same date**; `updateVenueAvailability` (after) sets `Venue__c.Availability_Status__c` to `Reserved` while a venue has any live booking and `Available` when it has none. |
| `EventTrigger` | Trigger | On `Event__c`, before insert/update and after insert/update. Delegates to the handler — no logic in the trigger body. |
| `BatchCompleteEvents` | Batch Apex | Marks events whose date has passed as `Completed`. Excludes `Canceled` and `Pending Cancellation` so it cannot overwrite an approval outcome. |
| `ScheduleCompleteEvents` | Schedulable | Calls the batch with a scope size of 200. Scheduled daily at 20:00 through Setup → Schedule Apex. |
| `VenueAvailabilityHandlerTest` | Test class | 12 tests: reservation, release on cancel/complete, venue change, double-booking block, same-save duplicate block, different-date allowance, cancelled-event rebooking, null venue, batch selectivity, scheduler execution. |
| `SeedEventForceData` | Utility | Creates 47 demo records in one transaction. Not part of the application. |

### Deploying the Apex

Developer Console → File → New → Apex Class (or Apex Trigger). Create them **in this order**, because the trigger will not compile until the handler exists:

1. `VenueAvailabilityHandler`
2. `EventTrigger` — set sObject to `Event__c`
3. `BatchCompleteEvents`
4. `ScheduleCompleteEvents`
5. `VenueAvailabilityHandlerTest`
6. `SeedEventForceData`

Then Setup → Apex Classes → `VenueAvailabilityHandlerTest` → Run. All 12 tests should pass.

### Field API names the code depends on

| Object | Field | API name |
|---|---|---|
| `Event__c` | Event Date | `Event_Date__c` |
| `Event__c` | Event Status | `Event_Status__c` |
| `Event__c` | Venue (lookup) | `Venue__c` |
| `Event__c` | Client (lookup) | `Client__c` |
| `Venue__c` | Availability Status | `Availability_Status__c` |
| `EventVendor__c` | Estimated Cost | `Estimated_Cost__c` |

Picklist values must be spelled exactly: `Planned`, `Pending Cancellation`, `Canceled` (one L), `Rejected`, `Completed` on Event; `Available`, `Reserved` on Venue. They are declared once as constants at the top of `VenueAvailabilityHandler` and repeated in the `BatchCompleteEvents` query.

## Build order

| Phase | Deliverable | Guide |
|---|---|---|
| 1 | Developer org, custom objects, fields, relationships | `docs/01-data-model.md` |
| 2 | Custom tabs and the Lightning app | `docs/01-data-model.md` |
| 3 | Validation rules, formula and roll-up fields | `docs/02-validation-and-formulas.md` |
| 4 | Reminder flow, approval process, Apex | `docs/03-automation.md` |
| 5 | Sample data, reports, dashboard | `docs/04-analytics-and-sample-data.md` |
| 6 | OWD, profiles, roles, permission set, sharing rules | `docs/05-security.md` |

## Deviations from the original specification

Recorded here so they can be defended rather than discovered.

1. **Double-booking is date-aware.** The brief said "prevent double bookings" without qualifying it. Blocking any two live events on the same venue would mean four venues could never host ten events. The rule blocks two live events on the same venue **on the same date**, which is what double booking actually means for single-day events.
2. **`BatchCompleteEvents` excludes canceled events.** The specified query, `Event_Status__c != 'Completed'`, also matches `Canceled` and `Pending Cancellation`, so the nightly job would have overwritten the approval process outcome. The implemented query excludes all three.
3. **`Client__c.Email__c` is an Email field, not Text.** Email Alerts can only address Email-type fields, and the approval process must notify the client. Trade-off: Salesforce runs its own format check first, so the custom `Email_Valid_Address` rule only surfaces for values the native check accepts, such as `john@college`.
4. **No custom tab for `EventVendor__c`.** A junction object is managed from the *Event Vendors* related list on the Event record. Giving it a tab would allow orphan junction rows to be created directly.
5. **`EventVendor__c.Estimated_Cost__c` was added.** Not in the original field list, but a budget is only meaningful against committed spend, and this is the field the roll-up summary aggregates.
