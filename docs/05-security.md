# Phase 6 — Security Model

Five layers, applied in this order: Organization-Wide Defaults set the floor, the role hierarchy opens records upward, profiles cap what a user can do, permission sets add narrow exceptions, and sharing rules open specific records sideways.

Build order: OWD → Roles → Profiles → Permission Set → Sharing Rules → Users.

---

## 6a. Organization-Wide Defaults

Setup → Users → **Sharing Settings** → *Edit*.

| Object | OWD | Why |
|---|---|---|
| Client | **Private** | Personal contact data. Only the owner and users above them in the hierarchy should see it. |
| Event | **Private** | Commercially sensitive — budgets and client relationships. |
| Feedback | **Private** | Contains client criticism that should not be visible to vendor-facing staff. |
| Vendor | **Public Read Only** | Shared reference data every coordinator needs, but only vendor managers maintain it. |
| Venue | **Public Read Only** | Everyone must be able to see availability to plan an event; only admins and venue managers edit it. |
| Event Vendor | **Controlled by Parent** | Automatic and not editable. A master-detail child always inherits its parent's sharing — which is precisely why the junction uses master-detail. |

Leave **Grant Access Using Hierarchies** ticked on every object. This is the default, and it is what lets the Event Admin see everything owned by roles below them. If you untick it, hierarchy stops working and every upward grant needs an explicit sharing rule — a good viva contrast, but not what this project wants.

Click **Save**. Recalculation runs asynchronously; large orgs show a progress banner.

---

## 6b. Role hierarchy

Setup → Users → **Roles** → Create Role. Build the tree top-down.

```
Event Admin
├── Event Coordinator
├── Vendor Manager
└── Venue Manager
```

For **Event Admin**: *Choose a reporting structure* → **None** (it is the root). Role Name `Event Admin`, Role Unique Name `Event_Admin`. Leave the User field empty for now — users are created at the end of this phase.

For each of the other three: Roles → click **Event Admin** → *Add Role* → fill Role Name and Unique Name (`Event_Coordinator`, `Vendor_Manager`, `Venue_Manager`) → reports to `Event Admin` → Save.

**There is deliberately no Client role.** Clients are not internal staff, so they do not belong in the internal reporting hierarchy. Their visibility comes from record ownership plus OWD, not from a reporting line. That is the answer if asked why the spec lists a Client profile but only four roles.

The hierarchy has one effect: **Event Admin sees every record owned by the three roles beneath it**, regardless of Private OWD. It grants nothing sideways — a Coordinator cannot see a Vendor Manager's records. That is what sharing rules are for.

---

## 6c. Profiles

Setup → Users → **Profiles** → New. The *Clone From* picklist matters — always clone rather than build from scratch.

| Profile | Clone From |
|---|---|
| `Event Admin` | **System Administrator** |
| `Event Coordinator` | Standard User |
| `Vendor Manager` | Standard User |
| `Client` | Standard User |

### Object permissions

Profile → *Object Permissions* → Edit.

| Object | Event Admin | Event Coordinator | Vendor Manager | Client |
|---|---|---|---|---|
| Event | C R E D | C R E D | R | R |
| Client | C R E D | C R E | — | R |
| Vendor | C R E D | R E | C R E D | — |
| Venue | C R E D | R E | R | R |
| Feedback | C R E D | C R E D | R | C R |
| Event Vendor | C R E D | C R E D | C R E D | — |

`—` means no access at all. Note the two deliberate exclusions: **Vendor Manager cannot read Client** (they negotiate services, they do not need client contact data) and **Client cannot read Vendor** (clients should not be able to browse the supplier directory).

Because `Event Vendor` is master-detail, its access level is actually *Controlled by Parent* at the sharing layer — but the profile still needs CRUD on the object or the related list will not render.

### Tab settings

Profile → *Tab Settings*.

| Tab | Event Admin | Event Coordinator | Vendor Manager | Client |
|---|---|---|---|---|
| Event | Default On | Default On | Default On | Default On |
| Client | Default On | Default On | **Tab Hidden** | Default On |
| Vendor | Default On | Default On | Default On | **Tab Hidden** |
| Venue | Default On | Default On | Default On | Default On |
| Feedback | Default On | Default On | Default On | Default On |

A hidden tab removes navigation but does **not** remove data access — that is what the object permissions above control. Setting both is what makes the restriction real.

### App and system permissions

