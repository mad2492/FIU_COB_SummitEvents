# Summit Events Custom Layer - Redundancy and Cleanup

## Duplicate or Overlapping Logic

| Candidate | Observation | Recommendation | Confidence |
|---|---|---|---|
| Readiness logic | `FiuReadinessRecalcService` and `FiuHomeDashboardService` both evaluate readiness-like conditions. | Create one shared readiness policy service and have Home, dashboard, triggers, and create/clone flows consume the same result. | High |
| Location validation | Location checks exist in the create wizard LWC, `FIU_EventsWizardService`, and readiness services. | Consolidate into server-side policy, with LWC mirroring only for immediate UX. | High |
| Program/record type scope | Home and browser components each manage scope/persistence. | Add a shared LWC utility module for scope storage, defaults, and option labels. | Medium |
| Browser list behavior | Event, Instance, and Registration browsers share filter, sort, pagination, quick view, and refresh patterns. | Keep `fiuListShell`, but move repeated JS helpers into a shared module. | Medium |
| Preview lifecycle | Preview creation, reuse, cleanup, and public URL lookup live inside the main wizard service. | Move preview concerns into `FiuPreviewLifecycleService`. | High |
| CSV/export code | `ExportCsvController` and roster export logic both generate CSV-like output. | Create a single export service pattern with row caps, permission checks, and async export option. | Medium |

## Unused or Possibly Unused Files

Do not delete these without validation.

| Candidate | Observation | Recommendation |
|---|---|---|
| `Clone_Summit_Event_Instance.flow-meta.xml` | Flow status is Draft and contains hardcoded URLs/name formulas. | Validate whether this was replaced by LWCs. If retired, archive/remove from source after business owner sign-off. |
| `spEventsFIUPlanLookup` | LWC directory exists but no JS/HTML source files were found. | Confirm whether it is obsolete, managed elsewhere, or missing source. |
| `fiuReadinessDashboard` | Component appears minimal/placeholder while a tab exists. | Hide until implemented or replace with the current readiness/home surfaces. |
| `fiuInstanceRosterManager` | Component appears minimal/placeholder. | Hide if exposed, or complete before UAT if it is part of the promised workflow. |

## Overly Complex Code

| File/component | Why it is complex | Suggested split |
|---|---|---|
| `FIU_EventsWizardService.cls` | Over 1,000 lines; handles describes, init, create, preview, cleanup, Campaign lookup, program mapping, and helpers. | `WizardInitService`, `EventCreateService`, `InstanceCreateService`, `PreviewLifecycleService`, `ProgramSelectionService`. |
| `fiuEventCreateWizard` | Very large JS/HTML; owns form state, validation, rich text image conversion, public file service calls, preview, and save. | Child components for payment, logistics, rich text editor/image handling, review/preview, and footer actions. |
| `ExportCsvController.cls` | Large Visualforce controller with dynamic query/export responsibilities. | Export query builder, field policy, CSV serializer, async export service. |
| `FiuInstanceBrowserService.cls` | Mixes access, query building, keyset fallback, readiness bucket evaluation, and DTO mapping. | Query builder plus cursor/pagination helper. |
| `FiuRegistrationBrowserService.cls` | Combines query, sort, search, DTO mapping, and mass update behavior. | Registration query service and registration bulk update service. |

## Naming and Structure Inconsistencies

- Repository uses `docs/`, while user-facing instructions sometimes refer to `Docs/`. This is fine on Windows, but standardize references for portability.
- FIU custom classes mix `FIU_` and `Fiu` prefixes. Existing names do not need urgent changes, but future classes should use one convention.
- Some flow labels and formula names preserve old workflow terminology. If the flows remain active, rename for the current app language.
- Event/Instance terms should stay explicit in labels. Avoid "Event Date" when the object is actually an Instance unless the UI explains it.

## Candidates for Shared Utility or Service Classes

- `FiuReadinessPolicyService`: single source for Event/Instance readiness, paid event blockers, capacity, account, location, virtual link, and program checks.
- `FiuCursorPagination`: shared keyset cursor serialization, sort validation, and `hasNext` logic.
- `FiuScopeService` or LWC utility module: record type/program scope persistence and defaulting.
- `FiuPublicAssetService`: public file allowlist, public link creation, distribution tracking, and revoke/cleanup.
- `FiuPreviewLifecycleService`: preview create/reuse/delete/scheduled cleanup.
- `FiuExportService`: CSV output, export permission checks, row cap messaging, and async export jobs.

## Candidates for Deletion

No file should be deleted immediately based on this review alone.

Candidates needing validation before removal:
- `Clone_Summit_Event_Instance.flow-meta.xml`
- `spEventsFIUPlanLookup`
- Placeholder components if not exposed or no longer planned

