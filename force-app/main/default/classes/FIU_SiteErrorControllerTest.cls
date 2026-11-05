@isTest
private class FIU_SiteErrorControllerTest {
	private static summit__Summit_Events_Instance__c createInstance() {
		SPDataInitManager initManager = new SPDataInitManager();
		SPSummitEventsTestDataFactory.createEventAndInstance(initManager);
		return [SELECT Id, summit__Event__c FROM summit__Summit_Events_Instance__c LIMIT 1];
	}

	private static FIU_SiteErrorController controllerFor(String instanceId) {
		System.PageReference errorPage = new System.PageReference('/FIU_Site_Error');
		errorPage.getParameters().put('instanceID', instanceId);
		Test.setCurrentPage(errorPage);
		return new FIU_SiteErrorController();
	}

	@isTest
	private static void testNamesMissingAccount() {
		summit__Summit_Events_Instance__c eventInstance = createInstance();

		Test.startTest();
		FIU_SiteErrorController controller = controllerFor(eventInstance.Id);
		Test.stopTest();

		System.assertEquals('Test Event Session', controller.eventName, 'The event must be named');
		System.assert(controller.hasMissingSetup, 'Missing setup must be reported');
		System.assertEquals(
			'Account (on the event)',
			controller.missingSetup[0],
			'The factory event has no Account, so it must be listed'
		);
		System.assertEquals(false, controller.hasBadEventLink, 'The link itself is fine');
	}

	@isTest
	private static void testNamesMissingInstanceFields() {
		summit__Summit_Events_Instance__c eventInstance = createInstance();
		eventInstance.summit__Instance_Start_Time__c = null;
		eventInstance.summit__Instance_Time_Zone__c = null;
		update eventInstance;

		Test.startTest();
		FIU_SiteErrorController controller = controllerFor(eventInstance.Id);
		Test.stopTest();

		String missing = String.join(controller.missingSetup, ', ');
		System.assert(missing.contains('Start time'), 'Start time must be listed: ' + missing);
		System.assert(missing.contains('Time zone'), 'Time zone must be listed: ' + missing);
	}

	@isTest
	private static void testMalformedLink() {
		Test.startTest();
		FIU_SiteErrorController controller = controllerFor('not-a-valid-id');
		Test.stopTest();

		System.assertEquals(true, controller.hasBadEventLink, 'A malformed link must be reported');
		System.assertEquals(false, controller.hasMissingSetup, 'No setup can be checked without an event');
	}

	@isTest
	private static void testLinkToMissingEvent() {
		String keyPrefix = summit__Summit_Events_Instance__c.SObjectType.getDescribe().getKeyPrefix();

		Test.startTest();
		FIU_SiteErrorController controller = controllerFor(keyPrefix + '000000000000');
		Test.stopTest();

		System.assertEquals(true, controller.hasBadEventLink, 'A link with no matching event must be reported');
	}

	@isTest
	private static void testNoEventInLink() {
		Test.setCurrentPage(new System.PageReference('/FIU_Site_Error'));

		Test.startTest();
		FIU_SiteErrorController controller = new FIU_SiteErrorController();
		Test.stopTest();

		System.assertEquals(false, controller.hasBadEventLink, 'No link problem without an instanceID');
		System.assertEquals(false, controller.hasMissingSetup, 'No setup problem without an instanceID');
	}

	@isTest
	private static void testReadsInstanceIdFromOriginalUrl() {
		System.assertEquals(
			'abc',
			FIU_SiteErrorController.readInstanceIdFromUrl('/fiubusiness/page?x=1&instanceID=abc&y=2'),
			'The instanceID must be read from the address'
		);
		System.assertEquals(
			null,
			FIU_SiteErrorController.readInstanceIdFromUrl('/fiubusiness/page'),
			'An address with no instanceID returns nothing'
		);
		System.assertEquals(null, FIU_SiteErrorController.readInstanceIdFromUrl(null), 'A blank address returns nothing');
	}
}
