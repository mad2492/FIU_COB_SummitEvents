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

        String soql = 'SELECT Id, Name, RecordTypeId, summit__Account__c, summit__Payment_Gateway__c, Accounting_Department__c, FIU_Create_Opps_From_Regs__c, Send_Registration_Confirmation_Email__c, summit__Event_Additional_Question_Title__c, summit__Event_Additional_Questions_Description__c, summit__Event_description__c, summit__Event_Short_Listing_Description__c, summit__Event_Footer__c, summit__Event_Full_Text__c, summit__Event_Confirmation_Description__c FROM ' + eventObject + ' WHERE Id = :eventId AND RecordTypeId IN :allowedRecordTypes LIMIT 1';
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

        if (safeGet(eventRecord, 'summit__Account__c') == null) {
            result.ready = false;
            result.missingFields.add('summit__Account__c');
            result.warnings.add('Account is required to avoid external-site authorization issues.');
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

        String customQuestionTitle = (String) safeGet(eventRecord, 'summit__Event_Additional_Question_Title__c');
        String customQuestionDescription = (String) safeGet(eventRecord, 'summit__Event_Additional_Questions_Description__c');
        Boolean hasCustomQuestionPageDetails = !String.isBlank(customQuestionTitle) || !String.isBlank(customQuestionDescription);
        Integer effectiveQuestionCount = relatedQuestionCount == null ? 0 : relatedQuestionCount;
        if (hasCustomQuestionPageDetails && effectiveQuestionCount == 0) {
            result.warnings.add('Custom Questions Page details are filled in, but no related Summit Event Questions exist.');
        }

        result.warnings.addAll(collectRichTextImageWarnings(eventRecord));

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

    private static Object safeGet(SObject record, String fieldApiName) {
        try {
            return record.get(fieldApiName);
        } catch (Exception ex) {
            return null;
        }
    }
}
