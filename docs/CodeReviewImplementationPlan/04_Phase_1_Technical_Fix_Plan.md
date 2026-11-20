# Phase 1 - Technical Fix Plan

Phase 1 implementation item count: 10

## P1-001 Shared Readiness Policy Service

Objective: Create one Apex policy service that evaluates Event and Instance readiness consistently.

Current risk: Readiness is split across wizard validation, recalculation, Home KPI logic, browser buckets, and documentation.

Recommended technical approach:
- Add a proposed new Apex class `FiuReadinessPolicyService`.
- Return structured results: status, blocking reasons, warning reasons, and normalized reason codes.
- Support Event-level and Instance-level evaluation.
- Keep policy configurable enough to handle optional fields with describe/resolver helpers.
- Have `FiuReadinessRecalcService`, `FiuHomeDashboardService`, and wizard save/preview logic call the policy rather than duplicating checks.

Files likely involved:
- `force-app/main/default/classes/FiuReadinessRecalcService.cls`
- `force-app/main/default/classes/FiuHomeDashboardService.cls`
- `force-app/main/default/classes/FiuEventsReadinessService.cls`
- `force-app/main/default/classes/FIU_EventsWizardService.cls`

New files likely needed:
- Proposed New File: `FiuReadinessPolicyService.cls`
- Proposed New File: `FiuReadinessPolicyServiceTest.cls`

Existing files likely modified:
- Readiness recalculation service, Home dashboard service, wizard service, readiness endpoint.

Test requirements:
- Missing Account, capacity, payment gateway, accounting department, Instance, date/time, virtual link, physical location details.
- Event and Instance policy methods.

Acceptance criteria:
- All readiness surfaces return the same blocker reasons for the same records.
- Missing Capacity is a blocker.
- Tests cover paid and unpaid, physical and virtual cases.

Rollback notes:
- Keep old readiness helper methods until policy is proven, then remove duplicates in a later refactor.

## P1-002 Capacity, Paid Event, and Location Blockers

Objective: Implement the highest-risk readiness blockers in the shared policy and UI messaging.

Current risk: Missing capacity/payment/location rules can be bypassed or inconsistently reported.

Recommended technical approach:
- Treat capacity <= 0 or null as a blocker.
- Treat paid event without Payment Gateway or Accounting Department as a blocker.
- Branch location requirements by location type.
- Keep LWC client-side validation as fast feedback, but Apex must be authoritative.

Files likely involved:
- `FiuReadinessPolicyService.cls`
- `FiuReadinessRecalcService.cls`
- `FiuHomeDashboardService.cls`
- `FIU_EventsWizardService.cls`
- `fiuEventCreateWizard`
- `fiuInstanceCreateWizard`

New files likely needed:
- None beyond P1-001.

Existing files likely modified:
- Wizard Apex/LWC validation and readiness recalculation.

Test requirements:
- Paid missing gateway/accounting.
- Free/unpaid event does not require payment fields.
- Online event does not require map/address/parking.
- Physical/offsite event requires logistics fields.

Acceptance criteria:
- Readiness reason text is clear to nontechnical users.
- Capacity missing appears as a blocker everywhere readiness is shown.

Rollback notes:
- Policy can be feature-switched by preserving old readiness status fields until UAT sign-off.

## P1-003 Instance Browser Cursor Pagination

Objective: Remove scale-limited fallback pagination for Instance Browser.

Current risk: Search and Unpublished modes use row-limited Apex filtering.

Recommended technical approach:
- Define cursor payload with primary sort value, secondary tie-breaker, and `Id`.
- Move Unpublished/readiness predicates into SOQL using stored readiness fields.
- For search, keep deterministic sort and return `pageSize + 1` rows to compute `hasNext`.
- Update LWC/list shell to consume cursor/hasNext instead of page-number totals where needed.

Files likely involved:
- `FiuInstanceBrowserService.cls`
- `FiuInstanceBrowserServiceTest.cls`
- `fiuInstanceBrowser`
- `fiuListShell`

New files likely needed:
- Proposed New File: `FiuCursorPage.cls` or inner DTO/helper if reusable.

