import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import queryEvents from '@salesforce/apex/FiuEventBrowserService.queryEvents';
import getProgramOptions from '@salesforce/apex/FiuProgramFilterService.getProgramOptions';

const VIEW_STATE_KEY = 'fiuEventBrowserViewStateV1';

const COLUMN_DEFS = [
    { key: 'name', label: 'Event Name', type: 'link', sortable: true, defaultVisible: true },
    { key: 'recordType', label: 'Record Type', type: 'text', sortable: true, defaultVisible: true },
    { key: 'status', label: 'Status', type: 'badge', themeKey: 'statusTheme', sortable: true, defaultVisible: true },
    { key: 'readiness', label: 'Readiness', type: 'badge', themeKey: 'readinessTheme', sortable: false, defaultVisible: true },
    { key: 'issueReason', label: 'Issues', type: 'multiline', sortable: false, defaultVisible: true },
    { key: 'instanceCount', label: 'Instances', type: 'count-link', action: 'viewInstances', actionTooltip: 'View instances for this event', sortable: false, defaultVisible: true },
    { key: 'startDate', label: 'Start Date', type: 'date', sortable: true, defaultVisible: true }
];

const DEFAULT_VISIBLE_COLUMN_KEYS = COLUMN_DEFS.filter((c) => c.defaultVisible).map((c) => c.key);

export default class FiuEventBrowser extends NavigationMixin(LightningElement) {
    columns = COLUMN_DEFS;
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

    @wire(getProgramOptions)
    wiredPrograms({ data }) {
        if (data) this.programOptions = [{ label: 'All Programs', value: '' }, ...data];
    }

    // ---- derived state shared with the shell + quick-view body
    get selectedEvent() { return this.rows.find((row) => row.id === this.selectedEventId); }

    get activeFilterPills() {
        const pills = [];
        if (this.searchKey) pills.push({ key: 'search', label: `Search: "${this.searchKey}"` });
        if (this.statusFilter) pills.push({ key: 'status', label: `Status: ${this.statusOptions.find((o) => o.value === this.statusFilter)?.label || this.statusFilter}` });
        if (this.readinessFilter) pills.push({ key: 'readiness', label: `Readiness: ${this.readinessOptions.find((o) => o.value === this.readinessFilter)?.label || this.readinessFilter}` });
        if (this.programCode) pills.push({ key: 'program', label: `Program: ${this.programOptions.find((o) => o.value === this.programCode)?.label || this.programCode}` });
        return pills;
    }

    get fieldChooserOptions() {
        return COLUMN_DEFS.map((c) => ({ label: c.label, value: c.key }));
    }

    get quickViewTitle() { return this.selectedEvent?.name || ''; }
    get quickViewSubhead() { return this.selectedEvent?.recordType || ''; }
    get quickViewStatusLabel() { return this.selectedEvent?.status || 'Unknown'; }
    get quickViewReadinessLabel() {
        if (!this.selectedEvent) return 'Unknown';
        if (this.selectedEvent.readiness === 'Active w/ Issues') return 'Setup Incomplete';
        return this.selectedEvent.readiness || 'Unknown';
    }
    get quickViewStatusTheme() {
        return this.selectedEvent ? this.getStatusTheme(this.selectedEvent) : 'neutral';
    }
    get quickViewReadinessTheme() {
        return this.selectedEvent ? this.getReadinessTheme(this.selectedEvent) : 'neutral';
    }
    get showQuickViewIssuePanel() {
        return !!(this.selectedEvent?.issueReason || this.selectedEvent?.readiness === 'Active w/ Issues');
    }
    get quickViewIssueTitle() {
        const issue = (this.selectedEvent?.issueReason || '').toLowerCase();
        if (issue.includes('missing selected program')) return 'Program selection required';
        return 'Setup action required';
    }
    get quickViewIssueBody() {
        const issue = (this.selectedEvent?.issueReason || '').toLowerCase();
        if (issue.includes('missing selected program')) {
            return 'A program must be selected before this event can be marked ready.';
        }
        if (this.selectedEvent?.issueReason) return this.selectedEvent.issueReason;
        return 'This event needs additional setup before it can be marked ready.';
    }
    get quickViewIssueActionLabel() {
        const issue = (this.selectedEvent?.issueReason || '').toLowerCase();
        if (issue.includes('missing selected program')) return 'Select a program';
        return null;
    }

