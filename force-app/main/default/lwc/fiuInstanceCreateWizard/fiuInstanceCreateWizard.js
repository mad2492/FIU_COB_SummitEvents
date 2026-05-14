import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getContext from '@salesforce/apex/FiuInstanceWizardService.getContext';
import saveInstance from '@salesforce/apex/FiuInstanceWizardService.saveInstance';

const CLONE_VERIFY_FIELDS = ['startDateTime', 'endDateTime', 'capacity', 'virtualMeetingLink', 'locationAddress'];

export default class FiuInstanceCreateWizard extends NavigationMixin(LightningElement) {
    isLoading = true;
    isSaving = false;
    mode = 'create';
    selectedSection = 'schedule';
    eventId;
    sourceInstanceId;
    showAdvanced = false;
    copiedFields = {};
    SECTION_ORDER = ['schedule', 'where', 'review'];

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
        buildingOverride: '',
        templateLogoOverride: '',
        eventFeeOverride: null,
        eventFeeAdditionalOverride: null,
        createDefaultReminders: false,
        reminderMode: 'NONE'
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

    get isCloneMode() {
        return this.mode === 'clone';
    }

    get titleText() {
        return this.isCloneMode ? 'Clone Instance' : 'Create New Instance';
    }

    get subtitleText() {
        return this.isCloneMode
            ? 'Review the copied setup, confirm the date and link, and create the next occurrence.'
            : 'Set the date, capacity, and delivery details people will use to register.';
    }

    get eventName() {
        return this.context?.eventName || 'Selected Event';
    }

    get accountName() {
        return this.context?.accountName || '';
    }

    get eventContextLabel() {
        const name = this.eventName;
        const acct = this.accountName;
        return acct ? `${name} • ${acct}` : name;
    }

    get isLocationVirtual() {
        return this.form.locationType === 'Online' || this.form.locationType === 'Virtual';
    }

    get hasLocationType() {
        return !!this.form.locationType;
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
        return this.context?.reminderHelpText || 'No reminder pattern was detected for this event.';
    }

    get reminderToggleLabel() {
        if (this.form.reminderMode === 'DEFAULT') return 'Create Department Reminders';
        if (this.form.reminderMode === 'SOURCE') return 'Clone Source Reminders';
        return 'Create Instance Reminders';
    }

    get reminderDisabled() {
        return this.form.reminderMode === 'NONE';
    }

    get timeZoneInlineHelp() {
        const label = this.context?.timeZoneLabel || 'Eastern Time';
        return `Times are saved as ${label}—no DST toggle needed.`;
    }

    get saveLabel() {
        if (this.isSaving) return this.isCloneMode ? 'Cloning...' : 'Creating...';
        return this.isCloneMode ? 'Clone Instance' : 'Create Instance';
    }

    get isScheduleSection() {
        return this.selectedSection === 'schedule';
    }

    get isWhereSection() {
        return this.selectedSection === 'where';
    }

    get isReviewSection() {
        return this.selectedSection === 'review';
    }

    get currentSectionMeta() {
        return this.sectionRailItems.find((item) => item.value === this.selectedSection) || this.sectionRailItems[0];
    }

    get selectedSectionIndex() {
        return this.SECTION_ORDER.indexOf(this.selectedSection);
    }

    get hasPreviousSection() {
        return this.selectedSectionIndex > 0;
    }

    get hasNextSection() {
        return this.selectedSectionIndex >= 0 && this.selectedSectionIndex < this.SECTION_ORDER.length - 1;
    }

