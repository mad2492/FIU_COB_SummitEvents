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
 * 2.2    11/7/2026                mdennis    Tests for confirmationReceipt
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

	@isTest
	private static void testConfirmationReceiptListsRegistrationAndPayment() {
		System.PageReference currentPage = confirmationPage();
		testSetup();
		insertReceivedPayment(1234.5);

		Test.startTest();
		SPRsvpTemplateService service = new SPRsvpTemplateService(currentPage);
		String receiptJson = service.confirmationReceipt;
		Test.stopTest();

		summit__Summit_Events_Registration__c registration = [SELECT Name FROM summit__Summit_Events_Registration__c LIMIT 1];
		Map<String, Object> receipt = (Map<String, Object>) JSON.deserializeUntyped(receiptJson);
		System.assertEquals(registration.Name, receipt.get('registrationNumber'), 'The receipt must carry the EVR number');
		System.assertEquals('TestFirst TestLast', receipt.get('registrantName'), 'The receipt must name the registrant');
		List<Object> payments = (List<Object>) receipt.get('payments');
		System.assertEquals(1, payments.size(), 'The received payment must be listed');
		Map<String, Object> payment = (Map<String, Object>) payments[0];
		System.assertEquals('7940682228906416303812', payment.get('transactionId'), 'The CyberSource transaction ID must be listed');
		System.assertEquals('$1,234.50', payment.get('amount'), 'The amount must be formatted as currency');
		System.assertEquals('Visa', payment.get('cardType'), 'The card type must be listed');
		System.assert(String.isNotBlank((String) payment.get('paidOn')), 'The payment date must be listed');
	}

	@isTest
	private static void testConfirmationReceiptBlankOffConfirmationPage() {
		System.PageReference currentPage = registrationPage();
		testSetup();
		insertReceivedPayment(10);

		Test.startTest();
		SPRsvpTemplateService service = new SPRsvpTemplateService(currentPage);
		Test.stopTest();

		System.assertEquals('', service.confirmationReceipt, 'Only the confirmation page may show receipt details');
	}

	@isTest
	private static void testConfirmationReceiptBlankForAnotherEvent() {
		System.PageReference currentPage = confirmationPage();
		testSetup();
		insertReceivedPayment(10);
		summit__Summit_Events_Instance__c otherInstance = insertSecondInstance();
		currentPage.getParameters().put('instanceID', otherInstance.Id);

		Test.startTest();
		SPRsvpTemplateService service = new SPRsvpTemplateService(currentPage);
		Test.stopTest();

		System.assertEquals(
			'',
			service.confirmationReceipt,
			'A registration from another event in the cookie must not appear on this event\'s confirmation'
		);
	}

	@isTest
	private static void testConfirmationWordInQueryStringDoesNotCount() {
		System.PageReference currentPage = registrationPage();
		testSetup();
		insertReceivedPayment(10);
		currentPage.getParameters().put('next', 'summiteventsconfirmation');

		Test.startTest();
		SPRsvpTemplateService service = new SPRsvpTemplateService(currentPage);
		Test.stopTest();

		System.assertEquals('', service.confirmationReceipt, 'Only the confirmation page itself may show receipt details');
	}

	@isTest
	private static void testConfirmationReceiptSkipsPaymentsNotReceived() {
		System.PageReference currentPage = confirmationPage();
		testSetup();
		insertReceivedPayment(10);
		summit__Summit_Events_Payment__c refunded = [SELECT Id FROM summit__Summit_Events_Payment__c LIMIT 1];
		refunded.summit__Payment_Status__c = 'Refund';
		update refunded;

		Test.startTest();
		SPRsvpTemplateService service = new SPRsvpTemplateService(currentPage);
		Map<String, Object> receipt = (Map<String, Object>) JSON.deserializeUntyped(service.confirmationReceipt);
		Test.stopTest();

		System.assertEquals(0, ((List<Object>) receipt.get('payments')).size(), 'Only received payments belong on the receipt');
		System.assert(String.isNotBlank((String) receipt.get('registrationNumber')), 'The EVR number still shows');
	}

	@isTest
	private static void testFormatCurrency() {
		System.assertEquals('$1.00', SPRsvpTemplateService.formatCurrency(1), 'Whole dollars');
		System.assertEquals('$1,234,567.89', SPRsvpTemplateService.formatCurrency(1234567.891), 'Grouping and rounding');
		System.assertEquals('$500.00', SPRsvpTemplateService.formatCurrency(500), 'No grouping under a thousand');
		System.assertEquals(null, SPRsvpTemplateService.formatCurrency(null), 'Null stays null');
	}

	private static System.PageReference confirmationPage() {
		System.PageReference currentPage = new System.PageReference('/apex/summit__SummitEventsConfirmation');
		Test.setCurrentPage(currentPage);
		return currentPage;
	}

	private static void insertReceivedPayment(Decimal amount) {
		summit__Summit_Events_Registration__c registration = [SELECT Id FROM summit__Summit_Events_Registration__c LIMIT 1];
		insert new summit__Summit_Events_Payment__c(
			summit__Event_Registration__c = registration.Id,
			summit__Payment_Amount__c = amount,
			summit__Payment_Status__c = 'Received',
			summit__Payment_Received_Date__c = DateTime.now(),
			summit__TouchnetReceiptNumber__c = '7940682228906416303812',
			summit__Card_Type__c = 'Visa',
			summit__Name_On_Account__c = 'TestFirst TestLast',
			summit__Method_of_Payment__c = 'Credit Card'
		);
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