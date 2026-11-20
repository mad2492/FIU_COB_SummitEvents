# Staged Codex Implementation Prompts

Use these prompts one at a time after implementation is approved. Every prompt intentionally says do not deploy and do not modify managed package metadata.

## Prompt 1 - Phase 0 Decision Documentation Only

Scope: Document business decisions needed before implementation. Do not change code.

Files to inspect first:
- `docs/CodeReviewImplementationPlan/03_Phase_0_Business_Decisions.md`
- `docs/CodeReviewImplementationPlan/02_Prioritized_Backlog.md`
- `docs/CodeReview/06_Stakeholder_Facing_Governance_Notes.md`

Files likely to modify:
- A new or existing governance/decision markdown file under `docs/`

Instructions:
- Do not deploy anything.
- Do not modify managed package metadata.
- Do not change code behavior.
- Convert Phase 0 decisions into a concise stakeholder sign-off document.

Required test expectations:
- No tests required; documentation-only.

Required documentation update expectations:
- Link each decision to related backlog IDs.

Expected final summary:
- Files created/modified.
- Number of decisions documented.
- Decisions still unresolved.

## Prompt 2 - Shared Readiness Policy Service

Scope: Implement the shared Apex readiness policy service.

Files to inspect first:
- `FiuReadinessRecalcService.cls`
- `FiuHomeDashboardService.cls`
- `FiuEventsReadinessService.cls`
- `FIU_EventsWizardService.cls`
- `docs/CodeReviewImplementationPlan/04_Phase_1_Technical_Fix_Plan.md`

Files likely to modify:
- `FiuReadinessRecalcService.cls`
- `FiuHomeDashboardService.cls`
- `FiuEventsReadinessService.cls`
- `FIU_EventsWizardService.cls`

Files likely to add:
- `FiuReadinessPolicyService.cls`
- `FiuReadinessPolicyServiceTest.cls`

Instructions:
- Do not deploy anything.
- Do not modify managed package metadata.
- Keep managed package boundaries intact.
- Implement policy in a way that handles optional fields through describes/resolvers.

Required test expectations:
- Missing Account, missing Capacity, paid missing Payment Gateway, paid missing Accounting Department, physical missing logistics, virtual missing meeting details.

Required documentation update expectations:
- Update implementation notes with policy reason codes and any assumptions.

Expected final summary:
- Files changed.
- Policy checks implemented.
- Tests run/results.
- Remaining business-rule assumptions.

## Prompt 3 - Capacity Blocker

Scope: Ensure Capacity missing or <= 0 is treated as a blocker everywhere readiness appears.

Files to inspect first:
- `FiuReadinessPolicyService.cls`
- `FiuReadinessRecalcService.cls`
- `FiuHomeDashboardService.cls`
- `FIU_EventsWizardService.cls`
- `fiuEventCreateWizard`

Files likely to modify:
- Readiness policy/service callers and wizard validation/messages.

Instructions:
- Do not deploy anything.
- Do not modify managed package metadata.
- Keep UX copy clear for nontechnical users.

Required test expectations:
- Capacity null, zero, negative, and positive cases.

Required documentation update expectations:
- Update readiness rules documentation.

Expected final summary:
- Files changed.
- Capacity scenarios covered.
- Tests run/results.

## Prompt 4 - Instance Browser Pagination

Scope: Convert remaining Instance Browser search and Unpublished modes to true cursor/keyset pagination.

Files to inspect first:
- `FiuInstanceBrowserService.cls`
- `FiuInstanceBrowserServiceTest.cls`
- `fiuInstanceBrowser`
- `fiuListShell`

Files likely to modify:
- `FiuInstanceBrowserService.cls`
- `FiuInstanceBrowserServiceTest.cls`
- `fiuInstanceBrowser` JS/HTML if cursor contract changes
- `fiuListShell` if shared paging UI changes

Instructions:
- Do not deploy anything.
- Do not modify managed package metadata.
- Avoid broad UI rewrites.
- Preserve record type/program scope behavior.

Required test expectations:
- Default, search, Unpublished, duplicate sort values, program scope, record type scope.

Required documentation update expectations:
- Update implementation notes with cursor contract.

Expected final summary:
- Files changed.
- Old pagination fallback removed or remaining exceptions.
- Tests run/results.

## Prompt 5 - Registration Browser Pagination

Scope: Convert Registration Browser listing from page-number/StandardSetController pagination to cursor pagination.

Files to inspect first:
- `FiuRegistrationBrowserService.cls`
- `fiuRegistrationBrowser`
- `fiuListShell`
- `docs/CodeReviewImplementationPlan/04_Phase_1_Technical_Fix_Plan.md`

Files likely to modify:
- `FiuRegistrationBrowserService.cls`
- `fiuRegistrationBrowser`
- `fiuListShell`
- related tests

