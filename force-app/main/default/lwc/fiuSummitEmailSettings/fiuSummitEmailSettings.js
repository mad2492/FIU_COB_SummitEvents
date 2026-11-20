import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import getSettings from '@salesforce/apex/FIU_SummitEmailSettingsController.getSettings';
import saveSelection from '@salesforce/apex/FIU_SummitEmailSettingsController.saveSelection';

const NONE_OPTION = { label: '-- None --', value: '' };

export default class FiuSummitEmailSettings extends LightningElement {
    _recordId;
    hasConnected = false;
    loadRequest = 0;
    hasSettings = false;
    selectedOrgWideEmailId = '';
    selectedLetterheadId = '';
    currentOrgWideEmail = '';
    currentLetterhead = '';
    orgWideEmails;
    letterheads;
    isLoading = false;
    isSaving = false;
    loadError;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        if (this._recordId === value) {
            return;
        }
        this._recordId = value;
        if (this.hasConnected) {
            this.loadSettings();
        }
    }

    connectedCallback() {
        this.hasConnected = true;
        if (this.recordId) {
            this.loadSettings();
        }
    }

    get orgWideEmailOptions() {
        return [NONE_OPTION, ...(this.orgWideEmails || []).map((option) => ({
            label: option.label,
            value: option.value
        }))];
    }

    get letterheadOptions() {
        return [NONE_OPTION, ...(this.letterheads || []).map((option) => ({
            label: option.label,
            value: option.value
        }))];
    }

    get senderDisabled() {
        return this.isSaving || !this.orgWideEmails;
    }

    get letterheadDisabled() {
        return this.isSaving || !this.letterheads;
    }

    get senderChoicesUnavailable() {
        return !this.orgWideEmails;
    }

    get letterheadChoicesUnavailable() {
        return !this.letterheads;
    }

    get currentOrgWideEmailText() {
        return this.currentOrgWideEmail ? `Currently selected: ${this.currentOrgWideEmail}` : 'Currently selected: None';
    }

    get currentLetterheadText() {
        return this.currentLetterhead ? `Currently selected: ${this.currentLetterhead}` : 'Currently selected: None';
    }

    async loadSettings() {
        const recordId = this.recordId;
        const request = ++this.loadRequest;
        this.hasSettings = false;
        this.isLoading = Boolean(recordId);
        this.loadError = undefined;
        if (!recordId) {
            return;
        }

        try {
            const settings = await getSettings({ recordId });
            if (request === this.loadRequest) {
                this.applySavedSettings(settings);
                this.orgWideEmails = settings.orgWideEmails;
                this.letterheads = settings.letterheads;
                this.hasSettings = true;
            }
        } catch {
            if (request === this.loadRequest) {
                this.loadError = 'Unable to load saved email settings.';
            }
        } finally {
            if (request === this.loadRequest) {
                this.isLoading = false;
            }
        }
    }

    handleOrgWideEmailChange(event) {
        if (!this.senderDisabled) {
            this.persistSelection('orgWideEmail', event.detail.value);
        }
    }

    handleLetterheadChange(event) {
        if (!this.letterheadDisabled) {
            this.persistSelection('letterhead', event.detail.value);
        }
    }

    async persistSelection(setting, selectionId) {
        const recordId = this.recordId;
        const request = this.loadRequest;
        this.isSaving = true;

        try {
            const settings = await saveSelection({ recordId, setting, selectionId });
            if (request === this.loadRequest) {
                this.applySavedSettings(settings);
            }
        } catch (error) {
            if (request === this.loadRequest) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Unable to save email settings',
                    message: this.reduceError(error),
                    variant: 'error'
                }));
                await this.loadSettings();
            }
            return;
        } finally {
            this.isSaving = false;
        }

        try {
            await notifyRecordUpdateAvailable([{ recordId }]);
        } catch {
            if (request === this.loadRequest) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Email settings saved',
                    message: 'Refresh the page to update the rest of the record.',
                    variant: 'warning'
                }));
            }
        }
    }

    applySavedSettings(settings) {
        this.selectedOrgWideEmailId = settings.orgWideEmailId || '';
        this.selectedLetterheadId = settings.letterheadId || '';
        this.currentOrgWideEmail = settings.orgWideEmailAddress || '';
        this.currentLetterhead = settings.letterheadName || '';
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unexpected error';
    }
}
