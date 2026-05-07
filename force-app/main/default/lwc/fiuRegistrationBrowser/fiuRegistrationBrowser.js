import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import REGISTRATION_OBJECT from '@salesforce/schema/summit__Summit_Events_Registration__c';
import queryRegistrations from '@salesforce/apex/FiuRegistrationBrowserService.queryRegistrations';
import massUpdateRegistrations from '@salesforce/apex/FiuRegistrationBrowserService.massUpdateRegistrations';
import getLocationTypeOverrideOptions from '@salesforce/apex/FiuRegistrationBrowserService.getLocationTypeOverrideOptions';
import getProgramOptions from '@salesforce/apex/FiuProgramFilterService.getProgramOptions';

const VIEW_STATE_KEY = 'fiuRegBrowserViewStateV1';

const ALL_COLUMNS = [
    { key: 'name', label: 'Registration', type: 'url', fieldName: 'registrationUrl', sortable: true, typeAttributes: { label: { fieldName: 'name' }, target: '_blank' } },
    { key: 'contact', label: 'Contact', type: 'url', fieldName: 'contactUrl', typeAttributes: { label: { fieldName: 'contactDisplayName' }, target: '_blank' }, cellAttributes: { class: { fieldName: 'contactIssueClass' } } },
    { key: 'email', label: 'Email', type: 'text', fieldName: 'email', sortable: true },
    { key: 'eventName', label: 'Event', type: 'text', fieldName: 'eventName', sortable: true },
    { key: 'instanceName', label: 'Instance', type: 'text', fieldName: 'instanceName', sortable: true },
    { key: 'instanceStartDate', label: 'Instance Start', type: 'date', fieldName: 'instanceStartDate', sortable: true },
    { key: 'instanceEndDate', label: 'Instance End', type: 'date', fieldName: 'instanceEndDate', sortable: true },
    { key: 'locationTypeOverride', label: 'Location Type', type: 'text', fieldName: 'locationTypeOverride', sortable: true },
    { key: 'processStatus', label: 'Registration Status', type: 'text', fieldName: 'processStatus', sortable: true, cellAttributes: { class: { fieldName: 'processStatusClass' } } }
];

const DEFAULT_VISIBLE_COLUMN_KEYS = ['name', 'contact', 'email', 'eventName', 'instanceName', 'instanceStartDate', 'processStatus'];

const ACTION_COLUMN = {
    type: 'action',
    typeAttributes: {
        rowActions: [
            { label: 'View Registration', name: 'viewRegistration' }
        ]
    }
};

export default class FiuRegistrationBrowser extends NavigationMixin(LightningElement) {
    rows = [];
    selectedRowIds = [];
    totalCount = 0;

    searchKey = '';
    statusFilter = '';
    programCode = '';
    locationTypeOverrideFilter = '';
    instanceId;
    instanceScopeLabel = '';

    pageNumber = 1;
    pageSize = 25;
    pageSizeOptions = [
        { label: '25', value: '25' },
        { label: '50', value: '50' },
        { label: '100', value: '100' }
    ];

    sortField1 = 'name';
    sortDir1 = 'ASC';
    sortField2 = '';
    sortDir2 = 'ASC';

    searchDebounceTimer;

    visibleColumnKeys = [...DEFAULT_VISIBLE_COLUMN_KEYS];

    isLoading = false;
    loadError;

    isFilterModalOpen = false;
    draftStatusFilter = '';
    draftProgramCode = '';
    draftLocationTypeOverrideFilter = '';

    isFieldModalOpen = false;
    draftVisibleColumnKeys = [...DEFAULT_VISIBLE_COLUMN_KEYS];

    isMassModalOpen = false;
    updateStatusEnabled = false;
    updateEventEnabled = false;
    updateInstanceEnabled = false;
    massStatus = '';
    massEventId;
    massInstanceId;
    inlineErrorMessage;

    programOptions = [{ label: 'All Programs', value: '' }];
    locationTypeOverrideOptions = [{ label: 'All Location Types', value: '' }];
    canImport = false;
    openMassUpdateHint = false;

