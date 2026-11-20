@IsTest
private class FiuSupportServicesCoverageTest {
    @IsTest
    static void accessResolversReturnAvailableMetadata() {
        System.assertNotEquals(null, FiuEventsAccessService.resolveEventObject());
        System.assertNotEquals(null, FiuEventsAccessService.resolveInstanceObject());
        System.assertNotEquals(null, FiuEventsAccessService.getAllowedEventRecordTypeIds());
        System.assertNotEquals(null, FiuEventsAccessService.getScopedEventRecordTypeIds(null));
        System.assertNotEquals(null, FiuEventsAccessService.getEventRecordTypeOptions());

        FiuEventsAccessService.resolveEventPreviewField();
        FiuEventsAccessService.resolveEventUrlField();
        FiuEventsAccessService.resolveEventQuestionObject();
        FiuEventsAccessService.resolveEventQuestionLookupField();
        FiuEventsAccessService.resolveInstancePreviewField();
    }

    @IsTest
    static void programFilterHelpersNormalizeAndMatchConfiguredFields() {
        FiuProgramFilterService.ProgramFilterConfig config = FiuProgramFilterService.getConfig();
        FiuProgramFilterService.getProgramOptions(null);

        String normalized = FiuProgramFilterService.normalizeCode(' mba, ');
        System.assertEquals('MBA', normalized);
        FiuProgramFilterService.buildProgramWhereClause('summit__Event__r.', normalized, config);
        FiuProgramFilterService.buildProgramWhereClause('summit__Event__r.', null, config);

        SObject eventRecord = Schema.getGlobalDescribe().get(FiuEventsAccessService.resolveEventObject()).newSObject();
        for (String eventProgramField : config.eventProgramFields) {
            putIfPresent(eventRecord, eventProgramField, 'MBA, BBA');
        }

        Set<String> codes = FiuProgramFilterService.extractProgramCodesFromEvent(eventRecord, config);
        FiuProgramFilterService.eventMatchesSelectedProgram(eventRecord, config, 'MBA');
        FiuProgramFilterService.eventMatchesSelectedProgram(eventRecord, config, '');
        if (!config.eventProgramFields.isEmpty()) {
            System.assert(codes.contains('MBA'));
        }
    }

    @IsTest
    static void readinessEvaluateEventCoversDatabasePath() {
        Account account = new Account(Name = 'Cursor Readiness Account');
        insert account;

        Campaign campaign = new Campaign(
            Name = 'Cursor Readiness Campaign',
            IsActive = true
        );
        insert campaign;

        summit__Summit_Events__c eventRow = new summit__Summit_Events__c(
            Name = 'Cursor Readiness Event',
            summit__Template__c = 'FIU_Chapman_Payment_Template'
        );
        putIfPresent(eventRow, 'Preview_Event__c', false);
        putIfPresent(eventRow, 'Campaign__c', campaign.Id);
        putIfPresent(eventRow, 'summit__Account__c', account.Id);
        putIfPresent(eventRow, 'summit__Capacity__c', 25);
        putIfPresent(eventRow, 'summit__Payment_Gateway__c', 'No Gateway');
        putIfPresent(eventRow, 'FIU_Create_Opps_From_Regs__c', true);
        putIfPresent(eventRow, 'Send_Registration_Confirmation_Email__c', true);
        putIfPresent(eventRow, 'summit__Event_Additional_Question_Title__c', 'Questions');
        putIfPresent(eventRow, 'summit__Event_description__c', '<p><img src="/servlet/rtaImage?eid=a0B"/></p>');
        insert eventRow;

        FiuEventsReadinessService.ReadinessResult result = FiuEventsReadinessService.evaluateEvent(eventRow.Id);

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.warnings.size() > 0);
    }

    private static void putIfPresent(SObject record, String fieldApiName, Object value) {
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApiName)) {
            record.put(fieldApiName, value);
        }
    }
}
