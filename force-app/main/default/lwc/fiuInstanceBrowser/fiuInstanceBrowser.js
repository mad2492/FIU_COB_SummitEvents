import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import queryInstances from '@salesforce/apex/FiuInstanceBrowserService.queryInstances';
import getProgramOptions from '@salesforce/apex/FiuProgramFilterService.getProgramOptions';

const VIEW_STATE_KEY = 'fiuInstanceBrowserViewStateV1';

const ALL_COLUMNS = [
    { key: 'title', label: 'Instance', sortable: true },
    { key: 'eventName', label: 'Event', sortable: true },
    { key: 'startDate', label: 'Start', sortable: true },
    { key: 'activeStatus', label: 'Status', sortable: true },
    { key: 'readiness', label: 'Readiness' },
    { key: 'registrationProgress', label: 'Registered' },
    { key: 'unpublishedReason', label: 'Reason (if Not Ready)' }
];

const DEFAULT_VISIBLE_COLUMN_KEYS = ['title', 'eventName', 'startDate', 'activeStatus', 'readiness', 'registrationProgress', 'unpublishedReason'];

export default class FiuInstanceBrowser extends NavigationMixin(LightningElement) {
    rows = [];
    selectedRowIds = [];
    selectedInstanceId;
    searchKey = '';
    bucketFilter = 'Upcoming';
    eventId;
    programCode = '';
    programOptions = [{ label: 'All Programs', value: '' }];
    loadError;
    isLoading = false;
    totalCount = 0;
    pageNumber = 1;
    pageSize = 25;
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
    draftBucketFilter = 'Upcoming';
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
    hasCopiedRegisterUrl = false;

    @wire(CurrentPageReference)
    setPageRef(pageRef) {
        const state = pageRef?.state || {};
        this.eventId = state.c__eventId || null;
        this.hasStateBucketOverride = Object.prototype.hasOwnProperty.call(state, 'c__bucket');
        this.hasStateProgramOverride = Object.prototype.hasOwnProperty.call(state, 'c__program');
        if (state.c__bucket && this.bucketOptions.some((opt) => opt.value === state.c__bucket)) {
            this.bucketFilter = state.c__bucket;
        } else if (this.hasStateBucketOverride) {
            this.bucketFilter = 'Upcoming';
        } else if (this.eventId) {
            this.bucketFilter = 'All';
        }
        if (this.hasStateProgramOverride) {
            this.programCode = state.c__program || '';
        } else {
            this.programCode = '';
        }
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
        if (data) {
            this.programOptions = [{ label: 'All Programs', value: '' }, ...data];
        }
    }

