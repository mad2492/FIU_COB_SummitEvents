# FIU Custom Field Inventory (Partial UAT)

Snapshot date: 2026-05-03  
Extraction source: Tooling API `FieldDefinition` in Partial UAT (`cobsf@fiu.edu.prtluatprd`)

Rule used:
- Target Summit Events-related objects
- Include fields with API names ending in `__c`
- Exclude managed package fields with `summit__` prefix

## Object Counts
- `summit__Summit_Events__c`: 11
- `summit__Summit_Events_Instance__c`: 12
- `summit__Summit_Events_Registration__c`: 26
- `Summit_Events_Instance_Reminder__c`: 7
- `summit__Summit_Events_Payment__c`: 0
- `summit__Summit_Events_Question__c`: 0

## Raw Exports
- `docs/discovery/fields_summit_Summit_Events_c.csv`
- `docs/discovery/fields_summit_Summit_Events_Instance_c.csv`
- `docs/discovery/fields_summit_Summit_Events_Registration_c.csv`
- `docs/discovery/fields_Summit_Events_Instance_Reminder_c.csv`
- `docs/discovery/fields_summit_Summit_Events_Payment_c.csv`
- `docs/discovery/fields_summit_Summit_Events_Question_c.csv`

## Sample Confirmed FIU Fields
Event:
- `Accounting_Department__c`
- `Default_Plan__c`
- `FIU_Create_Opps_From_Regs__c`
- `Includes_Multiple_Programs__c`
- `Send_Registration_Confirmation_Email__c`

Instance:
- `Parking_info__c`
- `Instance_Description__c`
- `Campaign_Override__c`
- `Virtual_Meeting_ID__c`
- `Zoom_Recording_Link__c`

Registration:
- `Terms_and_Conditions__c`
- `Payment_Amount__c`
- `Passport_Number__c`
- `Academic_Advising_Status__c`
- `Virtual_Meeting_Password__c`

## Follow-Up Classification
Recommended next pass (same file set):
1. Mark each field as Required, Conditional, or Optional for Phase 1 user journeys.
2. Mark each field as UI-owned, Flow-owned, Apex-owned, or Reporting-only.
3. Identify fields that must be in selective Prod->UAT carryover for realistic validation.
