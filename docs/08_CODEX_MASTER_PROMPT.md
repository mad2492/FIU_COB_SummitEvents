# Codex Master Prompt - FIU Events Extension Layer

You are implementing an FIU-owned extension layer around the Summit Events managed package in Salesforce.

Read the handoff pack files in this folder before doing anything else.

## Absolute Environment Rule
- Learn/discover from **Prod**.
- Build, modify, test, and deploy **only in Partial UAT**.
- Do not push any new code, metadata, configuration changes, or destructive changes to Prod.
- Prod is for discovery and understanding only.

## Absolute Package Rule
- Do **not** modify managed package assets from Summit Events.
- If extra logic is needed, implement it in FIU-owned Apex, LWC, Flow, metadata, app pages, tabs, and permission sets.
- Preserve future upgrade compatibility with Summit Events.

## Read These Files First
1. `00_MASTER_HANDOFF.md`
2. `01_PROJECT_BRIEF.md`
3. `02_ARCHITECTURE_CONSTRAINTS.md`
4. `03_CURRENT_STATE_AND_BUSINESS_RULES.md`
5. `04_PHASED_DELIVERY_PLAN.md`
6. `05_COMPONENT_BACKLOG.md`
7. `06_DISCOVERY_AND_OPEN_QUESTIONS.md`
8. `07_DATA_COLLECTION_TEMPLATE.md`

## Problem to Solve First
FIU users think of an “event” as one thing. Summit Events actually uses:
- a parent Event
- one or more Event Instances

This confusion is the primary UX problem and must be solved first.

## Phase 1 Product Requirement
Build an FIU-owned Event-first entry experience that begins with only these options:
1. Create New Event
2. Clone Existing Event
3. Add New Instance to Existing Event

Each option must include plain-language explanation of when to use it.

## Implementation Priorities
1. Discover exact org-specific business rules from Prod
2. Build FIU Events app shell in Partial UAT
3. Build Event launcher in Partial UAT
4. Build Create New Event guided workflow
5. Build Clone Existing Event guided workflow with warnings and review
6. Build Add New Instance guided workflow
7. Build instance roster/attendance management and CSV export
8. Add readiness/diagnostic indicators for missing setup values

## Discovery Requirements in Prod
Before finalizing data model assumptions, inspect and document:
- active flows touching Summit Event, Event Instance, Registration, Reminder, Payment, and related FIU objects
- Apex classes touching Summit-related business logic
- exact field dependencies on Event and Instance records
- exact behavior of `FIU_Summit_Events_Registration_After_Create_or_Save`
- exact behavior of `SubFlow_FIU_Summit_Event_Reg_Send_Emails`
- exact role of `spEventsFIUPlanLookup`
- exact field/status model of `Summit_Events_Instance_Reminder__c`
- payment-related dependencies around `summit__Summit_Events_Payment__c`, `FIU_checkout_log__c`, `SPCybersourcePaymentManager`, and `SP_SummitEventsPayment`

Record those findings in a discovery note before building assumptions into code.

## Known FIU Business Rules Already Confirmed
At the Summit Event level:
- `summit__Payment_Gateway__c` is required when payment is needed
- `Accounting_Department__c` is required when payment is needed
- `summit__Account__c` must not be blank or external users may hit authorization errors
- `FIU_Create_Opps_From_Regs__c` controls whether registrations should create Opportunities
- `Send_Registration_Confirmation_Email__c` controls whether FIU’s dynamic confirmation email flow should run

Program/plan/business-unit related values are important because they feed FIU website/API behavior and influence Opportunity creation. Review and understand `spEventsFIUPlanLookup`.

## UX Requirements
- Start from the parent Event and guide users downward into the first or next Instance
- Do not force end users to understand managed package architecture to perform common tasks
- Clearly label parent Event data versus Instance data
- Warn users before cloning risky settings such as payment, Opportunity creation, confirmation email behavior, account/business unit/program/plan assignments, and any operationally sensitive values discovered in Prod
- Require review of critical fields before clone completion or activation
- Prefer guided flows/wizards over raw related-list editing

## Suggested Technical Shape
Use FIU-owned assets only. Likely implementation pattern:
- Lightning app: FIU Events
- LWC launcher/home experience
- LWC wizard(s) for create/clone/add-instance
- Apex service layer for discovery, create, clone, validation, and export
- Optional FIU app pages / record page utilities for readiness panels and roster management

## Attendance and Roster Requirement
Provide an FIU-owned instance-focused experience to:
- view registrations/attendance for a given instance
- update attendance naturally
- export attendees to CSV

## Payment Scope Rule
Do not rewrite the CyberSource/SkyPlanner payment engine in Phase 1.
Instead:
- discover the required setup fields and dependencies
- expose the minimum required payment setup values clearly in the FIU workflow
- surface warnings when payment-required setup is incomplete

## Reminder Scope Rule
Do not assume reminder logic can be replaced safely without discovery.
Instead:
- understand current reminder flows, jobs, and batch behavior from Prod
- expose reminder readiness or links where helpful
- defer deeper redesign until dependencies are understood

## OGI / Study Abroad Rule
OGI/study abroad needs are Phase 2 unless their existing dependencies materially affect Phase 1 architecture decisions.

## Delivery Expectations
Produce:
1. discovery notes
2. proposed architecture notes
3. source changes for Partial UAT only
4. test coverage for new Apex as needed
5. user-facing help text and warnings in the UI
6. deployment/readme notes for Partial UAT

## When In Doubt
- Do not touch managed package assets
- Discover from Prod
- Build only in Partial UAT
- Prefer additive FIU-owned solutions
- Preserve Summit package upgradeability
