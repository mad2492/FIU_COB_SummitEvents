import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';
import getInitData from '@salesforce/apex/FIU_EventsWizardService.getInitData';
import createEventAndFirstInstance from '@salesforce/apex/FIU_EventsWizardService.createEventAndFirstInstance';
import previewEventJson from '@salesforce/apex/FIU_EventsWizardService.previewEventJson';
import getBusinessUnits from '@salesforce/apex/FIU_EventsWizardService.getBusinessUnits';
import getProgramsForBusinessUnit from '@salesforce/apex/FIU_EventsWizardService.getProgramsForBusinessUnit';
import evaluateReadiness from '@salesforce/apex/FiuEventsReadinessService.evaluateEvent';

export default class FiuEventCreateWizard extends NavigationMixin(LightningElement) {
    STEP1_TAB_ORDER = ['eventDetails', 'additionalConfig', 'pageDetails', 'eventFees', 'rsvpTemplate'];
    @track isLoading = true;
    @track isSaving = false;
    @track error;

    @track step = 1;
    @track isSuccess = false;
    @track createdEventId;
    @track createdInstanceId;

    @track recordTypeOptions = [];
    @track eventObjectApiName;
    @track statusOptions = [];
    @track paymentGatewayOptions = [];
    @track locationTypeOptions = [];
    @track templateOptions = [];
    @track categoryOptions = [];
    @track eventTypeOptions = [];
    @track filterCategoryOptions = [];
    @track accountingDepartmentOptions = [];
    @track registrationEmailRestrictionOptions = [];
    @track eventFeeAllocationOptions = [];
    @track eventFeeAdditionalAllocationOptions = [];
    @track businessUnitOptions = [];
    @track programOptions = [];
    @track selectedStep1Tab = 'eventDetails';
    @track pageDetailsReviewed = false;
    @track configurationReviewed = false;
    @track previewState = {
        bannerLoaded: false,
        bannerError: false,
        logoLoaded: false,
        logoError: false
    };
    @track successWarnings = [];
    picklistMeta = {};

    @track form = {
        eventName: '',
        recordTypeId: '',
        businessUnitId: '',
        selectedPlanIds: [],
        accountId: '',
        eventStatus: '',
        eventStartDate: '',
        eventEndDate: '',
        includesMultiplePrograms: false,
        defaultPlanId: '',
        programFilterValues: {},
        createOppsFromRegs: false,
        sendRegistrationConfirmation: false,
        paymentGateway: '',
        isPaidRegistration: false,
        accountingDepartmentId: '',
        templateId: '',
        templateBannerImage: '',
        templateLogoImage: '',
        templateDisclaimerText: '',
        registerButtonText: '',
        registrationEmailRestriction: 'One registration per instance',
        websitePublishingChoice: '',
        eventFee: null,
        eventFeeAdditional: null,
        eventFeeAllocationId: '',
        eventFeeAdditionalAllocationId: '',
        eventPaymentReceivedDescription: '',
        eventPaymentDueDescription: '',
        eventFeeLabel: '',
        eventFeeSubmitListLabel: '',
        eventPaymentReceivedHeadingLabel: '',
        eventFeesReceivedLabel: '',
        eventFeeTotalLabel: '',
        eventPaymentDueHeadingLabel: '',
        category: '',
        eventType: '',
        locationType: '',
        locationTitle: '',
        locationAddress: '',
        locationMapLink: '',
        building: '',
        capacity: null,
        filterCategory: '',
        confirmationTitle: '',
        confirmationDescription: '',
        landingDescription: '',
        landingFullText: '',
        landingShortListingDescription: '',
        customQuestionsTitle: '',
        customQuestionsDescription: '',
        instanceTitle: '',
        instanceStart: '',
        instanceEnd: '',
        instanceOpenRegistration: false,
        instanceActiveStatus: 'Inactive'
    };

    connectedCallback() {
        this.loadInit();
    }

