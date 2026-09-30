# Phase 5 — Sample Data, Reports and Dashboard

## 5a. Sample data

`apex/SeedEventForceData.cls` creates 47 records in one transaction: 4 clients, 4 venues, 6 vendors, 10 events, 22 vendor assignments, 5 feedback rows.

### Before running

1. **Edit `DEMO_INBOX`** near the top of the class to a real inbox. Anita Desai owns three events and is the recipient for both the reminder flow and the approval emails.
2. **Deactivate `Event_Date_Not_In_Past`** if you created it. Three events are deliberately dated in the past so the nightly batch has work to do.
3. **`Event_Budget__c` must be a Currency field**, not a formula. If it is a formula, remove the `Event_Budget__c = ...` argument from all ten `new Event__c(...)` lines.
4. `EventVendor__c.Estimated_Cost__c` must exist.

### Run

Developer Console → Debug → **Open Execute Anonymous Window**:

```apex
SeedEventForceData.seed();
```

To start over:

```apex
SeedEventForceData.wipe();
SeedEventForceData.seed();
```

`seed()` refuses to run if any Event record already exists, so records cannot be duplicated by accident. `wipe()` deletes in dependency order — junction rows first, because a master-detail parent cannot be deleted while children exist.

### Dates are relative

Every date is computed from `Date.today()`, not hardcoded. Whenever the seeder runs, one event lands exactly three days out and three land in the past. The reminder flow always has a live target and the batch always has records to convert, so the demo does not rot as the calendar moves.

### What gets created

**Clients** — Priya Sharma (Chennai), Rahul Verma (Mumbai), Anita Desai (Bengaluru, `DEMO_INBOX`), Karan Malhotra (Delhi).

**Venues** — Grand Convention Hall (500), Seaside Resort Lawns (250), Metro Business Centre (180), Palace Grounds Pavilion (800). All start `Available`.

**Vendors** — Spice Route Caterers, Bloom Decor Studio, QuickMove Logistics, PixelFrame Photography, BassLine DJ Services (all Active), Legacy Sound & Light (Inactive).

**Events** — offsets are days from today:

| Event | Offset | Type | Status | Budget | Client | Venue |
|---|---|---|---|---|---|---|
| TechNova Annual Summit | −107 | Conference | Planned | 850000 | Anita Desai | Metro Business Centre |
| Verma Wedding Reception | −72 | Wedding | Planned | 1200000 | Rahul Verma | Palace Grounds Pavilion |
| Freshers Meet 2026 | −51 | Seminar | Planned | 150000 | Karan Malhotra | Grand Convention Hall |
| Startup Networking Night | −5 | Corporate | **Canceled** | 180000 | Rahul Verma | Grand Convention Hall |
| Product Launch Nova X | **+3** | Corporate | Planned | 600000 | Priya Sharma | Seaside Resort Lawns |
| Sharma Anniversary Dinner | +18 | Birthday | Planned | 250000 | Priya Sharma | Grand Convention Hall |
| GlobalCorp Leadership Offsite | +39 | Corporate | Planned | 950000 | Anita Desai | Metro Business Centre |
| Winter Music Festival | +53 | Concert | Planned | 1500000 | Karan Malhotra | Palace Grounds Pavilion |
| Tech Expo 2026 | +66 | Exhibition | Planned | 700000 | Priya Sharma | Grand Convention Hall |
| Desai Silver Jubilee | +108 | Wedding | Planned | 1100000 | Anita Desai | Seaside Resort Lawns |

No two live events share a venue on the same date, so nothing is blocked by `preventDoubleBooking`.

**Vendor assignments** — 22 junction rows. Resulting totals per vendor:

| Vendor | Events | Total Estimated Cost |
|---|---|---|
| Spice Route Caterers | 5 | 1,525,000 |
| Bloom Decor Studio | 6 | 1,300,000 |
| BassLine DJ Services | 3 | 960,000 |
| Legacy Sound & Light | 2 | 425,000 |
| QuickMove Logistics | 3 | 380,000 |
| PixelFrame Photography | 3 | 365,000 |

Budget utilisation per event:

| Event | Vendor Cost | Budget | Utilisation |
|---|---|---|---|
| TechNova Annual Summit | 520,000 | 850,000 | 61% |
| Verma Wedding Reception | 980,000 | 1,200,000 | 82% |
| Freshers Meet 2026 | 80,000 | 150,000 | 53% |
| Product Launch Nova X | 400,000 | 600,000 | 67% |
| **Winter Music Festival** | **1,600,000** | **1,500,000** | **107%** |
| Tech Expo 2026 | 435,000 | 700,000 | 62% |
| Desai Silver Jubilee | 940,000 | 1,100,000 | 85% |
| Sharma Anniversary Dinner | 155,000 | 250,000 | 62% |
| GlobalCorp Leadership Offsite | 510,000 | 950,000 | 54% |

Winter Music Festival is deliberately over budget by 100,000. That is the *Events Over Budget* dashboard component and the standard "what happens when a project overruns" answer.

