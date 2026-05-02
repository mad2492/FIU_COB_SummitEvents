public with sharing class FiuEventsRosterService {
    public class RegistrationRow {
        @AuraEnabled public Id registrationId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean attended;
    }

    @AuraEnabled(cacheable=true)
    public static List<RegistrationRow> getInstanceRoster(Id instanceId) {
        if (instanceId == null) {
            throw new AuraHandledException('Instance Id is required.');
        }

        String emailField = resolveOptionalField('summit__Summit_Events_Registration__c', new List<String>{ 'summit__Email__c', 'Email__c' });
        String statusField = resolveOptionalField('summit__Summit_Events_Registration__c', new List<String>{ 'summit__Attendance_Status__c', 'Attendance_Status__c' });
        String attendedField = resolveOptionalField('summit__Summit_Events_Registration__c', new List<String>{ 'summit__Attended__c', 'Attended__c' });

        List<String> selectFields = new List<String>{ 'Id', 'Name' };
        if (emailField != null) selectFields.add(emailField);
        if (statusField != null) selectFields.add(statusField);
        if (attendedField != null) selectFields.add(attendedField);

        String soql = 'SELECT ' + String.join(selectFields, ',') + ' FROM summit__Summit_Events_Registration__c WHERE summit__Event_Instance__c = :instanceId ORDER BY CreatedDate DESC LIMIT 2000';

        List<RegistrationRow> rows = new List<RegistrationRow>();
        for (SObject reg : Database.query(soql)) {
            RegistrationRow row = new RegistrationRow();
            row.registrationId = (Id) reg.get('Id');
            row.name = (String) reg.get('Name');
            row.email = emailField == null ? null : (String) reg.get(emailField);
            row.status = statusField == null ? null : String.valueOf(reg.get(statusField));
            row.attended = attendedField == null ? null : (Boolean) reg.get(attendedField);
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static String exportInstanceRosterCsv(Id instanceId) {
        return buildCsv(getInstanceRoster(instanceId));
    }

    public static String buildCsv(List<RegistrationRow> rows) {
        List<String> lines = new List<String>{'RegistrationId,Name,Email,Status,Attended'};
        for (RegistrationRow row : rows) {
            lines.add(String.join(new List<String>{
                csvCell((String) row.registrationId), csvCell(row.name), csvCell(row.email), csvCell(row.status), csvCell(String.valueOf(row.attended))
            }, ','));
        }
        return String.join(lines, '\n');
    }

    private static String csvCell(String value) {
        if (value == null) return '""';
        return '"' + value.replace('"', '""') + '"';
    }

    private static String resolveOptionalField(String objectApiName, List<String> candidates) {
        Schema.SObjectType sType = Schema.getGlobalDescribe().get(objectApiName);
        if (sType == null) return null;
        Map<String, Schema.SObjectField> fields = sType.getDescribe().fields.getMap();
        for (String apiName : candidates) {
            if (fields.containsKey(apiName)) return apiName;
        }
        return null;
    }
}
