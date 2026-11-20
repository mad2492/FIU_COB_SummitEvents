# Phase 0 Business Decision Packet - Overview

## Purpose

This packet gives business stakeholders one place to review and approve the policy decisions needed before coding begins for the Summit Events custom layer.

The code review found that the custom layer is moving in the right direction, but several production-risk items depend on business rules. The most important example is readiness: the system can only block an incomplete Event if the business agrees what "ready" means.

## Why Decisions Are Needed Before Coding

The next recommended coding pass is the shared readiness policy service plus Capacity blocker. That service will become the source of truth for whether an Event or Instance is ready enough for staff action and public registration workflows.

If the business rules are unclear, developers could accidentally create rules that are too strict, too loose, or inconsistent across screens. That would create exactly the problem the custom layer is trying to solve: users seeing different answers in different places.

## Major Risk Areas

- Readiness rules: which missing fields should block progress versus show a warning.
- Paid event setup: Payment Gateway and Accounting Department must be treated consistently.
- Capacity: missing or zero Capacity can affect registration limits and should be decided before implementation.
- Event versus Instance: users need clear labels so they know whether they are editing the parent Event or a dated Instance.
- Clone behavior: cloned Events can carry old payment, location, reminder, public file, or Opportunity settings.
- Public files: public image links need ownership, allowed file types, and cleanup rules.
- Preview records/files: abandoned previews need a retention and cleanup expectation.
- Reminder/Pardot data: cancelled or moved registrations should not feed stale campaign/reminder data.
- Permission boundaries: normal users, power users, admins, exporters, and override users should not all have the same access.

## Recommended Review Audience

- Salesforce/Admin owner
- Events/business owner
- Admissions stakeholder, if admissions events are in scope
- Payment/accounting representative, if paid events are in scope
- Marketing/Pardot or Account Engagement owner, if reminder data feeds campaigns
- Security or data governance representative for public files and permissions
- Technical/developer support for implementation impact questions

## Recommended Approval Process

1. Stakeholders read this packet and the approval form.
2. The business review meeting resolves the hard-blocker decisions first.
3. Each decision receives one of these outcomes:
   - Approve recommended default
   - Approve an alternative
   - Defer with a temporary fallback
4. The approved decisions are copied into project governance notes.
5. Only then should the next coding prompt run.

## Implementation Work Blocked Until Approval

- Shared readiness policy service
- Capacity blocker behavior
- Paid event validation
- Location-type readiness rules
- Clone warning/reset behavior
- Public file lifecycle/security hardening
- Reminder cleanup and Pardot data consistency work
- Permission/FLS hardening and custom permission splits
- UAT signoff criteria

## Recommended Next Coding Pass After Approval

After Phase 0 decisions are approved, the next coding pass should be:

```markdown
Implement the shared readiness policy service and Capacity blocker only. Do not implement pagination, KPI optimization, public file cleanup, clone warnings, or permission/FLS hardening in this pass.
```