    get sectionRailItems() {
        const items = [
            {
                value: 'schedule',
                label: 'Schedule',
                description: 'Title, date and time, capacity',
                complete: this.scheduleComplete,
                required: true
            },
            {
                value: 'where',
                label: 'Where',
                description: 'Location or virtual details',
                complete: this.whereComplete,
                required: true
            },
            {
                value: 'review',
                label: 'Review',
                description: 'Optional overrides, reminders, save',
                complete: this.scheduleComplete && this.whereComplete,
                required: false
            }
        ];
        return items.map((item, index) => {
            const isActive = item.value === this.selectedSection;
            const stateClass = item.complete ? 'is-complete' : (item.required ? '' : 'is-optional');
            return {
                ...item,
                index: index + 1,
                isActive,
                itemClass: `wizard-step ${isActive ? 'is-active' : ''}`,
                circleClass: `wizard-step__circle ${stateClass}`,
                showCheck: item.complete,
                showDash: !item.complete && !item.required,
                showNumber: !item.complete && item.required,
                ariaCurrent: isActive ? 'step' : null
            };
        });
    }

    get requiredStepsCount() {
        return this.sectionRailItems.filter((item) => item.required).length;
    }

    get completedRequiredCount() {
        return this.sectionRailItems.filter((item) => item.required && item.complete).length;
    }

    get progressLabel() {
        return `${this.completedRequiredCount} of ${this.requiredStepsCount} required complete`;
    }

    get scheduleComplete() {
        const cap = Number(this.form.capacity);
        if (!this.form.title || !(cap > 0)) return false;
        if (!this.form.startDateTime || !this.form.endDateTime) return false;
        return new Date(this.form.endDateTime) > new Date(this.form.startDateTime);
    }

    get whereComplete() {
        if (!this.form.locationType) return false;
        if (this.isLocationVirtual) return !!this.form.virtualMeetingLink;
        return !!(this.form.locationTitle && this.form.locationAddress && this.form.locationMapLink && this.form.parkingInfo);
    }

    get hasValidationErrors() {
        return this.validationErrors.length > 0;
    }

    get validationErrorCount() {
        return this.validationErrors.length;
    }

    get validationSummaryText() {
        const n = this.validationErrors.length;
        return `${n} item${n === 1 ? '' : 's'} need attention before saving.`;
    }

    get cloneVerifyChecklist() {
        if (!this.isCloneMode) return [];
        const items = [
            { key: 'datetime', label: 'Date and time of this occurrence', sectionId: 'schedule' },
            { key: 'capacity', label: 'Capacity for this occurrence', sectionId: 'schedule' }
        ];
        if (this.isLocationVirtual) {
            items.push({ key: 'link', label: 'Virtual meeting link', sectionId: 'where' });
        } else if (this.form.locationType) {
            items.push({ key: 'addr', label: 'Location address and map link', sectionId: 'where' });
        }
        return items;
    }

    get showAdvancedLabel() {
        return this.showAdvanced ? 'Hide optional overrides' : 'Show optional overrides';
    }

    get showParking() {
        return !!this.form.parkingInfo || this.parkingExpanded;
    }

    parkingExpanded = false;

