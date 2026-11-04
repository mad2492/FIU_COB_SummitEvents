---
title: FIU Events (Summit Events Extension Layer) Solutions Design Doc
subtitle: Plain-language design and operating reference for FIU_SummitEvents
profile: controlled
owner: FIU Business Salesforce Team
audience: FIU Business administrators and technical support
version: "0.2"
last_updated: November 4, 2026
status: Draft
related_metadata: FIU_Events app, FIU_Events_User, FIU_ADA_Notice, FIU_Floating_Register, FIU_RSVP_Core2026, Summit Events Visualforce templates, Fiu* Apex classes and LWCs
---

> Audience: any admin, with or without a developer background. Write in plain language.
> Explain *what* and *why* first; keep the technical surface area as a reference section.
>
> **Status: mixed.** The FIU Events app is **in development (Phase 1)** in the **Partial UAT**
> sandbox and has not been promoted to Production. The public registration page templates **are
> live in Production** as of November 4, 2026.

| Project detail | Value |
|---|---|
| Project | FIU_SummitEvents |
| Repo | https://github.com/mad2492/FIU_COB_SummitEvents |
| Protected branch | main |
| Build target org | Partial UAT sandbox, then Production when approved |
| Last documented commit | ca393cf |
| Last updated | November 4, 2026 |

# Plain-language Summary

FIU uses the **Summit Events** managed package to run admissions/recruiting events
(open houses, info sessions, study-abroad sessions, etc.). The package is powerful but
exposes a confusing, object-heavy setup model that asks non-technical staff to understand
Salesforce architecture before they can create a working event.

This project is an **FIU-owned experience layer that sits on top of Summit Events** — a
custom Lightning app ("FIU Events") with guided wizards, plain-language browsers, and
readiness checks. It lets staff create, clone, and operate events correctly **without**
needing to understand the underlying package structure. It does **not** replace or modify
the Summit managed package; it wraps it in a friendlier, mistake-proof front end.

The project also owns the **public registration page templates**: the pages people see when
they register for an event. These follow FIU's Core web design and carry the university's
required accommodations notice.

# Why It Exists

FIU staff think of an event as a single thing. Summit Events is actually two layers:

- a **parent Event** record that acts as a reusable container/template, and
- one or more **Event Instance** records that are the actual dated occurrences.

That mismatch causes recurring, costly mistakes: people create a brand-new parent Event
when they only needed another Instance, fail to reuse prior setup, misunderstand clone
behavior, and — most damaging — skip required operational fields. A missing payment
gateway, blank account, zero capacity, or un-toggled email setting produces a broken public
registration page, failed payments, no confirmation emails, or Opportunities that never get
created.

