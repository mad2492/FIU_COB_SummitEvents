import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getContext from '@salesforce/apex/FiuInstanceWizardService.getContext';
import saveInstance from '@salesforce/apex/FiuInstanceWizardService.saveInstance';

export default class FiuInstanceCreateWizard extends NavigationMixin(LightningElement) {
    isLoading = true;
    isSaving = false;
    mode = 'create';
    eventId;
    sourceInstanceId;

    form = {
        title: '',
        shortDescription: '',
        startDateTime: null,
        endDateTime: null,
        capacity: null,
        privateInstance: false,
        locationType: '',
        locationTitle: '',
        locationAddress: '',
        locationMapLink: '',
        parkingInfo: '',
        virtualMeetingLink: '',
        meetingId: '',
        meetingPasscode: '',
        templateLogoOverride: '',
        feedButtonTextOverride: '',
        eventFeeOverride: null,
        eventFeeAdditionalOverride: null,
        eventFeeAllocationOverrideId: null,
        eventFeeAdditionalAllocationOverrideId: null,
        campaignOverrideId: null,
        createDefaultReminders: false
    };

    context = {};
    validationErrors = [];

    @wire(CurrentPageReference)
    setPageRef(pageRef) {
        const state = pageRef?.state || {};
        this.eventId = state.c__eventId || null;
        this.sourceInstanceId = state.c__sourceInstanceId || null;
        this.mode = this.sourceInstanceId ? 'clone' : (state.c__mode || 'create');
        this.loadContext();
    }

    get titleText() {
        return this.mode === 'clone' ? 'Clone Instance' : 'Create New Instance';
    }

    get subtitleText() {
        return this.mode === 'clone'
            ? 'Review and adjust the cloned setup before creating the new instance.'
            : 'Capture scheduling, capacity, and communication overrides before publishing.';
    }

    get eventName() {
        return this.context?.eventName || 'Selected Event';
    }

    get accountName() {
        return this.context?.accountName || '';
    }

    get isLocationVirtual() {
        return this.form.locationType === 'Online' || this.form.locationType === 'Virtual';
    }

    get canCloneReminders() {
        return this.mode === 'clone' && this.context?.canCloneReminders;
    }

    get locationTypeOptions() {
        return [
            { label: '-- Select --', value: '' },
            { label: 'On-site', value: 'On-site' },
            { label: 'Online', value: 'Online' },
            { label: 'Virtual', value: 'Virtual' },
            { label: 'Hybrid', value: 'Hybrid' }
        ];
    }

    get reminderHelpText() {
        if (!this.canCloneReminders) return 'Create default reminders for this new instance.';
        return `Clone ${this.context?.sourceReminderCount || 0} reminder record(s) from the source instance.`;
    }

