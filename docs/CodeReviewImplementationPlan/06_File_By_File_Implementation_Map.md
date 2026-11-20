# File-by-File Implementation Map

| Existing file/component | Current purpose | Related findings | Proposed change | Risk level | Test coverage needed | Business validation before changing? |
|---|---|---|---|---|---|---|
| `FIU_EventsWizardService.cls` | Event create/preview orchestration. | CR-001, CR-007, CR-010, CR-018 | Call shared readiness policy; integrate preview lifecycle; avoid broad refactor until after high-risk fixes. | High | Paid/free, capacity, preview, clone sensitive settings. | Yes for readiness/clone rules. |
| `FiuReadinessRecalcService.cls` | Async readiness field recalculation. | CR-001, CR-005, CR-006, CR-025 | Replace duplicated logic with shared policy; add location-type rules and debounce/reconciliation later. | High | Readiness policy, bulk enqueue, stale-data scenarios. | Yes for readiness rules. |
| `FiuHomeDashboardService.cls` | Home KPIs and attention rows. | CR-002, CR-005 | Use aggregate counts and shared readiness status/policy; remove `LIMIT 10000` KPI dependency. | High | KPI counts, scope filters, preview exclusion. | No, assuming KPI definitions stay same. |
| `FiuInstanceBrowserService.cls` | Instance browser query/pagination. | CR-003 | Complete cursor pagination for search and Unpublished modes. | High | Cursor paging, search, unpublished, duplicate dates. | No. |
| `FiuRegistrationBrowserService.cls` | Registration browser query and mass update. | CR-004, CR-012 | Convert list to cursor pagination; block/admin-gate Event-only reassignment. | High | Cursor paging, mass update guardrails, status filters. | Yes for Event-only reassignment. |
| `FiuPublicFileService.cls` | Public ContentDistribution/public image creation. | CR-008, CR-024 | Add allowlist, size limits, SVG policy, lifecycle tracking/revoke if approved. | High | Supported/unsupported types, permission denial, public URL. | Yes for public file policy. |
| `FiuEventsReadinessService.cls` | Readiness endpoint. | CR-029, CR-001 | Return structured no-access/not-found errors; call shared policy. | Medium | Missing record/no access tests. | No. |
| `FiuEventsRosterService.cls` | Roster rows and CSV export. | CR-013 | Add cap warning or async export path. | High | Large roster/cap behavior. | Yes for export policy. |
| `FiuProgramFilterService.cls` | Program option/filter logic. | CR-016, CR-017 | Short term: preserve behavior; later source options from Plan/custom metadata. | Medium | Program option completeness and filters. | Yes for program ownership. |
| `FiuEventsAccessService.cls` | Record type/access resolver. | CR-014, CR-028 | Keep as central wrapper; extend if needed for permission/scoping. | High | No available record types, scoped record type tests. | Yes for scope behavior. |
| `FiuEventBrowserService.cls` | Event browser service. | CR-026, CR-027, CR-014 | Align scope/FLS/cursor patterns after Instance/Registration work. | Medium | Scope, search, permission tests. | No. |
| `FiuInstanceWizardService.cls` | Instance wizard helper/create logic. | CR-018, CR-028 | Replace hardcoded department/account assumptions with metadata later. | Medium | Department/default behavior tests. | Yes for defaults. |
| `ExportCsvController.cls` | Visualforce export controller. | CR-023 | Add export permission/field governance; consider async/LWC later. | Medium | Restricted user/export field tests. | Yes for export policy. |
| `FiuEventReadinessRecalc.trigger` | Event readiness trigger. | CR-006, CR-025 | Keep; route through debounce/reconciliation strategy if added. | Medium | Bulk trigger tests. | No. |
| `FiuInstanceReadinessRecalc.trigger` | Instance readiness trigger. | CR-006, CR-025 | Keep; route through debounce/reconciliation strategy if added. | Medium | Bulk trigger tests. | No. |
| `fiuEventCreateWizard` | Guided create/preview UI. | CR-011, CR-024, CR-001 | Update validation/messages to match shared policy; improve public image repair UX; refactor later. | High | Jest for validation and image flow. | Yes for UX wording/rules. |
| `fiuInstanceCreateWizard` | Guided Instance create UI. | CR-005, CR-018 | Mirror shared readiness rules and clone/default decisions. | Medium | Jest/manual location cases. | Yes for clone/default behavior. |
| `fiuInstanceBrowser` | Instance list UI. | CR-003 | Consume cursor/hasNext and remove page-number assumptions where needed. | High | Jest cursor interactions. | No. |
| `fiuRegistrationBrowser` | Registration list/mass update UI. | CR-004, CR-012 | Consume cursor/hasNext; block/admin-gate Event-only updates. | High | Jest cursor and mass update tests. | Yes for Event-only policy. |
| `fiuEventsHome` | Home KPI and scope UI. | CR-002, CR-026 | Render aggregate counts; keep record type/program scope. | High | Jest/manual KPI/scope tests. | Yes for selector behavior. |
| `fiuListShell` | Shared list shell. | CR-003, CR-004 | Add cursor-friendly mode with `hasNext`; avoid requiring exact totals. | High | Jest for paging controls. | No. |
| `fiuEventCloneWizard` | Clone workflow entry. | CR-018 | Add sensitive-setting review/reset once business rules are approved. | Medium | Clone UX tests/manual QA. | Yes. |
| `fiuReadinessDashboard` | Placeholder readiness dashboard. | CR-020, CR-033 | Hide until built or route to ready surface. | Medium | Manual nav check. | No. |
| `fiuInstanceRosterManager` | Placeholder roster manager. | CR-020 | Hide until built or replace with implemented workspace. | Medium | Manual nav check. | No. |
| `spEventsFIUPlanLookup` | Empty/missing LWC source candidate. | CR-021 | Validate source ownership before removing or restoring. | Medium | Source/deploy validation. | No. |
| `FIU_Events_User.permissionset-meta.xml` | App user permission set. | CR-014, CR-015 | Make preview/readiness read-only; split sensitive custom permissions. | High | Permission/runAs tests and manual user QA. | Yes for boundaries. |
| `Event_Created_Create_Campaign.flow-meta.xml` | Active Campaign creation flow. | CR-009, CR-030 | Add fault paths/idempotency or plan Apex replacement. | High | Flow/manual Campaign tests. | Yes for Campaign ownership. |
| `Event_Instance_Created_Create_Campaign.flow-meta.xml` | Active Instance Campaign flow. | CR-009, CR-030 | Same as Event flow; ensure preview skip remains. | High | Flow/manual tests. | Yes. |
| `Clone_Summit_Event_Instance.flow-meta.xml` | Draft clone flow. | CR-019 | Validate retired/active status; repair hardcoded URL/name logic if kept. | Medium | Manual validation only if kept. | Yes. |
| Visualforce templates | Public registration/payment templates. | CR-022 | Validate external URLs and environment-specific links. | Medium | Manual public page QA. | Yes with web owner. |
| Proposed New File: `FiuReadinessPolicyService.cls` | Central readiness policy. | CR-001, CR-005 | New Apex service for readiness blockers/warnings. | High | New policy test class. | Yes for policy rules. |
| Proposed New File: `FiuPreviewCleanupJob.cls` | Scheduled preview cleanup. | CR-007 | New schedulable/batch cleanup job. | High | Cleanup job tests. | Yes for retention window. |
| Proposed New File: cursor helper/DTO | Shared cursor pagination utility. | CR-003, CR-004 | Reusable cursor token/hasNext behavior. | High | Cursor unit tests through services. | No. |

