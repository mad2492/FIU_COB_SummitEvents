# Data Collection Template

Updated from Prod discovery snapshot on 2026-05-02. Supporting raw extracts are in `docs/discovery/`.

## 1. Event-Level Required Fields
| Field Label | API Name | Required When | Why Required | What Breaks If Missing |
|---|---|---|---|---|
| Payment Gateway | summit__Payment_Gateway__c | payment needed | payment setup | payment cannot work |
| Accounting Department | Accounting_Department__c | payment needed | payment setup | payment cannot work |
| Account | summit__Account__c | always / public site | public site auth | authorization error |
| Create Opps From Regs | FIU_Create_Opps_From_Regs__c | when relevant | controls opp creation | unwanted or missing opps |
| Send Registration Confirmation Email | Send_Registration_Confirmation_Email__c | when relevant | controls dynamic email flow | email behavior differs |

## 2. Instance-Level Required Fields
| Field Label | API Name | Required When | Why Required | What Breaks If Missing |
|---|---|---|---|---|
| Event | summit__Event__c | always | parent/child data model | instance cannot be created |
| Attendee List | summit__Attendee_List__c | always (default/explicit) | managed package required flag | instance save validation fails |
| Private Instance | summit__Private_Instance__c | always (default/explicit) | managed package required flag | instance save validation fails |

## 3. Registration-Level Required Fields
| Field Label | API Name | Required When | Why Required | What Breaks If Missing |
|---|---|---|---|---|
| Event Instance | summit__Event_Instance__c | always | ties registration to occurrence | registration cannot be created |
| Display Attendance Publicly | summit__Display_Attendance_Publicly__c | always (default/explicit) | required platform/package flag | save validation fails |
| Terms and Conditions | Terms_and_Conditions__c | always (default/explicit) | required compliance flag | save validation fails |

## 4. Active Automations
| Type | API Name | Entry Object | Purpose | Known Risks |
|---|---|---|---|---|
| Record-Triggered Flow | FIU Summit Events Registration - After Create | Registration | FIU registration orchestration | high coupling to downstream email/opportunity logic |
| Subflow | SubFlow - FIU Summit Event Reg Send Emails | registration/email | dynamic confirmation email | template/content branching complexity |
| Screen Flow | New Summit Events Reminder Screen | Event Instance launch | guided reminder creation | user input quality |
| Auto-launched Flow | Summit Events Reminder Emails | reminder records | reminder processing | volume sensitivity |
| Auto-launched Flow | Summit Events Reminders - Schedule Reminders ApexScheduler | scheduler/reminder | daily reminder scheduling | depends on upstream data and schedules |
| Auto-launched Flow | Summit Events Payment Received - After Save | payment object | payment lifecycle updates | payment dependency regressions |

## 5. Top User Journeys
### Journey 1
- Name: Create a new paid event with first instance
- User: Event manager
- Current steps: Manage parent event, then instance, then reminder/payment checks
- Common mistakes: Missing account/payment setup flags
- Desired future experience: Guided create with readiness checks before activation

### Journey 2
- Name: Re-run an existing event
- User: Recruiter/event coordinator
- Current steps: Manual clone/copy and field cleanup
- Common mistakes: Inheriting unsafe payment/opportunity/email settings without review
- Desired future experience: Guided clone with explicit risk review and confirmation

## 6. Permissions
- Recruiters: Pending role matrix confirmation from profile/permset inventory
- Event managers: Pending role matrix confirmation from profile/permset inventory
- Admins: Pending role matrix confirmation from profile/permset inventory
- OGI users: Pending role matrix confirmation from profile/permset inventory
- Raw Summit tab access: Pending final policy decision in Phase 1 rollout
