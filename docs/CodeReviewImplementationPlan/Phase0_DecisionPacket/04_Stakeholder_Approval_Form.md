# Stakeholder Approval Form

Use this form to approve the recommended defaults or record approved alternatives.

## Decision ID: BD-001

**Business Question:**  
Which fields are required before an Event is considered ready for public registration?

**Recommended Default:**  
Require Account, Capacity, active Instance, Instance date/time, location/virtual details, program scope, and paid-event payment fields when applicable.

**Approve Recommended Default?**  
- [ ] Yes
- [ ] No

**If No, Approved Alternative:**  


**Approver:**  


**Approval Date:**  


**Notes:**  


## Decision ID: BD-001A

**Business Question:**  
Should missing Event Account block production-ready setup?

**Recommended Default:**  
Yes. Missing Account should block readiness.

**Approve Recommended Default?**  
- [ ] Yes
- [ ] No

**If No, Approved Alternative:**  


**Approver:**  


**Approval Date:**  


**Notes:**  


## Decision ID: BD-001B

**Business Question:**  
Which readiness issues are hard blockers versus soft warnings?

**Recommended Default:**  
Public/payment/data-integrity issues are hard blockers; cosmetic guidance is a soft warning.

**Approve Recommended Default?**  
- [ ] Yes
- [ ] No

**If No, Approved Alternative:**  


**Approver:**  


**Approval Date:**  


**Notes:**  


## Decision ID: BD-002

**Business Question:**  
Should missing Capacity always block readiness and launch?

**Recommended Default:**  
Yes. Capacity must be greater than zero where Capacity controls are expected.

**Approve Recommended Default?**  
- [ ] Yes
- [ ] No

**If No, Approved Alternative:**  


**Approver:**  


**Approval Date:**  


**Notes:**  


## Decision ID: BD-003

**Business Question:**  
Should paid events require both Payment Gateway and Accounting Department?

**Recommended Default:**  
Yes. Both fields should be hard blockers for paid events.

**Approve Recommended Default?**  
- [ ] Yes
- [ ] No

**If No, Approved Alternative:**  


**Approver:**  


**Approval Date:**  


**Notes:**  


## Decision ID: BD-003A

**Business Question:**  
Should Payment Gateway be required for paid events?

**Recommended Default:**  
Yes. Payment Gateway is a hard blocker for paid events.

**Approve Recommended Default?**  
- [ ] Yes
- [ ] No

**If No, Approved Alternative:**  


**Approver:**  


**Approval Date:**  


**Notes:**  


## Decision ID: BD-003B

**Business Question:**  
Should Accounting Department be required for paid events?

**Recommended Default:**  
Yes. Accounting Department is a hard blocker for paid events.

**Approve Recommended Default?**  
- [ ] Yes
- [ ] No

**If No, Approved Alternative:**  


**Approver:**  


**Approval Date:**  


**Notes:**  


## Decision ID: BD-004

**Business Question:**  
Which location fields are required by location type?

**Recommended Default:**  
Physical/offsite require title, address, map, building, and parking; online/virtual require meeting link/instructions.

**Approve Recommended Default?**  
- [ ] Yes
- [ ] No

**If No, Approved Alternative:**  


**Approver:**  


**Approval Date:**  


**Notes:**  


## Decision ID: BD-005

**Business Question:**  
Which sensitive fields must be reviewed when cloning?

**Recommended Default:**  
Require review/reset for payment gateway, accounting department, Opportunity creation, confirmation email, reminders, Capacity, location, parking, and public images.

**Approve Recommended Default?**  
- [ ] Yes
- [ ] No

**If No, Approved Alternative:**  


**Approver:**  


**Approval Date:**  


**Notes:**  


## Decision ID: BD-006

**Business Question:**  
Should standard users be allowed to update Registration Event without Instance?

**Recommended Default:**  
No. Standard users should select Instance; Event should be derived from the selected Instance.

**Approve Recommended Default?**  
- [ ] Yes
- [ ] No

**If No, Approved Alternative:**  


**Approver:**  


**Approval Date:**  


**Notes:**  


## Decision ID: BD-007

**Business Question:**  
Who may create public file links?

**Recommended Default:**  
Limit to FIU Events power users/admins through a custom permission.

**Approve Recommended Default?**  
- [ ] Yes
- [ ] No

**If No, Approved Alternative:**  


**Approver:**  


**Approval Date:**  


**Notes:**  


## Decision ID: BD-008

**Business Question:**  
Which public image file formats are allowed?

**Recommended Default:**  
Allow PNG, JPG/JPEG, GIF, WEBP; block SVG unless separately approved and sanitized.

**Approve Recommended Default?**  
- [ ] Yes
- [ ] No

**If No, Approved Alternative:**  


**Approver:**  


**Approval Date:**  


**Notes:**  


## Decision ID: BD-009

**Business Question:**  
How long should preview records and preview/public files live?

**Recommended Default:**  
Preview records should expire after 24 to 72 hours and be cleaned by a scheduled process.

**Approve Recommended Default?**  
- [ ] Yes
- [ ] No

**If No, Approved Alternative:**  


**Approver:**  


**Approval Date:**  


**Notes:**  


## Decision ID: BD-010

**Business Question:**  
What should happen to reminder data when registrations are cancelled or moved?

**Recommended Default:**  
Cancelled/moved registrations should clear or suppress stale reminder fields and be eligible for retry/recalculation only when current.

**Approve Recommended Default?**  
- [ ] Yes
- [ ] No

**If No, Approved Alternative:**  


**Approver:**  


**Approval Date:**  


**Notes:**  


## Decision ID: BD-011

**Business Question:**  
What should Pardot/Account Engagement treat as the source of truth for reminder eligibility?

**Recommended Default:**  
Salesforce registration status plus current Instance/date should determine eligibility.

**Approve Recommended Default?**  
- [ ] Yes
- [ ] No

**If No, Approved Alternative:**  


**Approver:**  


**Approval Date:**  


**Notes:**  


## Decision ID: BD-012

**Business Question:**  
How should Event versus Instance be explained in the UX?

**Recommended Default:**  
Use explicit labels: Event = program/configuration; Instance = date/session. Hide unnecessary selector when user has one record type.

**Approve Recommended Default?**  
- [ ] Yes
- [ ] No

**If No, Approved Alternative:**  


**Approver:**  


**Approval Date:**  


**Notes:**  


## Decision ID: BD-013

**Business Question:**  
What export, public-file, readiness override, and admin permissions should be separated?

**Recommended Default:**  
Separate normal app use, public file creation, export, readiness/admin override, and campaign/admin cleanup permissions.

**Approve Recommended Default?**  
- [ ] Yes
- [ ] No

**If No, Approved Alternative:**  


**Approver:**  


**Approval Date:**  


**Notes:**  


## Decision ID: BD-014

**Business Question:**  
Who can override readiness blockers, if anyone?

**Recommended Default:**  
No standard-user override. If needed, allow only a small admin/power-user group with audit expectation.

**Approve Recommended Default?**  
- [ ] Yes
- [ ] No

**If No, Approved Alternative:**  


**Approver:**  


**Approval Date:**  


**Notes:**  