Instructions:
- Do not deploy anything.
- Do not modify managed package metadata.
- Keep mass update behavior separate unless explicitly included.

Required test expectations:
- Cursor paging, filters, search, duplicate sort values, no-access scope.

Required documentation update expectations:
- Update cursor contract notes and UAT checklist if behavior changes.

Expected final summary:
- Files changed.
- Paging behavior before/after.
- Tests run/results.

## Prompt 6 - Home KPI Performance Fix

Scope: Replace Home KPI row-limited scans with aggregate or summary-based counts.

Files to inspect first:
- `FiuHomeDashboardService.cls`
- `fiuEventsHome`
- `FiuAppScopeIntegrationTest.cls`

Files likely to modify:
- `FiuHomeDashboardService.cls`
- Related tests

Instructions:
- Do not deploy anything.
- Do not modify managed package metadata.
- Keep attention rows separate from KPI counts.

Required test expectations:
- KPI counts not tied to returned row limit, scope filters apply, preview records excluded.

Required documentation update expectations:
- Document KPI definitions and any count limitations.

Expected final summary:
- Files changed.
- KPI query strategy.
- Tests run/results.

## Prompt 7 - Public File Lifecycle and Scheduled Preview Cleanup

Scope: Harden public file handling and add scheduled preview cleanup.

Files to inspect first:
- `FiuPublicFileService.cls`
- `FiuPublicFileServiceTest.cls`
- `FIU_EventsWizardService.cls`
- preview field metadata
- `fiuEventCreateWizard`

Files likely to modify:
- `FiuPublicFileService.cls`
- `FiuPublicFileServiceTest.cls`
- `FIU_EventsWizardService.cls` if helper extraction is needed
- `fiuEventCreateWizard` messages if needed

Files likely to add:
- `FiuPreviewCleanupJob.cls`
- `FiuPreviewCleanupJobTest.cls`

Instructions:
- Do not deploy anything.
- Do not modify managed package metadata.
- Do not make public file behavior broader than approved.

Required test expectations:
- Allowed image types, unsupported type rejection, SVG policy, permission denial, expired preview cleanup, non-preview protection.

Required documentation update expectations:
- Document public file allowlist, preview retention, and cleanup schedule.

Expected final summary:
- Files changed/added.
- Security controls added.
- Tests run/results.

## Prompt 8 - Permission/FLS Hardening

Scope: Apply least-privilege and FLS/CRUD strategy to highest-risk custom Apex and permission metadata.

Files to inspect first:
- `FIU_Events_User.permissionset-meta.xml`
- `FiuPublicFileService.cls`
- `ExportCsvController.cls`
- browser services
- wizard services

Files likely to modify:
- Permission set/custom permissions
- High-risk Apex services
- Tests

Instructions:
- Do not deploy anything.
- Do not modify managed package metadata.
- Keep app users functional while limiting sensitive actions.

Required test expectations:
- User without public file permission, standard app user, restricted record type/scope, export permission if implemented.

Required documentation update expectations:
- Document permission model and any manual assignment steps.

Expected final summary:
- Files changed.
- Permission boundaries implemented.
- Tests run/results.

## Prompt 9 - Test Coverage Expansion

Scope: Add missing Apex and Jest tests for the production-risk areas.

Files to inspect first:
- `docs/CodeReviewImplementationPlan/05_Test_Implementation_Backlog.md`
- Existing Apex test classes
- LWC folders

Files likely to modify:
- Existing test classes
- New Apex test classes
- New LWC Jest tests if project setup supports them

Instructions:
- Do not deploy anything.
- Do not modify managed package metadata.
- Do not change production code unless a test exposes an already-approved defect and the user explicitly approves a fix.

Required test expectations:
- Paid events, readiness, public files, pagination, registration reassignment, permissions, scale, timezone/date.

Required documentation update expectations:
- Mark test backlog items completed/remaining.

Expected final summary:
- Tests added/modified.
- Test command results.
- Remaining untested risks.

## Prompt 10 - Final Regression and Documentation Update

Scope: Run final review of implemented changes, update docs, and prepare UAT validation notes.

Files to inspect first:
- `docs/CodeReviewImplementationPlan/07_UAT_Readiness_Checklist.md`
- changed source files
- test results

Files likely to modify:
- UAT checklist/status docs
- Release/deployment notes

Instructions:
- Do not deploy anything.
- Do not modify managed package metadata.
- Do not modify Production.
- Summarize what is ready for Partial UAT validation.

Required test expectations:
- Run relevant Apex tests and LWC/Jest tests available locally.

Required documentation update expectations:
- Update UAT checklist, implementation notes, and remaining risk list.

Expected final summary:
- Files changed.
- Tests run/results.
- UAT-ready items.
- Remaining blockers.

