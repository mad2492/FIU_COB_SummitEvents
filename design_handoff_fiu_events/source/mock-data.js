/* eslint-disable no-undef */
/* Mock data for the FIU Events prototype */
window.MOCK = {
  programs: [
    { value: "", label: "All Programs" },
    { value: "MBA-FT",     label: "Full-Time MBA",                          dept: "Chapman", level: "Masters" },
    { value: "MBA-PT",     label: "Professional MBA",                       dept: "Chapman", level: "Masters" },
    { value: "MBA-ONLINE", label: "Online MBA",                             dept: "Chapman", level: "Masters" },
    { value: "EMBA",       label: "Executive MBA",                          dept: "Chapman", level: "Executive" },
    { value: "EMBA-HC",    label: "Executive MBA in Healthcare",            dept: "Chapman", level: "Executive" },
    { value: "MS-FIN",     label: "MS in Finance",                          dept: "Chapman", level: "Masters" },
    { value: "MS-FIN-CFA", label: "MS in Finance (CFA Track)",              dept: "Chapman", level: "Masters" },
    { value: "MS-MKT",     label: "MS in Marketing",                        dept: "Chapman", level: "Masters" },
    { value: "MS-IB",      label: "MS in International Business",           dept: "Chapman", level: "Masters" },
    { value: "MS-HRM",     label: "MS in Human Resource Management",        dept: "Chapman", level: "Masters" },
    { value: "MS-LSCM",    label: "MS in Logistics & Supply Chain Mgmt",    dept: "Chapman", level: "Masters" },
    { value: "MS-ACC",     label: "MS in Accounting",                       dept: "Chapman", level: "Masters" },
    { value: "MS-TAX",     label: "MS in Taxation",                         dept: "Chapman", level: "Masters" },
    { value: "MS-ANL",     label: "MS in Business Analytics",               dept: "Chapman", level: "Masters" },
    { value: "MS-RE",      label: "MS in Real Estate",                      dept: "Chapman", level: "Masters" },
    { value: "MS-HSPM",    label: "MS in Hospitality Management",           dept: "Chaplin", level: "Masters" },
    { value: "PHD-BUS",    label: "PhD in Business Administration",         dept: "Chapman", level: "Doctoral" },
    { value: "DBA",        label: "Doctor of Business Administration",      dept: "Chapman", level: "Doctoral" },
    { value: "CERT-DA",    label: "Certificate in Data Analytics",          dept: "EPE",     level: "Certificate" },
    { value: "CERT-PM",    label: "Certificate in Project Management",      dept: "EPE",     level: "Certificate" },
    { value: "CERT-LEAD",  label: "Certificate in Executive Leadership",    dept: "EPE",     level: "Certificate" },
    { value: "OGI",        label: "Office of Global Initiatives",           dept: "OGI",     level: "Other" }
  ],
  recordTypes: [
    { value: "RT_CHAP", label: "Chapman Events" },
    { value: "RT_EPE",  label: "EPE Events" },
    { value: "RT_OGI",  label: "OGI Events" }
  ],
  businessUnits: [
    { value: "BU_CHAP", label: "Chapman Graduate School" },
    { value: "BU_EPE",  label: "Executive and Professional Education" },
    { value: "BU_OGI",  label: "Office of Global Initiatives" }
  ],
  templates: [
    {
      value: "TPL_STANDARD",
      label: "Standard FIU Business",
      desc: "Clean institutional layout. Best for general-purpose events and webinars.",
      preview: { bg: "linear-gradient(135deg,#1a3865 0%,#0f2647 100%)", accent: "#FFC845" }
    },
    {
      value: "TPL_CHAPMAN",
      label: "Chapman Branded",
      desc: "Chapman School identity. Use for MBA, MS, and PhD recruiting events.",
      preview: { bg: "linear-gradient(135deg,#081E3F 0%,#B6862C 100%)", accent: "#B6862C" }
    },
    {
      value: "TPL_EXECUTIVE",
      label: "Executive Education",
      desc: "Premium feel for EMBA, Executive Briefings, and Certificate cohorts.",
      preview: { bg: "linear-gradient(135deg,#1f1f1f 0%,#3a3a3a 100%)", accent: "#C8A45A" }
    },
    {
      value: "TPL_GLOBAL",
      label: "Global Initiatives",
      desc: "Photo-led layout for Global Treks and international partnerships.",
      preview: { bg: "linear-gradient(135deg,#0a5d6e 0%,#13909e 100%)", accent: "#FFB347" }
    }
  ],
  eventTypes: [
    { value: "GRAD_REC", label: "Graduate Recruitment" },
    { value: "EXEC_ED",  label: "Executive Education" },
    { value: "ALUMNI",   label: "Alumni Engagement" },
    { value: "STUDENT",  label: "Current Student" },
    { value: "PARTNER",  label: "Corporate Partner" }
  ],
  categories: [
    { value: "INFO_SESSION", label: "Information Session", controller: "GRAD_REC" },
    { value: "OPEN_HOUSE",   label: "Open House",          controller: "GRAD_REC" },
    { value: "WEBINAR",      label: "Webinar",             controller: "GRAD_REC" },
    { value: "CERT_PROG",    label: "Certificate Program", controller: "EXEC_ED"  },
    { value: "EXEC_BRIEF",   label: "Executive Briefing",  controller: "EXEC_ED"  },
    { value: "REUNION",      label: "Reunion",             controller: "ALUMNI"   },
    { value: "NETWORKING",   label: "Networking",          controller: "ALUMNI"   }
  ],
  locationTypes: [
    { value: "On-site",    label: "On-site (Modesto Maidique Campus)" },
    { value: "Off-campus", label: "Off-campus" },
    { value: "Online",     label: "Online (Zoom / Teams)" },
    { value: "Hybrid",     label: "Hybrid" }
  ],
  paymentGateways: [
    { value: "TouchNet",  label: "TouchNet (FIU standard)" },
    { value: "Stripe",    label: "Stripe" },
    { value: "PayPal",    label: "PayPal" }
  ],
  accountingDepts: [
    { value: "ACC_GRAD", label: "Graduate Programs - 60001" },
    { value: "ACC_EPE",  label: "Executive Education - 60042" },
    { value: "ACC_OGI",  label: "Global Initiatives - 60055" }
  ],
  events: [
    { id:"E001", name:"MBA Spring 2026 Open House", recordType:"Chapman Events", status:"Active",  readiness:"Ready",     issue:"", startDate:"2026-03-12", endDate:"2026-03-12", program:"MBA",     instances:3,  registrations:147 },
    { id:"E002", name:"EMBA Info Session — Miami",   recordType:"Chapman Events", status:"Active",  readiness:"Ready",     issue:"", startDate:"2026-05-22", endDate:"2026-05-22", program:"EMBA",    instances:2,  registrations:84  },
    { id:"E003", name:"MS in Finance Webinar Series",recordType:"Chapman Events", status:"Active",  readiness:"Not Ready", issue:"Missing RSVP template banner image", startDate:"2026-06-04", endDate:"2026-08-27", program:"MS-FIN",  instances:6,  registrations:212 },
    { id:"E004", name:"Executive Briefing: AI in Finance",recordType:"EPE Events", status:"Draft",   readiness:"Not Ready", issue:"No instance created yet", startDate:"2026-07-10", endDate:"2026-07-10", program:"EPE",     instances:0,  registrations:0   },
    { id:"E005", name:"Global Trek - Madrid 2026",   recordType:"OGI Events",     status:"Active",  readiness:"Ready",     issue:"", startDate:"2026-10-04", endDate:"2026-10-12", program:"OGI",     instances:1,  registrations:38  },
    { id:"E006", name:"MS Marketing Coffee Chat",    recordType:"Chapman Events", status:"Active",  readiness:"Not Ready", issue:"Payment gateway not set",   startDate:"2026-04-18", endDate:"2026-04-18", program:"MS-MKT",  instances:1,  registrations:12  },
    { id:"E007", name:"Certificate in Data Analytics — Cohort 14", recordType:"EPE Events", status:"Active", readiness:"Ready", issue:"", startDate:"2026-09-08", endDate:"2026-12-12", program:"EPE", instances:1,  registrations:64 },
    { id:"E008", name:"Alumni Reunion 2026",         recordType:"Chapman Events", status:"Active",  readiness:"Ready",     issue:"", startDate:"2026-11-06", endDate:"2026-11-08", program:"MBA",     instances:1,  registrations:284 },
    { id:"E009", name:"MS-IB Application Workshop",  recordType:"Chapman Events", status:"Closed",  readiness:"Ready",     issue:"", startDate:"2025-11-15", endDate:"2025-11-15", program:"MS-IB",   instances:4,  registrations:98  }
  ],
  instances: [
    { id:"I001", title:"Spring 2026 Open House — May 12 (Evening)", eventId:"E001", eventName:"MBA Spring 2026 Open House", startDate:"2026-05-12T18:30:00", status:"Active",  readiness:"Ready", reason:"", capacity:120, registered:84, program:"MBA" },
    { id:"I002", title:"Spring 2026 Open House — May 14 (Lunch)",   eventId:"E001", eventName:"MBA Spring 2026 Open House", startDate:"2026-05-14T12:00:00", status:"Active",  readiness:"Ready", reason:"", capacity:80,  registered:42, program:"MBA" },
    { id:"I003", title:"Spring 2026 Open House — May 19 (Virtual)", eventId:"E001", eventName:"MBA Spring 2026 Open House", startDate:"2026-05-19T18:00:00", status:"Inactive", readiness:"Not Ready", reason:"Banner image not loaded", capacity:200, registered:21, program:"MBA" },
    { id:"I004", title:"EMBA Info Session — Coral Gables",          eventId:"E002", eventName:"EMBA Info Session — Miami",   startDate:"2026-05-22T19:00:00", status:"Active", readiness:"Ready", reason:"", capacity:60,  registered:58, program:"EMBA" },
    { id:"I005", title:"EMBA Info Session — Brickell",              eventId:"E002", eventName:"EMBA Info Session — Miami",   startDate:"2026-06-08T18:30:00", status:"Active", readiness:"Ready", reason:"", capacity:60,  registered:26, program:"EMBA" },
    { id:"I006", title:"MS Finance Webinar — Wave 1",               eventId:"E003", eventName:"MS in Finance Webinar Series",startDate:"2026-06-04T17:00:00", status:"Active", readiness:"Not Ready", reason:"Banner image URL is broken", capacity:500, registered:147, program:"MS-FIN" },
    { id:"I007", title:"MS Marketing Coffee Chat",                  eventId:"E006", eventName:"MS Marketing Coffee Chat",    startDate:"2026-04-18T10:00:00", status:"Active", readiness:"Not Ready", reason:"Paid event missing payment gateway", capacity:30, registered:12, program:"MS-MKT" },
    { id:"I008", title:"Madrid Trek — Cohort 14",                   eventId:"E005", eventName:"Global Trek - Madrid 2026",   startDate:"2026-10-04T08:00:00", status:"Active", readiness:"Ready", reason:"", capacity:24, registered:18, program:"OGI" }
  ],
  registrations: [
    { id:"R001", name:"REG-1024", contactName:"Maria Alvarez",     email:"malvar@fiu.edu",     event:"MBA Spring 2026 Open House", instance:"Spring 2026 Open House — May 12 (Evening)", instanceStart:"2026-05-12T18:30:00", locationType:"On-site", status:"Registered", program:"MBA" },
    { id:"R002", name:"REG-1025", contactName:"James Park",         email:"jpark@gmail.com",   event:"MBA Spring 2026 Open House", instance:"Spring 2026 Open House — May 12 (Evening)", instanceStart:"2026-05-12T18:30:00", locationType:"On-site", status:"Started",     program:"MBA" },
    { id:"R003", name:"REG-1026", contactName:"Priya Shah",         email:"pshah@fiu.edu",     event:"MBA Spring 2026 Open House", instance:"Spring 2026 Open House — May 14 (Lunch)",   instanceStart:"2026-05-14T12:00:00", locationType:"On-site", status:"Registered", program:"MBA" },
    { id:"R004", name:"REG-1027", contactName:"(Missing Contact)",  email:"unknown@unknown",   event:"EMBA Info Session — Miami",   instance:"EMBA Info Session — Coral Gables",          instanceStart:"2026-05-22T19:00:00", locationType:"On-site", status:"Started",     program:"EMBA", issue:true },
    { id:"R005", name:"REG-1028", contactName:"Daniel Chen",        email:"dchen@fiu.edu",     event:"EMBA Info Session — Miami",   instance:"EMBA Info Session — Coral Gables",          instanceStart:"2026-05-22T19:00:00", locationType:"On-site", status:"Registered", program:"EMBA" },
    { id:"R006", name:"REG-1029", contactName:"Sofia Hernandez",    email:"sherna@fiu.edu",    event:"MS in Finance Webinar Series",instance:"MS Finance Webinar — Wave 1",                instanceStart:"2026-06-04T17:00:00", locationType:"Online", status:"Registered", program:"MS-FIN" },
    { id:"R007", name:"REG-1030", contactName:"Aaron Goldberg",     email:"agold@fiu.edu",     event:"MS in Finance Webinar Series",instance:"MS Finance Webinar — Wave 1",                instanceStart:"2026-06-04T17:00:00", locationType:"Online", status:"Cancelled",  program:"MS-FIN" },
    { id:"R008", name:"REG-1031", contactName:"Lin Zhao",           email:"lzhao@fiu.edu",     event:"Global Trek - Madrid 2026",   instance:"Madrid Trek — Cohort 14",                    instanceStart:"2026-10-04T08:00:00", locationType:"Off-campus", status:"Registered", program:"OGI" },
    { id:"R009", name:"REG-1032", contactName:"Carlos Mendez",      email:"cmend@fiu.edu",     event:"MS Marketing Coffee Chat",    instance:"MS Marketing Coffee Chat",                   instanceStart:"2026-04-18T10:00:00", locationType:"On-site", status:"Started", program:"MS-MKT" }
  ]
};
