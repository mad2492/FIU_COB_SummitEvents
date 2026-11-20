# Recommended Defaults

Decision count: 18

## BD-001 - Required Event Readiness Fields

Recommended default: Require Account, Capacity, active Instance, Instance date/time, location/virtual details, program scope, and paid-event payment fields when applicable.

Why: These fields affect public registration, reporting, payments, reminders, and staff confidence in readiness dashboards.

Risk reduced: Incomplete public Events, broken payments, missing schedule/location, and inconsistent readiness.

Impact on users: Users get clearer blockers before an Event is treated as ready.

Impact on implementation: Shared readiness policy must evaluate Event and Instance fields together.

Rule type: Hard blocker for launch/readiness.

## BD-001A - Event Account Requirement

Recommended default: Missing Account should block production-ready Event setup.

Why: Account identifies ownership/reporting context and supports downstream Campaign/reporting expectations.

Risk reduced: Orphaned Events and incorrect business ownership.

Impact on users: Users must choose the owning Account before readiness clears.

Impact on implementation: Account check belongs in shared readiness policy.

Rule type: Hard blocker.

## BD-001B - Hard Blockers Versus Soft Warnings

Recommended default: Treat public/payment/data-integrity issues as hard blockers; treat cosmetic or advisory items as soft warnings.

Why: Users should not be blocked by purely helpful guidance, but critical setup gaps should not slip through.

Risk reduced: Overblocking and underblocking.

Impact on users: Important issues stop progress; lower-risk issues remain visible but do not halt work.

Impact on implementation: Policy result should distinguish blockers from warnings.

Rule type: Mixed hard blocker and soft warning.

## BD-002 - Capacity Requirement

Recommended default: Capacity must be greater than zero where Capacity controls are expected.

Why: Capacity controls overbooking and was identified as a showstopper in the review.

Risk reduced: Events opening without a registration limit.

Impact on users: Users must enter Capacity before readiness clears.

Impact on implementation: First coding pass should include Capacity blocker only with the shared readiness service.

Rule type: Hard blocker.

## BD-003 - Paid Event Blockers

Recommended default: Paid events require both Payment Gateway and Accounting Department.

Why: Payment Gateway controls payment routing; Accounting Department supports reconciliation.

Risk reduced: Broken paid registration and incorrect accounting.

Impact on users: Paid Event creators must complete both fields.

Impact on implementation: Paid-event checks belong in shared readiness policy after the Capacity pass or in the same policy with tests.

Rule type: Hard blocker.

## BD-003A - Payment Gateway Requirement

Recommended default: Payment Gateway is required for paid events.

Why: A paid event without a gateway can fail at checkout or route incorrectly.

Risk reduced: Broken payment registration.

Impact on users: Users must select the gateway before readiness clears.

Impact on implementation: Requires reliable paid-event detection and gateway field resolution.

Rule type: Hard blocker.

## BD-003B - Accounting Department Requirement

Recommended default: Accounting Department is required for paid events.

Why: Finance needs the department for reconciliation and reporting.

Risk reduced: Incorrect financial routing/reporting.

Impact on users: Users must select the accounting department before readiness clears.

Impact on implementation: Add accounting department check to readiness policy.

Rule type: Hard blocker.

## BD-004 - Location Fields by Type

Recommended default: Physical/offsite Events require title, address, map, building, and parking; online/virtual Events require meeting link/instructions.

Why: Different event types need different attendee instructions.

Risk reduced: Virtual Events being blocked for physical fields, and physical Events missing logistics.

Impact on users: Readiness messages become more accurate and less frustrating.

Impact on implementation: Readiness policy must branch by location type.

Rule type: Hard blocker for required logistics, soft warning for optional enhancements.

## BD-005 - Clone Warning Behavior

Recommended default: Clone warnings should be explicit and unavoidable for paid events, location settings, reminders, public files, Opportunity creation, confirmation email, and Capacity.

Why: Clones can silently copy stale settings from a previous Event.

Risk reduced: Wrong payment destination, stale reminders, bad location details, and old public content.

Impact on users: Users will have one extra review step when cloning sensitive Events.

