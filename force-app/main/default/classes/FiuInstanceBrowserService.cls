public with sharing class FiuInstanceBrowserService {
    public class InstanceQueryResult {
        @AuraEnabled public List<InstanceRow> rows;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public String nextCursor;
        @AuraEnabled public Boolean hasNext;
        @AuraEnabled public Boolean hasPrevious;
        @AuraEnabled public Boolean cursorPaging;
    }

    public class InstanceRow {
        @AuraEnabled public Id id;
        @AuraEnabled public Id eventId;
        @AuraEnabled public String title;
        @AuraEnabled public String eventName;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public String activeStatus;
        @AuraEnabled public String readiness;
        @AuraEnabled public String unpublishedReason;
        @AuraEnabled public Decimal capacity;
        @AuraEnabled public Integer registrationCount;
        @AuraEnabled public String registerUrl;
    }

    private class SortSpec {
        public String key;
        public String soqlField;
        public String valueType;
        public String direction;
    }

    private class InstanceCursor {
        public String sortField;
        public String sortDir;
        public String stringValue;
        public Date dateValue;
        public Datetime datetimeValue;
        public Id id;
    }

    @AuraEnabled(cacheable=true)
    public static InstanceQueryResult queryInstances(Id eventId, String searchKey, String bucketFilter, String programCode, Integer pageNumber, Integer pageSize, String sortField1, String sortDir1, String sortField2, String sortDir2, String pageCursor, String recordTypeId) {
        InstanceQueryResult result = new InstanceQueryResult();
        result.rows = new List<InstanceRow>();
        result.totalCount = 0;
        result.hasNext = false;
        result.hasPrevious = false;
        result.cursorPaging = false;
        Set<Id> allowedRecordTypes = FiuEventsAccessService.getScopedEventRecordTypeIds(recordTypeId);
        if (allowedRecordTypes.isEmpty()) return result;
        FiuProgramFilterService.ProgramFilterConfig programConfig = FiuProgramFilterService.getConfig();
        String previewField = FiuEventsAccessService.resolveEventPreviewField();
        String normalizedSearch = String.isBlank(searchKey) ? null : searchKey.trim().toLowerCase();

        List<String> fields = new List<String>{
            'Id', 'CreatedDate', 'summit__Instance_Title__c', 'summit__Instance_Start_Date__c', 'summit__Instance_End_Date__c',
            'summit__Active_Status__c', 'summit__Open_Registration__c', 'summit__Capacity__c', 'summit__Registration_Link__c',
            'summit__Location_Title_Override__c', 'summit__Location_Address_Override__c', 'summit__Location_Map_Link_Override__c', 'Parking_info__c',
            'summit__Event__r.Id', 'summit__Event__r.Name', 'summit__Event__r.summit__Account__c', 'summit__Event__r.summit__Payment_Gateway__c', 'summit__Event__r.Accounting_Department__c',
            'summit__Event__r.FIU_Create_Opps_From_Regs__c', 'summit__Event__r.Send_Registration_Confirmation_Email__c',
            'summit__Event__r.Default_Plan__c', 'summit__Event__r.Includes_Multiple_Programs__c',
            'summit__Event__r.summit__Add_Info_Question_Text_1__c',
            'summit__Event__r.summit__Add_Info_Question_Pick_List_1__c',
            'summit__Event__r.summit__Add_Info_Question_Pick_List_Long_1__c',
            'summit__Event__r.summit__Event_Additional_Question_Title__c', 'summit__Event__r.summit__Event_Additional_Questions_Description__c',
            'summit__Event__r.summit__Event_description__c', 'summit__Event__r.summit__Event_Short_Listing_Description__c',
            'summit__Event__r.summit__Event_Footer__c', 'summit__Event__r.summit__Event_Full_Text__c',
            'summit__Event__r.summit__Event_Confirmation_Description__c'
        };
        for (String eventProgramField : programConfig.eventProgramFields) {
            fields.add('summit__Event__r.' + eventProgramField);
        }
        if (programConfig.hasDefaultPlanLookup) fields.add('summit__Event__r.Default_Plan__r.Plan_Code__c');

        String soql = 'SELECT ' + String.join(fields, ',') +
            ' FROM summit__Summit_Events_Instance__c WHERE summit__Event__r.RecordTypeId IN :allowedRecordTypes';
        if (previewField != null) soql += ' AND (summit__Event__r.' + previewField + ' = false OR summit__Event__r.' + previewField + ' = null)';

        if (eventId != null) soql += ' AND summit__Event__c = :eventId';
        String programClause = FiuProgramFilterService.buildProgramWhereClause('summit__Event__r.', programCode, programConfig);
        if (programClause != null) soql += ' AND ' + programClause;
        Date today = Date.today();
        if (bucketFilter == 'Upcoming') soql += ' AND summit__Instance_Start_Date__c >= :today';
        if (bucketFilter == 'Past') soql += ' AND summit__Instance_Start_Date__c < :today';

        Integer safePageSize = pageSize == null || pageSize < 1 ? 25 : Math.min(pageSize, 100);
        Integer safePageNumber = pageNumber == null || pageNumber < 1 ? 1 : pageNumber;
        Integer offsetRows = (safePageNumber - 1) * safePageSize;
        SortSpec keysetSort = resolveSortSpec(sortField1, sortDir1);
        String orderBy = buildOrderBy(sortField1, sortDir1, sortField2, sortDir2);
        List<SObject> queriedRows;
        if (normalizedSearch == null && bucketFilter != 'Unpublished') {
            InstanceCursor cursor = decodeCursor(pageCursor);
            if (cursor != null && (cursor.sortField != keysetSort.key || cursor.sortDir != keysetSort.direction)) {
                cursor = null;
            }

            String cursorStringValue = cursor == null ? null : cursor.stringValue;
            Date cursorDateValue = cursor == null ? null : cursor.dateValue;
            Datetime cursorDatetimeValue = cursor == null ? null : cursor.datetimeValue;
            Id cursorIdValue = cursor == null ? null : cursor.id;
            String cursorPredicate = buildKeysetPredicate(keysetSort, cursor);
            if (cursorPredicate != null) soql += ' AND ' + cursorPredicate;

            Integer queryLimit = safePageSize + 1;
            soql += ' ORDER BY ' + buildKeysetOrderBy(keysetSort) + ' LIMIT :queryLimit';
            queriedRows = Database.query(soql);
            result.cursorPaging = true;
            result.hasPrevious = cursor != null;
            result.hasNext = queriedRows.size() > safePageSize;
            if (result.hasNext) queriedRows.remove(queriedRows.size() - 1);
            result.totalCount = queriedRows.size();
            if (result.hasNext && !queriedRows.isEmpty()) {
                result.nextCursor = encodeCursor(queriedRows[queriedRows.size() - 1], keysetSort);
            }
        } else {
            soql += ' ORDER BY ' + orderBy + ' LIMIT 10000';
            queriedRows = Database.query(soql);
        }

        Set<Id> instanceIds = new Set<Id>();
        Set<Id> eventIds = new Set<Id>();
        for (SObject row : queriedRows) {
            instanceIds.add((Id) row.get('Id'));
            SObject evt = row.getSObject('summit__Event__r');
            if (evt != null && evt.get('Id') != null) {
                eventIds.add((Id) evt.get('Id'));
            }
        }

        Map<Id, Integer> registrationCountByInstanceId = new Map<Id, Integer>();
        if (!instanceIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT summit__Event_Instance__c instanceId, COUNT(Id) rowCount
                FROM summit__Summit_Events_Registration__c
                WHERE summit__Event_Instance__c IN :instanceIds
                GROUP BY summit__Event_Instance__c
            ]) {
                registrationCountByInstanceId.put(
                    (Id) ar.get('instanceId'),
                    Integer.valueOf(String.valueOf(ar.get('rowCount')))
                );
            }
        }

        Map<Id, Integer> questionCountByEventId = new Map<Id, Integer>();
        String questionObject = FiuEventsAccessService.resolveEventQuestionObject();
        String questionEventLookup = FiuEventsAccessService.resolveEventQuestionLookupField();
        if (!eventIds.isEmpty() && questionObject != null && questionEventLookup != null) {
            try {
                String questionSoql =
                    'SELECT ' + questionEventLookup + ' eventId, COUNT(Id) rowCount FROM ' + questionObject +
                    ' WHERE ' + questionEventLookup + ' IN :eventIds GROUP BY ' + questionEventLookup;
                for (AggregateResult ar : Database.query(questionSoql)) {
                    questionCountByEventId.put((Id) ar.get('eventId'), Integer.valueOf(String.valueOf(ar.get('rowCount'))));
                }
            } catch (Exception ex) {
                // Ignore if the related question object is unavailable in the current context.
            }
        }

        List<InstanceRow> outRows = new List<InstanceRow>();
        for (SObject row : queriedRows) {
            InstanceRow r = new InstanceRow();
            r.id = (Id) row.get('Id');
            r.title = (String) row.get('summit__Instance_Title__c');
            r.startDate = (Date) row.get('summit__Instance_Start_Date__c');
            r.endDate = (Date) row.get('summit__Instance_End_Date__c');
            r.activeStatus = (String) row.get('summit__Active_Status__c');
            r.capacity = (Decimal) row.get('summit__Capacity__c');
            SObject evt = row.getSObject('summit__Event__r');
            r.eventId = evt == null ? null : (Id) evt.get('Id');
            r.eventName = evt == null ? null : (String) evt.get('Name');
            String instanceReason = getUnpublishedReason(row);
            String parentEventReason = evt == null ? null : getParentEventNotReadyReason(
                evt,
                programConfig,
                questionCountByEventId.containsKey((Id) evt.get('Id')) ? questionCountByEventId.get((Id) evt.get('Id')) : 0
            );
            String combinedReason = combineReasons(instanceReason, parentEventReason);
            r.unpublishedReason = combinedReason;
            r.readiness = String.isBlank(combinedReason) ? 'Ready' : 'Not Ready';
            r.registrationCount = registrationCountByInstanceId.containsKey(r.id) ? registrationCountByInstanceId.get(r.id) : 0;
            r.registerUrl = extractRegistrationUrl((String) row.get('summit__Registration_Link__c'));

            if (bucketFilter == 'Unpublished' && String.isBlank(combinedReason)) {
                continue;
            }
            if (normalizedSearch != null && !matchesSearch(r, normalizedSearch)) {
                continue;
            }
            outRows.add(r);
        }
        if (bucketFilter == 'Unpublished' || normalizedSearch != null) {
            result.totalCount = outRows.size();
            Integer startIndex = offsetRows;
            if (startIndex >= outRows.size()) {
                result.rows = new List<InstanceRow>();
                result.totalCount = outRows.size();
                return result;
            }
            Integer endIndex = Math.min(startIndex + safePageSize, outRows.size());
            List<InstanceRow> pageRows = new List<InstanceRow>();
            for (Integer i = startIndex; i < endIndex; i++) pageRows.add(outRows[i]);
            result.rows = pageRows;
            return result;
        }
        result.rows = outRows;
        return result;
    }

    private static SortSpec resolveSortSpec(String sortField, String sortDir) {
        SortSpec spec = new SortSpec();
        spec.key = String.isBlank(sortField) ? 'startDate' : sortField;
        spec.direction = String.valueOf(sortDir).toUpperCase() == 'ASC' ? 'ASC' : 'DESC';
        Map<String, String> sortMap = new Map<String, String>{
            'title' => 'summit__Instance_Title__c',
            'eventName' => 'summit__Event__r.Name',
            'startDate' => 'summit__Instance_Start_Date__c',
            'activeStatus' => 'summit__Active_Status__c',
            'createdDate' => 'CreatedDate'
        };
        Map<String, String> typeMap = new Map<String, String>{
            'title' => 'String',
            'eventName' => 'String',
            'startDate' => 'Date',
            'activeStatus' => 'String',
            'createdDate' => 'Datetime'
        };
        if (!sortMap.containsKey(spec.key)) spec.key = 'startDate';
        spec.soqlField = sortMap.get(spec.key);
        spec.valueType = typeMap.get(spec.key);
        return spec;
    }

    private static String buildKeysetOrderBy(SortSpec spec) {
        return spec.soqlField + ' ' + spec.direction + ' NULLS LAST, Id ASC';
    }

    private static String buildKeysetPredicate(SortSpec spec, InstanceCursor cursor) {
        if (cursor == null || cursor.id == null) return null;
        String bindName = spec.valueType == 'Date' ? 'cursorDateValue'
            : spec.valueType == 'Datetime' ? 'cursorDatetimeValue'
            : 'cursorStringValue';
        Boolean cursorValueIsNull = (spec.valueType == 'Date' && cursor.dateValue == null)
            || (spec.valueType == 'Datetime' && cursor.datetimeValue == null)
            || (spec.valueType == 'String' && cursor.stringValue == null);
        if (cursorValueIsNull) {
            return '(' + spec.soqlField + ' = null AND Id > :cursorIdValue)';
        }
        String comparison = spec.direction == 'ASC' ? '>' : '<';
        return '((' + spec.soqlField + ' ' + comparison + ' :' + bindName + ')'
            + ' OR (' + spec.soqlField + ' = :' + bindName + ' AND Id > :cursorIdValue)'
            + ' OR ' + spec.soqlField + ' = null)';
    }

    private static String encodeCursor(SObject row, SortSpec spec) {
        InstanceCursor cursor = new InstanceCursor();
        cursor.sortField = spec.key;
        cursor.sortDir = spec.direction;
        cursor.id = (Id) row.get('Id');
        Object sortValue = getSortValue(row, spec);
        if (spec.valueType == 'Date') cursor.dateValue = (Date) sortValue;
        else if (spec.valueType == 'Datetime') cursor.datetimeValue = (Datetime) sortValue;
        else cursor.stringValue = (String) sortValue;
        return EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(cursor)));
    }

    private static InstanceCursor decodeCursor(String pageCursor) {
        if (String.isBlank(pageCursor)) return null;
        try {
            String decoded = EncodingUtil.base64Decode(pageCursor).toString();
            return (InstanceCursor) JSON.deserialize(decoded, InstanceCursor.class);
        } catch (Exception ex) {
            throw new AuraHandledException('The instance list position expired. Refresh the page and try again.');
        }
    }

    private static Object getSortValue(SObject row, SortSpec spec) {
        if (spec.key == 'eventName') {
            SObject evt = row.getSObject('summit__Event__r');
            return evt == null ? null : evt.get('Name');
        }
        return row.get(spec.soqlField);
    }

    private static String buildOrderBy(String sortField1, String sortDir1, String sortField2, String sortDir2) {
        Map<String, String> sortMap = new Map<String, String>{
            'title' => 'summit__Instance_Title__c',
            'eventName' => 'summit__Event__r.Name',
            'startDate' => 'summit__Instance_Start_Date__c',
            'activeStatus' => 'summit__Active_Status__c',
            'createdDate' => 'CreatedDate'
        };
        List<String> orderParts = new List<String>();
        addSortPart(orderParts, sortMap, sortField1, sortDir1);
        addSortPart(orderParts, sortMap, sortField2, sortDir2);
        if (orderParts.isEmpty()) return 'summit__Instance_Start_Date__c ASC NULLS LAST, Id ASC';
        orderParts.add('Id ASC');
        return String.join(orderParts, ', ');
    }

    private static void addSortPart(List<String> orderParts, Map<String, String> sortMap, String sortField, String sortDir) {
        if (String.isBlank(sortField) || !sortMap.containsKey(sortField)) return;
        String dir = String.valueOf(sortDir).toUpperCase() == 'ASC' ? 'ASC' : 'DESC';
        String part = sortMap.get(sortField) + ' ' + dir + ' NULLS LAST';
        if (!orderParts.contains(part)) orderParts.add(part);
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

        return reasons.isEmpty() ? null : String.join(reasons, '; ');
    }

    private static String getParentEventNotReadyReason(SObject eventRow, FiuProgramFilterService.ProgramFilterConfig programConfig, Integer relatedQuestionCount) {
        FiuReadinessPolicyService.EventPolicyContext context = new FiuReadinessPolicyService.EventPolicyContext();
        context.programConfig = programConfig;
        context.relatedQuestionCount = relatedQuestionCount;
        context.includeProgramCheck = true;
        context.includeEventCapacityCheck = false;
        context.includeRelatedInstancePresenceCheck = false;
        context.includeRelatedInstanceCapacityCheck = false;
        List<String> reasons = FiuReadinessPolicyService.evaluateEvent(eventRow, context).blockingMessages();
        String gateway = (String) eventRow.get('summit__Payment_Gateway__c');
        if (!String.isBlank(gateway) && gateway != 'No Gateway' && eventRow.get('Accounting_Department__c') == null) {
            reasons.add('Paid event missing Accounting Department');
        }
        return reasons.isEmpty() ? null : String.join(reasons, '; ');
    }

    private static String combineReasons(String firstReason, String secondReason) {
        List<String> reasons = new List<String>();
        appendReasons(reasons, firstReason);
        appendReasons(reasons, secondReason);
        return reasons.isEmpty() ? null : String.join(reasons, '; ');
    }

    private static void appendReasons(List<String> reasons, String reasonString) {
        if (String.isBlank(reasonString)) return;
        for (String reason : reasonString.split(';')) {
            String trimmedReason = reason == null ? null : reason.trim();
            if (!String.isBlank(trimmedReason) && !reasons.contains(trimmedReason)) {
                reasons.add(trimmedReason);
            }
        }
    }

    private static String extractRegistrationUrl(String rawValue) {
        if (String.isBlank(rawValue)) return null;
        String trimmedValue = rawValue.trim();
        String lowerValue = trimmedValue.toLowerCase();
        if (!lowerValue.startsWith('<a')) {
            return trimmedValue;
        }

        Pattern hrefPattern = Pattern.compile('(?i)href\\s*=\\s*"([^"]+)"');
        Matcher hrefMatcher = hrefPattern.matcher(trimmedValue);
        if (hrefMatcher.find()) {
            return hrefMatcher.group(1);
        }

        Pattern singleQuoteHrefPattern = Pattern.compile('(?i)href\\s*=\\s*\\\'([^\\\']+)\\\'');
        Matcher singleQuoteHrefMatcher = singleQuoteHrefPattern.matcher(trimmedValue);
        if (singleQuoteHrefMatcher.find()) {
            return singleQuoteHrefMatcher.group(1);
        }

        return null;
    }

    private static Boolean matchesSearch(InstanceRow row, String normalizedSearch) {
        List<String> haystacks = new List<String>{
            row.title,
            row.eventName,
            row.activeStatus,
            row.readiness,
            row.unpublishedReason
        };
        for (String value : haystacks) {
            if (!String.isBlank(value) && value.toLowerCase().contains(normalizedSearch)) {
                return true;
            }
        }
        return false;
    }
}
