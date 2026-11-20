public with sharing class FiuEventsReadinessService {
    public class ReadinessResult {
        @AuraEnabled public Boolean ready = true;
        @AuraEnabled public List<String> warnings = new List<String>();
        @AuraEnabled public List<String> missingFields = new List<String>();
    }

    @AuraEnabled(cacheable=true)
    public static ReadinessResult evaluateEvent(Id eventId) {
        if (eventId == null) {
            throw new AuraHandledException('Event Id is required.');
        }

        String eventObject = FiuEventsAccessService.resolveEventObject();
        if (eventObject == null) {
            throw new AuraHandledException('No Summit Event object found in this org.');
        }

        Set<Id> allowedRecordTypes = FiuEventsAccessService.getAllowedEventRecordTypeIds();
        if (allowedRecordTypes.isEmpty()) {
            throw new AuraHandledException('You do not have access to any FIU Event record types.');
        }

        Map<String, Schema.SObjectField> eventFields = Schema.getGlobalDescribe().get(eventObject).getDescribe().fields.getMap();
        List<String> selectFields = new List<String>{ 'Id', 'Name', 'RecordTypeId' };
        addFieldIfPresent(selectFields, eventFields, 'summit__Account__c');
        addFieldIfPresent(selectFields, eventFields, 'summit__Capacity__c');
        addFieldIfPresent(selectFields, eventFields, 'summit__Payment_Gateway__c');
        addFieldIfPresent(selectFields, eventFields, 'Accounting_Department__c');
        addFieldIfPresent(selectFields, eventFields, 'FIU_Create_Opps_From_Regs__c');
        addFieldIfPresent(selectFields, eventFields, 'Send_Registration_Confirmation_Email__c');
        addFieldIfPresent(selectFields, eventFields, 'summit__Event_Additional_Question_Title__c');
        addFieldIfPresent(selectFields, eventFields, 'summit__Event_Additional_Questions_Description__c');
        addFieldIfPresent(selectFields, eventFields, 'summit__Event_description__c');
        addFieldIfPresent(selectFields, eventFields, 'summit__Event_Short_Listing_Description__c');
        addFieldIfPresent(selectFields, eventFields, 'summit__Event_Footer__c');
        addFieldIfPresent(selectFields, eventFields, 'summit__Event_Full_Text__c');
        addFieldIfPresent(selectFields, eventFields, 'summit__Event_Confirmation_Description__c');
        String soql = 'SELECT ' + String.join(selectFields, ',') + ' FROM ' + eventObject + ' WHERE Id = :eventId AND RecordTypeId IN :allowedRecordTypes LIMIT 1';
        SObject eventRecord = Database.query(soql);
        Integer questionCount = 0;
        String questionObject = FiuEventsAccessService.resolveEventQuestionObject();
        String questionEventLookup = FiuEventsAccessService.resolveEventQuestionLookupField();
        if (questionObject != null && questionEventLookup != null) {
            try {
                String countSoql = 'SELECT COUNT() FROM ' + questionObject + ' WHERE ' + questionEventLookup + ' = :eventId';
                questionCount = Integer.valueOf(Database.countQuery(countSoql));
            } catch (Exception ex) {
                questionCount = 0;
            }
        }
        return evaluateEventRecord(eventRecord, questionCount);
    }

    public static ReadinessResult evaluateEventRecord(SObject eventRecord) {
        return evaluateEventRecord(eventRecord, null);
    }

    public static ReadinessResult evaluateEventRecord(SObject eventRecord, Integer relatedQuestionCount) {
        ReadinessResult result = new ReadinessResult();
        if (eventRecord == null) {
            result.ready = false;
            result.missingFields.add('Event record not found');
            return result;
        }

        FiuReadinessPolicyService.EventPolicyContext context = new FiuReadinessPolicyService.EventPolicyContext();
        context.eventCapacityField = FiuReadinessPolicyService.resolveOptionalField(eventRecord, new List<String>{ 'summit__Capacity__c', 'Capacity__c' });
        context.relatedQuestionCount = relatedQuestionCount;
        context.includeProgramCheck = false;
        context.includeRelatedInstancePresenceCheck = false;
        context.includeRelatedInstanceCapacityCheck = false;

        FiuReadinessPolicyService.ReadinessResult policyResult = FiuReadinessPolicyService.evaluateEvent(eventRecord, context);
        for (FiuReadinessPolicyService.ReadinessIssue issue : policyResult.issues) {
            if (issue == null) continue;
            Boolean legacyBlockingIssue = issue.code == 'EVENT_MISSING_ACCOUNT' || issue.code == 'EVENT_MISSING_CAPACITY';
            if (issue.blocking == true && legacyBlockingIssue) result.ready = false;
            if (!String.isBlank(issue.fieldApiName) && issue.blocking == true && legacyBlockingIssue && !result.missingFields.contains(issue.fieldApiName)) {
                result.missingFields.add(issue.fieldApiName);
            }
            if (!String.isBlank(issue.message)) result.warnings.add(toLegacyMessage(issue));
        }

        Boolean hasGateway = safeGet(eventRecord, 'summit__Payment_Gateway__c') != null;
        Boolean hasAccountingDept = safeGet(eventRecord, 'Accounting_Department__c') != null;
        if (!hasGateway || !hasAccountingDept) {
            result.warnings.add('If this event accepts payment, set Payment Gateway and Accounting Department before launch.');
        }

        if ((Boolean) safeGet(eventRecord, 'FIU_Create_Opps_From_Regs__c') == true) {
            result.warnings.add('Opportunity creation is enabled for registrations. Confirm this before go-live.');
        }

        if ((Boolean) safeGet(eventRecord, 'Send_Registration_Confirmation_Email__c') == true) {
            result.warnings.add('FIU dynamic registration confirmation email flow is enabled. Confirm content path expectations.');
        }

        return result;
    }

    public static List<String> collectRichTextImageWarnings(SObject eventRecord) {
        return FiuReadinessPolicyService.collectRichTextImageWarnings(eventRecord);
    }

    public static Boolean hasSalesforceHostedRichTextImage(String htmlValue) {
        return FiuReadinessPolicyService.hasSalesforceHostedRichTextImage(htmlValue);
    }

    private static Object safeGet(SObject record, String fieldApiName) {
        try {
            return record.get(fieldApiName);
        } catch (Exception ex) {
            return null;
        }
    }

    private static void addFieldIfPresent(List<String> selectFields, Map<String, Schema.SObjectField> fieldMap, String fieldApiName) {
        if (fieldMap.containsKey(fieldApiName)) {
            selectFields.add(fieldApiName);
        }
    }

    private static String toLegacyMessage(FiuReadinessPolicyService.ReadinessIssue issue) {
        if (issue == null) return null;
        if (issue.code == 'EVENT_MISSING_ACCOUNT') {
            return 'Account is required to avoid external-site authorization issues.';
        }
        if (issue.code == 'EVENT_MISSING_CAPACITY') {
            return 'Capacity must be greater than 0 before the public registration experience can launch.';
        }
        if (issue.code == 'EVENT_CUSTOM_QUESTIONS_MISSING') {
            return 'Custom Questions Page details are filled in, but no related Summit Event Questions exist.';
        }
        return issue.message;
    }
}
