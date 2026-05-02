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

        String eventObject = resolveEventObject();
        if (eventObject == null) {
            throw new AuraHandledException('No Summit Event object found in this org.');
        }

        String soql = 'SELECT Id, Name, summit__Account__c, summit__Payment_Gateway__c, Accounting_Department__c, FIU_Create_Opps_From_Regs__c, Send_Registration_Confirmation_Email__c FROM ' + eventObject + ' WHERE Id = :eventId LIMIT 1';
        SObject eventRecord = Database.query(soql);
        return evaluateEventRecord(eventRecord);
    }

    public static ReadinessResult evaluateEventRecord(SObject eventRecord) {
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

        return result;
    }

    private static String resolveEventObject() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey('summit__Summit_Event__c')) return 'summit__Summit_Event__c';
        if (gd.containsKey('summit__Event__c')) return 'summit__Event__c';
        return null;
    }

    private static Object safeGet(SObject record, String fieldApiName) {
        try {
            return record.get(fieldApiName);
        } catch (Exception ex) {
            return null;
        }
    }
}
