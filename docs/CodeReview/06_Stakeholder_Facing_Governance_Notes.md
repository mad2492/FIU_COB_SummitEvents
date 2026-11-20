# Summit Events Custom Layer - Governance Notes for Stakeholders

## What This Custom Layer Is Intended To Do

The FIU custom layer is meant to make Summit Events easier and safer for staff who build and manage events. It adds guided screens, clearer filters, readiness checks, public image handling, and admin tools on top of the managed Summit Events app.

The goal is not to replace Summit Events. The goal is to protect FIU's event process from common setup mistakes while keeping the managed package upgradeable.

## Why Governance Matters

Event setup affects public registration pages, payment collection, reminders, reporting, attendance, and sometimes Opportunity creation. A small setup mistake can become very visible:

- A paid event can open without the correct payment setup.
- A public page can show missing or broken images.
- Attendees can receive the wrong reminder.
- Staff can report the wrong registration or attendance counts.
- A cloned event can carry old payment or location information.

Governance means deciding which fields are required, which defaults are safe, who can change sensitive settings, and what must be reviewed before an event is public.

## Places Users Could Accidentally Create Bad Data

- Creating a paid event without Payment Gateway.
- Creating a paid event without Accounting Department.
- Creating an event without capacity.
- Creating an event without Account/business owner.
- Creating an online event without virtual meeting details.
- Creating a physical event without address, map, building, or parking details.
- Cloning an old event and keeping old payment, reminder, location, or Opportunity settings.
- Moving registrations to a different Event without also moving them to the correct Instance.
- Pasting images into a rich text field that are still private Salesforce files.
- Leaving preview Events/Instances behind after testing.

## Why Some Fields Should Be Required

Some fields should not be optional because they affect public or financial outcomes.

- Capacity protects registration limits and avoids overbooking.
- Payment Gateway tells the system where paid registrations should go.
- Accounting Department supports reconciliation and reporting.
- Account helps identify the business owner and reporting context.
- Location or virtual meeting details tell attendees where to go.
- Program/record type scope keeps unrelated event groups from mixing in reports and dashboards.

## Why Clone Warnings Matter

Cloning is useful, but it is also risky. A cloned event can silently carry settings that were correct last semester but wrong now.

Stakeholders should decide which fields are safe to copy and which fields must be reviewed every time. Recommended fields to review on clone:

- Payment Gateway
- Accounting Department
- Opportunity creation setting
- Confirmation email setting
- Reminder settings
- Location and parking details
- Capacity
- Public images and public registration content

## Why Permissions Should Be Limited

Not every user should be able to change public file links, payment setup, readiness flags, preview flags, or export large registration lists.

Limiting permissions protects users from accidental changes and protects FIU from public, financial, or reporting mistakes. The app can still be useful while keeping sensitive actions behind custom permissions.

## Decisions Stakeholders Should Validate

1. Which record types each event team should see.
2. Which program values belong to each event team.
3. Whether users with one record type should see a disabled selector or no selector.
4. Which fields are required before an event can be made public.
5. Which fields must be reset or reviewed when cloning an event.
6. Who can create public file links.
7. How long preview records should be kept before cleanup.
8. Whether Event-only registration reassignment should be allowed.
9. What row limits or approval process should apply to exports.
10. Who should receive alerts when automation fails.

## Open Questions for Business Owners

- Should missing capacity always block launch? Recommendation: yes.
- Should all paid events require both Payment Gateway and Accounting Department? Recommendation: yes.
- Should clone copy payment/reminder settings by default? Recommendation: no, require review.
- Should users be allowed to update a Registration's Event without selecting an Instance? Recommendation: no for standard users.
- How long should preview Events and Instances remain before deletion? Recommendation: 24 to 72 hours.
- Which image formats should be allowed for public rich text images? Recommendation: PNG, JPG/JPEG, GIF, WEBP; avoid SVG unless explicitly approved.
- Which teams need export access, and what counts as a large export?