    async loadContext() {
        this.isLoading = true;
        try {
            this.context = await getContext({ eventId: this.eventId, sourceInstanceId: this.sourceInstanceId });
            if (!this.eventId) this.eventId = this.context?.eventId || null;
            const next = {
                ...this.form,
                title: this.context?.title ?? this.form.title,
                shortDescription: this.context?.shortDescription ?? this.form.shortDescription,
                startDateTime: this.context?.startDateTime ?? this.form.startDateTime,
                endDateTime: this.context?.endDateTime ?? this.form.endDateTime,
                capacity: this.context?.capacity ?? this.form.capacity,
                privateInstance: this.context?.privateInstance === true,
                locationType: this.context?.locationType ?? this.form.locationType,
                locationTitle: this.context?.locationTitle ?? this.form.locationTitle,
                locationAddress: this.context?.locationAddress ?? this.form.locationAddress,
                locationMapLink: this.context?.locationMapLink ?? this.form.locationMapLink,
                parkingInfo: this.context?.parkingInfo ?? this.form.parkingInfo,
                virtualMeetingLink: this.context?.virtualMeetingLink ?? this.form.virtualMeetingLink,
                meetingId: this.context?.meetingId ?? this.form.meetingId,
                meetingPasscode: this.context?.meetingPasscode ?? this.form.meetingPasscode,
                buildingOverride: this.context?.buildingOverride ?? this.form.buildingOverride,
                templateLogoOverride: this.context?.templateLogoOverride ?? this.form.templateLogoOverride,
                eventFeeOverride: this.context?.eventFeeOverride ?? this.form.eventFeeOverride,
                eventFeeAdditionalOverride: this.context?.eventFeeAdditionalOverride ?? this.form.eventFeeAdditionalOverride,
                createDefaultReminders: this.context?.defaultCreateReminders === true,
                reminderMode: this.context?.reminderMode || 'NONE'
            };
            if (this.isCloneMode) {
                const copied = {};
                CLONE_VERIFY_FIELDS.forEach((f) => {
                    if (next[f] !== null && next[f] !== '' && next[f] !== undefined) {
                        copied[f] = true;
                    }
                });
                this.copiedFields = copied;
            }
            this.form = next;
            this.parkingExpanded = !!next.parkingInfo;
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
        if (this.copiedFields[field]) {
            this.copiedFields = { ...this.copiedFields, [field]: false };
        }
    }

    handleCheck(event) {
        const field = event.target.dataset.field;
        if (!field) return;
        this.form = { ...this.form, [field]: event.target.checked };
    }

    handleSectionClick(event) {
        const section = event.currentTarget?.dataset?.section;
        if (!section) return;
        this.selectedSection = section;
    }

    handlePreviousSection() {
        if (!this.hasPreviousSection) return;
        this.selectedSection = this.SECTION_ORDER[this.selectedSectionIndex - 1];
    }

    handleNextSection() {
        if (!this.hasNextSection) return;
        this.selectedSection = this.SECTION_ORDER[this.selectedSectionIndex + 1];
    }

    toggleAdvanced() {
        this.showAdvanced = !this.showAdvanced;
    }

    expandParking() {
        this.parkingExpanded = true;
    }

    handleJumpToFirstError() {
        this.selectFirstIncompleteSection();
    }

    validate() {
        const errors = [];
        const cap = Number(this.form.capacity);
        if (!this.eventId) errors.push('Event is required.');
        if (!this.form.title) errors.push('Instance Title is required.');
        if (!this.form.startDateTime || !this.form.endDateTime) errors.push('Start and End date/time are required.');
        if (this.form.startDateTime && this.form.endDateTime && new Date(this.form.endDateTime) <= new Date(this.form.startDateTime)) {
            errors.push('End date/time must be after Start date/time.');
        }
        if (!cap || cap <= 0) errors.push('Capacity must be greater than zero.');
        if (!this.form.locationType) errors.push('Location Type is required.');
        if (this.form.shortDescription && this.form.shortDescription.length > 255) errors.push('Instance Short Description must be 255 characters or fewer.');
        if (this.form.meetingId && this.form.meetingId.length > 100) errors.push('Meeting ID must be 100 characters or fewer.');
        if (this.form.meetingPasscode && this.form.meetingPasscode.length > 100) errors.push('Meeting Passcode must be 100 characters or fewer.');
        if (this.form.locationTitle && this.form.locationTitle.length > 255) errors.push('Location Title must be 255 characters or fewer.');
        if (this.form.locationAddress && this.form.locationAddress.length > 255) errors.push('Location Address must be 255 characters or fewer.');
        if (this.form.locationMapLink && this.form.locationMapLink.length > 255) errors.push('Map Link must be 255 characters or fewer.');
        if (this.form.virtualMeetingLink && this.form.virtualMeetingLink.length > 255) errors.push('Virtual Meeting Link must be 255 characters or fewer.');
        if (this.form.parkingInfo && this.form.parkingInfo.length > 1000) errors.push('Parking Info must be 1,000 characters or fewer.');
        if (this.form.eventFeeOverride && Number(this.form.eventFeeOverride) > 999999.99) errors.push('Event Fee Override must be 999,999.99 or less.');
        if (this.form.eventFeeAdditionalOverride && Number(this.form.eventFeeAdditionalOverride) > 999999.99) errors.push('Event Fee Additional Override must be 999,999.99 or less.');
        if (!this.isValidUrl(this.form.locationMapLink)) errors.push('Map Link must be a valid URL.');
        if (!this.isValidUrl(this.form.virtualMeetingLink)) errors.push('Virtual Meeting Link must be a valid URL.');
        if (!this.isValidUrl(this.form.templateLogoOverride)) errors.push('Template Logo Override must be a valid URL.');

        const isVirtual = this.isLocationVirtual;
        if (isVirtual) {
            if (!this.form.virtualMeetingLink) errors.push('Virtual Meeting Link is required for Online/Virtual instances.');
        } else if (this.form.locationType) {
            if (!this.form.locationTitle) errors.push('Location Title is required.');
            if (!this.form.locationAddress) errors.push('Location Address is required.');
            if (!this.form.locationMapLink) errors.push('Map Link is required.');
            if (!this.form.parkingInfo) errors.push('Parking Info is required.');
        }
        this.validationErrors = errors;
        return errors.length === 0;
    }

    selectFirstIncompleteSection() {
        const scheduleKeywords = ['Title', 'Capacity', 'date/time', 'Instance Short'];
        if (!this.scheduleComplete || this.validationErrors.some((e) => scheduleKeywords.some((k) => e.includes(k)))) {
            this.selectedSection = 'schedule';
            return;
        }
        const whereKeywords = ['Location', 'Virtual Meeting', 'Map Link', 'Meeting ID', 'Meeting Passcode', 'Parking'];
        if (!this.whereComplete || this.validationErrors.some((e) => whereKeywords.some((k) => e.includes(k)))) {
            this.selectedSection = 'where';
            return;
        }
        this.selectedSection = 'review';
    }

    async handleSave() {
        if (!this.validate()) {
            this.selectFirstIncompleteSection();
            this.notify('Almost there', `${this.validationErrors.length} item(s) still need attention.`, 'warning');
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
                    capacity: this.form.capacity !== null && this.form.capacity !== '' ? Number(this.form.capacity) : null,
                    privateInstance: this.form.privateInstance,
                    locationType: this.form.locationType,
                    locationTitle: this.form.locationTitle,
                    locationAddress: this.form.locationAddress,
                    locationMapLink: this.form.locationMapLink,
                    parkingInfo: this.form.parkingInfo,
                    virtualMeetingLink: this.form.virtualMeetingLink,
                    meetingId: this.form.meetingId,
                    meetingPasscode: this.form.meetingPasscode,
                    buildingOverride: this.form.buildingOverride,
                    templateLogoOverride: this.form.templateLogoOverride,
                    eventFeeOverride: this.form.eventFeeOverride !== null && this.form.eventFeeOverride !== '' ? Number(this.form.eventFeeOverride) : null,
                    eventFeeAdditionalOverride: this.form.eventFeeAdditionalOverride !== null && this.form.eventFeeAdditionalOverride !== '' ? Number(this.form.eventFeeAdditionalOverride) : null,
                    createDefaultReminders: this.form.createDefaultReminders && this.form.reminderMode !== 'NONE',
                    reminderMode: this.form.reminderMode
                }
            });

