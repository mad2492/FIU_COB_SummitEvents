# Implementation Run 01 - Shared Readiness Service and Capacity Blocker

Run date: 2026-05-18

Scope:
- Shared readiness policy service
- Capacity readiness blocker
- Minimal integration into existing readiness surfaces
- Apex test coverage for policy and Capacity behavior

Explicitly out of scope:
- Deployment
- Production changes
- Managed package metadata changes
- Pagination
- Home KPI optimization
- Public file lifecycle cleanup
- Clone warnings
- Broad permission/FLS hardening
- LWC redesign

## What Changed

Added a new Apex readiness policy service:

- `FiuReadinessPolicyService`

The service centralizes readiness issue construction and supports:

- Hard blockers
- Soft warning/info structure for future rules
- Stable issue codes
- User-facing messages
- Field API references
- Event-level checks
- Event Instance-level checks
- Parent Event checks for Instance readiness

Existing readiness paths now call the shared service instead of maintaining separate local readiness methods:

- `FiuReadinessRecalcService`
- `FiuHomeDashboardService`
- `FiuEventsReadinessService`

## Files Created

- `force-app/main/default/classes/FiuReadinessPolicyService.cls`
- `force-app/main/default/classes/FiuReadinessPolicyService.cls-meta.xml`
- `force-app/main/default/classes/FiuReadinessPolicyServiceTest.cls`
- `force-app/main/default/classes/FiuReadinessPolicyServiceTest.cls-meta.xml`
- `docs/CodeReviewImplementationPlan/ImplementationRuns/01_Shared_Readiness_Service_And_Capacity_Blocker.md`

## Files Modified

- `force-app/main/default/classes/FiuReadinessRecalcService.cls`
- `force-app/main/default/classes/FiuHomeDashboardService.cls`
- `force-app/main/default/classes/FiuEventsReadinessService.cls`

## Readiness Rules Now Centralized

The shared service now owns these issue definitions:

- Event missing Account
- Event missing Capacity
- Event missing selected Program, when the caller opts into program checks
- Event custom-question page details without related Summit Event Questions
- Event rich-text private image warning/check
- Event with no related Instances, when the caller opts in
- Event with related Instance missing Capacity, when the caller opts in
- Instance not Active
- Instance registration closed
- Instance missing Capacity
- Instance missing location title/address/map/parking
- Parent Event missing Account
- Parent paid Event missing Accounting Department, preserving existing compatibility behavior

This run did not expand paid-event readiness beyond existing compatibility logic.

## Capacity Blocker Behavior

Capacity is treated as a hard blocker when the relevant capacity field is available and the value is:

- `null`
- `0`
- less than `0`
- not parseable as a positive number

Capacity fields used:

- Event: `summit__Capacity__c`, falling back to `Capacity__c` if present
- Event Instance: `summit__Capacity__c`, falling back to `Capacity__c` if present

Reasoning:

- Existing wizard code already resolves these same candidate fields.
- Existing tests and object usage use `summit__Capacity__c`.
- The project documentation calls out Capacity as a readiness showstopper.
- The current data model stores Capacity on both the Event and Instance surfaces, and the wizard copies Event capacity to the first Instance.

## Assumptions from Phase 0 Defaults

The Phase 0 decision packet still shows decisions as pending business review. This implementation used the documented defaults:

- Capacity is a hard blocker.
- Missing or invalid Capacity means the record is not ready.
- Event and Instance readiness should share one issue model.
- Other readiness areas should be supported structurally but not expanded in this pass.

## Tests Added/Updated

Added:

- `FiuReadinessPolicyServiceTest`

Covered scenarios:

- Event with valid Capacity passes the Capacity policy.
- Event with missing Capacity returns `EVENT_MISSING_CAPACITY`.
- Event with zero Capacity returns `EVENT_MISSING_CAPACITY`.
- Event with negative Capacity returns `EVENT_MISSING_CAPACITY`.
- Instance with valid Capacity passes the Capacity policy.
- Instance with missing Capacity returns `INSTANCE_MISSING_CAPACITY`.
- Instance with zero Capacity returns `INSTANCE_MISSING_CAPACITY`.
- Instance with negative Capacity returns `INSTANCE_MISSING_CAPACITY`.
- Event with related Instance missing Capacity returns `EVENT_RELATED_INSTANCE_MISSING_CAPACITY`.
- Null Event/Instance records return structured blocking issues instead of throwing.
- Capacity-only policy evaluation does not run SOQL in bulk-style evaluation.

## How To Validate in UAT

1. Create or identify an Event with missing Capacity.
2. Run or trigger readiness recalculation.
3. Confirm Event readiness reason includes `Missing capacity`.
4. Create or identify an Event Instance with missing or zero Capacity.
5. Run or trigger readiness recalculation.
6. Confirm Instance readiness reason includes `Missing capacity`.
7. Confirm an Event/Instance with positive Capacity does not receive a Capacity-related readiness issue.
8. Confirm existing readiness reasons still display through Home and readiness surfaces.

## Known Limitations

- Phase 0 decisions remain pending; Capacity was implemented using the recommended default.
- Location-type readiness was not changed in this pass.
- Paid Event Payment Gateway and Accounting Department blockers were not expanded in this pass.
- Home KPI query optimization was not part of this pass.
- Public file lifecycle cleanup was not part of this pass.
- Clone warning behavior was not part of this pass.
- Permission/FLS hardening was not part of this pass.
- No deployment or org test execution was performed from this documentation run.

## Recommended Next Implementation Pass

Recommended next pass:

- Paid event validation blockers

Reason:

- The shared readiness policy now exists and can accept the next focused blocker category.
- Paid Event Payment Gateway and Accounting Department are the next highest business-risk readiness blockers after Capacity.
- This keeps the implementation narrow and avoids bundling pagination, public file cleanup, clone warnings, or permissions into the same pass.

