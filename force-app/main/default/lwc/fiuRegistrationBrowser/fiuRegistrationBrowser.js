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
    { key: 'name', label: 'Registration', sortable: true },
    { key: 'contact', label: 'Contact' },
    { key: 'email', label: 'Email', sortable: true },
    { key: 'eventName', label: 'Event', sortable: true },
    { key: 'instanceName', label: 'Instance', sortable: true },
    { key: 'instanceStartDate', label: 'Instance Start', sortable: true },
    { key: 'instanceEndDate', label: 'Instance End', sortable: true },
    { key: 'locationTypeOverride', label: 'Location Type', sortable: true },
    { key: 'processStatus', label: 'Status', sortable: true }
];

const DEFAULT_VISIBLE_COLUMN_KEYS = ['name', 'contact', 'email', 'eventName', 'instanceName', 'instanceStartDate', 'processStatus'];

export default class FiuRegistrationBrowser extends NavigationMixin(LightningElement) {
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

    get hasRows() {
        return this.rows.length > 0;
    }

    get allRowsSelected() {
        return this.rows.length > 0 && this.rows.every((row) => row.isSelected);
    }

    get selectedRegistration() {
        return this.rows.find((row) => row.id === this.selectedRegistrationId);
    }

    get browserLayoutClass() {
        return this.selectedRegistration ? 'browser-layout browser-layout--panel-open' : 'browser-layout';
    }

    get showNameColumn() {
        return this.visibleColumnKeys.includes('name');
    }

    get showContactColumn() {
        return this.visibleColumnKeys.includes('contact');
    }

    get showEmailColumn() {
        return this.visibleColumnKeys.includes('email');
    }

    get showEventColumn() {
        return this.visibleColumnKeys.includes('eventName');
    }

    get showInstanceColumn() {
        return this.visibleColumnKeys.includes('instanceName');
    }

    get showInstanceStartDateColumn() {
        return this.visibleColumnKeys.includes('instanceStartDate');
    }

    get showInstanceEndDateColumn() {
        return this.visibleColumnKeys.includes('instanceEndDate');
    }

    get showLocationTypeOverrideColumn() {
        return this.visibleColumnKeys.includes('locationTypeOverride');
    }

    get showProcessStatusColumn() {
        return this.visibleColumnKeys.includes('processStatus');
    }

    get nameSortIcon() {
        return this.getSortIcon('name');
    }

    get emailSortIcon() {
        return this.getSortIcon('email');
    }

    get eventNameSortIcon() {
        return this.getSortIcon('eventName');
    }

    get instanceNameSortIcon() {
        return this.getSortIcon('instanceName');
    }

    get instanceStartDateSortIcon() {
        return this.getSortIcon('instanceStartDate');
    }

    get instanceEndDateSortIcon() {
        return this.getSortIcon('instanceEndDate');
    }

    get locationTypeOverrideSortIcon() {
        return this.getSortIcon('locationTypeOverride');
    }

    get processStatusSortIcon() {
        return this.getSortIcon('processStatus');
    }

    get hasActiveFilters() {
        return !!(this.searchKey || this.statusFilter || this.programCode || this.locationTypeOverrideFilter);
    }

    get showFilterBand() {
        return !!(this.instanceScopeLabel || this.hasActiveFilters);
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
        return ALL_COLUMNS.map((column) => ({ label: column.label, value: column.key }));
    }