    get isStep1() { return this.step === 1; }
    get isStep2() { return this.step === 2; }
    get currentStepValue() { return String(this.step); }
    get title() { return this.isSuccess ? 'Event Created' : (this.isStep1 ? 'Create New Event' : 'First Instance Setup'); }
    get paidEvent() {
        return this.form.isPaidRegistration === true;
    }
    get selectedRecordTypeId() {
        return this.form.recordTypeId || null;
    }
    get hasRecordTypeSelected() {
        return !!this.form.recordTypeId;
    }
    get showDependentPicklists() {
        return this.hasRecordTypeSelected;
    }
    get filterCategoryValues() {
        if (!this.form.filterCategory) return [];
        return this.form.filterCategory.split(';').map((v) => v.trim()).filter((v) => !!v);
    }
    get websitePublishingOptions() {
        return [
            { label: '-- Select --', value: '' },
            { label: 'Yes, publish to business.fiu.edu', value: 'yes' },
            { label: 'No, keep off website feed', value: 'no' }
        ];
    }
    get landingPagesFilterValue() {
        const match = (this.filterCategoryOptions || []).find((opt) => {
            const label = (opt.label || '').toLowerCase();
            const value = (opt.value || '').toLowerCase();
            return label.includes('landing page') || value.includes('landing page');
        });
        return match?.value || null;
    }

    get selectedProgramValues() {
        return this.form.selectedPlanIds || [];
    }
    get showBannerPreview() {
        return !!this.form.templateBannerImage;
    }
    get showLogoPreview() {
        return !!this.form.templateLogoImage;
    }
    get canPreviewRsvp() {
        if (!this.showDependentPicklists) return false;
        return !!(
            this.form.templateId &&
            this.form.recordTypeId &&
            this.form.eventName &&
            this.form.eventStatus &&
            this.form.eventStartDate &&
            this.form.eventEndDate &&
            this.form.eventType &&
            this.form.category &&
            this.form.locationType &&
            this.form.businessUnitId &&
            this.form.selectedPlanIds?.length
        );
    }
    get isPreviewDisabled() {
        if (this.requiresPhysicalLocationFields) {
            return this.isSaving || !this.canPreviewRsvp || !this.form.locationTitle || !this.form.locationAddress || !this.form.locationMapLink || !this.form.building;
        }
        return this.isSaving || !this.canPreviewRsvp;
    }
    get eventDetailsComplete() {
        if (!this.form.eventName || !this.form.recordTypeId) return false;
        if (!this.showDependentPicklists) return false;
        if (!this.form.eventStartDate || !this.form.eventEndDate) return false;
        if (this.requiresPhysicalLocationFields) {
            if (!this.form.locationTitle || !this.form.locationAddress || !this.form.locationMapLink || !this.form.building) return false;
        }
        return !!(
            this.form.eventStatus &&
            this.form.eventType &&
            this.form.category &&
            this.form.locationType &&
            this.form.businessUnitId &&
            this.form.selectedPlanIds?.length
        );
    }
    get requiresPhysicalLocationFields() {
        const locationType = (this.form.locationType || '').toLowerCase();
        return locationType === 'on-site' || locationType === 'off-campus';
    }
    get isOnlineLocationType() {
        return (this.form.locationType || '').toLowerCase() === 'online';
    }
    get configurationStatus() {
        if (!this.showDependentPicklists) return 'Pending';
        return this.configurationReviewed ? 'Complete' : 'Review';
    }
    get configurationComplete() {
        return this.configurationReviewed;
    }
    get pageDetailsStatus() {
        return this.pageDetailsReviewed ? 'Complete' : 'Review';
    }
    get pageDetailsComplete() {
        return this.pageDetailsReviewed;
    }
    get eventFeesComplete() {
        if (!this.form.isPaidRegistration) return true;
        return !!(this.form.paymentGateway && this.form.accountingDepartmentId && (this.form.eventFee || this.form.eventFee === 0));
    }
    get rsvpTemplateComplete() {
        if (!this.showDependentPicklists) return false;
        return !!this.form.templateId;
    }
    get isEventDetailsTab() { return this.selectedStep1Tab === 'eventDetails'; }
    get isAdditionalConfigTab() { return this.selectedStep1Tab === 'additionalConfig'; }
    get isPageDetailsTab() { return this.selectedStep1Tab === 'pageDetails'; }
    get isEventFeesTab() { return this.selectedStep1Tab === 'eventFees'; }
    get isRsvpTemplateTab() { return this.selectedStep1Tab === 'rsvpTemplate'; }
    get firstSuccessWarning() { return this.successWarnings?.length ? this.successWarnings[0] : ''; }
    get selectedStep1TabIndex() { return this.STEP1_TAB_ORDER.indexOf(this.selectedStep1Tab); }
    get hasPrevTab() { return this.selectedStep1TabIndex > 0; }
    get hasNextTab() { return this.selectedStep1TabIndex >= 0 && this.selectedStep1TabIndex < this.STEP1_TAB_ORDER.length - 1; }
    get canFinalizeStep1() {
        const requiredText = ['eventName', 'eventStartDate', 'eventEndDate'];
        const requiredCombo = ['recordTypeId', 'eventStatus', 'eventType', 'category', 'locationType', 'templateId', 'businessUnitId'];
        if (this.requiresPhysicalLocationFields) requiredText.push('locationTitle', 'locationAddress', 'locationMapLink', 'building');
        if (this.form.isPaidRegistration) requiredCombo.push('paymentGateway', 'accountingDepartmentId');
        if (this.form.isPaidRegistration && !this.form.eventFee && this.form.eventFee !== 0) return false;
        if (requiredText.some((key) => !this.form[key])) return false;
        if (requiredCombo.some((key) => !this.form[key])) return false;
        return !!this.form.selectedPlanIds?.length;
    }
    get finalizeStep1Disabled() {
        return this.isSaving || !this.canFinalizeStep1;
    }
    get step1TabStatuses() {
        const tabs = [
            { value: 'eventDetails', label: 'Event Details', statusText: this.eventDetailsComplete ? 'Complete' : 'Pending' },
            { value: 'additionalConfig', label: 'Configuration', statusText: this.configurationStatus },
            { value: 'pageDetails', label: 'Page Details', statusText: this.pageDetailsStatus },
            { value: 'eventFees', label: 'Event Fees', statusText: this.form.isPaidRegistration ? (this.eventFeesComplete ? 'Complete' : 'Pending') : null },
            { value: 'rsvpTemplate', label: 'RSVP Template', statusText: this.rsvpTemplateComplete ? 'Complete' : 'Pending' }
        ];
        return tabs.map((tab) => ({
            ...tab,
            isActive: this.selectedStep1Tab === tab.value,
            badgeClass: `tab-status-badge ${this.getTabBadgeFlavor(tab.statusText)} ${tab.statusText ? '' : 'is-hidden'}`,
            buttonClass: `tab-status-item ${this.selectedStep1Tab === tab.value ? 'is-active' : ''}`
        }));
    }
    getTabBadgeFlavor(statusText) {
        if (statusText === 'Complete') return 'is-complete';
        if (statusText === 'Review') return 'is-review';
        return 'is-pending';
    }

