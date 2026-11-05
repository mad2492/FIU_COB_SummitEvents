/**
 * @File Name          : SPRsvpTemplateServiceTest.cls
 * @Description        :
 * @Author             : aniubo
 * @Group              :
 * @Last Modified By   : aniubo
 * @Last Modified On   : 6/16/2023, 4:04:54 PM
 * @Modification Log   :
 *==============================================================================
 * Ver         Date                     Author      		      Modification
 *==============================================================================
 * 1.0    6/15/2023, 4:18:45 PM   aniubo     Initial Version
 * 2.0    8/22/2023, 11:58:00 AM   mdennis    Tests for new additions
 * 2.1    11/4/2026                mdennis    Tests for instanceID taking priority over the cookie
 **/
@isTest
private class SPRsvpTemplateServiceTest {
	private static SPDataInitManager testSetup() {
		SPDataInitManager initManager = new SPDataInitManager();
		SPSummitEventsTestDataFactory.createEventAndInstance(initManager);
		SPSummitEventsTestDataFactory.createEventRegistration(initManager);
		SPSummitEventsTestDataFactory.createCookie(initManager);
		SPSummitEventsUtils.createEncryptedCookie(SPSummitEventConst.FBC_COOKIE, '_fbc');
		SPSummitEventsUtils.createEncryptedCookie(SPSummitEventConst.FBP_COOKIE, '_fbp');
		return initManager;
	}

	@isTest
	private static void testFacebookVisitRegistrationPage() {
		// Test data setup
		System.PageReference currentPage = new System.PageReference(
			'/' + SPSummitEventConst.REGISTER_PAGE_NAME
		);

		Boolean isOk = true;
		// Actual test
		Test.startTest();
		Test.setCurrentPage(currentPage);
		setMock();
		SPRsvpTemplateService service = new SPRsvpTemplateService(currentPage);
		try {
			service.facebookVisitRegistrationPage();
		} catch (Exception ex) {
			isOk = false;
		}

		Test.stopTest();
		System.assertEquals(isOk, true, 'No Error');

		// Asserts
	}

	@isTest
	private static void testAllFields() {
		System.PageReference currentPage = new System.PageReference(
			'/' + SPSummitEventConst.EVENT_REGISTRATION_NAME
		);
		Test.setCurrentPage(currentPage);
		
		// Test data setup
		testSetup();

		// Actual test
		Test.startTest();
		SPRsvpTemplateService service = new SPRsvpTemplateService(currentPage);

		Test.stopTest();
		System.assertEquals(
			service.backgroundImageUrl,
			'http://banner.com',
			'Must be the default value'
		);

		System.assertEquals(
			service.logoImageUrl,
			'http://logo.com',
			'Must be the default value'
		);
		System.assertEquals(
			service.eventDescription,
			'Test Event Session',
			'The value of eventDescription value must be equal to Test Event Session'
		);
		System.assertEquals(
			String.isNotBlank(service.startEventMonthDay),
			true,
			'startEventMonthDay Must be not empty'
		);
		System.assertEquals(
			String.isNotBlank(service.startEventYear),
			true,
			'startEventYear Must be not empty'
		);
		System.assertEquals(
			String.isNotBlank(service.startEventWeekDay),
			true,
			'startEventWeekDay Must be not empty'
		);
		System.assertEquals(
			String.isNotBlank(service.startEventTime),
			true,
			'startEventTime Must be  not empty'
		);
		System.assertEquals(
			service.registerButtonLabel,
			'Button_Label',
			'The value of registerButtonLabel value must be equal to Button_Label'
		);

		System.assertEquals(
			service.disclaimerText,
			'Disclaimer',
			'The value of disclaimerText value must be equal to Disclaimer'
		);

		System.assertEquals(
			service.onlineEvent,
			true,
			'The value of onlineEvent value must be equal to True'
		);

		System.assertEquals(
			service.meetUrl,
			'http://virtual-link.com',
			'The value of meetUrl value must be equal tohttp://virtual-link.com'
		);

		System.assertEquals(
			String.isNotBlank(service.calendarUrl),
			true,
			'The value of calendarUrl value must be not empty'
		);
		System.assertEquals(
			String.isNotBlank(service.metaTitle),
			true,
			'The value of metaTitle value must be not empty'
		);

		System.assertEquals(
			String.isNotBlank(service.fbc),
			true,
			'The value of fbc value must be not empty'
		);
		System.assertEquals(
			String.isNotBlank(service.fbp),
			true,
			'The value of fbp value must be not empty'
		);
		System.assertEquals(
			String.isNotBlank(service.userAgent),
			false,
			'The value of userAgent value must be not empty'
		);
		
		System.assertEquals(
			String.isNotBlank(service.clientIp),
			false,
			'The value of clientIp value must be not empty'
		);

		System.assertEquals(
			String.isNotBlank(service.registrationId),
			true,
			'The value of registrationId value must be not empty'
		);

		System.assertEquals(
			String.isNotBlank(service.relativePath),
			true,
			'The value of relativePath value must be not empty'
		);

		//MB 2.0
		System.assertEquals(
			service.eventInstanceDescription,
			'Test Instance Description',
			'The value of eventInstanceDescription value must be equal to Test Instance Description'
		);

		System.assertEquals(
			service.eventParentDescription,
			'Test Event',
			'The value of eventParentDescription value must be equal to Test Event'
		);

		 
		// Asserts
	}

