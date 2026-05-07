import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import LOCATION_TYPE_FIELD from '@salesforce/schema/summit__Summit_Events_Instance__c.summit__Location_Type_Override__c';
import EVENT_NAME_FIELD from '@salesforce/schema/summit__Summit_Events_Instance__c.summit__Event__r.Name';
import TITLE_FIELD from '@salesforce/schema/summit__Summit_Events_Instance__c.summit__Instance_Title__c';

const FIELDS = [TITLE_FIELD, EVENT_NAME_FIELD, LOCATION_TYPE_FIELD];

export default class FiuInstanceWorkspace extends NavigationMixin(LightningElement) {
    @api recordId;
    record;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ data }) {
        if (data) this.record = data;
    }

    get titleValue() { return getFieldValue(this.record, TITLE_FIELD) || '---'; }
    get eventNameValue() { return getFieldValue(this.record, EVENT_NAME_FIELD) || '---'; }

    get isOnlineLocation() {
        const val = String(getFieldValue(this.record, LOCATION_TYPE_FIELD) || '').toLowerCase();
        return val === 'online' || val === 'virtual';
    }

    get showPhysicalLocation() {
        return !this.isOnlineLocation;
    }

    handleEdit() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, objectApiName: 'summit__Summit_Events_Instance__c', actionName: 'edit' }
        });
    }

    handleViewRegistrations() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuRegistrationBrowser' },
            state: { c__instanceId: this.recordId }
        });
    }
}