- Profile → *Assigned Apps* → tick **Event Planner Management System**. Do this for all four; without it the app is invisible in the App Launcher for that profile. This is the step most often forgotten after Phase 2, where only System Administrator was enabled.
- **Event Coordinator** — System Permissions: tick `API Enabled`, `Run Flows`, `Run Reports`, `Export Report`, `Mass Delete`, `Transfer Record`. Do **not** tick `View All Data`.
- **Vendor Manager** — tick `API Enabled`, `Run Reports`.
- **Client** — leave Standard User defaults. Explicitly confirm `View All Data` and `Modify All Data` are off.

### Field-Level Security

The fastest path is per-field, because it sets all four profiles on one screen: Object Manager → object → Fields & Relationships → the field → **Set Field-Level Security**.

| Field | Event Admin | Event Coordinator | Vendor Manager | Client |
|---|---|---|---|---|
| `Event__c.Event_Budget__c` | Visible + R/W | Visible + R/W | **Hidden** | **Hidden** |
| `Event__c.Vendor_Cost__c` | Visible | Visible | Visible | **Hidden** |
| `Event__c.Budget_Balance__c` | Visible | Visible | **Hidden** | **Hidden** |
| `Event__c.Budget_Utilization__c` | Visible | Visible | **Hidden** | **Hidden** |
| `Event__c.Days_Until_Event__c` | Visible | Visible | Visible | Visible |
| `EventVendor__c.Estimated_Cost__c` | Visible + R/W | Visible + R/W | Visible + R/W | **Hidden** |
| `Client__c.Email__c` / `Phone__c` | Visible | Visible | n/a (no Client access) | Visible |

**The formula leak — say this in the viva.** `Budget_Balance__c` is a formula built from `Event_Budget__c`. Hiding the source field but leaving the formula visible would let a Vendor Manager subtract `Vendor_Cost__c` from `Budget_Balance__c` and recover the client's budget exactly. Field-Level Security is not propagated through formula evaluation, so both derived fields must be hidden alongside the field they derive from. This is why `Budget_Balance__c` and `Budget_Utilization__c` are hidden from Vendor Manager even though `Vendor_Cost__c` is not.

### Apex class access

Do not bother granting Apex access to the three restricted profiles. Triggers execute in system context and run regardless of profile Apex settings, and the scheduled batch runs as the Automated Process user. Profile-level Apex access only matters for classes a user invokes directly, and none of these are invoked that way. Event Admin inherits everything from the System Administrator clone.

---

## 6d. Permission set

Setup → Users → **Permission Sets** → New.

| Setting | Value |
|---|---|
| Label | `Budget Analysis` |
| API Name | `Budget_Analysis` |
| Licence | leave blank |

Open it → **Object Settings** → Event → Edit → tick **Read** on the object, then under Field Permissions tick Visible for `Event_Budget__c`, `Vendor_Cost__c`, `Budget_Balance__c` and `Budget_Utilization__c` → Done → Save.

Assign: Permission Set → **Manage Assignments** → Add Assignments → select the Vendor Manager user → Next → Assign.

**Why a permission set and not a profile edit.** The Vendor Manager profile deliberately hides the client's budget. One specific vendor manager occasionally needs to review budget utilisation across events. Editing the profile would grant it to every vendor manager permanently; a permission set grants it to one named user and can be revoked without touching the profile. That is the entire purpose of permission sets and the expected viva answer.

Note the interaction: the permission set makes `Budget_Balance__c` visible, which re-exposes the formula leak described above for that one user. That is an accepted, deliberate trade-off for a named analyst — and a good thing to volunteer before being asked.

---

## 6e. Sharing rules

Setup → Users → Sharing Settings → scroll to **Sharing Rules**.

### Rule 1 — criteria-based on Event

| Setting | Value |
|---|---|
| Label | `Share Pending Cancellations with Admins` |
| Rule Type | Based on criteria |
| Criteria | `Event Status` equals `Pending Cancellation` |
| Share with | Role → **Event Admin** |
| Access Level | **Read/Write** |

With Event OWD Private, an admin cannot act on a cancellation request they do not own. This rule opens exactly those records — and only those — the moment the approval process sets the status. When the status changes to `Canceled` or `Rejected` the record stops matching the criteria and access is withdrawn automatically.

### Rule 2 — role-based on Event

