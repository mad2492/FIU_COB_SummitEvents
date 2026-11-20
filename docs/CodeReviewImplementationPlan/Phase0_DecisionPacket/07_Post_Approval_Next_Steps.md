# Post-Approval Next Steps

## After Decisions Are Approved

1. Update the decision log with approved defaults or approved alternatives.
2. Record approver name, date, and any notes in the approval form or governance notes.
3. Update the implementation backlog if a recommended default changes.
4. Start with the narrowest coding pass: shared readiness policy service plus Capacity blocker only.
5. Do not bundle pagination, KPI optimization, public file cleanup, clone warnings, or permission/FLS hardening into the first coding pass.

## Next Codex Implementation Prompt

Use this prompt after business approval:

```markdown
Implement the shared readiness policy service and Capacity blocker only. Do not implement pagination, KPI optimization, public file cleanup, clone warnings, or permission/FLS hardening in this pass.
```

## Recommended First Code Implementation Pass

Scope:
- Add shared readiness policy service.
- Implement Capacity missing/zero blocker.
- Wire the Capacity blocker into existing readiness recalculation and readiness-facing surfaces as narrowly as possible.
- Add tests for Capacity readiness behavior.

Do not include:
- Instance Browser pagination.
- Registration Browser pagination.
- Home KPI optimization.
- Public file lifecycle cleanup.
- Clone warnings.
- Permission/FLS hardening.
- Flow changes.
- Managed package metadata changes.
- Deployment.

## Files to Update After Approval

Documentation:
- `docs/CodeReviewImplementationPlan/Phase0_DecisionPacket/02_Decision_Log.md`
- `docs/CodeReviewImplementationPlan/Phase0_DecisionPacket/04_Stakeholder_Approval_Form.md`
- `docs/CodeReviewImplementationPlan/02_Prioritized_Backlog.md`, if decisions change priority/scope
- `docs/CodeReviewImplementationPlan/07_UAT_Readiness_Checklist.md`, if UAT expectations change

First coding pass likely files:
- Proposed New File: `force-app/main/default/classes/FiuReadinessPolicyService.cls`
- Proposed New File: `force-app/main/default/classes/FiuReadinessPolicyService.cls-meta.xml`
- Proposed New File: `force-app/main/default/classes/FiuReadinessPolicyServiceTest.cls`
- Proposed New File: `force-app/main/default/classes/FiuReadinessPolicyServiceTest.cls-meta.xml`
- `force-app/main/default/classes/FiuReadinessRecalcService.cls`
- `force-app/main/default/classes/FiuHomeDashboardService.cls`
- `force-app/main/default/classes/FiuEventsReadinessService.cls`

Only modify wizard/LWC files in the first coding pass if Capacity messaging cannot otherwise be surfaced clearly.

## UAT Validation Order

1. Validate Capacity blocker on an Event with missing Capacity.
2. Validate Capacity blocker on an Event with zero Capacity.
3. Validate ready behavior when Capacity is greater than zero and other currently supported checks pass.
4. Validate readiness reason text is understandable to a nontechnical user.
5. Validate existing Event/Instance creation workflows still work.
6. Validate preview records are not accidentally affected by the Capacity-only pass unless explicitly intended.
7. Validate record type/program scope still behaves as before.

## Production Readiness Considerations

The first coding pass does not make the app fully production-ready by itself. It establishes the shared readiness policy foundation and addresses the most immediate documented blocker: Capacity.

Before production, the team should still complete:
- Paid Event blockers.
- Location-type readiness rules.
- Cursor pagination for Instance and Registration browsers.
- Home KPI aggregate counts.
- Public file lifecycle/security controls.
- Preview cleanup job.
- Permission/FLS hardening.
- Reminder/Pardot data consistency policy and implementation.
- UAT regression and stakeholder signoff.

## Documentation After First Code Pass

After the first code pass, update:
- The decision packet status if implementation reveals a business-rule ambiguity.
- The UAT checklist with exact Capacity test steps.
- The implementation backlog to mark Capacity-related work complete or partially complete.
- Any release notes for Partial UAT validation.

