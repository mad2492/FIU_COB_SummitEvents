@IsTest
private class FiuEventsServicesTest {
    @IsTest
    static void readiness_flags_missing_account() {
        SObject mockEvent = newMockEvent();
        putIfPresent(mockEvent, 'summit__Account__c', null);
        putIfPresent(mockEvent, 'FIU_Create_Opps_From_Regs__c', true);
        putIfPresent(mockEvent, 'Send_Registration_Confirmation_Email__c', true);

        FiuEventsReadinessService.ReadinessResult result = FiuEventsReadinessService.evaluateEventRecord(mockEvent);
        System.assertEquals(false, result.ready);
        System.assert(result.missingFields.contains('summit__Account__c'));
        System.assert(result.warnings.size() > 0);
    }

    @IsTest
    static void clone_risk_collects_expected_warnings() {
        SObject sourceEvent = newMockEvent();
        putIfPresent(sourceEvent, 'FIU_Create_Opps_From_Regs__c', true);
        putIfPresent(sourceEvent, 'Send_Registration_Confirmation_Email__c', true);
        putIfPresent(sourceEvent, 'Accounting_Department__c', 'Finance');

        FiuEventsOrchestratorService.CloneRiskResult result = FiuEventsOrchestratorService.evaluateCloneRiskRecord(sourceEvent);
        System.assert(result.riskWarnings.size() >= 1);
    }

    @IsTest
    static void readiness_detects_salesforce_hosted_rich_text_images() {
        System.assertEquals(
            true,
            FiuEventsReadinessService.hasSalesforceHostedRichTextImage('<p><img src="/servlet/rtaImage?eid=a0B"/></p>')
        );
        System.assertEquals(
            false,
            FiuEventsReadinessService.hasSalesforceHostedRichTextImage('<p><img src="https://example.edu/event-banner.png"/></p>')
        );
    }

    @IsTest
    static void csv_builder_quotes_values() {
        FiuEventsRosterService.RegistrationRow row = new FiuEventsRosterService.RegistrationRow();
        row.registrationId = 'a1T000000000001AAA';
        row.name = 'Person, Name';
        row.email = 'person@example.edu';
        row.status = 'Registered';
        row.attended = true;

        String csv = FiuEventsRosterService.buildCsv(new List<FiuEventsRosterService.RegistrationRow>{ row });
        System.assert(csv.contains('"Person, Name"'));
        System.assert(csv.startsWith('RegistrationId,Name,Email,Status,Attended'));
    }

    private static SObject newMockEvent() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey('summit__Summit_Event__c')) {
            return gd.get('summit__Summit_Event__c').newSObject();
        }
        if (gd.containsKey('summit__Event__c')) {
            return gd.get('summit__Event__c').newSObject();
        }
        return new Account();
    }

    private static void putIfPresent(SObject record, String fieldApiName, Object value) {
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApiName)) {
            record.put(fieldApiName, value);
        }
    }
}
