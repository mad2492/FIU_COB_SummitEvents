import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import queryInstances from '@salesforce/apex/FiuInstanceBrowserService.queryInstances';
import getProgramOptions from '@salesforce/apex/FiuProgramFilterService.getProgramOptions';
import getEventRecordTypeOptions from '@salesforce/apex/FiuEventsAccessService.getEventRecordTypeOptions';

const VIEW_STATE_KEY = 'fiuInstanceBrowserViewStateV1';
const APP_SCOPE_KEY = 'fiuEventsAppScopeV1';

const COLUMN_DEFS = [
    { key: 'title', label: 'Instance', type: 'link', sortable: true, defaultVisible: true },
    { key: 'eventName', label: 'Event', type: 'text', sortable: true, defaultVisible: true },
    { key: 'startDate', label: 'Start', type: 'datetime', sortable: true, defaultVisible: true },
    { key: 'activeStatus', label: 'Status', type: 'badge', themeKey: 'statusTheme', sortable: true, defaultVisible: true },
    { key: 'readiness', label: 'Readiness', type: 'badge', themeKey: 'readinessTheme', sortable: false, defaultVisible: true },
    { key: 'registrationProgress', label: 'Registered', type: 'capacity', sortable: false, defaultVisible: true },
    { key: 'unpublishedReason', label: 'Reason', type: 'multiline', sortable: false, defaultVisible: true }
];

const DEFAULT_VISIBLE_COLUMN_KEYS = COLUMN_DEFS.filter((c) => c.defaultVisible).map((c) => c.key);

export default class FiuInstanceBrowser extends NavigationMixin(LightningElement) {
    columns = COLUMN_DEFS;
    rows = [];
    selectedRowIds = [];
    selectedInstanceId;
    searchKey = '';
    bucketFilter = 'Upcoming';
    eventId;
    recordTypeId = '';
    programCode = '';
    availableRecordTypeOptions = [];
    recordTypeOptions = [{ label: 'All Record Types', value: '' }];
    programOptions = [{ label: 'All Programs', value: '' }];
    loadError = '';
    isLoading = false;
    totalCount = 0;
    pageNumber = 1;
    pageSize = 25;
    pageCursor = null;
    nextCursor = null;
    cursorHistory = [];
    hasNextPage = false;
    pageSizeOptions = [
        { label: '25', value: '25' },
        { label: '50', value: '50' },
        { label: '100', value: '100' }
    ];

    bucketOptions = [
        { label: 'Upcoming', value: 'Upcoming' },
        { label: 'All', value: 'All' },
        { label: 'Past', value: 'Past' },
        { label: 'Unpublished', value: 'Unpublished' }
    ];

    visibleColumnKeys = [...DEFAULT_VISIBLE_COLUMN_KEYS];

    isFilterModalOpen = false;
    draftRecordTypeId = '';
    draftProgramCode = '';

    isFieldModalOpen = false;
    draftVisibleColumnKeys = [...DEFAULT_VISIBLE_COLUMN_KEYS];

    sortField1 = 'startDate';
    sortDir1 = 'ASC';
    sortField2 = '';
    sortDir2 = 'ASC';

    searchDebounceTimer;
    copyResetTimer;
    hasStateBucketOverride = false;
    hasStateProgramOverride = false;
    hasStateRecordTypeOverride = false;
    hasCopiedRegisterUrl = false;

    @wire(CurrentPageReference)
    setPageRef(pageRef) {
        const state = pageRef?.state || {};
        this.eventId = state.c__eventId || null;
        this.restoreAppScope();
        this.hasStateBucketOverride = Object.prototype.hasOwnProperty.call(state, 'c__bucket');
        this.hasStateProgramOverride = Object.prototype.hasOwnProperty.call(state, 'c__program');
        this.hasStateRecordTypeOverride = Object.prototype.hasOwnProperty.call(state, 'c__recordType');
        if (state.c__bucket && this.bucketOptions.some((opt) => opt.value === state.c__bucket)) {
            this.bucketFilter = state.c__bucket;
        } else if (this.hasStateBucketOverride) {
            this.bucketFilter = 'Upcoming';
        } else if (this.eventId) {
            this.bucketFilter = 'All';
        }
        if (this.hasStateProgramOverride) {
            this.programCode = state.c__program || '';
        }
        if (this.hasStateRecordTypeOverride) {
            this.recordTypeId = state.c__recordType || '';
        }
        this.restoreViewState();
        this.resetPaging();
        this.loadRows();
    }

