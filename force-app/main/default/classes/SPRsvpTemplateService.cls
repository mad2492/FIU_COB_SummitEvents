/**
 * @File Name          : SPRsvpTemplateService.cls
 * @Description        :
 * @Author             : aniubo
 * @Group              :
 * @Modification Log   :
 *==============================================================================
 * Ver         Date                     Author      		      Modification
 *==============================================================================
 * 1.0    6/14/2023, 10:47:08 PM   aniubo     Initial Version
 * 2.0	  8/16/2023, 04:05:00 PM   mdennis    Several new funcs for OGI Template
 * 2.1	 11/13/2023, 12:05:00 PM   mdennis    Remove Daylight/Standard from TZs
 * 2.2	  7/26/2024, 02:30:00 PM   mdennis    Added htmlTitle and modified metaTitle to include Date/Time
 * 2.3	  11/4/2026                mdennis    Banner uses the page's instanceID before the Summit cookie;
 *                                            missing event data no longer crashes the page
 * 2.4	  11/7/2026                mdennis    confirmationReceipt: EVR number, registrant and received payments
 *                                            for the confirmation page's receipt
 **/
public inherited sharing class SPRsvpTemplateService extends SPSummitEventBaseService {
	private static final String INSTANCE_ID_PARAM = 'instanceID';

	/**
	 * Uses the event named in the page address first. The Summit cookie can still hold the
	 * previous event, so someone browsing between events would otherwise see its banner.
	 * Pages without a usable instanceID, such as later form steps, keep using the cookie.
	 */
	protected override void initialize() {
		Id requestedInstanceId = toId(this.currentPage?.getParameters().get(INSTANCE_ID_PARAM));
		if (requestedInstanceId != null) {
			this.instance = SPSummitEventsRepo.getEventInstance(requestedInstanceId);
		}
		Id cookieInstanceId = toId(this.info?.instanceId);
		if (this.instance == null && cookieInstanceId != null) {
			this.instance = SPSummitEventsRepo.getEventInstance(cookieInstanceId);
		}
	}

	/** Stops the page so the site error page can say what is missing, instead of a blank or partial page. */
	public class EventSetupException extends Exception {
	}

	/**
	 * Plain-language names of the setup a registration page cannot load without.
	 * Shared with the site error page, which shows this list to explain the failure.
	 */
	public static List<String> findMissingSetup(summit__Summit_Events_Instance__c eventInstance) {
		List<String> missing = new List<String>();
		if (eventInstance == null) {
			return missing;
		}
		if (String.isBlank(eventInstance.summit__Event__r?.summit__Account__r?.Name)) {
			missing.add('Account (on the event)');
		}
		if (eventInstance.summit__Instance_Start_Date__c == null) {
			missing.add('Start date (on the instance)');
		}
		if (eventInstance.summit__Instance_Start_Time__c == null) {
			missing.add('Start time (on the instance)');
		}
		if (String.isBlank(eventInstance.summit__Instance_Time_Zone__c)) {
			missing.add('Time zone (on the instance)');
		}
		return missing;
	}

	/** The instance query rejects malformed Ids, and both of these values can be malformed. */
	private static Id toId(String value) {
		if (String.isBlank(value)) {
			return null;
		}
		try {
			return Id.valueOf(value);
		} catch (StringException invalidId) {
			return null;
		}
	}

	public String backgroundImageUrl {
		//MB: 20 - added Instance-level Banner override.
		get {
			return String.isBlank(
					this.instance?.summit__Event__r?.Template_Banner_Image__c
				)
				? 
				 (
					String.isBlank(
						this.instance?.Template_Logo_Override__c
				) ? 'https://business.fiu.edu/faculty-and-research/centers-institutes/images/center-institutes.jpg'
				: this.instance?.Template_Logo_Override__c
				 )
				
				
				
				: this.instance.summit__Event__r.Template_Banner_Image__c;
		}
	}
	public String logoImageUrl {
		get {
			return String.isBlank(
					this.instance?.summit__Event__r?.Template_Logo_Image__c
				)
				? 'https://business.fiu.edu/_assets/images/fiu-business-logo-text.svg'
				: this.instance.summit__Event__r.Template_Logo_Image__c;
		}
	}

	public String eventDescription {
		get {
			return this.instance?.summit__Instance_Title__c;
		}
	}

/*MB: 2.0 begin */
 
public String eventParentDescription {
	get {
		return this.instance?.summit__Event__r.summit__Event_Name__c;
	}
}

public String eventInstanceDescription {
	get {
		return this.instance?.Instance_Description__c;
	} 
}

/*MB: 2.0 end */
	public String startEventWeekDay { get; private set; }

	public String startEventMonthDay { get; private set; }

	public String startEventYear { get; private set; }

	public String startEventTime { get; private set; }
//Added End Times
	public Boolean displayEndDate  { get; private set; }

	public String endEventWeekDay { get; private set; }

	public String endEventMonthDay { get; private set; }

	public String endEventTime { get; private set; }

	public String endEventYear { get; private set; }

	public String disclaimerText {
		get {
			return this.instance?.summit__Event__r?.Template_Disclaimer_Text__c;
		}
	}
	public String registerButtonLabel {
		get {
			return this.instance?.summit__Event__r?.Register_Button_Text__c;
		}
	}
	public String meetUrl {
		get {
			return this.instance?.summit__Virtual_Meeting_Link__c;
		}
	}

	public Boolean onlineEvent {
		get {
			String locationType = this.instance
				?.summit__Event__r
				?.summit__Location_Title__c;
			if (
				String.isNotBlank(
					this.instance?.summit__Location_Type_Override__c
				)
			) {
				locationType = this.instance?.summit__Location_Type_Override__c;
			}
			return String.isNotBlank(locationType) &&
				locationType == SPSummitEventConst.ONLINE_TYPE;
		}
	}
	public String calendarUrl {
		get {
			return 'summit__SummitEventsAddToCalendar?instanceID=' +
				this.instance?.Id;
		}
	}

	public String metaTitle {
		get {
			 
			String mTitle = '';
			
		 if (String.isNotBlank(instance?.summit__Instance_Title__c) && instance?.summit__Instance_Title__c <> instance?.summit__Event__r.summit__Event_Name__c ) {
				mTitle  = instance?.summit__Instance_Title__c;
			}else {
				mTitle = instance?.summit__Event__r.summit__Event_Name__c;
			}

			//MB 2.2 - adding startdate time to Meta tag.
			 return mTitle + ' - ' + this.startEventWeekDay + ', ' + this.startEventMonthDay + ' ' + startEventYear+ ' '  + this.startEventTime + ' ' + this.tz;  
			
			 
			
		}
	}

	//MB 2.2 - Customize the <title> tag for FIU needs
	public String htmlTitle {
		get {
			List<String> missingSetup = findMissingSetup(this.instance);
			if (!missingSetup.isEmpty()) {
				throw new EventSetupException('Event setup is missing: ' + String.join(missingSetup, ', '));
			}

			String mTitle = (String.isNotBlank(instance?.summit__Instance_Title__c) ? instance?.summit__Instance_Title__c : instance?.summit__Event__r?.summit__Event_Name__c) ;
			String accountName = instance?.summit__Event__r?.summit__Account__r?.Name;
			String businessUnit = accountName;
			if (String.isNotBlank(accountName)) {
				businessUnit = accountName.contains('Chapman') ? 'Graduate' : (accountName.contains('Executive') ? 'Executive Education' : accountName);
			}
			String category = instance?.summit__Event__r?.Category__c;
			String pageType = ApexPages.currentPage().getUrl().toLowerCase(); //(ApexPages.currentPage().getUrl().toLowerCase().substringBetween('apex/', '?')).substringAfter('summit__summitevents') ;
			Date startDate = instance?.summit__Instance_Start_Date__c;
		//summit__SummitEventsConfirmation
			pageType = (pageType.contains('register') ? 'Registration' : (pageType.contains('confirm') ?  'Confirmation' : pageType   ) ) ;

			// Leave out any part that is not filled in, so missing event data cannot crash the page.
			List<String> titleParts = new List<String>();
			if (String.isNotBlank(mTitle)) {
				titleParts.add(mTitle);
			}
			if (String.isNotBlank(category) && (String.isBlank(mTitle) || !mTitle.contains(category))) {
				titleParts.add(category);
			}
			if (startDate != null) {
				titleParts.add(startDate.month() + '/' + startDate.day() + '/' + startDate.year());
			}
			if (String.isNotBlank(businessUnit)) {
				titleParts.add(businessUnit);
			}
			titleParts.add(pageType);
			return String.join(titleParts, ' - ');

		}
	}

	public String userAgent {
		get {
			return this.currentPage.getHeaders()
				.get(SPSummitEventConst.USER_AGENT);
		}
	}

	public String fbp {
		get {
			return getCookie(SPSummitEventConst.FBP_COOKIE);
		}
	}

	public String fbc {
		get {
			return getCookie(SPSummitEventConst.FBC_COOKIE);
		}
	}

	public String clientIp {
		get {
			String ipAddress = this.currentPage
				.getHeaders()
				.get(SPSummitEventConst.TRUE_CLIENT_IP);
			if (String.isBlank(ipAddress)) {
				ipAddress = this.currentPage.getHeaders()
					.get(SPSummitEventConst.X_SALES_SIP);
			}
			if (String.isBlank(ipAddress)) {
				ipAddress = this.currentPage.getHeaders()
					.get(SPSummitEventConst.X_FORWARDED_FOR);
			}
			return ipAddress;
		}
	}

	public String registrationId {
		get {
			return this.info.registrationId;
		}
	}

	private static final String RECEIPT_TIME_ZONE = 'America/New_York';
	private String confirmationReceiptValue;

	/**
	 * Receipt details for the confirmation page, as JSON read by FIU_Confirmation_Fallback: the EVR registration
	 * number (the invoice number in CyberSource), the registrant, and each received payment with its CyberSource
	 * transaction ID, date, amount, card type and name on card. Blank on every other page.
	 *
	 * The registration comes only from the visitor's Summit cookie, which Summit encrypts, so a visitor cannot ask
	 * for someone else's receipt. It must also belong to the event in the page address, so a cookie left from
	 * another event never shows here. ReceiptQueries reads without sharing because the site guest user cannot see
	 * registrations or payments under sharing; it returns only the fields listed below.
	 */
	public String confirmationReceipt {
		get {
			if (confirmationReceiptValue == null) {
				confirmationReceiptValue = buildConfirmationReceipt();
			}
			return confirmationReceiptValue;
		}
	}

	private String buildConfirmationReceipt() {
		// The page name itself, without the query string, so "?anything=confirmation" on another page does not count.
		String pagePath = this.currentPage?.getUrl()?.substringBefore('?');
		Id cookieRegistrationId = toId(this.info?.registrationId);
		if (
			String.isBlank(pagePath) ||
			!pagePath.toLowerCase().endsWith('summiteventsconfirmation') ||
			cookieRegistrationId == null
		) {
			return '';
		}
		ReceiptQueries queries = new ReceiptQueries();
		summit__Summit_Events_Registration__c registration = queries.registration(cookieRegistrationId);
		if (registration == null || this.instance == null || registration.summit__Event_Instance__c != this.instance.Id) {
			return '';
		}

		List<Map<String, Object>> payments = new List<Map<String, Object>>();
		for (summit__Summit_Events_Payment__c payment : queries.receivedPayments(cookieRegistrationId)) {
			payments.add(
				new Map<String, Object>{
					'transactionId' => payment.summit__TouchnetReceiptNumber__c,
					'paidOn' => payment.summit__Payment_Received_Date__c?.format('MMMM d, yyyy, h:mm a z', RECEIPT_TIME_ZONE),
					'amount' => formatCurrency(payment.summit__Payment_Amount__c),
					'cardType' => payment.summit__Card_Type__c,
					'nameOnCard' => payment.summit__Name_On_Account__c
				}
			);
		}

		List<String> nameParts = new List<String>();
		for (String part : new List<String>{ registration.summit__Registrant_First_Name__c, registration.summit__Registrant_Last_Name__c }) {
			if (String.isNotBlank(part)) {
				nameParts.add(part.trim());
			}
		}
		return JSON.serialize(
			new Map<String, Object>{
				'registrationNumber' => registration.Name,
				'registrantName' => String.join(nameParts, ' '),
				'registrantEmail' => registration.summit__Registrant_Email__c,
				'payments' => payments
			}
		);
	}

	/** "$1,234.50". Returns null for a null amount. */
	@TestVisible
	private static String formatCurrency(Decimal amount) {
		if (amount == null) {
			return null;
		}
		String digits = String.valueOf(amount.abs().setScale(2));
		String whole = digits.substringBefore('.');
		String grouped = '';
		while (whole.length() > 3) {
			grouped = ',' + whole.right(3) + grouped;
			whole = whole.left(whole.length() - 3);
		}
		return (amount < 0 ? '-' : '') + '$' + whole + grouped + '.' + digits.substringAfter('.');
	}

	private without sharing class ReceiptQueries {
		summit__Summit_Events_Registration__c registration(Id registrationId) {
			List<summit__Summit_Events_Registration__c> registrations = [
				SELECT
					Name,
					summit__Event_Instance__c,
					summit__Registrant_First_Name__c,
					summit__Registrant_Last_Name__c,
					summit__Registrant_Email__c
				FROM summit__Summit_Events_Registration__c
				WHERE Id = :registrationId
				LIMIT 1
			];
			return registrations.isEmpty() ? null : registrations[0];
		}

		List<summit__Summit_Events_Payment__c> receivedPayments(Id registrationId) {
			return [
				SELECT
					summit__TouchnetReceiptNumber__c,
					summit__Payment_Received_Date__c,
					summit__Payment_Amount__c,
					summit__Card_Type__c,
					summit__Name_On_Account__c
				FROM summit__Summit_Events_Payment__c
				WHERE summit__Event_Registration__c = :registrationId AND summit__Payment_Status__c = 'Received'
				ORDER BY summit__Payment_Received_Date__c
			];
		}
	}

	public String relativePath {
		get {
			return this.currentPage.getUrl();
		}
	}

	public String tz {
		//MB: 2.0: Split at ( to remove extra TZ info
		get {
			if (Test.isRunningTest()==true) return 'test';
			String timeZoneName = instance?.summit__Instance_Time_Zone__c;
			if (String.isBlank(timeZoneName)) return '';
			return timeZoneName.substringBefore('(').replaceAll('Daylight','').replaceAll('Standard','') ;}
	}

	private String fullUrl {
		get {
			String relativeUrl = this.currentPage.getUrl();
			return URL.getSalesforceBaseUrl().toExternalForm() +
				'/' +
				relativeUrl;
		}
	}

	public SPRsvpTemplateService(System.PageReference currentPage) {
		super(currentPage);
		this.buildStartEventInfo(
			this.instance?.summit__Instance_Start_Date__c,
			this.instance?.summit__Instance_Start_Time__c,
			this.instance?.summit__Instance_End_Date__c,
			this.instance?.summit__Instance_End_Time__c
		);
	}

	public void facebookVisitRegistrationPage() {
		if (
			this.fullUrl.containsIgnoreCase(
				SPSummitEventConst.REGISTER_PAGE_NAME
			)
		) {
			new SPFacebookConversionManager(
					SPSummitEventConst.EVENT_VIEW_NAME,
					this.fullUrl
				)
				.execute(
					new SPFacebookConversionManager.ConversionInputParam(
						this.fbp,
						this.fbc,
						this.UserAgent,
						this.clientIp,
						DateTime.now()
					)
				);
		}
	}

	private void buildStartEventInfo(Date startDate, Time startTime, Date endDate, Time endTime) {
		this.displayEndDate = false;

		if (startDate != null && startTime != null) {
			DateTime convertedStartDate = DateTime.newInstance(
				startDate,
				startTime
			);

			
			this.startEventMonthDay =
				convertedStartDate.format('MMMM') +
				' ' +
				convertedStartDate.format('dd');

			

			this.startEventYear = String.valueOf(startDate.year());
			this.startEventWeekDay = convertedStartDate.format('EEEE');

			this.startEventTime = SPSummitEventsUtils.formatTime(
				convertedStartDate.time(),
				false
			);

			//EndDateTime
		if (endDate != null && endTime != null) {

			
			DateTime convertedEndDate = DateTime.newInstance(
				endDate,
				endTime
				);
	
				this.displayEndDate = endDate > startDate ;
	
				
				this.endEventMonthDay =
				convertedEndDate.format('MMMM') +
					' ' +
					convertedEndDate.format('dd');
	
				
	
				this.endEventYear = String.valueOf(endDate.year());
				this.endEventWeekDay = convertedEndDate.format('EEEE');
	
				this.endEventTime = SPSummitEventsUtils.formatTime(
					convertedEndDate.time(),
					false
				);
		}


		}


		
	}
	 

	private String getCookie(String name) {
		String encryptedString = SPSummitEventsUtils.getSeaCookie(false, name);
		return String.isNotBlank(encryptedString)
			? EncodingUtil.urlDecode(encryptedString, 'UTF-8').escapeHtml4()
			: null;
	}
}