    // ---- view state persistence
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
                statusTheme: this.getStatusTheme(row),
                readinessTheme: this.getReadinessTheme(row)
            }));
            this.totalCount = data?.totalCount || 0;
            const currentIds = new Set(this.rows.map((r) => r.id));
            this.selectedRowIds = this.selectedRowIds.filter((id) => currentIds.has(id));
            if (this.selectedEventId && !currentIds.has(this.selectedEventId)) this.selectedEventId = null;
            this.persistViewState();
        } finally {
            this.isLoading = false;
        }
    }

    // ---- shell events
    handleSearch(event) {
        const value = event.detail.value;
        this.searchKey = value;
        if (this.searchDebounceTimer) clearTimeout(this.searchDebounceTimer);
        this.searchDebounceTimer = setTimeout(() => {
            this.pageNumber = 1;
            this.loadRows();
        }, 300);
    }

    handleSortChange(event) {
        this.sortField1 = event.detail.field;
        this.sortDir1 = event.detail.direction;
        this.sortField2 = '';
        this.sortDir2 = 'ASC';
        this.pageNumber = 1;
        this.loadRows();
    }

    handlePageChange(event) {
        this.pageNumber = event.detail.pageNumber;
        this.loadRows();
    }

    handlePageSizeChange(event) {
        this.pageSize = event.detail.pageSize;
        this.pageNumber = 1;
        this.loadRows();
    }

    handleRowClick(event) {
        const rowId = event.detail.rowId;
        this.selectedEventId = this.selectedEventId === rowId ? null : rowId;
    }

    handleRowSelect(event) {
        const { rowId, checked } = event.detail;
        const ids = new Set(this.selectedRowIds);
        if (checked) ids.add(rowId);
        else ids.delete(rowId);
        this.selectedRowIds = [...ids];
    }

    handleRowSelectAll(event) {
        const checked = event.detail.checked;
        this.selectedRowIds = checked ? this.rows.map((r) => r.id) : [];
    }

    handleRemovePill(event) {
        const key = event.detail.key;
        if (key === 'search') this.searchKey = '';
        if (key === 'status') this.statusFilter = '';
        if (key === 'readiness') this.readinessFilter = '';
        if (key === 'program') this.programCode = '';
        this.pageNumber = 1;
        this.loadRows();
    }

    handleClearFilters() {
        this.resetToDefaultView();
    }

    handleClearSelection() {
        this.selectedRowIds = [];
    }

    handleInlineStatus(event) {
        this.statusFilter = event.detail.value || '';
        this.pageNumber = 1;
        this.loadRows();
    }

    handleInlineReadiness(event) {
        this.readinessFilter = event.detail.value || '';
        this.pageNumber = 1;
        this.loadRows();
    }

    handleCellAction(event) {
        const { rowId, action } = event.detail;
        if (action === 'viewInstances') {
            this[NavigationMixin.Navigate]({
                type: 'standard__navItemPage',
                attributes: { apiName: 'fiuInstanceBrowser' },
                state: { c__eventId: rowId }
            });
        }
    }

    handleOpenFilters() {
        this.openFilterModal();
    }

    handleOpenSettings() {
        this.openFieldModal();
    }

    handleResetView() {
        this.resetToDefaultView();
    }

    handleQuickViewClose() {
        this.selectedEventId = null;
    }

    handleBreadcrumbHome() {
        this.navigateHome();
    }

    // ---- filter modal
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

    // ---- field picker modal
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

    // ---- export
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

    // ---- create modal
    handleCreateNew() {
        this.isCreateModalOpen = true;
    }

    closeCreateModal() {
        this.isCreateModalOpen = false;
        this.loadRows();
    }

    // ---- themes
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

    // ---- navigation
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

    cloneSelectedEvent() {
        if (!this.selectedEvent) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: { componentName: 'c__fiuEventCloneWizard' },
            state: { c__sourceEventId: this.selectedEvent.id }
        });
    }

    handleQuickViewMoreSelect(event) {
        const action = event.detail.value;
        if (action === 'instances') this.openSelectedEventInstances();
        if (action === 'clone') this.cloneSelectedEvent();
    }

    handleQuickViewIssueAction() {
        const issue = (this.selectedEvent?.issueReason || '').toLowerCase();
        if (issue.includes('missing selected program')) {
            this.openFilterModal();
            return;
        }
        this.openSelectedEventRecord();
    }
}
