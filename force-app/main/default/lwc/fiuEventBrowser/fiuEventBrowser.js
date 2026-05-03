import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import queryEvents from '@salesforce/apex/FiuEventBrowserService.queryEvents';
import getProgramOptions from '@salesforce/apex/FiuProgramFilterService.getProgramOptions';

const COLUMNS = [
    { label: 'Event Name', fieldName: 'name' },
    { label: 'Record Type', fieldName: 'recordType' },
    { label: 'Status', fieldName: 'status', cellAttributes: { class: { fieldName: 'statusClass' } } },
    { label: 'Readiness', fieldName: 'readiness', cellAttributes: { class: { fieldName: 'readinessClass' } } },
    { label: 'Issues', fieldName: 'issueReason', wrapText: true },
    { label: 'Start Date', fieldName: 'startDate', type: 'date' },
    { label: 'End Date', fieldName: 'endDate', type: 'date' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Open Event', name: 'open' },
                { label: 'View Instances', name: 'instances' },
                { label: 'Add New Instance', name: 'newInstance' }
            ]
        }
    }
];

export default class FiuEventBrowser extends NavigationMixin(LightningElement) {
    columns = COLUMNS;
    rows = [];
    searchKey = '';
    statusFilter = '';
    readinessFilter = '';
    programCode = '';
    programOptions = [{ label: 'All Programs', value: '' }];

    statusOptions = [
        { label: 'All', value: '' },
        { label: 'Active', value: 'Active' },
        { label: 'Closed', value: 'Closed' },
        { label: 'Draft', value: 'Draft' }
    ];
    readinessOptions = [
        { label: 'All', value: '' },
        { label: 'Not Ready', value: 'NotReady' },
        { label: 'Ready', value: 'Ready' }
    ];

    @wire(CurrentPageReference)
    setPageRef(pageRef) {
        const state = pageRef?.state || {};
        if (Object.prototype.hasOwnProperty.call(state, 'c__program')) {
            this.programCode = state.c__program || '';
        }
        if (state.c__readiness && this.readinessOptions.some((opt) => opt.value === state.c__readiness)) {
            this.readinessFilter = state.c__readiness;
        }
    }

    @wire(queryEvents, { searchKey: '$searchKey', statusFilter: '$statusFilter', programCode: '$programCode', readinessFilter: '$readinessFilter' })
    wiredEvents({ data }) {
        if (data) this.rows = data;
    }

    @wire(getProgramOptions)
    wiredPrograms({ data }) {
        if (data) this.programOptions = [{ label: 'All Programs', value: '' }, ...data];
    }

    handleSearch(event) { this.searchKey = event.target.value; }
    handleStatus(event) { this.statusFilter = event.detail.value; }
    handleReadiness(event) { this.readinessFilter = event.detail.value; }
    handleProgram(event) { this.programCode = event.detail.value; }

    handleCreateNew() {
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: { componentName: 'c__fiuEventCreateWizard' }
        });
    }

    handleRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action === 'open') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.id, actionName: 'view' } });
        } else if (action === 'instances') {
            this[NavigationMixin.Navigate]({
                type: 'standard__navItemPage',
                attributes: { apiName: 'fiuInstanceBrowser' },
                state: { c__eventId: row.id }
            });
        } else if (action === 'newInstance') {
            this[NavigationMixin.Navigate]({
                type: 'standard__component',
                attributes: { componentName: 'c__fiuInstanceCreateWizard' },
                state: { c__eventId: row.id }
            });
        }
    }
}
