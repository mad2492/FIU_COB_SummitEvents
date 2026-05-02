# Discovery and Open Questions

Codex should discover these items from Prod before finalizing implementation details.

## High Priority Discovery
1. Exact required fields on `Summit_Events_Instance__c`
2. Exact required fields on `summit__Summit_Events_Registration__c`
3. Exact branches and downstream actions in `FIU_Summit_Events_Registration_After_Create_or_Save`
4. Exact field model and status workflow on `Summit_Events_Instance_Reminder__c`
5. Exact payment setup dependencies beyond `summit__Payment_Gateway__c` and `Accounting_Department__c`
6. Exact role/permission model for recruiters, admins, event managers, and OGI users
7. Exact usage and importance of `spEventsFIUPlanLookup`
8. Which Event and Instance fields drive FIU website/API visibility

## Discovery Deliverables Codex Should Produce for Itself
- inventory of active flows touching Summit-related objects
- inventory of Apex classes touching Summit-related objects
- field matrix for Event / Instance / Registration / Reminder / Payment-related logic
- current clone-relevant fields and exclusions
- current attendance status handling rules
- current Opportunity creation rules

## Questions Still Open
- Which instance overrides are most common and must be first-class in the wizard?
- Which fields should be copied versus re-confirmed during clone?
- Should the new UI embed `spEventsFIUPlanLookup` or replace it?
- Should payments be shown only when the event is configured as paid?
- Should reminder setup be included directly in the event/instance wizard or remain separate for Phase 1?
- Which user groups should retain access to raw Summit tabs?
