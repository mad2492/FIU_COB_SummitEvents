# Summit Events Custom Layer Code Review - Executive Summary

Review date: 2026-05-18

Scope reviewed:
- Project documentation in `docs/`
- FIU-owned Apex, LWC, triggers, flows, permission set, custom fields, tabs, app metadata, and Visualforce templates in source
- Summit Events managed package boundaries from the source available in this repo

Out of scope:
- No production metadata was changed or deployed.
- Managed package internals were not modified.
- Runtime org-only configuration not present in source could not be fully verified.

## Expected Behavior

The FIU custom layer is intended to make Summit Events safer and easier for College of Business users. The documented design centers on guided event creation, event instance creation, cloning, readiness checks, program/record type scoping, roster and registration tools, public registration readiness, reminders, and payment setup visibility.

The custom layer should preserve Summit Events upgradeability by extending the managed package rather than editing package code. It should also protect business users from common bad configurations: missing capacity, missing payment gateway/accounting department, missing account, incomplete location/virtual details, stale preview records, and confusing Event versus Instance relationships.

## Overall Risk Rating

Overall risk: High before production.

The core direction is sound and many of the right pieces are now present, especially the app shell, scoped browsing, guided creation, readiness fields, public file service, and Apex test foundations. The main production risks are scale behavior, stale readiness, public file/link governance, flow/Apex overlap, and a few data integrity paths that still depend on UI behavior instead of consistent server-side enforcement.

## Top 10 Findings

1. Critical: There is not yet a consistent server-side production readiness gate across all paths. UI validation exists, but direct edits, flows, imports, and older clone paths can still create incomplete event/payment/location configurations.
2. High: Home KPIs can under-report in production because `FiuHomeDashboardService` limits active Events and Instances to 10,000 rows and computes readiness in memory.
3. High: Instance Browser is partially keyset-based, but search and unpublished modes still fall back to `LIMIT 10000` and in-memory filtering.
4. High: Registration Browser still uses `ApexPages.StandardSetController` instead of keyset/cursor pagination.
5. High: Readiness checks require physical location fields even when an Instance may be online or virtual.
6. High: Readiness fields can become stale when related records change outside the Event/Instance triggers.
7. High: Preview records rely on best-effort inline cleanup, not a scheduled lifecycle process.
8. High: Public file creation is useful, but needs stricter file type, SVG, ownership, and lifecycle controls before broader rollout.
9. High: Active campaign creation flows overlap with Apex wizard behavior and need fault paths/idempotency hardening.
10. High: `FIU_EventsWizardService` and the create wizard LWC are both large orchestration surfaces, which increases regression risk.

## What Is Working Well

- The app is correctly moving toward a custom extension layer instead of managed package edits.
- Record type scoping is present in key services through `FiuEventsAccessService`.
- Program filtering now appears in the Home/listing pattern and is becoming app-wide.
- The public file service is the right architectural direction for embedded rich text images.
- Mass registration update now aligns Event to Instance when an Instance is chosen.
- Apex tests exist for several important services, including public file handling and readiness recalculation.
- Preview Events and Instances are explicitly marked with custom fields, giving the team a path to lifecycle governance.

## Needs Attention Before Production

- Add a single server-side readiness policy and use it consistently in create, clone, preview, browser, home KPI, and readiness surfaces.
- Finish true cursor/keyset pagination for Instance Browser and Registration Browser.
- Replace row-limited Home KPI logic with aggregate queries or summary data.
- Make readiness location checks conditional by location type.
- Add scheduled cleanup for preview records.
- Tighten public file governance.
- Review and harden active flows, especially Campaign creation.
- Add tests for paid events, missing capacity, online events, registration reassignment, large-volume pagination, and permission differences.

## Can Wait

- Cosmetic UI polish in guide and shell components.
- Full refactor of Visualforce templates, assuming current public pages remain stable.
- Replacing every hardcoded FIU external asset URL, though staging URLs should be checked before production.
- Removing legacy/draft flow assets, after validation that they are no longer used.

## Recommended Next Steps

1. Implement a shared readiness policy service and treat missing capacity as a blocker.
2. Convert Instance Browser search/unpublished modes to cursor pagination, then do Registration Browser.
3. Replace Home KPI row scans with aggregate queries or a summary object.
4. Add scheduled preview cleanup and public file lifecycle governance.
5. Expand Apex and LWC tests around the highest-risk business scenarios before production validation.

