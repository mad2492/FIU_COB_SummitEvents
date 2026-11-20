# UAT Readiness Checklist

## Required Code Fixes

- [ ] Shared readiness policy service exists and is used by key readiness surfaces.
- [ ] Missing Capacity is a blocker.
- [ ] Paid Event without Payment Gateway is blocked.
- [ ] Paid Event without Accounting Department is blocked.
- [ ] Physical location readiness requires the correct physical fields.
- [ ] Virtual/online readiness requires virtual meeting details and does not require physical map/address/parking.
- [ ] Instance Browser search and Unpublished filters use cursor pagination.
- [ ] Registration Browser listing uses cursor pagination.
- [ ] Home KPIs use aggregate or summary-based counts.
- [ ] Preview cleanup job exists and can be scheduled in Partial UAT.
- [ ] Public file service allowlist and permission checks are implemented.
- [ ] Registration mass update cannot create Event/Instance mismatches for standard users.

## Required Metadata Fixes

- [ ] Placeholder tabs/components are hidden or replaced.
- [ ] Preview/readiness fields are read-only for standard app users.
- [ ] Public file custom permission is assigned only to approved users.
- [ ] Export/admin permissions are separated if approved.
- [ ] Flow fault paths or approved Apex replacement plan exists for active Campaign flows.
- [ ] Visualforce template external URLs are validated for UAT and production readiness.

## Required Permission Checks

- [ ] Standard FIU Events user can open Home, Event Browser, Instance Browser, Registration Browser, and allowed wizards.
- [ ] User with one record type sees no confusing selector, or sees a disabled selector if business approved that pattern.
- [ ] User with multiple record types can set record type scope first, then program.
- [ ] User without public file permission cannot create public links.
- [ ] User without export permission cannot export restricted/high-volume data.
- [ ] User cannot directly edit readiness/preview system fields.

## Required Business Validations

- [ ] Required readiness fields approved.
- [ ] Paid event blockers approved.
- [ ] Capacity behavior approved.
- [ ] Clone warning/reset policy approved.
- [ ] Public image format policy approved.
- [ ] Preview retention window approved.
- [ ] Reminder cleanup/Pardot expectations approved.
- [ ] Registration Event-only reassignment policy approved.
- [ ] Record type/program ownership approved.
- [ ] Export access and row-limit policy approved.

## Required Test Coverage

- [ ] Apex tests for shared readiness policy.
- [ ] Apex tests for paid events.
- [ ] Apex tests for capacity blocker.
- [ ] Apex tests for physical and virtual location readiness.
- [ ] Apex tests for Instance Browser cursor pagination.
- [ ] Apex tests for Registration Browser cursor pagination.
- [ ] Apex tests for public file allowlist and permission denial.
- [ ] Apex tests for preview cleanup job.
- [ ] Apex tests for registration reassignment guardrails.
- [ ] Permission/runAs tests where practical.
- [ ] Jest tests or documented manual QA for LWC wizard, browser pagination, scope persistence, and mass update UX.

## Required Manual QA Scenarios

- [ ] Create unpaid physical Event with complete data.
- [ ] Create paid Event missing Payment Gateway and confirm blocker.
- [ ] Create paid Event missing Accounting Department and confirm blocker.
- [ ] Create Event missing Capacity and confirm blocker.
- [ ] Create online Event with virtual details and no physical address/map; confirm ready behavior.
- [ ] Create physical Event missing parking/map/address and confirm not-ready behavior.
- [ ] Upload image through rich text editor and verify public registration page loads image.
- [ ] Attempt private/pasted image scenario and verify repair UX is clear.
- [ ] Use Home record type and program filters, then navigate to Event/Instance/Registration tabs and verify scope follows.
- [ ] Page through Instance Browser search results.
- [ ] Page through Registration Browser results.
- [ ] Try Registration mass update to a new Instance and verify Event aligns.
- [ ] Attempt Event-only mass update as standard user and confirm blocked/controlled.
- [ ] Confirm preview records are marked and cleaned after expiry.
- [ ] Confirm placeholder tabs are hidden.

## Required Regression Scenarios

- [ ] Existing Event Browser filters still work.
- [ ] Existing Instance creation still works.
- [ ] Existing Registration Browser filters still work.
- [ ] Public registration templates still render.
- [ ] Campaign creation automation still creates/links expected Campaigns.
- [ ] Existing CSV/export flows still work for approved users.
- [ ] Readiness recalculation still updates status fields after Event/Instance edits.

## Required Documentation Updates

- [ ] Update `docs/CodeReviewImplementationPlan/` if implementation order changes.
- [ ] Add a signed-off governance note for Phase 0 decisions.
- [ ] Update user-facing guide/help content for readiness blockers and public image behavior.
- [ ] Update deployment notes with Partial UAT validation steps.
- [ ] Update admin notes for scheduled preview cleanup and permission assignments.

