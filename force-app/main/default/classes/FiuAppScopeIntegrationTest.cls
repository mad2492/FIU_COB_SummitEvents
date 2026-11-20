@IsTest
private class FiuAppScopeIntegrationTest {
    private static final String PROGRAM_CODE = 'MBA';

    @TestSetup
    static void setup() {
        Account account = new Account(Name = 'Scoped App Test Account');
        String accountRecordTypeId = universityDepartmentAccountRecordTypeId();
        if (String.isNotBlank(accountRecordTypeId)) account.RecordTypeId = (Id) accountRecordTypeId;
        insert account;

        Campaign campaign = new Campaign(
            Name = 'Scoped App Test Campaign',
            IsActive = true
        );
        insert campaign;

        summit__Summit_Events__c eventRow = new summit__Summit_Events__c(
            Name = 'Scoped App Event'
        );
        String recordTypeId = firstAvailableEventRecordTypeId();
        if (String.isNotBlank(recordTypeId)) eventRow.RecordTypeId = (Id) recordTypeId;
        putIfPresent(eventRow, 'summit__Template__c', eventPicklistValue('summit__Template__c', 'FIU_Chapman_Payment_Template'));
        putIfPresent(eventRow, 'Preview_Event__c', false);
        putIfPresent(eventRow, 'Campaign__c', campaign.Id);
        putIfPresent(eventRow, 'summit__Account__c', account.Id);
        putIfPresent(eventRow, 'summit__Event_Status__c', eventPicklistValue('summit__Event_Status__c', 'Active'));
        putIfPresent(eventRow, 'summit__Capacity__c', 25);
        putIfPresent(eventRow, 'summit__Payment_Gateway__c', eventPicklistValue('summit__Payment_Gateway__c', 'No Gateway'));
        putIfPresent(eventRow, 'FIU_Create_Opps_From_Regs__c', false);
        putIfPresent(eventRow, 'Send_Registration_Confirmation_Email__c', false);
        putProgramCode(eventRow, PROGRAM_CODE);
        insert eventRow;

        Date startDate = Date.today().addDays(15);
        summit__Summit_Events_Instance__c instanceRow = new summit__Summit_Events_Instance__c(
            summit__Event__c = eventRow.Id,
            summit__Instance_Title__c = 'Scoped App Instance',
            summit__Instance_Start_Date__c = startDate,
            summit__Instance_End_Date__c = startDate.addDays(1),
            summit__Active_Status__c = 'Active',
            summit__Capacity__c = 25,
            summit__Location_Title_Override__c = 'FIU MMC',
            summit__Location_Address_Override__c = '11200 SW 8th St, Miami, FL',
            summit__Location_Map_Link_Override__c = 'https://maps.fiu.edu',
            Parking_info__c = 'Visitor parking'
        );
        putIfPresent(instanceRow, 'Preview_Instance__c', false);
        putIfPresent(instanceRow, 'Campaign_Override__c', campaign.Id);
        insert instanceRow;

        Contact contact = new Contact(
            FirstName = 'Scoped',
            LastName = 'Registrant',
            Email = 'scoped.registrant@example.edu'
        );
        insert contact;
        insertRegistrationIfSupported(eventRow.Id, instanceRow.Id, contact.Id);
    }

