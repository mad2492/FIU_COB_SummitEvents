import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import queryRegistrations from '@salesforce/apex/FiuRegistrationBrowserService.queryRegistrations';
import getProgramOptions from '@salesforce/apex/FiuProgramFilterService.getProgramOptions';

const COLUMNS = [
    { label: 'Registrant', fieldName: 'name' },
    { label: 'Email', fieldName: 'email' },
    { label: 'Event', fieldName: 'eventName' },
    { label: 'Instance', fieldName: 'instanceName' },
    { label: 'Attendance', fieldName: 'attendanceStatus' }
];

export default class FiuRegistrationBrowser extends LightningElement {
    columns = COLUMNS;
    rows = [];
    searchKey = '';
    attendanceFilter = '';
    programCode = '';
    instanceId;
    instanceScopeLabel = '';
    programOptions = [{ label: 'All Programs', value: '' }];

    attendanceOptions = [
        { label: 'All', value: '' },
        { label: 'Attended', value: 'Attended' },
        { label: 'Registered', value: 'Registered' },
        { label: 'No Show', value: 'No Show' }
    ];

    @wire(CurrentPageReference)
    setPageRef(pageRef) {
        const state = pageRef?.state || {};
        this.instanceId = state.c__instanceId || null;
        if (Object.prototype.hasOwnProperty.call(state, 'c__program')) {
            this.programCode = state.c__program || '';
        }
        this.instanceScopeLabel = this.instanceId ? `Scoped to Instance: ${this.instanceId}` : '';
    }

    @wire(queryRegistrations, { searchKey: '$searchKey', attendanceFilter: '$attendanceFilter', programCode: '$programCode', instanceId: '$instanceId' })
    wiredRows({ data }) {
        if (data) {
            this.rows = data;
            if (this.instanceId && data.length > 0) {
                this.instanceScopeLabel = `Scoped to Instance: ${data[0].instanceName}`;
            }
        }
    }

    @wire(getProgramOptions)
    wiredPrograms({ data }) {
        if (data) this.programOptions = [{ label: 'All Programs', value: '' }, ...data];
    }

    handleSearch(event) {
        this.searchKey = event.target.value;
    }

    handleAttendance(event) {
        this.attendanceFilter = event.detail.value;
    }

    handleProgram(event) {
        this.programCode = event.detail.value;
    }

    handleExport() {
        const exportUrl =
            '/apex/ExportCsv?action=launch&objectApiName=summit__Summit_Events_Registration__c';
        window.open(exportUrl, '_blank');
    }
}