    get fieldChooserOptions() {
        return ALL_COLUMNS.map((column) => ({ label: column.label, value: column.key }));
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get allRowsSelected() {
        return this.rows.length > 0 && this.rows.every((row) => row.isSelected);
    }

    get showTitleColumn() {
        return this.visibleColumnKeys.includes('title');
    }

    get showEventNameColumn() {
        return this.visibleColumnKeys.includes('eventName');
    }

    get showStartDateColumn() {
        return this.visibleColumnKeys.includes('startDate');
    }

    get showActiveStatusColumn() {
        return this.visibleColumnKeys.includes('activeStatus');
    }

    get showReadinessColumn() {
        return this.visibleColumnKeys.includes('readiness');
    }

    get showRegistrationProgressColumn() {
        return this.visibleColumnKeys.includes('registrationProgress');
    }

    get showReasonColumn() {
        return this.visibleColumnKeys.includes('unpublishedReason');
    }

    get selectedInstance() {
        return this.rows.find((row) => row.id === this.selectedInstanceId);
    }

    get selectedInstanceRegisterUrlDisplay() {
        const registerUrl = this.selectedInstance?.registerUrl;
        if (!registerUrl) {
            return '';
        }
        return registerUrl.replace(/^https?:\/\//i, '');
    }

    get registerUrlRowClass() {
        return this.selectedInstance?.activeStatus === 'Active'
            ? 'register-url-row-shell'
            : 'register-url-row-shell register-url-row-shell--dimmed';
    }

    get copyButtonClass() {
        return this.hasCopiedRegisterUrl
            ? 'register-url-action register-url-action--copied'
            : 'register-url-action';
    }

    get copyButtonIcon() {
        return this.hasCopiedRegisterUrl ? 'utility:check' : 'utility:copy';
    }

    get copyButtonLabel() {
        return this.hasCopiedRegisterUrl ? 'Copied' : 'Copy';
    }

    get browserLayoutClass() {
        return this.selectedInstance ? 'browser-layout browser-layout--panel-open' : 'browser-layout';
    }

    get titleSortIcon() {
        return this.getSortIcon('title');
    }

    get eventNameSortIcon() {
        return this.getSortIcon('eventName');
    }

    get startDateSortIcon() {
        return this.getSortIcon('startDate');
    }

    get activeStatusSortIcon() {
        return this.getSortIcon('activeStatus');
    }

    get hasActiveFilters() {
        const isDefaultBucket = !this.bucketFilter || this.bucketFilter === 'Upcoming';
        return !!(this.searchKey || this.programCode || !isDefaultBucket);
    }

    get activeFilterPills() {
        const pills = [];
        if (this.searchKey) {
            pills.push({ key: 'search', label: `Search: "${this.searchKey}"` });
        }
        if (this.bucketFilter && this.bucketFilter !== 'Upcoming') {
            pills.push({ key: 'bucket', label: `View: ${this.bucketFilter}` });
        }
        if (this.programCode) {
            pills.push({ key: 'program', label: `Program: ${this.programOptions.find((option) => option.value === this.programCode)?.label || this.programCode}` });
        }
        return pills;
    }

    get totalPages() {
        return Math.max(1, Math.ceil((this.totalCount || 0) / this.pageSize));
    }

    get disablePrev() {
        return this.pageNumber <= 1;
    }

    get disableNext() {
        return this.pageNumber >= this.totalPages;
    }

    get pageSizeValue() {
        return String(this.pageSize);
    }

    handleRemovePill(event) {
        const key = event.target.name;
        if (key === 'search') this.searchKey = '';
        if (key === 'bucket') this.bucketFilter = 'Upcoming';
        if (key === 'program') this.programCode = '';
        this.pageNumber = 1;
        this.loadRows();
    }

    handleSortClick(event) {
        const fieldName = event.currentTarget?.dataset?.field;
        if (!fieldName) {
            return;
        }
        const direction = this.sortField1 === fieldName && this.sortDir1 === 'ASC' ? 'DESC' : 'ASC';
        this.sortField1 = fieldName;
        this.sortDir1 = direction;
        this.sortField2 = '';
        this.sortDir2 = 'ASC';
        this.pageNumber = 1;
        this.loadRows();
    }

    restoreViewState() {
        try {
            const raw = window.sessionStorage.getItem(VIEW_STATE_KEY);
            if (!raw) {
                return;
            }
            const savedState = JSON.parse(raw);
            if (Array.isArray(savedState.visibleColumnKeys) && savedState.visibleColumnKeys.length) {
                this.visibleColumnKeys = savedState.visibleColumnKeys;
            }
            if (typeof savedState.pageSize === 'number') {
                this.pageSize = savedState.pageSize;
            }
            if (typeof savedState.bucketFilter === 'string' && !this.hasStateBucketOverride && !this.eventId) {
                this.bucketFilter = savedState.bucketFilter;
            }
            if (typeof savedState.programCode === 'string' && !this.hasStateProgramOverride && !this.eventId) {
                this.programCode = savedState.programCode;
            }
            if (typeof savedState.sortField1 === 'string') {
                this.sortField1 = savedState.sortField1;
            }
            if (typeof savedState.sortDir1 === 'string') {
                this.sortDir1 = savedState.sortDir1;
            }
            if (typeof savedState.sortField2 === 'string') {
                this.sortField2 = savedState.sortField2;
            }
            if (typeof savedState.sortDir2 === 'string') {
                this.sortDir2 = savedState.sortDir2;
            }
        } catch (error) {
            // Ignore malformed session state.
        }
    }

    persistViewState() {
        const payload = {
            visibleColumnKeys: this.visibleColumnKeys,
            pageSize: this.pageSize,
            bucketFilter: this.bucketFilter,
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
                sortDir2: this.sortDir2
            });
            const rawRows = data?.rows || [];
            this.rows = rawRows.map((row) => {
                const capacity = row.capacity || 0;
                const registrations = row.registrationCount || 0;
                const percentFull = capacity > 0 ? Math.min(100, Math.round((registrations / capacity) * 100)) : 0;
                return {
                    ...row,
                    capacityDisplay: capacity > 0 ? String(capacity) : 'Not set',
                    statusTheme: this.getStatusTheme(row),
                    readinessTheme: this.getReadinessTheme(row),
                    registrationSummary: capacity > 0 ? `${registrations}/${capacity} (${this.formatPercent(registrations, capacity)})` : `${registrations} registered`,
                    capacityFillStyle: `width:${percentFull}%;`,
                    capacityFillClass: `capacity-fill ${this.getCapacityFillClass(percentFull)}`,
                    isSelected: this.selectedRowIds.includes(row.id)
                };
            });
            this.totalCount = data?.totalCount || 0;
            const currentIds = new Set(this.rows.map((row) => row.id));
            this.selectedRowIds = this.selectedRowIds.filter((id) => currentIds.has(id));
            this.rows = this.rows.map((row) => ({ ...row, isSelected: this.selectedRowIds.includes(row.id) }));
            this.loadError = undefined;
            this.persistViewState();
        } catch (error) {
            this.rows = [];
            this.totalCount = 0;
            this.loadError = error?.body?.message || 'Could not load instances. Please refresh.';
        } finally {
            this.isLoading = false;
        }
    }

