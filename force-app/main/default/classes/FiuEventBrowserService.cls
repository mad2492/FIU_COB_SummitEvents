public with sharing class FiuEventBrowserService {
    public class EventQueryResult {
        @AuraEnabled public List<EventRow> rows;
        @AuraEnabled public Integer totalCount;
    }

    public class EventRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String recordType;
        @AuraEnabled public String status;
        @AuraEnabled public String statusClass;
        @AuraEnabled public Integer instanceCount;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public String readiness;
        @AuraEnabled public String readinessClass;
        @AuraEnabled public String issueReason;
    }

    @AuraEnabled(cacheable=true)
    public static EventQueryResult queryEvents(String searchKey, String statusFilter, String programCode, String readinessFilter, Integer pageNumber, Integer pageSize, String sortField1, String sortDir1, String sortField2, String sortDir2, String recordTypeId) {
        String eventObject = FiuEventsAccessService.resolveEventObject();
        EventQueryResult result = new EventQueryResult();
        result.rows = new List<EventRow>();
        result.totalCount = 0;
        if (eventObject == null) return result;

        Set<Id> allowedRecordTypes = FiuEventsAccessService.getScopedEventRecordTypeIds(recordTypeId);
        if (allowedRecordTypes.isEmpty()) return result;

        FiuProgramFilterService.ProgramFilterConfig programConfig = FiuProgramFilterService.getConfig();
        String previewField = FiuEventsAccessService.resolveEventPreviewField();
        Map<String, Schema.SObjectField> eventFields =
            Schema.getGlobalDescribe().get(eventObject).getDescribe().fields.getMap();
        String capacityField = resolveOptionalField(eventFields, new List<String>{ 'summit__Capacity__c', 'Capacity__c' });
        String readinessStatusField = resolveOptionalField(eventFields, new List<String>{ 'FIU_Readiness_Status__c' });
        String readinessReasonField = resolveOptionalField(eventFields, new List<String>{ 'FIU_Readiness_Reason__c' });
        String normalizedSearch = String.isBlank(searchKey) ? null : searchKey.trim().toLowerCase();
        List<String> selectFields = new List<String>{
            'Id', 'Name', 'RecordType.Name', 'summit__Event_Status__c', 'summit__Start_Date__c', 'summit__End_Date__c',
            'summit__Account__c', 'FIU_Create_Opps_From_Regs__c', 'Send_Registration_Confirmation_Email__c',
            'Default_Plan__c', 'Includes_Multiple_Programs__c', 'summit__Add_Info_Question_Text_1__c',
            'summit__Add_Info_Question_Pick_List_1__c', 'summit__Add_Info_Question_Pick_List_Long_1__c',
            'summit__Event_Additional_Question_Title__c', 'summit__Event_Additional_Questions_Description__c',
            'summit__Event_description__c', 'summit__Event_Short_Listing_Description__c',
            'summit__Event_Footer__c', 'summit__Event_Full_Text__c', 'summit__Event_Confirmation_Description__c'
        };
        if (capacityField != null) selectFields.add(capacityField);
        if (readinessStatusField != null) selectFields.add(readinessStatusField);
        if (readinessReasonField != null) selectFields.add(readinessReasonField);
        selectFields.addAll(programConfig.eventProgramFields);
        if (programConfig.hasDefaultPlanLookup) selectFields.add('Default_Plan__r.Plan_Code__c');

        String soql = 'SELECT ' + String.join(selectFields, ',') +
                      ' FROM ' + eventObject +
                      ' WHERE RecordTypeId IN :allowedRecordTypes';
        if (previewField != null) soql += ' AND (' + previewField + ' = false OR ' + previewField + ' = null)';

        if (String.isNotBlank(statusFilter)) {
            soql += ' AND summit__Event_Status__c = :statusFilter';
        }
        String programClause = FiuProgramFilterService.buildProgramWhereClause('', programCode, programConfig);
        if (programClause != null) soql += ' AND ' + programClause;

        Integer safePageSize = pageSize == null || pageSize < 1 ? 25 : Math.min(pageSize, 100);
        Integer safePageNumber = pageNumber == null || pageNumber < 1 ? 1 : pageNumber;
        Integer offsetRows = (safePageNumber - 1) * safePageSize;
        String orderedSoql = soql + ' ORDER BY ' + buildOrderBy(sortField1, sortDir1, sortField2, sortDir2);
        List<SObject> rawRows;
        if (normalizedSearch == null) {
            ApexPages.StandardSetController pager = new ApexPages.StandardSetController(Database.getQueryLocator(orderedSoql));
            pager.setPageSize(safePageSize);
            pager.setPageNumber(safePageNumber);
            result.totalCount = pager.getResultSize();
            rawRows = pager.getRecords();
        } else {
            orderedSoql += ' LIMIT 10000';
            rawRows = Database.query(orderedSoql);
        }

        Map<Id, Integer> questionCountByEventId = new Map<Id, Integer>();
        Map<Id, Integer> instanceCountByEventId = new Map<Id, Integer>();
        Set<Id> eventIds = new Set<Id>();
        for (SObject raw : rawRows) eventIds.add((Id) raw.get('Id'));
        if (!eventIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT summit__Event__c eventId, COUNT(Id) rowCount
                FROM summit__Summit_Events_Instance__c
                WHERE summit__Event__c IN :eventIds
                GROUP BY summit__Event__c
            ]) {
                instanceCountByEventId.put((Id) ar.get('eventId'), Integer.valueOf(String.valueOf(ar.get('rowCount'))));
            }
            String questionObject = FiuEventsAccessService.resolveEventQuestionObject();
            String questionEventLookup = FiuEventsAccessService.resolveEventQuestionLookupField();
            if (questionObject != null && questionEventLookup != null) {
                try {
                    String questionSoql =
                        'SELECT ' + questionEventLookup + ' eventId, COUNT(Id) rowCount FROM ' + questionObject +
                        ' WHERE ' + questionEventLookup + ' IN :eventIds GROUP BY ' + questionEventLookup;
                    for (AggregateResult ar : Database.query(questionSoql)) {
                        questionCountByEventId.put((Id) ar.get('eventId'), Integer.valueOf(String.valueOf(ar.get('rowCount'))));
                    }
                } catch (Exception ex) {
                    // Ignore if child object is unavailable in the current context.
                }
            }
        }

        List<EventRow> rows = new List<EventRow>();
        for (SObject record : rawRows) {
            Integer questionCount = questionCountByEventId.containsKey((Id) record.get('Id')) ? questionCountByEventId.get((Id) record.get('Id')) : 0;
            String issueReason = readinessReasonField == null ? null : (String) record.get(readinessReasonField);
            String persistedReadiness = readinessStatusField == null ? null : (String) record.get(readinessStatusField);
            if (String.isBlank(issueReason)) {
                issueReason = getEventIssueReason(record, programConfig, questionCount, capacityField);
            }
            if (readinessFilter == 'NotReady' && String.isBlank(issueReason)) continue;
            if (readinessFilter == 'Ready' && !String.isBlank(issueReason)) continue;
            EventRow row = new EventRow();
            row.id = (Id) record.get('Id');
            row.name = (String) record.get('Name');
            SObject rt = record.getSObject('RecordType');
            row.recordType = rt == null ? null : (String) rt.get('Name');
            row.status = (String) record.get('summit__Event_Status__c');
            row.instanceCount = instanceCountByEventId.containsKey(row.id) ? instanceCountByEventId.get(row.id) : 0;
            row.startDate = (Date) record.get('summit__Start_Date__c');
            row.endDate = (Date) record.get('summit__End_Date__c');
            row.issueReason = issueReason;
            if (!String.isBlank(persistedReadiness)) {
                row.readiness = persistedReadiness;
                if (persistedReadiness == 'Ready') {
                    row.readinessClass = 'slds-text-color_success slds-text-title_bold';
                    row.statusClass = 'slds-text-color_success';
                } else if (persistedReadiness == 'Needs Review') {
                    row.readinessClass = 'slds-text-color_warning slds-text-title_bold';
                    row.statusClass = 'slds-text-color_warning';
                } else {
                    row.readinessClass = 'slds-text-color_error slds-text-title_bold';
                    row.statusClass = row.status == 'Active' ? 'slds-text-color_error slds-text-title_bold' : 'slds-text-color_warning';
                }
            } else {
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
            }
            if (normalizedSearch != null && !matchesSearch(row, normalizedSearch)) continue;
            rows.add(row);
        }
        if (normalizedSearch != null) {
            result.totalCount = rows.size();
            Integer startIdx = Math.min(offsetRows, rows.size());
            Integer endIdx = Math.min(startIdx + safePageSize, rows.size());
            result.rows = new List<EventRow>();
            for (Integer idx = startIdx; idx < endIdx; idx++) {
                result.rows.add(rows[idx]);
            }
        } else {
            result.rows = rows;
        }
        return result;
    }

    private static String buildOrderBy(String sortField1, String sortDir1, String sortField2, String sortDir2) {
        Map<String, String> sortMap = new Map<String, String>{
            'name' => 'Name',
            'recordType' => 'RecordType.Name',
            'status' => 'summit__Event_Status__c',
            'startDate' => 'summit__Start_Date__c',
            'endDate' => 'summit__End_Date__c',
            'createdDate' => 'CreatedDate'
        };
        List<String> orderParts = new List<String>();
        addSortPart(orderParts, sortMap, sortField1, sortDir1);
        addSortPart(orderParts, sortMap, sortField2, sortDir2);
        if (orderParts.isEmpty()) return 'LastModifiedDate DESC';
        orderParts.add('LastModifiedDate DESC');
        return String.join(orderParts, ', ');
    }

    private static void addSortPart(List<String> orderParts, Map<String, String> sortMap, String sortField, String sortDir) {
        if (String.isBlank(sortField) || !sortMap.containsKey(sortField)) return;
        String dir = String.valueOf(sortDir).toUpperCase() == 'ASC' ? 'ASC' : 'DESC';
        String part = sortMap.get(sortField) + ' ' + dir + ' NULLS LAST';
        if (!orderParts.contains(part)) orderParts.add(part);
    }

    private static String getEventIssueReason(SObject eventRow, FiuProgramFilterService.ProgramFilterConfig programConfig, Integer relatedQuestionCount, String capacityField) {
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

    private static String resolveOptionalField(Map<String, Schema.SObjectField> fieldMap, List<String> candidates) {
        if (fieldMap == null || candidates == null) return null;
        for (String fieldApi : candidates) {
            if (fieldMap.containsKey(fieldApi)) return fieldApi;
        }
        return null;
    }

    private static Boolean matchesSearch(EventRow row, String normalizedSearch) {
        List<String> haystacks = new List<String>{
            row.name,
            row.recordType,
            row.status,
            row.readiness,
            row.issueReason
        };
        for (String value : haystacks) {
            if (!String.isBlank(value) && value.toLowerCase().contains(normalizedSearch)) {
                return true;
            }
        }
        return false;
    }
}
