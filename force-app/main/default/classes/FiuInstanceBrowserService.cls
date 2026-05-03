public with sharing class FiuInstanceBrowserService {
    public class InstanceRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String title;
        @AuraEnabled public String eventName;
        @AuraEnabled public Date startDate;
        @AuraEnabled public String activeStatus;
        @AuraEnabled public String readiness;
        @AuraEnabled public String unpublishedReason;
    }

    @AuraEnabled(cacheable=true)
    public static List<InstanceRow> queryInstances(Id eventId, String searchKey, String bucketFilter, String programCode) {
        Set<Id> allowedRecordTypes = FiuEventsAccessService.getAllowedEventRecordTypeIds();
        if (allowedRecordTypes.isEmpty()) return new List<InstanceRow>();
        FiuProgramFilterService.ProgramFilterConfig programConfig = FiuProgramFilterService.getConfig();

        List<String> fields = new List<String>{
            'Id', 'summit__Instance_Title__c', 'summit__Instance_Start_Date__c', 'summit__Instance_End_Date__c',
            'summit__Active_Status__c', 'summit__Open_Registration__c',
            'summit__Location_Title_Override__c', 'summit__Location_Address_Override__c', 'summit__Location_Map_Link_Override__c', 'Parking_info__c',
            'summit__Event__r.Name', 'summit__Event__r.summit__Account__c', 'summit__Event__r.summit__Payment_Gateway__c', 'summit__Event__r.Accounting_Department__c'
        };
        for (String eventProgramField : programConfig.eventProgramFields) {
            fields.add('summit__Event__r.' + eventProgramField);
        }
        if (programConfig.hasDefaultPlanLookup) fields.add('summit__Event__r.Default_Plan__r.Plan_Code__c');

        String soql = 'SELECT ' + String.join(fields, ',') +
            ' FROM summit__Summit_Events_Instance__c WHERE summit__Event__r.RecordTypeId IN :allowedRecordTypes';

        if (eventId != null) soql += ' AND summit__Event__c = :eventId';
        if (String.isNotBlank(searchKey)) soql += ' AND summit__Instance_Title__c LIKE :likeSearch';
        soql += ' ORDER BY summit__Instance_Start_Date__c ASC NULLS LAST LIMIT 500';

        String likeSearch = '%' + String.escapeSingleQuotes(searchKey == null ? '' : searchKey.trim()) + '%';

        List<InstanceRow> outRows = new List<InstanceRow>();
        Date today = Date.today();
        for (SObject row : Database.query(soql)) {
            if (!FiuProgramFilterService.eventMatchesSelectedProgram(row.getSObject('summit__Event__r'), programConfig, programCode)) continue;
            InstanceRow r = new InstanceRow();
            r.id = (Id) row.get('Id');
            r.title = (String) row.get('summit__Instance_Title__c');
            r.startDate = (Date) row.get('summit__Instance_Start_Date__c');
            r.activeStatus = (String) row.get('summit__Active_Status__c');
            SObject evt = row.getSObject('summit__Event__r');
            r.eventName = evt == null ? null : (String) evt.get('Name');
            String reason = getUnpublishedReason(row);
            r.unpublishedReason = reason;
            r.readiness = String.isBlank(reason) ? 'Ready' : 'Not Ready';

            if (bucketFilter == 'Upcoming' && (r.startDate == null || r.startDate < today)) {
                continue;
            }
            if (bucketFilter == 'Past' && (r.startDate == null || r.startDate >= today)) {
                continue;
            }
            if (bucketFilter == 'Unpublished' && String.isBlank(reason)) {
                continue;
            }
            outRows.add(r);
        }
        return outRows;
    }

    private static String getUnpublishedReason(SObject row) {
        List<String> reasons = new List<String>();
        Date startDate = (Date) row.get('summit__Instance_Start_Date__c');
        Date today = Date.today();
        Boolean isPast = startDate != null && startDate < today;
        String activeStatus = (String) row.get('summit__Active_Status__c');
        if (!isPast && activeStatus != 'Active') reasons.add('Instance not Active');
        if (!isPast && (Boolean) row.get('summit__Open_Registration__c') == false) reasons.add('Registration closed');
        if (row.get('summit__Instance_Start_Date__c') == null) reasons.add('Missing start date');
        if (row.get('summit__Instance_End_Date__c') == null) reasons.add('Missing end date');
        if (String.isBlank((String) row.get('summit__Location_Title_Override__c'))) reasons.add('Missing location title');
        if (String.isBlank((String) row.get('summit__Location_Address_Override__c'))) reasons.add('Missing location address');
        if (String.isBlank((String) row.get('summit__Location_Map_Link_Override__c'))) reasons.add('Missing location map link');
        if (String.isBlank((String) row.get('Parking_info__c'))) reasons.add('Missing parking info');

        SObject evt = row.getSObject('summit__Event__r');
        if (evt != null) {
            if (evt.get('summit__Account__c') == null) reasons.add('Parent event missing Account');
            String gateway = (String) evt.get('summit__Payment_Gateway__c');
            if (!String.isBlank(gateway) && gateway != 'No Gateway' && evt.get('Accounting_Department__c') == null) {
                reasons.add('Paid event missing Accounting Department');
            }
        }
        return reasons.isEmpty() ? null : String.join(reasons, '; ');
    }
}