    handleSearch(event) {
        const value = event.target.value;
        this.searchKey = value;
        if (this.searchDebounceTimer) {
            clearTimeout(this.searchDebounceTimer);
        }
        this.searchDebounceTimer = setTimeout(() => {
            this.pageNumber = 1;
            this.loadRows();
        }, 300);
    }

    handlePageSize(event) {
        this.pageSize = Number(event.detail.value);
        this.pageNumber = 1;
        this.loadRows();
    }

    handlePrevPage() {
        if (!this.disablePrev) {
            this.pageNumber -= 1;
            this.loadRows();
        }
    }

    handleNextPage() {
        if (!this.disableNext) {
            this.pageNumber += 1;
            this.loadRows();
        }
    }

    handleSelectAllRows(event) {
        const checked = event.target.checked;
        this.selectedRowIds = checked ? this.rows.map((row) => row.id) : [];
        this.rows = this.rows.map((row) => ({ ...row, isSelected: checked }));
    }

    handleRowSelection(event) {
        const rowId = event.currentTarget?.dataset?.id;
        const checked = event.target.checked;
        if (!rowId) {
            return;
        }
        const ids = new Set(this.selectedRowIds);
        if (checked) {
            ids.add(rowId);
        } else {
            ids.delete(rowId);
        }
        this.selectedRowIds = [...ids];
        this.rows = this.rows.map((row) => (row.id === rowId ? { ...row, isSelected: checked } : row));
    }

    openFilterModal() {
        this.draftBucketFilter = this.bucketFilter;
        this.draftProgramCode = this.programCode;
        this.isFilterModalOpen = true;
    }

    closeFilterModal() {
        this.isFilterModalOpen = false;
    }

    handleDraftBucket(event) {
        this.draftBucketFilter = event.detail.value;
    }

    handleDraftProgram(event) {
        this.draftProgramCode = event.detail.value;
    }

    applyFilters() {
        this.bucketFilter = this.draftBucketFilter || 'Upcoming';
        this.programCode = this.draftProgramCode || '';
        this.isFilterModalOpen = false;
        this.pageNumber = 1;
        this.loadRows();
    }

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