    @wire(getEventRecordTypeOptions)
    wiredRecordTypes({ data }) {
        if (data) {
            this.availableRecordTypeOptions = data;
            this.recordTypeOptions = data.length > 1 ? [{ label: 'All Record Types', value: '' }, ...data] : data;
            if (this.normalizeRecordTypeScope()) {
                this.resetPaging();
                this.loadRows();
            }
        }
    }

    @wire(getProgramOptions, { recordTypeId: '$recordTypeId' })
    wiredPrograms({ data }) {
        if (data) {
            this.programOptions = [{ label: 'All Programs', value: '' }, ...data];
            if (this.programCode && !this.programOptions.some((option) => option.value === this.programCode)) {
                this.programCode = '';
                this.persistAppScope();
            }
        }
    }

    // ---- derived state
    get selectedInstance() {
        return this.rows.find((row) => row.id === this.selectedInstanceId);
    }

    get selectedInstanceRegisterUrlDisplay() {
        const registerUrl = this.selectedInstance?.registerUrl;
        if (!registerUrl) return '';
        return registerUrl.replace(/^https?:\/\//i, '');
    }

    get selectedInstanceCapacityFillClass() {
        const tier = this.selectedInstance?.registrationProgress?.tier || 'success';
        return `qv-capacity__fill qv-capacity__fill--${tier}`;
    }

    get selectedInstanceCapacityFillStyle() {
        const percent = Math.max(0, Math.min(100, Number(this.selectedInstance?.registrationProgress?.percent) || 0));
        return `width:${percent}%;`;
    }

    get selectedInstanceIssueText() {
        const reason = this.selectedInstance?.unpublishedReason;
        if (!reason || reason === '—') return '';
        return reason;
    }

    get useCursorPagination() {
        return !(this.searchKey || '').trim() && this.bucketFilter !== 'Unpublished';
    }

    get hasPreviousPage() {
        return this.useCursorPagination ? this.cursorHistory.length > 0 : this.pageNumber > 1;
    }

    get registerUrlRowClass() {
        return this.selectedInstance?.activeStatus === 'Active'
            ? 'qv-url-row'
            : 'qv-url-row qv-url-row--dimmed';
    }

    get copyButtonClass() {
        return this.hasCopiedRegisterUrl ? 'qv-url-action qv-url-action--copied' : 'qv-url-action';
    }

    get copyButtonIcon() {
        return this.hasCopiedRegisterUrl ? 'utility:check' : 'utility:copy';
    }

    get copyButtonLabel() {
        return this.hasCopiedRegisterUrl ? 'Copied' : 'Copy';
    }

    get quickViewTitle() { return this.selectedInstance?.title || ''; }
    get quickViewSubhead() { return this.selectedInstance?.eventName || ''; }

    get activeFilterPills() {
        const pills = [];
        if (this.searchKey) {
            pills.push({ key: 'search', label: `Search: "${this.searchKey}"` });
        }
        if (this.bucketFilter && this.bucketFilter !== 'Upcoming') {
            pills.push({ key: 'bucket', label: `View: ${this.bucketFilter}` });
        }
        if (this.recordTypeId && this.showRecordTypePicker) {
            pills.push({ key: 'recordType', label: `Record Type: ${this.recordTypeOptions.find((option) => option.value === this.recordTypeId)?.label || 'Selected'}` });
        }
        if (this.programCode) {
            pills.push({ key: 'program', label: `Program: ${this.programOptions.find((option) => option.value === this.programCode)?.label || this.programCode}` });
        }
        return pills;
    }

    get fieldChooserOptions() {
        return COLUMN_DEFS.map((column) => ({ label: column.label, value: column.key }));
    }

    get showRecordTypePicker() {
        return this.availableRecordTypeOptions.length > 1;
    }

    // ---- view state persistence
    restoreViewState() {
        try {
            const raw = window.sessionStorage.getItem(VIEW_STATE_KEY);
            if (!raw) return;
            const savedState = JSON.parse(raw);
            if (Array.isArray(savedState.visibleColumnKeys) && savedState.visibleColumnKeys.length) {
                this.visibleColumnKeys = savedState.visibleColumnKeys;
            }
            if (typeof savedState.pageSize === 'number') this.pageSize = savedState.pageSize;
            if (typeof savedState.bucketFilter === 'string' && !this.hasStateBucketOverride && !this.eventId) {
                this.bucketFilter = savedState.bucketFilter;
            }
            if (typeof savedState.sortField1 === 'string') this.sortField1 = savedState.sortField1;
            if (typeof savedState.sortDir1 === 'string') this.sortDir1 = savedState.sortDir1;
            if (typeof savedState.sortField2 === 'string') this.sortField2 = savedState.sortField2;
            if (typeof savedState.sortDir2 === 'string') this.sortDir2 = savedState.sortDir2;
        } catch (error) {
            // ignore malformed session state
        }
    }

    persistViewState() {
        const payload = {
            visibleColumnKeys: this.visibleColumnKeys,
            pageSize: this.pageSize,
            bucketFilter: this.bucketFilter,
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
            const data = await queryInstances({
                eventId: this.eventId,
                searchKey: this.searchKey,
                bucketFilter: this.bucketFilter,
                programCode: this.programCode,
                pageNumber: this.pageNumber,
                pageSize: this.pageSize,
                sortField1: this.sortField1,
                sortDir1: this.sortDir1,
                sortField2: this.sortField2,
                sortDir2: this.sortDir2,
                pageCursor: this.useCursorPagination ? this.pageCursor : null,
                recordTypeId: this.recordTypeId
            });
            const rawRows = data?.rows || [];
            this.rows = rawRows.map((row) => {
                const capacity = row.capacity || 0;
                const registrations = row.registrationCount || 0;
                const percent = capacity > 0 ? Math.min(100, (registrations / capacity) * 100) : 0;
                const percentRounded = Math.round(percent);
                const summary = capacity > 0
                    ? `${registrations}/${capacity} (${this.formatPercent(percent)})`
                    : `${registrations} registered`;
                return {
                    ...row,
                    capacityDisplay: capacity > 0 ? String(capacity) : 'Not set',
                    statusTheme: this.getStatusTheme(row),
                    readinessTheme: this.getReadinessTheme(row),
                    registrationProgress: {
                        summary,
                        percent: percentRounded,
                        tier: this.getCapacityTier(percent)
                    },
                    unpublishedReason: row.unpublishedReason || '—'
                };
            });
            this.totalCount = data?.totalCount || 0;
            this.nextCursor = data?.nextCursor || null;
            this.hasNextPage = this.useCursorPagination
                ? !!data?.hasNext
                : this.pageNumber < Math.max(1, Math.ceil((this.totalCount || 0) / this.pageSize));
            const currentIds = new Set(this.rows.map((row) => row.id));
            this.selectedRowIds = this.selectedRowIds.filter((id) => currentIds.has(id));
            if (this.selectedInstanceId && !currentIds.has(this.selectedInstanceId)) this.selectedInstanceId = null;
            this.loadError = '';
            this.persistAppScope();
            this.persistViewState();
        } catch (error) {
            this.rows = [];
            this.totalCount = 0;
            this.nextCursor = null;
            this.hasNextPage = false;
            this.loadError = error?.body?.message || 'Could not load instances. Please refresh.';
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
            this.resetPaging();
            this.loadRows();
        }, 300);
    }