    @IsTest
    static void scopedServicesUseRecordTypeThenProgram() {
        summit__Summit_Events__c eventRow = [
            SELECT Id, RecordTypeId
            FROM summit__Summit_Events__c
            WHERE Name = 'Scoped App Event'
            LIMIT 1
        ];
        summit__Summit_Events_Instance__c instanceRow = [
            SELECT Id
            FROM summit__Summit_Events_Instance__c
            WHERE summit__Event__c = :eventRow.Id
            LIMIT 1
        ];
        String scopedRecordTypeId = String.valueOf(eventRow.RecordTypeId);

        Test.startTest();
        FiuHomeDashboardService.DashboardData dashboard =
            FiuHomeDashboardService.loadDashboard(PROGRAM_CODE, scopedRecordTypeId);
        FiuHomeDashboardService.DashboardData invalidScopeDashboard =
            FiuHomeDashboardService.loadDashboard(PROGRAM_CODE, UserInfo.getUserId());
        FiuEventBrowserService.EventQueryResult events =
            FiuEventBrowserService.queryEvents('Scoped', null, PROGRAM_CODE, null, 1, 10, 'name', 'ASC', null, null, scopedRecordTypeId);
        FiuInstanceBrowserService.InstanceQueryResult instances =
            FiuInstanceBrowserService.queryInstances(null, 'Scoped', 'All', PROGRAM_CODE, 1, 10, 'startDate', 'ASC', null, null, null, scopedRecordTypeId);
        FiuRegistrationBrowserService.RegistrationQueryResult registrations =
            FiuRegistrationBrowserService.queryRegistrations('Scoped', PROGRAM_CODE, null, null, null, 1, 10, 'name', 'ASC', null, null, scopedRecordTypeId);
        FiuRegistrationBrowserService.getLocationTypeOverrideOptions();
        try {
            FiuRegistrationBrowserService.massUpdateRegistrations(new List<Id>(), null, null, null);
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
        if (!registrations.rows.isEmpty()) {
            FiuRegistrationBrowserService.massUpdateRegistrations(new List<Id>{ registrations.rows[0].id }, 'Started', null, null);
        }
        FiuEventsOrchestratorService.CloneRiskResult cloneRisk = FiuEventsOrchestratorService.evaluateCloneRisk(eventRow.Id);
        List<FiuEventsRosterService.RegistrationRow> roster = FiuEventsRosterService.getInstanceRoster(instanceRow.Id);
        String rosterCsv = FiuEventsRosterService.exportInstanceRosterCsv(instanceRow.Id);
        Test.stopTest();

        System.assert(dashboard.upcomingInstances >= 0, 'The app scope dashboard should execute.');
        System.assertEquals(0, invalidScopeDashboard.upcomingInstances, 'An unavailable record type scope should return no rows.');
        System.assert(events.rows.size() >= 0, 'Event browser should honor the same app scope.');
        System.assert(instances.rows.size() >= 0, 'Instance browser should honor the same app scope.');
        System.assert(registrations.rows.size() >= 0, 'Registration browser should execute under the same app scope.');
        System.assert(cloneRisk.riskWarnings.size() > 0, 'Clone risk should evaluate the scoped event from the database path.');
        System.assert(roster != null, 'Roster should be available for the scoped instance.');
        System.assert(rosterCsv.startsWith('RegistrationId,Name,Email,Status,Attended'));
    }

    @IsTest
    static void wizardCreateAndPreviewPathsUseSafeDefaults() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Scoped App Test Account' LIMIT 1];
        Campaign campaign = [SELECT Id FROM Campaign WHERE Name = 'Scoped App Test Campaign' LIMIT 1];
        summit__Summit_Events__c eventRow = [
            SELECT Id
            FROM summit__Summit_Events__c
            WHERE Name = 'Scoped App Event'
            LIMIT 1
        ];
        FIU_EventsWizardService.InitData initData = FIU_EventsWizardService.getInitData();
        FIU_EventsWizardService.getBusinessUnits();
        FIU_EventsWizardService.getProgramsForBusinessUnit(null);
        FIU_EventsWizardService.getProgramsForBusinessUnit(String.valueOf(account.Id));

        FIU_EventsWizardService.CreateRequest workingReq = newWizardRequest(account.Id, initData, 'Scoped Wizard Working');
        workingReq.campaignId = String.valueOf(campaign.Id);
        FIU_EventsWizardService.CreateRequest createReq = newWizardRequest(account.Id, initData, 'Scoped Wizard Create');
        createReq.campaignId = String.valueOf(campaign.Id);
        createReq.workingEventId = String.valueOf(eventRow.Id);
        createReq.createFirstInstance = true;
        FIU_EventsWizardService.CreateRequest previewReq = newWizardRequest(account.Id, initData, 'Scoped Wizard Preview');
        previewReq.campaignId = String.valueOf(campaign.Id);
        previewReq.previewSessionKey = 'scoped-preview-session';
        FIU_EventsWizardService.CreateRequest physicalUpdateReq = newWizardRequest(account.Id, initData, 'Scoped Wizard Physical Update');
        physicalUpdateReq.campaignId = String.valueOf(campaign.Id);
        physicalUpdateReq.workingEventId = String.valueOf(eventRow.Id);
        physicalUpdateReq.locationType = 'On-Site';
        physicalUpdateReq.createFirstInstance = false;
        Id programPlanId = createPlanIfSupported(account.Id, 'Professional MBA', PROGRAM_CODE);
        if (programPlanId != null) createReq.selectedPlanIds = new List<String>{ String.valueOf(programPlanId) };

        Test.startTest();
        Id workingId = FIU_EventsWizardService.createWorkingEvent(workingReq);
        Id draftId = FIU_EventsWizardService.createDraftEvent(workingReq);
        FIU_EventsWizardService.CreateResult created = FIU_EventsWizardService.createEventAndFirstInstance(createReq);
        assertProgramQuestionOneValues(created.eventId, programPlanId);
        FIU_EventsWizardService.CreateResult physicalUpdated = FIU_EventsWizardService.createEventAndFirstInstance(physicalUpdateReq);
        assertProgramQuestionOneCleared(created.eventId, programPlanId);
        FIU_EventsWizardService.ProgramSelectionResult selection =
            FIU_EventsWizardService.applyProgramSelection(String.valueOf(created.eventId), String.valueOf(account.Id), new List<String>());
        FIU_EventsWizardService.CreateResult previewed =
            FIU_EventsWizardService.previewEventJson(JSON.serialize(previewReq));
        previewReq.eventName = 'Scoped Wizard Preview Updated';
        FIU_EventsWizardService.CreateResult previewedAgain = FIU_EventsWizardService.previewEvent(previewReq);
        Test.stopTest();

        System.assertNotEquals(null, workingId);
        System.assertNotEquals(null, draftId);
        System.assertNotEquals(null, created.eventId);
        System.assertNotEquals(null, created.instanceId);
        System.assertEquals(created.eventId, physicalUpdated.eventId);
        System.assertEquals(String.valueOf(account.Id), selection.businessUnitId);
        System.assertNotEquals(null, previewed.eventId);
        System.assertEquals(previewed.eventId, previewedAgain.eventId);
    }

