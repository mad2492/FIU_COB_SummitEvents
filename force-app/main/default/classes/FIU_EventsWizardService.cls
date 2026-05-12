public with sharing class FIU_EventsWizardService {
    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class InitData {
        @AuraEnabled public String eventObjectApiName;
        @AuraEnabled public List<Option> recordTypeOptions;
        @AuraEnabled public List<Option> eventStatusOptions;
        @AuraEnabled public List<Option> paymentGatewayOptions;
        @AuraEnabled public List<Option> locationTypeOptions;
        @AuraEnabled public List<Option> templateOptions;
        @AuraEnabled public List<Option> categoryOptions;
        @AuraEnabled public List<Option> eventTypeOptions;
        @AuraEnabled public List<Option> filterCategoryOptions;
        @AuraEnabled public List<Option> accountingDepartmentOptions;
        @AuraEnabled public List<Option> registrationEmailRestrictionOptions;
        @AuraEnabled public List<Option> eventFeeAllocationOptions;
        @AuraEnabled public List<Option> eventFeeAdditionalAllocationOptions;
        @AuraEnabled public List<String> programFilterFields;
        @AuraEnabled public String defaultRecordTypeId;
        @AuraEnabled public String defaultEventStatus;
    }


    public class CreateRequest {
        @AuraEnabled public String workingEventId;
        @AuraEnabled public String draftEventId;
        @AuraEnabled public String eventName;
        @AuraEnabled public String recordTypeId;
        @AuraEnabled public String accountId;
        @AuraEnabled public String eventStatus;
        @AuraEnabled public Date eventStartDate;
        @AuraEnabled public Date eventEndDate;
        @AuraEnabled public Boolean includesMultiplePrograms;
        @AuraEnabled public String defaultPlanId;
        @AuraEnabled public Map<String, String> programFilterValues;
        @AuraEnabled public Boolean createOppsFromRegs;
        @AuraEnabled public Boolean sendRegistrationConfirmation;
        @AuraEnabled public String paymentGateway;
        @AuraEnabled public String accountingDepartmentId;
        @AuraEnabled public String templateId;
        @AuraEnabled public String category;
        @AuraEnabled public String eventType;
        @AuraEnabled public String locationType;
        @AuraEnabled public String locationTitle;
        @AuraEnabled public String locationAddress;
        @AuraEnabled public String locationMapLink;
        @AuraEnabled public String building;
        @AuraEnabled public Decimal capacity;
        @AuraEnabled public String filterCategory;
        @AuraEnabled public String businessUnitId;
        @AuraEnabled public List<String> selectedPlanIds;
        @AuraEnabled public Boolean createFirstInstance;
        @AuraEnabled public String confirmationTitle;
        @AuraEnabled public String confirmationDescription;
        @AuraEnabled public String landingDescription;
        @AuraEnabled public String landingFullText;
        @AuraEnabled public String landingShortListingDescription;
        @AuraEnabled public String customQuestionsTitle;
        @AuraEnabled public String customQuestionsDescription;
        @AuraEnabled public Boolean privateEvent;
        @AuraEnabled public String templateBannerImage;
        @AuraEnabled public String templateLogoImage;
        @AuraEnabled public String templateDisclaimerText;
        @AuraEnabled public String registerButtonText;
        @AuraEnabled public String eventHomeLinkTitle;
        @AuraEnabled public String eventHomeLinkUrl;
        @AuraEnabled public String feedRegistrationButtonText;
        @AuraEnabled public String registrationEmailRestriction;
        @AuraEnabled public Decimal eventFee;
        @AuraEnabled public Decimal eventFeeAdditional;
        @AuraEnabled public String eventFeeAllocationId;
        @AuraEnabled public String eventFeeAdditionalAllocationId;
        @AuraEnabled public String eventPaymentReceivedDescription;
        @AuraEnabled public String eventPaymentDueDescription;
        @AuraEnabled public String eventFeeLabel;
        @AuraEnabled public String eventFeeSubmitListLabel;
        @AuraEnabled public String eventPaymentReceivedHeadingLabel;
        @AuraEnabled public String eventFeesReceivedLabel;
        @AuraEnabled public String eventFeeTotalLabel;
        @AuraEnabled public String eventPaymentDueHeadingLabel;

        @AuraEnabled public String instanceTitle;
        @AuraEnabled public Datetime instanceStart;
        @AuraEnabled public Datetime instanceEnd;
        @AuraEnabled public Boolean instanceOpenRegistration;
        @AuraEnabled public String instanceActiveStatus;
        @AuraEnabled public Boolean isPreview;
    }

    public class ProgramOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String code;
    }

    public class ProgramSelectionResult {
        @AuraEnabled public String workingEventId;
        @AuraEnabled public String businessUnitId;
        @AuraEnabled public String defaultPlanId;
        @AuraEnabled public Boolean includesMultiplePrograms;
        @AuraEnabled public Map<String, String> programFilterValues;
    }

    private class ProgramSelectionComputed {
        String defaultPlanId;
        Boolean includesMultiple;
        Map<String, String> programFilters;
    }

    @AuraEnabled
    public static Id createDraftEvent(CreateRequest req) {
        return createWorkingEvent(req);
    }

    @AuraEnabled
    public static Id createWorkingEvent(CreateRequest req) {
        if (req == null) throw new AuraHandledException('Missing draft request.');
        String eventObject = FiuEventsAccessService.resolveEventObject();
        if (eventObject == null) throw new AuraHandledException('Event object could not be resolved.');
        Schema.SObjectType eventType = Schema.getGlobalDescribe().get(eventObject);
        Schema.DescribeSObjectResult eventDescribe = eventType.getDescribe();
        Map<String, Schema.SObjectField> eventFields = eventType.getDescribe().fields.getMap();

        String eventStatusField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Status__c', 'summit__Status__c' });
        String accountField = resolveOptionalField(eventFields, new List<String>{ 'summit__Account__c' });
        String createOppsField = resolveOptionalField(eventFields, new List<String>{ 'FIU_Create_Opps_From_Regs__c' });
        String sendEmailField = resolveOptionalField(eventFields, new List<String>{ 'Send_Registration_Confirmation_Email__c' });
        String includesMultipleField = resolveOptionalField(eventFields, new List<String>{ 'Includes_Multiple_Programs__c' });

        String draftName = String.isBlank(req.eventName) ? 'In Progress Event ' + Datetime.now().format('yyyy-MM-dd HH:mm') : req.eventName;
        String draftRecordTypeId = req.recordTypeId;
        if (String.isBlank(draftRecordTypeId)) {
            for (Schema.RecordTypeInfo rti : eventDescribe.getRecordTypeInfos()) {
                if (rti.isAvailable()) {
                    draftRecordTypeId = String.valueOf(rti.getRecordTypeId());
                    break;
                }
            }
        }

        SObject eventRecord = eventType.newSObject();
        eventRecord.put('Name', draftName);
        if (String.isNotBlank(draftRecordTypeId)) eventRecord.put('RecordTypeId', draftRecordTypeId);
        if (accountField != null && String.isNotBlank(req.accountId)) eventRecord.put(accountField, req.accountId);
        // Working record initialization should avoid org-specific restricted picklist failures.
        if (createOppsField != null) eventRecord.put(createOppsField, req.createOppsFromRegs == null ? false : req.createOppsFromRegs);
        if (sendEmailField != null) eventRecord.put(sendEmailField, req.sendRegistrationConfirmation == null ? false : req.sendRegistrationConfirmation);
        if (includesMultipleField != null) eventRecord.put(includesMultipleField, req.includesMultiplePrograms == true);
        insert eventRecord;
        return (Id) eventRecord.get('Id');
    }

    @AuraEnabled(cacheable=true)
    public static List<Option> getBusinessUnits() {
        List<Option> out = new List<Option>();
        List<RecordType> rt = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account' AND IsActive = true
            AND (DeveloperName = 'University_Department' OR Name = 'University Department')
            LIMIT 1
        ];
        if (rt.isEmpty()) return out;
        for (Account a : [SELECT Id, Name FROM Account WHERE RecordTypeId = :rt[0].Id ORDER BY Name LIMIT 5000]) {
            Option o = new Option();
            o.label = a.Name;
            o.value = a.Id;
            out.add(o);
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static List<ProgramOption> getProgramsForBusinessUnit(String businessUnitId) {
        List<ProgramOption> out = new List<ProgramOption>();
        if (String.isBlank(businessUnitId)) return out;
        for (Plan__c p : [
            SELECT Id, Name, Plan_Code__c
            FROM Plan__c
            WHERE Department__c = :businessUnitId AND Plan_Code__c != null
            ORDER BY Name
            LIMIT 5000
        ]) {
            ProgramOption o = new ProgramOption();
            o.label = p.Name + ' (' + p.Plan_Code__c + ')';
            o.value = p.Id;
            o.code = p.Plan_Code__c;
            out.add(o);
        }
        return out;
    }

    @AuraEnabled
    public static ProgramSelectionResult applyProgramSelection(String workingEventId, String businessUnitId, List<String> selectedPlanIds) {
        if (String.isBlank(workingEventId)) throw new AuraHandledException('Working Event context is required.');
        if (String.isBlank(businessUnitId)) throw new AuraHandledException('Business Unit is required.');
        String eventObject = FiuEventsAccessService.resolveEventObject();
        if (eventObject == null) throw new AuraHandledException('Event object could not be resolved.');
        Schema.SObjectType eventType = Schema.getGlobalDescribe().get(eventObject);
        Map<String, Schema.SObjectField> eventFields = eventType.getDescribe().fields.getMap();

        String accountField = resolveOptionalField(eventFields, new List<String>{ 'summit__Account__c' });
        String includesMultipleField = resolveOptionalField(eventFields, new List<String>{ 'Includes_Multiple_Programs__c' });
        String defaultPlanField = resolveOptionalField(eventFields, new List<String>{ 'Default_Plan__c' });
        if (accountField == null) throw new AuraHandledException('Account field is not available on Event.');

        List<String> planIds = selectedPlanIds == null ? new List<String>() : selectedPlanIds;
        Map<Id, Plan__c> planById = new Map<Id, Plan__c>();
        if (!planIds.isEmpty()) {
            for (Plan__c p : [SELECT Id, Plan_Code__c FROM Plan__c WHERE Id IN :planIds]) {
                planById.put(p.Id, p);
            }
        }

        List<String> planCodes = new List<String>();
        for (String pid : planIds) {
            Plan__c p = planById.get((Id) pid);
            if (p != null && String.isNotBlank(p.Plan_Code__c)) planCodes.add(p.Plan_Code__c.trim());
        }

        List<String> buckets = splitProgramCodes(planCodes);
        FiuProgramFilterService.ProgramFilterConfig programConfig = FiuProgramFilterService.getConfig();
        SObject eventRecord = eventType.newSObject((Id) workingEventId);
        eventRecord.put(accountField, businessUnitId);
        if (includesMultipleField != null) eventRecord.put(includesMultipleField, planIds.size() > 1);
        if (defaultPlanField != null) eventRecord.put(defaultPlanField, planIds.size() == 1 ? planIds[0] : null);
        for (Integer i = 0; i < programConfig.eventProgramFields.size(); i++) {
            String pf = programConfig.eventProgramFields[i];
            if (!eventFields.containsKey(pf)) continue;
            eventRecord.put(pf, i < buckets.size() ? buckets[i] : null);
        }
        update eventRecord;

        ProgramSelectionResult out = new ProgramSelectionResult();
        out.workingEventId = workingEventId;
        out.businessUnitId = businessUnitId;
        out.defaultPlanId = planIds.size() == 1 ? planIds[0] : null;
        out.includesMultiplePrograms = planIds.size() > 1;
        out.programFilterValues = new Map<String, String>();
        for (Integer i = 0; i < programConfig.eventProgramFields.size(); i++) {
            out.programFilterValues.put(programConfig.eventProgramFields[i], i < buckets.size() ? buckets[i] : null);
        }
        return out;
    }

    public class CreateResult {
        @AuraEnabled public Id eventId;
        @AuraEnabled public Id instanceId;
        @AuraEnabled public String eventName;
        @AuraEnabled public String instanceName;
        @AuraEnabled public String previewUrl;
    }

    @AuraEnabled(cacheable=true)
    public static InitData getInitData() {
        String eventObject = FiuEventsAccessService.resolveEventObject();
        if (eventObject == null) throw new AuraHandledException('Event object could not be resolved.');

        Schema.SObjectType eventType = Schema.getGlobalDescribe().get(eventObject);
        Schema.DescribeSObjectResult d = eventType.getDescribe();
        Map<String, Schema.SObjectField> eventFields = d.fields.getMap();

        InitData out = new InitData();
        out.eventObjectApiName = eventObject;
        out.recordTypeOptions = new List<Option>();
        out.eventStatusOptions = new List<Option>();
        out.paymentGatewayOptions = new List<Option>();
        out.locationTypeOptions = new List<Option>();
        out.templateOptions = new List<Option>();
        out.categoryOptions = new List<Option>();
        out.eventTypeOptions = new List<Option>();
        out.filterCategoryOptions = new List<Option>();
        out.accountingDepartmentOptions = new List<Option>();
        out.registrationEmailRestrictionOptions = new List<Option>();
        out.eventFeeAllocationOptions = new List<Option>();
        out.eventFeeAdditionalAllocationOptions = new List<Option>();
        out.programFilterFields = FiuProgramFilterService.getConfig().eventProgramFields;

        for (Schema.RecordTypeInfo rti : d.getRecordTypeInfos()) {
            if (!rti.isAvailable()) continue;
            Option o = new Option();
            o.label = rti.getName();
            o.value = String.valueOf(rti.getRecordTypeId());
            out.recordTypeOptions.add(o);
            if (out.defaultRecordTypeId == null) out.defaultRecordTypeId = o.value;
        }

        addPicklistOptions(eventFields, new List<String>{ 'summit__Event_Status__c', 'summit__Status__c' }, out.eventStatusOptions);
        addPicklistOptions(eventFields, new List<String>{ 'summit__Payment_Gateway__c' }, out.paymentGatewayOptions);
        addPicklistOptions(eventFields, new List<String>{ 'summit__Location_Type__c' }, out.locationTypeOptions);
        addFlexibleOptions(eventFields, new List<String>{ 'summit__Template__c' }, out.templateOptions);
        addPicklistOptions(eventFields, new List<String>{ 'summit__Event_Type__c' }, out.eventTypeOptions);
        addFlexibleOptions(eventFields, new List<String>{ 'Category__c' }, out.categoryOptions);
        addFlexibleOptions(eventFields, new List<String>{ 'summit__Filter_Category__c' }, out.filterCategoryOptions);
        addFlexibleOptions(eventFields, new List<String>{ 'Accounting_Department__c' }, out.accountingDepartmentOptions);
        addPicklistOptions(eventFields, new List<String>{ 'summit__Registration_Email_Restriction__c' }, out.registrationEmailRestrictionOptions);
        addFlexibleOptions(eventFields, new List<String>{ 'summit__Event_Fee_Allocation__c' }, out.eventFeeAllocationOptions);
        addFlexibleOptions(eventFields, new List<String>{ 'summit__Event_Fee_Additional_Allocation__c' }, out.eventFeeAdditionalAllocationOptions);

        out.defaultEventStatus = findDefaultStatus(out.eventStatusOptions);
        return out;
    }

    @AuraEnabled
    public static CreateResult createEventAndFirstInstance(CreateRequest req) {
        if (req == null) throw new AuraHandledException('Missing create request.');
        System.debug(LoggingLevel.WARN, 'FIU_CREATE_EVENT_ENTER req.recordTypeId=' + req.recordTypeId + ', req.workingEventId=' + req.workingEventId + ', req.draftEventId=' + req.draftEventId + ', req.isPreview=' + req.isPreview);

        String eventObject = FiuEventsAccessService.resolveEventObject();
        if (eventObject == null) throw new AuraHandledException('Event object could not be resolved.');

        Schema.SObjectType eventType = Schema.getGlobalDescribe().get(eventObject);
        Schema.DescribeSObjectResult eventDescribe = eventType.getDescribe();
        Map<String, Schema.SObjectField> eventFields = eventDescribe.fields.getMap();

        String eventStatusField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Status__c', 'summit__Status__c' });
        String accountField = resolveOptionalField(eventFields, new List<String>{ 'summit__Account__c' });
        String paymentGatewayField = resolveOptionalField(eventFields, new List<String>{ 'summit__Payment_Gateway__c' });
        String accountingDeptField = resolveOptionalField(eventFields, new List<String>{ 'Accounting_Department__c' });
        String createOppsField = resolveOptionalField(eventFields, new List<String>{ 'FIU_Create_Opps_From_Regs__c' });
        String sendEmailField = resolveOptionalField(eventFields, new List<String>{ 'Send_Registration_Confirmation_Email__c' });
        String includesMultipleField = resolveOptionalField(eventFields, new List<String>{ 'Includes_Multiple_Programs__c' });
        String defaultPlanField = resolveOptionalField(eventFields, new List<String>{ 'Default_Plan__c' });
        String templateField = resolveOptionalField(eventFields, new List<String>{ 'summit__Template__c' });
        String categoryField = resolveOptionalField(eventFields, new List<String>{ 'Category__c' });
        String eventTypeField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Type__c' });
        String locationTypeField = resolveOptionalField(eventFields, new List<String>{ 'summit__Location_Type__c' });
        String startDateField = resolveOptionalField(eventFields, new List<String>{ 'summit__Start_Date__c', 'Start_Date__c' });
        String endDateField = resolveOptionalField(eventFields, new List<String>{ 'summit__End_Date__c', 'End_Date__c' });
        String eventLabelField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Label__c', 'Event_Label__c' });
        String locationTitleField = resolveOptionalField(eventFields, new List<String>{ 'summit__Location_Title__c', 'Location_Title__c' });
        String locationAddressField = resolveOptionalField(eventFields, new List<String>{ 'summit__Location_Address__c', 'Location_Address__c' });
        String locationMapLinkField = resolveOptionalField(eventFields, new List<String>{ 'summit__Location_Map_Link__c', 'Location_Map_Link__c' });
        String buildingField = resolveOptionalField(eventFields, new List<String>{ 'summit__Building__c', 'Building__c' });
        String capacityField = resolveOptionalField(eventFields, new List<String>{ 'summit__Capacity__c', 'Capacity__c' });
        String privateEventField = resolveOptionalField(eventFields, new List<String>{ 'summit__Private_Event__c' });
        String filterCategoryField = resolveOptionalField(eventFields, new List<String>{ 'summit__Filter_Category__c' });
        String confirmationTitleField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Confirmation_Title__c' });
        String confirmationDescriptionField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Confirmation_Description__c' });
        String landingDescriptionField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_description__c' });
        String landingFullTextField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Full_Text__c' });
        String landingShortListingField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Short_Listing_Description__c' });
        String customQuestionsTitleField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Additional_Question_Title__c' });
        String customQuestionsDescriptionField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Additional_Questions_Description__c' });
        String templateBannerImageField = resolveOptionalField(eventFields, new List<String>{ 'Template_Banner_Image__c', 'summit__Template_Banner_Image__c' });
        String templateLogoImageField = resolveOptionalField(eventFields, new List<String>{ 'Template_Logo_Image__c', 'summit__Template_Logo_Image__c' });
        String templateDisclaimerField = resolveOptionalField(eventFields, new List<String>{ 'Template_Disclaimer_Text__c', 'summit__Template_Disclaimer_Text__c' });
        String registerButtonTextField = resolveOptionalField(eventFields, new List<String>{ 'Register_Button_Text__c', 'summit__Register_Button_Text__c' });
        String eventHomeLinkTitleField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Home_Link_Title__c' });
        String eventHomeLinkUrlField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Home_Link_URL__c' });
        String feedRegistrationButtonTextField = resolveOptionalField(eventFields, new List<String>{ 'summit__Feed_Registration_Button_Text__c' });
        String registrationEmailRestrictionField = resolveOptionalField(eventFields, new List<String>{ 'summit__Registration_Email_Restriction__c' });
        String eventFeeField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Fee__c' });
        String eventFeeAdditionalField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Fee_Additional__c' });
        String eventFeeAllocationField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Fee_Allocation__c' });
        String eventFeeAdditionalAllocationField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Fee_Additional_Allocation__c' });
        String eventPaymentReceivedDescriptionField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Payment_Received_Description__c' });
        String eventPaymentDueDescriptionField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Payment_Due_Description__c' });
        String eventFeeLabelField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Fee_Label__c' });
        String eventFeeSubmitListLabelField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Fee_Submit_List_Label__c' });
        String eventPaymentReceivedHeadingLabelField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Payment_Received_Heading_Label__c' });
        String eventFeesReceivedLabelField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Fees_Received_Label__c' });
        String eventFeeTotalLabelField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Fee_Total_Label__c' });
        String eventPaymentDueHeadingLabelField = resolveOptionalField(eventFields, new List<String>{ 'summit__Event_Payment_Due_Heading_Label__c' });
        String noMatchBehaviorField = resolveOptionalField(eventFields, new List<String>{ 'summit__Contact_Matching_No_Match_Behavior__c' });
        String multipleMatchBehaviorField = resolveOptionalField(eventFields, new List<String>{ 'summit__Contact_Matching_Multiple_Match_Behavior__c' });
        String previewField = FiuEventsAccessService.resolveEventPreviewField();
        String eventUrlField = FiuEventsAccessService.resolveEventUrlField();

        if (String.isBlank(req.eventName)) throw new AuraHandledException('Event name is required.');
        if (accountField == null) throw new AuraHandledException('Account field is not available on Event.');
        if (eventStatusField == null || String.isBlank(req.eventStatus)) throw new AuraHandledException('Event status is required.');
        if (templateField != null && String.isBlank(req.templateId)) throw new AuraHandledException('Template is required.');
        if (eventTypeField != null && String.isBlank(req.eventType)) throw new AuraHandledException('Event Type is required.');
        if (categoryField != null && String.isBlank(req.category)) throw new AuraHandledException('Category is required.');
        if (locationTypeField != null && String.isBlank(req.locationType)) throw new AuraHandledException('Location type is required.');
        if (capacityField != null && (req.capacity == null || req.capacity <= 0)) {
            throw new AuraHandledException('Capacity must be greater than 0 before this Event can be previewed or created.');
        }
        if (startDateField != null && req.eventStartDate == null) throw new AuraHandledException('Event Start Date is required.');
        if (endDateField != null && req.eventEndDate == null) throw new AuraHandledException('Event End Date is required.');
        if (startDateField != null && endDateField != null && req.eventStartDate != null && req.eventEndDate != null && req.eventEndDate < req.eventStartDate) {
            throw new AuraHandledException('Event End Date must be on or after Start Date.');
        }
        String locationTypeNormalized = req.locationType == null ? '' : req.locationType.trim().toLowerCase();
        Boolean requiresPhysicalLocation = locationTypeNormalized == 'on-site' || locationTypeNormalized == 'off-campus';
        Boolean isOnlineLocationType = locationTypeNormalized == 'online';
        if (requiresPhysicalLocation) {
            if (String.isBlank(req.locationTitle) || String.isBlank(req.locationAddress) || String.isBlank(req.locationMapLink) || String.isBlank(req.building)) {
                throw new AuraHandledException('Location Title, Location Address, Location Map Link, and Building are required for On-Site and Off-Campus events.');
            }
        }

        Boolean includesMultiple = req.includesMultiplePrograms == true;

        Boolean paidRegistration = req.paymentGateway != null && req.paymentGateway != 'No Gateway' && req.paymentGateway != '';
        if (paidRegistration && String.isBlank(req.accountingDepartmentId)) {
            throw new AuraHandledException('Accounting Department is required for paid events.');
        }

        Boolean createFirstInstance = req.createFirstInstance == true;
        if (req.isPreview == true) createFirstInstance = false;
        if (createFirstInstance && (req.instanceStart == null || req.instanceEnd == null)) {
            throw new AuraHandledException('Instance start and end date/time are required.');
        }

        String workingEventId = String.isNotBlank(req.workingEventId) ? req.workingEventId : req.draftEventId;
        SObject existingDraft;
        if (String.isNotBlank(workingEventId)) {
            String draftSoql = 'SELECT Id, RecordTypeId,' + accountField + ' FROM ' + eventObject + ' WHERE Id = :workingEventId LIMIT 1';
            existingDraft = Database.query(draftSoql);
        }
        if (String.isBlank(req.recordTypeId) && existingDraft != null) {
            Object existingRt = existingDraft.get('RecordTypeId');
            if (existingRt != null) req.recordTypeId = String.valueOf(existingRt);
        }
        System.debug(LoggingLevel.WARN, 'FIU_CREATE_EVENT_RESOLVE_RT afterExistingDraft req.recordTypeId=' + req.recordTypeId);
        if (String.isBlank(req.recordTypeId)) {
            for (Schema.RecordTypeInfo rti : eventDescribe.getRecordTypeInfos()) {
                if (rti.isAvailable()) {
                    req.recordTypeId = String.valueOf(rti.getRecordTypeId());
                    break;
                }
            }
        }
        System.debug(LoggingLevel.WARN, 'FIU_CREATE_EVENT_RESOLVE_RT final req.recordTypeId=' + req.recordTypeId);
        if (String.isBlank(req.recordTypeId)) throw new AuraHandledException('Record type is required.');
        String resolvedAccountId = String.isNotBlank(req.businessUnitId) ? req.businessUnitId : req.accountId;
        if (String.isBlank(resolvedAccountId) && existingDraft != null) {
            Object draftAccount = existingDraft.get(accountField);
            if (draftAccount != null) resolvedAccountId = String.valueOf(draftAccount);
        }
        if (String.isBlank(resolvedAccountId)) {
            throw new AuraHandledException('Business Unit selection is required.');
        }

        SObject eventRecord;
        if (String.isNotBlank(workingEventId)) {
            eventRecord = eventType.newSObject((Id) workingEventId);
        } else {
            eventRecord = eventType.newSObject();
            eventRecord.put('RecordTypeId', req.recordTypeId);
        }
        eventRecord.put('Name', req.eventName);
        if (eventLabelField != null) eventRecord.put(eventLabelField, req.eventName);
        eventRecord.put(accountField, resolvedAccountId);
        eventRecord.put(eventStatusField, req.eventStatus);
        if (createOppsField != null) eventRecord.put(createOppsField, req.createOppsFromRegs == null ? false : req.createOppsFromRegs);
        if (sendEmailField != null) eventRecord.put(sendEmailField, req.sendRegistrationConfirmation == null ? false : req.sendRegistrationConfirmation);
        ProgramSelectionComputed selection = computeProgramSelection(req.selectedPlanIds, req.programFilterValues);
        if (selection != null) {
            includesMultiple = selection.includesMultiple;
            req.defaultPlanId = selection.defaultPlanId;
            req.programFilterValues = selection.programFilters;
        }
        if (includesMultipleField != null) eventRecord.put(includesMultipleField, includesMultiple);
        if (defaultPlanField != null) eventRecord.put(defaultPlanField, String.isNotBlank(req.defaultPlanId) ? req.defaultPlanId : null);
        if (paymentGatewayField != null) eventRecord.put(paymentGatewayField, String.isNotBlank(req.paymentGateway) ? req.paymentGateway : null);
        if (accountingDeptField != null) eventRecord.put(accountingDeptField, String.isNotBlank(req.accountingDepartmentId) ? req.accountingDepartmentId : null);
        if (templateField != null) eventRecord.put(templateField, String.isNotBlank(req.templateId) ? req.templateId : null);
        if (eventTypeField != null) eventRecord.put(eventTypeField, String.isNotBlank(req.eventType) ? req.eventType : null);
        if (categoryField != null) eventRecord.put(categoryField, String.isNotBlank(req.category) ? req.category : null);
        if (locationTypeField != null) eventRecord.put(locationTypeField, String.isNotBlank(req.locationType) ? req.locationType : null);
        if (startDateField != null) eventRecord.put(startDateField, req.eventStartDate);
        if (endDateField != null) eventRecord.put(endDateField, req.eventEndDate);
        if (isOnlineLocationType) {
            if (locationTitleField != null) eventRecord.put(locationTitleField, null);
            if (locationAddressField != null) eventRecord.put(locationAddressField, null);
            if (locationMapLinkField != null) eventRecord.put(locationMapLinkField, null);
            if (buildingField != null) eventRecord.put(buildingField, null);
        } else {
            if (locationTitleField != null) eventRecord.put(locationTitleField, req.locationTitle);
            if (locationAddressField != null) eventRecord.put(locationAddressField, req.locationAddress);
            if (locationMapLinkField != null) eventRecord.put(locationMapLinkField, req.locationMapLink);
            if (buildingField != null) eventRecord.put(buildingField, req.building);
        }
        if (capacityField != null) eventRecord.put(capacityField, req.capacity);
        if (privateEventField != null) eventRecord.put(privateEventField, req.isPreview == true ? true : (req.privateEvent == true));
        if (filterCategoryField != null) eventRecord.put(filterCategoryField, String.isNotBlank(req.filterCategory) ? req.filterCategory : null);
        if (confirmationTitleField != null) eventRecord.put(confirmationTitleField, req.confirmationTitle);
        if (confirmationDescriptionField != null) eventRecord.put(confirmationDescriptionField, req.confirmationDescription);
        if (landingDescriptionField != null) eventRecord.put(landingDescriptionField, req.landingDescription);
        if (landingFullTextField != null) eventRecord.put(landingFullTextField, req.landingFullText);
        if (landingShortListingField != null) eventRecord.put(landingShortListingField, req.landingShortListingDescription);
        if (customQuestionsTitleField != null) eventRecord.put(customQuestionsTitleField, req.customQuestionsTitle);
        if (customQuestionsDescriptionField != null) eventRecord.put(customQuestionsDescriptionField, req.customQuestionsDescription);
        if (templateBannerImageField != null) eventRecord.put(templateBannerImageField, req.templateBannerImage);
        if (templateLogoImageField != null) eventRecord.put(templateLogoImageField, req.templateLogoImage);
        if (templateDisclaimerField != null) eventRecord.put(templateDisclaimerField, req.templateDisclaimerText);
        if (registerButtonTextField != null) eventRecord.put(registerButtonTextField, req.registerButtonText);
        if (eventHomeLinkTitleField != null) eventRecord.put(eventHomeLinkTitleField, req.eventHomeLinkTitle);
        if (eventHomeLinkUrlField != null) eventRecord.put(eventHomeLinkUrlField, req.eventHomeLinkUrl);
        if (feedRegistrationButtonTextField != null) eventRecord.put(feedRegistrationButtonTextField, req.feedRegistrationButtonText);
        if (registrationEmailRestrictionField != null) eventRecord.put(registrationEmailRestrictionField, String.isNotBlank(req.registrationEmailRestriction) ? req.registrationEmailRestriction : null);
        if (eventFeeField != null) eventRecord.put(eventFeeField, req.eventFee);
        if (eventFeeAdditionalField != null) eventRecord.put(eventFeeAdditionalField, req.eventFeeAdditional);
        if (eventFeeAllocationField != null) eventRecord.put(eventFeeAllocationField, req.eventFeeAllocationId);
        if (eventFeeAdditionalAllocationField != null) eventRecord.put(eventFeeAdditionalAllocationField, req.eventFeeAdditionalAllocationId);
        if (eventPaymentReceivedDescriptionField != null) eventRecord.put(eventPaymentReceivedDescriptionField, req.eventPaymentReceivedDescription);
        if (eventPaymentDueDescriptionField != null) eventRecord.put(eventPaymentDueDescriptionField, req.eventPaymentDueDescription);
        if (eventFeeLabelField != null) eventRecord.put(eventFeeLabelField, req.eventFeeLabel);
        if (eventFeeSubmitListLabelField != null) eventRecord.put(eventFeeSubmitListLabelField, req.eventFeeSubmitListLabel);
        if (eventPaymentReceivedHeadingLabelField != null) eventRecord.put(eventPaymentReceivedHeadingLabelField, req.eventPaymentReceivedHeadingLabel);
        if (eventFeesReceivedLabelField != null) eventRecord.put(eventFeesReceivedLabelField, req.eventFeesReceivedLabel);
        if (eventFeeTotalLabelField != null) eventRecord.put(eventFeeTotalLabelField, req.eventFeeTotalLabel);
        if (eventPaymentDueHeadingLabelField != null) eventRecord.put(eventPaymentDueHeadingLabelField, req.eventPaymentDueHeadingLabel);
        if (previewField != null && req.isPreview != null) eventRecord.put(previewField, req.isPreview);
        if (noMatchBehaviorField != null) eventRecord.put(noMatchBehaviorField, 'Skip Creating Contact');
        if (multipleMatchBehaviorField != null) eventRecord.put(multipleMatchBehaviorField, 'Skip matching');

        FiuProgramFilterService.ProgramFilterConfig programConfig = FiuProgramFilterService.getConfig();
        String defaultPlanCode = lookupPlanCode(req.defaultPlanId);
        for (String pf : programConfig.eventProgramFields) {
            if (!eventFields.containsKey(pf)) continue;
            String val = req.programFilterValues == null ? null : req.programFilterValues.get(pf);
            if (String.isNotBlank(val)) eventRecord.put(pf, val.trim());
            else if (String.isNotBlank(defaultPlanCode)) eventRecord.put(pf, defaultPlanCode);
            else eventRecord.put(pf, null);
        }

        if (String.isNotBlank(workingEventId)) update eventRecord;
        else insert eventRecord;

        // Final guardrail: require Program/Plan selection only when registrations should create Opportunities.
        if (req.createOppsFromRegs == true && !hasPersistedProgramSelection(eventObject, (Id) eventRecord.get('Id'), programConfig)) {
            throw new AuraHandledException('Program/Plan selection is required when registrations create Opportunities. Please choose Business Unit and Program(s).');
        }

        CreateResult out = new CreateResult();
        out.eventId = (Id) eventRecord.get('Id');
        out.eventName = req.eventName;
        if (eventUrlField != null && out.eventId != null) {
            String urlSoql = 'SELECT ' + eventUrlField + ' FROM ' + eventObject + ' WHERE Id = :out.eventId LIMIT 1';
            SObject savedEvent = Database.query(urlSoql);
            Object rawUrl = savedEvent == null ? null : savedEvent.get(eventUrlField);
            if (rawUrl != null) out.previewUrl = String.valueOf(rawUrl);
        }
        if (createFirstInstance) {
            Schema.SObjectType instType = Schema.getGlobalDescribe().get('summit__Summit_Events_Instance__c');
            if (instType == null) throw new AuraHandledException('Instance object could not be resolved.');
            Map<String, Schema.SObjectField> instFields = instType.getDescribe().fields.getMap();

            String instEventField = resolveWritableField(instFields, new List<String>{ 'summit__Event__c', 'summit__Summit_Event__c', 'Event__c' }, true);
            String instTitleField = resolveWritableField(instFields, new List<String>{ 'summit__Instance_Title__c', 'Instance_Title__c' }, true);
            String instStartField = resolveWritableField(instFields, new List<String>{ 'summit__Instance_Start_Date__c', 'summit__Start_Date__c', 'Start_Date__c' }, true);
            String instEndField = resolveWritableField(instFields, new List<String>{ 'summit__Instance_End_Date__c', 'summit__End_Date__c', 'End_Date__c' }, true);
            String instActiveStatusField = resolveWritableField(instFields, new List<String>{ 'summit__Active_Status__c', 'Active_Status__c' }, true);
            String instOpenRegField = resolveWritableField(instFields, new List<String>{ 'summit__Open_Registration__c', 'Open_Registration__c' }, true);
            String instCapacityField = resolveWritableField(instFields, new List<String>{ 'summit__Capacity__c', 'Capacity__c' }, true);
            if (instEventField == null) throw new AuraHandledException('Instance event lookup field is not writable in this org.');

            SObject instanceRecord = instType.newSObject();
            instanceRecord.put(instEventField, (Id) eventRecord.get('Id'));
            if (instTitleField != null) instanceRecord.put(instTitleField, String.isBlank(req.instanceTitle) ? req.eventName : req.instanceTitle);
            else instanceRecord.put('Name', String.isBlank(req.instanceTitle) ? req.eventName : req.instanceTitle);
            instanceRecord.put(instStartField, req.instanceStart);
            instanceRecord.put(instEndField, req.instanceEnd);
            if (instCapacityField != null) instanceRecord.put(instCapacityField, req.capacity);
            if (isWritableField(instFields, instOpenRegField, true)) {
                instanceRecord.put(instOpenRegField, req.instanceOpenRegistration == null ? false : req.instanceOpenRegistration);
            }
            if (instActiveStatusField != null) {
                if (String.isNotBlank(req.instanceActiveStatus)) instanceRecord.put(instActiveStatusField, req.instanceActiveStatus);
                else instanceRecord.put(instActiveStatusField, 'Inactive');
            }

            insert instanceRecord;
            out.instanceId = (Id) instanceRecord.get('Id');
            out.instanceName = String.isBlank(req.instanceTitle) ? req.eventName : req.instanceTitle;
        }
        return out;
    }

    @AuraEnabled
    public static CreateResult previewEvent(CreateRequest req) {
        if (req == null) throw new AuraHandledException('Missing preview request.');
        String previewTrace = 'trace(rt=' + req.recordTypeId + ', name=' + req.eventName + ', bu=' + req.businessUnitId + ', acct=' + req.accountId + ')';
        System.debug(LoggingLevel.WARN, 'FIU_PREVIEW_ENTER req.recordTypeId=' + req.recordTypeId + ', req.eventName=' + req.eventName + ', req.businessUnitId=' + req.businessUnitId + ', req.accountId=' + req.accountId);
        if (String.isBlank(req.eventName)) throw new AuraHandledException('Enter an Event Name first. ' + previewTrace);
        if (String.isBlank(req.businessUnitId) && String.isBlank(req.accountId)) {
            throw new AuraHandledException('Select a Business Unit first. ' + previewTrace);
        }

        String eventObject = FiuEventsAccessService.resolveEventObject();
        if (eventObject == null) throw new AuraHandledException('Event object could not be resolved.');
        String previewField = FiuEventsAccessService.resolveEventPreviewField();
        if (previewField == null) throw new AuraHandledException('Preview field is not available on Event.');
        if (String.isBlank(req.recordTypeId)) {
            Schema.SObjectType eventType = Schema.getGlobalDescribe().get(eventObject);
            if (eventType != null) {
                for (Schema.RecordTypeInfo rti : eventType.getDescribe().getRecordTypeInfos()) {
                    if (rti.isAvailable()) {
                        req.recordTypeId = String.valueOf(rti.getRecordTypeId());
                        break;
                    }
                }
            }
        }
        System.debug(LoggingLevel.WARN, 'FIU_PREVIEW_RT_RESOLVED req.recordTypeId=' + req.recordTypeId);
        if (String.isBlank(req.recordTypeId)) throw new AuraHandledException('Select a Record Type first. ' + previewTrace);

        Id currentUserId = UserInfo.getUserId();
        Id previewRecordTypeId = (Id) req.recordTypeId;
        String q = 'SELECT Id FROM ' + eventObject +
            ' WHERE CreatedById = :currentUserId' +
            ' AND RecordTypeId = :previewRecordTypeId' +
            ' AND (' + previewField + ' = true)' +
            ' ORDER BY LastModifiedDate DESC LIMIT 1';
        List<SObject> existing = Database.query(q);
        if (!existing.isEmpty()) req.workingEventId = String.valueOf(existing[0].get('Id'));
        System.debug(LoggingLevel.WARN, 'FIU_PREVIEW_WORKING_EVENT req.workingEventId=' + req.workingEventId);

        req.isPreview = true;
        req.createFirstInstance = false;
        req.draftEventId = null;
        CreateResult previewResult = createEventAndFirstInstance(req);
        if (previewResult != null && previewResult.eventId != null) {
            previewResult.instanceId = ensurePreviewInstance(previewResult.eventId, req);
            if (previewResult.instanceId != null) {
                previewResult.previewUrl = getPreviewInstanceAdminOpenUrl(previewResult.instanceId);
            }
        }
        return previewResult;
    }

    @AuraEnabled
    public static CreateResult previewEventJson(String reqJson) {
        if (String.isBlank(reqJson)) throw new AuraHandledException('Missing preview request payload.');
        CreateRequest req = (CreateRequest) JSON.deserialize(reqJson, CreateRequest.class);
        return previewEvent(req);
    }

    private static Id ensurePreviewInstance(Id eventId, CreateRequest req) {
        if (eventId == null) return null;
        String instanceObject = FiuEventsAccessService.resolveInstanceObject();
        if (instanceObject == null) return null;
        Schema.SObjectType instType = Schema.getGlobalDescribe().get(instanceObject);
        if (instType == null) return null;
        Map<String, Schema.SObjectField> instFields = instType.getDescribe().fields.getMap();

        Boolean isInsert = true;
        String instEventQueryField = resolveOptionalField(instFields, new List<String>{ 'summit__Event__c', 'summit__Summit_Event__c', 'Event__c' });
        String instEventField = resolveWritableField(instFields, new List<String>{ 'summit__Event__c', 'summit__Summit_Event__c', 'Event__c' }, isInsert);
        String instTitleField = resolveWritableField(instFields, new List<String>{ 'summit__Instance_Title__c', 'Instance_Title__c' }, isInsert);
        String instStartField = resolveWritableField(instFields, new List<String>{ 'summit__Instance_Start_Date__c', 'summit__Start_Date__c', 'Start_Date__c' }, isInsert);
        String instEndField = resolveWritableField(instFields, new List<String>{ 'summit__Instance_End_Date__c', 'summit__End_Date__c', 'End_Date__c' }, isInsert);
        String instActiveStatusField = resolveWritableField(instFields, new List<String>{ 'summit__Active_Status__c', 'Active_Status__c' }, isInsert);
        String instOpenRegField = resolveWritableField(instFields, new List<String>{ 'summit__Open_Registration__c', 'Open_Registration__c' }, isInsert);
        String instPreviewField = FiuEventsAccessService.resolveInstancePreviewField();
        if (instEventQueryField == null) return null;

        Id existingId;
        String existingQ = 'SELECT Id FROM ' + instanceObject + ' WHERE ' + instEventQueryField + ' = :eventId';
        if (instPreviewField != null) existingQ += ' AND ' + instPreviewField + ' = true';
        existingQ += ' ORDER BY LastModifiedDate DESC LIMIT 1';
        List<SObject> existing = Database.query(existingQ);
        if (!existing.isEmpty()) existingId = (Id) existing[0].get('Id');

        isInsert = existingId == null;
        instEventField = resolveWritableField(instFields, new List<String>{ 'summit__Event__c', 'summit__Summit_Event__c', 'Event__c' }, isInsert);
        instTitleField = resolveWritableField(instFields, new List<String>{ 'summit__Instance_Title__c', 'Instance_Title__c' }, isInsert);
        instStartField = resolveWritableField(instFields, new List<String>{ 'summit__Instance_Start_Date__c', 'summit__Start_Date__c', 'Start_Date__c' }, isInsert);
        instEndField = resolveWritableField(instFields, new List<String>{ 'summit__Instance_End_Date__c', 'summit__End_Date__c', 'End_Date__c' }, isInsert);
        instActiveStatusField = resolveWritableField(instFields, new List<String>{ 'summit__Active_Status__c', 'Active_Status__c' }, isInsert);
        instOpenRegField = resolveWritableField(instFields, new List<String>{ 'summit__Open_Registration__c', 'Open_Registration__c' }, isInsert);
        String instCapacityField = resolveWritableField(instFields, new List<String>{ 'summit__Capacity__c', 'Capacity__c' }, isInsert);
        if (existingId == null && instEventField == null) return null;

        SObject previewInst = existingId == null ? instType.newSObject() : instType.newSObject(existingId);
        if (instEventField != null) previewInst.put(instEventField, eventId);
        // Reset common override/config fields so previous preview values do not leak.
        for (String resetField : new List<String>{
            'summit__Location_Title_Override__c',
            'summit__Location_Address_Override__c',
            'summit__Location_Map_Link_Override__c',
            'summit__Location_Type_Override__c',
            'summit__Building_Override__c',
            'summit__Virtual_Meeting_URL__c',
            'summit__Virtual_Meeting_Phone__c',
            'Parking_info__c'
        }) {
            if (isWritableField(instFields, resetField, isInsert)) previewInst.put(resetField, null);
        }
        if (isWritableField(instFields, instPreviewField, isInsert)) previewInst.put(instPreviewField, true);
        if (instTitleField != null) previewInst.put(instTitleField, 'Preview - ' + req.eventName);
        if (instActiveStatusField != null) previewInst.put(instActiveStatusField, 'Active');
        if (instOpenRegField != null) previewInst.put(instOpenRegField, true);
        if (instCapacityField != null) previewInst.put(instCapacityField, req.capacity);
        applyTemporalValue(previewInst, instFields, instStartField, req.instanceStart, req.eventStartDate);
        applyTemporalValue(previewInst, instFields, instEndField, req.instanceEnd, req.eventEndDate);

        if (existingId == null) insert previewInst;
        else update previewInst;
        return (Id) previewInst.get('Id');
    }

    private static String getPreviewInstanceAdminOpenUrl(Id instanceId) {
        if (instanceId == null) return null;
        String instanceObject = FiuEventsAccessService.resolveInstanceObject();
        if (String.isBlank(instanceObject)) return null;
        Schema.SObjectType instType = Schema.getGlobalDescribe().get(instanceObject);
        if (instType == null) return null;
        Map<String, Schema.SObjectField> instFields = instType.getDescribe().fields.getMap();
        String adminOpenField = resolveOptionalField(instFields, new List<String>{
            'summit__Admin_Open_Registration__c',
            'Admin_Open_Registration__c'
        });
        String instEventField = resolveOptionalField(instFields, new List<String>{ 'summit__Event__c', 'summit__Summit_Event__c', 'Event__c' });

        List<String> selectFields = new List<String>{ 'Id' };
        if (String.isNotBlank(adminOpenField)) selectFields.add(adminOpenField);
        if (String.isNotBlank(instEventField)) selectFields.add(instEventField);
        String q = 'SELECT ' + String.join(selectFields, ', ') + ' FROM ' + instanceObject + ' WHERE Id = :instanceId LIMIT 1';
        SObject instanceRecord = Database.query(q);
        if (instanceRecord == null) return null;

        if (String.isNotBlank(adminOpenField)) {
            Object rawUrl = instanceRecord.get(adminOpenField);
            if (rawUrl != null && String.isNotBlank(String.valueOf(rawUrl))) {
                return String.valueOf(rawUrl);
            }
        }

        Id eventId = String.isBlank(instEventField) ? null : (Id) instanceRecord.get(instEventField);
        return buildAdminOpenRegistrationUrl(eventId, instanceId);
    }

    private static String buildAdminOpenRegistrationUrl(Id eventId, Id instanceId) {
        if (eventId == null || instanceId == null) return null;
        String eventObject = FiuEventsAccessService.resolveEventObject();
        if (String.isBlank(eventObject)) return null;
        Schema.SObjectType eventType = Schema.getGlobalDescribe().get(eventObject);
        if (eventType == null) return null;
        Map<String, Schema.SObjectField> eventFields = eventType.getDescribe().fields.getMap();
        String communityBaseUrlField = resolveOptionalField(eventFields, new List<String>{
            'summit__Community_Base_URL__c',
            'Community_Base_URL__c'
        });
        if (String.isBlank(communityBaseUrlField)) return null;

        String eventQ = 'SELECT ' + communityBaseUrlField + ' FROM ' + eventObject + ' WHERE Id = :eventId LIMIT 1';
        SObject eventRecord = Database.query(eventQ);
        String baseUrl = eventRecord == null ? null : String.valueOf(eventRecord.get(communityBaseUrlField));
        if (String.isBlank(baseUrl)) return null;

        Boolean isManagedPackage = isManagedPackageEnabled();
        String path = isManagedPackage ? 'summit__SummitEventsRegister' : 'SummitEventsRegister';
        String normalizedBase = baseUrl.endsWith('/') ? baseUrl : baseUrl + '/';
        return normalizedBase + path + '?instanceID=' + String.valueOf(instanceId) + '&adminopen=1';
    }

    private static Boolean isManagedPackageEnabled() {
        try {
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            String settingsObject = gd.containsKey('summit__Summit_Events_Settings__c')
                ? 'summit__Summit_Events_Settings__c'
                : (gd.containsKey('Summit_Events_Settings__c') ? 'Summit_Events_Settings__c' : null);
            if (String.isBlank(settingsObject)) return true;

            Schema.SObjectType settingsType = gd.get(settingsObject);
            if (settingsType == null) return true;
            Map<String, Schema.SObjectField> settingsFields = settingsType.getDescribe().fields.getMap();
            String managedPackageField = resolveOptionalField(settingsFields, new List<String>{
                'summit__Managed_Package__c',
                'Managed_Package__c'
            });
            if (String.isBlank(managedPackageField)) return true;

            String q = 'SELECT ' + managedPackageField + ' FROM ' + settingsObject + ' LIMIT 1';
            List<SObject> rows = Database.query(q);
            if (rows.isEmpty()) return true;
            Object rawValue = rows[0].get(managedPackageField);
            return rawValue == null ? true : (Boolean) rawValue;
        } catch (Exception ex) {
            return true;
        }
    }

    private static void applyTemporalValue(
        SObject target,
        Map<String, Schema.SObjectField> fieldMap,
        String fieldApi,
        Datetime preferredDateTime,
        Date fallbackDate
    ) {
        if (target == null || String.isBlank(fieldApi) || !fieldMap.containsKey(fieldApi)) return;
        Schema.DisplayType t = fieldMap.get(fieldApi).getDescribe().getType();
        if (t == Schema.DisplayType.DateTime) {
            Datetime outDt = preferredDateTime;
            if (outDt == null) {
                Date anchor = fallbackDate == null ? Date.today() : fallbackDate;
                Time nowTime = Datetime.now().time();
                outDt = Datetime.newInstance(anchor, Time.newInstance(nowTime.hour(), nowTime.minute(), nowTime.second(), 0));
            }
            target.put(fieldApi, outDt);
        } else if (t == Schema.DisplayType.Date) {
            Date outDate = preferredDateTime == null ? fallbackDate : preferredDateTime.date();
            if (outDate == null) outDate = Date.today();
            target.put(fieldApi, outDate);
        }
    }

    private static Boolean isWritableField(
        Map<String, Schema.SObjectField> fieldMap,
        String fieldApi,
        Boolean isInsert
    ) {
        if (fieldMap == null || String.isBlank(fieldApi) || !fieldMap.containsKey(fieldApi)) return false;
        Schema.DescribeFieldResult d = fieldMap.get(fieldApi).getDescribe();
        return isInsert ? d.isCreateable() : d.isUpdateable();
    }

    private static String resolveWritableField(
        Map<String, Schema.SObjectField> fieldMap,
        List<String> candidates,
        Boolean isInsert
    ) {
        if (fieldMap == null || candidates == null) return null;
        for (String api : candidates) {
            if (isWritableField(fieldMap, api, isInsert)) return api;
        }
        return null;
    }

    private static List<String> splitProgramCodes(List<String> codes) {
        List<String> out = new List<String>{ '', '', '' };
        if (codes == null || codes.isEmpty()) return out;
        Integer idx = 0;
        for (String code : codes) {
            if (String.isBlank(code)) continue;
            String token = code.trim() + ',';
            Boolean placed = false;
            while (idx < out.size()) {
                String nextValue = out[idx] + token;
                if (nextValue.length() <= 255) {
                    out[idx] = nextValue;
                    placed = true;
                    break;
                }
                idx++;
            }
            if (!placed) break;
        }
        return out;
    }

    private static ProgramSelectionComputed computeProgramSelection(List<String> selectedPlanIds, Map<String, String> existingFilters) {
        if (selectedPlanIds == null || selectedPlanIds.isEmpty()) return null;
        Map<Id, Plan__c> planById = new Map<Id, Plan__c>([
            SELECT Id, Plan_Code__c FROM Plan__c WHERE Id IN :selectedPlanIds
        ]);
        List<String> codes = new List<String>();
        for (String pid : selectedPlanIds) {
            Plan__c p = planById.get((Id) pid);
            if (p != null && String.isNotBlank(p.Plan_Code__c)) codes.add(p.Plan_Code__c.trim());
        }
        List<String> buckets = splitProgramCodes(codes);
        FiuProgramFilterService.ProgramFilterConfig cfg = FiuProgramFilterService.getConfig();
        ProgramSelectionComputed out = new ProgramSelectionComputed();
        out.defaultPlanId = selectedPlanIds.size() == 1 ? selectedPlanIds[0] : null;
        out.includesMultiple = selectedPlanIds.size() > 1;
        out.programFilters = new Map<String, String>();
        if (existingFilters != null) out.programFilters.putAll(existingFilters);
        for (Integer i = 0; i < cfg.eventProgramFields.size(); i++) {
            out.programFilters.put(cfg.eventProgramFields[i], i < buckets.size() ? buckets[i] : null);
        }
        return out;
    }


    private static String resolveOptionalField(Map<String, Schema.SObjectField> fields, List<String> candidates) {
        if (fields == null) return null;
        for (String f : candidates) if (fields.containsKey(f)) return f;
        return null;
    }

    private static void addPicklistOptions(Map<String, Schema.SObjectField> fields, List<String> candidates, List<Option> output) {
        String api = resolveOptionalField(fields, candidates);
        if (api == null) return;
        for (Schema.PicklistEntry pe : fields.get(api).getDescribe().getPicklistValues()) {
            Option o = new Option();
            o.label = pe.getLabel();
            o.value = pe.getValue();
            output.add(o);
        }
    }

    private static void addFlexibleOptions(Map<String, Schema.SObjectField> fields, List<String> candidates, List<Option> output) {
        String api = resolveOptionalField(fields, candidates);
        if (api == null || output == null) return;
        Schema.DescribeFieldResult fd = fields.get(api).getDescribe();
        if (fd.getType() == Schema.DisplayType.Picklist || fd.getType() == Schema.DisplayType.MultiPicklist) {
            addPicklistOptions(fields, new List<String>{ api }, output);
            return;
        }
        if (fd.getType() == Schema.DisplayType.Reference) {
            List<Schema.SObjectType> refs = fd.getReferenceTo();
            if (refs == null || refs.isEmpty()) return;
            String target = refs[0].getDescribe().getName();
            String soql = 'SELECT Id, Name FROM ' + target + ' ORDER BY Name LIMIT 200';
            for (SObject row : Database.query(soql)) {
                Option o = new Option();
                o.label = (String) row.get('Name');
                o.value = String.valueOf(row.get('Id'));
                output.add(o);
            }
        }
    }


    private static String lookupPlanCode(String planId) {
        if (String.isBlank(planId)) return null;
        try {
            Plan__c p = [SELECT Plan_Code__c FROM Plan__c WHERE Id = :planId LIMIT 1];
            return p.Plan_Code__c;
        } catch (Exception ex) {
            return null;
        }
    }

    private static Boolean hasPersistedProgramSelection(String eventObject, Id eventId, FiuProgramFilterService.ProgramFilterConfig programConfig) {
        if (eventId == null) return false;
        List<String> fields = new List<String>{ 'Id', 'Default_Plan__c' };
        for (String pf : programConfig.eventProgramFields) fields.add(pf);
        String soql = 'SELECT ' + String.join(fields, ',') + ' FROM ' + eventObject + ' WHERE Id = :eventId LIMIT 1';
        SObject eventRow = Database.query(soql);
        if (eventRow.get('Default_Plan__c') != null) return true;
        for (String pf : programConfig.eventProgramFields) {
            Object v = eventRow.get(pf);
            if (v != null && String.isNotBlank(String.valueOf(v))) return true;
        }
        return false;
    }

    private static String findDefaultStatus(List<Option> options) {
        if (options == null || options.isEmpty()) return null;
        for (Option o : options) {
            if (o == null || String.isBlank(o.value)) continue;
            String v = o.value.toLowerCase();
            if (v == 'draft' || v == 'active') return o.value;
        }
        return options[0].value;
    }
}
