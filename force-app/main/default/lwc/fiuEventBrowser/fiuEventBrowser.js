import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import queryEvents from '@salesforce/apex/FiuEventBrowserService.queryEvents';
import getProgramOptions from '@salesforce/apex/FiuProgramFilterService.getProgramOptions';

const VIEW_STATE_KEY = 'fiuEventBrowserViewStateV1';

const ALL_COLUMNS = [
    { key: 'name', label: 'Event Name', sortable: true },
    { key: 'recordType', label: 'Record Type', sortable: true },
    { key: 'status', label: 'Status', sortable: true },
    { key: 'readiness', label: 'Readiness' },
    { key: 'issueReason', label: 'Issues' },
    { key: 'instanceCount', label: 'Instances' },
    { key: 'startDate', label: 'Start Date', sortable: true }
];

const DEFAULT_VISIBLE_COLUMN_KEYS = ['name', 'recordType', 'status', 'readiness', 'issueReason', 'instanceCount', 'startDate'];

export default class FiuEventBrowser extends NavigationMixin(LightningElement) {
    rows = [];
    selectedRowIds = [];
    selectedEventId;
    totalCount = 0;
    isLoading = false;

    searchKey = '';
    statusFilter = '';
    readinessFilter = '';
    programCode = '';

    pageNumber = 1;
    pageSize = 25;
    pageSizeOptions = [
        { label: '25', value: '25' },
        { label: '50', value: '50' },
        { label: '100', value: '100' }
    ];

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

    visibleColumnKeys = [...DEFAULT_VISIBLE_COLUMN_KEYS];

    isFilterModalOpen = false;
    draftStatusFilter = '';
    draftReadinessFilter = '';
    draftProgramCode = '';

    isFieldModalOpen = false;
    draftVisibleColumnKeys = [...DEFAULT_VISIBLE_COLUMN_KEYS];

    isCreateModalOpen = false;
    sortField1 = 'startDate';
    sortDir1 = 'DESC';
    sortField2 = '';
    sortDir2 = 'ASC';

    searchDebounceTimer;

    @wire(CurrentPageReference)
    setPageRef(pageRef) {
        const state = pageRef?.state || {};
        if (Object.prototype.hasOwnProperty.call(state, 'c__program')) this.programCode = state.c__program || '';
        if (state.c__readiness && this.readinessOptions.some((opt) => opt.value === state.c__readiness)) this.readinessFilter = state.c__readiness;
        this.restoreViewState();
        this.pageNumber = 1;
        this.loadRows();
    }

    connectedCallback() {
        this.restoreViewState();
        this.loadRows();
    }

    @wire(getProgramOptions)
    wiredPrograms({ data }) {
        if (data) this.programOptions = [{ label: 'All Programs', value: '' }, ...data];
    }

    get hasRows() { return this.rows.length > 0; }
    get allRowsSelected() {
        return this.rows.length > 0 && this.rows.every((row) => row.isSelected);
    }
    get showNameColumn() { return this.visibleColumnKeys.includes('name'); }
    get showRecordTypeColumn() { return this.visibleColumnKeys.includes('recordType'); }
    get showStatusColumn() { return this.visibleColumnKeys.includes('status'); }
    get showReadinessColumn() { return this.visibleColumnKeys.includes('readiness'); }
    get showIssuesColumn() { return this.visibleColumnKeys.includes('issueReason'); }
    get showInstancesColumn() { return this.visibleColumnKeys.includes('instanceCount'); }
    get showStartDateColumn() { return this.visibleColumnKeys.includes('startDate'); }
    get selectedEvent() { return this.rows.find((row) => row.id === this.selectedEventId); }
    get browserLayoutClass() {
        return this.selectedEvent ? 'browser-layout browser-layout--panel-open' : 'browser-layout';
    }
    get sortedDirection() { return (this.sortDir1 || 'ASC').toLowerCase(); }
    get nameSortIcon() { return this.getSortIcon('name'); }
    get recordTypeSortIcon() { return this.getSortIcon('recordType'); }
    get statusSortIcon() { return this.getSortIcon('status'); }
    get startDateSortIcon() { return this.getSortIcon('startDate'); }
    get hasActiveFilters() {
        return !!(this.statusFilter || this.readinessFilter || this.programCode || this.searchKey);
    }
    get activeFilterPills() {
        const pills = [];
        if (this.searchKey) pills.push({ key: 'search', label: `Search: "${this.searchKey}"` });
        if (this.statusFilter) pills.push({ key: 'status', label: `Status: ${this.statusOptions.find((o) => o.value === this.statusFilter)?.label || this.statusFilter}` });
        if (this.readinessFilter) pills.push({ key: 'readiness', label: `Readiness: ${this.readinessOptions.find((o) => o.value === this.readinessFilter)?.label || this.readinessFilter}` });
        if (this.programCode) pills.push({ key: 'program', label: `Program: ${this.programOptions.find((o) => o.value === this.programCode)?.label || this.programCode}` });
        return pills;
    }

