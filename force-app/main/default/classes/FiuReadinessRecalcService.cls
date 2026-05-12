public with sharing class FiuReadinessRecalcService {
    private static Boolean internalUpdateInProgress = false;

    public static Boolean isInternalUpdateInProgress() {
        return internalUpdateInProgress;
    }

    public static void enqueueForEvents(Set<Id> eventIds) {
        Set<Id> safeIds = sanitizeIds(eventIds);
        if (safeIds.isEmpty()) return;
        System.enqueueJob(new RecalcQueueable(safeIds, new Set<Id>()));
    }

    public static void enqueueForInstances(Set<Id> instanceIds) {
        Set<Id> safeIds = sanitizeIds(instanceIds);
        if (safeIds.isEmpty()) return;
        System.enqueueJob(new RecalcQueueable(new Set<Id>(), safeIds));
    }

    public static void recalcNow(Set<Id> eventIds, Set<Id> instanceIds) {
        Set<Id> safeEventIds = sanitizeIds(eventIds);
        Set<Id> safeInstanceIds = sanitizeIds(instanceIds);
        if (safeEventIds.isEmpty() && safeInstanceIds.isEmpty()) return;

        String eventObject = FiuEventsAccessService.resolveEventObject();
        String instanceObject = FiuEventsAccessService.resolveInstanceObject();
        if (String.isBlank(eventObject) || String.isBlank(instanceObject)) return;

        Schema.SObjectType eventType = Schema.getGlobalDescribe().get(eventObject);
        Schema.SObjectType instanceType = Schema.getGlobalDescribe().get(instanceObject);
        if (eventType == null || instanceType == null) return;
        Map<String, Schema.SObjectField> eventFields = eventType.getDescribe().fields.getMap();
        Map<String, Schema.SObjectField> instanceFields = instanceType.getDescribe().fields.getMap();

        String eventReadinessStatusField = resolveOptionalField(eventFields, new List<String>{ 'FIU_Readiness_Status__c' });
        String eventReadinessReasonField = resolveOptionalField(eventFields, new List<String>{ 'FIU_Readiness_Reason__c' });
        String eventReadinessUpdatedAtField = resolveOptionalField(eventFields, new List<String>{ 'FIU_Readiness_Updated_At__c' });
        String instanceReadinessStatusField = resolveOptionalField(instanceFields, new List<String>{ 'FIU_Readiness_Status__c' });
        String instanceReadinessReasonField = resolveOptionalField(instanceFields, new List<String>{ 'FIU_Readiness_Reason__c' });
        String instanceReadinessUpdatedAtField = resolveOptionalField(instanceFields, new List<String>{ 'FIU_Readiness_Updated_At__c' });
        if (eventReadinessStatusField == null || eventReadinessReasonField == null || instanceReadinessStatusField == null || instanceReadinessReasonField == null) {
            return;
        }

        String instanceEventLookupField = resolveOptionalField(instanceFields, new List<String>{ 'summit__Event__c', 'summit__Summit_Event__c', 'Event__c' });
        if (instanceEventLookupField == null) return;

        Set<Id> allEventIds = new Set<Id>();
        allEventIds.addAll(safeEventIds);
        Map<Id, SObject> instanceRowsById = new Map<Id, SObject>();

        if (!safeInstanceIds.isEmpty()) {
            List<String> instanceSelectFields = new List<String>{
                'Id',
                instanceEventLookupField,
                'summit__Instance_Start_Date__c',
                'summit__Active_Status__c',
                'summit__Open_Registration__c',
                'summit__Location_Title_Override__c',
                'summit__Location_Address_Override__c',
                'summit__Location_Map_Link_Override__c',
                'Parking_info__c'
            };
            String instCapField = resolveOptionalField(instanceFields, new List<String>{ 'summit__Capacity__c', 'Capacity__c' });
            if (instCapField != null) instanceSelectFields.add(instCapField);
            String instSoql = 'SELECT ' + String.join(instanceSelectFields, ',') + ' FROM ' + instanceObject + ' WHERE Id IN :safeInstanceIds';
            for (SObject row : Database.query(instSoql)) {
                instanceRowsById.put((Id) row.get('Id'), row);
                Id parentEventId = (Id) row.get(instanceEventLookupField);
                if (parentEventId != null) allEventIds.add(parentEventId);
            }
        }

        if (allEventIds.isEmpty()) return;

        FiuProgramFilterService.ProgramFilterConfig programConfig = FiuProgramFilterService.getConfig();
        List<String> eventSelectFields = new List<String>{
            'Id',
            'summit__Account__c',
            'summit__Payment_Gateway__c',
            'Accounting_Department__c',
            'Default_Plan__c',
            'Includes_Multiple_Programs__c',
            'summit__Event_Additional_Question_Title__c',
            'summit__Event_Additional_Questions_Description__c',
            'summit__Event_description__c',
            'summit__Event_Short_Listing_Description__c',
            'summit__Event_Footer__c',
            'summit__Event_Full_Text__c',
            'summit__Event_Confirmation_Description__c'
        };
        eventSelectFields.addAll(programConfig.eventProgramFields);
        if (programConfig.hasDefaultPlanLookup) eventSelectFields.add('Default_Plan__r.Plan_Code__c');

        Map<Id, SObject> eventRowsById = new Map<Id, SObject>();
        String eventSoql = 'SELECT ' + String.join(eventSelectFields, ',') + ' FROM ' + eventObject + ' WHERE Id IN :allEventIds';
        for (SObject row : Database.query(eventSoql)) {
            eventRowsById.put((Id) row.get('Id'), row);
        }
        if (eventRowsById.isEmpty()) return;

        Map<Id, Integer> questionCountByEventId = loadQuestionCounts(eventRowsById.keySet());

        List<String> childInstanceSelectFields = new List<String>{
            'Id',
            instanceEventLookupField,
            'summit__Instance_Start_Date__c',
            'summit__Active_Status__c',
            'summit__Open_Registration__c',
            'summit__Location_Title_Override__c',
            'summit__Location_Address_Override__c',
            'summit__Location_Map_Link_Override__c',
            'Parking_info__c'
        };
        String childInstCapField = resolveOptionalField(instanceFields, new List<String>{ 'summit__Capacity__c', 'Capacity__c' });
        if (childInstCapField != null) childInstanceSelectFields.add(childInstCapField);

        Map<Id, List<SObject>> instancesByEventId = new Map<Id, List<SObject>>();
        Set<Id> recalculationEventIds = eventRowsById.keySet();
        String allInstSoql =
            'SELECT ' + String.join(childInstanceSelectFields, ',') +
            ' FROM ' + instanceObject +
            ' WHERE ' + instanceEventLookupField + ' IN :recalculationEventIds';
        for (SObject inst : Database.query(allInstSoql)) {
            Id eventId = (Id) inst.get(instanceEventLookupField);
            if (eventId == null) continue;
            if (!instancesByEventId.containsKey(eventId)) instancesByEventId.put(eventId, new List<SObject>());
            instancesByEventId.get(eventId).add(inst);
            if (safeInstanceIds.contains((Id) inst.get('Id'))) {
                instanceRowsById.put((Id) inst.get('Id'), inst);
            }
        }

        List<SObject> instanceUpdates = new List<SObject>();
        for (Id instanceId : safeInstanceIds) {
            SObject instanceRow = instanceRowsById.get(instanceId);
            if (instanceRow == null) continue;
            SObject parentEvent = eventRowsById.get((Id) instanceRow.get(instanceEventLookupField));
            List<String> reasons = computeInstanceReasons(instanceRow, parentEvent, childInstCapField);
            String status = reasons.isEmpty() ? 'Ready' : 'Not Ready';
            String reason = reasons.isEmpty() ? null : String.join(reasons, '; ');
            SObject updateRow = instanceType.newSObject(instanceId);
            updateRow.put(instanceReadinessStatusField, status);
            updateRow.put(instanceReadinessReasonField, reason);
            if (instanceReadinessUpdatedAtField != null) updateRow.put(instanceReadinessUpdatedAtField, Datetime.now());
            instanceUpdates.add(updateRow);
        }

        List<SObject> eventUpdates = new List<SObject>();
        for (Id eventId : allEventIds) {
            SObject eventRow = eventRowsById.get(eventId);
            if (eventRow == null) continue;
            Integer questionCount = questionCountByEventId.containsKey(eventId) ? questionCountByEventId.get(eventId) : 0;
            List<String> reasons = computeEventReasons(eventRow, instancesByEventId.get(eventId), programConfig, questionCount, childInstCapField);
            String status = reasons.isEmpty() ? 'Ready' : 'Not Ready';
            String reason = reasons.isEmpty() ? null : String.join(reasons, '; ');
            SObject updateRow = eventType.newSObject(eventId);
            updateRow.put(eventReadinessStatusField, status);
            updateRow.put(eventReadinessReasonField, reason);
            if (eventReadinessUpdatedAtField != null) updateRow.put(eventReadinessUpdatedAtField, Datetime.now());
            eventUpdates.add(updateRow);
        }

        if (instanceUpdates.isEmpty() && eventUpdates.isEmpty()) return;
        internalUpdateInProgress = true;
        try {
            if (!instanceUpdates.isEmpty()) update instanceUpdates;
            if (!eventUpdates.isEmpty()) update eventUpdates;
        } finally {
            internalUpdateInProgress = false;
        }
    }

    private static List<String> computeEventReasons(SObject eventRow, List<SObject> relatedInstances, FiuProgramFilterService.ProgramFilterConfig programConfig, Integer relatedQuestionCount, String instanceCapacityField) {
        List<String> reasons = new List<String>();
        if (eventRow.get('summit__Account__c') == null) reasons.add('Missing account');

        Boolean includesMultiple = (Boolean) eventRow.get('Includes_Multiple_Programs__c');
        Boolean hasDefaultPlan = eventRow.get('Default_Plan__c') != null;
        Boolean hasProgramFilterCodes = !FiuProgramFilterService.extractProgramCodesFromEvent(eventRow, programConfig).isEmpty();
        if (includesMultiple == true) {
            if (!hasProgramFilterCodes && !hasDefaultPlan) reasons.add('Missing selected program');
        } else if (!hasDefaultPlan && !hasProgramFilterCodes) {
            reasons.add('Missing selected program');
        }

        String customQuestionTitle = (String) eventRow.get('summit__Event_Additional_Question_Title__c');
        String customQuestionDescription = (String) eventRow.get('summit__Event_Additional_Questions_Description__c');
        Boolean hasCustomQuestionPageDetails = !String.isBlank(customQuestionTitle) || !String.isBlank(customQuestionDescription);
        if (hasCustomQuestionPageDetails && (relatedQuestionCount == null || relatedQuestionCount == 0)) {
            reasons.add('Custom questions details set but no related Summit Event Questions');
        }
        reasons.addAll(FiuEventsReadinessService.collectRichTextImageWarnings(eventRow));

        Boolean hasInstances = relatedInstances != null && !relatedInstances.isEmpty();
        if (!hasInstances) {
            reasons.add('No instances configured');
        } else if (instanceCapacityField != null) {
            Boolean hasCapacityIssue = false;
            for (SObject inst : relatedInstances) {
                Decimal cap = (Decimal) inst.get(instanceCapacityField);
                if (cap == null || cap <= 0) {
                    hasCapacityIssue = true;
                    break;
                }
            }
            if (hasCapacityIssue) reasons.add('Instance missing capacity');
        }
        return reasons;
    }

    private static List<String> computeInstanceReasons(SObject instanceRow, SObject eventRow, String instanceCapacityField) {
        List<String> reasons = new List<String>();
        Date startDate = (Date) instanceRow.get('summit__Instance_Start_Date__c');
        Date today = Date.today();
        Boolean isPast = startDate != null && startDate < today;
        if (!isPast && (String) instanceRow.get('summit__Active_Status__c') != 'Active') reasons.add('Not Active');
        if (!isPast && (Boolean) instanceRow.get('summit__Open_Registration__c') == false) reasons.add('Registration closed');
        if (instanceCapacityField != null) {
            Decimal capacity = (Decimal) instanceRow.get(instanceCapacityField);
            if (capacity == null || capacity <= 0) reasons.add('Missing capacity');
        }
        if (instanceRow.get('summit__Location_Title_Override__c') == null) reasons.add('Missing location title');
        if (instanceRow.get('summit__Location_Address_Override__c') == null) reasons.add('Missing location address');
        if (instanceRow.get('summit__Location_Map_Link_Override__c') == null) reasons.add('Missing location map link');
        if (instanceRow.get('Parking_info__c') == null) reasons.add('Missing parking info');

        if (eventRow != null) {
            if (eventRow.get('summit__Account__c') == null) reasons.add('Parent event missing account');
            String gateway = (String) eventRow.get('summit__Payment_Gateway__c');
            if (!String.isBlank(gateway) && gateway != 'No Gateway' && eventRow.get('Accounting_Department__c') == null) {
                reasons.add('Paid event missing accounting department');
            }
        }
        return reasons;
    }

    private static Map<Id, Integer> loadQuestionCounts(Set<Id> eventIds) {
        Map<Id, Integer> counts = new Map<Id, Integer>();
        if (eventIds == null || eventIds.isEmpty()) return counts;
        String questionObject = FiuEventsAccessService.resolveEventQuestionObject();
        String questionEventLookup = FiuEventsAccessService.resolveEventQuestionLookupField();
        if (questionObject == null || questionEventLookup == null) return counts;
        try {
            String soql =
                'SELECT ' + questionEventLookup + ' eventId, COUNT(Id) rowCount FROM ' + questionObject +
                ' WHERE ' + questionEventLookup + ' IN :eventIds GROUP BY ' + questionEventLookup;
            for (AggregateResult ar : Database.query(soql)) {
                counts.put((Id) ar.get('eventId'), Integer.valueOf(String.valueOf(ar.get('rowCount'))));
            }
        } catch (Exception ex) {
            // Ignore if child object visibility differs in a given org context.
        }
        return counts;
    }

    private static Set<Id> sanitizeIds(Set<Id> ids) {
        Set<Id> out = new Set<Id>();
        if (ids == null) return out;
        for (Id idVal : ids) if (idVal != null) out.add(idVal);
        return out;
    }

    private static String resolveOptionalField(Map<String, Schema.SObjectField> fieldMap, List<String> candidates) {
        if (fieldMap == null || candidates == null) return null;
        for (String fieldApi : candidates) {
            if (fieldMap.containsKey(fieldApi)) return fieldApi;
        }
        return null;
    }

    public class RecalcQueueable implements Queueable {
        private Set<Id> eventIds;
        private Set<Id> instanceIds;

        public RecalcQueueable(Set<Id> eventIds, Set<Id> instanceIds) {
            this.eventIds = eventIds == null ? new Set<Id>() : eventIds;
            this.instanceIds = instanceIds == null ? new Set<Id>() : instanceIds;
        }

        public void execute(QueueableContext context) {
            FiuReadinessRecalcService.recalcNow(eventIds, instanceIds);
        }
    }
}