	@isTest
	private static void testPageInstanceReplacesCookieInstance() {
		System.PageReference currentPage = registrationPage();
		testSetup();
		summit__Summit_Events_Instance__c pageInstance = insertSecondInstance();
		currentPage.getParameters().put('instanceID', pageInstance.Id);

		Test.startTest();
		SPRsvpTemplateService service = new SPRsvpTemplateService(currentPage);
		Test.stopTest();

		System.assertEquals(
			'Page Event Session',
			service.eventDescription,
			'The banner must show the event in the page address, not the cookie event'
		);
		System.assertEquals(
			String.valueOf(Date.today().addDays(30).year()),
			service.startEventYear,
			'The banner date must come from the event in the page address'
		);
		System.assert(
			String.isNotBlank(service.registrationId),
			'The registration must still come from the cookie'
		);
	}

	@isTest
	private static void testMalformedPageInstanceUsesCookie() {
		System.PageReference currentPage = registrationPage();
		testSetup();
		currentPage.getParameters().put('instanceID', 'not-a-valid-id');

		Test.startTest();
		SPRsvpTemplateService service = new SPRsvpTemplateService(currentPage);
		Test.stopTest();

		System.assertEquals(
			'Test Event Session',
			service.eventDescription,
			'A malformed instanceID must fall back to the cookie event'
		);
	}

	@isTest
	private static void testUnknownPageInstanceUsesCookie() {
		System.PageReference currentPage = registrationPage();
		testSetup();
		String keyPrefix = summit__Summit_Events_Instance__c.SObjectType.getDescribe().getKeyPrefix();
		currentPage.getParameters().put('instanceID', keyPrefix + '000000000000');

		Test.startTest();
		SPRsvpTemplateService service = new SPRsvpTemplateService(currentPage);
		Test.stopTest();

		System.assertEquals(
			'Test Event Session',
			service.eventDescription,
			'An instanceID with no record must fall back to the cookie event'
		);
	}

	@isTest
	private static void testEventWithoutAccountStopsWithReason() {
		System.PageReference currentPage = registrationPage();
		testSetup();
		summit__Summit_Events_Instance__c existing = [
			SELECT Id
			FROM summit__Summit_Events_Instance__c
			LIMIT 1
		];
		currentPage.getParameters().put('instanceID', existing.Id);

		Test.startTest();
		SPRsvpTemplateService service = new SPRsvpTemplateService(currentPage);
		String failure;
		try {
			String title = service.htmlTitle;
		} catch (SPRsvpTemplateService.EventSetupException setupException) {
			failure = setupException.getMessage();
		}
		Test.stopTest();

		System.assert(
			failure != null && failure.contains('Account'),
			'An event with no Account must stop and name the Account: ' + failure
		);
	}

	@isTest
	private static void testCompleteEventBuildsTitle() {
		System.PageReference currentPage = registrationPage();
		testSetup();
		summit__Summit_Events_Instance__c existing = [
			SELECT Id, summit__Event__c
			FROM summit__Summit_Events_Instance__c
			LIMIT 1
		];
		Account eventAccount = new Account(Name = 'Chapman Test Account');
		insert eventAccount;
		update new summit__Summit_Events__c(Id = existing.summit__Event__c, summit__Account__c = eventAccount.Id);
		currentPage.getParameters().put('instanceID', existing.Id);

		Test.startTest();
		SPRsvpTemplateService service = new SPRsvpTemplateService(currentPage);
		String title = service.htmlTitle;
		Test.stopTest();

		System.assert(title.startsWith('Test Event Session'), 'The title must start with the instance title: ' + title);
		System.assert(title.contains('Graduate'), 'A Chapman Account must show as Graduate: ' + title);
	}

	@isTest
	private static void testNoEventAnywhereDoesNotCrash() {
		System.PageReference currentPage = registrationPage();
		currentPage.getParameters().put('instanceID', 'not-a-valid-id');

		Test.startTest();
		SPRsvpTemplateService service = new SPRsvpTemplateService(currentPage);
		String title = service.htmlTitle;
		String metaTitle = service.metaTitle;
		String timeZoneText = service.tz;
		Test.stopTest();

		System.assertEquals(null, service.eventDescription, 'No event should be found');
		System.assert(String.isNotBlank(title), 'The page title must still build with no event');
		System.assert(String.isNotBlank(metaTitle), 'The meta title must still build with no event');
		System.assertNotEquals(null, timeZoneText, 'The time zone text must not be null');
	}

	/** Set the page before testSetup, because the Summit cookie is written onto the current page. */
	private static System.PageReference registrationPage() {
		System.PageReference currentPage = new System.PageReference(
			'/' + SPSummitEventConst.EVENT_REGISTRATION_NAME
		);
		Test.setCurrentPage(currentPage);
		return currentPage;
	}

	private static summit__Summit_Events_Instance__c insertSecondInstance() {
		summit__Summit_Events_Instance__c existing = [
			SELECT
				summit__Event__c,
				summit__Instance_Start_Time__c,
				summit__Instance_End_Time__c,
				summit__Instance_Time_Zone__c,
				summit__Active_Status__c
			FROM summit__Summit_Events_Instance__c
			LIMIT 1
		];
		summit__Summit_Events_Instance__c pageInstance = existing.clone(false, true);
		pageInstance.summit__Instance_Title__c = 'Page Event Session';
		pageInstance.summit__Instance_Start_Date__c = Date.today().addDays(30);
		pageInstance.summit__Instance_End_Date__c = Date.today().addDays(30);
		insert pageInstance;
		return pageInstance;
	}

	private static void setMock() {
		String responseBody =
			'{"messages":[],' +
			'"fbtrace_id":"AGOE6VduIDaY36PWKGp6jnb",' +
			'"events_received":1,' +
			'"error":null' +
			'}';
		Test.setMock(
			HttpCalloutMock.class,
			new SPHttpCalloutMock(
				200,
				responseBody,
				'Ok',
				new Map<String, String>()
			)
		);
	}
}