import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import queryInstances from '@salesforce/apex/FiuInstanceBrowserService.queryInstances';
import getProgramOptions from '@salesforce/apex/FiuProgramFilterService.getProgramOptions';

const COLUMNS = [
    { label: 'Instance', fieldName: 'title' },
    { label: 'Event', fieldName: 'eventName' },
    { label: 'Start Date', fieldName: 'startDate', type: 'date' },
    { label: 'Status', fieldName: 'activeStatus' },
    { label: 'Readiness', fieldName: 'readiness' },
    { label: 'Reason (if Not Ready)', fieldName: 'unpublishedReason', wrapText: true },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Open Instance', name: 'open' },
                { label: 'Clone Instance', name: 'clone' },
                { label: 'View Registrations', name: 'registrations' }
            ]
        }
    }
];

export default class FiuInstanceBrowser extends NavigationMixin(LightningElement) {
    columns = COLUMNS;
    rows = [];
    searchKey = '';
    bucketFilter = 'Upcoming';
    eventId;
    programCode = '';
    programOptions = [{ label: 'All Programs', value: '' }];
    loadError;
    isLoading = false;

    bucketOptions = [
        { label: 'Upcoming', value: 'Upcoming' },
        { label: 'All', value: 'All' },
        { label: 'Past', value: 'Past' },
        { label: 'Unpublished', value: 'Unpublished' }
    ];

    @wire(CurrentPageReference)
    setPageRef(pageRef) {
        const state = pageRef?.state || {};
        this.eventId = state.c__eventId || null;
        if (state.c__bucket && this.bucketOptions.some((opt) => opt.value === state.c__bucket)) {
            this.bucketFilter = state.c__bucket;
        } else if (Object.prototype.hasOwnProperty.call(state, 'c__bucket')) {
            this.bucketFilter = 'Upcoming';
        }
        if (Object.prototype.hasOwnProperty.call(state, 'c__program')) {
            this.programCode = state.c__program || '';
        } else {
            this.programCode = '';
        }
        this.loadRows();
    }

    connectedCallback() {
        this.loadRows();
    }

    @wire(getProgramOptions)
    wiredPrograms({ data }) {
        if (data) this.programOptions = [{ label: 'All Programs', value: '' }, ...data];
    }

    async loadRows() {
        this.isLoading = true;
        try {
            const data = await queryInstances({
                eventId: this.eventId,
                searchKey: this.searchKey,
                bucketFilter: this.bucketFilter,
                programCode: this.programCode
            });
            this.rows = data || [];
            this.loadError = undefined;
        } catch (e) {
            this.rows = [];
            this.loadError = e?.body?.message || 'Could not load instances. Please refresh.';
        } finally {
            this.isLoading = false;
        }
    }

    handleSearch(event) { this.searchKey = event.target.value; this.loadRows(); }
    handleBucket(event) { this.bucketFilter = event.detail.value; this.loadRows(); }
    handleProgram(event) { this.programCode = event.detail.value; this.loadRows(); }

    handleRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action === 'open') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.id, actionName: 'view' } });
        }
        if (action === 'clone') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.id, objectApiName: 'summit__Summit_Events_Instance__c', actionName: 'clone' } });
        }
        if (action === 'registrations') {
            this[NavigationMixin.Navigate]({
                type: 'standard__navItemPage',
                attributes: { apiName: 'fiuRegistrationBrowser' },
                state: { c__instanceId: row.id, c__program: this.programCode || '' }
            });
        }
    }
}
