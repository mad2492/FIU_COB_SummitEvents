/**
 * ExportCsvController
 *
 * Backing controller for ExportCsv.page.  Two modes via URL param "action":
 *
 * Download (default):
 *   Calls List View Describe → runs SOQL → streams CSV with
 *   Content-Disposition: attachment so the browser honours the filename.
 *
 * Email (?action=email&to=addr):
 *   Calls Describe → runs SOQL (up to 10 000 rows) → emails CSV as
 *   attachment → returns a small JSON response for the calling JS.
 *
 * PREREQUISITE (one-time admin task):
 *   Setup → Security → Remote Site Settings → New
 *   Name: SalesforceAPI   URL: https://<org-base>.my.salesforce.com
 */
public with sharing class ExportCsvController {

    public String pageContentType { get; private set; }
    public String output          { get; private set; }

    private static final Integer MAX_DOWNLOAD_ROWS = 2000;
    private static final Integer MAX_EMAIL_ROWS    = 10000;
    private static final String  API_VERSION       = 'v66.0';
    // Power Automate webhook URL stored in Custom Label for easy updates
    private static final String  PA_WEBHOOK_URL    = System.Label.ExportCsv_WebhookUrl;

    public ExportCsvController() {
        Map<String, String> p = ApexPages.currentPage().getParameters();
        String objectApiName = p.get('objectApiName');
        String filterName    = p.get('filterName');
        String scope         = p.get('scope');
        String action        = p.get('action');
        String emailTo       = p.get('to');
        Boolean wantsJson    = 'json'.equalsIgnoreCase(p.get('format'));
        Boolean isLaunch     = 'launch'.equalsIgnoreCase(action);
        Boolean isEmail      = 'email'.equalsIgnoreCase(action);
        Boolean isProbe      = 'probe'.equalsIgnoreCase(action);
        Boolean isJsonAction = isProbe || (isEmail && wantsJson);
        Boolean isCustomRegScope = 'fiuRegistrationBrowser'.equalsIgnoreCase(scope);
        Boolean isCustomEventScope = 'fiuEventBrowser'.equalsIgnoreCase(scope);
        Boolean isCustomInstanceScope = 'fiuInstanceBrowser'.equalsIgnoreCase(scope);

        pageContentType = isJsonAction ? 'application/json' : 'text/csv;charset=UTF-8;';

        if (isCustomRegScope) {
            handleFiuRegistrationBrowserExport(p, action, emailTo, wantsJson, isLaunch, isEmail, isProbe);
            return;
        }
        if (isCustomEventScope) {
            handleFiuEventBrowserExport(p, action, emailTo, wantsJson, isLaunch, isEmail, isProbe);
            return;
        }
        if (isCustomInstanceScope) {
            handleFiuInstanceBrowserExport(p, action, emailTo, wantsJson, isLaunch, isEmail, isProbe);
            return;
        }

        if (String.isBlank(objectApiName)) {
            handleError('Missing objectApiName parameter.', isJsonAction);
            return;
        }
        if (isRecentListViewToken(filterName)) {
            handleError(
                'Recently Viewed is session-based and cannot be exported. Open a saved list view and try again.',
                isJsonAction
            );
            return;
        }
        if (String.isBlank(filterName)) {
            filterName = resolveLatestViewedListViewId(objectApiName);
            if (String.isBlank(filterName)) {
                handleError('Unable to determine the current list view. Please open a saved list view and try again.', isJsonAction);
                return;
            }
        }

        if (isLaunch) {
            renderLaunchPage(objectApiName, filterName);
            return;
        }

        try {
            Map<String, Object> describe = callDescribe(objectApiName, filterName);
            String       label = (String)       describe.get('label');
            String       soql  = (String)       describe.get('query');
            List<Object> cols  = (List<Object>) describe.get('columns');

            List<String> fieldPaths = new List<String>();
            List<String> headers    = new List<String>();
            for (Object c : cols) {
                Map<String, Object> col = (Map<String, Object>) c;
                if (col.get('hidden') == true) continue;
                fieldPaths.add((String) col.get('fieldNameOrPath'));
                headers.add((String)    col.get('label'));
            }
            if (fieldPaths.isEmpty()) {
                handleError('No visible columns found in this list view.', isJsonAction);
                return;
            }

            if (isProbe) {
                doProbe(soql, label, objectApiName);
            } else if (isEmail) {
                doEmailExport(soql, headers, fieldPaths, label, objectApiName, filterName, emailTo, wantsJson);
            } else {
                doDownload(soql, headers, fieldPaths, label, objectApiName, filterName);
            }

        } catch (System.CalloutException e) {
            handleError('Callout failed — ensure the org base URL is in Remote Site Settings. ('
                + e.getMessage() + ')', isJsonAction);
        } catch (Exception e) {
            handleError(e.getMessage(), isJsonAction);
        }
    }

    private void handleFiuRegistrationBrowserExport(Map<String, String> p, String action, String emailTo, Boolean wantsJson, Boolean isLaunch, Boolean isEmail, Boolean isProbe) {
        String searchKey    = p.get('searchKey');
        String statusFilter = p.get('statusFilter');
        String programCode  = p.get('programCode');
        String locationTypeOverrideFilter = p.get('locationTypeOverrideFilter');
        String exportMode   = p.get('exportMode');
        String selectedIdsRaw = p.get('selectedIds');
        String sortField1 = p.get('sortField1');
        String sortDir1   = p.get('sortDir1');
        String sortField2 = p.get('sortField2');
        String sortDir2   = p.get('sortDir2');
        String instanceIdRaw = p.get('instanceId');
        Id instanceId = parseOptionalId(instanceIdRaw);

        if (isLaunch) {
            renderCustomScopeLaunchPage(p);
            return;
        }

        List<String> headers = new List<String>{ 'Registration', 'Contact', 'Email', 'Event', 'Instance', 'Instance Start', 'Instance End', 'Location Type Override', 'Status' };
        List<String> fieldPaths = new List<String>{
            'Name',
            'summit__Contact__r.Name',
            'summit__Registrant_Email__c',
            'summit__Event__r.Name',
            'summit__Event_Instance__r.Name',
            'summit__Event_Instance_Start_Date__c',
            'summit__Event_Instance_End_Date__c',
            'summit__Event_Instance__r.summit__Location_Type_Override__c',
            'summit__Status__c'
        };

        Set<Id> allowedRecordTypes = FiuEventsAccessService.getAllowedEventRecordTypeIds();
        if (allowedRecordTypes.isEmpty()) {
            handleError('You do not have access to any FIU Event record types.', isProbe || (isEmail && wantsJson));
            return;
        }
        String previewField = FiuEventsAccessService.resolveEventPreviewField();

        FiuProgramFilterService.ProgramFilterConfig programConfig = FiuProgramFilterService.getConfig();
        String soql = 'SELECT Id, Name, summit__Registrant_Email__c, summit__Status__c,' +
            ' summit__Contact__c, summit__Contact__r.Name, summit__Contact__r.Email,' +
            ' summit__Event__r.Name, summit__Event_Instance__r.Name,' +
            ' summit__Event_Instance_Start_Date__c, summit__Event_Instance_End_Date__c,' +
            ' summit__Event_Instance__r.summit__Location_Type_Override__c,' +
            ' summit__Event_Instance__r.summit__Event__r.RecordTypeId';
        for (String eventProgramField : programConfig.eventProgramFields) {
            soql += ', summit__Event_Instance__r.summit__Event__r.' + eventProgramField;
        }
        if (programConfig.hasDefaultPlanLookup) {
            soql += ', summit__Event_Instance__r.summit__Event__r.Default_Plan__r.Plan_Code__c';
        }
        soql += ' FROM summit__Summit_Events_Registration__c WHERE summit__Event_Instance__r.summit__Event__r.RecordTypeId IN (' + idSetToInClause(allowedRecordTypes) + ')';
        if (previewField != null) soql += ' AND (summit__Event_Instance__r.summit__Event__r.' + previewField + ' = false OR summit__Event_Instance__r.summit__Event__r.' + previewField + ' = null)';

        if (String.isNotBlank(searchKey)) {
            String likeSearch = '%' + String.escapeSingleQuotes(searchKey.trim()) + '%';
            soql += ' AND (Name LIKE \'' + likeSearch + '\' OR summit__Event__r.Name LIKE \'' + likeSearch + '\' OR summit__Event_Instance__r.Name LIKE \'' + likeSearch + '\')';
        }
        if (instanceId != null) {
            soql += ' AND summit__Event_Instance__c = \'' + String.escapeSingleQuotes(String.valueOf(instanceId)) + '\'';
        }
        if (statusFilter == 'Open') {
            soql += ' AND summit__Status__c NOT IN (\'Started\', \'Cancelled\')';
        } else if (statusFilter == 'Started') {
            soql += ' AND summit__Status__c = \'Started\'';
        } else if (statusFilter == 'Cancelled') {
            soql += ' AND summit__Status__c = \'Cancelled\'';
        }
        if (String.isNotBlank(locationTypeOverrideFilter)) {
            soql += ' AND summit__Event_Instance__r.summit__Location_Type_Override__c = \'' + String.escapeSingleQuotes(locationTypeOverrideFilter) + '\'';
        }
        if (exportMode == 'selected') {
            Set<Id> selectedIds = parseIdSet(selectedIdsRaw);
            if (selectedIds.isEmpty()) {
                handleError('No selected rows were provided for export.', isProbe || (isEmail && wantsJson));
                return;
            }
            soql += ' AND Id IN (' + idSetToInClause(selectedIds) + ')';
        }
        String programClause = FiuProgramFilterService.buildProgramWhereClause('summit__Event_Instance__r.summit__Event__r.', programCode, programConfig);
        if (programClause != null) soql += ' AND ' + programClause;
        soql += ' ORDER BY ' + buildRegistrationOrderBy(sortField1, sortDir1, sortField2, sortDir2);

        try {
            List<SObject> records = Database.query(withLimit(soql, (isEmail || isProbe) ? (MAX_EMAIL_ROWS + 1) : (MAX_DOWNLOAD_ROWS + 1)));
            for (SObject rec : records) {
                SObject contact = rec.getSObject('summit__Contact__r');
                String contactEmail = contact == null ? null : (String) contact.get('Email');
                if (!String.isBlank(contactEmail)) {
                    rec.put('summit__Registrant_Email__c', contactEmail);
                }
            }

            String label = 'FIU Registrations (Custom Scope)';
            if (isProbe) {
                Integer count = records.size() > MAX_DOWNLOAD_ROWS ? (MAX_DOWNLOAD_ROWS + 1) : records.size();
                jsonPayload(new Map<String, Object>{
                    'status' => 'ok',
                    'mode' => (records.size() > MAX_DOWNLOAD_ROWS ? 'email_prompt' : 'download'),
                    'count' => count,
                    'maxDownloadRows' => MAX_DOWNLOAD_ROWS,
                    'maxEmailRows' => MAX_EMAIL_ROWS,
                    'label' => label,
                    'listLabel' => label,
                    'defaultEmail' => UserInfo.getUserEmail()
                });
                return;
            }

            if (isEmail) {
                doEmailExport(soql, headers, fieldPaths, label, 'summit__Summit_Events_Registration__c', 'customScope', emailTo, wantsJson);
            } else {
                doDownload(soql, headers, fieldPaths, label, 'summit__Summit_Events_Registration__c', 'customScope');
            }
        } catch (Exception ex) {
            handleError(ex.getMessage(), isProbe || (isEmail && wantsJson));
        }
    }

    private Id parseOptionalId(String raw) {
        if (String.isBlank(raw)) return null;
        try {
            return (Id) raw;
        } catch (Exception ex) {
            return null;
        }
    }

    private void handleFiuEventBrowserExport(Map<String, String> p, String action, String emailTo, Boolean wantsJson, Boolean isLaunch, Boolean isEmail, Boolean isProbe) {
        String searchKey = p.get('searchKey');
        String statusFilter = p.get('statusFilter');
        String readinessFilter = p.get('readinessFilter');
        String programCode = p.get('programCode');
        String exportMode = p.get('exportMode');
        String selectedIdsRaw = p.get('selectedIds');
        String sortField1 = p.get('sortField1');
        String sortDir1 = p.get('sortDir1');
        String sortField2 = p.get('sortField2');
        String sortDir2 = p.get('sortDir2');

        if (isLaunch) {
            renderCustomScopeLaunchPage('fiuEventBrowser', p);
            return;
        }

        Set<Id> allowedRecordTypes = FiuEventsAccessService.getAllowedEventRecordTypeIds();
        if (allowedRecordTypes.isEmpty()) {
            handleError('You do not have access to any FIU Event record types.', isProbe || (isEmail && wantsJson));
            return;
        }

        FiuProgramFilterService.ProgramFilterConfig programConfig = FiuProgramFilterService.getConfig();
        String previewField = FiuEventsAccessService.resolveEventPreviewField();
        List<String> headers = new List<String>{ 'Event', 'Record Type', 'Status', 'Start Date', 'End Date' };
        List<String> fieldPaths = new List<String>{ 'Name', 'RecordType.Name', 'summit__Event_Status__c', 'summit__Start_Date__c', 'summit__End_Date__c' };

        String soql = 'SELECT Id, Name, RecordType.Name, summit__Event_Status__c, summit__Start_Date__c, summit__End_Date__c, RecordTypeId';
        for (String eventProgramField : programConfig.eventProgramFields) soql += ', ' + eventProgramField;
        if (programConfig.hasDefaultPlanLookup) soql += ', Default_Plan__r.Plan_Code__c';
        soql += ' FROM summit__Summit_Events__c WHERE RecordTypeId IN (' + idSetToInClause(allowedRecordTypes) + ')';
        if (previewField != null) soql += ' AND (' + previewField + ' = false OR ' + previewField + ' = null)';
        if (String.isNotBlank(searchKey)) soql += ' AND Name LIKE \'%' + String.escapeSingleQuotes(searchKey.trim()) + '%\'';
        if (String.isNotBlank(statusFilter)) soql += ' AND summit__Event_Status__c = \'' + String.escapeSingleQuotes(statusFilter) + '\'';
        String programClause = FiuProgramFilterService.buildProgramWhereClause('', programCode, programConfig);
        if (programClause != null) soql += ' AND ' + programClause;
        if (exportMode == 'selected') {
            Set<Id> selectedIds = parseIdSet(selectedIdsRaw);
            if (selectedIds.isEmpty()) {
                handleError('No selected rows were provided for export.', isProbe || (isEmail && wantsJson));
                return;
            }
            soql += ' AND Id IN (' + idSetToInClause(selectedIds) + ')';
        }
        soql += ' ORDER BY ' + buildEventOrderBy(sortField1, sortDir1, sortField2, sortDir2);

        String label = 'FIU Events (Custom Scope)';
        if (isProbe) {
            List<SObject> probe = Database.query(withLimit(soql, MAX_DOWNLOAD_ROWS + 1));
            Integer count = probe.size() > MAX_DOWNLOAD_ROWS ? (MAX_DOWNLOAD_ROWS + 1) : probe.size();
            jsonPayload(new Map<String, Object>{ 'status' => 'ok', 'mode' => (probe.size() > MAX_DOWNLOAD_ROWS ? 'email_prompt' : 'download'), 'count' => count, 'maxDownloadRows' => MAX_DOWNLOAD_ROWS, 'maxEmailRows' => MAX_EMAIL_ROWS, 'label' => label, 'listLabel' => label, 'defaultEmail' => UserInfo.getUserEmail() });
            return;
        }
        if (isEmail) doEmailExport(soql, headers, fieldPaths, label, 'summit__Summit_Events__c', 'customScope', emailTo, wantsJson);
        else doDownload(soql, headers, fieldPaths, label, 'summit__Summit_Events__c', 'customScope');
    }

    private void handleFiuInstanceBrowserExport(Map<String, String> p, String action, String emailTo, Boolean wantsJson, Boolean isLaunch, Boolean isEmail, Boolean isProbe) {
        String searchKey = p.get('searchKey');
        String bucketFilter = p.get('bucketFilter');
        String programCode = p.get('programCode');
        String exportMode = p.get('exportMode');
        String selectedIdsRaw = p.get('selectedIds');
        String sortField1 = p.get('sortField1');
        String sortDir1 = p.get('sortDir1');
        String sortField2 = p.get('sortField2');
        String sortDir2 = p.get('sortDir2');
        Id eventId = parseOptionalId(p.get('eventId'));

        if (isLaunch) {
            renderCustomScopeLaunchPage('fiuInstanceBrowser', p);
            return;
        }

        Set<Id> allowedRecordTypes = FiuEventsAccessService.getAllowedEventRecordTypeIds();
        if (allowedRecordTypes.isEmpty()) {
            handleError('You do not have access to any FIU Event record types.', isProbe || (isEmail && wantsJson));
            return;
        }

        FiuProgramFilterService.ProgramFilterConfig programConfig = FiuProgramFilterService.getConfig();
        String previewField = FiuEventsAccessService.resolveEventPreviewField();
        List<String> headers = new List<String>{ 'Instance', 'Event', 'Start Date', 'Status', 'Readiness', 'Reason (if Not Ready)' };
        List<String> fieldPaths = new List<String>{ 'Name', 'summit__Event__r.Name', 'summit__Start_Date__c', 'Status_Label__c', 'Readiness__c', 'Readiness_Reason__c' };

        String soql = 'SELECT Id, Name, summit__Event__r.Name, summit__Event__r.RecordTypeId, summit__Start_Date__c, Status_Label__c, Readiness__c, Readiness_Reason__c, summit__Status__c';
        for (String eventProgramField : programConfig.eventProgramFields) soql += ', summit__Event__r.' + eventProgramField;
        if (programConfig.hasDefaultPlanLookup) soql += ', summit__Event__r.Default_Plan__r.Plan_Code__c';
        soql += ' FROM summit__Summit_Events_Instance__c WHERE summit__Event__r.RecordTypeId IN (' + idSetToInClause(allowedRecordTypes) + ')';
        if (previewField != null) soql += ' AND (summit__Event__r.' + previewField + ' = false OR summit__Event__r.' + previewField + ' = null)';
        if (eventId != null) soql += ' AND summit__Event__c = \'' + String.escapeSingleQuotes(String.valueOf(eventId)) + '\'';
        if (String.isNotBlank(searchKey)) soql += ' AND Name LIKE \'%' + String.escapeSingleQuotes(searchKey.trim()) + '%\'';
        if (bucketFilter == 'Upcoming') soql += ' AND summit__Start_Date__c >= TODAY';
        else if (bucketFilter == 'Past') soql += ' AND summit__Start_Date__c < TODAY';
        else if (bucketFilter == 'Unpublished') soql += ' AND (Readiness__c = \'Not Ready\' OR summit__Status__c != \'Active\')';
        String programClause = FiuProgramFilterService.buildProgramWhereClause('summit__Event__r.', programCode, programConfig);
        if (programClause != null) soql += ' AND ' + programClause;
        if (exportMode == 'selected') {
            Set<Id> selectedIds = parseIdSet(selectedIdsRaw);
            if (selectedIds.isEmpty()) {
                handleError('No selected rows were provided for export.', isProbe || (isEmail && wantsJson));
                return;
            }
            soql += ' AND Id IN (' + idSetToInClause(selectedIds) + ')';
        }
        soql += ' ORDER BY ' + buildInstanceOrderBy(sortField1, sortDir1, sortField2, sortDir2);

        String label = 'FIU Instances (Custom Scope)';
        if (isProbe) {
            List<SObject> probe = Database.query(withLimit(soql, MAX_DOWNLOAD_ROWS + 1));
            Integer count = probe.size() > MAX_DOWNLOAD_ROWS ? (MAX_DOWNLOAD_ROWS + 1) : probe.size();
            jsonPayload(new Map<String, Object>{ 'status' => 'ok', 'mode' => (probe.size() > MAX_DOWNLOAD_ROWS ? 'email_prompt' : 'download'), 'count' => count, 'maxDownloadRows' => MAX_DOWNLOAD_ROWS, 'maxEmailRows' => MAX_EMAIL_ROWS, 'label' => label, 'listLabel' => label, 'defaultEmail' => UserInfo.getUserEmail() });
            return;
        }
        if (isEmail) doEmailExport(soql, headers, fieldPaths, label, 'summit__Summit_Events_Instance__c', 'customScope', emailTo, wantsJson);
        else doDownload(soql, headers, fieldPaths, label, 'summit__Summit_Events_Instance__c', 'customScope');
    }

    private Set<Id> parseIdSet(String csv) {
        Set<Id> out = new Set<Id>();
        if (String.isBlank(csv)) return out;
        for (String token : csv.split(',')) {
            String trimmed = token == null ? null : token.trim();
            if (String.isBlank(trimmed)) continue;
            try {
                out.add((Id) trimmed);
            } catch (Exception ex) {
                // skip invalid ids
            }
        }
        return out;
    }

    private String buildRegistrationOrderBy(String sortField1, String sortDir1, String sortField2, String sortDir2) {
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

    private void addSortPart(List<String> orderParts, Map<String, String> sortMap, String sortField, String sortDir) {
        if (String.isBlank(sortField) || !sortMap.containsKey(sortField)) return;
        String dir = String.valueOf(sortDir).toUpperCase() == 'ASC' ? 'ASC' : 'DESC';
        String part = sortMap.get(sortField) + ' ' + dir + ' NULLS LAST';
        if (!orderParts.contains(part)) orderParts.add(part);
    }

    private String buildEventOrderBy(String sortField1, String sortDir1, String sortField2, String sortDir2) {
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
        if (orderParts.isEmpty()) return 'summit__Start_Date__c DESC NULLS LAST, Name ASC, CreatedDate DESC';
        orderParts.add('CreatedDate DESC');
        return String.join(orderParts, ', ');
    }

    private String buildInstanceOrderBy(String sortField1, String sortDir1, String sortField2, String sortDir2) {
        Map<String, String> sortMap = new Map<String, String>{
            'title' => 'summit__Instance_Title__c',
            'eventName' => 'summit__Event__r.Name',
            'startDate' => 'summit__Start_Date__c',
            'activeStatus' => 'summit__Active_Status__c',
            'createdDate' => 'CreatedDate'
        };
        List<String> orderParts = new List<String>();
        addSortPart(orderParts, sortMap, sortField1, sortDir1);
        addSortPart(orderParts, sortMap, sortField2, sortDir2);
        if (orderParts.isEmpty()) return 'summit__Start_Date__c ASC NULLS LAST, summit__Instance_Title__c ASC, CreatedDate DESC';
        orderParts.add('CreatedDate DESC');
        return String.join(orderParts, ', ');
    }

    private void renderCustomScopeLaunchPage(Map<String, String> p) {
        renderCustomScopeLaunchPage('fiuRegistrationBrowser', p);
    }

    private void renderCustomScopeLaunchPage(String scope, Map<String, String> p) {
        pageContentType = 'text/html';
        String searchKey = safeUrlEncode(p.get('searchKey'));
        String statusFilter = safeUrlEncode(p.get('statusFilter'));
        String programCode = safeUrlEncode(p.get('programCode'));
        String instanceId = safeUrlEncode(p.get('instanceId'));
        String exportMode = safeUrlEncode(p.get('exportMode'));
        String selectedIds = safeUrlEncode(p.get('selectedIds'));
        String sortField1 = safeUrlEncode(p.get('sortField1'));
        String sortDir1 = safeUrlEncode(p.get('sortDir1'));
        String sortField2 = safeUrlEncode(p.get('sortField2'));
        String sortDir2 = safeUrlEncode(p.get('sortDir2'));
        String locationTypeOverrideFilter = safeUrlEncode(p.get('locationTypeOverrideFilter'));
        String readinessFilter = safeUrlEncode(p.get('readinessFilter'));
        String bucketFilter = safeUrlEncode(p.get('bucketFilter'));
        String eventId = safeUrlEncode(p.get('eventId'));
        output = '<!DOCTYPE html><html><head><meta charset="UTF-8"/><title>Export Custom Scope</title></head><body>'
            + '<script>'
            + 'var base="/apex/ExportCsv?scope=' + safeUrlEncode(scope) + '";'
            + 'base += "&searchKey=' + searchKey + '";'
            + 'base += "&statusFilter=' + statusFilter + '";'
            + 'base += "&readinessFilter=' + readinessFilter + '";'
            + 'base += "&programCode=' + programCode + '";'
            + 'base += "&bucketFilter=' + bucketFilter + '";'
            + 'base += "&instanceId=' + instanceId + '";'
            + 'base += "&eventId=' + eventId + '";'
            + 'base += "&exportMode=' + exportMode + '";'
            + 'base += "&selectedIds=' + selectedIds + '";'
            + 'base += "&sortField1=' + sortField1 + '";'
            + 'base += "&sortDir1=' + sortDir1 + '";'
            + 'base += "&sortField2=' + sortField2 + '";'
            + 'base += "&sortDir2=' + sortDir2 + '";'
            + 'base += "&locationTypeOverrideFilter=' + locationTypeOverrideFilter + '";'
            + 'window.location.href = base;'
            + '</script></body></html>';
    }

    private String safeUrlEncode(String input) {
        return EncodingUtil.urlEncode(input == null ? '' : input, 'UTF-8');
    }

    private String idSetToInClause(Set<Id> ids) {
        if (ids == null || ids.isEmpty()) return '\'000000000000000AAA\'';
        List<String> out = new List<String>();
        for (Id i : ids) out.add('\'' + String.escapeSingleQuotes(String.valueOf(i)) + '\'');
        return String.join(out, ',');
    }

    // ── Download ──────────────────────────────────────────────────────────────

    private void doDownload(String soql, List<String> headers, List<String> fieldPaths,
                            String label, String objectApiName, String filterName) {

        List<SObject> records = Database.query(withLimit(soql, MAX_DOWNLOAD_ROWS + 1));

        if (records.size() > MAX_DOWNLOAD_ROWS) {
            renderEmailPrompt(objectApiName, filterName, label);
            return;
        }

        String listLabel = resolveListLabel(label, objectApiName, filterName);
        String filename = buildFilename(listLabel);
        ApexPages.currentPage().getHeaders().put(
            'Content-Disposition', 'attachment; filename="' + filename + '"');
        ApexPages.currentPage().getHeaders().put('Cache-Control', 'no-cache, no-store');
        output = buildCsv(headers, fieldPaths, records);
    }

    // ── Email export ──────────────────────────────────────────────────────────

    private void doEmailExport(String soql, List<String> headers, List<String> fieldPaths,
                               String label, String objectApiName, String filterName,
                               String emailTo, Boolean asJson) {

        if (String.isBlank(emailTo)) {
            if (asJson) {
                jsonError('Missing email address.');
            } else {
                renderEmailPrompt(objectApiName, filterName, label);
            }
            return;
        }

        if (!emailTo.toLowerCase().endsWith('@fiu.edu')) {
            handleError('Email address must be an @fiu.edu address.', asJson);
            return;
        }
        if (!emailTo.equalsIgnoreCase(UserInfo.getUserEmail())) {
            handleError('Export can only be emailed to your own address.', asJson);
            return;
        }

        List<SObject> records = Database.query(withLimit(soql, MAX_EMAIL_ROWS + 1));

        if (records.size() > MAX_EMAIL_ROWS) {
            handleError('This list has more than ' + MAX_EMAIL_ROWS.format()
                + ' records \u2014 too large even for email. Please apply additional filters.', asJson);
            return;
        }

        String listLabel  = resolveListLabel(label, objectApiName, filterName);
        String filename   = buildFilename(listLabel);
        String csvContent = buildCsv(headers, fieldPaths, records);
        Integer cnt       = records.size();

        // POST to Power Automate webhook to send email via M365
        Map<String, Object> payload = new Map<String, Object>{
            'to'        => emailTo,
            'subject'   => (isSandbox() ? '[SANDBOX] ' : '') + 'List View Export: ' + listLabel,
            'body'      => '<p>' + cnt.format() + ' record' + (cnt == 1 ? '' : 's')
                           + ' exported from the &ldquo;' + listLabel.escapeHtml4() + '&rdquo; list view.<br/>'
                           + 'The CSV file is attached.</p>'
                           + '<hr/>'
                           + '<p style="font-size:small;color:#666;">'
                           + '<strong>Export Details</strong><br/>'
                           + 'Requested by: ' + UserInfo.getName().escapeHtml4() + ' (' + UserInfo.getUserEmail().escapeHtml4() + ')<br/>'
                           + 'Object: ' + objectApiName.escapeHtml4() + '<br/>'
                           + 'List View: ' + listLabel.escapeHtml4() + '<br/>'
                           + 'Records: ' + cnt.format() + '<br/>'
                           + 'Environment: ' + getEnvironmentLabel() + ' (' + UserInfo.getOrganizationId() + ')<br/>'
                           + 'Timestamp: ' + Datetime.now().format('yyyy-MM-dd HH:mm:ss z')
                           + '</p>',
            'fileName'  => filename,
            'csvBase64' => EncodingUtil.base64Encode(Blob.valueOf(csvContent))
        };

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(PA_WEBHOOK_URL);
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(30000);
        req.setBody(JSON.serialize(payload));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            handleError('Email webhook failed (HTTP ' + res.getStatusCode() + '): '
                + res.getBody(), asJson);
            return;
        }

        if (asJson) {
            jsonPayload(new Map<String, Object>{
                'status' => 'ok',
                'count' => cnt
            });
        } else {
            renderEmailSuccess(emailTo, cnt, listLabel);
        }
    }

    // ── Probe (JSON only) ─────────────────────────────────────────────────────

    private void doProbe(String soql, String label, String objectApiName) {
        List<SObject> records = Database.query(withLimit(soql, MAX_DOWNLOAD_ROWS + 1));
        Integer count = records.size() > MAX_DOWNLOAD_ROWS ? (MAX_DOWNLOAD_ROWS + 1) : records.size();

        Map<String, Object> payload = new Map<String, Object>{
            'status' => 'ok',
            'mode' => (records.size() > MAX_DOWNLOAD_ROWS ? 'email_prompt' : 'download'),
            'count' => count,
            'maxDownloadRows' => MAX_DOWNLOAD_ROWS,
            'maxEmailRows' => MAX_EMAIL_ROWS,
            'label' => String.isNotBlank(label) ? label : objectApiName,
            'listLabel' => String.isNotBlank(label) ? label : objectApiName,
            'defaultEmail' => UserInfo.getUserEmail()
        };
        jsonPayload(payload);
    }

    private void renderLaunchPage(String objectApiName, String filterName) {
        pageContentType = 'text/html';
        String jsObj    = EncodingUtil.urlEncode(objectApiName, 'UTF-8');
        String jsFilter = EncodingUtil.urlEncode(filterName, 'UTF-8');
        output = '<!DOCTYPE html><html><head><meta charset="UTF-8"/>'
            + '<title>Export List View</title>'
            + '<style>'
            + 'body{font-family:"Salesforce Sans",Arial,sans-serif;padding:1.5rem;max-width:560px;'
            + 'margin:1rem auto;color:#16325c}'
            + '.card{border:1px solid #dddbda;border-radius:.25rem;padding:1rem 1.25rem}'
            + '.spinner{width:2rem;height:2rem;border:.2rem solid #d8dde6;border-top-color:#0176d3;'
            + 'border-radius:50%;animation:spin 1s linear infinite;margin:0 auto .75rem}'
            + '.center{text-align:center}'
            + '.ok{background:#2e844a;border-radius:50%;width:3rem;height:3rem;display:inline-flex;'
            + 'align-items:center;justify-content:center;margin-bottom:.75rem;color:#fff;font-size:1.25rem}'
            + '.btn{padding:.45rem 1.1rem;border-radius:.25rem;font-size:.875rem;cursor:pointer;'
            + 'border:1px solid #dddbda;background:#fff;color:#16325c;margin-top:.75rem}'
            + '.err{background:#fce3e3;border-left:4px solid #c23934;padding:.75rem 1rem;border-radius:.25rem;'
            + 'font-size:.875rem;color:#c23934}'
            + '@keyframes spin{to{transform:rotate(360deg)}}'
            + '</style></head><body>'
            + '<div class="card">'
            + '<div id="state-loading" class="center">'
            + '<div class="spinner"></div>'
            + '<p id="msg">Preparing export...</p>'
            + '</div>'
            + '<div id="state-success" class="center" style="display:none;">'
            + '<div class="ok">&#10003;</div>'
            + '<h2 style="margin:.2rem 0 .5rem;">Download started</h2>'
            + '<p id="summary" style="color:#54698d;"></p>'
            + '<button id="btnBack" class="btn">Back to List View</button>'
            + '</div>'
            + '<div id="state-error" style="display:none;">'
            + '<div class="err" id="err"></div>'
            + '<button id="btnBackErr" class="btn">Back</button>'
            + '</div>'
            + '</div>'
            + '<iframe id="dl" style="display:none;"></iframe>'
            + '<script>'
            + 'function q(s){return document.getElementById(s);} '
            + 'function show(n){q("state-loading").style.display=(n==="loading")?"":"none";'
            + 'q("state-success").style.display=(n==="success")?"":"none";'
            + 'q("state-error").style.display=(n==="error")?"":"none";}'
            + 'function back(){history.back();}'
            + 'q("btnBack").addEventListener("click",back);'
            + 'q("btnBackErr").addEventListener("click",back);'
            + 'var obj="' + jsObj + '"; var fn="' + jsFilter + '";'
            + 'function expUrl(action){return "/apex/ExportCsv?action="+encodeURIComponent(action)'
            + '+ "&objectApiName="+obj+"&filterName="+fn;}'
            + 'fetch(expUrl("probe"),{headers:{Accept:"application/json"}})'
            + '.then(function(r){return r.json();})'
            + '.then(function(b){'
            + 'if(b.status==="error"){throw new Error(b.message||"Export failed.");}'
            + 'if(b.mode==="email_prompt"){window.location.href="/apex/ExportCsv?objectApiName="+obj+"&filterName="+fn;return;}'
            + 'q("dl").src="/apex/ExportCsv?objectApiName="+obj+"&filterName="+fn;'
            + 'q("summary").textContent=(b.count||0)+" record(s) exported from "+(b.label||"this list view")+"." ;'
            + 'show("success");'
            + '})'
            + '.catch(function(e){q("err").textContent=e.message||"Export failed.";show("error");});'
            + '</script></body></html>';
    }

    private String resolveLatestViewedListViewId(String objectApiName) {
        try {
            List<ListView> lvs = [
                SELECT Id
                FROM ListView
                WHERE SobjectType = :objectApiName
                ORDER BY LastViewedDate DESC NULLS LAST
                LIMIT 1
            ];
            return lvs.isEmpty() ? null : lvs[0].Id;
        } catch (Exception e) {
            return null;
        }
    }

    private Boolean isRecentListViewToken(String filterName) {
        if (String.isBlank(filterName)) return false;
        String f = filterName.trim().toLowerCase();
        return f == '__recent' || f == 'recent';
    }

    private void renderRecentViewUnsupported() {
        pageContentType = 'text/html';
        output = '<!DOCTYPE html><html><head><meta charset="UTF-8"/>'
            + '<title>Recently Viewed Not Supported</title>'
            + '<style>'
            + 'body{font-family:"Salesforce Sans",Arial,sans-serif;padding:1.5rem;max-width:560px;'
            + 'margin:1rem auto;color:#16325c}'
            + '.card{border:1px solid #dddbda;border-radius:.25rem;padding:1rem 1.25rem}'
            + '.banner{padding:.75rem 1rem;border-radius:.25rem;background:#fff7e6;'
            + 'border-left:4px solid #ffb75d;color:#8a6d3b;line-height:1.5}'
            + '.btn{padding:.45rem 1.1rem;border-radius:.25rem;font-size:.875rem;cursor:pointer;'
            + 'border:1px solid #dddbda;background:#fff;color:#16325c;margin-top:1rem}'
            + '</style></head><body>'
            + '<div class="card">'
            + '<h2 style="margin:.2rem 0 .75rem;">Cannot export Recently Viewed</h2>'
            + '<div class="banner">Recently Viewed is session-based and not a saved list view. '
            + 'To avoid exporting the wrong records, this action is blocked.</div>'
            + '<p style="color:#54698d;margin-top:.9rem;">Open a saved list view, then click Export again.</p>'
            + '<button id="btnBack" class="btn">Back to List View</button>'
            + '</div>'
            + '<script>document.getElementById("btnBack").addEventListener("click",function(){history.back();});</script>'
            + '</body></html>';
    }

    private String resolveListLabel(String labelFromDescribe, String objectApiName, String filterName) {
        if (String.isNotBlank(labelFromDescribe)) return labelFromDescribe;
        try {
            List<ListView> lvs = [
                SELECT Name
                FROM ListView
                WHERE Id = :filterName
                LIMIT 1
            ];
            if (!lvs.isEmpty() && String.isNotBlank(lvs[0].Name)) {
                return lvs[0].Name;
            }
        } catch (Exception e) {
            // Fall through to the safest default.
        }
        return objectApiName;
    }

    private void renderEmailPrompt(String objectApiName, String filterName, String label) {
        pageContentType = 'text/html';
        String safeLabel = (String.isNotBlank(label) ? label : objectApiName).escapeHtml4();
        String jsObj     = EncodingUtil.urlEncode(objectApiName, 'UTF-8');
        String jsFilter  = EncodingUtil.urlEncode(filterName, 'UTF-8');
        String userEmail = UserInfo.getUserEmail().escapeHtml4();

        output = '<!DOCTYPE html><html><head><meta charset="UTF-8"/>'
            + '<title>Export - Large List</title>'
            + '<style>'
            + 'body{font-family:"Salesforce Sans",Arial,sans-serif;padding:1.5rem;max-width:520px;'
            + 'margin:1rem auto;color:#16325c}'
            + 'label{display:block;font-size:.75rem;font-weight:700;color:#54698d;'
            + 'margin:.75rem 0 .3rem;text-transform:uppercase;letter-spacing:.04em}'
            + 'input[type=email]{width:100%;padding:.5rem .75rem;border:1px solid #dddbda;'
            + 'border-radius:.25rem;font-size:.875rem;box-sizing:border-box;margin-bottom:1rem}'
            + '.btn{padding:.45rem 1.1rem;border-radius:.25rem;font-size:.875rem;cursor:pointer;'
            + 'border:1px solid #dddbda;background:#fff;color:#16325c;margin-top:.25rem}'
            + '.btn.brand{background:#0070d2;border-color:#0070d2;color:#fff;margin-right:.5rem}'
            + '.banner{padding:.75rem 1rem;border-radius:.25rem;font-size:.875rem;margin-bottom:1.25rem;line-height:1.5;'
            + 'background:#e8f4fd;border-left:4px solid #0070d2}'
            + '</style></head><body>'
            + '<div class="banner">This list has more than ' + MAX_DOWNLOAD_ROWS.format()
            + ' records and is too large to download directly.<br/>'
            + 'Enter an email address and we will send a CSV (up to '
            + MAX_EMAIL_ROWS.format() + ' records).</div>'
            + '<p style="font-size:.75rem;color:#999;margin:0 0 .75rem;">' + safeLabel + '</p>'
            + '<label for="emailTo">Send to</label>'
            + '<input type="email" id="emailTo" value="' + userEmail + '"/>'
            + '<button class="btn brand" id="btnSend">Send CSV</button>'
            + '<button class="btn" id="btnCancel">Cancel</button>'
            + '<script>'
            + 'document.getElementById("btnSend").addEventListener("click",function(){'
            +   'var to=document.getElementById("emailTo").value.trim();'
            +   'if(!to){alert("Please enter an email address.");return;}'
            +   'window.location.href="/apex/ExportCsv?action=email'
            +   '&objectApiName=' + jsObj
            +   '&filterName=' + jsFilter
            +   '&to="+encodeURIComponent(to);'
            + '});'
            + 'document.getElementById("btnCancel").addEventListener("click",function(){history.back();});'
            + '</script></body></html>';
    }

    private void renderEmailSuccess(String emailTo, Integer cnt, String label) {
        pageContentType = 'text/html';
        output = '<!DOCTYPE html><html><head><meta charset="UTF-8"/>'
            + '<title>Email Sent</title>'
            + '<style>'
            + 'body{font-family:"Salesforce Sans",Arial,sans-serif;padding:1.5rem;max-width:520px;'
            + 'margin:1rem auto;color:#16325c;text-align:center}'
            + '.ok{background:#2e844a;border-radius:50%;width:3rem;height:3rem;display:inline-flex;'
            + 'align-items:center;justify-content:center;margin-bottom:1rem;color:#fff;font-size:1.25rem}'
            + '.btn{padding:.45rem 1.1rem;border-radius:.25rem;font-size:.875rem;cursor:pointer;'
            + 'border:1px solid #dddbda;background:#fff;color:#16325c;margin-top:.75rem}'
            + '</style></head><body>'
            + '<div class="ok">&#10003;</div>'
            + '<h2 style="margin:.2rem 0 1rem;">Email sent</h2>'
            + '<p style="color:#54698d;">' + cnt.format() + ' record' + (cnt == 1 ? '' : 's')
            + ' from <strong>' + label.escapeHtml4() + '</strong> sent to '
            + '<strong>' + emailTo.escapeHtml4() + '</strong>.</p>'
            + '<button class="btn" id="btnBack">Back</button>'
            + '<script>document.getElementById("btnBack").addEventListener("click",function(){history.back();});</script>'
            + '</body></html>';
    }

    // ── HTTP callout ──────────────────────────────────────────────────────────

    private Map<String, Object> callDescribe(String objectApiName, String filterName) {
        String endpoint = getApiBaseUrl()
            + '/services/data/' + API_VERSION
            + '/sobjects/' + EncodingUtil.urlEncode(objectApiName, 'UTF-8')
            + '/listviews/' + EncodingUtil.urlEncode(filterName,    'UTF-8')
            + '/describe';

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(endpoint);
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Accept', 'application/json');
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new System.CalloutException(extractApiError(res));
        }
        return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    }

    private String getApiBaseUrl() {
        return Url.getOrgDomainUrl().toExternalForm();
    }

    private static Boolean isSandbox() {
        return [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
    }

    private static String getEnvironmentLabel() {
        if (!isSandbox()) return 'Production';
        // Extract sandbox name from domain: fiucrm--uat.sandbox.my.salesforce.com → uat
        String host = Url.getOrgDomainUrl().getHost(); // e.g. fiucrm--uat.sandbox.my.salesforce.com
        if (host.contains('--')) {
            String name = host.substringAfter('--').substringBefore('.');
            return 'Sandbox (' + name.toUpperCase() + ')';
        }
        return 'Sandbox';
    }

    // ── Response helpers ──────────────────────────────────────────────────────

    private void handleError(String msg, Boolean asJson) {
        if (asJson) { jsonError(msg); } else { renderError(msg); }
    }

    private void jsonOk(Integer cnt) {
        jsonPayload(new Map<String, Object>{ 'status' => 'ok', 'count' => cnt });
    }

    private void jsonError(String msg) {
        jsonPayload(new Map<String, Object>{ 'status' => 'error', 'message' => msg });
    }

    private void jsonPayload(Map<String, Object> payload) {
        pageContentType = 'application/json';
        output = JSON.serialize(payload);
    }

    private void renderError(String msg) {
        pageContentType = 'text/html';
        output = '<!DOCTYPE html><html><head><meta charset="UTF-8"/>'
            + '<title>Export Error</title>'
            + '<style>'
            + 'body{font-family:"Salesforce Sans",Arial,sans-serif;padding:1.5rem;'
            +      'max-width:520px;margin:1rem auto;color:#16325c}'
            + '.err{background:#fce3e3;border-left:4px solid #c23934;padding:.75rem 1rem;'
            +      'border-radius:.25rem;font-size:.875rem;color:#c23934;margin-bottom:1rem}'
            + 'button{padding:.45rem 1.1rem;border-radius:.25rem;font-size:.875rem;'
            +        'cursor:pointer;border:1px solid #dddbda;background:#fff;color:#16325c}'
            + '</style></head><body>'
            + '<div class="err"><strong>Export failed:</strong> ' + msg.escapeHtml4() + '</div>'
            + '<button id="b">Close Window</button>'
            + '<script>document.getElementById("b").addEventListener("click",function(){'
            + 'try{window.close();}catch(e){}window.history.back();});</script>'
            + '</body></html>';
    }

    // ── CSV helpers ───────────────────────────────────────────────────────────

    private String withLimit(String soql, Integer lim) {
        return soql.toLowerCase().contains(' limit ')
            ? soql
            : soql + ' LIMIT ' + lim;
    }

    private String buildFilename(String label) {
        String safe = label.replaceAll('[^a-zA-Z0-9 _\\-]', '')
                           .trim()
                           .replaceAll('\\s+', '_')
                           .replaceAll('_+', '_');
        if (safe.length() > 20) safe = safe.substring(0, 20);
        if (safe.endsWith('_')) safe = safe.substring(0, safe.length() - 1);
        String suffix = EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 6);
        return safe + '_' + suffix + '.csv';
    }

    private String buildCsv(List<String> headers, List<String> fieldPaths, List<SObject> records) {
        List<String> rows = new List<String>();
        rows.add(escRow(headers));
        for (SObject rec : records) {
            List<String> vals = new List<String>();
            for (String path : fieldPaths) {
                vals.add(getVal(rec, path));
            }
            rows.add(escRow(vals));
        }
        return '\uFEFF' + String.join(rows, '\r\n');   // BOM keeps Excel happy
    }

    private String getVal(SObject rec, String path) {
        try {
            List<String> parts = path.split('\\.', 2);
            if (parts.size() == 1) {
                Object v = rec.get(path);
                return v == null ? '' : String.valueOf(v);
            }
            SObject rel = rec.getSObject(parts[0]);
            if (rel == null) return '';
            Object v = rel.get(parts[1]);
            return v == null ? '' : String.valueOf(v);
        } catch (Exception e) {
            return '';
        }
    }

    private String escRow(List<String> vals) {
        List<String> out = new List<String>();
        for (String v : vals) {
            out.add('"' + v.replace('"', '""') + '"');
        }
        return String.join(out, ',');
    }

    private String extractApiError(HttpResponse res) {
        try {
            List<Object> errs = (List<Object>) JSON.deserializeUntyped(res.getBody());
            Map<String, Object> first = (Map<String, Object>) errs[0];
            String msg = (String) first.get('message');
            return String.isNotBlank(msg) ? msg : res.getStatus();
        } catch (Exception e) {
            return res.getStatus();
        }
    }
}
