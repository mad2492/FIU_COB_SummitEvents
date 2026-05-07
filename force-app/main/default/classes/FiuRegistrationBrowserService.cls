public with sharing class FiuRegistrationBrowserService {
    public class RegistrationRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Id contactId;
        @AuraEnabled public String contactName;
        @AuraEnabled public String email;
        @AuraEnabled public Id eventId;
        @AuraEnabled public String eventName;
        @AuraEnabled public Id instanceId;
        @AuraEnabled public String instanceName;
        @AuraEnabled public String processStatus;
        @AuraEnabled public Date instanceStartDate;
        @AuraEnabled public Date instanceEndDate;
        @AuraEnabled public String locationTypeOverride;
        @AuraEnabled public String processStatusClass;
        @AuraEnabled public String contactIssue;
        @AuraEnabled public String contactIssueClass;
    }

    public class RegistrationQueryResult {
        @AuraEnabled public List<RegistrationRow> rows;
        @AuraEnabled public Integer totalCount;
    }

    public class MassUpdateResult {
        @AuraEnabled public Integer updatedCount;
        @AuraEnabled public List<String> warnings;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getLocationTypeOverrideOptions() {
        List<String> out = new List<String>();
        for (AggregateResult ar : [
            SELECT summit__Location_Type_Override__c val
            FROM summit__Summit_Events_Instance__c
            WHERE summit__Location_Type_Override__c != null
            GROUP BY summit__Location_Type_Override__c
            ORDER BY summit__Location_Type_Override__c
            LIMIT 200
        ]) {
            out.add((String) ar.get('val'));
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static RegistrationQueryResult queryRegistrations(
        String searchKey,
        String programCode,
        Id instanceId,
        String statusFilter,
        String locationTypeOverrideFilter,
        Integer pageNumber,
        Integer pageSize,
        String sortField1,
        String sortDir1,
        String sortField2,
        String sortDir2
    ) {
        String emailField = resolveOptionalField('summit__Summit_Events_Registration__c', new List<String>{ 'summit__Email__c', 'Email__c' });
        String processStatusField = resolveOptionalField('summit__Summit_Events_Registration__c', new List<String>{ 'summit__Status__c', 'Status__c' });
        String contactField = resolveOptionalField('summit__Summit_Events_Registration__c', new List<String>{ 'summit__Contact__c', 'Contact__c' });
        String contactNameField = resolveOptionalField('summit__Summit_Events_Registration__c', new List<String>{ 'summit__Contact_Name__c', 'Contact_Name__c' });
        String contactRelationshipField = contactField == null ? null : (contactField == 'summit__Contact__c' ? 'summit__Contact__r' : 'Contact__r');
        String eventObject = FiuEventsAccessService.resolveEventObject();
        RegistrationQueryResult result = new RegistrationQueryResult();
        result.rows = new List<RegistrationRow>();
        result.totalCount = 0;
        if (eventObject == null) return result;

        Set<Id> allowedRecordTypes = FiuEventsAccessService.getAllowedEventRecordTypeIds();
        if (allowedRecordTypes.isEmpty()) return result;
        FiuProgramFilterService.ProgramFilterConfig programConfig = FiuProgramFilterService.getConfig();
        String previewField = FiuEventsAccessService.resolveEventPreviewField();

        List<String> fields = new List<String>{
            'Id', 'Name', 'summit__Event__c', 'summit__Event_Instance__c', 'summit__Event_Instance__r.Name',
            'summit__Event_Instance__r.summit__Event__r.Name', 'summit__Event_Instance__r.summit__Event__r.RecordTypeId',
            'summit__Event_Instance_Start_Date__c', 'summit__Event_Instance_End_Date__c',
            'summit__Event_Instance__r.summit__Location_Type_Override__c'
        };
        for (String eventProgramField : programConfig.eventProgramFields) {
            fields.add('summit__Event_Instance__r.summit__Event__r.' + eventProgramField);
        }
        if (programConfig.hasDefaultPlanLookup) fields.add('summit__Event_Instance__r.summit__Event__r.Default_Plan__r.Plan_Code__c');
        if (emailField != null) fields.add(emailField);
        if (processStatusField != null) fields.add(processStatusField);
        if (contactField != null) fields.add(contactField);
        if (contactNameField != null) fields.add(contactNameField);
        if (contactRelationshipField != null) {
            fields.add(contactRelationshipField + '.Name');
            fields.add(contactRelationshipField + '.Email');
        }

        String soql = 'SELECT ' + String.join(fields, ',') + ' FROM summit__Summit_Events_Registration__c ' +
                      'WHERE summit__Event_Instance__r.summit__Event__r.RecordTypeId IN :allowedRecordTypes';
        if (previewField != null) soql += ' AND (summit__Event_Instance__r.summit__Event__r.' + previewField + ' = false OR summit__Event_Instance__r.summit__Event__r.' + previewField + ' = null)';
        if (String.isNotBlank(searchKey)) {
            soql += ' AND (Name LIKE :likeSearch OR summit__Event_Instance__r.summit__Event__r.Name LIKE :likeSearch)';
        }
        if (instanceId != null) {
            soql += ' AND summit__Event_Instance__c = :instanceId';
        }
        if (statusFilter == 'Open' && processStatusField != null) {
            soql += ' AND ' + processStatusField + ' NOT IN (\'Started\', \'Cancelled\')';
        } else if (statusFilter == 'Started' && processStatusField != null) {
            soql += ' AND ' + processStatusField + ' = \'Started\'';
        } else if (statusFilter == 'Cancelled' && processStatusField != null) {
            soql += ' AND ' + processStatusField + ' = \'Cancelled\'';
        }
        if (String.isNotBlank(locationTypeOverrideFilter)) {
            soql += ' AND summit__Event_Instance__r.summit__Location_Type_Override__c = :locationTypeOverrideFilter';
        }
        String programClause = FiuProgramFilterService.buildProgramWhereClause('summit__Event_Instance__r.summit__Event__r.', programCode, programConfig);
        if (programClause != null) soql += ' AND ' + programClause;

        String countSoql = 'SELECT COUNT() FROM summit__Summit_Events_Registration__c WHERE summit__Event_Instance__r.summit__Event__r.RecordTypeId IN :allowedRecordTypes';
        if (previewField != null) countSoql += ' AND (summit__Event_Instance__r.summit__Event__r.' + previewField + ' = false OR summit__Event_Instance__r.summit__Event__r.' + previewField + ' = null)';
        if (String.isNotBlank(searchKey)) countSoql += ' AND (Name LIKE :likeSearch OR summit__Event_Instance__r.summit__Event__r.Name LIKE :likeSearch)';
        if (instanceId != null) countSoql += ' AND summit__Event_Instance__c = :instanceId';
        if (statusFilter == 'Open' && processStatusField != null) countSoql += ' AND ' + processStatusField + ' NOT IN (\'Started\', \'Cancelled\')';
        else if (statusFilter == 'Started' && processStatusField != null) countSoql += ' AND ' + processStatusField + ' = \'Started\'';
        else if (statusFilter == 'Cancelled' && processStatusField != null) countSoql += ' AND ' + processStatusField + ' = \'Cancelled\'';
        if (String.isNotBlank(locationTypeOverrideFilter)) countSoql += ' AND summit__Event_Instance__r.summit__Location_Type_Override__c = :locationTypeOverrideFilter';
        if (programClause != null) countSoql += ' AND ' + programClause;

        Integer safePageSize = pageSize == null || pageSize < 1 ? 25 : Math.min(pageSize, 100);
        Integer safePageNumber = pageNumber == null || pageNumber < 1 ? 1 : pageNumber;
        Integer offsetRows = (safePageNumber - 1) * safePageSize;
        result.totalCount = Integer.valueOf(Database.countQuery(countSoql));

        String orderBy = buildOrderBy(sortField1, sortDir1, sortField2, sortDir2);
        soql += ' ORDER BY ' + orderBy + ' LIMIT :safePageSize OFFSET :offsetRows';

        String likeSearch = '%' + String.escapeSingleQuotes(searchKey == null ? '' : searchKey.trim()) + '%';
        List<RegistrationRow> rows = new List<RegistrationRow>();
        for (SObject reg : Database.query(soql)) {
            SObject inst = reg.getSObject('summit__Event_Instance__r');
            SObject evt = inst == null ? null : inst.getSObject('summit__Event__r');
            RegistrationRow row = new RegistrationRow();
            row.id = (Id) reg.get('Id');
            row.name = (String) reg.get('Name');
            row.contactId = contactField == null ? null : (Id) reg.get(contactField);
            SObject contactRef = contactRelationshipField == null ? null : reg.getSObject(contactRelationshipField);
            row.contactName = contactRef == null ? (contactNameField == null ? null : (String) reg.get(contactNameField)) : (String) contactRef.get('Name');
            String registrantEmail = emailField == null ? null : (String) reg.get(emailField);
            String contactEmail = contactRef == null ? null : (String) contactRef.get('Email');
            row.email = String.isBlank(contactEmail) ? registrantEmail : contactEmail;
            row.processStatus = processStatusField == null ? null : String.valueOf(reg.get(processStatusField));
            row.instanceStartDate = (Date) reg.get('summit__Event_Instance_Start_Date__c');
            row.instanceEndDate = (Date) reg.get('summit__Event_Instance_End_Date__c');
            if (row.processStatus == 'Started') {
                row.processStatusClass = 'slds-text-color_warning slds-text-title_bold';
            } else if (row.processStatus == 'Cancelled') {
                row.processStatusClass = 'slds-text-color_weak';
            } else if (!String.isBlank(row.processStatus)) {
                row.processStatusClass = 'slds-text-color_success';
            }
            if (contactField != null && reg.get(contactField) == null) {
                row.contactIssue = 'Missing Contact';
                row.contactIssueClass = 'slds-text-color_warning slds-text-title_bold';
            } else {
                row.contactIssue = 'OK';
                row.contactIssueClass = 'slds-text-color_success';
            }
            if (inst != null) {
                row.instanceId = (Id) reg.get('summit__Event_Instance__c');
                row.instanceName = (String) inst.get('Name');
                row.locationTypeOverride = (String) inst.get('summit__Location_Type_Override__c');
                if (evt != null) {
                    row.eventName = (String) evt.get('Name');
                    row.eventId = (Id) reg.get('summit__Event__c');
                }
            }
            rows.add(row);
        }
        result.rows = rows;
        return result;
    }

    private static String buildOrderBy(String sortField1, String sortDir1, String sortField2, String sortDir2) {
        Map<String, String> sortMap = new Map<String, String>{
            'name' => 'Name',
            'email' => 'summit__Registrant_Email__c',
            'eventName' => 'summit__Event__r.Name',
            'instanceName' => 'summit__Event_Instance__r.Name',
            'processStatus' => 'summit__Status__c',
            'instanceStartDate' => 'summit__Event_Instance_Start_Date__c',
            'instanceEndDate' => 'summit__Event_Instance_End_Date__c',
            'locationTypeOverride' => 'summit__Event_Instance__r.summit__Location_Type_Override__c',
            'createdDate' => 'CreatedDate'
        };
        List<String> orderParts = new List<String>();
        addSortPart(orderParts, sortMap, sortField1, sortDir1);
        addSortPart(orderParts, sortMap, sortField2, sortDir2);
        if (orderParts.isEmpty()) return 'CreatedDate DESC';
        orderParts.add('CreatedDate DESC');
        return String.join(orderParts, ', ');
    }

    private static void addSortPart(List<String> orderParts, Map<String, String> sortMap, String sortField, String sortDir) {
        if (String.isBlank(sortField) || !sortMap.containsKey(sortField)) return;
        String dir = String.valueOf(sortDir).toUpperCase() == 'ASC' ? 'ASC' : 'DESC';
        String part = sortMap.get(sortField) + ' ' + dir + ' NULLS LAST';
        if (!orderParts.contains(part)) orderParts.add(part);
    }

    @AuraEnabled
    public static MassUpdateResult massUpdateRegistrations(List<Id> registrationIds, String newStatus, Id newEventId, Id newInstanceId) {
        if (registrationIds == null || registrationIds.isEmpty()) {
            throw new AuraHandledException('Select at least one registration.');
        }

        String statusField = resolveOptionalField('summit__Summit_Events_Registration__c', new List<String>{ 'summit__Status__c', 'Status__c' });
        String eventField = resolveOptionalField('summit__Summit_Events_Registration__c', new List<String>{ 'summit__Event__c', 'Event__c' });
        String instanceField = resolveOptionalField('summit__Summit_Events_Registration__c', new List<String>{ 'summit__Event_Instance__c', 'Event_Instance__c' });

        if (statusField == null && instanceField == null && eventField == null) {
            throw new AuraHandledException('No supported fields found for mass update.');
        }
        if (String.isBlank(newStatus) && newEventId == null && newInstanceId == null) {
            throw new AuraHandledException('Choose at least one field to update.');
        }

        if (newInstanceId != null && newEventId != null) {
            Integer relationCount = [
                SELECT COUNT()
                FROM summit__Summit_Events_Instance__c
                WHERE Id = :newInstanceId AND summit__Event__c = :newEventId
            ];
            if (relationCount == 0) throw new AuraHandledException('Selected Instance does not belong to selected Event.');
        }

        List<SObject> updates = new List<SObject>();
        for (Id registrationId : registrationIds) {
            SObject row = Schema.getGlobalDescribe().get('summit__Summit_Events_Registration__c').newSObject(registrationId);
            if (!String.isBlank(newStatus) && statusField != null) row.put(statusField, newStatus);
            if (newEventId != null && eventField != null) row.put(eventField, newEventId);
            if (newInstanceId != null && instanceField != null) row.put(instanceField, newInstanceId);
            updates.add(row);
        }

        update updates;

        MassUpdateResult result = new MassUpdateResult();
        result.updatedCount = updates.size();
        result.warnings = new List<String>();
        if (newInstanceId == null && newEventId != null) {
            result.warnings.add('Event was updated without changing Instance. Confirm event/instance alignment.');
        }
        return result;
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
