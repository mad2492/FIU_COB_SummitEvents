import { LightningElement, api } from 'lwc';

const DEFAULT_PAGE_SIZE_OPTIONS = [
    { label: '25', value: '25' },
    { label: '50', value: '50' },
    { label: '100', value: '100' }
];

export default class FiuListShell extends LightningElement {
    // ---- page header
    @api breadcrumbLabel = 'Home';
    @api currentCrumb;
    @api pageTitle = '';

    // ---- list shell header
    @api iconName = 'utility:list';
    @api iconColor = '#5867e8';
    @api listTitle = '';
    @api totalCount = 0;
    @api objectLabel = 'Record'; // e.g., "Event"

    @api hintText = '';
    @api hintIcon = 'utility:info';
    get showHint() { return !!this.hintText; }

    // ---- toolbar
    @api searchValue = '';
    @api searchPlaceholder = 'Search this list...';
    @api enableRefresh = false;
    @api hideSettingsMenu = false;
    @api filtersButtonLabel = 'Filters';

    // ---- columns + rows
    @api columns = [];           // [{ key, label, type, sortable, themeKey, width, alignment, defaultVisible }]
    @api rows = [];              // domain rows; each must have id; cells looked up by column.key
    @api visibleColumnKeys = []; // ordered list
    @api selectedRowId;
    @api selectedRowIds = [];
    @api sortField;
    @api sortDir = 'ASC';

    // ---- loading + empty state
    @api isLoading = false;
    @api errorMessage = '';
    @api emptyTitle = 'No records to display.';
    @api emptyBody = 'Try adjusting your search or filters, or clear all to start over.';
    @api hideEmptyClear = false;

    // ---- pager
    @api pageNumber = 1;
    @api pageSize = 25;
    @api pageSizeOptions = DEFAULT_PAGE_SIZE_OPTIONS;

    // ---- filters
    @api activeFilterPills = [];
    @api scopeLabel = '';
    @api scopeClearable = false;
    @api hideBulkSelection = false;

    // ---- quick-view rail
    @api quickViewTitle = '';
    @api quickViewSubhead = '';

    _lastFocusedSelectedId;

    // ---- derived
    get showSettingsMenu() { return !this.hideSettingsMenu; }
    get showBulkSelection() { return !this.hideBulkSelection; }
    get showEmptyClear() { return !this.hideEmptyClear; }

    get pageHeaderCrumbLabel() {
        return this.currentCrumb || this.pageTitle;
    }

    get hasActiveFilters() {
        return Array.isArray(this.activeFilterPills) && this.activeFilterPills.length > 0;
    }

    get showFilterBand() {
        return this.hasActiveFilters || !!this.scopeLabel;
    }

    get hasRows() {
        return Array.isArray(this.rows) && this.rows.length > 0;
    }

    get showEmptyState() {
        return !this.hasRows && !this.isLoading && !this.errorMessage;
    }

    get hasError() {
        return !!this.errorMessage;
    }

    get totalPages() {
        const size = this.pageSize > 0 ? this.pageSize : 25;
        return Math.max(1, Math.ceil((this.totalCount || 0) / size));
    }

    get disablePrev() { return this.pageNumber <= 1; }
    get disableNext() { return this.pageNumber >= this.totalPages; }
    get pageSizeValue() { return String(this.pageSize); }

    get visibleColumns() {
        if (!Array.isArray(this.columns)) return [];
        const keys = Array.isArray(this.visibleColumnKeys) && this.visibleColumnKeys.length
            ? this.visibleColumnKeys
            : this.columns.filter((c) => c.defaultVisible !== false).map((c) => c.key);
        const byKey = new Map(this.columns.map((c) => [c.key, c]));
        return keys
            .map((k) => byKey.get(k))
            .filter(Boolean)
            .map((col) => this.decorateColumnForHeader(col));
    }

    get hasRail() {
        return !!this.selectedRowId;
    }

    get layoutClass() {
        return this.hasRail ? 'browser-layout browser-layout--panel-open' : 'browser-layout';
    }

    get listIconStyle() {
        return `background:${this.iconColor};`;
    }

    get allRowsSelected() {
        if (!this.hasRows) return false;
        const ids = new Set(this.selectedRowIds || []);
        return this.rows.every((r) => ids.has(r.id));
    }

    get quickViewEyebrow() {
        const idx = this.selectedRowIndex;
        if (idx >= 0 && this.rows.length > 1) {
            return `${this.objectLabel} · ${idx + 1} of ${this.rows.length}`;
        }
        return `${this.objectLabel} quick view`;
    }

    get quickViewAriaLabel() {
        return `${this.objectLabel} quick view`;
    }