    handleSortChange(event) {
        this.sortField1 = event.detail.field;
        this.sortDir1 = event.detail.direction;
        this.sortField2 = '';
        this.sortDir2 = 'ASC';
        this.resetPaging();
        this.loadRows();
    }

    handlePageChange(event) {
        const requestedPage = event.detail.pageNumber;
        if (this.useCursorPagination) {
            if (requestedPage > this.pageNumber && this.hasNextPage && this.nextCursor) {
                this.cursorHistory = [...this.cursorHistory, this.pageCursor];
                this.pageCursor = this.nextCursor;
                this.pageNumber += 1;
            } else if (requestedPage < this.pageNumber && this.hasPreviousPage) {
                const previousCursors = [...this.cursorHistory];
                this.pageCursor = previousCursors.pop() || null;
                this.cursorHistory = previousCursors;
                this.pageNumber = Math.max(1, this.pageNumber - 1);
            } else {
                return;
            }
        } else {
            this.pageNumber = requestedPage;
        }
        this.loadRows();
    }

    handlePageSizeChange(event) {
        this.pageSize = event.detail.pageSize;
        this.resetPaging();
        this.loadRows();
    }

    handleRowClick(event) {
        const rowId = event.detail.rowId;
        if (this.selectedInstanceId === rowId) {
            this.handleQuickViewClose();
        } else {
            this.resetCopiedRegisterUrlState();
            this.selectedInstanceId = rowId;
        }
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
        if (key === 'bucket') this.bucketFilter = 'Upcoming';
        if (key === 'recordType') {
            this.recordTypeId = '';
            this.programCode = '';
        }
        if (key === 'program') this.programCode = '';
        if (key === 'recordType' || key === 'program') this.persistAppScope();
        this.resetPaging();
        this.loadRows();
    }

