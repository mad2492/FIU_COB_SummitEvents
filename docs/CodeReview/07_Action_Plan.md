# Summit Events Custom Layer - Action Plan

## Immediate Recommended Fixes

1. Build a shared readiness policy service.
   - Include Account, capacity, payment gateway, accounting department, location type, physical location fields, virtual meeting fields, and Instance date/time.
   - Use the same service for wizard validation, readiness recalculation, Home KPIs, browser readiness buckets, and future publish/launch actions.

2. Correct location-specific readiness.
   - Online/virtual events should not require physical map/address/parking fields.
   - Physical/offsite events should require the physical logistics fields.

3. Continue cursor pagination work.
   - Finish `FiuInstanceBrowserService` for search and Unpublished filters.
   - Then convert `FiuRegistrationBrowserService` from page-number/StandardSetController to cursor pagination.

4. Replace Home KPI row scans.
   - Use aggregate queries for counts.
   - Use a separate limited query for attention rows.
   - Consider a summary object if KPI logic becomes expensive.

5. Tighten public file handling.
   - Allowlist safe image formats.
   - Block SVG unless explicitly approved and sanitized.
   - Track public distributions created by the app.
   - Add cleanup/revoke procedure.

## UAT Readiness Checklist

- [ ] Record type selector behavior is signed off for one-record-type users and multi-record-type users.
- [ ] Program filter follows users across Home, Events, Instances, and Registrations.
- [ ] Missing capacity shows as a blocker.
- [ ] Paid event without gateway/accounting department shows as a blocker.
- [ ] Online event readiness does not require physical map/address/parking.
- [ ] Physical event readiness requires logistics fields.
- [ ] Public image upload flow works for nontechnical users without duplicate uploads.
- [ ] Placeholder tabs/components are hidden or replaced.
- [ ] Registration mass update cannot create mismatched Event/Instance values for standard users.
- [ ] Preview records are visibly marked and excluded from normal dashboards/lists.
- [ ] Apex tests cover critical readiness and public file cases.

## Production Readiness Checklist

- [ ] True cursor/keyset pagination is in place for high-volume browsers.
- [ ] Home KPIs cannot truncate at 10,000 rows.
- [ ] Scheduled preview cleanup is deployed and monitored.
- [ ] Flow fault paths or Apex replacement are in place for Campaign creation.
- [ ] Permission set follows least privilege for preview/readiness/public file/export actions.
- [ ] Field-level security strategy is documented and tested.
- [ ] Public Visualforce templates have production-safe URLs and trusted external dependencies.
- [ ] Export behavior has row caps, permission checks, and async path for large exports.
- [ ] Reminder stale-data and duplicate-send scenarios are covered by policy/tests.
- [ ] Business owners sign off on clone governance and required fields.

## Deferred Improvements

- Refactor `FIU_EventsWizardService` into smaller service classes.
- Split `fiuEventCreateWizard` into child components and shared JS modules.
- Normalize program filtering into metadata or a junction object.
- Modernize CSV/export UX from Visualforce to LWC/async Apex.
- Replace hardcoded department/account logic with custom metadata.
- Add observability/reporting for automation failures and readiness recalculation backlog.

## Suggested Order of Operations

1. Readiness policy and missing capacity blocker.
2. Location-type readiness correction.
3. Public file service hardening.
4. Instance Browser cursor completion.
5. Registration Browser cursor conversion.
6. Home KPI aggregate query pass.
7. Preview cleanup scheduled job.
8. Flow fault/idempotency review.
9. Permission/FLS hardening.
10. Test expansion and UAT regression pass.

## Items Needing Business Owner Validation

- Required fields for public launch.
- Clone reset/review policy.
- Event-only registration reassignment policy.
- Public file format policy.
- Export access policy.
- Preview retention window.
- Record type and program ownership by team.

## Items Needing Developer Implementation

- Shared readiness policy service.
- Cursor pagination helpers and browser updates.
- Aggregate Home KPI queries.
- Public file allowlist/lifecycle tracking.
- Scheduled preview cleanup.
- Apex and Jest tests.
- Registration mass update guardrails.
- Flow-to-Apex campaign service if flows are replaced.

## Items Needing Admin Configuration

- Hide placeholder tabs/components before UAT.
- Make preview/readiness fields read-only for normal users.
- Confirm permission set/class/field access for intended app users.
- Validate Campaign parent/record type metadata.
- Validate Visualforce template URLs and trusted external resources.
- Define UAT test users by record type/program scope.

