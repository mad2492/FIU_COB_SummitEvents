@IsTest
private class FiuReadinessRecalcServiceTest {
    @IsTest
    static void eventAndInstanceTriggersQueueReadinessRecalc() {
        Campaign campaign = new Campaign(
            Name = 'Preview Readiness Test Campaign',
            IsActive = true
        );
        insert campaign;

        summit__Summit_Events__c eventRow = new summit__Summit_Events__c(
            Name = 'Preview Readiness Test'
        );
        String recordTypeId = firstAvailableEventRecordTypeId();
        if (String.isNotBlank(recordTypeId)) eventRow.RecordTypeId = (Id) recordTypeId;
        putIfPresent(eventRow, 'Campaign__c', campaign.Id);
        putIfPresent(eventRow, 'Preview_Event__c', true);
        putIfPresent(eventRow, 'summit__Template__c', eventPicklistValue('summit__Template__c', 'FIU_Chapman_Payment_Template'));

        Test.startTest();
        insert eventRow;

        summit__Summit_Events_Instance__c instanceRow = new summit__Summit_Events_Instance__c(
            summit__Event__c = eventRow.Id,
            summit__Instance_Start_Date__c = Date.today().addDays(14),
            summit__Active_Status__c = 'Active',
            summit__Capacity__c = 25,
            summit__Location_Title_Override__c = 'FIU',
            summit__Location_Address_Override__c = '11200 SW 8th St, Miami, FL',
            summit__Location_Map_Link_Override__c = 'https://maps.fiu.edu',
            Parking_info__c = 'Visitor parking'
        );
        putIfPresent(instanceRow, 'Campaign_Override__c', campaign.Id);
        insert instanceRow;
        FiuReadinessRecalcService.recalcNow(new Set<Id>{ eventRow.Id }, new Set<Id>{ instanceRow.Id });
        Test.stopTest();

        summit__Summit_Events_Instance__c refreshedInstance = [
            SELECT FIU_Readiness_Status__c, FIU_Readiness_Reason__c
            FROM summit__Summit_Events_Instance__c
            WHERE Id = :instanceRow.Id
        ];
        System.assertNotEquals(null, refreshedInstance.FIU_Readiness_Status__c);

        summit__Summit_Events__c refreshedEvent = [
            SELECT FIU_Readiness_Status__c
            FROM summit__Summit_Events__c
            WHERE Id = :eventRow.Id
        ];
        System.assertNotEquals(null, refreshedEvent.FIU_Readiness_Status__c);
    }

    private static void putIfPresent(SObject record, String fieldApiName, Object value) {
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApiName)) {
            record.put(fieldApiName, value);
        }
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
}
