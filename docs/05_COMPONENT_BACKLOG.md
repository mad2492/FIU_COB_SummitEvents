# Component Backlog

## App / Navigation
- FIU Events Lightning App
- FIU Events Home page
- FIU Events utility/help text panel
- `fiuEventsGuide`

## Launcher / Guided Entry
- `fiuEventsLauncher`
- `fiuEventCreateWizard`
- `fiuEventCloneWizard`
- `fiuInstanceCreateWizard`

## Browsing / Search
- `fiuEventBrowser`
- `fiuInstanceBrowser`
- shared FIU custom list-shell/table pattern for browser screens
- `fiuUpcomingInstanceBrowser`
- filters by status, program, business unit, payment-enabled, future/past

## Readiness / Diagnostics
- `fiuEventReadinessPanel`
- `fiuInstanceReadinessPanel`
- surfaces missing required fields and operational warnings
- quick-view readiness callouts and public registration-link actions for instances

## Attendance / Registration Ops
- `fiuInstanceRosterManager`
- `fiuAttendanceUpdateGrid`
- CSV export utility/service

## Clone Support
- clone preview summary component
- clone warning panel for risky settings
- clone service Apex layer

## Shared Services / Apex
- event discovery/query service
- event creation orchestrator
- clone service
- instance creation/update service
- attendee export service
- readiness evaluation service

## Potential Reuse / Reference Assets
- `spEventsFIUPlanLookup` should be reviewed for reuse, embedding, or replacement