    get selectedCount() {
        return this.selectedRowIds.length;
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

    get statusInputDisabled() {
        return !this.updateStatusEnabled;
    }

    get eventInputDisabled() {
        return !this.updateEventEnabled;
    }

    get instanceInputDisabled() {
        return !this.updateInstanceEnabled;
    }

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
            // Ignore malformed view state.
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
            this.rows = baseRows.map((row) => ({
                ...row,
                contactDisplayName: row.contactName || 'Missing Contact',
                processStatusTheme: this.getProcessStatusTheme(row.processStatus),
                isStarted: row.processStatus === 'Started',
                quickViewIcon: row.id === this.selectedRegistrationId ? 'utility:chevrondown' : 'utility:chevronright',
                isSelected: this.selectedRowIds.includes(row.id)
            }));
            if (this.instanceId && this.rows.length > 0 && this.rows[0].instanceName) {
                this.instanceScopeLabel = `Scoped to: ${this.rows[0].instanceName}`;
            } else if (this.instanceId) {
                this.instanceScopeLabel = 'Scoped to selected instance';
            }
            const currentIds = new Set(this.rows.map((row) => row.id));
            this.selectedRowIds = this.selectedRowIds.filter((id) => currentIds.has(id));
            this.rows = this.rows.map((row) => ({ ...row, isSelected: this.selectedRowIds.includes(row.id) }));
            if (this.selectedRegistrationId && !currentIds.has(this.selectedRegistrationId)) {
                this.selectedRegistrationId = null;
            }
            this.refreshQuickViewIcons();
            this.persistViewState();
        } catch (error) {
            this.rows = [];
            this.totalCount = 0;
            this.loadError = error?.body?.message || 'Could not load registrations.';
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
        if (!rowId) return;
        const ids = new Set(this.selectedRowIds);
        if (checked) ids.add(rowId);
        else ids.delete(rowId);
        this.selectedRowIds = [...ids];
        this.rows = this.rows.map((row) => (row.id === rowId ? { ...row, isSelected: checked } : row));
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

    openQuickViewFromButton(event) {
        const rowId = event.currentTarget?.dataset?.id;
        if (!rowId) return;
        if (this.selectedRegistrationId === rowId) {
            this.closeQuickView();
            return;
        }
        this.selectedRegistrationId = rowId;
        this.refreshQuickViewIcons();
    }

    closeQuickView() {
        this.selectedRegistrationId = null;
        this.refreshQuickViewIcons();
    }

    refreshQuickViewIcons() {
        this.rows = this.rows.map((row) => ({
            ...row,
            quickViewIcon: row.id === this.selectedRegistrationId ? 'utility:chevrondown' : 'utility:chevronright'
        }));
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
        this.rows = this.rows.map((row) => ({ ...row, isSelected: row.id === this.selectedRegistration.id }));
        this.openMassModal();
        this.updateStatusEnabled = true;
        this.massStatus = this.selectedRegistration.processStatus || '';
    }

    openFilterModal() {
        this.draftStatusFilter = this.statusFilter;
        this.draftProgramCode = this.programCode;
        this.draftLocationTypeOverrideFilter = this.locationTypeOverrideFilter;
        this.isFilterModalOpen = true;
    }

    closeFilterModal() {
        this.isFilterModalOpen = false;
    }

    handleDraftStatus(event) {
        this.draftStatusFilter = event.detail.value;
    }

    handleDraftProgram(event) {
        this.draftProgramCode = event.detail.value;
    }

    handleDraftLocationTypeOverride(event) {
        this.draftLocationTypeOverrideFilter = event.detail.value;
    }

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

    handleMassStatus(event) {
        this.massStatus = event.detail.value;
    }

    handleMassEvent(event) {
        this.massEventId = event.detail.recordId;
    }

    handleMassInstance(event) {
        this.massInstanceId = event.detail.recordId;
    }

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
            this.rows = this.rows.map((row) => ({ ...row, isSelected: false }));
            this.showToast('Mass update complete', `${result.updatedCount} registration(s) updated.`, 'success');
            await this.loadRows();
        } catch (error) {
            this.inlineErrorMessage = error?.body?.message || 'Mass update failed.';
        }
    }

    getProcessStatusTheme(status) {
        if (status === 'Started') return 'warning';
        if (status === 'Cancelled') return 'neutral';
        if (!status) return 'neutral';
        return 'success';
    }

    getSortIcon(fieldName) {
        if (this.sortField1 !== fieldName) return 'utility:chevrondown';
        return this.sortDir1 === 'ASC' ? 'utility:arrowup' : 'utility:arrowdown';
    }
}