    async loadContext() {
        this.isLoading = true;
        try {
            this.context = await getContext({ eventId: this.eventId, sourceInstanceId: this.sourceInstanceId });
            if (!this.eventId) this.eventId = this.context?.eventId || null;
            this.form = {
                ...this.form,
                title: this.context?.title || this.form.title,
                shortDescription: this.context?.shortDescription || this.form.shortDescription,
                startDateTime: this.context?.startDateTime || this.form.startDateTime,
                endDateTime: this.context?.endDateTime || this.form.endDateTime,
                capacity: this.context?.capacity || this.form.capacity,
                privateInstance: this.context?.privateInstance === true,
                locationType: this.context?.locationType || this.form.locationType,
                locationTitle: this.context?.locationTitle || this.form.locationTitle,
                locationAddress: this.context?.locationAddress || this.form.locationAddress,
                locationMapLink: this.context?.locationMapLink || this.form.locationMapLink,
                parkingInfo: this.context?.parkingInfo || this.form.parkingInfo,
                virtualMeetingLink: this.context?.virtualMeetingLink || this.form.virtualMeetingLink,
                meetingId: this.context?.meetingId || this.form.meetingId,
                meetingPasscode: this.context?.meetingPasscode || this.form.meetingPasscode,
                templateLogoOverride: this.context?.templateLogoOverride || this.form.templateLogoOverride,
                feedButtonTextOverride: this.context?.feedButtonTextOverride || this.form.feedButtonTextOverride,
                eventFeeOverride: this.context?.eventFeeOverride || this.form.eventFeeOverride,
                eventFeeAdditionalOverride: this.context?.eventFeeAdditionalOverride || this.form.eventFeeAdditionalOverride,
                eventFeeAllocationOverrideId: this.context?.eventFeeAllocationOverrideId || this.form.eventFeeAllocationOverrideId,
                eventFeeAdditionalAllocationOverrideId: this.context?.eventFeeAdditionalAllocationOverrideId || this.form.eventFeeAdditionalAllocationOverrideId,
                campaignOverrideId: this.context?.campaignOverrideId || this.form.campaignOverrideId
            };
        } catch (error) {
            this.notify('Error', error?.body?.message || 'Could not load instance context.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        if (!field) return;
        this.form = { ...this.form, [field]: event.detail?.value ?? event.target.value };
    }

    handleCheck(event) {
        const field = event.target.dataset.field;
        if (!field) return;
        this.form = { ...this.form, [field]: event.target.checked };
    }

    validate() {
        const errors = [];
        const cap = Number(this.form.capacity);
        if (!this.eventId) errors.push('Event is required.');
        if (!this.form.startDateTime || !this.form.endDateTime) errors.push('Start and End date/time are required.');
        if (this.form.startDateTime && this.form.endDateTime && new Date(this.form.endDateTime) <= new Date(this.form.startDateTime)) {
            errors.push('End date/time must be after Start date/time.');
        }
        if (!cap || cap <= 0) errors.push('Capacity must be greater than zero.');
        if (!this.form.locationType) errors.push('Location Type Override is required.');

        const isVirtual = this.isLocationVirtual;
        if (isVirtual) {
            if (!this.form.virtualMeetingLink) errors.push('Virtual Meeting Link is required for Online/Virtual instances.');
        } else {
            if (!this.form.locationTitle) errors.push('Location Title Override is required.');
            if (!this.form.locationAddress) errors.push('Location Address Override is required.');
            if (!this.form.locationMapLink) errors.push('Location Map Link Override is required.');
            if (!this.form.parkingInfo) errors.push('Parking Info is required.');
        }
        this.validationErrors = errors;
        return errors.length === 0;
    }

    async handleSave() {
        if (!this.validate()) {
            this.notify('Missing required items', `Please resolve ${this.validationErrors.length} required item(s).`, 'error');
            return;
        }
        this.isSaving = true;
        try {
            const result = await saveInstance({
                req: {
                    eventId: this.eventId,
                    sourceInstanceId: this.sourceInstanceId,
                    mode: this.mode,
                    title: this.form.title,
                    shortDescription: this.form.shortDescription,
                    startDateTime: this.form.startDateTime,
                    endDateTime: this.form.endDateTime,
                    capacity: this.form.capacity ? Number(this.form.capacity) : null,
                    privateInstance: this.form.privateInstance,
                    locationType: this.form.locationType,
                    locationTitle: this.form.locationTitle,
                    locationAddress: this.form.locationAddress,
                    locationMapLink: this.form.locationMapLink,
                    parkingInfo: this.form.parkingInfo,
                    virtualMeetingLink: this.form.virtualMeetingLink,
                    meetingId: this.form.meetingId,
                    meetingPasscode: this.form.meetingPasscode,
                    templateLogoOverride: this.form.templateLogoOverride,
                    feedButtonTextOverride: this.form.feedButtonTextOverride,
                    eventFeeOverride: this.form.eventFeeOverride ? Number(this.form.eventFeeOverride) : null,
                    eventFeeAdditionalOverride: this.form.eventFeeAdditionalOverride ? Number(this.form.eventFeeAdditionalOverride) : null,
                    eventFeeAllocationOverrideId: this.form.eventFeeAllocationOverrideId || null,
                    eventFeeAdditionalAllocationOverrideId: this.form.eventFeeAdditionalAllocationOverrideId || null,
                    campaignOverrideId: this.form.campaignOverrideId || null,
                    createDefaultReminders: this.form.createDefaultReminders
                }
            });

            const reminderMsg = result?.remindersCreated ? ` ${result.remindersCreated} reminder(s) created.` : '';
            this.notify('Success', `Instance created.${reminderMsg}`, 'success');
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: result.instanceId,
                    objectApiName: 'summit__Summit_Events_Instance__c',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.notify('Error', error?.body?.message || 'Could not create the instance.', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    notify(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