    handleClearFilters() {
        this.resetToDefaultView();
    }

    handleClearSelection() {
        this.selectedRowIds = [];
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
        this.resetCopiedRegisterUrlState();
        this.selectedInstanceId = null;
    }

    handleBreadcrumbHome() {
        this.navigateHome();
    }

    handleBucketChange(event) {
        this.bucketFilter = event.detail.value || 'Upcoming';
        this.resetPaging();
        this.loadRows();
    }

    // ---- filter modal (Program only — Bucket is inline)
    openFilterModal() {
        this.draftRecordTypeId = this.recordTypeId;
        this.draftProgramCode = this.programCode;
        this.isFilterModalOpen = true;
    }

    closeFilterModal() {
        this.isFilterModalOpen = false;
    }

    handleDraftProgram(event) {
        this.draftProgramCode = event.detail.value;
    }

    handleDraftRecordType(event) {
        this.draftRecordTypeId = event.detail.value;
        this.draftProgramCode = '';
    }

    applyFilters() {
        this.recordTypeId = this.draftRecordTypeId || '';
        this.programCode = this.draftProgramCode || '';
        this.isFilterModalOpen = false;
        this.persistAppScope();
        this.resetPaging();
        this.loadRows();
    }

    // ---- field picker modal
    openFieldModal() {
        this.draftVisibleColumnKeys = [...this.visibleColumnKeys];
        this.isFieldModalOpen = true;
    }

