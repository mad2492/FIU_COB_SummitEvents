public with sharing class FiuEventsOrchestratorService {
    public class CloneRiskResult {
        @AuraEnabled public List<String> riskWarnings = new List<String>();
        @AuraEnabled public Map<String, Object> snapshot = new Map<String, Object>();
    }

    @AuraEnabled(cacheable=true)
    public static CloneRiskResult evaluateCloneRisk(Id sourceEventId) {
        if (sourceEventId == null) {
            throw new AuraHandledException('Source Event Id is required.');
        }

        String eventObject = FiuEventsAccessService.resolveEventObject();
        if (eventObject == null) {
            throw new AuraHandledException('No Summit Event object found in this org.');
        }

        Set<Id> allowedRecordTypes = FiuEventsAccessService.getAllowedEventRecordTypeIds();
        if (allowedRecordTypes.isEmpty()) {
            throw new AuraHandledException('You do not have access to any FIU Event record types.');
        }

        String soql = 'SELECT Id, Name, RecordTypeId, summit__Account__c, summit__Payment_Gateway__c, Accounting_Department__c, FIU_Create_Opps_From_Regs__c, Send_Registration_Confirmation_Email__c FROM ' + eventObject + ' WHERE Id = :sourceEventId AND RecordTypeId IN :allowedRecordTypes LIMIT 1';
        SObject sourceEvent = Database.query(soql);
        return evaluateCloneRiskRecord(sourceEvent);
    }

    public static CloneRiskResult evaluateCloneRiskRecord(SObject sourceEvent) {
        CloneRiskResult result = new CloneRiskResult();
        if (sourceEvent == null) {
            result.riskWarnings.add('Source event not found.');
            return result;
        }

        result.snapshot.put('name', safeGet(sourceEvent, 'Name'));
        result.snapshot.put('accountId', safeGet(sourceEvent, 'summit__Account__c'));
        result.snapshot.put('paymentGateway', safeGet(sourceEvent, 'summit__Payment_Gateway__c'));
        result.snapshot.put('accountingDepartment', safeGet(sourceEvent, 'Accounting_Department__c'));
        result.snapshot.put('createOppsFromRegs', safeGet(sourceEvent, 'FIU_Create_Opps_From_Regs__c'));
        result.snapshot.put('sendConfirmationEmail', safeGet(sourceEvent, 'Send_Registration_Confirmation_Email__c'));

        if (safeGet(sourceEvent, 'summit__Payment_Gateway__c') != null || safeGet(sourceEvent, 'Accounting_Department__c') != null) {
            result.riskWarnings.add('Payment settings detected. Reconfirm gateway and accounting ownership on clone.');
        }
        if ((Boolean) safeGet(sourceEvent, 'FIU_Create_Opps_From_Regs__c') == true) {
            result.riskWarnings.add('Clone will inherit Opportunity creation behavior unless changed.');
        }
        if ((Boolean) safeGet(sourceEvent, 'Send_Registration_Confirmation_Email__c') == true) {
            result.riskWarnings.add('Clone will inherit dynamic registration confirmation email behavior unless changed.');
        }
        if (safeGet(sourceEvent, 'summit__Account__c') == null) {
            result.riskWarnings.add('Source event has no Account and may produce external authorization issues.');
        }

        result.riskWarnings.add('Review business-unit/program/plan values in spEventsFIUPlanLookup before activation.');
        return result;
    }

    private static Object safeGet(SObject record, String fieldApiName) {
        try {
            return record.get(fieldApiName);
        } catch (Exception ex) {
            return null;
        }
    }
}