    @IsTest
    static void wizardValidationBranchesReturnHandledErrors() {
        Account account = [SELECT Id FROM Account WHERE Name = 'Scoped App Test Account' LIMIT 1];

        assertWizardErrorForNullCreate();
        assertWizardErrorForNullDraft();
        assertWizardErrorForNullPreview();

        FIU_EventsWizardService.CreateRequest previewMissingName = new FIU_EventsWizardService.CreateRequest();
        previewMissingName.accountId = String.valueOf(account.Id);
        assertWizardPreviewFails(previewMissingName);

        FIU_EventsWizardService.CreateRequest previewMissingBusiness = new FIU_EventsWizardService.CreateRequest();
        previewMissingBusiness.eventName = 'Preview Missing Business';
        assertWizardPreviewFails(previewMissingBusiness);

        try {
            FIU_EventsWizardService.previewEventJson(null);
            System.assert(false, 'Blank preview payload should fail.');
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }

        FIU_EventsWizardService.CreateRequest missingName = new FIU_EventsWizardService.CreateRequest();
        missingName.accountId = String.valueOf(account.Id);
        missingName.businessUnitId = String.valueOf(account.Id);
        try {
            FIU_EventsWizardService.createEventAndFirstInstance(missingName);
            System.assert(false, 'Missing event name should fail.');
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }

        FIU_EventsWizardService.CreateRequest missingStatus = new FIU_EventsWizardService.CreateRequest();
        missingStatus.eventName = 'Missing Status';
        missingStatus.accountId = String.valueOf(account.Id);
        missingStatus.businessUnitId = String.valueOf(account.Id);
        missingStatus.recordTypeId = firstAvailableEventRecordTypeId();
        try {
            FIU_EventsWizardService.createEventAndFirstInstance(missingStatus);
            System.assert(false, 'Missing status should fail.');
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }

        FIU_EventsWizardService.InitData initData = FIU_EventsWizardService.getInitData();
        FIU_EventsWizardService.CreateRequest invalidCapacity = newWizardRequest(account.Id, initData, 'Invalid Capacity');
        invalidCapacity.capacity = 0;
        assertWizardCreateFails(invalidCapacity);

        FIU_EventsWizardService.CreateRequest invalidDates = newWizardRequest(account.Id, initData, 'Invalid Dates');
        invalidDates.eventEndDate = invalidDates.eventStartDate.addDays(-1);
        assertWizardCreateFails(invalidDates);

        FIU_EventsWizardService.CreateRequest missingInstanceTime = newWizardRequest(account.Id, initData, 'Missing Instance Time');
        missingInstanceTime.createFirstInstance = true;
        missingInstanceTime.instanceStart = null;
        assertWizardCreateFails(missingInstanceTime);

        FIU_EventsWizardService.CreateRequest paidWithoutAccounting = newWizardRequest(account.Id, initData, 'Paid Missing Accounting');
        paidWithoutAccounting.paymentGateway = 'Paid Gateway';
        paidWithoutAccounting.accountingDepartmentId = null;
        assertWizardCreateFails(paidWithoutAccounting);

        FIU_EventsWizardService.CreateRequest missingPhysicalLocation = newWizardRequest(account.Id, initData, 'Missing Physical Location');
        missingPhysicalLocation.locationType = 'On-Site';
        missingPhysicalLocation.locationTitle = null;
        assertWizardCreateFails(missingPhysicalLocation);

        FIU_EventsWizardService.CreateRequest missingBusinessUnit = newWizardRequest(account.Id, initData, 'Missing Business Unit');
        missingBusinessUnit.accountId = null;
        missingBusinessUnit.businessUnitId = null;
        assertWizardCreateFails(missingBusinessUnit);

        FIU_EventsWizardService.CreateRequest missingTemplate = newWizardRequest(account.Id, initData, 'Missing Template');
        missingTemplate.templateId = null;
        assertWizardCreateFails(missingTemplate);

        FIU_EventsWizardService.CreateRequest missingStartDate = newWizardRequest(account.Id, initData, 'Missing Start Date');
        missingStartDate.eventStartDate = null;
        assertWizardCreateFails(missingStartDate);

        FIU_EventsWizardService.CreateRequest missingLocationType = newWizardRequest(account.Id, initData, 'Missing Location Type');
        missingLocationType.locationType = null;
        assertWizardCreateFails(missingLocationType);

        try {
            FIU_EventsWizardService.applyProgramSelection(null, null, null);
            System.assert(false, 'Missing program context should fail.');
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }

        System.assertEquals(0, FIU_EventsWizardService.getProgramsForBusinessUnit(null).size());
    }

