# FIU COB Summit Events - Phase 1 (Partial UAT)

## Overview
This repository contains FIU-owned extensions for Summit Events focused on a practical Event Management experience for FIU teams.

The current delivery target is **Phase 1 in Partial UAT** with a **Prod discovery-first** approach.

## Phase 1 Goals
1. Build an FIU Events app experience centered on event operations.
2. Provide guided Create/Clone/Add Instance flows with guardrails.
3. Improve operational visibility for instances, registrations, readiness, and attendance exports.
4. Respect user visibility and record type access patterns (for example: Chapman vs EPE scope).
5. Seed UAT with selective, realistic event data and dependencies (not full-clone seeding).

## Environment Boundaries
- **Production**: discovery and source-of-truth behavior validation only.
- **Partial UAT**: implementation, iteration, and UAT validation.
- Managed package assets are not modified directly; FIU-owned metadata/components are used for extensions.

## What Is Implemented So Far
1. FIU Events Lightning App shell and navigation setup.
2. FIU Home tab with operational KPIs and action entry points.
3. Launcher actions for:
   - Create New Event
   - Clone Existing Event
   - Add New Instance
4. Browser tabs:
   - Events Browser (including Create New Event and View Instances flows)
   - Instances Browser (including Open, Clone Instance, and View Registrations actions)
   - Registrations Browser (including Export to CSV action via FIU controller and instance-scoped deep links)
5. Instance-focused workspace/page experience for operational handling.
6. Server-side record-type-aware filtering based on user-available event record types.
7. Program-aware filtering across Home/Events/Instances/Registrations using:
   - Event Program Filter fields (including delimited values)
   - Event Default Plan lookup (`Default_Plan__c -> Plan_Code__c`)
   - Normalized Plan Code matching with deduped program options.
8. Home command-center enhancements:
   - Program scope selector with visible current scope
   - Not Ready Instances KPI with deep-link to prefiltered Instance Browser (`Unpublished`)
   - Not Ready Events KPI
9. Event readiness diagnostics:
   - Event Browser includes `Readiness` and `Issues` columns
   - Color-coded highlighting for Active events with issues vs ready events
   - Deep-link from Home `Review Events` into Not Ready event filter
10. Instance readiness behavior aligned to operations:
   - Past instances are not flagged just for closed registration / inactive status
11. Discovery documentation expanded with FIU custom-field inventory from Partial UAT Tooling API.
12. Selective production data carryover into Partial UAT for key event journeys.

## In Progress / Near-Term Phase 1 Work
1. Expand wizard business logic depth for create/clone/add-instance paths.
2. Continue UX polish for Home and role-relevant scoping.
3. Deepen readiness diagnostics and negative-path handling.
4. Add/expand Apex unit tests and LWC Jest coverage aligned to Phase 1 test cases.
5. Finalize permissions and profile/permission-set alignment for target user groups.

## Key Functional Expectations
1. Users can create events, clone events, and add instances from FIU-owned entry points.
2. Users can browse events and drill into related instances quickly.
3. Users can manage registrations and export registration data.
4. Program filtering is intuitive and non-redundant (single option per logical program).
5. Views should be meaningful to each audience based on visibility and record types.

## Repository Docs
Core project context and discovery templates are in `docs/`:
1. `docs/08_CODEX_MASTER_PROMPT.md`
2. `docs/00_MASTER_HANDOFF.md`
3. `docs/01_PROJECT_BRIEF.md`
4. `docs/02_ARCHITECTURE_CONSTRAINTS.md`
5. `docs/03_CURRENT_STATE_AND_BUSINESS_RULES.md`
6. `docs/04_PHASED_DELIVERY_PLAN.md`
7. `docs/05_COMPONENT_BACKLOG.md`
8. `docs/06_DISCOVERY_AND_OPEN_QUESTIONS.md`
9. `docs/07_DATA_COLLECTION_TEMPLATE.md`

## Salesforce DX Quick Start
1. Authenticate orgs as needed:
   - Partial UAT target org
   - Prod discovery org (read/discovery only)
2. Deploy metadata from `force-app/main/default` to Partial UAT.
3. Assign FIU permissions/permission sets for testing users.
4. Validate app navigation, tabs, filters, row actions, and readiness signals.

## Testing Expectations (Phase 1)
1. Apex unit tests for create/clone/validation/export/readiness-related services.
2. LWC Jest tests for launcher/browser filter behavior and required-field gating.
3. UAT scenarios:
   - Create paid event with readiness pass
   - Clone event with risky-setting review
   - Add instance with expected inheritance behavior
   - Manage attendance and export CSV
   - Negative tests for missing critical config

## Branching and Delivery
Use feature branches for iterative work and merge into shared integration branches after UAT validation checkpoints.

Recommended naming examples:
- `phase1-partial-uat`
- `phase1-wizard-logic`
- `phase1-readiness`