    statusOptions = [
        { label: 'All', value: '' },
        { label: 'Active', value: 'Open' },
        { label: 'Started (Review)', value: 'Started' },
        { label: 'Cancelled', value: 'Cancelled' }
    ];

    massStatusOptions = [
        { label: '-- No Change --', value: '' },
        { label: 'Started', value: 'Started' },
        { label: 'Registered', value: 'Registered' },
        { label: 'Attended', value: 'Attended' },
        { label: 'Cancelled', value: 'Cancelled' }
    ];

    get columns() {
        const selected = ALL_COLUMNS.filter((c) => this.visibleColumnKeys.includes(c.key)).map((c) => {
            if (c.type === 'url') {
                return { label: c.label, fieldName: c.fieldName, type: c.type, sortable: c.sortable, typeAttributes: c.typeAttributes, cellAttributes: c.cellAttributes };
            }
            return { label: c.label, fieldName: c.fieldName, type: c.type, sortable: c.sortable, cellAttributes: c.cellAttributes };
        });
        return [...selected, ACTION_COLUMN];
    }

    get hasRows() { return this.rows.length > 0; }
    get sortedDirection() { return (this.sortDir1 || 'ASC').toLowerCase(); }
    get hasActiveFilters() {
        return !!(this.searchKey || this.statusFilter || this.programCode || this.locationTypeOverrideFilter);
    }
    get activeFilterPills() {
        const pills = [];
        if (this.searchKey) pills.push({ key: 'search', label: `Search: "${this.searchKey}"` });
        if (this.statusFilter) pills.push({ key: 'status', label: `Status: ${this.statusOptions.find((o) => o.value === this.statusFilter)?.label || this.statusFilter}` });
        if (this.programCode) pills.push({ key: 'program', label: `Program: ${this.programOptions.find((o) => o.value === this.programCode)?.label || this.programCode}` });
        if (this.locationTypeOverrideFilter) pills.push({ key: 'locationType', label: `Location Type: ${this.locationTypeOverrideFilter}` });
        return pills;
    }

    handleRemovePill(event) {
        const key = event.target.name;
        if (key === 'search') this.searchKey = '';
        if (key === 'status') this.statusFilter = '';
        if (key === 'program') this.programCode = '';
        if (key === 'locationType') this.locationTypeOverrideFilter = '';
        this.pageNumber = 1;
        this.loadRows();
    }

