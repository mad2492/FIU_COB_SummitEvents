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
    STEP1_TAB_ORDER = ['basics', 'programs', 'branding', 'logistics', 'payment', 'review'];
    FIELD_TAB_MAP = {
        eventName: 'basics',
        recordTypeId: 'basics',
        eventStatus: 'basics',
        eventType: 'basics',
        category: 'basics',
        eventStartDate: 'basics',
        eventEndDate: 'basics',
        businessUnitId: 'programs',
        selectedPlanIds: 'programs',
        templateId: 'branding',
        locationType: 'logistics',
        capacity: 'logistics',
        locationTitle: 'logistics',
        locationAddress: 'logistics',
        locationMapLink: 'logistics',
        building: 'logistics',
        paymentGateway: 'payment',
        accountingDepartmentId: 'payment',
        eventFee: 'payment'
    };

    isLoading = true;
    isSaving = false;
    error;

    step = 1;
    isSuccess = false;
    createdEventId;
    createdInstanceId;

    recordTypeOptions = [];
    eventObjectApiName;
    statusOptions = [];
    paymentGatewayOptions = [];
    locationTypeOptions = [];
    templateOptions = [];
    categoryOptions = [];
    eventTypeOptions = [];
    filterCategoryOptions = [];
    accountingDepartmentOptions = [];
    registrationEmailRestrictionOptions = [];
    eventFeeAllocationOptions = [];
    eventFeeAdditionalAllocationOptions = [];
    businessUnitOptions = [];
    programOptions = [];
    selectedStep1Tab = 'basics';

    // @track is required here because previewState is mutated via object spread.
    @track previewState = {
        bannerLoaded: false,
        bannerError: false,
        logoLoaded: false,
        logoError: false
    };
    successWarnings = [];
    picklistMeta = {};

    // @track is required here because form is mutated via object spread on every keystroke.
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
        templateLogoImage: 'https://business.fiu.edu/_assets/images/fiu-business-logo-text.svg',
        templateDisclaimerText: '',
        registerButtonText: '',
        eventHomeLinkTitle: '',
        eventHomeLinkUrl: '',
        feedRegistrationButtonText: '',
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
        privateEvent: false,
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
            { label: 'Yes - include in program landing page sections', value: 'yes' },
            { label: 'No - keep in general website listings only', value: 'no' }
        ];
    }
    get websitePublishingChoiceLabel() {
        if (this.form.websitePublishingChoice === 'yes') return 'Include in program landing page sections';
        if (this.form.websitePublishingChoice === 'no') return 'General website listings only';
        return 'Not set';
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
    get showWebsitePublishingChoice() {
        return this.form.privateEvent !== true;
    }
    get isProgramSelectionRequired() {
        return this.form.createOppsFromRegs === true;
    }
    get programsIntroCopy() {
        if (this.isProgramSelectionRequired) {
            return 'Choose the Business Unit, then select the Programs you want shown on the RSVP form. Registrants will choose one during registration, that choice will be stored on the Registration, and it will drive Opportunity creation.';
        }
        return 'Choose the Business Unit / Account this Event belongs to. Program selection is optional when registrations are not creating Opportunities.';
    }
    get programsWhyThisMattersTitle() {
        return this.isProgramSelectionRequired ? 'How recruitment routing works' : 'When Programs are optional';
    }
    get programsWhyThisMattersCopy() {
        if (this.isProgramSelectionRequired) {
            return 'The RSVP form will show only the Programs you select here. The registrant choice is stored on the Registration and used to associate the created Opportunity with the right recruitment interest.';
        }
        return 'If this Event is not creating Opportunities from registrations, the critical requirement is the Account / Business Unit. You can still preselect Programs for context, but they are not a creation blocker.';
    }
    get programSelectionMessageWhenMissing() {
        return this.isProgramSelectionRequired
            ? 'Select at least one Program when registrations create Opportunities.'
            : 'Programs are optional for events that do not create Opportunities.';
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
            this.form.capacity > 0 &&
            this.form.businessUnitId &&
            (!this.isProgramSelectionRequired || this.form.selectedPlanIds?.length)
        );
    }
    get isPreviewDisabled() {
        if (this.requiresPhysicalLocationFields) {
            return this.isSaving || !this.canPreviewRsvp || !this.form.locationTitle || !this.form.locationAddress || !this.form.locationMapLink || !this.form.building;
        }
        return this.isSaving || !this.canPreviewRsvp;
    }
    get basicsComplete() {
        if (!this.form.eventName || !this.form.recordTypeId) return false;
        if (!this.showDependentPicklists) return false;
        return !!(
            this.form.eventStatus &&
            this.form.eventStartDate &&
            this.form.eventEndDate &&
            this.form.eventStatus &&
            this.form.eventType &&
            this.form.category
        );
    }
    get programsComplete() {
        if (!this.form.businessUnitId) return false;
        if (!this.isProgramSelectionRequired) return true;
        return !!this.form.selectedPlanIds?.length;
    }
    get requiresPhysicalLocationFields() {
        const locationType = (this.form.locationType || '').toLowerCase();
        return locationType === 'on-site' || locationType === 'off-campus';
    }
    get isOnlineLocationType() {
        return (this.form.locationType || '').toLowerCase() === 'online';
    }
    get brandingComplete() {
        if (!this.showDependentPicklists) return false;
        return !!this.form.templateId;
    }
    get logisticsComplete() {
        if (!this.form.locationType) return false;
        if (!(this.form.capacity > 0)) return false;
        if (this.requiresPhysicalLocationFields) {
            return !!(this.form.locationTitle && this.form.locationAddress && this.form.locationMapLink && this.form.building);
        }
        return true;
    }
    get eventFeesComplete() {
        if (!this.form.isPaidRegistration) return true;
        return !!(this.form.paymentGateway && this.form.accountingDepartmentId && (this.form.eventFee || this.form.eventFee === 0));
    }
    get reviewComplete() { return this.canFinalizeStep1; }
    get isBasicsTab() { return this.selectedStep1Tab === 'basics'; }
    get isProgramsTab() { return this.selectedStep1Tab === 'programs'; }
    get isBrandingTab() { return this.selectedStep1Tab === 'branding'; }
    get isLogisticsTab() { return this.selectedStep1Tab === 'logistics'; }
    get isPaymentTab() { return this.selectedStep1Tab === 'payment'; }
    get isReviewTab() { return this.selectedStep1Tab === 'review'; }
    get wizardLayoutClass() {
        return 'wizard-layout';
    }
    get firstSuccessWarning() { return this.successWarnings?.length ? this.successWarnings[0] : ''; }
    get hasValidationErrors() { return this.validationErrors.length > 0; }
    get hasValidationWarnings() { return this.validationWarningsForRail.length > 0; }
    get validationErrorCount() { return this.validationErrors.length; }
    get validationWarningCount() { return this.validationWarningsForRail.length; }
    get currentStepValidationErrors() {
        return this.buildRequiredFieldReport()
            .filter((item) => item.tab === this.selectedStep1Tab)
            .map((item) => item.message);
    }
    get hasCurrentStepValidationErrors() { return this.currentStepValidationErrors.length > 0; }
    get hasSuccessWarnings() { return this.successWarnings.length > 0; }
    get selectedStep1TabIndex() { return this.STEP1_TAB_ORDER.indexOf(this.selectedStep1Tab); }
    get hasPrevTab() { return this.selectedStep1TabIndex > 0; }
    get hasNextTab() { return this.selectedStep1TabIndex >= 0 && this.selectedStep1TabIndex < this.STEP1_TAB_ORDER.length - 1; }
    get canFinalizeStep1() {
        return this.buildRequiredFieldReport().length === 0;
    }
    get finalizeStep1Disabled() {
        return this.isSaving || !this.canFinalizeStep1;
    }
    get currentStepMeta() {
        return this.stepRailItems.find((item) => item.value === this.selectedStep1Tab) || this.stepRailItems[0];
    }
    get stepRailItems() {
        const items = [
            { value: 'basics', label: 'Basics', description: 'Name, record type, dates, type', complete: this.basicsComplete },
            { value: 'programs', label: 'Programs', description: 'Business unit and program routing', complete: this.programsComplete },
            { value: 'branding', label: 'Branding', description: 'Template, images, page copy', complete: this.brandingComplete },
            { value: 'logistics', label: 'Logistics', description: 'Location, capacity, operations', complete: this.logisticsComplete },
            { value: 'payment', label: 'Payment', description: 'Gateway, accounting, fees', complete: this.eventFeesComplete },
            { value: 'review', label: 'Review', description: 'Check readiness before create', complete: this.reviewComplete }
        ];
        return items.map((item, index) => {
            const isActive = item.value === this.selectedStep1Tab;
            const isCompleted = item.complete && index < this.selectedStep1TabIndex;
            const isFailed = !item.complete && index < this.selectedStep1TabIndex;
            const progress = ((index + 1) / items.length) * 100;
            return {
                ...item,
                index: index + 1,
                isActive,
                isCompleted,
                isFailed,
                ariaCurrent: isActive && this.isStep1 ? 'step' : 'false',
                itemClass: `wizard-step ${isActive ? 'is-active' : ''}`,
                circleClass: `wizard-step__circle ${isCompleted ? 'is-complete' : ''} ${isFailed ? 'is-failed' : ''}`,
                stateText: item.complete ? 'Complete' : (isFailed ? 'Needs attention' : 'In progress'),
                progressValue: Math.round(progress),
                progressStyle: `width:${progress}%`
            };
        });
    }
    get validationErrors() {
        return this.buildRequiredFieldReport().map((item) => item.message);
    }
    get validationWarningsForRail() {
        const warnings = [];
        if (!this.form.templateBannerImage) warnings.push('Banner image is not set yet.');
        if (!this.form.templateLogoImage) warnings.push('Logo image is not set yet.');
        if (!this.form.confirmationTitle && !this.form.confirmationDescription) warnings.push('Confirmation page content still uses defaults/blank values.');
        if (!this.form.createOppsFromRegs) warnings.push('Create Opportunities from Registrations is off.');
        if (!this.form.sendRegistrationConfirmation) warnings.push('Registration confirmation email is off.');
        return warnings;
    }
    get previewRecordTypeLabel() {
        return this.recordTypeOptions.find((opt) => opt.value === this.form.recordTypeId)?.label || 'Select a record type';
    }
    get previewTemplateLabel() {
        return this.templateOptions.find((opt) => opt.value === this.form.templateId)?.label || 'Select a template';
    }
    get previewProgramsLabel() {
        if (!this.form.selectedPlanIds?.length) return 'No programs selected';
        const labels = this.programOptions
            .filter((opt) => this.form.selectedPlanIds.includes(opt.value))
            .map((opt) => opt.label);
        if (labels.length <= 2) {
            return labels.join(', ');
        }
        const remainingCount = labels.length - 2;
        return `${labels[0]}, ${labels[1]}, and ${remainingCount} more`;
    }
    get previewLocationLabel() {
        if (!this.form.locationType) return 'Location type not chosen';
        if (this.requiresPhysicalLocationFields) {
            return this.form.locationTitle || 'Physical location details needed';
        }
        if (this.isOnlineLocationType) {
            return 'Online event';
        }
        return this.form.locationType;
    }
    get summaryEventName() {
        return this.form.eventName || '';
    }
    get hasSummaryEventName() {
        return !!this.summaryEventName;
    }
    get hasSummaryTags() {
        return this.summaryTags.length > 0;
    }
    get summaryTags() {
        return [
            { key: 'recordType', label: this.previewRecordTypeLabel, show: !!this.form.recordTypeId },
            { key: 'eventType', label: this.form.eventType, show: !!this.form.eventType },
            { key: 'category', label: this.form.category, show: !!this.form.category }
        ].filter((item) => item.show);
    }
    get summaryFacts() {
        const locationTypeLabel = this.form.locationType || 'Location';
        const locationValue = !this.form.locationType
            ? null
            : (this.isOnlineLocationType ? 'Virtual' : (this.form.locationTitle || null));
        const capacityValue = this.form.capacity || this.form.capacity === 0
            ? (Number(this.form.capacity) > 0 ? `${this.form.capacity} seats${this.form.waitlist ? ' - waitlist' : ''}` : null)
            : null;
        let pricingValue = this.summaryHasStarted ? 'Free' : null;
        if (this.form.isPaidRegistration) {
            pricingValue = (this.form.eventFee || this.form.eventFee === 0)
                ? `$${this.form.eventFee}`
                : 'Paid (price TBD)';
        }
        const programCount = this.form.selectedPlanIds?.length || 0;
        return [
            {
                key: 'window',
                icon: 'utility:date_input',
                label: 'Window',
                value: this.form.eventStartDate
                    ? (this.form.eventEndDate && this.form.eventEndDate !== this.form.eventStartDate
                        ? `${this.form.eventStartDate} -> ${this.form.eventEndDate}`
                        : this.form.eventStartDate)
                    : null
            },
            {
                key: 'location',
                icon: 'utility:location',
                label: locationTypeLabel,
                value: locationValue
            },
            {
                key: 'capacity',
                icon: 'utility:people',
                label: 'Capacity',
                value: capacityValue
            },
            {
                key: 'programs',
                icon: 'utility:apps',
                label: 'Programs',
                value: programCount ? `${programCount} program${programCount === 1 ? '' : 's'} routed` : null
            },
            {
                key: 'pricing',
                icon: 'utility:moneybag',
                label: 'Pricing',
                value: pricingValue
            },
            {
                key: 'template',
                icon: 'utility:brush',
                label: 'Template',
                value: this.form.templateId ? this.previewTemplateLabel : null
            }
        ];
    }
    get summaryFlags() {
        if (!this.summaryHasStarted) return [];
        const flags = [{ key: 'public', label: 'Public registration' }];
        if (this.form.createOppsFromRegs) flags.push({ key: 'opps', label: 'Creates Opportunities' });
        if (this.form.isPaidRegistration) flags.push({ key: 'paid', label: 'Paid event' });
        if (this.form.waitlist) flags.push({ key: 'waitlist', label: 'Waitlist enabled' });
        const locationType = (this.form.locationType || '').toLowerCase();
        if (locationType === 'on-site' && this.form.locationTitle) {
            flags.push({ key: 'onsite', label: `On-site at ${this.form.locationTitle.split(',')[0].trim()}` });
        }
        if (locationType === 'virtual' || locationType === 'hybrid' || locationType === 'online') {
            flags.push({ key: 'virtual', label: 'Virtual attendance' });
        }
        return flags;
    }
    get hasSummaryFlags() {
        return this.summaryFlags.length > 0;
    }
    get summaryHasStarted() {
        return !!(
            this.form.eventName ||
            this.form.recordTypeId ||
            this.form.templateId ||
            this.form.eventType ||
            this.form.category ||
            this.form.locationType ||
            this.form.businessUnitId
        );
    }
    get summaryStepChecks() {
        const programCount = this.form.selectedPlanIds?.length || 0;
        const paymentSkip = !this.form.isPaidRegistration && this.summaryHasStarted;
        return [
            {
                key: 'identity',
                label: 'Identity',
                ok: !!(this.form.eventName && this.form.recordTypeId && this.form.templateId),
                skip: false,
                count: '',
                tab: 'basics'
            },
            {
                key: 'programs',
                label: 'Programs',
                ok: programCount > 0,
                skip: false,
                count: programCount > 0 ? String(programCount) : '',
                tab: 'programs'
            },
            {
                key: 'branding',
                label: 'Branding',
                ok: !!this.form.templateId,
                skip: false,
                count: '',
                tab: 'branding'
            },
            {
                key: 'logistics',
                label: 'Logistics',
                ok: !!(this.form.locationType && Number(this.form.capacity) > 0),
                skip: false,
                count: '',
                tab: 'logistics'
            },
            {
                key: 'payment',
                label: 'Payment',
                ok: !!(this.form.isPaidRegistration && this.form.paymentGateway && (this.form.eventFee || this.form.eventFee === 0)),
                skip: paymentSkip,
                count: paymentSkip ? 'n/a' : '',
                tab: 'payment'
            }
        ].map((item) => ({
            ...item,
            dotClass: `summary-step__dot${item.ok || item.skip ? (item.skip ? ' is-skip' : ' is-complete') : ''}`,
            rowClass: `summary-step${item.skip ? ' is-skip' : ''}`
        }));
    }
    get summaryProgressPct() {
        const steps = this.summaryStepChecks;
        const total = steps.length;
        const completed = steps.filter((item) => item.ok || item.skip).length;
        return total ? Math.round((completed / total) * 100) : 0;
    }
    get summaryProgressStyle() {
        return `width:${this.summaryProgressPct}%`;
    }
    get summaryProgressClass() {
        return this.summaryProgressPct === 100 ? 'is-complete' : '';
    }
    get summaryProgressFillClass() {
        return `summary-progress-track__fill ${this.summaryProgressClass}`.trim();
    }
    get showDetailedValidationRail() {
        return this.selectedStep1TabIndex >= 2 || this.validationErrorCount <= 2;
    }
    get showValidationRailSection() {
        return this.showDetailedValidationRail || this.hasCurrentStepValidationErrors;
    }
    get validationSummaryVariantClass() {
        if (this.hasValidationErrors) return 'validation-summary validation-summary--error';
        if (this.hasValidationWarnings) return 'validation-summary validation-summary--warning';
        return 'validation-summary validation-summary--ok';
    }
    get validationSummaryTitle() {
        if (this.hasValidationErrors) {
            return `${this.validationErrorCount} required item${this.validationErrorCount === 1 ? '' : 's'} still need setup`;
        }
        if (this.hasValidationWarnings) {
            return `${this.validationWarningCount} recommended item${this.validationWarningCount === 1 ? '' : 's'} to review`;
        }
        return 'Required fields for Event creation are currently satisfied.';
    }
    get validationSummaryBody() {
        if (this.hasValidationErrors) {
            return 'Keep going. The full checklist will appear here once you are a little further into the build.';
        }
        if (this.hasValidationWarnings) {
            return 'Nothing is blocking creation yet. These are optional refinements you can revisit later.';
        }
        return '';
    }
    get currentHelpTitle() {
        const helpByStep = {
            basics: 'Start with the event frame',
            programs: 'Programs drive routing',
            branding: 'Template controls the experience',
            logistics: 'Instances inherit a lot from this',
            payment: 'Paid events need complete setup',
            review: 'Readiness before creation'
        };
        return helpByStep[this.selectedStep1Tab];
    }
    get currentHelpBody() {
        const helpByStep = {
            basics: 'Choose the parent event setup carefully. Record Type, Event Type, and Category affect downstream behavior and what users will see.',
            programs: this.isProgramSelectionRequired
                ? 'For recruitment events, the Programs you choose here become the choices shown on the RSVP form. The registrant selection is stored on the Registration and used when the Opportunity is created.'
                : 'For non-recruitment events, the key requirement is the Business Unit / Account. Programs can still add context, but they are not required when registrations are not creating Opportunities.',
            branding: 'The RSVP template is the foundation of the public registration page. Images and copy layer on top of that template.',
            logistics: 'Location, capacity, private/public visibility, and publishing choices shape what the first Instance can actually do once it is created.',
            payment: 'If this is paid, admins need gateway and accounting details before the public registration/payment flow will work.',
            review: 'Use this last pass to catch missing setup before moving into first-instance creation or saving the event on its own.'
        };
        return helpByStep[this.selectedStep1Tab];
    }
    get basicsSummaryItems() {
        return [
            { label: 'Event Name', value: this.form.eventName || 'Not set' },
            { label: 'Record Type', value: this.previewRecordTypeLabel },
            { label: 'Status', value: this.form.eventStatus || 'Not set' },
            { label: 'Dates', value: this.form.eventStartDate && this.form.eventEndDate ? `${this.form.eventStartDate} to ${this.form.eventEndDate}` : 'Not set' },
            { label: 'Event Type', value: this.form.eventType || 'Not set' },
            { label: 'Category', value: this.form.category || 'Not set' }
        ];
    }
    get programSummaryItems() {
        return [
            { label: 'Business Unit', value: this.businessUnitOptions.find((opt) => opt.value === this.form.businessUnitId)?.label || 'Not set' },
            { label: 'Programs Required', value: this.isProgramSelectionRequired ? 'Yes' : 'No' },
            { label: 'Programs', value: this.previewProgramsLabel }
        ];
    }
    get brandingSummaryItems() {
        return [
            { label: 'Template', value: this.previewTemplateLabel },
            { label: 'Banner Image', value: this.form.templateBannerImage ? 'Set' : 'Not set' },
            { label: 'Logo Image', value: this.form.templateLogoImage ? 'Set' : 'Not set' },
            { label: 'Register Button Text', value: this.form.registerButtonText || 'Default / blank' },
            { label: 'Feed Button Text', value: this.form.feedRegistrationButtonText || 'Default / blank' },
            { label: 'Event Home Link', value: this.form.eventHomeLinkUrl || 'Not set' }
        ];
    }
    get logisticsSummaryItems() {
        return [
            { label: 'Location Type', value: this.form.locationType || 'Not set' },
            { label: 'Primary Venue', value: this.previewLocationLabel },
            { label: 'Capacity', value: Number(this.form.capacity) > 0 ? String(this.form.capacity) : 'Not set' },
            { label: 'Private Event', value: this.form.privateEvent ? 'Yes' : 'No' },
            { label: 'Website Publish', value: this.form.privateEvent ? 'Not applicable while private' : this.websitePublishingChoiceLabel }
        ];
    }
    get paymentSummaryItems() {
        return [
            { label: 'Paid Registration', value: this.form.isPaidRegistration ? 'Yes' : 'No' },
            { label: 'Payment Gateway', value: this.form.paymentGateway || 'Not set' },
            { label: 'Accounting Department', value: this.accountingDepartmentOptions.find((opt) => opt.value === this.form.accountingDepartmentId)?.label || 'Not set' },
            { label: 'Event Fee', value: this.form.eventFee || this.form.eventFee === 0 ? String(this.form.eventFee) : 'Not set' }
        ];
    }
    get step1TabStatuses() {
        return this.stepRailItems;
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
        if (key === 'privateEvent' && nextValue === true) {
            this.form = {
                ...this.form,
                privateEvent: true,
                websitePublishingChoice: '',
                filterCategory: ''
            };
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
        if (!tab) return;
        if (this.isStep2) {
            this.step = 1;
            this.error = undefined;
        }
        this.setSelectedStep1Tab(tab);
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
        this.selectedStep1Tab = nextTab;
        this.scrollToCurrentStepTop();
    }

    scrollToCurrentStepTop() {
        requestAnimationFrame(() => {
            const anchor = this.template.querySelector('[data-step-anchor]');
            if (anchor) {
                anchor.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
            const heading = this.template.querySelector('[data-step-heading]');
            if (heading && typeof heading.focus === 'function') {
                heading.focus();
            }
        });
    }

    async handleBusinessUnitChange(event) {
        const businessUnitId = event.detail.value || '';
        await this.setBusinessUnitAndPrograms(businessUnitId);
    }

    async handleProgramSelectionChange(event) {
        const selectedPlanIds = event.detail.value || [];
        this.form = { ...this.form, selectedPlanIds };
    }

    handleSummaryStepJump(event) {
        const tab = event.currentTarget?.dataset?.tab;
        if (!tab) return;
        this.step = 1;
        this.setSelectedStep1Tab(tab);
        this.error = undefined;
    }

    async setBusinessUnitAndPrograms(businessUnitId) {
        this.form = { ...this.form, businessUnitId, accountId: businessUnitId || '', selectedPlanIds: [] };
        this.programOptions = [];
        if (businessUnitId) {
            const options = await getProgramsForBusinessUnit({ businessUnitId });
            this.programOptions = options.map((o) => ({ label: o.label, value: o.value, code: o.code }));
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

    buildRequiredFieldReport() {
        const report = [];
        const add = (condition, field, message, validateMessage = 'Some required fields are missing. We highlighted them for you.') => {
            if (!condition) return;
            report.push({
                field,
                message,
                validateMessage,
                tab: this.FIELD_TAB_MAP[field] || 'basics'
            });
        };

        add(!this.form.eventName, 'eventName', 'Event name is required.');
        add(!this.form.recordTypeId, 'recordTypeId', 'Record Type is required.');
        add(!this.form.eventStatus, 'eventStatus', 'Event Status is required.');
        add(!this.form.eventStartDate, 'eventStartDate', 'Event Start Date is required.');
        add(!this.form.eventEndDate, 'eventEndDate', 'Event End Date is required.');
        add(!this.form.eventType, 'eventType', 'Event Type is required.');
        add(!this.form.category, 'category', 'Category is required.');
        add(!this.form.businessUnitId, 'businessUnitId', 'Business Unit is required.');
        add(
            this.isProgramSelectionRequired && !this.form.selectedPlanIds?.length,
            'selectedPlanIds',
            'Select at least one Program when registrations create Opportunities.'
        );
        add(!this.form.templateId, 'templateId', 'Template is required.');
        add(!this.form.locationType, 'locationType', 'Location Type is required.');
        add(
            this.form.capacity === null || this.form.capacity === '' || Number(this.form.capacity) <= 0,
            'capacity',
            'Capacity must be greater than 0.',
            'Capacity must be greater than 0 before this Event can be previewed or created.'
        );
        if (this.requiresPhysicalLocationFields) {
            add(!this.form.locationTitle, 'locationTitle', 'Location Title is required for this location type.');
            add(!this.form.locationAddress, 'locationAddress', 'Location Address is required for this location type.');
            add(!this.form.locationMapLink, 'locationMapLink', 'Location Map Link is required for this location type.');
            add(!this.form.building, 'building', 'Building is required for this location type.');
        }
        if (this.form.isPaidRegistration) {
            add(!this.form.paymentGateway, 'paymentGateway', 'Paid events require a Payment Gateway.');
            add(!this.form.accountingDepartmentId, 'accountingDepartmentId', 'Paid events require an Accounting Department.');
            add(
                !this.form.eventFee && this.form.eventFee !== 0,
                'eventFee',
                'Event Fee is required for paid events.',
                'Event Fee is required for paid registration events.'
            );
        }
        return report;
    }

    validateStep1() {
        const report = this.buildRequiredFieldReport();
        const firstError =
            report.find((item) => item.field === 'eventFee') ||
            report.find((item) => item.field === 'capacity') ||
            report[0];
        if (!firstError) return null;

        const targetTab = firstError.tab;
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

        return firstError.validateMessage;
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
            const result = await previewEventJson({ reqJson: JSON.stringify(req) });
            const previewUrl = this.extractPreviewUrl(result?.previewUrl);
            if (previewUrl) {
                window.open(this.withAdminOpenParam(previewUrl), '_blank');
            } else {
                this.error = 'Preview registration link could not be generated yet. Make sure the preview instance was created successfully and has an Admin Open Registration URL.';
            }
        } catch (e) {
            this.error = e?.body?.message || 'Could not prepare preview event.';
        } finally {
            this.isSaving = false;
        }
    }

    extractPreviewUrl(rawValue) {
        if (!rawValue) return null;
        const trimmedValue = String(rawValue).trim();
        if (!trimmedValue.toLowerCase().startsWith('<a')) {
            return this.decodeHtmlEntities(trimmedValue);
        }
        const doubleQuoteMatch = trimmedValue.match(/href\s*=\s*"([^"]+)"/i);
        if (doubleQuoteMatch?.[1]) return this.decodeHtmlEntities(doubleQuoteMatch[1]);
        const singleQuoteMatch = trimmedValue.match(/href\s*=\s*'([^']+)'/i);
        if (singleQuoteMatch?.[1]) return this.decodeHtmlEntities(singleQuoteMatch[1]);
        return null;
    }

    withAdminOpenParam(url) {
        if (!url) return url;
        const normalizedUrl = this.decodeHtmlEntities(String(url));
        const hashIndex = normalizedUrl.indexOf('#');
        const base = hashIndex >= 0 ? normalizedUrl.slice(0, hashIndex) : normalizedUrl;
        const hash = hashIndex >= 0 ? normalizedUrl.slice(hashIndex) : '';
        const sep = base.includes('?') ? '&' : '?';
        if (/[?&]adminopen=/.test(base)) return `${base}${hash}`;
        return `${base}${sep}adminopen=1${hash}`;
    }

    decodeHtmlEntities(value) {
        return String(value)
            .replace(/&amp;/gi, '&')
            .replace(/&quot;/gi, '"')
            .replace(/&#39;/gi, "'")
            .replace(/&lt;/gi, '<')
            .replace(/&gt;/gi, '>');
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
