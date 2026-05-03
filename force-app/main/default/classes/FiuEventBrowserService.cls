public with sharing class FiuEventBrowserService {
    public class EventRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String recordType;
        @AuraEnabled public String status;
        @AuraEnabled public String statusClass;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public String readiness;
        @AuraEnabled public String readinessClass;
        @AuraEnabled public String issueReason;
    }

    @AuraEnabled(cacheable=true)
    public static List<EventRow> queryEvents(String searchKey, String statusFilter, String programCode, String readinessFilter) {
        String eventObject = FiuEventsAccessService.resolveEventObject();
        if (eventObject == null) return new List<EventRow>();

        Set<Id> allowedRecordTypes = FiuEventsAccessService.getAllowedEventRecordTypeIds();
        if (allowedRecordTypes.isEmpty()) return new List<EventRow>();

        FiuProgramFilterService.ProgramFilterConfig programConfig = FiuProgramFilterService.getConfig();
        List<String> selectFields = new List<String>{
            'Id', 'Name', 'RecordType.Name', 'summit__Event_Status__c', 'summit__Start_Date__c', 'summit__End_Date__c',
            'summit__Account__c', 'Default_Plan__c', 'Includes_Multiple_Programs__c'
        };
        selectFields.addAll(programConfig.eventProgramFields);
        if (programConfig.hasDefaultPlanLookup) selectFields.add('Default_Plan__r.Plan_Code__c');

        String soql = 'SELECT ' + String.join(selectFields, ',') +
                      ' FROM ' + eventObject +
                      ' WHERE RecordTypeId IN :allowedRecordTypes';

        if (String.isNotBlank(searchKey)) {
            soql += ' AND Name LIKE :likeSearch';
        }
        if (String.isNotBlank(statusFilter)) {
            soql += ' AND summit__Event_Status__c = :statusFilter';
        }
        soql += ' ORDER BY LastModifiedDate DESC LIMIT 200';

        String likeSearch = '%' + String.escapeSingleQuotes(searchKey == null ? '' : searchKey.trim()) + '%';
        List<EventRow> rows = new List<EventRow>();
        for (SObject record : Database.query(soql)) {
            if (!FiuProgramFilterService.eventMatchesSelectedProgram(record, programConfig, programCode)) continue;
            String issueReason = getEventIssueReason(record, programConfig);
            if (readinessFilter == 'NotReady' && String.isBlank(issueReason)) continue;
            if (readinessFilter == 'Ready' && !String.isBlank(issueReason)) continue;
            EventRow row = new EventRow();
            row.id = (Id) record.get('Id');
            row.name = (String) record.get('Name');
            SObject rt = record.getSObject('RecordType');
            row.recordType = rt == null ? null : (String) rt.get('Name');
            row.status = (String) record.get('summit__Event_Status__c');
            row.startDate = (Date) record.get('summit__Start_Date__c');
            row.endDate = (Date) record.get('summit__End_Date__c');
            row.issueReason = issueReason;
            Boolean hasIssues = !String.isBlank(issueReason);
            if (hasIssues && row.status == 'Active') {
                row.readiness = 'Active w/ Issues';
                row.readinessClass = 'slds-text-color_error slds-text-title_bold';
                row.statusClass = 'slds-text-color_error slds-text-title_bold';
            } else if (hasIssues) {
                row.readiness = 'Needs Review';
                row.readinessClass = 'slds-text-color_warning slds-text-title_bold';
                row.statusClass = 'slds-text-color_warning';
            } else {
                row.readiness = 'Ready';
                row.readinessClass = 'slds-text-color_success slds-text-title_bold';
                row.statusClass = 'slds-text-color_success';
            }
            rows.add(row);
        }
        return rows;
    }

    private static String getEventIssueReason(SObject eventRow, FiuProgramFilterService.ProgramFilterConfig programConfig) {
        List<String> reasons = new List<String>();
        if (eventRow.get('summit__Account__c') == null) reasons.add('Missing account');

        Boolean includesMultiple = (Boolean) eventRow.get('Includes_Multiple_Programs__c');
        Boolean hasDefaultPlan = eventRow.get('Default_Plan__c') != null;
        Boolean hasProgramFilterCodes = !FiuProgramFilterService.extractProgramCodesFromEvent(eventRow, programConfig).isEmpty();

        if (includesMultiple == true) {
            if (!hasProgramFilterCodes && !hasDefaultPlan) reasons.add('Missing selected program');
        } else {
            if (!hasDefaultPlan && !hasProgramFilterCodes) reasons.add('Missing selected program');
        }
        return reasons.isEmpty() ? null : String.join(reasons, '; ');
    }
}