    handleSort(event) {
        const fieldName = event.detail.fieldName;
        const direction = (event.detail.sortDirection || 'asc').toUpperCase();
        this.sortField1 = fieldName;
        this.sortDir1 = direction;
        this.sortField2 = '';
        this.sortDir2 = 'ASC';
        this.pageNumber = 1;
        this.loadRows();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get fieldChooserOptions() {
        return ALL_COLUMNS.map((c) => ({ label: c.label, value: c.key }));
    }

    @wire(CurrentPageReference)
    setPageRef(pageRef) {
        const state = pageRef?.state || {};
        this.instanceId = state.c__instanceId || null;
        if (Object.prototype.hasOwnProperty.call(state, 'c__program')) this.programCode = state.c__program || '';
        if (Object.prototype.hasOwnProperty.call(state, 'c__status')) this.statusFilter = state.c__status || '';
        this.openMassUpdateHint = state.c__openMassUpdate === '1';
        this.instanceScopeLabel = this.instanceId ? 'Scoped to selected instance' : '';
        this.restoreViewState();
        this.pageNumber = 1;
        this.loadRows();
        if (this.openMassUpdateHint) {
            setTimeout(() => {
                this.showToast('Bulk update', 'Select one or more rows, then click Mass Update.', 'info');
            }, 250);
        }
    }

    connectedCallback() {
        this.restoreViewState();
        this.loadRows();
    }

    @wire(getProgramOptions)
    wiredPrograms({ data }) {
        if (data) this.programOptions = [{ label: 'All Programs', value: '' }, ...data];
    }

    @wire(getObjectInfo, { objectApiName: REGISTRATION_OBJECT })
    wiredObjectInfo({ data }) {
        this.canImport = !!data?.createable;
    }

    @wire(getLocationTypeOverrideOptions)
    wiredLocationTypeOptions({ data }) {
        if (data) {
            this.locationTypeOverrideOptions = [
                { label: 'All Location Types', value: '' },
                ...data.map((v) => ({ label: v, value: v }))
            ];
        }
    }

    restoreViewState() {
        try {
            const raw = window.sessionStorage.getItem(VIEW_STATE_KEY);
            if (!raw) return;
            const s = JSON.parse(raw);
            if (Array.isArray(s.visibleColumnKeys) && s.visibleColumnKeys.length) this.visibleColumnKeys = s.visibleColumnKeys;
            if (typeof s.pageSize === 'number') this.pageSize = s.pageSize;
            if (typeof s.statusFilter === 'string') this.statusFilter = s.statusFilter;
            if (typeof s.programCode === 'string' && !this.instanceId) this.programCode = s.programCode;
            if (typeof s.locationTypeOverrideFilter === 'string') this.locationTypeOverrideFilter = s.locationTypeOverrideFilter;
            if (typeof s.sortField1 === 'string') this.sortField1 = s.sortField1;
            if (typeof s.sortDir1 === 'string') this.sortDir1 = s.sortDir1;
            if (typeof s.sortField2 === 'string') this.sortField2 = s.sortField2;
            if (typeof s.sortDir2 === 'string') this.sortDir2 = s.sortDir2;
        } catch (e) {
            // ignore
        }
    }

    persistViewState() {
        const payload = {
            visibleColumnKeys: this.visibleColumnKeys,
            pageSize: this.pageSize,
            statusFilter: this.statusFilter,
            programCode: this.programCode,
            locationTypeOverrideFilter: this.locationTypeOverrideFilter,
            sortField1: this.sortField1,
            sortDir1: this.sortDir1,
            sortField2: this.sortField2,
            sortDir2: this.sortDir2
        };
        window.sessionStorage.setItem(VIEW_STATE_KEY, JSON.stringify(payload));
    }

    get selectedCount() { return this.selectedRowIds.length; }
    get totalPages() { return Math.max(1, Math.ceil((this.totalCount || 0) / this.pageSize)); }
    get disablePrev() { return this.pageNumber <= 1; }
    get disableNext() { return this.pageNumber >= this.totalPages; }
    get pageSizeValue() { return String(this.pageSize); }
    get statusInputDisabled() { return !this.updateStatusEnabled; }
    get eventInputDisabled() { return !this.updateEventEnabled; }
    get instanceInputDisabled() { return !this.updateInstanceEnabled; }

    get massSummary() {
        const updates = [];
        if (this.updateStatusEnabled && this.massStatus) updates.push(`Status -> "${this.massStatus}"`);
        if (this.updateEventEnabled && this.massEventId) updates.push(`Event -> ${this.massEventId}`);
        if (this.updateInstanceEnabled && this.massInstanceId) updates.push(`Instance -> ${this.massInstanceId}`);
        if (!updates.length) return 'No field updates selected yet.';
        return `${this.selectedCount} records will be updated: ${updates.join(', ')}`;
    }

    async loadRows() {
        this.isLoading = true;
        this.loadError = undefined;
        try {
            const data = await queryRegistrations({
                searchKey: this.searchKey,
                programCode: this.programCode,
                instanceId: this.instanceId,
                statusFilter: this.statusFilter,
                locationTypeOverrideFilter: this.locationTypeOverrideFilter,
                pageNumber: this.pageNumber,
                pageSize: this.pageSize,
                sortField1: this.sortField1,
                sortDir1: this.sortDir1,
                sortField2: this.sortField2,
                sortDir2: this.sortDir2
            });
            const baseRows = data?.rows || [];
            this.totalCount = data?.totalCount || 0;
            this.rows = baseRows.map((r) => ({
                ...r,
                registrationUrl: `/${r.id}`,
                contactDisplayName: r.contactName || 'Missing Contact',
                contactUrl: r.contactId ? `/${r.contactId}` : null
            }));
            if (this.instanceId && this.rows.length > 0 && this.rows[0].instanceName) {
                this.instanceScopeLabel = `Scoped to: ${this.rows[0].instanceName}`;
            } else if (this.instanceId) {
                this.instanceScopeLabel = 'Scoped to selected instance';
            }
            const currentIds = new Set(this.rows.map((r) => r.id));
            this.selectedRowIds = this.selectedRowIds.filter((id) => currentIds.has(id));
            this.persistViewState();
        } catch (e) {
            this.rows = [];
            this.totalCount = 0;
            this.loadError = e?.body?.message || 'Could not load registrations.';
        } finally {
            this.isLoading = false;
        }
    }

    handleSearch(event) {
        const value = event.target.value;
        this.searchKey = value;
        if (this.searchDebounceTimer) clearTimeout(this.searchDebounceTimer);
        this.searchDebounceTimer = setTimeout(() => {
            this.pageNumber = 1;
            this.loadRows();
        }, 300);
    }
    handlePageSize(event) { this.pageSize = Number(event.detail.value); this.pageNumber = 1; this.loadRows(); }
    handlePrevPage() { if (!this.disablePrev) { this.pageNumber -= 1; this.loadRows(); } }
    handleNextPage() { if (!this.disableNext) { this.pageNumber += 1; this.loadRows(); } }
    handleSelection(event) { this.selectedRowIds = (event.detail.selectedRows || []).map((r) => r.id); }

    handleRowAction(event) {
        const { name } = event.detail.action;
        const row = event.detail.row;
        if (name === 'viewRegistration') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: row.id, objectApiName: 'summit__Summit_Events_Registration__c', actionName: 'view' }
            });
        }
    }

    openFilterModal() {
        this.draftStatusFilter = this.statusFilter;
        this.draftProgramCode = this.programCode;
        this.draftLocationTypeOverrideFilter = this.locationTypeOverrideFilter;
        this.isFilterModalOpen = true;
    }
    closeFilterModal() { this.isFilterModalOpen = false; }
    handleDraftStatus(event) { this.draftStatusFilter = event.detail.value; }
    handleDraftProgram(event) { this.draftProgramCode = event.detail.value; }
    handleDraftLocationTypeOverride(event) { this.draftLocationTypeOverrideFilter = event.detail.value; }
    applyFilters() {
        this.statusFilter = this.draftStatusFilter || '';
        this.programCode = this.draftProgramCode || '';
        this.locationTypeOverrideFilter = this.draftLocationTypeOverrideFilter || '';
        this.isFilterModalOpen = false;
        this.pageNumber = 1;
        this.loadRows();
    }

    openFieldModal() {
        this.draftVisibleColumnKeys = [...this.visibleColumnKeys];
        this.isFieldModalOpen = true;
    }
    closeFieldModal() { this.isFieldModalOpen = false; }
    handleFieldSelection(event) {
        this.draftVisibleColumnKeys = event.detail.value || [];
    }
    applyFieldSelection() {
        this.visibleColumnKeys = this.draftVisibleColumnKeys.length ? [...this.draftVisibleColumnKeys] : [...DEFAULT_VISIBLE_COLUMN_KEYS];
        this.isFieldModalOpen = false;
        this.persistViewState();
    }

    handleGearSelect(event) {
        const action = event.detail.value;
        if (action === 'fields') this.openFieldModal();
        if (action === 'reset') this.resetToDefaultView();
    }

    resetToDefaultView() {
        this.visibleColumnKeys = [...DEFAULT_VISIBLE_COLUMN_KEYS];
        this.statusFilter = '';
        this.programCode = '';
        this.locationTypeOverrideFilter = '';
        this.searchKey = '';
        this.sortField1 = 'name';
        this.sortDir1 = 'ASC';
        this.sortField2 = '';
        this.sortDir2 = 'ASC';
        this.pageSize = 25;
        this.pageNumber = 1;
        this.inlineErrorMessage = undefined;
        this.persistViewState();
        this.loadRows();
    }

    refreshView() {
        this.loadRows();
    }

    navigateHome() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuEventsHome' }
        });
    }

    handleExportMenuSelect(event) {
        const action = event.detail.value;
        if (action === 'selected') this.handleExportSelected();
        if (action === 'filtered') this.handleExportFiltered();
    }

    handleImport() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/dataImporter/dataImporter.app?objectSelection=summit__Summit_Events_Registration__c'
            }
        });
    }

    handleExportFiltered() {
        const params = new URLSearchParams({
            action: 'launch',
            scope: 'fiuRegistrationBrowser',
            exportMode: 'filtered',
            searchKey: this.searchKey || '',
            statusFilter: this.statusFilter || '',
            programCode: this.programCode || '',
            locationTypeOverrideFilter: this.locationTypeOverrideFilter || '',
            instanceId: this.instanceId || '',
            sortField1: this.sortField1 || '',
            sortDir1: this.sortDir1 || '',
            sortField2: this.sortField2 || '',
            sortDir2: this.sortDir2 || ''
        });
        window.open(`/apex/ExportCsv?${params.toString()}`, '_blank');
    }

    handleExportSelected() {
        if (!this.selectedCount) {
            this.showToast('No rows selected', 'Select one or more rows to export selected.', 'warning');
            return;
        }
        const params = new URLSearchParams({
            action: 'launch',
            scope: 'fiuRegistrationBrowser',
            exportMode: 'selected',
            selectedIds: this.selectedRowIds.join(',')
        });
        window.open(`/apex/ExportCsv?${params.toString()}`, '_blank');
    }

    openMassModal() {
        if (!this.selectedCount) {
            this.showToast('No rows selected', 'Select one or more rows before mass update.', 'warning');
            return;
        }
        this.inlineErrorMessage = undefined;
        this.updateStatusEnabled = false;
        this.updateEventEnabled = false;
        this.updateInstanceEnabled = false;
        this.massStatus = '';
        this.massEventId = undefined;
        this.massInstanceId = undefined;
        this.isMassModalOpen = true;
    }

    closeMassModal() { this.isMassModalOpen = false; }

    handleToggleStatus(event) { this.updateStatusEnabled = event.target.checked; if (!this.updateStatusEnabled) this.massStatus = ''; }
    handleToggleEvent(event) { this.updateEventEnabled = event.target.checked; if (!this.updateEventEnabled) this.massEventId = undefined; }
    handleToggleInstance(event) { this.updateInstanceEnabled = event.target.checked; if (!this.updateInstanceEnabled) this.massInstanceId = undefined; }
    handleMassStatus(event) { this.massStatus = event.detail.value; }
    handleMassEvent(event) { this.massEventId = event.detail.recordId; }
    handleMassInstance(event) { this.massInstanceId = event.detail.recordId; }

    async applyMassUpdate() {
        const newStatus = this.updateStatusEnabled ? this.massStatus : '';
        const newEventId = this.updateEventEnabled ? this.massEventId : null;
        const newInstanceId = this.updateInstanceEnabled ? this.massInstanceId : null;
        if (!newStatus && !newEventId && !newInstanceId) {
            this.inlineErrorMessage = 'Choose at least one field to update.';
            return;
        }
        try {
            const result = await massUpdateRegistrations({ registrationIds: this.selectedRowIds, newStatus, newEventId, newInstanceId });
            this.isMassModalOpen = false;
            this.inlineErrorMessage = undefined;
            this.selectedRowIds = [];
            this.showToast('Mass update complete', `${result.updatedCount} registration(s) updated.`, 'success');
            await this.loadRows();
        } catch (e) {
            this.inlineErrorMessage = e?.body?.message || 'Mass update failed.';
        }
    }
}
