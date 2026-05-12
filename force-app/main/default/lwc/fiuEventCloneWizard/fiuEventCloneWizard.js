import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import queryEvents from '@salesforce/apex/FiuEventBrowserService.queryEvents';

export default class FiuEventCloneWizard extends NavigationMixin(LightningElement) {
    sourceEventId;
    isLoading = false;
    searchKey = '';
    rows = [];
    autoLaunchDone = false;
    searchDebounceTimer;

    @wire(CurrentPageReference)
    setPageRef(pageRef) {
        this.sourceEventId = pageRef?.state?.c__sourceEventId || null;
        if (this.sourceEventId && !this.autoLaunchDone) {
            this.autoLaunchDone = true;
            this.cloneEventById(this.sourceEventId);
            return;
        }
        this.loadRows();
    }

    get hasSourceEvent() {
        return !!this.sourceEventId;
    }

    get showPicker() {
        return !this.hasSourceEvent;
    }

    get hasRows() {
        return (this.rows || []).length > 0;
    }

    get hasSearch() {
        return !!this.searchKey;
    }

    handleSearch(event) {
        this.searchKey = event.target.value || '';
        if (this.searchDebounceTimer) clearTimeout(this.searchDebounceTimer);
        this.searchDebounceTimer = setTimeout(() => this.loadRows(), 250);
    }

    async loadRows() {
        if (!this.showPicker) return;
        this.isLoading = true;
        try {
            const data = await queryEvents({
                searchKey: this.searchKey,
                statusFilter: '',
                readinessFilter: '',
                programCode: '',
                pageNumber: 1,
                pageSize: 25,
                sortField1: 'startDate',
                sortDir1: 'DESC',
                sortField2: '',
                sortDir2: 'ASC'
            });
            this.rows = (data?.rows || []).map((row) => ({
                ...row,
                subtitle: `${row.recordType || 'Event'} - ${row.status || 'Status unknown'}`
            }));
        } finally {
            this.isLoading = false;
        }
    }

    cloneEventById(eventId) {
        if (!eventId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: eventId,
                objectApiName: 'summit__Summit_Events__c',
                actionName: 'clone'
            }
        });
    }

    handleCloneFromRow(event) {
        const eventId = event.currentTarget?.dataset?.id;
        this.cloneEventById(eventId);
    }

    goToEventBrowser() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuEventBrowser' }
        });
    }
}