    get selectedRowIndex() {
        if (!this.selectedRowId || !Array.isArray(this.rows)) return -1;
        return this.rows.findIndex((r) => r.id === this.selectedRowId);
    }

    get disableQuickViewPrev() {
        return this.selectedRowIndex <= 0;
    }

    get disableQuickViewNext() {
        const idx = this.selectedRowIndex;
        return idx < 0 || idx >= this.rows.length - 1;
    }

    get displayRows() {
        const cols = this.visibleColumns;
        const selectedIds = new Set(this.selectedRowIds || []);
        return (this.rows || []).map((row) => {
            const cells = cols.map((col) => this.buildCell(col, row));
            const isQuickViewed = row.id === this.selectedRowId;
            return {
                id: row.id,
                _raw: row,
                cells,
                isSelected: selectedIds.has(row.id),
                isQuickViewed,
                rowClass: 'fls-row' + (isQuickViewed ? ' fls-row--active' : ''),
                quickViewIcon: isQuickViewed ? 'utility:chevrondown' : 'utility:chevronright'
            };
        });
    }

    get pagerSummary() {
        return `Page ${this.pageNumber} of ${this.totalPages} (${this.totalCount} ${this.totalCount === 1 ? 'record' : 'records'})`;
    }

    get countLabel() {
        const n = this.totalCount || 0;
        return `${n} ${n === 1 ? 'record' : 'records'}`;
    }

    get selectionCount() {
        return Array.isArray(this.selectedRowIds) ? this.selectedRowIds.length : 0;
    }

    get hasSelection() {
        return this.selectionCount > 0;
    }

    get selectionLabel() {
        const n = this.selectionCount;
        return `${n} selected`;
    }

    handleClearSelection() {
        this.dispatchEvent(new CustomEvent('clearselection'));
    }

    handleClearScope() {
        this.dispatchEvent(new CustomEvent('clearscope'));
    }

    handleCellAction(event) {
        event.stopPropagation();
        const rowId = event.currentTarget?.dataset?.id;
        const action = event.currentTarget?.dataset?.action;
        if (!rowId || !action) return;
        this.dispatchEvent(new CustomEvent('cellaction', { detail: { rowId, action } }));
    }

    stopRowClick(event) {
        event.stopPropagation();
    }

    decorateColumnForHeader(col) {
        const isSorted = this.sortField === col.key;
        const isAsc = (this.sortDir || 'ASC').toUpperCase() === 'ASC';
        let icon = 'utility:chevrondown';
        if (isSorted) icon = isAsc ? 'utility:arrowup' : 'utility:arrowdown';
        return {
            ...col,
            sortIcon: icon,
            isSortable: !!col.sortable,
            headerClass: 'fls-th' + (col.width ? '' : '') + (col.alignment === 'end' ? ' fls-th--end' : '')
        };
    }

    buildCell(col, row) {
        const value = col.valueKey ? row[col.valueKey] : row[col.key];
        const type = col.type || 'text';
        const theme = col.themeKey ? row[col.themeKey] : undefined;
        const isWarn = col.warnKey ? !!row[col.warnKey] : false;
        const cellClass = 'fls-td'
            + (col.alignment === 'end' ? ' fls-td--end' : '')
            + (type === 'multiline' ? ' fls-td--wrap' : '')
            + (type === 'capacity' ? ' fls-td--capacity' : '')
            + (isWarn ? ' fls-td--warn' : '');
        const base = {
            key: `${row.id}::${col.key}`,
            colKey: col.key,
            value,
            theme,
            cellClass,
            action: col.action || '',
            actionTooltip: col.actionTooltip || '',
            isText: type === 'text',
            isDate: type === 'date',
            isDateTime: type === 'datetime',
            isNumber: type === 'number',
            isBadge: type === 'badge',
            isLink: type === 'link',
            isMultiline: type === 'multiline',
            isCapacity: type === 'capacity',
            isCountLink: type === 'count-link'
        };
        if (type === 'capacity' && value && typeof value === 'object') {
            const percent = Math.max(0, Math.min(100, Number(value.percent) || 0));
            const tier = value.tier === 'danger' ? 'danger'
                : value.tier === 'warning' ? 'warning'
                : 'success';
            return {
                ...base,
                capacitySummary: value.summary || '',
                capacityFillStyle: `width:${percent}%;`,
                capacityFillClass: `fls-capacity__fill fls-capacity__fill--${tier}`
            };
        }
        return base;
    }

    // ---- event handlers
    handleSearch(event) {
        const value = event.target?.value || '';
        this.dispatchEvent(new CustomEvent('search', { detail: { value } }));
    }

    handleRefresh() {
        this.dispatchEvent(new CustomEvent('refresh'));
    }

    handleOpenFilters() {
        this.dispatchEvent(new CustomEvent('openfilters'));
    }

