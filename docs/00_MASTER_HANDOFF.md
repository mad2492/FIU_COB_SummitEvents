# FIU Events - Master Handoff

## Objective
Build an FIU-owned guided user experience on top of the Summit Events managed package so end users can create, clone, manage, and operate events without needing to understand raw package complexity.

The target result is a significantly more intuitive Lightning experience for FIU users that reduces setup errors, prevents broken event configurations, and improves visibility into instances, registrations, attendance, reminders, payments, and Opportunity-creation behavior.

## Critical Delivery Rule
- Use **Prod** only to learn and discover current metadata, automation, field usage, business rules, and working patterns.
- Push **all new code, metadata, configuration, and deployment changes only to Partial UAT**.
- Do **not** modify managed package assets.

## Root UX Problem
FIU users think of an event as a single thing. Summit Events is architected as:
- a parent Event record that serves as a reusable container/template
- one or more Event Instance records that represent the actual occurrence(s)

This mismatch causes users to:
- create unnecessary new parent events
- fail to reuse existing event structures
- misunderstand when to clone versus add an instance
- miss required setup values at the correct level
- produce broken reminder, payment, email, website, or Opportunity outcomes

## Phase 1 Goal
Solve the Event-versus-Instance confusion first with an FIU-owned launcher and guided workflows.

## Primary Entry Experience
Users should begin from an FIU-owned landing experience with only these choices:
1. Create New Event
2. Clone Existing Event
3. Add New Instance to Existing Event

Each option must explain in plain language when to use it.

## Known Existing FIU Assets
### Reminder architecture
- Custom object: `Summit_Events_Instance_Reminder__c`
- Flow scheduler path: `FIU_FlowScheduler` / flow `Summit_Events_Reminders_Schedule_Reminders_CRON`
- Batch Apex: `FIU_SEA_ReminderBatch`
- Screen flow: `New_Summit_Events_Reminder_Screen`
- Screen flow: `Update_Attendees_from_Instance_Screen_Flow`

### Registration automation
- Key record-triggered flow: `FIU_Summit_Events_Registration_After_Create_or_Save`
- Dynamic email subflow: `SubFlow_FIU_Summit_Event_Reg_Send_Emails`

### Payment architecture
- Summit payment object: `summit__Summit_Events_Payment__c`
- FIU logging/integration object: `FIU_checkout_log__c`
- Key class family begins with `SPCybersourcePaymentManager`
- Visualforce page: `SP_SummitEventsPayment`
- SkyPlanner-delivered payment work is largely out of scope to rewrite; expose minimum setup fields more clearly instead

### Existing FIU helper UI
- LWC: `spEventsFIUPlanLookup`
- Purpose: guide users to select business unit / plans / related program values used by FIU website/API and Opportunity-creation logic

## Confirmed Critical Event-Level Fields
| Object | Field API | Why it matters |
|---|---|---|
| Summit Event | `summit__Payment_Gateway__c` | Required when payment is needed |
| Summit Event | `Accounting_Department__c` | Required when payment is needed |
| Summit Event | `summit__Account__c` | If blank, external users can hit authorization errors |
| Summit Event | `summit__Capacity__c` | Must be populated and greater than zero; blank/zero capacity breaks public registration behavior and must block preview/create |
| Summit Event | `FIU_Create_Opps_From_Regs__c` | Controls whether registrations should create Opportunities |
| Summit Event | `Send_Registration_Confirmation_Email__c` | Controls whether FIU’s dynamic confirmation email flow should run |

## Desired Future Capabilities
- Browse Events by status, program, and upcoming instance activity
- Browse Events and Instances in a shared FIU list-shell experience with right-side quick view
- Guided event creation
- Robust clone event experience with warnings
- Guided add-instance experience
- In-app Guide page that teaches the Event -> Instance -> Registration model
- Easier RSVP/attendance viewing by instance
- CSV export of attendees
- Natural post-event attendance updating
- Better visibility into reminder and payment readiness
- Reduced reliance on raw related lists and managed package tabs for end users

## Delivery Strategy
1. Discover and document business rules from Prod
2. Build FIU-owned app shell, tabs, and landing pages in Partial UAT
3. Build guided Event-first workflows
4. Add operational views and attendance tools
5. Defer OGI and advanced Summit feature parity to Phase 2

## Explicit Non-Goals for Initial Build
- Rewriting Summit managed package behavior
- Modifying managed package components or metadata
- Replacing payment engine internals in Phase 1
- Replacing all existing automation before understanding dependencies
