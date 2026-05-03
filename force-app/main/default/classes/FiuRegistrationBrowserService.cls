public with sharing class FiuRegistrationBrowserService {
    public class RegistrationRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String eventName;
        @AuraEnabled public String instanceName;
        @AuraEnabled public String attendanceStatus;
    }

    @AuraEnabled(cacheable=true)
    public static List<RegistrationRow> queryRegistrations(String searchKey, String attendanceFilter, String programCode, Id instanceId) {
        String emailField = resolveOptionalField('summit__Summit_Events_Registration__c', new List<String>{ 'summit__Email__c', 'Email__c' });
        String attendanceField = resolveOptionalField('summit__Summit_Events_Registration__c', new List<String>{ 'summit__Attendance_Status__c', 'Attendance_Status__c' });
        String eventObject = FiuEventsAccessService.resolveEventObject();
        if (eventObject == null) return new List<RegistrationRow>();

        Set<Id> allowedRecordTypes = FiuEventsAccessService.getAllowedEventRecordTypeIds();
        if (allowedRecordTypes.isEmpty()) return new List<RegistrationRow>();
        FiuProgramFilterService.ProgramFilterConfig programConfig = FiuProgramFilterService.getConfig();

        List<String> fields = new List<String>{
            'Id', 'Name', 'summit__Event_Instance__r.Name', 'summit__Event_Instance__r.summit__Event__r.Name', 'summit__Event_Instance__r.summit__Event__r.RecordTypeId'
        };
        for (String eventProgramField : programConfig.eventProgramFields) {
            fields.add('summit__Event_Instance__r.summit__Event__r.' + eventProgramField);
        }
        if (programConfig.hasDefaultPlanLookup) fields.add('summit__Event_Instance__r.summit__Event__r.Default_Plan__r.Plan_Code__c');
        if (emailField != null) fields.add(emailField);
        if (attendanceField != null) fields.add(attendanceField);

        String soql = 'SELECT ' + String.join(fields, ',') + ' FROM summit__Summit_Events_Registration__c ' +
                      'WHERE summit__Event_Instance__r.summit__Event__r.RecordTypeId IN :allowedRecordTypes';
        if (String.isNotBlank(searchKey)) {
            soql += ' AND (Name LIKE :likeSearch OR summit__Event_Instance__r.summit__Event__r.Name LIKE :likeSearch)';
        }
        if (String.isNotBlank(attendanceFilter) && attendanceField != null) {
            soql += ' AND ' + attendanceField + ' = :attendanceFilter';
        }
        if (instanceId != null) {
            soql += ' AND summit__Event_Instance__c = :instanceId';
        }
        soql += ' ORDER BY CreatedDate DESC LIMIT 300';

        String likeSearch = '%' + String.escapeSingleQuotes(searchKey == null ? '' : searchKey.trim()) + '%';
        List<RegistrationRow> rows = new List<RegistrationRow>();
        for (SObject reg : Database.query(soql)) {
            SObject inst = reg.getSObject('summit__Event_Instance__r');
            SObject evt = inst == null ? null : inst.getSObject('summit__Event__r');
            if (!FiuProgramFilterService.eventMatchesSelectedProgram(evt, programConfig, programCode)) continue;
            RegistrationRow row = new RegistrationRow();
            row.id = (Id) reg.get('Id');
            row.name = (String) reg.get('Name');
            row.email = emailField == null ? null : (String) reg.get(emailField);
            row.attendanceStatus = attendanceField == null ? null : String.valueOf(reg.get(attendanceField));
            if (inst != null) {
                row.instanceName = (String) inst.get('Name');
                if (evt != null) row.eventName = (String) evt.get('Name');
            }
            rows.add(row);
        }
        return rows;
    }

    private static String resolveOptionalField(String objectApiName, List<String> candidates) {
        Schema.SObjectType sType = Schema.getGlobalDescribe().get(objectApiName);
        if (sType == null) return null;
        Map<String, Schema.SObjectField> mapFields = sType.getDescribe().fields.getMap();
        for (String fieldApi : candidates) {
            if (mapFields.containsKey(fieldApi)) return fieldApi;
        }
        return null;
    }
}
