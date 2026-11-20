# Test Implementation Backlog

Test item count: 28

## Apex Tests

| Test ID | Related finding/backlog ID | Purpose | Scenario | Expected result | Data setup notes | Priority |
|---|---|---|---|---|---|---|
| T-001 | CR-001 / BL-001 | Validate shared readiness policy. | Event missing Account, capacity, Instance, or date/time. | Policy returns blocker reason codes and Not Ready status. | Use test factory for Account, Event, Instance. | Critical |
| T-002 | CR-001 / BL-001 | Validate paid event blockers. | Paid Event missing Payment Gateway and/or Accounting Department. | Policy blocks readiness with payment-specific reasons. | Use available payment indicator fields/options from describe. | Critical |
| T-003 | CR-005 / BL-002 | Validate physical readiness. | Physical/offsite Instance missing address/map/building/parking. | Policy blocks physical logistics only for physical types. | Create Instance with location type override. | High |
| T-004 | CR-005 / BL-002 | Validate virtual readiness. | Online/virtual Instance with meeting link but no physical address/map. | Policy does not require physical fields. | Use location type values available in org/package. | High |
| T-005 | CR-006 / BL-010 | Validate stale readiness recovery. | Related data changes after Event/Instance readiness was calculated. | Scheduled or triggered reconciliation updates readiness. | Depends on selected stale-data implementation. | High |
| T-006 | CR-002 / BL-005 | Protect Home KPI count path. | Create enough test data to prove count is not tied to returned attention rows. | KPI count and attention row list are calculated separately. | Use small injected/testable threshold if needed. | High |
| T-007 | CR-003 / BL-003 | Instance cursor default path. | Fetch first and next pages with duplicate dates. | No duplicates or skipped rows; `hasNext` correct. | Create Instances with same start dates and different Ids. | High |
| T-008 | CR-003 / BL-003 | Instance cursor search path. | Search term matches records across multiple pages. | Cursor pages all matching records without 10,000-row fallback. | Names with stable prefixes/suffixes. | High |
| T-009 | CR-003 / BL-003 | Instance cursor Unpublished path. | Filter by Unpublished/readiness bucket. | SOQL-filtered cursor returns expected records. | Set readiness fields directly where appropriate. | High |
| T-010 | CR-004 / BL-004 | Registration cursor pagination. | Multiple pages of registrations with duplicate sort values. | Cursor returns stable pages and `hasNext`. | Create Event, Instance, Contacts/Registrations. | High |
| T-011 | CR-004 / BL-004 | Registration filter combinations. | Status, instance, location type, program, and search filters. | Filtered results are correct and stable. | Include program fields and varied statuses. | High |
| T-012 | CR-012 / BL-009 | Registration reassignment guard. | Normal user attempts Event-only mass update. | Update is blocked or requires approved confirmation. | Use `System.runAs` where practical. | High |
| T-013 | CR-012 / BL-009 | Registration Instance reassignment. | User selects new Instance only. | Registration Event is aligned to selected Instance parent. | Create two Events/Instances. | High |
| T-014 | CR-007 / BL-007 | Preview cleanup deletes expired previews. | Expired preview Event/Instance records exist. | Job deletes only expired preview records. | Set preview fields and expiration dates. | High |
| T-015 | CR-007 / BL-007 | Preview cleanup protects real records. | Non-preview or non-expired records match some date conditions. | Records are retained. | Include false/null preview flags. | High |
| T-016 | CR-008 / BL-006 | Public file allowed type. | PNG/JPG ContentVersion or base64 upload. | Public result is returned. | Create ContentVersion in test. | High |
| T-017 | CR-008 / BL-006 | Public file unsupported type. | PDF/TXT/SVG or unsupported content type. | AuraHandledException/user-safe error. | Use ContentVersion metadata and base64 method. | High |
| T-018 | CR-008 / BL-006 | Public file permission denial. | User without custom permission calls service. | Service rejects request. | Use `System.runAs`; assign no custom permission. | High |
| T-019 | CR-014 / BL-008 | FLS-safe DTO behavior. | Restricted user queries browser/home service. | Service strips or omits inaccessible fields, or returns friendly error. | Salesforce test FLS limits may require custom permission/profile strategy. | High |
| T-020 | CR-029 / BL-018 | No-access/deleted record errors. | Readiness service called for record user cannot access or nonexistent Id. | Friendly `AuraHandledException` or structured error. | Use sharing/record type scoping where practical. | Medium |
| T-021 | CR-025 / BL-024 | Queueable debounce/bulk. | Bulk update many Events/Instances. | Recalc does not exceed queueable limit. | Use Test.startTest/stopTest. | Medium |
| T-022 | CR-013 / BL-012 | Roster export cap behavior. | Roster exceeds synchronous cap. | Export warns/blocks/routes async, not silent truncation. | Use manageable test cap/injected value. | Medium |
| T-023 | CR-016 / BL-021 | Program option source. | Program exists in Plan metadata/source but few Events use it. | Option still appears if implementation changes source. | Create Plan records. | Medium |
| T-024 | Failure scenarios | Timezone/DST handling. | Instance starts around DST transition. | Dates/times are stored/displayed consistently. | Use fixed dates around DST boundaries. | Medium |