    async loadInit() {
        this.isLoading = true;
        this.error = undefined;
        try {
            const data = await getInitData();
            this.recordTypeOptions = data?.recordTypeOptions || [];
            this.eventObjectApiName = data?.eventObjectApiName || '';
            this.statusOptions = data?.eventStatusOptions || [];
            this.paymentGatewayOptions = [{ label: '-- None --', value: '' }, ...(data?.paymentGatewayOptions || [])];
            this.locationTypeOptions = [{ label: '-- Select --', value: '' }, ...(data?.locationTypeOptions || [])];
            this.templateOptions = [{ label: '-- Select --', value: '' }, ...(data?.templateOptions || [])];
            this.categoryOptions = [{ label: '-- Select --', value: '' }, ...(data?.categoryOptions || [])];
            this.eventTypeOptions = [{ label: '-- Select --', value: '' }];
            this.filterCategoryOptions = data?.filterCategoryOptions || [];
            this.accountingDepartmentOptions = [{ label: '-- Select --', value: '' }, ...(data?.accountingDepartmentOptions || [])];
            this.registrationEmailRestrictionOptions = data?.registrationEmailRestrictionOptions || [];
            this.eventFeeAllocationOptions = [{ label: '-- Select --', value: '' }, ...(data?.eventFeeAllocationOptions || [])];
            this.eventFeeAdditionalAllocationOptions = [{ label: '-- Select --', value: '' }, ...(data?.eventFeeAdditionalAllocationOptions || [])];
            if (this.registrationEmailRestrictionOptions.some((o) => o.value === 'One registration per instance')) {
                this.form.registrationEmailRestriction = 'One registration per instance';
            } else if (this.registrationEmailRestrictionOptions.length) {
                this.form.registrationEmailRestriction = this.registrationEmailRestrictionOptions[0].value;
            }
            this.form.recordTypeId = this.recordTypeOptions.length === 1 ? this.recordTypeOptions[0].value : '';
            this.form.eventStatus = data?.defaultEventStatus || '';
            this.businessUnitOptions = [{ label: '-- Select --', value: '' }, ...(await getBusinessUnits())];
            await this.applyRecordTypeBusinessUnitDefault();
        } catch (e) {
            this.error = e?.body?.message || 'Could not load wizard metadata.';
        } finally {
            this.isLoading = false;
        }
    }