The goal of this layer is to make the right action obvious ("do I need a new Event, a clone,
or another Instance?"), guide the user through valid setup, and surface readiness problems
*before* an event goes live — instead of discovering them after registrants are affected.

# Major Features

> Legend: ✅ implemented in UAT · 🚧 in progress / partial · 🔭 planned (Phase 2) · 🟢 live in Production

## Public registration page templates (FIU Core 2026) 🟢

- **What it does:** Each Summit Event picks a Visualforce template, which supplies the banner,
  page design, accommodations notice, and footer around the registration form. All 16 FIU
  templates now use FIU's current Core web design: its fonts, type sizes, page width, and
  buttons.
- **Who uses it:** Anyone registering for an FIU event. Staff choose a template on the Event
  record.
- **Notable behavior:** Each unit keeps its own logo, contact details, and form scripts. On
  phones, a Register button floats at the bottom of open registration pages until the form is
  on screen.

## Reasonable Accommodations Policy notice 🟢

- **What it does:** Shows the university's required accommodations and nondiscrimination text
  in Core's Blue - General callout.
- **Why it matters:** FIU requires this text on every page that promotes the details of an event
  or takes registrations for it, and a page without it may be taken down or modified.
- **Notable behavior:** The wording lives in one place, the `FIU_ADA_Notice` component, and all
  16 templates use it. If the university changes the wording, update that component only. Copy
  the text verbatim from the [FIU Core policy post](https://core.fiu.edu/blog/2026/reasonable-accommodations-policy-for-events.html).

## FIU Events app & home dashboard ✅

- **What it does:** A dedicated "FIU Events" Lightning app with a Home dashboard summarizing
  upcoming instances, open/started registrations, and counts of events/instances that are
  "not ready" (missing required setup), plus an attention list of items needing action.
- **Who uses it:** FIU event staff and admins.
- **Notable behavior:** Home is the launch point; "not ready" counts come from the readiness
  engine (see below).

## Event-first launcher & guided workflows 🚧

- **What it does:** Presents the three core choices in plain language — **Create New Event**,
  **Clone Existing Event**, **Add New Instance to Existing Event** — each with guidance on
  when to use it. Wizards then walk the user through valid setup.
- **Who uses it:** Anyone setting up an event.
- **Notable behavior:** Create and Clone and Add-Instance wizards exist as components; clone
  surfaces **risk warnings** (see clone risk below). Wizard polish and validation are still
  being refined.

## Clone Event with risk warnings ✅

- **What it does:** Before cloning, evaluates the source event and shows risk warnings plus a
  snapshot of what will carry over, so users don't blindly duplicate a broken or misconfigured
  setup.
- **Notable behavior:** Backed by `FiuEventsOrchestratorService.evaluateCloneRisk`.

## Readiness / "is this event safe to go live?" engine ✅

- **What it does:** Checks events and instances against FIU's operational rules and reports
  **Blocker / Warning / Info** issues — e.g. missing payment gateway, missing accounting
  department, blank account, zero/blank capacity, missing program-of-interest values. Blockers
  are meant to stop preview/publish of a broken event.
- **Who uses it:** Staff (to fix issues) and admins (to diagnose). Shown via the Readiness
  Dashboard and inline in wizards.
- **Notable behavior:** Policy lives in `FiuReadinessPolicyService`; recalculation runs
  asynchronously (queueable) when events/instances change, with re-entrancy guards.

## Event / Instance / Registration browsers ✅

- **What it does:** Plain, filterable list views (built on a shared list-shell component with
  a right-side quick-view) for browsing Events, Instances, and Registrations — replacing the
  related-list-heavy native experience. Includes program/status filtering.
- **Who uses it:** Day-to-day event operators.

## Instance roster & attendance manager 🚧

- **What it does:** View RSVP/attendance by instance and update attendance more naturally
  after an event.
- **Notable behavior:** Backed by `FiuEventsRosterService`; field API names are resolved
  defensively to tolerate org/package variations.

## CSV export of attendees ✅

- **What it does:** Export an instance's attendee/registration list to CSV instead of wrestling
  with related lists.
- **Notable behavior:** Backed by `ExportCsvController`.

## In-app Events Guide ✅

- **What it does:** A teaching page that explains the Event → Instance → Registration model
  in plain language so staff build the right mental model.

## Public file / image link helper ✅

- **What it does:** Creates a public (ContentDistribution) link for an uploaded file/image so
  it can be referenced by the public event website.
- **Notable behavior:** Backed by `FiuPublicFileService`; guards base64 size against heap limits.

## Plan / Business-Unit lookup helper ✅ (pre-existing FIU asset, retained)

- **What it does:** Guides users to select the program / plan / business-unit values that feed
  the FIU website/API and downstream Opportunity-creation logic.
- **Notable behavior:** Component `spEventsFIUPlanLookup`.

## Phase 2 — OGI / study-abroad & advanced Summit usage 🔭

- Advanced flows for OGI users who rely more on native Summit Questions, Emails, and
  payment-driven registration; advanced payment UX; exception/reporting dashboards. Deferred.

# Salesforce Surface Area (the Dev Bridge)

The concrete metadata this project touches. **All FIU-owned** — the Summit managed package is
not modified.

**Public registration templates (live in Production):**

- Visualforce pages: `SP_RsvpTemplate`, `SP_OpenEnrollmentTemplate`,
  `FIU_RsvpTemplate_NonRecruitment`, `FIU_GeneralPayment_Template`, `FIU_EPE_NonRecruitment`,
  `FIU_OGI_Template`, `FIU_EPE_OpenEnrollment`, `PINO_RsvpTemplate`, `FIU_Pino_Payment_Template`,
  `FIU_GSC_RsvpTemplate`, `FIU_GSC_Full_Template`, `FIU_EPE_Payment_Template`,
  `FIU_Student_Services_Template`, `FIU_Chapman_Payment_Template`, `FIU_EPE_RsvpTemplate`,
  `FIU_Financial_Aid_RSVP_Template`.
- Components: `FIU_ADA_Notice` (required policy text) and `FIU_Floating_Register` (phone button).
- Static resource: `FIU_RSVP_Core2026` (the layout rules Core does not provide, and form sizing).
- External assets, loaded live: FIU Core CSS and JS from `digicdn.fiu.edu`, `brand-2026.css` from
  `core.fiu.edu`, the proxima-nova font kit from Adobe Fonts, and `custom.js` and
  `info-sessions-listing.js` from `business.fiu.edu`.
- In Production but not yet in this repo: `SPRsvpTemplateController`, `SPRsvpTemplateService`,
  `SPSummitEventBaseService`, `SPSummitEventsUtils`, and the `sp_rsvp` and `sp_open_enrollment`
  static resources.

**Apex (all with sharing):**

- `FiuEventsAccessService` — resolves the Summit Event object API name across org variants and
  the allowed/scoped record-type IDs; central access/describe helper used by other services.
- `FiuEventsOrchestratorService` — clone risk evaluation (`evaluateCloneRisk`): warnings +
  carryover snapshot.
- `FiuEventsReadinessService` — per-event readiness evaluation (ready flag, warnings, missing
  fields).
- `FiuReadinessPolicyService` — the readiness rule set / severities (Blocker/Warning/Info) for
  events and instances.
- `FiuReadinessRecalcService` — async (queueable) recalculation of readiness when events/
  instances change, with internal-update re-entrancy guard.
- `FIU_EventsWizardService` / `FiuInstanceWizardService` — backing logic for the create/clone
  and add-instance wizards.
- `FiuEventBrowserService` / `FiuInstanceBrowserService` / `FiuRegistrationBrowserService` —
  data for the three browsers.
- `FiuHomeDashboardService` — home dashboard metrics (upcoming instances, open/started
  registrations, not-ready counts, attention & upcoming rows).
- `FiuEventsRosterService` — instance roster + attendance rows.
- `FiuProgramFilterService` — program/plan filter options.
- `FiuPublicFileService` — public ContentDistribution link creation for files/images.
- `ExportCsvController` — attendee CSV export.
- Tests: `FiuEventsServicesTest`, `FiuInstanceBrowserServiceTest`, `FiuReadinessPolicyServiceTest`,
  `FiuReadinessRecalcServiceTest`, `FiuPublicFileServiceTest`, `FiuSupportServicesCoverageTest`,
  `FiuAppScopeIntegrationTest`, `ExportCsvControllerTest`.

**LWC / UI:**

- `fiuEventsHome` (Home dashboard), `fiuEventsLauncher` (3-choice launcher), `fiuEventsGuide`
  (teaching page).
- `fiuEventBrowser`, `fiuInstanceBrowser`, `fiuRegistrationBrowser` (browsers) on
  `fiuListShell` (shared shell + quick view).
- `fiuEventCreateWizard`, `fiuEventCloneWizard`, `fiuInstanceCreateWizard` (wizards).
- `fiuInstanceWorkspace`, `fiuInstanceRosterManager` (attendance/roster).
- `fiuReadinessDashboard` (readiness view).
- `fiuDatatable` / `fiuDatatablePillCell` (shared table primitives).
- `spEventsFIUPlanLookup` (program/plan helper, retained).

**Flows (FIU-owned):**

- `Event_Created_Create_Campaign` — record-triggered: create a Campaign when an Event is created.
- `Event_Instance_Created_Create_Campaign` — record-triggered: create a Campaign per Instance.
- `Clone_Summit_Event_Instance` — instance clone helper.

**App / tabs / objects:**

- Custom app `FIU_Events` (tabs: Home, Event Browser, Instance Browser, Registration Browser,
  Events Guide).
- Custom tabs for the wizards, guide, and readiness dashboard.
- Objects referenced (managed package, **not modified**): `summit__Summit_Events__c`,
  `summit__Summit_Events_Instance__c` (and registration/payment objects from the package).

**Key event-level fields the readiness rules depend on:**
`summit__Payment_Gateway__c`, `Accounting_Department__c`, `summit__Account__c`,
`summit__Capacity__c`, `FIU_Create_Opps_From_Regs__c`, `Send_Registration_Confirmation_Email__c`.

# Personas & Permissions

| Persona | Permission set(s) | Can do |
|---|---|---|
| FIU event staff / admin | **FIU_Events_User** | Access the FIU Events app shell, browsers, guided wizards, readiness dashboard, roster/attendance, and CSV export. |

The permission set grants the FIU Events tabs and the supporting Apex/UI. It is the single
access grant for this layer today; finer-grained role separation (e.g. read-only diagnostic
vs. full editor) is an open item.

# Integrations & Dependencies

- **Summit Events managed package** — the system of record this layer wraps. Hard dependency;
  the layer reads the package's Event/Instance/Registration/Payment objects and never modifies
  package components.
- **FIU Core web design** — the registration templates load Core's live CSS, JavaScript, and font
  kit. They use pinned Core CSS and JavaScript versions, except `brand-2026.css`, which has no
  version, so a Digital Communications change there reaches these pages automatically.
- **FIU reminder layer** (pre-existing, adjacent): `Summit_Events_Instance_Reminder__c`,
  screen flow `New_Summit_Events_Reminder_Screen`, scheduled flow
  `Summit_Events_Reminders_Schedule_Reminders_CRON`, batch `FIU_SEA_ReminderBatch`. Large-volume
  reminders are sometimes offloaded to Pardot/MCAE.
- **FIU dynamic confirmation email** (pre-existing): subflow
  `SubFlow_FIU_Summit_Event_Reg_Send_Emails`, gated by `Send_Registration_Confirmation_Email__c`.
- **Payment / CyberSource integration** (pre-existing, out of scope to rewrite in Phase 1):
  `summit__Summit_Events_Payment__c`, `FIU_checkout_log__c`, `SPCybersourcePaymentManager` and
  related `SP*` classes, Visualforce `SP_SummitEventsPayment`. This project only surfaces the
  required setup fields more clearly.
- **FIU public website / API & Opportunity creation** — driven by program/plan/business-unit
  values (`FiuProgramFilterService`, `spEventsFIUPlanLookup`) and
  `FIU_Create_Opps_From_Regs__c`.
- **Public file links** — Salesforce ContentDistribution (public URLs for event imagery).

# Known Limitations & Open Decisions

- **FIU Events app is UAT-only.** Built and tested in Partial UAT; the app has **not** been
  deployed to Production. Only the public registration templates are in Production.
- **Phase 1 scope:** guided create/clone/add-instance, browsers, readiness, roster, CSV export.
  Payment internals, advanced reminder routing, and OGI/study-abroad workflows are **Phase 2**.
- **Wizards still being polished** — validation, helper text, and edge-case handling are
  iterating.
- **Single permission set** today; no split between full editor and read-only diagnostic access
  yet.
- **Field/object name resolution is defensive** because Summit object/field API names can vary
  by package version (`summit__Summit_Events__c` vs `summit__Summit_Event__c`, etc.). New orgs
  should be spot-checked.
- **Readiness recalculation is asynchronous** (queueable) — there can be a short lag between a
  change and updated "not ready" counts; governor-limit posture for large event sets is a watch
  item.
- **Reminders at scale** remain a known weak spot in the surrounding FIU architecture
  (offloaded to Pardot/MCAE for large registrant volumes).
- **Registration banner can show the previous event.** The template reads the event from the
  Summit cookie rather than the page address, so someone browsing between events can see the
  last event's title and date until they reload. A first-time visitor has not been tested.
- **Templates are still separate copies.** Only the notice, the floating button, and the layout
  CSS are shared. The head, footer, and custom scripts still live in each of the 16 templates.
- **Testing templates in UAT:** record types limit which templates an event can use, and
  `FIU_Financial_Aid_RSVP_Template` is not in UAT's picklist.

# Revision History

| Date | Commit | Summary of change |
|---|---|---|
| November 4, 2026 | ca393cf | Moved all 16 public registration templates to FIU Core 2026 in Production. Added the required Reasonable Accommodations Policy text as a shared component in Core's Blue - General callout, including 5 templates that had no notice. Added the phone register button, fixed footer links and accessibility gaps, and removed staging references. Corrected the status: the templates are live in Production, and the FIU Events app remains UAT-only. Prod deploys 0AfVr000002sVAXKA2 and 0AfVr000002sVldKAE. |
| June 4, 2026 | a4b6b77 | Initial SDD created. Documents the in-development Phase 1 FIU Events extension layer: app + home dashboard, event-first launcher and guided create/clone/add-instance wizards, clone risk warnings, readiness engine (policy + async recalc), Event/Instance/Registration browsers on a shared list-shell, instance roster/attendance, CSV export, in-app guide, public file link and plan-lookup helpers. Captures Salesforce surface area, the FIU_Events_User permission set, Summit/reminder/payment/email dependencies, and UAT-only status. |
