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

const COLUMN_DEFS = [
    { key: 'name', label: 'Registration', type: 'link', sortable: true, defaultVisible: true },
    { key: 'contact', label: 'Contact', type: 'text', valueKey: 'contactDisplayName', warnKey: 'contactIssue', sortable: false, defaultVisible: true },
    { key: 'email', label: 'Email', type: 'text', sortable: true, defaultVisible: true },
    { key: 'eventName', label: 'Event', type: 'text', sortable: true, defaultVisible: true },
    { key: 'instanceName', label: 'Instance', type: 'text', sortable: true, defaultVisible: true },
    { key: 'instanceStartDate', label: 'Instance Start', type: 'date', sortable: true, defaultVisible: true },
    { key: 'instanceEndDate', label: 'Instance End', type: 'date', sortable: true, defaultVisible: false },
    { key: 'locationTypeOverride', label: 'Location Type', type: 'text', sortable: true, defaultVisible: false },
    { key: 'processStatus', label: 'Status', type: 'badge', themeKey: 'processStatusTheme', sortable: true, defaultVisible: true }
];

const DEFAULT_VISIBLE_COLUMN_KEYS = COLUMN_DEFS.filter((c) => c.defaultVisible).map((c) => c.key);

export default class FiuRegistrationBrowser extends NavigationMixin(LightningElement) {
    columns = COLUMN_DEFS;
    rows = [];
    selectedRowIds = [];
    selectedRegistrationId;
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
    loadError = '';

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
        { label: 'Registered / Active', value: 'Open' },
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

    // ---- derived state
    get selectedRegistration() {
        return this.rows.find((row) => row.id === this.selectedRegistrationId);
    }

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

    get fieldChooserOptions() {
        return COLUMN_DEFS.map((column) => ({ label: column.label, value: column.key }));
    }

    get scopeIsClearable() {
        return !!this.instanceId;
    }

    get quickViewTitle() {
        return this.selectedRegistration?.contactDisplayName || '';
    }

    get quickViewSubhead() {
        if (!this.selectedRegistration) return '';
        const parts = [];
        if (this.selectedRegistration.email) parts.push(this.selectedRegistration.email);
        if (this.selectedRegistration.name) parts.push(this.selectedRegistration.name);
        return parts.join(' · ');
    }

    get selectedCount() {
        return this.selectedRowIds.length;
    }

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
                ...data.map((value) => ({ label: value, value }))
            ];
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    restoreViewState() {
        try {
            const raw = window.sessionStorage.getItem(VIEW_STATE_KEY);
            if (!raw) return;
            const savedState = JSON.parse(raw);
            if (Array.isArray(savedState.visibleColumnKeys) && savedState.visibleColumnKeys.length) this.visibleColumnKeys = savedState.visibleColumnKeys;
            if (typeof savedState.pageSize === 'number') this.pageSize = savedState.pageSize;
            if (typeof savedState.statusFilter === 'string') this.statusFilter = savedState.statusFilter;
            if (typeof savedState.programCode === 'string' && !this.instanceId) this.programCode = savedState.programCode;
            if (typeof savedState.locationTypeOverrideFilter === 'string') this.locationTypeOverrideFilter = savedState.locationTypeOverrideFilter;
            if (typeof savedState.sortField1 === 'string') this.sortField1 = savedState.sortField1;
            if (typeof savedState.sortDir1 === 'string') this.sortDir1 = savedState.sortDir1;
            if (typeof savedState.sortField2 === 'string') this.sortField2 = savedState.sortField2;
            if (typeof savedState.sortDir2 === 'string') this.sortDir2 = savedState.sortDir2;
        } catch (error) {
            // ignore malformed view state
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

    async loadRows() {
        this.isLoading = true;
        this.loadError = '';
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
            this.rows = baseRows.map((row) => ({
                ...row,
                contactDisplayName: row.contactName || 'Missing Contact',
                processStatusTheme: this.getProcessStatusTheme(row.processStatus),
                isStarted: row.processStatus === 'Started'
            }));
            if (this.instanceId && this.rows.length > 0 && this.rows[0].instanceName) {
                this.instanceScopeLabel = `Scoped to: ${this.rows[0].instanceName}`;
            } else if (this.instanceId) {
                this.instanceScopeLabel = 'Scoped to selected instance';
            }
            const currentIds = new Set(this.rows.map((row) => row.id));
            this.selectedRowIds = this.selectedRowIds.filter((id) => currentIds.has(id));
            if (this.selectedRegistrationId && !currentIds.has(this.selectedRegistrationId)) {
                this.selectedRegistrationId = null;
            }
            this.persistViewState();
        } catch (error) {
            this.rows = [];
            this.totalCount = 0;
            this.loadError = error?.body?.message || 'Could not load registrations.';
        } finally {
            this.isLoading = false;
        }
    }

    // ---- shell events
    handleSearch(event) {
        this.searchKey = event.detail.value;
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
        this.selectedRegistrationId = this.selectedRegistrationId === rowId ? null : rowId;
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
        if (key === 'program') this.programCode = '';
        if (key === 'locationType') this.locationTypeOverrideFilter = '';
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

    handleInlineLocationType(event) {
        this.locationTypeOverrideFilter = event.detail.value || '';
        this.pageNumber = 1;
        this.loadRows();
    }

    handleClearScope() {
        // Drop the instance scope by re-navigating to the bare browser nav item.
        // The CurrentPageReference wire fires with no state and rebuilds clean.
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuRegistrationBrowser' }
        });
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
        this.selectedRegistrationId = null;
    }

    handleBreadcrumbHome() {
        this.navigateHome();
    }

    // ---- filter modal
    openFilterModal() {
        this.draftStatusFilter = this.statusFilter;
        this.draftProgramCode = this.programCode;
        this.draftLocationTypeOverrideFilter = this.locationTypeOverrideFilter;
        this.isFilterModalOpen = true;
    }

    closeFilterModal() {
        this.isFilterModalOpen = false;
    }

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

    // ---- navigation
    navigateHome() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuEventsHome' }
        });
    }

    openSelectedRegistrationRecord() {
        if (!this.selectedRegistration) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.selectedRegistration.id, objectApiName: 'summit__Summit_Events_Registration__c', actionName: 'view' }
        });
    }

    editSelectedRegistrationStatus() {
        if (!this.selectedRegistration) return;
        this.selectedRowIds = [this.selectedRegistration.id];
        this.openMassModal();
        this.updateStatusEnabled = true;
        this.massStatus = this.selectedRegistration.processStatus || '';
    }

    // ---- export / import
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

    // ---- mass update modal
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

    closeMassModal() {
        this.isMassModalOpen = false;
    }

    handleToggleStatus(event) {
        this.updateStatusEnabled = event.target.checked;
        if (!this.updateStatusEnabled) this.massStatus = '';
    }

    handleToggleEvent(event) {
        this.updateEventEnabled = event.target.checked;
        if (!this.updateEventEnabled) this.massEventId = undefined;
    }

    handleToggleInstance(event) {
        this.updateInstanceEnabled = event.target.checked;
        if (!this.updateInstanceEnabled) this.massInstanceId = undefined;
    }

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
        } catch (error) {
            this.inlineErrorMessage = error?.body?.message || 'Mass update failed.';
        }
    }

    // ---- themes
    getProcessStatusTheme(status) {
        if (status === 'Started') return 'warning';
        if (status === 'Cancelled') return 'neutral';
        if (!status) return 'neutral';
        return 'success';
    }
}
