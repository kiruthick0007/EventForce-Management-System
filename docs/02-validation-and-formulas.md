# Phase 3 — Validation Rules, Formula and Roll-Up Fields

## Validation rules

### `Email_Valid_Address` on `Client__c` (required)

Object Manager → **Client** → Validation Rules → **New**.

| Setting | Value |
|---|---|
| Rule Name | `Email_Valid_Address` |
| Active | ticked |
| Error Message | `Please Enter Valid Email Address` |
| Error Location | **Field** |
| Field | Email |

Error Condition Formula — paste exactly, including the double backslash:

```
NOT(REGEX(Email__c, "^[a-zA-Z0-9._]+@[a-zA-Z0-9.]+\\.[a-zA-Z]{2,}$"))
```

Click *Check Syntax*, then Save.

**The `\\.` is correct.** The formula parser consumes one backslash, so the regex engine receives `\.` — a literal period. A single `\.` fails the syntax check.

**Test values.** `abc@` is caught by Salesforce's native Email-field validation before your rule runs, so use **`john@college`** to demo the custom message. `john@college.edu` saves.

**Validation rules fire on every save**, including updates made by flows, Apex, field updates and Data Loader. Keep this in mind during Phase 4 — a flow that touches a Client record with an invalid email will fail.

### Optional additional rules

Same click path, different object. Wrap date rules in `ISNEW()` so existing records stay editable.

| Object | Rule Name | Formula | Error Message |
|---|---|---|---|
| `Event__c` | `Event_Date_Not_In_Past` | `AND(ISNEW(), Event_Date__c < TODAY())` | Event date cannot be in the past |
| `Feedback__c` | `Rating_Within_Scale` | `OR(Rating__c < 1, Rating__c > 5)` | Rating must be between 1 and 5 |
| `Event__c` | `Budget_Must_Be_Positive` | `AND(ISNEW(), Event_Budget__c <= 0)` | Event budget must be greater than zero |

If you create `Event_Date_Not_In_Past`, **deactivate it before running the sample-data seeder** — three seeded events are deliberately dated in the past so the nightly batch has work to do. Reactivate afterwards.

## Roll-up summary field

A roll-up only works across a master-detail relationship, which is why `EventVendor__c` uses master-detail rather than lookups.

Object Manager → Event → Fields & Relationships → New → **Roll-Up Summary**.

| Setting | Value |
|---|---|
| Field Label | `Vendor Cost` |
| API Name | `Vendor_Cost__c` |
| Summarized Object | Event Vendor |
| Roll-Up Type | SUM |
| Field to Aggregate | Estimated Cost |
| Filter Criteria | none |

This is the only way to total committed vendor spend per event. A lookup from `EventVendor__c` to `Event__c` would not offer the Roll-Up Summary option at all.

## Formula fields

### On `Event__c`

New → **Formula**.

| Label | API Name | Return Type | Formula |
|---|---|---|---|
| Budget Balance | `Budget_Balance__c` | Currency | `Event_Budget__c - Vendor_Cost__c` |
| Budget Utilization | `Budget_Utilization__c` | Percent (0 dp) | `IF(Event_Budget__c > 0, Vendor_Cost__c / Event_Budget__c, 0)` |
| Days Until Event | `Days_Until_Event__c` | Number (0 dp) | `Event_Date__c - TODAY()` |

`Event_Budget__c` stays an editable Currency field — the entered budget. Everything else is derived, so the balance cannot be mistyped. The `IF` guard prevents a divide-by-zero error when the budget is blank.

`Days_Until_Event__c` goes negative for past events. The *Upcoming Events* report filters on `Days Until Event >= 0`, which is the entire definition of "upcoming" — no date arithmetic in the report filter.

### On `Feedback__c`

| Label | API Name | Return Type | Formula |
|---|---|---|---|
| Rating Label | `Rating_Label__c` | Text | see below |

```
IF(Rating__c >= 5, "Excellent",
  IF(Rating__c >= 4, "Good",
    IF(Rating__c >= 3, "Average",
      IF(Rating__c >= 2, "Poor", "Very Poor"))))
```

Four nested `IF`s need four closing parentheses. This is the standard place a syntax error appears.

## Verify

1. Create a Client with email `john@college` → save → error under the Email field. Change to `john@college.edu` → saves.
2. Open an Event → the layout shows Vendor Cost, Budget Balance, Budget Utilization, Days Until Event.
3. Set `Event_Budget__c` = 500000. From the **Event Vendors** related list → New → vendor + Estimated Cost 120000 → Save.
4. Back on the Event: Vendor Cost 120000, Budget Balance 380000, Budget Utilization 24%.
5. Add a second junction row at 400000 → Balance −20000, Utilisation 104%. The negative case is what the dashboard's *Events Over Budget* component reports on.
6. Create a Feedback with Rating 9 → blocked. Rating 5 → Rating Label reads `Excellent`.

Screenshots for the report: the validation rule edit page showing the formula and the fired error; the Event record showing the three derived budget fields populated.
