public with sharing class FiuHomeDashboardService {
    public class DashboardData {
        @AuraEnabled public Integer upcomingInstances;
        @AuraEnabled public Integer openRegistrations;
        @AuraEnabled public Integer startedRegistrations;
        @AuraEnabled public Integer notReadyInstances;
        @AuraEnabled public Integer notReadyEvents;
        @AuraEnabled public Integer activeEvents;
        @AuraEnabled public List<AttentionRow> attentionRows;
        @AuraEnabled public List<UpcomingRow> upcomingRows;
    }

    public class AttentionRow {
        @AuraEnabled public Id instanceId;
        @AuraEnabled public Id eventId;
        @AuraEnabled public String rowType;
        @AuraEnabled public String instanceTitle;
        @AuraEnabled public String eventName;
        @AuraEnabled public String reason;
    }

    public class UpcomingRow {
        @AuraEnabled public Id instanceId;
        @AuraEnabled public String instanceTitle;
        @AuraEnabled public String eventName;
        @AuraEnabled public Date startDate;
        @AuraEnabled public String status;
    }

    @AuraEnabled(cacheable=true)
    public static DashboardData loadDashboard(String programCode) {
        DashboardData data = new DashboardData();
        data.upcomingInstances = 0;
        data.openRegistrations = 0;
        data.startedRegistrations = 0;
        data.notReadyInstances = 0;
        data.notReadyEvents = 0;
        data.activeEvents = 0;
        data.attentionRows = new List<AttentionRow>();
        data.upcomingRows = new List<UpcomingRow>();

        Set<Id> allowedRt = FiuEventsAccessService.getAllowedEventRecordTypeIds();
        if (allowedRt.isEmpty()) return data;

        Date today = Date.today();

        FiuProgramFilterService.ProgramFilterConfig programConfig = FiuProgramFilterService.getConfig();
        List<String> activeEventFields = new List<String>{
            'Id',
            'Name',
            'summit__Event_Status__c',
            'summit__Account__c',
            'Default_Plan__c',
            'Includes_Multiple_Programs__c',
            'summit__Event_Additional_Question_Title__c',
            'summit__Event_Additional_Questions_Description__c'
        };
        activeEventFields.addAll(programConfig.eventProgramFields);
        if (programConfig.hasDefaultPlanLookup) activeEventFields.add('Default_Plan__r.Plan_Code__c');
        List<SObject> activeEventRows = Database.query(
            'SELECT ' + String.join(activeEventFields, ',') +
            ' FROM summit__Summit_Events__c WHERE RecordTypeId IN :allowedRt AND summit__Event_Status__c = \'Active\' LIMIT 5000'
        );
        Map<Id, Integer> questionCountByEventId = new Map<Id, Integer>();
        Set<Id> activeEventIds = new Set<Id>();
        for (SObject eventRow : activeEventRows) {
            activeEventIds.add((Id) eventRow.get('Id'));
        }
        if (!activeEventIds.isEmpty()) {
            String questionObject = FiuEventsAccessService.resolveEventQuestionObject();
            String questionEventLookup = FiuEventsAccessService.resolveEventQuestionLookupField();
            if (questionObject != null && questionEventLookup != null) {
                try {
                    String soql =
                        'SELECT ' + questionEventLookup + ' eventId, COUNT(Id) rowCount FROM ' + questionObject +
                        ' WHERE ' + questionEventLookup + ' IN :activeEventIds GROUP BY ' + questionEventLookup;
                    for (AggregateResult ar : Database.query(soql)) {
                        questionCountByEventId.put((Id) ar.get('eventId'), Integer.valueOf(String.valueOf(ar.get('rowCount'))));
                    }
                } catch (Exception ex) {
                    // Gracefully continue if question object/field visibility differs.
                }
            }
        }
        for (SObject eventRow : activeEventRows) {
            if (!FiuProgramFilterService.eventMatchesSelectedProgram(eventRow, programConfig, programCode)) continue;
            data.activeEvents++;
            Integer questionCount = questionCountByEventId.containsKey((Id) eventRow.get('Id')) ? questionCountByEventId.get((Id) eventRow.get('Id')) : 0;
            String eventReason = getEventNotReadyReason(eventRow, programConfig, questionCount);
            if (!String.isBlank(eventReason)) {
                data.notReadyEvents++;
                if (data.attentionRows.size() < 8) {
                    AttentionRow eventAttention = new AttentionRow();
                    eventAttention.eventId = (Id) eventRow.get('Id');
                    eventAttention.rowType = 'Event';
                    eventAttention.instanceTitle = (String) eventRow.get('Name');
                    eventAttention.eventName = 'Event';
                    eventAttention.reason = eventReason;
                    data.attentionRows.add(eventAttention);
                }
            }
        }

        List<String> instanceFields = new List<String>{
            'Id', 'summit__Instance_Title__c', 'summit__Instance_Start_Date__c', 'summit__Active_Status__c', 'summit__Open_Registration__c',
            'summit__Location_Title_Override__c', 'summit__Location_Address_Override__c', 'summit__Location_Map_Link_Override__c', 'Parking_info__c',
            'summit__Event__c',
            'summit__Event__r.Name', 'summit__Event__r.summit__Account__c', 'summit__Event__r.summit__Payment_Gateway__c', 'summit__Event__r.Accounting_Department__c'
        };
        for (String eventProgramField : programConfig.eventProgramFields) {
            instanceFields.add('summit__Event__r.' + eventProgramField);
        }
        if (programConfig.hasDefaultPlanLookup) instanceFields.add('summit__Event__r.Default_Plan__r.Plan_Code__c');
        String instanceSoql =
            'SELECT ' + String.join(instanceFields, ',') +
            ' FROM summit__Summit_Events_Instance__c WHERE summit__Event__r.RecordTypeId IN :allowedRt';
        instanceSoql += ' ORDER BY summit__Instance_Start_Date__c ASC NULLS LAST LIMIT 1000';
        List<SObject> instances = Database.query(instanceSoql);

        Set<Id> upcomingIds = new Set<Id>();
        for (SObject row : instances) {
            if (!FiuProgramFilterService.eventMatchesSelectedProgram(row.getSObject('summit__Event__r'), programConfig, programCode)) continue;
            Date startDate = (Date) row.get('summit__Instance_Start_Date__c');
            String reason = getNotReadyReason(row);

            if (startDate != null && startDate >= today) {
                data.upcomingInstances++;
                upcomingIds.add((Id) row.get('Id'));
                if (data.upcomingRows.size() < 8) {
                    UpcomingRow up = new UpcomingRow();
                    up.instanceId = (Id) row.get('Id');
                    up.instanceTitle = (String) row.get('summit__Instance_Title__c');
                    up.startDate = startDate;
                    up.status = (String) row.get('summit__Active_Status__c');
                    SObject ev = row.getSObject('summit__Event__r');
                    up.eventName = ev == null ? null : (String) ev.get('Name');
                    data.upcomingRows.add(up);
                }
            }

            if (!String.isBlank(reason)) {
                data.notReadyInstances++;
                if (data.attentionRows.size() < 8) {
                    AttentionRow ar = new AttentionRow();
                    ar.instanceId = (Id) row.get('Id');
                    ar.eventId = (Id) row.get('summit__Event__c');
                    ar.rowType = 'Instance';
                    ar.instanceTitle = (String) row.get('summit__Instance_Title__c');
                    SObject ev = row.getSObject('summit__Event__r');
                    ar.eventName = ev == null ? null : (String) ev.get('Name');
                    ar.reason = reason;
                    data.attentionRows.add(ar);
                }
            }
        }

        if (!upcomingIds.isEmpty()) {
            String statusField = resolveOptionalField('summit__Summit_Events_Registration__c', new List<String>{ 'summit__Status__c', 'Status__c' });
            if (statusField == null) {
                data.openRegistrations = [
                    SELECT COUNT()
                    FROM summit__Summit_Events_Registration__c
                    WHERE summit__Event_Instance__c IN :upcomingIds
                ];
            } else {
                List<SObject> regs = Database.query(
                    'SELECT Id, ' + statusField + ' FROM summit__Summit_Events_Registration__c WHERE summit__Event_Instance__c IN :upcomingIds LIMIT 5000'
                );
                for (SObject reg : regs) {
                    String statusValue = String.valueOf(reg.get(statusField));
                    if (statusValue == 'Started') {
                        data.startedRegistrations++;
                    }
                    if (statusValue != 'Started' && statusValue != 'Cancelled') {
                        data.openRegistrations++;
                    }
                }
            }
        }

        return data;
    }

    private static String getEventNotReadyReason(SObject eventRow, FiuProgramFilterService.ProgramFilterConfig programConfig, Integer relatedQuestionCount) {
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

        String customQuestionTitle = (String) eventRow.get('summit__Event_Additional_Question_Title__c');
        String customQuestionDescription = (String) eventRow.get('summit__Event_Additional_Questions_Description__c');
        Boolean hasCustomQuestionPageDetails = !String.isBlank(customQuestionTitle) || !String.isBlank(customQuestionDescription);
        if (hasCustomQuestionPageDetails && (relatedQuestionCount == null || relatedQuestionCount == 0)) {
            reasons.add('Custom questions details set but no related Summit Event Questions');
        }
        return reasons.isEmpty() ? null : String.join(reasons, '; ');
    }

    private static String getNotReadyReason(SObject row) {
        List<String> reasons = new List<String>();
        Date startDate = (Date) row.get('summit__Instance_Start_Date__c');
        Date today = Date.today();
        Boolean isPast = startDate != null && startDate < today;
        if (!isPast && (String) row.get('summit__Active_Status__c') != 'Active') reasons.add('Not Active');
        if (!isPast && (Boolean) row.get('summit__Open_Registration__c') == false) reasons.add('Registration closed');
        if (row.get('summit__Location_Title_Override__c') == null) reasons.add('Missing location title');
        if (row.get('summit__Location_Address_Override__c') == null) reasons.add('Missing location address');
        if (row.get('summit__Location_Map_Link_Override__c') == null) reasons.add('Missing location map link');
        if (row.get('Parking_info__c') == null) reasons.add('Missing parking info');

        SObject ev = row.getSObject('summit__Event__r');
        if (ev != null) {
            if (ev.get('summit__Account__c') == null) reasons.add('Parent event missing account');
            String gateway = (String) ev.get('summit__Payment_Gateway__c');
            if (!String.isBlank(gateway) && gateway != 'No Gateway' && ev.get('Accounting_Department__c') == null) {
                reasons.add('Paid event missing accounting department');
            }
        }
        return reasons.isEmpty() ? null : String.join(reasons, '; ');
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
