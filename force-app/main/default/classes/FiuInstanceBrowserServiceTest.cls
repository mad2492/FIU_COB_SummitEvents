@IsTest
private class FiuInstanceBrowserServiceTest {
    @IsTest
    static void queryInstancesUsesCursorForBrowsePages() {
        Campaign campaign = new Campaign(
            Name = 'Cursor Browser Test Campaign',
            IsActive = true
        );
        insert campaign;

        summit__Summit_Events__c eventRow = new summit__Summit_Events__c(
            Name = 'Cursor Browser Test',
            summit__Template__c = 'FIU_Chapman_Payment_Template'
        );
        putIfPresent(eventRow, 'Preview_Event__c', false);
        putIfPresent(eventRow, 'Campaign__c', campaign.Id);
        insert eventRow;

        Date startDate = Date.today().addDays(14);
        List<summit__Summit_Events_Instance__c> instances = new List<summit__Summit_Events_Instance__c>();
        for (Integer i = 0; i < 3; i++) {
            summit__Summit_Events_Instance__c instanceRow = new summit__Summit_Events_Instance__c(
                summit__Event__c = eventRow.Id,
                summit__Instance_Title__c = 'Cursor Instance ' + i,
                summit__Instance_Start_Date__c = startDate,
                summit__Instance_End_Date__c = startDate.addDays(1),
                summit__Active_Status__c = 'Active',
                summit__Capacity__c = 25,
                summit__Location_Title_Override__c = 'FIU',
                summit__Location_Address_Override__c = '11200 SW 8th St, Miami, FL',
                summit__Location_Map_Link_Override__c = 'https://maps.fiu.edu',
                Parking_info__c = 'Visitor parking'
            );
            putIfPresent(instanceRow, 'Campaign_Override__c', campaign.Id);
            instances.add(instanceRow);
        }
        insert instances;

        Test.startTest();
        FiuInstanceBrowserService.InstanceQueryResult firstPage = FiuInstanceBrowserService.queryInstances(
            eventRow.Id,
            null,
            'All',
            '',
            1,
            2,
            'startDate',
            'ASC',
            '',
            'ASC',
            null,
            null
        );
        FiuInstanceBrowserService.InstanceQueryResult secondPage = FiuInstanceBrowserService.queryInstances(
            eventRow.Id,
            null,
            'All',
            '',
            2,
            2,
            'startDate',
            'ASC',
            '',
            'ASC',
            firstPage.nextCursor,
            null
        );
        Test.stopTest();

        System.assertEquals(true, firstPage.cursorPaging, 'Browse pages should use cursor pagination.');
        System.assertEquals(2, firstPage.rows.size(), 'The first page should be filled to the requested page size.');
        System.assertEquals(true, firstPage.hasNext, 'A lookahead row should mark the first page as having a next page.');
        System.assertNotEquals(null, firstPage.nextCursor, 'The first page should return a cursor for the next page.');

        System.assertEquals(true, secondPage.cursorPaging, 'The second page should remain in cursor mode.');
        System.assertEquals(true, secondPage.hasPrevious, 'A supplied cursor should indicate that a previous page exists.');
        System.assertEquals(1, secondPage.rows.size(), 'Only the remaining row should be returned.');
        System.assertEquals(false, secondPage.hasNext, 'The final page should not expose another cursor.');
        System.assert(!new Set<Id>{ firstPage.rows[0].id, firstPage.rows[1].id }.contains(secondPage.rows[0].id));
    }

    private static void putIfPresent(SObject record, String fieldApiName, Object value) {
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApiName)) {
            record.put(fieldApiName, value);
        }
    }
}