## LWC/Jest Tests

| Test ID | Related finding/backlog ID | Purpose | Scenario | Expected result | Data setup notes | Priority |
|---|---|---|---|---|---|---|
| JT-001 | CR-011 / BL-020 | Wizard readiness validation UX. | Missing capacity and paid fields. | User sees clear field-level/global messages and cannot proceed. | Mock Apex init data/options. | High |
| JT-002 | CR-024 / BL-017 | Public image repair UX. | Private image warning and successful conversion. | Warning clears after public image creation. | Mock `FiuPublicFileService`. | High |
| JT-003 | CR-003 / BL-003 | Instance Browser cursor UX. | User clicks next page with cursor. | LWC sends cursor and renders next page. | Mock Apex result with `hasNext`. | High |
| JT-004 | CR-004 / BL-004 | Registration Browser cursor UX. | Cursor paging under status/search filters. | Filter changes reset cursor; next page uses returned token. | Mock Apex result. | High |
| JT-005 | CR-012 / BL-009 | Registration mass update UX. | Event-only update attempted by normal user. | UI blocks or requires approved confirmation. | Mock selected rows and permissions. | High |
| JT-006 | CR-026 / BL-028 | Scope persistence. | Record type and program selected on Home, then Browser opened. | Browser reads same app-wide scope. | Mock storage. | Medium |
| JT-007 | CR-020 / BL-016 | Placeholder hiding. | Placeholder feature disabled. | User does not see incomplete surface. | Depends on metadata/UI implementation. | Medium |

## Flow and Manual Validation

| Test ID | Related finding/backlog ID | Purpose | Scenario | Expected result | Data setup notes | Priority |
|---|---|---|---|---|---|---|
| FT-001 | CR-009 / BL-011 | Campaign flow normal path. | Event and Instance create with valid metadata. | Campaign is created/linked once. | Use Partial UAT manual or Flow test if feasible. | High |
| FT-002 | CR-009 / BL-011 | Campaign flow duplicate protection. | Same Event/Instance path runs again. | No duplicate Campaigns. | Manual/UAT validation if flow remains. | High |
| FT-003 | CR-030 / BL-019 | Flow fault path. | Missing Campaign parent/RecordType simulation. | Admin-visible error/log occurs. | Best in sandbox/UAT. | Medium |
| MT-001 | CR-022 / BL-022 | Public template URL validation. | Load each Visualforce public template. | No staging URLs or blocked assets. | Manual browser QA. | Medium |

## Minimum Test Gate Before Production

- All Critical and High Apex tests pass.
- Public file negative tests pass.
- Readiness policy tests cover paid/free and virtual/physical.
- Cursor pagination tests cover duplicate sort values.
- Permission tests cover normal app user and restricted user paths.
- Manual Flow validation is complete if active flows remain.