Existing files likely modified:
- Instance browser service and LWC.

Test requirements:
- Default, search, Unpublished, program, record type, duplicate date/order cases.

Acceptance criteria:
- No `LIMIT 10000` fallback for search/unpublished list paths.
- Stable next-page cursor behavior.

Rollback notes:
- Keep DTO compatibility where possible and hide page counts if exact counts are removed.

## P1-004 Registration Browser Cursor Pagination

Objective: Convert Registration Browser from page-number/StandardSetController pagination to cursor pagination.

Current risk: Large registration volumes can be slow, miscounted, or expensive.

Recommended technical approach:
- Reuse cursor contract from Instance Browser.
- Use stable default ordering such as CreatedDate DESC, Id DESC.
- Apply all filters in SOQL: record type, program, instance, status, location type, search.
- Return `hasNext`; make exact total optional or approximate.

Files likely involved:
- `FiuRegistrationBrowserService.cls`
- `fiuRegistrationBrowser`
- `fiuListShell`

New files likely needed:
- Shared cursor helper if not already created in P1-003.

Existing files likely modified:
- Registration browser service and LWC.

Test requirements:
- Cursor paging under filters, duplicate sort values, no-access record type, status filters, search filters.

Acceptance criteria:
- `ApexPages.StandardSetController` is no longer used for Registration Browser listing.
- LWC navigates forward predictably and shows clear count/hasNext behavior.

Rollback notes:
- Keep current mass update method separate from listing refactor to reduce blast radius.

## P1-005 Home KPI Aggregate Counts

Objective: Remove 10,000-row KPI truncation risk.

Current risk: Home KPIs are computed from row-limited queries and can under-report.

Recommended technical approach:
- Use aggregate/count queries for KPI numbers.
- Use readiness status fields or shared policy-derived fields where possible.
- Query only a small attention list for display rows.
- Consider summary object later if aggregate filters become too complex.

Files likely involved:
- `FiuHomeDashboardService.cls`
- `fiuEventsHome`
- `FiuAppScopeIntegrationTest.cls`

New files likely needed:
- None initially.

Existing files likely modified:
- Home dashboard service and tests.

Test requirements:
- Counts not tied to limited row list.
- Record type/program scope filters still apply.
- Preview records excluded.

Acceptance criteria:
- No active Event/Instance KPI query depends on `LIMIT 10000`.
- KPI and attention list behavior are separately tested.

Rollback notes:
- Keep old row DTO mapping for attention rows; change only count calculation first.

## P1-006 Scheduled Preview Cleanup

Objective: Give preview records a reliable lifecycle.

Current risk: Preview records are cleaned only during preview creation.

Recommended technical approach:
- Add scheduled/batch Apex that deletes expired preview Instances and Events by `Preview_Expires_At__c`.
- Exclude non-preview records defensively.
- Log failures in debug/admin-visible mechanism available in the org.
- Keep inline cleanup as best-effort, but not the only cleanup path.

Files likely involved:
- `FIU_EventsWizardService.cls`
- Preview fields on Event/Instance

New files likely needed:
- Proposed New File: `FiuPreviewCleanupJob.cls`
- Proposed New File: `FiuPreviewCleanupJobTest.cls`

Existing files likely modified:
- Wizard service only if helper methods are extracted or reused.

Test requirements:
- Expired previews deleted.
- Non-expired previews retained.
- Non-preview records retained.
- Instance cleanup occurs before/with Event cleanup safely.

Acceptance criteria:
- Scheduled class exists and can be scheduled in UAT.
- Preview cleanup behavior is tested without relying on org data.

Rollback notes:
- Schedule can be paused; code can remain inert if no schedule exists.

## P1-007 Public File Lifecycle Controls

Objective: Make public image/file creation safe enough for production.

Current risk: Current service can create public links without enough format/lifecycle guardrails.

Recommended technical approach:
- Enforce allowlist for image content types/extensions.
- Block SVG unless business/security explicitly approves.
- Add size limits.
- Store enough metadata to identify app-created public distributions.
- Add revoke/cleanup method if feasible.

