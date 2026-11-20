@IsTest
private class FiuReadinessPolicyServiceTest {
    @IsTest
    static void eventCapacityPositivePassesCapacityPolicy() {
        SObject eventRow = newEventRecord();
        putIfPresent(eventRow, 'summit__Account__c', fakeId(Account.SObjectType));
        putIfPresent(eventRow, 'summit__Capacity__c', 25);

        FiuReadinessPolicyService.EventPolicyContext context = eventContext();
        FiuReadinessPolicyService.ReadinessResult result = FiuReadinessPolicyService.evaluateEvent(eventRow, context);

        System.assertEquals(true, result.ready, 'Valid event capacity should not create a blocking issue.');
        System.assertEquals(false, hasIssue(result, 'EVENT_MISSING_CAPACITY'));
    }

    @IsTest
    static void eventCapacityMissingZeroAndNegativeBlockReadiness() {
        for (Decimal capacity : new List<Decimal>{ null, Decimal.valueOf('0'), Decimal.valueOf('-1') }) {
            SObject eventRow = newEventRecord();
            putIfPresent(eventRow, 'summit__Account__c', fakeId(Account.SObjectType));
            putIfPresent(eventRow, 'summit__Capacity__c', capacity);

            FiuReadinessPolicyService.ReadinessResult result = FiuReadinessPolicyService.evaluateEvent(eventRow, eventContext());

            System.assertEquals(false, result.ready, 'Invalid event capacity should block readiness.');
            FiuReadinessPolicyService.ReadinessIssue issue = firstIssue(result, 'EVENT_MISSING_CAPACITY');
            System.assertNotEquals(null, issue, 'Capacity issue should use a stable code.');
            System.assertEquals(true, issue.blocking);
            System.assertEquals('Missing capacity', issue.message);
            System.assertEquals('summit__Capacity__c', issue.fieldApiName);
        }
    }

    @IsTest
    static void instanceCapacityPositivePassesCapacityPolicy() {
        SObject instanceRow = newInstanceRecord();
        putIfPresent(instanceRow, 'summit__Capacity__c', 10);
        putRequiredInstanceFields(instanceRow);

        FiuReadinessPolicyService.ReadinessResult result = FiuReadinessPolicyService.evaluateInstance(instanceRow, null, instanceContext());

        System.assertEquals(true, result.ready, 'Valid instance capacity should not create a blocking issue.');
        System.assertEquals(false, hasIssue(result, 'INSTANCE_MISSING_CAPACITY'));
    }

    @IsTest
    static void instanceCapacityMissingZeroAndNegativeBlockReadiness() {
        for (Decimal capacity : new List<Decimal>{ null, Decimal.valueOf('0'), Decimal.valueOf('-1') }) {
            SObject instanceRow = newInstanceRecord();
            putIfPresent(instanceRow, 'summit__Capacity__c', capacity);
            putRequiredInstanceFields(instanceRow);

            FiuReadinessPolicyService.ReadinessResult result = FiuReadinessPolicyService.evaluateInstance(instanceRow, null, instanceContext());

            System.assertEquals(false, result.ready, 'Invalid instance capacity should block readiness.');
            FiuReadinessPolicyService.ReadinessIssue issue = firstIssue(result, 'INSTANCE_MISSING_CAPACITY');
            System.assertNotEquals(null, issue, 'Instance capacity issue should use a stable code.');
            System.assertEquals(true, issue.blocking);
            System.assertEquals('Missing capacity', issue.message);
            System.assertEquals('summit__Capacity__c', issue.fieldApiName);
        }
    }

    @IsTest
    static void eventRelatedInstanceCapacityBlocksEventReadiness() {
        SObject eventRow = newEventRecord();
        putIfPresent(eventRow, 'summit__Account__c', fakeId(Account.SObjectType));
        putIfPresent(eventRow, 'summit__Capacity__c', 25);

        SObject validInstance = newInstanceRecord();
        putIfPresent(validInstance, 'summit__Capacity__c', 10);

        SObject invalidInstance = newInstanceRecord();
        putIfPresent(invalidInstance, 'summit__Capacity__c', 0);

        FiuReadinessPolicyService.EventPolicyContext context = eventContext();
        context.relatedInstances = new List<SObject>{ validInstance, invalidInstance };
        context.includeRelatedInstanceCapacityCheck = true;
        context.instanceCapacityField = 'summit__Capacity__c';

        FiuReadinessPolicyService.ReadinessResult result = FiuReadinessPolicyService.evaluateEvent(eventRow, context);

        System.assertEquals(false, result.ready);
        System.assert(hasIssue(result, 'EVENT_RELATED_INSTANCE_MISSING_CAPACITY'));
    }

