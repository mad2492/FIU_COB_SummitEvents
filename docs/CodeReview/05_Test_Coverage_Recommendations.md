# Summit Events Custom Layer - Test Coverage Recommendations

## Existing Test Strengths

Existing Apex tests found:
- `ExportCsvControllerTest`
- `FiuAppScopeIntegrationTest`
- `FiuEventsServicesTest`
- `FiuInstanceBrowserServiceTest`
- `FiuPublicFileServiceTest`
- `FiuReadinessRecalcServiceTest`
- `FiuSupportServicesCoverageTest`

Strengths:
- Public file service has dedicated test coverage.
- Instance browser has a dedicated test class, which is important for the pagination work.
- Readiness recalculation has dedicated coverage.
- App scope integration is being tested, which aligns with the record type/program filter direction.
- Export controller has a broad test file.

## Critical Apex Tests To Add

| Test area | Recommended tests | Priority |
|---|---|---|
| Shared readiness policy | Missing Account, missing capacity, paid without Payment Gateway, paid without Accounting Department, online without meeting link, physical without address/map/parking. | Critical |
| Location-specific readiness | Onsite, offsite, online, virtual, hybrid if used; verify online does not require physical location fields. | High |
| Home KPI scale | More than one page of data; assert aggregate counts do not truncate at 10,000. Use smaller test limits by injecting query strategy if needed. | High |
| Instance keyset pagination | Search mode, Unpublished mode, record type scope, program scope, stable ordering with duplicate dates. | High |
| Registration pagination | Cursor paging across many registrations, duplicate sort values, filters, and no-access record types. | High |
| Registration mass update | Instance-only update aligns Event; Event-only update is blocked or requires explicit confirmation; mismatched Event/Instance throws error. | High |
| Preview lifecycle | Preview create, preview reuse by session, expiration cleanup, scheduled cleanup, cleanup failure does not block preview. | High |
| Public file service | Permission denied, unsupported file type, SVG blocked, oversized body rejected, ContentDocument without latest version, public URL returned. | High |
| Permission behavior | `System.runAs` app user, app user without custom permission, user without record type access, user lacking field permission where practical. | High |
| Flow-adjacent campaign behavior | Event create and Instance create with missing Campaign metadata; duplicate prevention/idempotency if moved to Apex. | High |

## Additional Apex Tests

- Paid event clone resets or requires confirmation for payment fields.
- Clone does not unintentionally retain old reminder values.
- Event with no Instance returns a clear readiness blocker.
- Registration without Contact but with Email is flagged differently from no Contact and no Email.
- Cancelled registration clears/suppresses reminder fields if reminder logic is added.
- Queueable readiness recalculation handles bulk Event/Instance updates without exceeding queueable limits.
- Export service warns or routes to async when roster exceeds synchronous row cap.
- Program filter options are complete when Plan metadata exists but few historical Events exist.
- DST and timezone edge cases for Instance start/end handling.

## LWC/Jest Tests To Add

No Jest tests were found in source.

Recommended LWC tests:
- `fiuEventCreateWizard`
  - Capacity required.
  - Paid event requires gateway/accounting department.
  - Physical location fields required only for physical/offsite types.
  - Online event does not require map/address but requires virtual details.
  - Private rich text image warning and public conversion success/failure.
  - Preview disabled states and successful preview navigation behavior.
- `fiuEventsHome`
  - Record type selector hidden/disabled when only one record type is available.
  - Program filter persists across tabs.
  - Empty/error/loading states render clearly.
- `fiuInstanceBrowser`
  - Cursor/next-page behavior.
  - Unpublished filter behavior.
  - Program and record type scope passed to Apex.
- `fiuRegistrationBrowser`
  - Mass update modal blocks no-op updates.
  - Event-only update confirmation/blocking behavior.
  - Warnings from Apex are displayed.
- `fiuListShell`
  - Pagination controls, empty state, total/hasNext behavior, and accessibility labels.

## Flow Testing

If active Campaign creation flows remain:
- Add Flow tests where possible for normal path, missing parent Campaign, missing RecordType, preview Event skip, duplicate prevention, and fault path.
- If Flow tests are not practical, move the business behavior into Apex and cover it with Apex tests.

## Data Setup Recommendations

- Use factory methods for Summit Event, Instance, Registration, Plan, Account, Campaign, and ContentVersion records.
- Avoid relying on existing org data.
- Resolve record types dynamically by developer name only inside test helper methods, and skip/assert clearly when a package record type is unavailable.
- Use explicit dates, including DST boundary dates.
- Include low-permission `runAs` users where Salesforce test limitations allow.
- Keep managed package required fields in one factory so future package upgrades only require one test update.

## Tests Needed Before Production Deployment

Before production, prioritize:
1. Readiness policy blocker tests.
2. Instance and Registration pagination tests.
3. Public file service negative/security tests.
4. Preview lifecycle cleanup tests.
5. Permission/record type scope tests.
6. Registration mass update mismatch tests.
7. Online versus physical event readiness tests.

