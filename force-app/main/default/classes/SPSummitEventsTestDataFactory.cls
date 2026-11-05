/**
 * @File Name          : SPSummitEventsTestDataFactory.cls
 * @Description        :
 * @Author             : aniubo
 * @Group              :
 * @Last Modified By   : aniubo
 * @Last Modified On   : 6/23/2023, 4:29:37 PM
 * @Modification Log   :
 *==============================================================================
 * Ver         Date                     Author      		      Modification
 *==============================================================================
 * 1.0    6/6/2023, 9:25:36 AM   aniubo     Initial Version
 **/
@IsTest
public inherited sharing class SPSummitEventsTestDataFactory {
	public static void createEventAndInstance(SPDataInitManager initManager) {
		checkSeaCustomSettings();
		SPAccountTestDataFactory.createAccount(
			initManager,
			SPTestDataKeys.ACCOUNT
		);
		SPPlanTestDataFactory.createPlan(
			initManager,
			SPTestDataKeys.PLAN,
			SPSummitEventConst.PLAN_RECRUITMENT_RT
		);
		createEventAllocation(initManager, SPTestDataKeys.FEE_ALLOCATION);
		createEvent(initManager);
		createEventInstance(initManager);
	}

	public static void checkSeaCustomSettings() {
		summit__Summit_Events_Settings__c SummitEventsSettings = summit__Summit_Events_Settings__c.getOrgDefaults();
		if (
			String.isBlank(
				SummitEventsSettings.summit__Cookie_Encryption_Key__c
			)
		) {
			Blob cryptoKey = Crypto.generateAesKey(256);
			String encryptionString = EncodingUtil.base64Encode(cryptoKey)
				.substring(0, 32);
			SummitEventsSettings.summit__Cookie_Encryption_Key__c = encryptionString;
			upsert SummitEventsSettings;
		}
	}

	public static void createEvent(
		SPDataInitManager initManager,
		String objKey
	) {
		SPDataInitProxy initProxy = initManager.getProxy(
			objKey,
			Schema.SObjectType.summit__Summit_Events__c
		);
		summit__Summit_Events__c event = new summit__Summit_Events__c();
		// The Event Created - Create Campaign flow only runs when Campaign__c is blank, and it fails in test context.
		Campaign eventCampaign = new Campaign(Name = 'Test Event Campaign');
		insert eventCampaign;
		//Create event
		event = new summit__Summit_Events__c(
			Campaign__c = eventCampaign.Id,
			Name = 'Test Event',
			summit__Event_description__c = 'Description',
			summit__Event_Status__c = SPSummitEventConst.ACTIVE_STATUS,
			summit__Event_Name__c = 'Test Event',
			summit__Start_Date__c = Date.today().addDays(-20),
			summit__End_Date__c = Date.today().addDays(20),
			summit__Template__c = 'SP_RsvpTemplate',
			summit__Close_Event_Days_Before__c = 0,
			summit__Location_Title__c = 'A location',
			summit__Location_Map_Link__c = 'Map Link 1',
			summit__Location_Address__c = '123 Electric Ave.',
			summit__Location_Type__c = SPSummitEventConst.LOCATION_TYPE_ONLINE,
			summit__Allow_Other_Attendees__c = true,
			summit__Max_Other_Attendees__c = 10,
			Template_Disclaimer_Text__c = 'Disclaimer',
			Template_Banner_Image__c = 'http://banner.com',
			Template_Logo_Image__c = 'http://logo.com',
			Register_Button_Text__c = 'Button_Label',
			Category__c = 'General Recruitment' ,
			summit__Event_Type__c = 'Graduate recruitment',
			RecordTypeId = initManager.getRecordTypeId( summit__Summit_Events__c.SObjectType.getDescribe() , 'Chapman_Events' ), 
			Accounting_Department__c = initManager.getObjectId(
				SPTestDataKeys.ACCOUNTING_DEPARTMENT,
				false
			),
			summit__Payment_Gateway__c = 'SP_SummitEventsPayment',
			Default_Plan__c = initManager.getObjectId(
				SPTestDataKeys.PLAN,
				true
			),
			summit__Event_Fee_Allocation__c = initManager.getObjectId(
				SPTestDataKeys.FEE_ALLOCATION,
				true
			),
			summit__Event_Fee__c = 100
		);
		initProxy.insertObj(event);
	}

	public static void createEvent(SPDataInitManager initManager) {
		createEvent(initManager, SPTestDataKeys.EVENT);
	}

	public static void createEventInstance(
		SPDataInitManager initManager,
		String objKey
	) {
		SPDataInitProxy initProxy = initManager.getProxy(
			objKey,
			Schema.SObjectType.summit__Summit_Events_Instance__c
		);
		summit__Summit_Events_Instance__c seaInstance = new summit__Summit_Events_Instance__c();
		seaInstance.summit__Event__c = initManager.getObjectId(
			SPTestDataKeys.EVENT,
			true
		);
		seaInstance.summit__Instance_Title__c = 'Test Event Session';
		seaInstance.summit__Instance_Start_Date__c = Date.today();
		seaInstance.summit__Instance_Start_Time__c = Time.newInstance(
			8,
			0,
			0,
			0
		);
		seaInstance.summit__Instance_End_Date__c = Date.today();
		seaInstance.summit__Instance_End_Time__c = Time.newInstance(
			14,
			0,
			0,
			0
		);
		seaInstance.summit__Instance_Time_Zone__c = 'Central Daylight Time (America/Chicago)';
		seaInstance.summit__Active_Status__c = SPSummitEventConst.ACTIVE_STATUS;
		seaInstance.summit__Capacity__c = 100;
		seaInstance.summit__Location_Type_Override__c = SPSummitEventConst.LOCATION_TYPE_ONLINE;
		seaInstance.summit__Location_Title_Override__c = 'Override Title';
		seaInstance.summit__Virtual_Meeting_Link__c = 'http://virtual-link.com';
		seaInstance.Instance_Description__c = 'Test Instance Description'; //MB 2.0
		initProxy.insertObj(seaInstance);
	}

	public static void createEventInstance(SPDataInitManager initManager) {
		createEventInstance(initManager, SPTestDataKeys.EVENT_INSTANCE);
	}

	public static void createEventRegistration(
		SPDataInitManager initManager,
		String objKey
	) {
		SPDataInitProxy initProxy = initManager.getProxy(
			objKey,
			Schema.SObjectType.summit__Summit_Events_Registration__c
		);
		Id eventId = initManager.getObjectId(SPTestDataKeys.EVENT, true);
		Id eventInstanceId = initManager.getObjectId(
			SPTestDataKeys.EVENT_INSTANCE,
			true
		);
		summit__Summit_Events_Registration__c testRegistration = new summit__Summit_Events_Registration__c(
			summit__Event__c = eventId,
			summit__Event_Instance__c = eventInstanceId,
			summit__Registrant_Email__c = 'test@valleyhill.net',
			summit__Registrant_First_Name__c = 'TestFirst',
			summit__Registrant_Last_Name__c = 'TestLast',
			summit__Registrant_Zip__c = '55418',
			summit__Registrant_Postal_Code__c = '55418',
			summit__Registrant_Street_1__c = '123 Electric Ave',
			summit__Registrant_Street_2__c = 'Apartment C',
			summit__Registrant_City__c = 'Beach City',
			summit__Registrant_State__c = 'MN',
			summit__Registrant_High_School_Code__c = '000000',
			summit__Registrant_Date_of_Birth__c = Date.valueOf('1971-03-22'),
			summit__Preferred_Class_Year__c = '2012',
			summit__Status__c = 'Started',
			summit__Registrant_Third_Party_Status__c = 'Primary Registrant'
		);

		initProxy.insertObj(testRegistration);
	}

	public static void createEventRegistration(SPDataInitManager initManager) {
		createEventRegistration(initManager, SPTestDataKeys.EVENT_REGISTRATION);
	}

	public static void createEventAllocation(
		SPDataInitManager initManager,
		String objKey
	) {
		SPDataInitProxy initProxy = initManager.getProxy(
			objKey,
			Schema.SObjectType.summit__Summit_Events_Fee_Allocation__c
		);
		summit__Summit_Events_Fee_Allocation__c allocation = new summit__Summit_Events_Fee_Allocation__c(
			Name = 'Fee Allocation'
		);
		initProxy.insertObj(allocation);
	}

	public static void createEventFee(
		SPDataInitManager initManager,
		String objKey
	) {
		SPDataInitProxy initProxy = initManager.getProxy(
			objKey,
			Schema.SObjectType.summit__Summit_Events_Fee__c
		);
		summit__Summit_Events_Fee__c fee = new summit__Summit_Events_Fee__c(
			summit__Event_Fee__c = 100,
			summit__Event_Fee_Type__c = 'Event',
			summit__Summit_Events_Payment__c = initManager.getObjectId(
				SPTestDataKeys.EVENT_PAYMENT,
				false
			),
			summit__Event_Registration__c = initManager.getObjectId(
				SPTestDataKeys.EVENT_REGISTRATION,
				true
			),
			summit__Event_Fee_Allocation__c = initManager.getObjectId(
				SPTestDataKeys.FEE_ALLOCATION,
				false
			)
		);
		initProxy.insertObj(fee);
	}

	public static void createEventPayment(
		SPDataInitManager initManager,
		String objKey
	) {
		SPDataInitProxy initProxy = initManager.getProxy(
			objKey,
			Schema.SObjectType.summit__Summit_Events_Payment__c
		);
		summit__Summit_Events_Payment__c paymentInformation = new summit__Summit_Events_Payment__c(
			summit__Gateway_Session_Identifier__c = 'Gateway_Response',
			summit__Phone__c = '123456789',
			summit__Payment_Method__c = 'Card',
			summit__Name_On_Account__c = 'John Doe',
			summit__Address_1__c = 'street',
			summit__City__c = 'city',
			summit__Country__c = 'US',
			summit__Email_Address__c = 'johnDoe@email.com',
			summit__State__c = 'state',
			summit__Zip__c = 'zip',
			summit__Card_Type__c = 'Visa',
			summit__Payment_Amount__c = 100,
			summit__TouchnetReceiptNumber__c = 'transactionId',
			summit__GatewayApprovalCode__c = 'cyberResponse',
			summit__Event_Registration__c = initManager.getObjectId(
				SPTestDataKeys.EVENT_REGISTRATION,
				true
			),
			summit__Method_of_Payment__c = 'Credit Card',
			summit__Payment_Status__c = 'Received',
			summit__Payment_Received_Date__c = DateTime.now()
		);
		initProxy.insertObj(paymentInformation);
	}

	public static void createCookie(
		SPDataInitManager initManager,
		String instanceObjKey,
		String eventObjKey,
		String registrationObjKey
	) {
		Id registrationId = initManager.getObjectId(registrationObjKey, false);
		// create cookie;
		String encryptedString = SPSummitEventsUtils.createEncryptedCookie(
			'test_audience',
			initManager.getObjectId(instanceObjKey, true),
			initManager.getObjectId(eventObjKey, true),
			registrationId
		);

		if (String.isNotBlank(registrationId)) {
			summit__Summit_Events_Registration__c registration = new summit__Summit_Events_Registration__c(
				Id = registrationId
			);
			if (encryptedString.length() > 255) {
				registration.summit__Encrypted_Registration_Id_1__c = encryptedString.substring(
					0,
					255
				);
				registration.summit__Encrypted_Registration_Id_2__c = encryptedString.substring(
					255,
					encryptedString.length()
				);
			} else {
				registration.summit__Encrypted_Registration_Id_1__c = encryptedString;
			}
			//update registration;
		}
	}

	public static void createCookie(SPDataInitManager initManager) {
		createCookie(
			initManager,
			SPTestDataKeys.EVENT_INSTANCE,
			SPTestDataKeys.EVENT,
			SPTestDataKeys.EVENT_REGISTRATION
		);
	}
}