    handleGearSelect(event) {
        const value = event.detail.value;
        if (value === 'fields') this.dispatchEvent(new CustomEvent('opensettings'));
        if (value === 'reset') this.dispatchEvent(new CustomEvent('resetview'));
    }

    handleRemovePill(event) {
        const key = event.target.name;
        this.dispatchEvent(new CustomEvent('removepill', { detail: { key } }));
    }

    handleClearFilters() {
        this.dispatchEvent(new CustomEvent('clearfilters'));
    }

    handleSortHeader(event) {
        const field = event.currentTarget?.dataset?.field;
        if (!field) return;
        const current = this.sortField === field ? (this.sortDir || 'ASC').toUpperCase() : null;
        const next = current === 'ASC' ? 'DESC' : 'ASC';
        this.dispatchEvent(new CustomEvent('sortchange', { detail: { field, direction: next } }));
    }

    handleSelectAllRows(event) {
        const checked = event.target.checked;
        this.dispatchEvent(new CustomEvent('rowselectall', { detail: { checked } }));
    }

    handleRowSelectionChange(event) {
        event.stopPropagation();
        const rowId = event.currentTarget?.dataset?.id;
        if (!rowId) return;
        this.dispatchEvent(new CustomEvent('rowselect', { detail: { rowId, checked: event.target.checked } }));
    }

    handleRowClick(event) {
        const rowId = event.currentTarget?.dataset?.id;
        if (!rowId) return;
        this.dispatchEvent(new CustomEvent('rowclick', { detail: { rowId } }));
    }

    handleNameClick(event) {
        event.stopPropagation();
        const rowId = event.currentTarget?.dataset?.id;
        if (!rowId) return;
        this.dispatchEvent(new CustomEvent('rowclick', { detail: { rowId } }));
    }

    handleQuickViewToggle(event) {
        event.stopPropagation();
        const rowId = event.currentTarget?.dataset?.id;
        if (!rowId) return;
        this.dispatchEvent(new CustomEvent('rowclick', { detail: { rowId } }));
    }

    handlePrevPage() {
        if (!this.disablePrev) this.dispatchEvent(new CustomEvent('pagechange', { detail: { pageNumber: this.pageNumber - 1 } }));
    }

    handleNextPage() {
        if (!this.disableNext) this.dispatchEvent(new CustomEvent('pagechange', { detail: { pageNumber: this.pageNumber + 1 } }));
    }

    handlePageSize(event) {
        const value = Number(event.detail.value);
        this.dispatchEvent(new CustomEvent('pagesizechange', { detail: { pageSize: value } }));
    }

    handleQuickViewClose() {
        this.dispatchEvent(new CustomEvent('quickviewclose'));
    }

    handleQuickViewPrev() {
        if (this.disableQuickViewPrev) return;
        const target = this.rows[this.selectedRowIndex - 1];
        if (target) this.dispatchEvent(new CustomEvent('rowclick', { detail: { rowId: target.id } }));
    }

    handleQuickViewNext() {
        if (this.disableQuickViewNext) return;
        const target = this.rows[this.selectedRowIndex + 1];
        if (target) this.dispatchEvent(new CustomEvent('rowclick', { detail: { rowId: target.id } }));
    }

    handleQuickViewKeydown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.handleQuickViewClose();
        }
    }

    // Page-level keyboard model (mounted on the root)
    handleShellKeydown(event) {
        const tag = (event.target?.tagName || '').toLowerCase();
        const inEditable = tag === 'input' || tag === 'textarea' || event.target?.isContentEditable;

        // Slash focuses search (industry convention) — only when not in a text field
        if (!inEditable && event.key === '/') {
            event.preventDefault();
            const search = this.template.querySelector('.fls-search');
            if (search) search.focus();
            return;
        }

        // Arrow keys navigate quick-view rows when rail is open
        if (this.hasRail && (event.key === 'ArrowDown' || event.key === 'ArrowUp')) {
            if (inEditable) return;
            event.preventDefault();
            if (event.key === 'ArrowDown') this.handleQuickViewNext();
            else this.handleQuickViewPrev();
        }
    }

    handleNavigateHome() {
        this.dispatchEvent(new CustomEvent('breadcrumbhome'));
    }

    renderedCallback() {
        // focus management for quick-view title when selection changes
        if (this.selectedRowId && this._lastFocusedSelectedId !== this.selectedRowId) {
            const heading = this.template.querySelector('[data-quick-view-heading]');
            if (heading) {
                heading.focus();
                this._lastFocusedSelectedId = this.selectedRowId;
            }
        }
        if (!this.selectedRowId) {
            this._lastFocusedSelectedId = null;
        }
    }
}