    handleInput(event) {
        const key = event.target.dataset.field;
        if (!key) return;
        const nextValue = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.form = { ...this.form, [key]: nextValue };
        if (key === 'recordTypeId') {
            this.form = { ...this.form, templateId: '', eventType: '', category: '', filterCategory: '' };
            this.configurationReviewed = false;
            this.applyRecordTypeBusinessUnitDefault();
        }
        if (key === 'templateBannerImage') {
            this.previewState = { ...this.previewState, bannerLoaded: false, bannerError: false };
        }
        if (key === 'templateLogoImage') {
            this.previewState = { ...this.previewState, logoLoaded: false, logoError: false };
        }
        if (key === 'eventType') {
            const eventTypeNormalized = (nextValue || '').toLowerCase();
            const shouldEnableRecruitingDefaults =
                eventTypeNormalized === 'graduate recruitment' ||
                eventTypeNormalized === 'executive education';
            this.configurationReviewed = false;
            this.form = {
                ...this.form,
                category: '',
                filterCategory: '',
                createOppsFromRegs: shouldEnableRecruitingDefaults,
                sendRegistrationConfirmation: shouldEnableRecruitingDefaults
            };
        }
        if (key === 'category') {
            this.form = { ...this.form, filterCategory: '' };
        }
        if (key === 'websitePublishingChoice') {
            const landingPagesValue = this.landingPagesFilterValue;
            if (nextValue === 'yes' && landingPagesValue) {
                this.form = { ...this.form, filterCategory: landingPagesValue, websitePublishingChoice: nextValue };
            } else if (nextValue === 'no') {
                this.form = { ...this.form, filterCategory: '', websitePublishingChoice: nextValue };
            } else {
                this.form = { ...this.form, websitePublishingChoice: nextValue };
            }
        }
        if (key === 'locationType' && this.isOnlineLocationType) {
            this.form = {
                ...this.form,
                locationTitle: '',
                locationAddress: '',
                locationMapLink: '',
                building: ''
            };
        }
        this.applyDependencyOptions();
    }

    handleStatusTabClick(event) {
        const tab = event.currentTarget?.dataset?.tab;
        if (tab) this.setSelectedStep1Tab(tab);
    }
    handleStep1PrevTab() {
        if (!this.hasPrevTab) return;
        this.setSelectedStep1Tab(this.STEP1_TAB_ORDER[this.selectedStep1TabIndex - 1]);
    }
    handleStep1NextTab() {
        if (!this.hasNextTab) return;
        this.setSelectedStep1Tab(this.STEP1_TAB_ORDER[this.selectedStep1TabIndex + 1]);
    }
    setSelectedStep1Tab(nextTab) {
        if (this.selectedStep1Tab === 'pageDetails' && nextTab !== 'pageDetails') {
            this.pageDetailsReviewed = true;
        }
        if (this.selectedStep1Tab === 'additionalConfig' && nextTab !== 'additionalConfig' && this.showDependentPicklists) {
            this.configurationReviewed = true;
        }
        this.selectedStep1Tab = nextTab;
    }

    async handleBusinessUnitChange(event) {
        const businessUnitId = event.detail.value || '';
        await this.setBusinessUnitAndPrograms(businessUnitId);
    }

    async handleProgramSelectionChange(event) {
        const selectedPlanIds = event.detail.value || [];
        this.form = { ...this.form, selectedPlanIds };
    }

    async setBusinessUnitAndPrograms(businessUnitId) {
        this.form = { ...this.form, businessUnitId, accountId: businessUnitId || '', selectedPlanIds: [] };
        this.programOptions = [];
        if (businessUnitId) {
            const options = await getProgramsForBusinessUnit({ businessUnitId });
            this.programOptions = options.map((o) => ({ label: o.label, value: o.value }));
        }
    }

    getSelectedRecordTypeLabel() {
        const selected = this.recordTypeOptions.find((opt) => opt.value === this.form.recordTypeId);
        return (selected?.label || '').trim();
    }

    findBusinessUnitOptionByName(name) {
        if (!name) return null;
        return this.businessUnitOptions.find((opt) => (opt.label || '').trim().toLowerCase() === name.toLowerCase()) || null;
    }

