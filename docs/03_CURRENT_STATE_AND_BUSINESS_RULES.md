# Current State and Business Rules

## Core UX Confusion
To typical FIU users, an event is one thing. In Summit architecture, the actual occurrence is an Event Instance beneath a parent Event. This leads to:
- users making a new Event when they really need a new Instance
- poor reuse of prior setup
- difficulty understanding clone behavior

## Product Direction
The future UX should make these actions easy first:
1. Create New Event
2. Clone Existing Event
3. Add New Instance to Existing Event

## Confirmed FIU Business Rules
### Event-level operational fields
- `summit__Payment_Gateway__c` must be set when payment is needed
- `Accounting_Department__c` must be set when payment is needed
- `summit__Account__c` must be set to avoid public-site authorization errors
- `FIU_Create_Opps_From_Regs__c` determines whether registrations should create Opportunities
- `Send_Registration_Confirmation_Email__c` determines whether the dynamic confirmation email flow should run

### Program/Plan/Business Unit significance
The FIU Plan Lookup helper exists because program-related values are critical:
- they feed the FIU website/API for showing upcoming event instances
- they influence downstream Opportunity creation behavior
- users need clearer guidance on their importance

## Reminders
FIU created a custom reminder layer because the Summit package did not provide a sufficient reminder setup UX for their use case.

Known assets:
- `Summit_Events_Instance_Reminder__c`
- `New_Summit_Events_Reminder_Screen`
- `Summit_Events_Reminders_Schedule_Reminders_CRON`
- `FIU_SEA_ReminderBatch`

Known issue:
- reminders can struggle or fail when registrant volume gets large, so FIU sometimes offloads larger reminder work to Pardot/MCAE

## Attendance
Users need a better way to:
- view RSVP/attendance by instance
- update attendance naturally post-event
- export attendee lists to CSV

Current experience is too related-list-heavy and confusing.

## Payments
FIU uses Summit plus FIU-specific CyberSource/payment integration work.

Known integration path:
- `summit__Summit_Events_Payment__c`
- `FIU_checkout_log__c`
- `SPCybersourcePaymentManager` and related `SP*` classes
- Visualforce page `SP_SummitEventsPayment`

Phase 1 should not rewrite payment internals. It should expose minimum required setup values more clearly to users.

## Email Confirmation Logic
FIU does not trust end users to configure Summit Event Email Template objects per event. Instead, FIU uses a robust flow-based dynamic email approach.

Known asset:
- `SubFlow_FIU_Summit_Event_Reg_Send_Emails`

Reason this exists:
- conditional content is needed based on whether an instance is online or in person, and Lightning template options were not sufficient for FIU’s needs

## OGI / Study Abroad
Phase 2 must account for OGI users, who use more of Summit’s native advanced features such as Questions, Emails, and payment-driven registration patterns.
