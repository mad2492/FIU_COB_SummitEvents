public with sharing class FiuReadinessPolicyService {
    public static final String SEVERITY_BLOCKER = 'Blocker';
    public static final String SEVERITY_WARNING = 'Warning';
    public static final String SEVERITY_INFO = 'Info';

    public static final String RECORD_TYPE_EVENT = 'Event';
    public static final String RECORD_TYPE_INSTANCE = 'Instance';
    public static final String PROGRAM_OF_INTEREST_LABEL = 'Program of Interest';

    public class ReadinessIssue {
        @AuraEnabled public String severity;
        @AuraEnabled public String code;
        @AuraEnabled public String message;
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public Id recordId;
        @AuraEnabled public String recordType;
        @AuraEnabled public Boolean blocking;
    }

    public class ReadinessResult {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String recordType;
        @AuraEnabled public Boolean ready = true;
        @AuraEnabled public List<ReadinessIssue> issues = new List<ReadinessIssue>();

        public void addIssue(String severity, String code, String message, String fieldApiName, Id issueRecordId, String issueRecordType, Boolean blocking) {
            ReadinessIssue issue = new ReadinessIssue();
            issue.severity = String.isBlank(severity) ? SEVERITY_WARNING : severity;
            issue.code = code;
            issue.message = message;
            issue.fieldApiName = fieldApiName;
            issue.recordId = issueRecordId;
            issue.recordType = issueRecordType;
            issue.blocking = blocking == true;
            issues.add(issue);
            if (issue.blocking) ready = false;
        }

        public Boolean hasBlockingIssues() {
            for (ReadinessIssue issue : issues) {
                if (issue != null && issue.blocking == true) return true;
            }
            return false;
        }

        public List<String> blockingMessages() {
            List<String> messages = new List<String>();
            for (ReadinessIssue issue : issues) {
                if (issue != null && issue.blocking == true && !String.isBlank(issue.message)) {
                    messages.add(issue.message);
                }
            }
            return messages;
        }

        public List<String> allMessages() {
            List<String> messages = new List<String>();
            for (ReadinessIssue issue : issues) {
                if (issue != null && !String.isBlank(issue.message)) messages.add(issue.message);
            }
            return messages;
        }
    }

    public class EventPolicyContext {
        public String eventCapacityField;
        public String instanceCapacityField;
        public List<SObject> relatedInstances;
        public FiuProgramFilterService.ProgramFilterConfig programConfig;
        public Integer relatedQuestionCount;
        public Boolean includeAccountCheck = true;
        public Boolean includeEventCapacityCheck = true;
        public Boolean includeProgramCheck = false;
        public Boolean includeProgramPickerLabelCheck = true;
        public Boolean includeQuestionCheck = true;
        public Boolean includeRichTextImageCheck = true;
        public Boolean includeRelatedInstancePresenceCheck = false;
        public Boolean includeRelatedInstanceCapacityCheck = false;
    }

    public class InstancePolicyContext {
        public String instanceCapacityField;
        public Boolean includeCapacityCheck = true;
        public Boolean includeOperationalChecks = true;
        public Boolean includeLocationChecks = true;
        public Boolean includeParentEventChecks = true;
    }

    public static ReadinessResult evaluateEvent(SObject eventRecord, EventPolicyContext context) {
        ReadinessResult result = baseResult(eventRecord, RECORD_TYPE_EVENT);
        if (eventRecord == null) {
            result.ready = false;
            result.addIssue(SEVERITY_BLOCKER, 'EVENT_NOT_FOUND', 'Event record not found', null, null, RECORD_TYPE_EVENT, true);
            return result;
        }

        EventPolicyContext safeContext = context == null ? new EventPolicyContext() : context;
        Id eventId = safeId(eventRecord);
        result.recordId = eventId;

        if (safeContext.includeAccountCheck == true && safeGet(eventRecord, 'summit__Account__c') == null) {
            result.addIssue(SEVERITY_BLOCKER, 'EVENT_MISSING_ACCOUNT', 'Missing account', 'summit__Account__c', eventId, RECORD_TYPE_EVENT, true);
        }

        String eventCapacityField = String.isBlank(safeContext.eventCapacityField)
            ? resolveOptionalField(eventRecord, new List<String>{ 'summit__Capacity__c', 'Capacity__c' })
            : safeContext.eventCapacityField;
        if (safeContext.includeEventCapacityCheck == true && !String.isBlank(eventCapacityField)) {
            Decimal capacity = safeDecimal(eventRecord, eventCapacityField);
            if (capacity == null || capacity <= 0) {
                result.addIssue(SEVERITY_BLOCKER, 'EVENT_MISSING_CAPACITY', 'Missing capacity', eventCapacityField, eventId, RECORD_TYPE_EVENT, true);
            }
        }

        if (safeContext.includeProgramCheck == true) {
            FiuProgramFilterService.ProgramFilterConfig programConfig = safeContext.programConfig == null
                ? FiuProgramFilterService.getConfig()
                : safeContext.programConfig;
            Boolean includesMultiple = (Boolean) safeGet(eventRecord, 'Includes_Multiple_Programs__c');
            Boolean hasDefaultPlan = safeGet(eventRecord, 'Default_Plan__c') != null;
            Boolean hasProgramFilterCodes = !FiuProgramFilterService.extractProgramCodesFromEvent(eventRecord, programConfig).isEmpty();
            if (includesMultiple == true) {
                if (!hasProgramFilterCodes && !hasDefaultPlan) {
                    result.addIssue(SEVERITY_BLOCKER, 'EVENT_MISSING_PROGRAM', 'Missing selected program', null, eventId, RECORD_TYPE_EVENT, true);
                }
            } else if (!hasDefaultPlan && !hasProgramFilterCodes) {
                result.addIssue(SEVERITY_BLOCKER, 'EVENT_MISSING_PROGRAM', 'Missing selected program', null, eventId, RECORD_TYPE_EVENT, true);
            }

            String programQuestionTextField = resolveOptionalField(eventRecord, new List<String>{ 'summit__Add_Info_Question_Text_1__c' });
            String programQuestionShortPicklistField = resolveOptionalField(eventRecord, new List<String>{ 'summit__Add_Info_Question_Pick_List_1__c' });
            String programQuestionLongPicklistField = resolveOptionalField(eventRecord, new List<String>{ 'summit__Add_Info_Question_Pick_List_Long_1__c' });
            if (
                safeContext.includeProgramPickerLabelCheck == true &&
                !String.isBlank(programQuestionTextField) &&
                includesMultiple == true
            ) {
                String questionLabel = (String) safeGet(eventRecord, programQuestionTextField);
                if (questionLabel != PROGRAM_OF_INTEREST_LABEL) {
                    result.addIssue(
                        SEVERITY_BLOCKER,
                        'EVENT_PROGRAM_PICKER_LABEL_MISMATCH',
                        'Program-routed registrations require Additional Question 1 to be labeled "Program of Interest".',
                        programQuestionTextField,
                        eventId,
                        RECORD_TYPE_EVENT,
                        true
                    );
                }
                Boolean hasProgramPickerOptions =
                    !String.isBlank((String) safeGet(eventRecord, programQuestionLongPicklistField));
                if (!hasProgramPickerOptions) {
                    result.addIssue(
                        SEVERITY_BLOCKER,
                        'EVENT_PROGRAM_PICKER_OPTIONS_MISSING',
                        'Program-routed registrations require Program of Interest choices in Additional Question 1.',
                        programQuestionLongPicklistField,
                        eventId,
                        RECORD_TYPE_EVENT,
                        true
                    );
                }
            }
        }

        if (safeContext.includeQuestionCheck == true) {
            String customQuestionTitle = (String) safeGet(eventRecord, 'summit__Event_Additional_Question_Title__c');
            String customQuestionDescription = (String) safeGet(eventRecord, 'summit__Event_Additional_Questions_Description__c');
            Boolean hasCustomQuestionPageDetails = !String.isBlank(customQuestionTitle) || !String.isBlank(customQuestionDescription);
            Integer questionCount = safeContext.relatedQuestionCount == null ? 0 : safeContext.relatedQuestionCount;
            if (hasCustomQuestionPageDetails && questionCount == 0) {
                result.addIssue(
                    SEVERITY_BLOCKER,
                    'EVENT_CUSTOM_QUESTIONS_MISSING',
                    'Custom questions details set but no related Summit Event Questions',
                    null,
                    eventId,
                    RECORD_TYPE_EVENT,
                    true
                );
            }
        }

        if (safeContext.includeRichTextImageCheck == true) {
            for (String warning : collectRichTextImageWarnings(eventRecord)) {
                result.addIssue(SEVERITY_BLOCKER, 'EVENT_PRIVATE_RICH_TEXT_IMAGE', warning, null, eventId, RECORD_TYPE_EVENT, true);
            }
        }

        Boolean hasRelatedInstances = safeContext.relatedInstances != null && !safeContext.relatedInstances.isEmpty();
        if (safeContext.includeRelatedInstancePresenceCheck == true && !hasRelatedInstances) {
            result.addIssue(SEVERITY_BLOCKER, 'EVENT_NO_INSTANCES', 'No instances configured', null, eventId, RECORD_TYPE_EVENT, true);
        }

        if (safeContext.includeRelatedInstanceCapacityCheck == true && hasRelatedInstances && !String.isBlank(safeContext.instanceCapacityField)) {
            Boolean hasCapacityIssue = false;
            for (SObject instanceRow : safeContext.relatedInstances) {
                Decimal capacity = safeDecimal(instanceRow, safeContext.instanceCapacityField);
                if (capacity == null || capacity <= 0) {
                    hasCapacityIssue = true;
                    break;
                }
            }
            if (hasCapacityIssue) {
                result.addIssue(SEVERITY_BLOCKER, 'EVENT_RELATED_INSTANCE_MISSING_CAPACITY', 'Instance missing capacity', safeContext.instanceCapacityField, eventId, RECORD_TYPE_EVENT, true);
            }
        }

        return result;
    }

    public static ReadinessResult evaluateInstance(SObject instanceRecord, SObject parentEventRecord, InstancePolicyContext context) {
        ReadinessResult result = baseResult(instanceRecord, RECORD_TYPE_INSTANCE);
        if (instanceRecord == null) {
            result.ready = false;
            result.addIssue(SEVERITY_BLOCKER, 'INSTANCE_NOT_FOUND', 'Instance record not found', null, null, RECORD_TYPE_INSTANCE, true);
            return result;
        }

        InstancePolicyContext safeContext = context == null ? new InstancePolicyContext() : context;
        Id instanceId = safeId(instanceRecord);
        result.recordId = instanceId;

        Date startDate = (Date) safeGet(instanceRecord, 'summit__Instance_Start_Date__c');
        Date today = Date.today();
        Boolean isPast = startDate != null && startDate < today;

        if (safeContext.includeOperationalChecks == true) {
            if (!isPast && (String) safeGet(instanceRecord, 'summit__Active_Status__c') != 'Active') {
                result.addIssue(SEVERITY_BLOCKER, 'INSTANCE_NOT_ACTIVE', 'Not Active', 'summit__Active_Status__c', instanceId, RECORD_TYPE_INSTANCE, true);
            }
            if (!isPast && (Boolean) safeGet(instanceRecord, 'summit__Open_Registration__c') == false) {
                result.addIssue(SEVERITY_BLOCKER, 'INSTANCE_REGISTRATION_CLOSED', 'Registration closed', 'summit__Open_Registration__c', instanceId, RECORD_TYPE_INSTANCE, true);
            }
        }

        String instanceCapacityField = String.isBlank(safeContext.instanceCapacityField)
            ? resolveOptionalField(instanceRecord, new List<String>{ 'summit__Capacity__c', 'Capacity__c' })
            : safeContext.instanceCapacityField;
        if (safeContext.includeCapacityCheck == true && !String.isBlank(instanceCapacityField)) {
            Decimal capacity = safeDecimal(instanceRecord, instanceCapacityField);
            if (capacity == null || capacity <= 0) {
                result.addIssue(SEVERITY_BLOCKER, 'INSTANCE_MISSING_CAPACITY', 'Missing capacity', instanceCapacityField, instanceId, RECORD_TYPE_INSTANCE, true);
            }
        }

        if (safeContext.includeLocationChecks == true) {
            if (safeGet(instanceRecord, 'summit__Location_Title_Override__c') == null) {
                result.addIssue(SEVERITY_BLOCKER, 'INSTANCE_MISSING_LOCATION_TITLE', 'Missing location title', 'summit__Location_Title_Override__c', instanceId, RECORD_TYPE_INSTANCE, true);
            }
            if (safeGet(instanceRecord, 'summit__Location_Address_Override__c') == null) {
                result.addIssue(SEVERITY_BLOCKER, 'INSTANCE_MISSING_LOCATION_ADDRESS', 'Missing location address', 'summit__Location_Address_Override__c', instanceId, RECORD_TYPE_INSTANCE, true);
            }
            if (safeGet(instanceRecord, 'summit__Location_Map_Link_Override__c') == null) {
                result.addIssue(SEVERITY_BLOCKER, 'INSTANCE_MISSING_LOCATION_MAP_LINK', 'Missing location map link', 'summit__Location_Map_Link_Override__c', instanceId, RECORD_TYPE_INSTANCE, true);
            }
            if (safeGet(instanceRecord, 'Parking_info__c') == null) {
                result.addIssue(SEVERITY_BLOCKER, 'INSTANCE_MISSING_PARKING_INFO', 'Missing parking info', 'Parking_info__c', instanceId, RECORD_TYPE_INSTANCE, true);
            }
        }

        if (safeContext.includeParentEventChecks == true && parentEventRecord != null) {
            Id parentEventId = safeId(parentEventRecord);
            if (safeGet(parentEventRecord, 'summit__Account__c') == null) {
                result.addIssue(SEVERITY_BLOCKER, 'PARENT_EVENT_MISSING_ACCOUNT', 'Parent event missing account', 'summit__Account__c', parentEventId, RECORD_TYPE_EVENT, true);
            }
            String gateway = (String) safeGet(parentEventRecord, 'summit__Payment_Gateway__c');
            if (!String.isBlank(gateway) && gateway != 'No Gateway' && safeGet(parentEventRecord, 'Accounting_Department__c') == null) {
                result.addIssue(SEVERITY_BLOCKER, 'PARENT_PAID_EVENT_MISSING_ACCOUNTING_DEPARTMENT', 'Paid event missing accounting department', 'Accounting_Department__c', parentEventId, RECORD_TYPE_EVENT, true);
            }
        }

        return result;
    }

    public static List<String> collectRichTextImageWarnings(SObject eventRecord) {
        List<String> warnings = new List<String>();
        List<String> affectedFields = new List<String>();
        for (String fieldApiName : new List<String>{
            'summit__Event_description__c',
            'summit__Event_Short_Listing_Description__c',
            'summit__Event_Footer__c',
            'summit__Event_Full_Text__c',
            'summit__Event_Additional_Questions_Description__c',
            'summit__Event_Confirmation_Description__c'
        }) {
            if (hasSalesforceHostedRichTextImage((String) safeGet(eventRecord, fieldApiName))) {
                affectedFields.add(fieldApiName);
            }
        }
        if (!affectedFields.isEmpty()) {
            warnings.add(
                'Summit Events 0.37 removes Guest User sharing to Event records. Verify embedded images in these rich text fields use public links before launch: ' +
                String.join(affectedFields, ', ')
            );
        }
        return warnings;
    }

    public static Boolean hasSalesforceHostedRichTextImage(String htmlValue) {
        if (String.isBlank(htmlValue)) return false;
        String normalized = htmlValue.toLowerCase();
        if (!normalized.contains('<img')) return false;
        return normalized.contains('/servlet/rtaimage') ||
            normalized.contains('/sfc/servlet.shepherd') ||
            normalized.contains('/servlet/servlet.filedownload') ||
            normalized.contains('/servlet/filefield') ||
            normalized.contains('documentforce.com') ||
            normalized.contains('file.force.com');
    }

    public static String resolveOptionalField(SObject record, List<String> candidates) {
        if (record == null || candidates == null) return null;
        Map<String, Schema.SObjectField> fields = record.getSObjectType().getDescribe().fields.getMap();
        for (String fieldApiName : candidates) {
            if (fields.containsKey(fieldApiName)) return fieldApiName;
        }
        return null;
    }

    public static Object safeGet(SObject record, String fieldApiName) {
        if (record == null || String.isBlank(fieldApiName)) return null;
        try {
            return record.get(fieldApiName);
        } catch (Exception ex) {
            return null;
        }
    }

    private static ReadinessResult baseResult(SObject record, String recordType) {
        ReadinessResult result = new ReadinessResult();
        result.recordType = recordType;
        result.recordId = safeId(record);
        result.ready = true;
        result.issues = new List<ReadinessIssue>();
        return result;
    }

    private static Id safeId(SObject record) {
        Object rawId = safeGet(record, 'Id');
        return rawId == null ? null : (Id) rawId;
    }

    private static Decimal safeDecimal(SObject record, String fieldApiName) {
        Object raw = safeGet(record, fieldApiName);
        if (raw == null) return null;
        if (raw instanceof Decimal) return (Decimal) raw;
        try {
            return Decimal.valueOf(String.valueOf(raw));
        } catch (Exception ex) {
            return null;
        }
    }

}