    closeFieldModal() {
        this.isFieldModalOpen = false;
    }

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
        this.bucketFilter = 'Upcoming';
        this.recordTypeId = this.defaultRecordTypeScopeValue;
        this.programCode = '';
        this.searchKey = '';
        this.sortField1 = 'startDate';
        this.sortDir1 = 'ASC';
        this.sortField2 = '';
        this.sortDir2 = 'ASC';
        this.pageSize = 25;
        this.resetPaging();
        this.persistAppScope();
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
            scope: 'fiuInstanceBrowser',
            exportMode: 'selected',
            selectedIds: this.selectedRowIds.join(',')
        });
        window.open(`/apex/ExportCsv?${params.toString()}`, '_blank');
    }

    handleExportFiltered() {
        const params = new URLSearchParams({
            action: 'launch',
            scope: 'fiuInstanceBrowser',
            exportMode: 'filtered',
            searchKey: this.searchKey || '',
            bucketFilter: this.bucketFilter || '',
            recordTypeId: this.recordTypeId || '',
            programCode: this.programCode || '',
            eventId: this.eventId || '',
            sortField1: this.sortField1 || '',
            sortDir1: this.sortDir1 || '',
            sortField2: this.sortField2 || '',
            sortDir2: this.sortDir2 || ''
        });
        window.open(`/apex/ExportCsv?${params.toString()}`, '_blank');
    }

    // ---- navigation
    navigateHome() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuEventsHome' }
        });
    }

    navigateToCreateInstance() {
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: { componentName: 'c__fiuInstanceCreateWizard' }
        });
    }

    openSelectedInstanceRecord() {
        if (!this.selectedInstance) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.selectedInstance.id, actionName: 'view' }
        });
    }

    handleQuickViewMoreSelect(event) {
        const action = event.detail.value;
        if (action === 'clone') this.cloneSelectedInstance();
        if (action === 'download') this.downloadSelectedInstanceRegistrations();
    }

    cloneSelectedInstance() {
        if (!this.selectedInstance) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: { componentName: 'c__fiuInstanceCreateWizard' },
            state: {
                c__mode: 'clone',
                c__sourceInstanceId: this.selectedInstance.id,
                c__eventId: this.selectedInstance.eventId
            }
        });
    }

    openSelectedInstanceRegistrations() {
        if (!this.selectedInstance) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuRegistrationBrowser' },
            state: { c__instanceId: this.selectedInstance.id, c__program: this.programCode || '', c__recordType: this.recordTypeId || '' }
        });
    }

    downloadSelectedInstanceRegistrations() {
        if (!this.selectedInstance) return;
        const params = new URLSearchParams({
            action: 'launch',
            scope: 'fiuRegistrationBrowser',
            exportMode: 'filtered',
            instanceId: this.selectedInstance.id,
            recordTypeId: this.recordTypeId || '',
            statusFilter: 'Open',
            quickDownload: '1'
        });
        window.open(`/apex/ExportCsv?${params.toString()}`, '_blank');
    }

    // ---- clipboard
    async handleCopyRegisterUrl() {
        const registerUrl = this.selectedInstance?.registerUrl;
        if (!registerUrl) return;
        try {
            await navigator.clipboard.writeText(registerUrl);
            this.hasCopiedRegisterUrl = true;
            if (this.copyResetTimer) clearTimeout(this.copyResetTimer);
            this.copyResetTimer = setTimeout(() => {
                this.hasCopiedRegisterUrl = false;
                this.copyResetTimer = null;
            }, 1600);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Copied',
                message: 'Registration URL copied to clipboard.',
                variant: 'success'
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Copy failed',
                message: 'Could not copy the registration URL automatically.',
                variant: 'error'
            }));
        }
    }

    disconnectedCallback() {
        this.resetCopiedRegisterUrlState();
    }

    resetCopiedRegisterUrlState() {
        this.hasCopiedRegisterUrl = false;
        if (this.copyResetTimer) {
            clearTimeout(this.copyResetTimer);
            this.copyResetTimer = null;
        }
    }

    resetPaging() {
        this.pageNumber = 1;
        this.pageCursor = null;
        this.nextCursor = null;
        this.cursorHistory = [];
        this.hasNextPage = false;
    }

    restoreAppScope() {
        try {
            const raw = window.sessionStorage.getItem(APP_SCOPE_KEY);
            if (!raw) return;
            const scope = JSON.parse(raw);
            if (typeof scope.recordTypeId === 'string') this.recordTypeId = scope.recordTypeId;
            if (typeof scope.programCode === 'string') this.programCode = scope.programCode;
        } catch (error) {
            // ignore malformed app scope
        }
    }

    persistAppScope() {
        window.sessionStorage.setItem(APP_SCOPE_KEY, JSON.stringify({
            recordTypeId: this.recordTypeId,
            programCode: this.programCode
        }));
    }

    get defaultRecordTypeScopeValue() {
        return this.availableRecordTypeOptions.length === 1 ? this.availableRecordTypeOptions[0].value : '';
    }

    normalizeRecordTypeScope() {
        if (this.availableRecordTypeOptions.length === 1) {
            const onlyRecordTypeId = this.availableRecordTypeOptions[0].value;
            if (this.recordTypeId !== onlyRecordTypeId) {
                this.recordTypeId = onlyRecordTypeId;
                this.programCode = '';
                this.persistAppScope();
                return true;
            }
        } else if (this.recordTypeId && !this.availableRecordTypeOptions.some((option) => option.value === this.recordTypeId)) {
            this.recordTypeId = '';
            this.programCode = '';
            this.persistAppScope();
            return true;
        }
        return false;
    }

    // ---- themes / helpers
    getStatusTheme(row) {
        return row.activeStatus === 'Active' ? 'success' : 'neutral';
    }

    getReadinessTheme(row) {
        return row.readiness === 'Ready' ? 'success' : 'error';
    }

    getCapacityTier(percent) {
        if (percent >= 90) return 'danger';
        if (percent >= 70) return 'warning';
        return 'success';
    }

    formatPercent(percent) {
        if (!percent || percent <= 0) return '0%';
        if (percent > 0 && percent < 1) return `${percent.toFixed(1)}%`;
        return `${Math.round(percent)}%`;
    }
}