    handleGearSelect(event) {
        const action = event.detail.value;
        if (action === 'fields') {
            this.openFieldModal();
        }
        if (action === 'reset') {
            this.resetToDefaultView();
        }
    }

    resetToDefaultView() {
        this.visibleColumnKeys = [...DEFAULT_VISIBLE_COLUMN_KEYS];
        this.bucketFilter = 'Upcoming';
        this.programCode = '';
        this.searchKey = '';
        this.sortField1 = 'startDate';
        this.sortDir1 = 'ASC';
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

    navigateHome() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuEventsHome' }
        });
    }

    navigateToCreateEvent() {
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: { componentName: 'c__fiuInstanceCreateWizard' }
        });
    }

    closeQuickView() {
        this.resetCopiedRegisterUrlState();
        this.selectedInstanceId = null;
    }

    handleExportMenuSelect(event) {
        const action = event.detail.value;
        if (action === 'selected') {
            this.handleExportSelected();
        }
        if (action === 'filtered') {
            this.handleExportFiltered();
        }
    }

    handleExportSelected() {
        if (!this.selectedRowIds.length) {
            return;
        }
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
            programCode: this.programCode || '',
            eventId: this.eventId || '',
            sortField1: this.sortField1 || '',
            sortDir1: this.sortDir1 || '',
            sortField2: this.sortField2 || '',
            sortDir2: this.sortDir2 || ''
        });
        window.open(`/apex/ExportCsv?${params.toString()}`, '_blank');
    }

    openQuickViewFromButton(event) {
        const rowId = event.currentTarget?.dataset?.id;
        if (rowId) {
            this.resetCopiedRegisterUrlState();
            this.selectedInstanceId = rowId;
        }
    }

    openSelectedInstanceRecord() {
        if (!this.selectedInstance) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.selectedInstance.id, actionName: 'view' }
        });
    }

    cloneSelectedInstance() {
        if (!this.selectedInstance) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.selectedInstance.id,
                objectApiName: 'summit__Summit_Events_Instance__c',
                actionName: 'clone'
            }
        });
    }

    openSelectedInstanceRegistrations() {
        if (!this.selectedInstance) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuRegistrationBrowser' },
            state: { c__instanceId: this.selectedInstance.id, c__program: this.programCode || '' }
        });
    }

    async handleCopyRegisterUrl() {
        const registerUrl = this.selectedInstance?.registerUrl;
        if (!registerUrl) {
            return;
        }
        try {
            await navigator.clipboard.writeText(registerUrl);
            this.hasCopiedRegisterUrl = true;
            if (this.copyResetTimer) {
                clearTimeout(this.copyResetTimer);
            }
            this.copyResetTimer = setTimeout(() => {
                this.hasCopiedRegisterUrl = false;
                this.copyResetTimer = null;
            }, 1600);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Copied',
                    message: 'Registration URL copied to clipboard.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Copy failed',
                    message: 'Could not copy the registration URL automatically.',
                    variant: 'error'
                })
            );
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

    getStatusTheme(row) {
        return row.activeStatus === 'Active' ? 'success' : 'neutral';
    }

    getReadinessTheme(row) {
        return row.readiness === 'Ready' ? 'success' : 'error';
    }

    getCapacityFillClass(percent) {
        if (percent >= 90) {
            return 'capacity-fill--danger';
        }
        if (percent >= 70) {
            return 'capacity-fill--warning';
        }
        return 'capacity-fill--success';
    }

    formatPercent(registrations, capacity) {
        if (!capacity || capacity <= 0) {
            return '0%';
        }
        const percent = (registrations / capacity) * 100;
        if (percent > 0 && percent < 1) {
            return `${percent.toFixed(1)}%`;
        }
        return `${Math.round(percent)}%`;
    }

    getSortIcon(fieldName) {
        if (this.sortField1 !== fieldName) {
            return 'utility:chevrondown';
        }
        return this.sortDir1 === 'ASC' ? 'utility:arrowup' : 'utility:arrowdown';
    }
}