    async applyRecordTypeBusinessUnitDefault() {
        if (!this.form.recordTypeId || !this.businessUnitOptions?.length) return;
        const rtLabel = this.getSelectedRecordTypeLabel().toLowerCase();
        let desiredBuName = null;
        if (rtLabel === 'chapman events') desiredBuName = 'Chapman Graduate School';
        if (rtLabel === 'epe events') desiredBuName = 'Executive and Professional Education';
        if (rtLabel === 'ogi events') desiredBuName = 'Office of Global Initiatives';
        if (!desiredBuName) return;

        const desiredBu = this.findBusinessUnitOptionByName(desiredBuName);
        if (desiredBu?.value) {
            await this.setBusinessUnitAndPrograms(desiredBu.value);
            return;
        }
        if (rtLabel === 'epe events' || rtLabel === 'ogi events') {
            await this.setBusinessUnitAndPrograms('');
        }
    }

    handleMultiSelect(event) {
        const key = event.target.dataset.field;
        if (!key) return;
        const values = event.detail?.value || [];
        this.form = { ...this.form, [key]: values.join(';') };
    }

    async openInstanceStep() {
        const msg = this.validateStep1();
        if (msg) {
            this.error = msg;
            return;
        }
        this.error = undefined;
        this.step = 2;
    }

    prevStep() {
        this.error = undefined;
        this.step = 1;
    }

    FIELD_TAB_MAP = {
        eventName: 'eventDetails',
        recordTypeId: 'eventDetails',
        eventStatus: 'eventDetails',
        eventType: 'eventDetails',
        category: 'eventDetails',
        locationType: 'eventDetails',
        eventStartDate: 'eventDetails',
        eventEndDate: 'eventDetails',
        locationTitle: 'eventDetails',
        locationAddress: 'eventDetails',
        locationMapLink: 'eventDetails',
        building: 'eventDetails',
        templateId: 'rsvpTemplate',
        businessUnitId: 'eventDetails',
        selectedPlanIds: 'eventDetails',
        paymentGateway: 'eventFees',
        accountingDepartmentId: 'eventFees',
        eventFee: 'eventFees'
    };

    validateStep1() {
        const requiredText = ['eventName', 'eventStartDate', 'eventEndDate'];
        const requiredCombo = ['recordTypeId', 'eventStatus', 'eventType', 'category', 'locationType', 'templateId', 'businessUnitId'];
        if (this.requiresPhysicalLocationFields) {
            requiredText.push('locationTitle', 'locationAddress', 'locationMapLink', 'building');
        }
        if (this.form.isPaidRegistration) requiredCombo.push('paymentGateway', 'accountingDepartmentId');
        if (this.form.isPaidRegistration && !this.form.eventFee && this.form.eventFee !== 0) {
            const targetTab = this.FIELD_TAB_MAP.eventFee;
            if (targetTab && this.selectedStep1Tab !== targetTab) this.setSelectedStep1Tab(targetTab);
            return 'Event Fee is required for paid registration events.';
        }

        const missingField = [...requiredText, ...requiredCombo].find((key) => !this.form[key]);
        const programsMissing = !this.form.selectedPlanIds?.length;
        if (!missingField && !programsMissing) return null;

        const offending = missingField || 'selectedPlanIds';
        const targetTab = this.FIELD_TAB_MAP[offending];
        if (targetTab && this.selectedStep1Tab !== targetTab) {
            this.setSelectedStep1Tab(targetTab);
        }

        Promise.resolve().then(() => {
            const inputs = this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-dual-listbox');
            let firstInvalid;
            inputs.forEach((el) => {
                if (typeof el.reportValidity === 'function') {
                    const valid = el.reportValidity();
                    if (!valid && !firstInvalid) firstInvalid = el;
                }
            });
            if (firstInvalid && typeof firstInvalid.focus === 'function') firstInvalid.focus();
        });

        return 'Some required fields are missing. We highlighted them for you.';
    }

    validateStep2() {
        const inputs = this.template.querySelectorAll('lightning-input');
        let firstInvalid;
        let allValid = true;
        inputs.forEach((el) => {
            if (typeof el.reportValidity === 'function') {
                const valid = el.reportValidity();
                if (!valid) {
                    allValid = false;
                    if (!firstInvalid) firstInvalid = el;
                }
            }
        });
        if (allValid) return null;
        if (firstInvalid && typeof firstInvalid.focus === 'function') firstInvalid.focus();
        return 'Some required fields are missing. We highlighted them for you.';
    }