    handleRemovePill(event) {
        const key = event.target.name;
        if (key === 'search') this.searchKey = '';
        if (key === 'status') this.statusFilter = '';
        if (key === 'readiness') this.readinessFilter = '';
        if (key === 'program') this.programCode = '';
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

    handleSortClick(event) {
        const fieldName = event.currentTarget?.dataset?.field;
        if (!fieldName) return;
        const direction = this.sortField1 === fieldName && this.sortDir1 === 'ASC' ? 'DESC' : 'ASC';
        this.sortField1 = fieldName;
        this.sortDir1 = direction;
        this.sortField2 = '';
        this.sortDir2 = 'ASC';
        this.pageNumber = 1;
        this.loadRows();
    }

    get fieldChooserOptions() {
        return ALL_COLUMNS.map((c) => ({ label: c.label, value: c.key }));
    }

    get totalPages() { return Math.max(1, Math.ceil((this.totalCount || 0) / this.pageSize)); }
    get disablePrev() { return this.pageNumber <= 1; }
    get disableNext() { return this.pageNumber >= this.totalPages; }
    get pageSizeValue() { return String(this.pageSize); }

    restoreViewState() {
        try {
            const raw = window.sessionStorage.getItem(VIEW_STATE_KEY);
            if (!raw) return;
            const s = JSON.parse(raw);
            if (Array.isArray(s.visibleColumnKeys) && s.visibleColumnKeys.length) this.visibleColumnKeys = s.visibleColumnKeys;
            if (typeof s.pageSize === 'number') this.pageSize = s.pageSize;
            if (typeof s.statusFilter === 'string') this.statusFilter = s.statusFilter;
            if (typeof s.readinessFilter === 'string') this.readinessFilter = s.readinessFilter;
            if (typeof s.programCode === 'string') this.programCode = s.programCode;
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
            readinessFilter: this.readinessFilter,
            programCode: this.programCode,
            sortField1: this.sortField1,
            sortDir1: this.sortDir1,
            sortField2: this.sortField2,
            sortDir2: this.sortDir2
        };
        window.sessionStorage.setItem(VIEW_STATE_KEY, JSON.stringify(payload));
    }

    async loadRows() {
        this.isLoading = true;
        try {
            const data = await queryEvents({
                searchKey: this.searchKey,
                statusFilter: this.statusFilter,
                programCode: this.programCode,
                readinessFilter: this.readinessFilter,
                pageNumber: this.pageNumber,
                pageSize: this.pageSize,
                sortField1: this.sortField1,
                sortDir1: this.sortDir1,
                sortField2: this.sortField2,
                sortDir2: this.sortDir2
            });
            const rawRows = data?.rows || [];
            this.rows = rawRows.map((row) => ({
                ...row,
                eventUrl: `/lightning/r/summit__Summit_Events__c/${row.id}/view`,
                statusTheme: this.getStatusTheme(row),
                readinessTheme: this.getReadinessTheme(row),
                isSelected: this.selectedRowIds.includes(row.id)
            }));
            this.totalCount = data?.totalCount || 0;
            const currentIds = new Set(this.rows.map((r) => r.id));
            this.selectedRowIds = this.selectedRowIds.filter((id) => currentIds.has(id));
            this.rows = this.rows.map((row) => ({ ...row, isSelected: this.selectedRowIds.includes(row.id) }));
            this.persistViewState();
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

    handleSelectAllRows(event) {
        const checked = event.target.checked;
        this.selectedRowIds = checked ? this.rows.map((row) => row.id) : [];
        this.rows = this.rows.map((row) => ({ ...row, isSelected: checked }));
    }

    handleRowSelection(event) {
        const rowId = event.currentTarget?.dataset?.id;
        const checked = event.target.checked;
        if (!rowId) return;
        const ids = new Set(this.selectedRowIds);
        if (checked) ids.add(rowId);
        else ids.delete(rowId);
        this.selectedRowIds = [...ids];
        this.rows = this.rows.map((row) => (row.id === rowId ? { ...row, isSelected: checked } : row));
    }

    openFilterModal() {
        this.draftStatusFilter = this.statusFilter;
        this.draftReadinessFilter = this.readinessFilter;
        this.draftProgramCode = this.programCode;
        this.isFilterModalOpen = true;
    }

    closeFilterModal() { this.isFilterModalOpen = false; }
    handleDraftStatus(event) { this.draftStatusFilter = event.detail.value; }
    handleDraftReadiness(event) { this.draftReadinessFilter = event.detail.value; }
    handleDraftProgram(event) { this.draftProgramCode = event.detail.value; }

    applyFilters() {
        this.statusFilter = this.draftStatusFilter || '';
        this.readinessFilter = this.draftReadinessFilter || '';
        this.programCode = this.draftProgramCode || '';
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
        this.readinessFilter = '';
        this.programCode = '';
        this.searchKey = '';
        this.sortField1 = 'startDate';
        this.sortDir1 = 'DESC';
        this.sortField2 = '';
        this.sortDir2 = 'ASC';
        this.pageSize = 25;
        this.pageNumber = 1;
        this.persistViewState();
        this.loadRows();
    }

    refreshView() {
        this.loadRows();
    }

    closeQuickView() {
        this.selectedEventId = null;
    }

    handleExportMenuSelect(event) {
        const action = event.detail.value;
        if (action === 'selected') this.handleExportSelected();
        if (action === 'filtered') this.handleExportFiltered();
    }

    handleExportSelected() {
        if (!this.selectedRowIds.length) return;
        const params = new URLSearchParams({
            action: 'launch',
            scope: 'fiuEventBrowser',
            exportMode: 'selected',
            selectedIds: this.selectedRowIds.join(',')
        });
        window.open(`/apex/ExportCsv?${params.toString()}`, '_blank');
    }

    handleExportFiltered() {
        const params = new URLSearchParams({
            action: 'launch',
            scope: 'fiuEventBrowser',
            exportMode: 'filtered',
            searchKey: this.searchKey || '',
            statusFilter: this.statusFilter || '',
            readinessFilter: this.readinessFilter || '',
            programCode: this.programCode || '',
            sortField1: this.sortField1 || '',
            sortDir1: this.sortDir1 || '',
            sortField2: this.sortField2 || '',
            sortDir2: this.sortDir2 || ''
        });
        window.open(`/apex/ExportCsv?${params.toString()}`, '_blank');
    }

    handleCreateNew() {
        this.isCreateModalOpen = true;
    }

    getStatusTheme(row) {
        if (row.status === 'Active' && row.issueReason) return 'warning';
        if (row.status === 'Active') return 'success';
        if (row.status === 'Draft') return 'info';
        if (row.status === 'Closed') return 'neutral';
        return 'neutral';
    }

    getReadinessTheme(row) {
        if (row.readiness === 'Ready') return 'success';
        if (row.readiness === 'Needs Review') return 'warning';
        if (row.readiness === 'Active w/ Issues') return 'error';
        return 'neutral';
    }

    navigateHome() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuEventsHome' }
        });
    }

    openSelectedEventRecord() {
        if (!this.selectedEvent) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.selectedEvent.id, actionName: 'view' }
        });
    }

    openSelectedEventInstances() {
        if (!this.selectedEvent) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuInstanceBrowser' },
            state: { c__eventId: this.selectedEvent.id }
        });
    }

    addInstanceForSelectedEvent() {
        if (!this.selectedEvent) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: { componentName: 'c__fiuInstanceCreateWizard' },
            state: { c__eventId: this.selectedEvent.id }
        });
    }

    closeCreateModal() {
        this.isCreateModalOpen = false;
        this.loadRows();
    }

    openQuickViewFromButton(event) {
        const rowId = event.currentTarget?.dataset?.id;
        if (rowId) this.selectedEventId = rowId;
    }

    getSortIcon(fieldName) {
        if (this.sortField1 !== fieldName) return 'utility:chevrondown';
        return this.sortDir1 === 'ASC' ? 'utility:arrowup' : 'utility:arrowdown';
    }
}