            const reminderMsg = result?.remindersCreated ? ` ${result.remindersCreated} reminder(s) created.` : '';
            const successTitle = this.isCloneMode ? 'Cloned' : 'Created';
            this.notify(successTitle, `Instance ${successTitle.toLowerCase()}.${reminderMsg}`, 'success');
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: result.instanceId,
                    objectApiName: 'summit__Summit_Events_Instance__c',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.notify('Error', error?.body?.message || 'Could not save the instance.', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        if (this.eventId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.eventId,
                    objectApiName: 'summit__Summit_Events__c',
                    actionName: 'view'
                }
            });
            return;
        }
        this[NavigationMixin.Navigate]({ type: 'standard__navItemPage', attributes: { apiName: 'fiuEventBrowser' } });
    }

    isValidUrl(value) {
        if (!value) return true;
        if (/\s/.test(value)) return false;
        try {
            // eslint-disable-next-line no-new
            new URL(value.includes('://') ? value : `https://${value}`);
            return true;
        } catch (e) {
            return false;
        }
    }

    getDateTimeParts(value) {
        if (!value) return null;
        const match = String(value).match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/);
        if (!match) return null;
        return {
            year: Number(match[1]),
            month: Number(match[2]),
            day: Number(match[3]),
            hour: Number(match[4]),
            minute: Number(match[5])
        };
    }

    formatDateTime(value) {
        const parts = this.getDateTimeParts(value);
        if (!parts) return null;
        const date = new Date(parts.year, parts.month - 1, parts.day);
        const dateStr = new Intl.DateTimeFormat(undefined, {
            weekday: 'short',
            month: 'short',
            day: 'numeric',
            year: 'numeric'
        }).format(date);
        const suffix = parts.hour >= 12 ? 'PM' : 'AM';
        const hour12 = parts.hour % 12 || 12;
        const timeStr = `${hour12}:${String(parts.minute).padStart(2, '0')} ${suffix}`;
        return `${dateStr}, ${timeStr}`;
    }

    get reviewSummaryRows() {
        const rows = [];
        rows.push({
            key: 'title',
            label: 'Title',
            value: this.form.title || '—',
            isMissing: !this.form.title,
            sectionId: 'schedule'
        });
        const startStr = this.formatDateTime(this.form.startDateTime);
        const endStr = this.formatDateTime(this.form.endDateTime);
        let whenValue = 'Not set';
        let whenMissing = true;
        if (startStr && endStr) {
            whenValue = `${startStr} → ${endStr}`;
            whenMissing = false;
        } else if (startStr) {
            whenValue = `${startStr} (end missing)`;
        }
        rows.push({
            key: 'when',
            label: 'When',
            value: whenValue,
            isMissing: whenMissing,
            sectionId: 'schedule'
        });
        const cap = Number(this.form.capacity);
        rows.push({
            key: 'capacity',
            label: 'Capacity',
            value: cap > 0 ? `${cap} seats` : 'Not set',
            isMissing: !(cap > 0),
            sectionId: 'schedule'
        });
        let deliveryValue = 'Not set';
        let deliveryMissing = true;
        if (this.form.locationType) {
            const detail = this.isLocationVirtual
                ? (this.form.virtualMeetingLink ? 'link provided' : 'link missing')
                : (this.form.locationTitle || 'location details missing');
            deliveryValue = `${this.form.locationType} — ${detail}`;
            deliveryMissing = this.isLocationVirtual ? !this.form.virtualMeetingLink : !this.whereComplete;
        }
        rows.push({
            key: 'delivery',
            label: 'Delivery',
            value: deliveryValue,
            isMissing: deliveryMissing,
            sectionId: 'where'
        });
        if (this.form.privateInstance) {
            rows.push({
                key: 'private',
                label: 'Visibility',
                value: 'Private (hidden from public registration)',
                isMissing: false,
                sectionId: 'schedule'
            });
        }
        return rows.map((r) => ({
            ...r,
            rowClass: `review-row ${r.isMissing ? 'is-missing' : ''}`.trim()
        }));
    }

    handleReviewJump(event) {
        const section = event.currentTarget?.dataset?.section;
        if (section) this.selectedSection = section;
    }

    notify(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get isTitleCopied() { return this.isCloneMode && !!this.copiedFields.title; }
    get isCapacityCopied() { return this.isCloneMode && !!this.copiedFields.capacity; }
    get isStartCopied() { return this.isCloneMode && !!this.copiedFields.startDateTime; }
    get isEndCopied() { return this.isCloneMode && !!this.copiedFields.endDateTime; }
    get isVirtualLinkCopied() { return this.isCloneMode && !!this.copiedFields.virtualMeetingLink; }
    get isLocationAddressCopied() { return this.isCloneMode && !!this.copiedFields.locationAddress; }
}