    @IsTest
    static void programRoutedEventBlocksWhenQuestionOneLabelIsNotExact() {
        SObject eventRow = newEventRecord();
        putIfPresent(eventRow, 'summit__Account__c', fakeId(Account.SObjectType));
        putIfPresent(eventRow, 'summit__Capacity__c', 25);
        putIfPresent(eventRow, 'Default_Plan__c', fakePlanId());
        putIfPresent(eventRow, 'Includes_Multiple_Programs__c', true);
        putIfPresent(eventRow, 'Send_Registration_Confirmation_Email__c', true);
        putIfPresent(eventRow, 'summit__Add_Info_Question_Text_1__c', 'Enrolled Program');
        putIfPresent(eventRow, 'summit__Add_Info_Question_Pick_List_Long_1__c', 'Professional MBA');

        FiuReadinessPolicyService.ReadinessResult result =
            FiuReadinessPolicyService.evaluateEvent(eventRow, programRoutingContext());

        System.assertEquals(false, result.ready, 'Program-routed events should not pass with a mismatched Summit question label.');
        FiuReadinessPolicyService.ReadinessIssue issue = firstIssue(result, 'EVENT_PROGRAM_PICKER_LABEL_MISMATCH');
        System.assertNotEquals(null, issue, 'Program picker label issue should use a stable code.');
        System.assertEquals(true, issue.blocking);
        System.assertEquals('summit__Add_Info_Question_Text_1__c', issue.fieldApiName);
    }

    @IsTest
    static void programRoutedEventPassesWhenQuestionOneLabelIsExact() {
        SObject eventRow = newEventRecord();
        putIfPresent(eventRow, 'summit__Account__c', fakeId(Account.SObjectType));
        putIfPresent(eventRow, 'summit__Capacity__c', 25);
        putIfPresent(eventRow, 'Default_Plan__c', fakePlanId());
        putIfPresent(eventRow, 'Includes_Multiple_Programs__c', true);
        putIfPresent(eventRow, 'Send_Registration_Confirmation_Email__c', true);
        putIfPresent(eventRow, 'summit__Add_Info_Question_Text_1__c', FiuReadinessPolicyService.PROGRAM_OF_INTEREST_LABEL);
        putIfPresent(eventRow, 'summit__Add_Info_Question_Pick_List_Long_1__c', 'Professional MBA');

        FiuReadinessPolicyService.ReadinessResult result =
            FiuReadinessPolicyService.evaluateEvent(eventRow, programRoutingContext());

        System.assertEquals(false, hasIssue(result, 'EVENT_PROGRAM_PICKER_LABEL_MISMATCH'));
        System.assertEquals(false, hasIssue(result, 'EVENT_PROGRAM_PICKER_OPTIONS_MISSING'));
    }

    @IsTest
    static void programRoutedEventBlocksWhenQuestionOneOptionsAreMissing() {
        SObject eventRow = newEventRecord();
        putIfPresent(eventRow, 'summit__Account__c', fakeId(Account.SObjectType));
        putIfPresent(eventRow, 'summit__Capacity__c', 25);
        putIfPresent(eventRow, 'Default_Plan__c', fakePlanId());
        putIfPresent(eventRow, 'Includes_Multiple_Programs__c', true);
        putIfPresent(eventRow, 'Send_Registration_Confirmation_Email__c', true);
        putIfPresent(eventRow, 'summit__Add_Info_Question_Text_1__c', FiuReadinessPolicyService.PROGRAM_OF_INTEREST_LABEL);

        FiuReadinessPolicyService.ReadinessResult result =
            FiuReadinessPolicyService.evaluateEvent(eventRow, programRoutingContext());

        System.assertEquals(false, result.ready);
        System.assertNotEquals(null, firstIssue(result, 'EVENT_PROGRAM_PICKER_OPTIONS_MISSING'));
    }

    @IsTest
    static void singlePlanEventDoesNotRequireProgramPickerQuestionOne() {
        SObject eventRow = newEventRecord();
        putIfPresent(eventRow, 'summit__Account__c', fakeId(Account.SObjectType));
        putIfPresent(eventRow, 'summit__Capacity__c', 25);
        putIfPresent(eventRow, 'Default_Plan__c', fakePlanId());
        putIfPresent(eventRow, 'Includes_Multiple_Programs__c', false);
        putIfPresent(eventRow, 'Send_Registration_Confirmation_Email__c', true);
        putIfPresent(eventRow, 'summit__Add_Info_Question_Text_1__c', 'Enrolled Program');

        FiuReadinessPolicyService.ReadinessResult result =
            FiuReadinessPolicyService.evaluateEvent(eventRow, programRoutingContext());

        System.assertEquals(false, hasIssue(result, 'EVENT_PROGRAM_PICKER_LABEL_MISMATCH'));
        System.assertEquals(false, hasIssue(result, 'EVENT_PROGRAM_PICKER_OPTIONS_MISSING'));
    }