| Setting | Value |
|---|---|
| Label | `Coordinator Events to Vendor Managers` |
| Rule Type | Based on roles |
| Owner | Role → **Event Coordinator** |
| Share with | Role → **Vendor Manager** |
| Access Level | **Read Only** |

Vendor managers need to see what coordinators have planned so they can staff and supply it, but they must not be able to change event details. The role hierarchy cannot express this because the two roles are siblings under Event Admin — hierarchy only flows upward. That is exactly the gap sharing rules fill.

### Rule 3 — manual sharing (demonstration, not configuration)

Open any Event record → **Share** button (top right, or the dropdown) → Add Users → pick a user → Read Only → Save. Show this to prove per-record exception handling exists without any configuration.

Click **Recalculate** at the top of the Sharing Rules page after creating rules. Salesforce processes it asynchronously.

---

## 6f. Users

Setup → Users → **New**.

A Developer Org allows only **2 users with a Salesforce licence**. The spec notes this. Two ways round it:

- Deactivate an unused seeded user, or change their licence type, freeing a seat.
- Use the **Salesforce Platform** licence instead. Every EventForce object is custom, and the Platform licence covers custom objects and Apex, so it is sufficient for the Coordinator, Vendor Manager and Venue Manager demo users.

| User | Username | Profile | Role | Licence |
|---|---|---|---|---|
| Event Coordinator | `coordinator.eventforce.<unique>@gmail.com` | Event Coordinator | Event Coordinator | Salesforce Platform |
| Vendor Manager | `vendormgr.eventforce.<unique>@gmail.com` | Vendor Manager | Vendor Manager | Salesforce Platform |

Usernames must be email-formatted and **globally unique across all of Salesforce**, not just your org. A plain `coordinator@gmail.com` will be rejected as already taken — use a made-up domain or a plus-address. Set Email to your own inbox so activation mail reaches you.

Assign yourself (the admin) to the **Event Admin** role so the hierarchy has a root user.

**Then go back to Phase 4** and reassign the approval process approver from your admin user to the Coordinator user: Setup → Approval Processes → Event → `Event Cancellation Approval` → edit the approver assignment and the approval step's assigned approver. Until you do this, you are both submitter and approver, which proves nothing about routing.

---

## 6g. Verify — and the trap

Setup → Users → find a user → dropdown → **Login As**. This opens a session as that user without their password.

**You cannot test any of this as the admin.** System Administrator has `View All Data`, which overrides OWD, sharing rules and record ownership entirely. Everything looks visible and the whole phase appears to do nothing. Every check below must be done through Login As.

| Log in as | Should see | Should NOT see |
|---|---|---|
| Event Coordinator | Own events; nothing owned by Vendor Manager or Venue Manager | Budget fields hidden? No — Coordinator sees all four budget fields |
| Vendor Manager | All Vendor records editable; Events read-only; events owned by the Coordinator via sharing rule 2 | `Event Budget`, `Budget Balance`, `Budget Utilization` columns render blank; Client tab absent |
| Client | Only records they own; Venue names on their events | Vendor tab absent; all budget and cost fields blank |
| Event Admin | Everything, including all three subordinate roles' records via hierarchy | — |

Because Event OWD is Private, the Coordinator and Client users see only records **they own**. To make the demo meaningful, change the Owner on two or three events to the Coordinator user (record → Change Owner) before logging in as them.

The single strongest screenshot is the **same Event record opened as Vendor Manager** with the budget fields blank, next to the same record as Event Admin with them populated.

---

## 6h. How the layers combine

Worked example, for the viva question *"walk me through what happens when a Vendor Manager opens an event owned by a Coordinator."*

1. **OWD** on Event is Private → the starting position is no access, because the manager is not the owner.
2. **Role hierarchy** grants nothing → Vendor Manager and Event Coordinator are siblings under Event Admin, and hierarchy only flows upward.
3. **Sharing rule 2** grants Read Only → this is the layer that actually opens the record.
4. **Profile object permission** allows Read but not Edit or Delete → the record opens read-only, and the Edit button is absent.
5. **Field-Level Security** hides `Event_Budget__c`, `Budget_Balance__c` and `Budget_Utilization__c` → those three columns render blank even though the record is visible.
6. **Permission set** `Budget_Analysis` would re-grant those four fields, but only for the one user it is assigned to.

Access is the intersection of all six. Removing any layer removes access; no single layer can grant more than the profile allows.