Files likely involved:
- `FiuPublicFileService.cls`
- `FiuPublicFileServiceTest.cls`
- `fiuEventCreateWizard`
- Custom permission metadata if split is needed

New files likely needed:
- Optional Proposed New File: custom metadata/object for public asset tracking, only if approved.

Existing files likely modified:
- Public file service, tests, and wizard error messaging.

Test requirements:
- Supported image succeeds.
- Unsupported type fails.
- SVG blocked.
- Oversized payload fails.
- User without custom permission fails.

Acceptance criteria:
- Public link creation is limited to approved formats and authorized users.
- User-facing errors explain how to fix image issues.

Rollback notes:
- New restrictions can be staged behind clear validation messages before enforcing on old content.

## P1-008 Permission/FLS Hardening

Objective: Define and implement a consistent security approach for custom Apex and metadata.

Current risk: `with sharing` is present, but FLS/CRUD handling is inconsistent.

Recommended technical approach:
- Use `Security.stripInaccessible` for DTO responses where user-mode SOQL is impractical.
- Use user-mode DML where package constraints allow.
- Split sensitive operations into custom permissions: public files, export, admin cleanup/readiness override if needed.
- Make system-owned readiness/preview fields read-only for normal users.

Files likely involved:
- Apex services returning LWC DTOs
- `FIU_Events_User.permissionset-meta.xml`
- Custom permissions

New files likely needed:
- Optional proposed custom permissions for export/admin actions.

Existing files likely modified:
- High-risk Apex services first: public files, exports, wizard, browsers.

Test requirements:
- `System.runAs` app user.
- User without public file permission.
- User without record type access.
- Restricted field behavior where testable.

Acceptance criteria:
- Sensitive actions check custom permissions.
- DTOs do not intentionally expose inaccessible fields.
- Normal app users cannot edit preview/readiness fields directly.

Rollback notes:
- Metadata permission changes should be deployable separately from Apex changes.

## P1-009 Registration Reassignment Guardrails

Objective: Prevent Event/Instance mismatches in registration mass update.

Current risk: Event-only update remains possible with only a warning.

Recommended technical approach:
- Default UI should expose Instance reassignment, not Event-only reassignment.
- Apex should derive Event from selected Instance.
- Event-only update should require admin custom permission or explicit confirmation token.

Files likely involved:
- `FiuRegistrationBrowserService.cls`
- `fiuRegistrationBrowser`
- `FiuRegistrationBrowserService` tests

New files likely needed:
- Optional custom permission for Event-only reassignment.

Existing files likely modified:
- Registration browser service/LWC.

Test requirements:
- Instance-only update aligns Event.
- Event-only update blocked for normal user.
- Mismatched Event + Instance throws error.
- Admin override works only if approved.

Acceptance criteria:
- Standard users cannot create mismatch via mass update.
- Warning copy is replaced by prevention or explicit confirmation.

Rollback notes:
- Keep existing server validation for mismatched explicit Event/Instance values.

## P1-010 High-Priority Test Expansion

Objective: Add tests that protect all Phase 1 behavior.

Current risk: Existing tests are helpful but do not yet cover enough negative/security/scale paths.

Recommended technical approach:
- Add targeted Apex tests alongside each changed service.
- Add Jest tests for LWC validation, scope, pagination, and mass update where project Jest setup supports it.
- If Jest setup is missing, create setup as a separate approved task or document manual QA coverage.

Files likely involved:
- Existing Apex test classes
- New test classes from P1 items
- LWC `__tests__` folders if Jest is configured

New files likely needed:
- `FiuReadinessPolicyServiceTest.cls`
- `FiuPreviewCleanupJobTest.cls`
- Additional LWC test files

Existing files likely modified:
- Existing test classes for browser/public file/readiness coverage.

Test requirements:
- Paid events, public files, readiness, registration reassignment, scale, permission, timezone/date.

Acceptance criteria:
- Phase 1 code has meaningful assertions for positive and negative paths.
- Tests avoid org data.

Rollback notes:
- Test-only changes can be adjusted independently if managed package test setup needs factory tuning.