    @IsTest
    static void nullRecordsReturnStructuredBlockingIssues() {
        FiuReadinessPolicyService.ReadinessResult eventResult = FiuReadinessPolicyService.evaluateEvent(null, eventContext());
        FiuReadinessPolicyService.ReadinessResult instanceResult = FiuReadinessPolicyService.evaluateInstance(null, null, instanceContext());

        System.assertEquals(false, eventResult.ready);
        System.assertEquals(true, hasIssue(eventResult, 'EVENT_NOT_FOUND'));
        System.assertEquals(false, instanceResult.ready);
        System.assertEquals(true, hasIssue(instanceResult, 'INSTANCE_NOT_FOUND'));
    }

    @IsTest
    static void policyEvaluationIsBulkSafeAndDoesNotQueryForCapacityOnlyChecks() {
        List<SObject> events = new List<SObject>();
        for (Integer i = 0; i < 50; i++) {
            SObject eventRow = newEventRecord();
            putIfPresent(eventRow, 'summit__Account__c', fakeId(Account.SObjectType));
            putIfPresent(eventRow, 'summit__Capacity__c', i == 0 ? 0 : 25);
            events.add(eventRow);
        }

        Integer queriesBefore = Limits.getQueries();
        Integer blockingCount = 0;
        for (SObject eventRow : events) {
            if (!FiuReadinessPolicyService.evaluateEvent(eventRow, eventContext()).ready) {
                blockingCount++;
            }
        }
        Integer queriesAfter = Limits.getQueries();

        System.assertEquals(1, blockingCount, 'Only the invalid record should be blocked.');
        System.assertEquals(queriesBefore, queriesAfter, 'Capacity-only policy evaluation should not run SOQL.');
    }

    private static FiuReadinessPolicyService.EventPolicyContext eventContext() {
        FiuReadinessPolicyService.EventPolicyContext context = new FiuReadinessPolicyService.EventPolicyContext();
        context.eventCapacityField = 'summit__Capacity__c';
        context.includeProgramCheck = false;
        context.includeQuestionCheck = false;
        context.includeRichTextImageCheck = false;
        context.includeRelatedInstancePresenceCheck = false;
        context.includeRelatedInstanceCapacityCheck = false;
        return context;
    }

    private static FiuReadinessPolicyService.EventPolicyContext programRoutingContext() {
        FiuReadinessPolicyService.EventPolicyContext context = eventContext();
        context.includeProgramCheck = true;
        context.programConfig = new FiuProgramFilterService.ProgramFilterConfig();
        return context;
    }

    private static FiuReadinessPolicyService.InstancePolicyContext instanceContext() {
        FiuReadinessPolicyService.InstancePolicyContext context = new FiuReadinessPolicyService.InstancePolicyContext();
        context.instanceCapacityField = 'summit__Capacity__c';
        return context;
    }

    private static SObject newEventRecord() {
        return Schema.getGlobalDescribe().get('summit__Summit_Events__c').newSObject();
    }

    private static SObject newInstanceRecord() {
        return Schema.getGlobalDescribe().get('summit__Summit_Events_Instance__c').newSObject();
    }

    private static void putRequiredInstanceFields(SObject instanceRow) {
        putIfPresent(instanceRow, 'summit__Instance_Start_Date__c', Date.today().addDays(10));
        putIfPresent(instanceRow, 'summit__Active_Status__c', 'Active');
        putIfPresent(instanceRow, 'summit__Open_Registration__c', true);
        putIfPresent(instanceRow, 'summit__Location_Title_Override__c', 'FIU');
        putIfPresent(instanceRow, 'summit__Location_Address_Override__c', '11200 SW 8th St, Miami, FL');
        putIfPresent(instanceRow, 'summit__Location_Map_Link_Override__c', 'https://maps.fiu.edu');
        putIfPresent(instanceRow, 'Parking_info__c', 'Visitor parking');
    }

    private static void putIfPresent(SObject record, String fieldApiName, Object value) {
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApiName)) {
            record.put(fieldApiName, value);
        }
    }

    private static Id fakeId(Schema.SObjectType sObjectType) {
        String rawId = String.valueOf(sObjectType.getDescribe().getKeyPrefix()) + '000000000000AAA';
        return (Id) rawId;
    }

    private static Id fakePlanId() {
        Schema.SObjectType planType = Schema.getGlobalDescribe().get('Plan__c');
        return planType == null ? null : fakeId(planType);
    }

    private static Boolean hasIssue(FiuReadinessPolicyService.ReadinessResult result, String code) {
        return firstIssue(result, code) != null;
    }

    private static FiuReadinessPolicyService.ReadinessIssue firstIssue(FiuReadinessPolicyService.ReadinessResult result, String code) {
        if (result == null || result.issues == null) return null;
        for (FiuReadinessPolicyService.ReadinessIssue issue : result.issues) {
            if (issue != null && issue.code == code) return issue;
        }
        return null;
    }
}
