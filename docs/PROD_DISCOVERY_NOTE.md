# Prod Discovery Note - FIU Events Phase 1

Date: 2026-05-02
Source Org Alias: `Prod`

## Active Automation Inventory (event-related)
Captured from Tooling API query and stored at:
- `docs/discovery/prod_active_flows.json`
- `docs/discovery/prod_event_related_apex_classes.json`

Confirmed active flows include:
- FIU Summit Events Registration - After Create
- SubFlow - FIU Summit Event Reg Send Emails
- New Summit Events Reminder Screen
- Summit Events Reminder Emails
- Summit Events Reminders - Schedule Reminders ApexScheduler
- Event Registration Updated - After Save
- Summit Events Payment Received - After Save

## Required-field snapshot from object describe
Stored at:
- `docs/discovery/prod_required_instance_fields.json`
- `docs/discovery/prod_required_registration_fields.json`

Instance required at create-time includes:
- `summit__Event__c`
- `summit__Attendee_List__c`
- `summit__Private_Instance__c`

Registration required at create-time includes:
- `summit__Event_Instance__c`
- boolean defaults/flags such as attendance/public-display/new-contact/new-lead reminders and terms fields

## Notes and limitations
- Tooling `Flow` query returns active flow names and process type, but exact branch logic still requires metadata retrieval of each named flow version.
- `FieldDefinition` query path is restricted in this org for this object set; `sobject describe` was used instead.
- This repo now includes FIU-owned Phase 1 scaffolding in `force-app/main/default` with no managed package edits.
