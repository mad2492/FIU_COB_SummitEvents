import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

const FIELDS = [
    'summit__Summit_Events_Instance__c.summit__Instance_Title__c',
    'summit__Summit_Events_Instance__c.summit__Event__r.Name',
    'summit__Summit_Events_Instance__c.summit__Instance_Start_Date__c',
    'summit__Summit_Events_Instance__c.summit__Instance_Start_Time__c',
    'summit__Summit_Events_Instance__c.summit__Instance_End_Date__c',
    'summit__Summit_Events_Instance__c.summit__Instance_End_Time__c',
    'summit__Summit_Events_Instance__c.summit__Instance_Time_Zone__c',
    'summit__Summit_Events_Instance__c.summit__Location_Type_Override__c',
    'summit__Summit_Events_Instance__c.summit__Location_Title_Override__c',
    'summit__Summit_Events_Instance__c.summit__Location_Address_Override__c',
    'summit__Summit_Events_Instance__c.summit__Location_Map_Link_Override__c',
    'summit__Summit_Events_Instance__c.Parking_info__c',
    'summit__Summit_Events_Instance__c.summit__Virtual_Meeting_Link__c',
    'summit__Summit_Events_Instance__c.summit__Virtual_Appointment_Link__c',
    'summit__Summit_Events_Instance__c.summit__Active_Status__c',
    'summit__Summit_Events_Instance__c.summit__Open_Registration__c',
    'summit__Summit_Events_Instance__c.summit__Capacity__c',
    'summit__Summit_Events_Instance__c.summit__Current_Available_Capacity__c'
];

export default class FiuInstanceWorkspace extends LightningElement {
    @api recordId;
    record;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ data }) {
        if (data) this.record = data;
    }

    value(field) {
        return this.record?.fields?.[field]?.displayValue || this.record?.fields?.[field]?.value || '---';
    }

    get titleValue() { return this.value('summit__Instance_Title__c'); }
    get eventNameValue() { return this.record?.fields?.summit__Event__r?.displayValue || '---'; }
    get startDateValue() { return this.value('summit__Instance_Start_Date__c'); }
    get startTimeValue() { return this.value('summit__Instance_Start_Time__c'); }
    get endDateValue() { return this.value('summit__Instance_End_Date__c'); }
    get endTimeValue() { return this.value('summit__Instance_End_Time__c'); }
    get timeZoneValue() { return this.value('summit__Instance_Time_Zone__c'); }

    get locationTypeValue() { return this.value('summit__Location_Type_Override__c'); }
    get locationTitleValue() { return this.value('summit__Location_Title_Override__c'); }
    get locationAddressValue() { return this.value('summit__Location_Address_Override__c'); }
    get mapLinkValue() { return this.value('summit__Location_Map_Link_Override__c'); }
    get parkingInfoValue() { return this.value('Parking_info__c'); }
    get virtualMeetingValue() { return this.value('summit__Virtual_Meeting_Link__c'); }
    get virtualApptValue() { return this.value('summit__Virtual_Appointment_Link__c'); }

    get activeStatusValue() { return this.value('summit__Active_Status__c'); }
    get openRegistrationValue() { return this.value('summit__Open_Registration__c'); }
    get capacityValue() { return this.value('summit__Capacity__c'); }
    get availableCapacityValue() { return this.value('summit__Current_Available_Capacity__c'); }

    get isOnlineLocation() {
        const val = String(this.locationTypeValue || '').toLowerCase();
        return val === 'online' || val === 'virtual';
    }

    get showPhysicalLocation() {
        return !this.isOnlineLocation;
    }
}
