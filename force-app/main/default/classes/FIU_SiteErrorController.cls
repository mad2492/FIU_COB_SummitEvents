/**
 * Works out why a public event page failed, so FIU_Site_Error can say what is wrong in plain language.
 * Runs from the error page itself, so it must never throw: an error here would hide the original problem.
 **/
public without sharing class FIU_SiteErrorController {
	private static final String INSTANCE_ID_PARAM = 'instanceID';

	public String eventName { get; private set; }
	public List<String> missingSetup { get; private set; }
	public Boolean hasBadEventLink { get; private set; }

	public Boolean hasMissingSetup {
		get {
			return !this.missingSetup.isEmpty();
		}
	}

	public FIU_SiteErrorController() {
		this.missingSetup = new List<String>();
		this.hasBadEventLink = false;
		try {
			this.diagnose(findInstanceIdText());
		} catch (Exception unexpected) {
			System.debug(LoggingLevel.ERROR, 'FIU_Site_Error diagnosis failed: ' + unexpected.getMessage());
		}
	}

	@TestVisible
	private void diagnose(String instanceIdText) {
		if (String.isBlank(instanceIdText)) {
			return;
		}
		Id instanceId;
		try {
			instanceId = Id.valueOf(instanceIdText);
		} catch (StringException malformedId) {
			this.hasBadEventLink = true;
			return;
		}
		summit__Summit_Events_Instance__c eventInstance = SPSummitEventsRepo.getEventInstance(instanceId);
		if (eventInstance == null) {
			this.hasBadEventLink = true;
			return;
		}
		this.eventName = String.isNotBlank(eventInstance.summit__Instance_Title__c)
			? eventInstance.summit__Instance_Title__c
			: eventInstance.summit__Event__r?.summit__Event_Name__c;
		this.missingSetup = SPRsvpTemplateService.findMissingSetup(eventInstance);
	}

	private static String findInstanceIdText() {
		String fromPage = ApexPages.currentPage()?.getParameters().get(INSTANCE_ID_PARAM);
		if (String.isNotBlank(fromPage)) {
			return fromPage;
		}
		return readInstanceIdFromUrl(Site.getOriginalUrl());
	}

	@TestVisible
	private static String readInstanceIdFromUrl(String url) {
		if (String.isBlank(url) || !url.containsIgnoreCase(INSTANCE_ID_PARAM + '=')) {
			return null;
		}
		for (String pair : url.substringAfter('?').split('&')) {
			if (pair.startsWithIgnoreCase(INSTANCE_ID_PARAM + '=')) {
				return pair.substringAfter('=');
			}
		}
		return null;
	}
}
