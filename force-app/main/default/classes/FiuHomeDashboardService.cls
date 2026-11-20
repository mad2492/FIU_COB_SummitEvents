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
    public static DashboardData loadDashboard(String programCode, String recordTypeId) {
        DashboardData data = new DashboardData();
        data.upcomingInstances = 0;
        data.openRegistrations = 0;
        data.startedRegistrations = 0;
        data.notReadyInstances = 0;
        data.notReadyEvents = 0;
        data.activeEvents = 0;
        data.attentionRows = new List<AttentionRow>();
        data.upcomingRows = new List<UpcomingRow>();

        Set<Id> allowedRt = FiuEventsAccessService.getScopedEventRecordTypeIds(recordTypeId);
        if (allowedRt.isEmpty()) return data;

        Date today = Date.today();

        FiuProgramFilterService.ProgramFilterConfig programConfig = FiuProgramFilterService.getConfig();
        String previewField = FiuEventsAccessService.resolveEventPreviewField();
        Map<String, Schema.SObjectField> eventFields =
            Schema.getGlobalDescribe().get('summit__Summit_Events__c').getDescribe().fields.getMap();
        String capacityField = resolveOptionalField(eventFields, new List<String>{ 'summit__Capacity__c', 'Capacity__c' });
        String readinessStatusField = resolveOptionalField(eventFields, new List<String>{ 'FIU_Readiness_Status__c' });
        String readinessReasonField = resolveOptionalField(eventFields, new List<String>{ 'FIU_Readiness_Reason__c' });
        List<String> activeEventFields = new List<String>{
            'Id',
            'Name',
            'summit__Event_Status__c',
            'summit__Account__c',
            'FIU_Create_Opps_From_Regs__c',
            'Send_Registration_Confirmation_Email__c',
            'Default_Plan__c',
            'Includes_Multiple_Programs__c',
            'summit__Add_Info_Question_Text_1__c',
            'summit__Add_Info_Question_Pick_List_1__c',
            'summit__Add_Info_Question_Pick_List_Long_1__c',
            'summit__Event_Additional_Question_Title__c',
            'summit__Event_Additional_Questions_Description__c',
            'summit__Event_description__c',
            'summit__Event_Short_Listing_Description__c',
            'summit__Event_Footer__c',
            'summit__Event_Full_Text__c',
            'summit__Event_Confirmation_Description__c'
        };
        if (capacityField != null) activeEventFields.add(capacityField);
        if (readinessStatusField != null) activeEventFields.add(readinessStatusField);
        if (readinessReasonField != null) activeEventFields.add(readinessReasonField);
        activeEventFields.addAll(programConfig.eventProgramFields);
        if (programConfig.hasDefaultPlanLookup) activeEventFields.add('Default_Plan__r.Plan_Code__c');
        String activeEventSoql =
            'SELECT ' + String.join(activeEventFields, ',') +
            ' FROM summit__Summit_Events__c WHERE RecordTypeId IN :allowedRt AND summit__Event_Status__c = \'Active\'';
        if (previewField != null) activeEventSoql += ' AND (' + previewField + ' = false OR ' + previewField + ' = null)';
        String eventProgramClause = FiuProgramFilterService.buildProgramWhereClause('', programCode, programConfig);
        if (eventProgramClause != null) activeEventSoql += ' AND ' + eventProgramClause;
        String activeEventCountSoql =
            'SELECT COUNT() FROM summit__Summit_Events__c WHERE RecordTypeId IN :allowedRt AND summit__Event_Status__c = \'Active\'';
        if (previewField != null) activeEventCountSoql += ' AND (' + previewField + ' = false OR ' + previewField + ' = null)';
        if (eventProgramClause != null) activeEventCountSoql += ' AND ' + eventProgramClause;
        data.activeEvents = Integer.valueOf(Database.countQuery(activeEventCountSoql));
        activeEventSoql += ' LIMIT 10000';
        List<SObject> activeEventRows = Database.query(activeEventSoql);
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
            Integer questionCount = questionCountByEventId.containsKey((Id) eventRow.get('Id')) ? questionCountByEventId.get((Id) eventRow.get('Id')) : 0;
            String eventReason = readinessReasonField == null ? null : (String) eventRow.get(readinessReasonField);
            if (String.isBlank(eventReason)) {
                eventReason = getEventNotReadyReason(eventRow, programConfig, questionCount, capacityField);
            }
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
            'summit__Event__r.Name', 'summit__Event__r.summit__Account__c', 'summit__Event__r.summit__Payment_Gateway__c', 'summit__Event__r.Accounting_Department__c',
            'summit__Event__r.FIU_Create_Opps_From_Regs__c', 'summit__Event__r.Send_Registration_Confirmation_Email__c',
            'summit__Event__r.summit__Add_Info_Question_Text_1__c',
            'summit__Event__r.summit__Add_Info_Question_Pick_List_1__c',
            'summit__Event__r.summit__Add_Info_Question_Pick_List_Long_1__c'
        };
        String instanceReadinessReasonField = resolveOptionalField('summit__Summit_Events_Instance__c', new List<String>{ 'FIU_Readiness_Reason__c' });
        if (instanceReadinessReasonField != null) instanceFields.add(instanceReadinessReasonField);
        String instanceCapacityField = resolveOptionalField('summit__Summit_Events_Instance__c', new List<String>{ 'summit__Capacity__c', 'Capacity__c' });
        if (instanceCapacityField != null) instanceFields.add(instanceCapacityField);
        for (String eventProgramField : programConfig.eventProgramFields) {
            instanceFields.add('summit__Event__r.' + eventProgramField);
        }
        if (programConfig.hasDefaultPlanLookup) instanceFields.add('summit__Event__r.Default_Plan__r.Plan_Code__c');
        String instanceSoql =
            'SELECT ' + String.join(instanceFields, ',') +
            ' FROM summit__Summit_Events_Instance__c WHERE summit__Event__r.RecordTypeId IN :allowedRt';
        if (previewField != null) instanceSoql += ' AND (summit__Event__r.' + previewField + ' = false OR summit__Event__r.' + previewField + ' = null)';
        String instanceProgramClause = FiuProgramFilterService.buildProgramWhereClause('summit__Event__r.', programCode, programConfig);
        if (instanceProgramClause != null) instanceSoql += ' AND ' + instanceProgramClause;
        String upcomingCountSoql =
            'SELECT COUNT() FROM summit__Summit_Events_Instance__c WHERE summit__Event__r.RecordTypeId IN :allowedRt AND summit__Instance_Start_Date__c >= :today';
        if (previewField != null) upcomingCountSoql += ' AND (summit__Event__r.' + previewField + ' = false OR summit__Event__r.' + previewField + ' = null)';
        if (instanceProgramClause != null) upcomingCountSoql += ' AND ' + instanceProgramClause;
        data.upcomingInstances = Integer.valueOf(Database.countQuery(upcomingCountSoql));
        instanceSoql += ' ORDER BY summit__Instance_Start_Date__c ASC NULLS LAST LIMIT 10000';
        List<SObject> instances = Database.query(instanceSoql);

        for (SObject row : instances) {
            if (!FiuProgramFilterService.eventMatchesSelectedProgram(row.getSObject('summit__Event__r'), programConfig, programCode)) continue;
            Date startDate = (Date) row.get('summit__Instance_Start_Date__c');
            String reason = instanceReadinessReasonField == null ? null : (String) row.get(instanceReadinessReasonField);
            if (String.isBlank(reason)) reason = getNotReadyReason(row, instanceCapacityField);

            if (startDate != null && startDate >= today) {
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

        String statusField = resolveOptionalField('summit__Summit_Events_Registration__c', new List<String>{ 'summit__Status__c', 'Status__c' });
        String registrationBaseCountSoql =
            'SELECT COUNT() FROM summit__Summit_Events_Registration__c WHERE summit__Event_Instance__r.summit__Event__r.RecordTypeId IN :allowedRt' +
            ' AND summit__Event_Instance__r.summit__Instance_Start_Date__c >= :today';
        if (previewField != null) registrationBaseCountSoql += ' AND (summit__Event_Instance__r.summit__Event__r.' + previewField + ' = false OR summit__Event_Instance__r.summit__Event__r.' + previewField + ' = null)';
        String registrationProgramClause = FiuProgramFilterService.buildProgramWhereClause('summit__Event_Instance__r.summit__Event__r.', programCode, programConfig);
        if (registrationProgramClause != null) registrationBaseCountSoql += ' AND ' + registrationProgramClause;
        if (statusField == null) {
            data.openRegistrations = Integer.valueOf(Database.countQuery(registrationBaseCountSoql));
        } else {
            data.startedRegistrations = Integer.valueOf(Database.countQuery(registrationBaseCountSoql + ' AND ' + statusField + ' = \'Started\''));
            data.openRegistrations = Integer.valueOf(Database.countQuery(registrationBaseCountSoql + ' AND ' + statusField + ' NOT IN (\'Started\', \'Cancelled\')'));
        }

        return data;
    }

    private static String getEventNotReadyReason(SObject eventRow, FiuProgramFilterService.ProgramFilterConfig programConfig, Integer relatedQuestionCount, String capacityField) {
        FiuReadinessPolicyService.EventPolicyContext context = new FiuReadinessPolicyService.EventPolicyContext();
        context.eventCapacityField = capacityField;
        context.programConfig = programConfig;
        context.relatedQuestionCount = relatedQuestionCount;
        context.includeProgramCheck = true;
        context.includeRelatedInstancePresenceCheck = false;
        context.includeRelatedInstanceCapacityCheck = false;
        List<String> reasons = FiuReadinessPolicyService.evaluateEvent(eventRow, context).blockingMessages();
        return reasons.isEmpty() ? null : String.join(reasons, '; ');
    }

    private static String getNotReadyReason(SObject row, String instanceCapacityField) {
        FiuReadinessPolicyService.InstancePolicyContext context = new FiuReadinessPolicyService.InstancePolicyContext();
        context.instanceCapacityField = instanceCapacityField;
        List<String> reasons = FiuReadinessPolicyService.evaluateInstance(row, row.getSObject('summit__Event__r'), context).blockingMessages();
        return reasons.isEmpty() ? null : String.join(reasons, '; ');
    }

    private static String resolveOptionalField(String objectApiName, List<String> candidates) {
        Schema.SObjectType sType = Schema.getGlobalDescribe().get(objectApiName);
        if (sType == null) return null;
        Map<String, Schema.SObjectField> mapFields = sType.getDescribe().fields.getMap();
        return resolveOptionalField(mapFields, candidates);
    }

    private static String resolveOptionalField(Map<String, Schema.SObjectField> mapFields, List<String> candidates) {
        if (mapFields == null || candidates == null) return null;
        for (String fieldApi : candidates) {
            if (mapFields.containsKey(fieldApi)) return fieldApi;
        }
        return null;
    }
}