**Feedback** — ratings 5, 4, 2, 5, 3 across the five events that have a narrative (three completed, one upcoming, one cancelled). The spread gives the rating report something to group.

### Verify the seed

- **Venues tab** — all four read `Reserved`. `EventTrigger` fired on a bulk insert, which is the first proof it is bulk-safe.
- Grand Convention Hall stays `Reserved` even though `Startup Networking Night` was inserted as `Canceled`, because three live events still hold it on other dates.
- Run the batch once so the past events convert:

```apex
Database.executeBatch(new BatchCompleteEvents(), 200);
```

Then check that TechNova Annual Summit, Verma Wedding Reception and Freshers Meet 2026 are `Completed` while Startup Networking Night remains `Canceled` — that is the batch's status exclusion working.

---

## 5b. Report folder

Reports tab → **New Folder** → `EventForce Reports` → shared with all users → Save.

## 5c. Custom report type

`EventVendor__c` has no tab, so no report type was auto-created for it, and the standard `Events` report type cannot reach vendor data.

Setup → **Custom Report Types** → New:

| Setting | Value |
|---|---|
| Primary Object | **Vendor** |
| Store in Category | EventForce Reports |
| Label | `Vendors with Event Assignments` |
| Deployment Status | **Deployed** |

Next screen → **Add Relationship** → select **Event Vendors** (the child) → add fields: from *Vendor* take Vendor Name, Service Type, Status; from *Event Vendors* take Estimated Cost.

## 5d. Report 1 — Upcoming Events: Summary by Month

Reports → New Report → report type **Events** → Start Report.

| Setting | Value |
|---|---|
| Filters | Show Me: **All Events** · Created Date: All Time · `Days Until Event` greater or equal `0` |
| Group Rows | `Event Date` → click the group dropdown → **Group Date By → Calendar Month** |
| Columns | Event Name, Client, Venue, Event Status, Event Budget, Vendor Cost, Budget Balance |
| Format | Summary |

Add a **bar chart**: X = Calendar Month, Y = Record Count. Save into `EventForce Reports` as `Upcoming Events — Summary by Month`.

This is where the Phase 3 formula pays off — `Days Until Event >= 0` is the whole definition of "upcoming", with no date arithmetic in the filter.

## 5e. Report 2 — Vendor Performance

New Report → type **Vendors with Event Assignments**.

| Setting | Value |
|---|---|
| Filters | Show Me: All · `Vendor: Status` equals `Active` |
| Group Rows | `Vendor Name` |
| Columns | Service Type, Estimated Cost |
| Summarize | Sum of Estimated Cost, plus row count |

Sort by Sum of Estimated Cost descending. Add a **horizontal bar chart** on Vendor Name / Sum of Estimated Cost. Save as `Vendor Performance`.

Expected with the seeded data: Spice Route Caterers 1,525,000 · Bloom Decor Studio 1,300,000 · BassLine DJ Services 960,000 · Legacy Sound & Light 425,000 · QuickMove Logistics 380,000 · PixelFrame Photography 365,000. Legacy Sound & Light is excluded by the `Status = Active` filter, which is the point of that filter.

## 5f. Report 3 — Event Summary

New Report → type **Events**, Show Me: All Events.

| Setting | Value |
|---|---|
| Group Rows | `Event Status`, then nested `Event Type` |
| Columns | Event Name, Client, Venue, Event Date, Event Budget, Vendor Cost, Budget Utilization |
| Summarize | Sum of Event Budget, Average of Budget Utilization |

Add a **donut chart** grouped by Event Status. Save as `Event Summary`.

## 5g. Dashboard

Reports tab → **Dashboards** → New Folder `EventForce Dashboards` → New Dashboard → name `EventForce Dashboard`, save into that folder.

| Component | Type | Source report | Display |
|---|---|---|---|
| Upcoming Events by Month | Vertical Bar | Upcoming Events — Summary by Month | Calendar Month / Record Count |
| Events by Status | Donut | Event Summary | Event Status / Record Count |
| Spend by Vendor | Horizontal Bar | Vendor Performance | Vendor Name / Sum of Estimated Cost |
| Events Over Budget | Table | Event Summary | Event Name, Budget Balance — filter `Budget Balance < 0` |
| Total Upcoming Events | Metric | Upcoming Events — Summary by Month | Record Count |

Set **View Dashboard As → The dashboard viewer**, then Save.

## Verify analytics

1. Schedule the batch: Setup → Apex Classes → **Schedule Apex** → Job Name `Daily Event Completion`, class `ScheduleCompleteEvents`, Frequency Weekly, all days, 20:00.
2. Open all three reports — each returns rows.
3. Open the dashboard — five components populated, Winter Music Festival listed under *Events Over Budget*.

**Two gotchas.** Dashboard components cache, so after running the batch click **Refresh**. And if a report shows no rows while the data exists, the *Show Me* filter is set to **My** records rather than **All** — which will start mattering once Phase 6 sets Organization-Wide Defaults to Private.

Screenshots for the report: each report with its chart, and the full dashboard.
