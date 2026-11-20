# Implementation Blockers by Decision

## Blocks Shared Readiness Policy Service

| Decision ID | What cannot safely be implemented until decided | Why | Recommended fallback if stakeholders do not respond |
|---|---|---|---|
| BD-001 | Full readiness rule set. | The policy service needs to know which fields are blockers. | Implement only Capacity blocker first and leave other checks as warnings/documented assumptions. |
| BD-001A | Account readiness check. | Missing Account may or may not be considered launch-blocking by stakeholders. | Treat missing Account as a soft warning until approved. |
| BD-001B | Blocker versus warning response model. | The policy DTO needs to distinguish blockers from warnings. | Build the model with both categories, but enforce only approved blockers. |
| BD-004 | Location-type readiness branch. | Physical and virtual requirements differ. | Keep location checks as warnings except clearly missing date/time/Capacity. |
| BD-012 | Event/Instance terminology in readiness messages. | User-facing reason text needs business-approved language. | Use plain labels: Event and Instance, with no extra department-specific wording. |
| BD-014 | Override behavior. | The policy needs to know whether blockers can be bypassed. | No override for standard users. |

## Blocks Capacity Blocker Implementation

| Decision ID | What cannot safely be implemented until decided | Why | Recommended fallback if stakeholders do not respond |
|---|---|---|---|
| BD-002 | Whether missing/zero Capacity blocks readiness. | Capacity was identified as a showstopper, but business approval confirms enforcement. | Implement Capacity as a hard blocker because it is the recommended first code pass and highest-confidence rule. |
| BD-001B | Whether Capacity is hard blocker or soft warning. | UI and Apex behavior differ depending on severity. | Treat Capacity as hard blocker. |

## Blocks Paid Event Validation Implementation

| Decision ID | What cannot safely be implemented until decided | Why | Recommended fallback if stakeholders do not respond |
|---|---|---|---|
| BD-003 | Combined paid-event validation. | Payment and accounting rules must match finance policy. | Treat both fields as blockers for paid events in readiness, but hold clone/payment UX changes. |
| BD-003A | Payment Gateway requirement. | Paid checkout depends on gateway routing. | Treat as hard blocker. |
| BD-003B | Accounting Department requirement. | Finance reconciliation depends on department. | Treat as hard blocker. |
| BD-014 | Override authority. | Payment blockers should not be bypassable by standard users. | No standard-user override. |

## Blocks Clone Warning Implementation

| Decision ID | What cannot safely be implemented until decided | Why | Recommended fallback if stakeholders do not respond |
|---|---|---|---|
| BD-005 | Which cloned fields require explicit review/reset. | Clone warnings are only useful if the sensitive fields are agreed. | Show non-blocking review warnings for all recommended fields. |
| BD-003 | Paid event clone behavior. | Paid Event clones are highest risk. | Require paid setting review before clone save. |
| BD-009 | Public/preview file behavior in clones. | Cloned public files may carry old links. | Warn and require users to re-check public content. |
| BD-012 | Clone wording around Event versus Instance. | Users need to understand whether they are cloning configuration or dated sessions. | Use plain Event/Instance labels. |

## Blocks Public File Lifecycle/Security Hardening

| Decision ID | What cannot safely be implemented until decided | Why | Recommended fallback if stakeholders do not respond |
|---|---|---|---|
| BD-007 | Who can create public file links. | Public ContentDistribution creation is sensitive. | Limit to admins/power users through existing custom permission. |
| BD-008 | Allowed public image formats. | File validation needs an allowlist. | Allow PNG, JPG/JPEG, GIF, WEBP; block SVG. |
| BD-009 | Preview/public file cleanup window. | Lifecycle controls need a retention policy. | Use 72 hours for previews and document that public assets created for final content remain until replaced/revoked. |

## Blocks Reminder Cleanup/Pardot Data Consistency Work

| Decision ID | What cannot safely be implemented until decided | Why | Recommended fallback if stakeholders do not respond |
|---|---|---|---|
| BD-010 | Cancelled/moved registration reminder cleanup. | Code needs to know whether to clear, suppress, or retain fields. | Suppress reminders for cancelled/moved registrations and document stale fields as a known risk. |
| BD-011 | Account Engagement source of truth. | Integration rules must match marketing automation expectations. | Treat Salesforce status + current Instance/date as source of truth. |
| BD-006 | Registration reassignment behavior. | Moving registrations affects reminder eligibility. | Derive Event from Instance and block Event-only reassignment for standard users. |

## Blocks Permission/FLS Hardening

| Decision ID | What cannot safely be implemented until decided | Why | Recommended fallback if stakeholders do not respond |
|---|---|---|---|
| BD-007 | Public file permission boundary. | Public link creation should not be available to all app users. | Keep custom permission and limit assignment. |
| BD-013 | Permission split model. | Metadata changes need an approved least-privilege model. | Split only the highest-risk permissions first: public files, exports, readiness override. |
| BD-014 | Readiness override permission. | Override behavior should not accidentally be granted broadly. | No override permission in first implementation. |
| BD-006 | Registration reassignment permission. | Event-only reassignment may need admin-only permission. | Block Event-only reassignment for standard users. |

## Blocks UAT Readiness Signoff

| Decision ID | What cannot safely be signed off until decided | Why | Recommended fallback if stakeholders do not respond |
|---|---|---|---|
| BD-001 | UAT readiness checklist. | Testers need to know expected blockers. | Test only approved Capacity blocker first. |
| BD-002 | Capacity UAT scenarios. | Capacity behavior is a required manual QA scenario. | Treat as hard blocker. |
| BD-003 | Paid Event UAT scenarios. | Paid Event validation affects checkout readiness. | Mark paid Event validation as pending business approval. |
| BD-004 | Location/virtual UAT scenarios. | Testers need expected physical versus virtual behavior. | Test physical/virtual separately as warnings until approved. |
| BD-005 | Clone UAT scenarios. | Clone review requirements need explicit acceptance criteria. | Defer clone warning implementation. |
| BD-007 | Public file UAT permissions. | Testers need known users with/without permission. | Use Salesforce admins/power users only. |
| BD-010 | Reminder UAT scenarios. | Reminder behavior can affect external campaigns. | Mark reminder cleanup as out of first code pass. |
| BD-012 | UX signoff. | User labels and filters need business acceptance. | Use explicit Event/Instance labels. |
| BD-013 | Permission UAT. | Least-privilege testing depends on approved permission roles. | Use minimal existing app user and admin personas. |