    async createEventOnly() {
        await this.finishCreate(false);
    }

    async handlePreviewRsvp() {
        const step1Err = this.validateStep1();
        if (step1Err) {
            this.error = step1Err;
            this.step = 1;
            return;
        }
        this.error = undefined;
        this.isSaving = true;
        try {
            const req = {
                ...this.form,
                workingEventId: null,
                draftEventId: null,
                createFirstInstance: false,
                isPreview: true
            };
            // Prevent Apex JSON deserialize typed-field errors (Date/Datetime/Decimal) from empty strings.
            req.instanceStart = req.instanceStart || null;
            req.instanceEnd = req.instanceEnd || null;
            req.eventStartDate = req.eventStartDate || null;
            req.eventEndDate = req.eventEndDate || null;
            req.eventFee = (req.eventFee === '' || req.eventFee === undefined) ? null : req.eventFee;
            req.eventFeeAdditional = (req.eventFeeAdditional === '' || req.eventFeeAdditional === undefined) ? null : req.eventFeeAdditional;
            // TEMP TRACE: capture outbound preview payload fields tied to record type drift.
            // eslint-disable-next-line no-console
            console.log('[FIU Preview] outbound req', JSON.stringify({
                recordTypeId: req.recordTypeId,
                eventName: req.eventName,
                businessUnitId: req.businessUnitId,
                accountId: req.accountId,
                selectedStep1Tab: this.selectedStep1Tab
            }));
            const result = await previewEventJson({ reqJson: JSON.stringify(req) });
            if (result?.previewUrl) {
                window.open(this.withAdminOpenParam(result.previewUrl), '_blank');
            } else if (result?.eventId) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: { recordId: result.eventId, actionName: 'view' }
                });
            }
        } catch (e) {
            this.error = e?.body?.message || 'Could not prepare preview event.';
        } finally {
            this.isSaving = false;
        }
    }

    withAdminOpenParam(url) {
        if (!url) return url;
        const hashIndex = url.indexOf('#');
        const base = hashIndex >= 0 ? url.slice(0, hashIndex) : url;
        const hash = hashIndex >= 0 ? url.slice(hashIndex) : '';
        const sep = base.includes('?') ? '&' : '?';
        if (/[?&]adminopen=/.test(base)) return url;
        return `${base}${sep}adminopen=1${hash}`;
    }

    @wire(getPicklistValuesByRecordType, { objectApiName: '$eventObjectApiName', recordTypeId: '$selectedRecordTypeId' })
    handleRecordTypePicklists({ data }) {
        if (!data || !data.picklistFieldValues) return;
        this.picklistMeta = data.picklistFieldValues || {};
        this.applyDependencyOptions();
    }

    applyDependencyOptions() {
        const templateMeta = this.picklistMeta['summit__Template__c'];
        const eventTypeMeta = this.picklistMeta['summit__Event_Type__c'];
        const categoryMeta = this.picklistMeta['Category__c'];
        const filterCategoryMeta = this.picklistMeta['summit__Filter_Category__c'];

        const templateValues = templateMeta?.values || [];
        this.templateOptions = [{ label: '-- Select --', value: '' }, ...templateValues.map((v) => ({ label: v.label, value: v.value }))];
        if (this.form.templateId && !templateValues.some((v) => v.value === this.form.templateId)) {
            this.form = { ...this.form, templateId: '', category: '', filterCategory: '' };
        }

        const eventTypeValues = eventTypeMeta?.values || [];
        this.eventTypeOptions = [{ label: '-- Select --', value: '' }, ...eventTypeValues.map((v) => ({ label: v.label, value: v.value }))];
        if (this.form.eventType && !eventTypeValues.some((v) => v.value === this.form.eventType)) {
            this.form = { ...this.form, eventType: '', category: '', filterCategory: '' };
        }

        const categoryControllerValue = this.form.eventType;
        const filteredCategories = this.filterDependentOptions(categoryMeta, categoryControllerValue);
        this.categoryOptions = [{ label: '-- Select --', value: '' }, ...filteredCategories.map((v) => ({ label: v.label, value: v.value }))];
        if (this.form.category && !filteredCategories.some((v) => v.value === this.form.category)) {
            this.form = { ...this.form, category: '', filterCategory: '' };
        }

        const filteredFilterCategories = this.filterDependentOptions(filterCategoryMeta, this.form.category);
        this.filterCategoryOptions = filteredFilterCategories.map((v) => ({ label: v.label, value: v.value }));
        if (this.form.filterCategory) {
            const allowed = new Set(filteredFilterCategories.map((v) => v.value));
            const kept = this.filterCategoryValues.filter((v) => allowed.has(v));
            if (kept.join(';') !== this.form.filterCategory) {
                this.form = { ...this.form, filterCategory: kept.join(';') };
            }
        }
        const landingPagesValue = this.landingPagesFilterValue;
        if (this.form.websitePublishingChoice === 'yes' && landingPagesValue) {
            if (this.form.filterCategory !== landingPagesValue) {
                this.form = { ...this.form, filterCategory: landingPagesValue };
            }
        } else if (this.form.websitePublishingChoice === 'no') {
            if (this.form.filterCategory) {
                this.form = { ...this.form, filterCategory: '' };
            }
        }
    }

    filterDependentOptions(fieldMeta, controllingValue) {
        if (!fieldMeta?.values?.length) return [];
        const hasController = fieldMeta.controllerValues && Object.keys(fieldMeta.controllerValues).length > 0;
        if (!hasController) return fieldMeta.values;
        if (!controllingValue) return [];
        const controllerIndex = fieldMeta.controllerValues[controllingValue];
        if (controllerIndex === undefined || controllerIndex === null) return [];
        return fieldMeta.values.filter((entry) => (entry.validFor || []).includes(controllerIndex));
    }

    handlePreviewLoad(event) {
        const type = event.target?.dataset?.preview;
        if (type === 'banner') {
            this.previewState = { ...this.previewState, bannerLoaded: true, bannerError: false };
        } else if (type === 'logo') {
            this.previewState = { ...this.previewState, logoLoaded: true, logoError: false };
        }
    }

    handlePreviewError(event) {
        const type = event.target?.dataset?.preview;
        if (type === 'banner') {
            this.previewState = { ...this.previewState, bannerLoaded: false, bannerError: true };
        } else if (type === 'logo') {
            this.previewState = { ...this.previewState, logoLoaded: false, logoError: true };
        }
    }

    async finishCreate(createFirstInstance = true) {
        const step1Err = this.validateStep1();
        if (step1Err) {
            this.error = step1Err;
            this.step = 1;
            return;
        }
        if (createFirstInstance) {
            const step2Err = this.validateStep2();
            if (step2Err) {
                this.error = step2Err;
                return;
            }
        }

        this.error = undefined;
        this.isSaving = true;
        try {
            const req = {
                ...this.form,
                workingEventId: null,
                draftEventId: null,
                createFirstInstance,
                paymentGateway: this.form.isPaidRegistration ? this.form.paymentGateway : 'No Gateway',
                instanceStart: this.form.instanceStart ? new Date(this.form.instanceStart).toISOString() : null,
                instanceEnd: this.form.instanceEnd ? new Date(this.form.instanceEnd).toISOString() : null
            };
            const result = await createEventAndFirstInstance({ req });
            this.createdEventId = result?.eventId;
            this.createdInstanceId = result?.instanceId;
            this.isSuccess = true;
            await this.loadSuccessWarnings();
        } catch (e) {
            this.error = e?.body?.message || 'Create failed.';
        } finally {
            this.isSaving = false;
        }
    }

    openEvent() {
        this.navigateToRecord(this.createdEventId, 'view');
    }

    openInstance() {
        this.navigateToRecord(this.createdInstanceId, 'view');
    }

    addAnotherInstance() {
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: { componentName: 'c__fiuInstanceCreateWizard' },
            state: { c__eventId: this.createdEventId }
        });
    }

    returnToBrowser() {
        this[NavigationMixin.Navigate]({ type: 'standard__navItemPage', attributes: { apiName: 'fiuEventBrowser' } });
    }

    navigateToRecord(recordId, actionName) {
        if (!recordId) return;
        this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId, actionName } });
    }

    async loadSuccessWarnings() {
        this.successWarnings = [];
        if (!this.createdEventId) return;
        try {
            const readiness = await evaluateReadiness({ eventId: this.createdEventId });
            this.successWarnings = readiness?.warnings || [];
        } catch (e) {
            // Do not block success screen when readiness fetch fails.
            this.successWarnings = [];
        }
    }
}