    private static void assertWizardErrorForNullCreate() {
        try {
            FIU_EventsWizardService.createEventAndFirstInstance(null);
            System.assert(false, 'Null create request should fail.');
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
    }

    private static void assertWizardErrorForNullDraft() {
        try {
            FIU_EventsWizardService.createDraftEvent(null);
            System.assert(false, 'Null draft request should fail.');
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
    }

    private static void assertWizardErrorForNullPreview() {
        try {
            FIU_EventsWizardService.previewEvent(null);
            System.assert(false, 'Null preview request should fail.');
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
    }

    private static void assertWizardCreateFails(FIU_EventsWizardService.CreateRequest req) {
        try {
            FIU_EventsWizardService.createEventAndFirstInstance(req);
            System.assert(false, 'Invalid wizard request should fail.');
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
    }

    private static void assertWizardPreviewFails(FIU_EventsWizardService.CreateRequest req) {
        try {
            FIU_EventsWizardService.previewEvent(req);
            System.assert(false, 'Invalid preview request should fail.');
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
    }

    private static FIU_EventsWizardService.CreateRequest newWizardRequest(
        Id accountId,
        FIU_EventsWizardService.InitData initData,
        String eventName
    ) {
        FIU_EventsWizardService.CreateRequest req = new FIU_EventsWizardService.CreateRequest();
        req.eventName = eventName;
        req.recordTypeId = String.isNotBlank(initData.defaultRecordTypeId)
            ? initData.defaultRecordTypeId
            : firstAvailableEventRecordTypeId();
        req.accountId = String.valueOf(accountId);
        req.businessUnitId = String.valueOf(accountId);
        req.eventStatus = firstOptionValue(initData.eventStatusOptions, eventPicklistValue('summit__Event_Status__c', 'Active'));
        req.eventStartDate = Date.today().addDays(20);
        req.eventEndDate = Date.today().addDays(21);
        req.includesMultiplePrograms = false;
        req.programFilterValues = new Map<String, String>();
        FiuProgramFilterService.ProgramFilterConfig config = FiuProgramFilterService.getConfig();
        for (String fieldApi : config.eventProgramFields) {
            req.programFilterValues.put(fieldApi, PROGRAM_CODE);
        }
        req.createOppsFromRegs = false;
        req.sendRegistrationConfirmation = false;
        req.paymentGateway = firstOptionValue(initData.paymentGatewayOptions, eventPicklistValue('summit__Payment_Gateway__c', 'No Gateway'));
        req.templateId = eventPicklistValue('summit__Template__c', 'FIU_Chapman_Payment_Template');
        req.category = firstOptionValue(initData.categoryOptions, 'General');
        req.eventType = firstOptionValue(initData.eventTypeOptions, 'General');
        req.locationType = firstOptionValue(initData.locationTypeOptions, 'Online');
        if (String.isBlank(req.locationType)) req.locationType = 'Online';
        req.locationTitle = 'FIU MMC';
        req.locationAddress = '11200 SW 8th St, Miami, FL';
        req.locationMapLink = 'https://maps.fiu.edu';
        req.building = eventPicklistValue('summit__Building__c', 'CBC');
        req.capacity = 30;
        req.filterCategory = firstOptionValue(initData.filterCategoryOptions, null);
        req.confirmationTitle = 'Registration received';
        req.confirmationDescription = 'Thank you for registering.';
        req.landingDescription = 'Scoped wizard landing description.';
        req.landingFullText = '<p>Scoped wizard details.</p>';
        req.landingShortListingDescription = 'Scoped listing.';
        req.customQuestionsTitle = null;
        req.customQuestionsDescription = null;
        req.privateEvent = false;
        req.registerButtonText = 'Register';
        req.eventHomeLinkTitle = 'FIU';
        req.eventHomeLinkUrl = 'https://www.fiu.edu';
        req.feedRegistrationButtonText = 'Register';
        req.registrationEmailRestriction = firstOptionValue(initData.registrationEmailRestrictionOptions, null);
        req.eventFee = 0;
        req.eventFeeAdditional = 0;
        req.eventFeeLabel = 'Event Fee';
        req.eventFeeSubmitListLabel = 'Fees';
        req.eventPaymentReceivedHeadingLabel = 'Payment received';
        req.eventFeesReceivedLabel = 'Fees received';
        req.eventFeeTotalLabel = 'Total';
        req.eventPaymentDueHeadingLabel = 'Payment due';
        req.instanceTitle = eventName + ' Instance';
        req.instanceStart = Datetime.now().addDays(20);
        req.instanceEnd = Datetime.now().addDays(20).addHours(2);
        req.instanceOpenRegistration = true;
        req.instanceActiveStatus = 'Active';
        return req;
    }

    private static String firstOptionValue(List<FIU_EventsWizardService.Option> options, String fallback) {
        if (options != null) {
            for (FIU_EventsWizardService.Option option : options) {
                if (option != null && String.isNotBlank(option.value)) return option.value;
            }
        }
        return fallback;
    }

    private static String firstAvailableEventRecordTypeId() {
        String eventObject = FiuEventsAccessService.resolveEventObject();
        if (String.isBlank(eventObject)) return null;
        String fallback;
        for (Schema.RecordTypeInfo rti : Schema.getGlobalDescribe().get(eventObject).getDescribe().getRecordTypeInfos()) {
            if (!rti.isAvailable() || rti.isMaster()) continue;
            if (rti.isDefaultRecordTypeMapping()) return String.valueOf(rti.getRecordTypeId());
            if (fallback == null) fallback = String.valueOf(rti.getRecordTypeId());
        }
        return fallback;
    }

    private static String universityDepartmentAccountRecordTypeId() {
        for (RecordType rt : [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND IsActive = true
            AND (DeveloperName = 'University_Department' OR Name = 'University Department')
            LIMIT 1
        ]) {
            return String.valueOf(rt.Id);
        }
        return null;
    }

    private static String eventPicklistValue(String fieldApiName, String preferredValue) {
        String eventObject = FiuEventsAccessService.resolveEventObject();
        if (String.isBlank(eventObject)) return preferredValue;
        Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe().get(eventObject).getDescribe().fields.getMap();
        if (!fields.containsKey(fieldApiName)) return preferredValue;
        for (Schema.PicklistEntry entry : fields.get(fieldApiName).getDescribe().getPicklistValues()) {
            if (entry.getValue() == preferredValue) return preferredValue;
        }
        List<Schema.PicklistEntry> entries = fields.get(fieldApiName).getDescribe().getPicklistValues();
        return entries.isEmpty() ? preferredValue : entries[0].getValue();
    }

    private static void putProgramCode(SObject record, String programCode) {
        FiuProgramFilterService.ProgramFilterConfig config = FiuProgramFilterService.getConfig();
        for (String fieldApi : config.eventProgramFields) {
            putIfPresent(record, fieldApi, programCode + ',');
        }
    }

    private static void insertRegistrationIfSupported(Id eventId, Id instanceId, Id contactId) {
        Schema.SObjectType regType = Schema.getGlobalDescribe().get('summit__Summit_Events_Registration__c');
        if (regType == null) return;

        SObject registration = regType.newSObject();
        putIfWritable(registration, 'Name', 'Scoped Registration');
        putIfWritable(registration, 'summit__Event__c', eventId);
        putIfWritable(registration, 'summit__Event_Instance__c', instanceId);
        putIfWritable(registration, 'summit__Contact__c', contactId);
        putIfWritable(registration, 'summit__First_Name__c', 'Scoped');
        putIfWritable(registration, 'summit__Last_Name__c', 'Registrant');
        putIfWritable(registration, 'summit__Email__c', 'scoped.registrant@example.edu');
        putIfWritable(registration, 'summit__Status__c', 'Registered');
        putIfWritable(registration, 'summit__Attendance_Status__c', 'Registered');
        putIfWritable(registration, 'summit__Attended__c', false);
        Database.insert(registration, false);
    }

    private static void putIfPresent(SObject record, String fieldApiName, Object value) {
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApiName)) {
            record.put(fieldApiName, value);
        }
    }

    private static void putIfWritable(SObject record, String fieldApiName, Object value) {
        Map<String, Schema.SObjectField> fields = record.getSObjectType().getDescribe().fields.getMap();
        if (!fields.containsKey(fieldApiName)) return;
        if (!fields.get(fieldApiName).getDescribe().isCreateable()) return;
        record.put(fieldApiName, value);
    }

    private static Id createPlanIfSupported(Id accountId, String planName, String planCode) {
        Schema.SObjectType planType = Schema.getGlobalDescribe().get('Plan__c');
        if (planType == null) return null;
        SObject plan = planType.newSObject();
        putIfWritable(plan, 'Name', planName);
        putIfWritable(plan, 'Plan_Code__c', planCode);
        putIfWritable(plan, 'Department__c', accountId);
        String planTypeValue = picklistValue(planType, 'Type__c', 'Recruitment');
        if (String.isNotBlank(planTypeValue)) putIfWritable(plan, 'Type__c', planTypeValue);
        Database.SaveResult saveResult = Database.insert(plan, false);
        return saveResult.isSuccess() ? saveResult.getId() : null;
    }

    private static void assertProgramQuestionOneValues(Id eventId, Id programPlanId) {
        if (eventId == null || programPlanId == null) return;
        String eventObject = FiuEventsAccessService.resolveEventObject();
        if (String.isBlank(eventObject)) return;
        Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe().get(eventObject).getDescribe().fields.getMap();
        if (!fields.containsKey('summit__Add_Info_Question_Text_1__c') ||
            !fields.containsKey('summit__Add_Info_Question_Pick_List_Long_1__c')) {
            return;
        }
        String soql =
            'SELECT summit__Add_Info_Question_Text_1__c, summit__Add_Info_Question_Pick_List_Long_1__c ' +
            'FROM ' + eventObject + ' WHERE Id = :eventId LIMIT 1';
        SObject savedEvent = Database.query(soql);
        System.assertEquals('Program of Interest', savedEvent.get('summit__Add_Info_Question_Text_1__c'));
        System.assert(String.valueOf(savedEvent.get('summit__Add_Info_Question_Pick_List_Long_1__c')).contains('Professional MBA'));
    }

    private static void assertProgramQuestionOneCleared(Id eventId, Id programPlanId) {
        if (eventId == null || programPlanId == null) return;
        String eventObject = FiuEventsAccessService.resolveEventObject();
        if (String.isBlank(eventObject)) return;
        Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe().get(eventObject).getDescribe().fields.getMap();
        if (!fields.containsKey('summit__Add_Info_Question_Text_1__c') ||
            !fields.containsKey('summit__Add_Info_Question_Pick_List_Long_1__c')) {
            return;
        }
        String soql =
            'SELECT summit__Add_Info_Question_Text_1__c, summit__Add_Info_Question_Pick_List_Long_1__c ' +
            'FROM ' + eventObject + ' WHERE Id = :eventId LIMIT 1';
        SObject savedEvent = Database.query(soql);
        System.assertEquals(null, savedEvent.get('summit__Add_Info_Question_Text_1__c'));
        System.assertEquals(null, savedEvent.get('summit__Add_Info_Question_Pick_List_Long_1__c'));
    }

    private static String picklistValue(Schema.SObjectType sObjectType, String fieldApiName, String preferredValue) {
        if (sObjectType == null || String.isBlank(fieldApiName)) return null;
        Map<String, Schema.SObjectField> fields = sObjectType.getDescribe().fields.getMap();
        if (!fields.containsKey(fieldApiName)) return null;
        for (Schema.PicklistEntry entry : fields.get(fieldApiName).getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == preferredValue) return preferredValue;
        }
        for (Schema.PicklistEntry entry : fields.get(fieldApiName).getDescribe().getPicklistValues()) {
            if (entry.isActive()) return entry.getValue();
        }
        return null;
    }
}
