# Meeting Agenda - Phase 0 Business Review

## Meeting Purpose

Review and approve the business decisions needed before coding begins for the Summit Events custom layer production-polish work.

The goal is not to design every technical detail. The goal is to confirm the operating rules that the next implementation pass should enforce.

## Attendees Needed

- Salesforce/Admin owner
- Events/business owner
- Admissions stakeholder, if admissions events are in scope
- Payment/accounting representative, if paid events are in scope
- Marketing/Pardot or Account Engagement owner, if reminder fields feed campaigns
- Security or data governance representative for public files and permission boundaries
- Technical/developer support, if implementation questions arise

## Pre-Read Documents

- `01_Decision_Packet_Overview.md`
- `02_Decision_Log.md`
- `03_Recommended_Defaults.md`
- `04_Stakeholder_Approval_Form.md`
- `05_Implementation_Blockers.md`

## Suggested Meeting Flow

### 1. Context and Goal - 5 minutes

- Confirm this is a decision meeting, not a coding session.
- Confirm no Production or managed package changes are being made from this packet.
- Confirm the next recommended coding pass is shared readiness policy service plus Capacity blocker only.

### 2. Readiness and Capacity - 15 minutes

Decisions to approve live:
- BD-001 Required readiness fields
- BD-001A Event Account requirement
- BD-001B Hard blockers versus soft warnings
- BD-002 Capacity requirement
- BD-004 Location fields by type
- BD-014 Readiness override authority

Outcome needed:
- Approved blocker/warning model for first readiness implementation.

### 3. Paid Event Rules - 10 minutes

Decisions to approve live:
- BD-003 Paid event blockers
- BD-003A Payment Gateway requirement
- BD-003B Accounting Department requirement

Outcome needed:
- Confirm paid Event fields are hard blockers and who owns exceptions.

### 4. Clone and Registration Data Integrity - 10 minutes

Decisions to approve live:
- BD-005 Clone warning behavior
- BD-006 Event-only registration update behavior

Outcome needed:
- Confirm clone review requirements and registration reassignment policy.

### 5. Public Files and Preview Cleanup - 10 minutes

Decisions to approve live:
- BD-007 Public file link permission
- BD-008 Public image formats
- BD-009 Preview record/file cleanup window

Outcome needed:
- Confirm who can create public links, allowed file types, and preview retention.

### 6. Reminder and Account Engagement Data - 10 minutes

Decisions to approve live:
- BD-010 Reminder cleanup behavior
- BD-011 Pardot/Account Engagement source of truth

Outcome needed:
- Confirm whether cancelled/moved registrations clear, suppress, or retain reminder data.

### 7. Permissions and UX Language - 10 minutes

Decisions to approve live:
- BD-012 Event versus Instance terminology
- BD-013 Permission boundaries

Outcome needed:
- Confirm UI terminology and least-privilege permission categories.

## Parking Lot Items

Use the parking lot for topics that matter but should not block the first code pass:

- Full pagination implementation details
- KPI aggregate query design
- Long-term program data model
- Export modernization
- Visualforce template redesign
- Full wizard component refactor
- Flow-to-Apex replacement strategy

## Post-Meeting Action Items

- Update `04_Stakeholder_Approval_Form.md` or a signed decision log with approved outcomes.
- Mark decisions as approved, alternative-approved, or deferred.
- Update implementation backlog if any recommended default changes.
- Run the next coding prompt only after readiness/Capacity decisions are approved.

## Decisions That Must Be Resolved Before First Coding Pass

- BD-001 or at least the portion covering Capacity and core readiness.
- BD-001B hard blocker versus soft warning model.
- BD-002 Capacity requirement.
- BD-012 UX terminology for readiness messages.
- BD-014 override authority, if any.