Impact on implementation: Clone UI should show sensitive copied fields and require confirmation/reset.

Rule type: Hard review step for sensitive clones.

## BD-006 - Registration Event-Only Updates

Recommended default: Standard users should not update Registration Event without selecting Instance.

Why: Registration Event and Instance must stay aligned.

Risk reduced: Event/Instance data mismatches.

Impact on users: Users choose the new Instance; the system derives Event.

Impact on implementation: Registration mass update Apex/LWC should block Event-only updates for standard users.

Rule type: Hard blocker for standard users.

## BD-007 - Public File Link Permission

Recommended default: Only approved FIU Events power users/admins can create public file links.

Why: Public links expose content outside authenticated Salesforce.

Risk reduced: Accidental exposure of sensitive or unsupported files.

Impact on users: Most users can use approved image flows but not create arbitrary public links.

Impact on implementation: Keep/extend custom permission checks.

Rule type: Permission boundary.

## BD-008 - Public Image Formats

Recommended default: Allow PNG, JPG/JPEG, GIF, and WEBP. Block SVG unless separately approved and sanitized.

Why: These formats are broadly supported and safer for public rendering.

Risk reduced: Risky SVG or unsupported files in public registration pages.

Impact on users: Users may need to convert unsupported images.

Impact on implementation: Public file service needs content type/extension allowlist and user-safe messages.

Rule type: Hard blocker for unsupported formats.

## BD-009 - Preview Records and Files Cleanup

Recommended default: Preview records and preview-created public assets should have a defined 24 to 72 hour cleanup window.

Why: Preview data should not live forever or affect reports/public content.

Risk reduced: Reporting pollution, stale previews, and public asset clutter.

Impact on users: Preview links are temporary by design.

Impact on implementation: Scheduled cleanup job and documentation are needed.

Rule type: Operational policy with scheduled enforcement.

## BD-010 - Reminder Cleanup

Recommended default: Cancelled or moved registrations should clear or suppress stale reminder fields and support retry/recalculation when appropriate.

Why: Reminder data can feed communications.

Risk reduced: Wrong attendees receiving reminders.

Impact on users: Staff can trust reminder eligibility after changes.

Impact on implementation: Reminder cleanup work should be a later focused pass after readiness.

Rule type: Hard data-consistency rule.

## BD-011 - Pardot / Account Engagement Source of Truth

Recommended default: Salesforce registration status plus current Instance/date should be the source of truth for reminder eligibility.

Why: Marketing automation should not rely on stale copied fields alone.

Risk reduced: Stale campaign audiences.

Impact on users: Marketing and Events teams share one eligibility rule.

Impact on implementation: Future reminder/MCAE work must align field updates and suppression logic.

Rule type: Hard data-governance rule.

## BD-012 - Event vs. Instance UX Terminology

Recommended default: Use explicit labels: Event = program/configuration; Instance = date/session. Hide the selector when a user has one record type, or show disabled only if the team wants visible context.

Why: The core usability problem is Event/Instance confusion.

Risk reduced: Users editing the wrong thing or misreading dashboards.

Impact on users: Screens become clearer and less technical.

Impact on implementation: Labels, help text, scope behavior, and wizard copy should align.

Rule type: UX standard.

## BD-013 - Permission Boundaries

Recommended default: Separate normal app use, public file creation, export, readiness/admin override, and campaign/admin cleanup permissions.

Why: Least privilege reduces accidental public/financial/reporting changes.

Risk reduced: Broad access to sensitive operations.

Impact on users: Some advanced actions require elevated permission.

Impact on implementation: Permission/FLS hardening should use custom permissions and runAs tests.

Rule type: Permission boundary.

## BD-014 - Readiness Override Authority

Recommended default: No standard-user override. If an override is required, restrict it to a small admin/power-user group with an audit expectation.

Why: Overrides can bypass the very controls being added for production safety.

Risk reduced: Untracked launch of incomplete Events.

Impact on users: Most users must fix blockers instead of bypassing them.

Impact on implementation: Any override should be a separate custom permission, not part of normal app access.

Rule type: Permission boundary and hard blocker for standard users.

