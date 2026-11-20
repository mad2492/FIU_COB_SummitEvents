# Implementation Run 02 - Summit Program Picker Guardrail

Run date: 2026-05-21

Scope:
- Prevent multiple-program Events from passing readiness when Summit Additional Question 1 is not labeled exactly `Program of Interest`.
- Auto-stamp the required label from the FIU event wizard when users save program routing.
- Keep the change focused on readiness/wizard guardrails only.

Explicitly out of scope:
- Deployment
- Production changes
- Managed package metadata changes
- Rebuilding the Summit question model
- Pagination
- Home KPI optimization
- Public file lifecycle cleanup
- Clone warnings
- Broad permission/FLS hardening

## What Changed

The shared readiness service now includes a hard blocker for multiple-program registrations when Additional Question 1 is not labeled exactly:

`Program of Interest`

This protects the existing Summit registration after-save flow, which only treats Additional Answer 1 as the program/plan value when Additional Question 1 has that exact label.

The FIU event wizard now also stamps `summit__Add_Info_Question_Text_1__c` to `Program of Interest` when program routing is saved from the wizard.

After confirming the production data pattern, the wizard also writes selected Plan names into:

- `summit__Add_Info_Question_Pick_List_Long_1__c`

The values are newline-delimited, matching the observed Summit production configuration. The short picklist field is cleared when the long field is available so stale short-list values do not compete with the long list.

If multiple Plans are not selected at submit time, the wizard clears Question 1 program picker fields so a prior multi-program picker cannot remain on an Event that is now using a single/default Plan path.

## Files Modified

- `force-app/main/default/classes/FiuReadinessPolicyService.cls`
- `force-app/main/default/classes/FiuReadinessPolicyServiceTest.cls`
- `force-app/main/default/classes/FIU_EventsWizardService.cls`
- `force-app/main/default/classes/FiuReadinessRecalcService.cls`
- `force-app/main/default/classes/FiuHomeDashboardService.cls`
- `force-app/main/default/classes/FiuEventBrowserService.cls`
- `force-app/main/default/classes/FiuInstanceBrowserService.cls`
- `force-app/main/default/classes/FiuAppScopeIntegrationTest.cls`

## Readiness Rule Added

New stable issue code:

- `EVENT_PROGRAM_PICKER_LABEL_MISMATCH`
- `EVENT_PROGRAM_PICKER_OPTIONS_MISSING`

Message:

- `Program-routed registrations require Additional Question 1 to be labeled "Program of Interest".`
- `Program-routed registrations require Program of Interest choices in Additional Question 1.`

The blockers apply only when readiness program checks are enabled and `Includes_Multiple_Programs__c = true`.

`EVENT_PROGRAM_PICKER_OPTIONS_MISSING` means the Event is marked as multiple-program, but `summit__Add_Info_Question_Pick_List_Long_1__c` is blank.

## Wizard Behavior Added

When users save program selection through the wizard, Apex sets:

- `summit__Add_Info_Question_Text_1__c = Program of Interest`
- `summit__Add_Info_Question_Pick_List_Long_1__c = selected Plan__c.Name values, separated by newline`

When users submit without multiple selected Plans, Apex clears:

- `summit__Add_Info_Question_Text_1__c`
- `summit__Add_Info_Question_Pick_List_1__c`
- `summit__Add_Info_Question_Pick_List_Long_1__c`

This reduces the chance that a non-technical user creates a visually valid program picker that downstream automation treats as blank.

## Why This Matters

If the label is changed to something like `Enrolled Program`, the registration can still visually store the selected value in Additional Answer 1. However, the downstream flow formula resolves the program name as blank, which can break:

- matching to `Plan__c`
- recruitment interest updates
- program-specific sender routing
- emails that should use `Plan__c.OrgWideEmail__c`

The practical failure mode is that a registration email may fall back to an unintended sender, including the Site User fallback path.

## Tests Added

Updated `FiuReadinessPolicyServiceTest` with coverage for:

- multiple-program Event with mismatched Additional Question 1 label returns `EVENT_PROGRAM_PICKER_LABEL_MISMATCH`
- multiple-program Event with exact `Program of Interest` label does not return the mismatch issue
- multiple-program Event with the exact label but missing long picklist options returns `EVENT_PROGRAM_PICKER_OPTIONS_MISSING`

Updated `FiuAppScopeIntegrationTest` with conditional coverage for:

- wizard program selection writes `Program of Interest`
- wizard program selection writes selected Plan names into `summit__Add_Info_Question_Pick_List_Long_1__c`

## Known Limitations

This pass now populates the Summit Question 1 long picklist from selected `Plan__c.Name` values using newline delimiters.

Future hardening should validate that selected Plans are active, `Type__c = Recruitment`, belong to the Event Account/Department, and have `OrgWideEmail__c` populated when program-specific sender routing is expected.

## How To Validate in UAT

1. Create an Event in the FIU wizard with a Business Unit and Program selected.
2. Save or preview the Event.
3. Confirm Additional Question 1 text on the Event is exactly `Program of Interest`.
4. Confirm Additional Question Pick List Long 1 contains the selected Program names, one per line.
5. Manually change Additional Question 1 text to `Enrolled Program`.
6. Run or trigger readiness recalculation.
7. Confirm the Event no longer appears ready and shows the program picker label blocker.
8. Change the label back to `Program of Interest` and clear the picklist values.
9. Confirm readiness shows the missing options blocker.
10. Restore the newline-delimited Program names.
11. Submit a registration with the program selected and confirm downstream sender routing uses the intended program/Chapman path, not the Site User fallback.

## Recommended Next Implementation Pass

Recommended next pass:

- Plan validation for program routing

Reason:

- The label guardrail prevents the known formula bypass.
- The next highest-risk gap is ensuring selected Plan values are active Recruitment Plans for the Event Account/Department and have sender configuration when program-specific routing is expected.
