import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import USER_FIRST_NAME_FIELD from '@salesforce/schema/User.FirstName';
import loadDashboard from '@salesforce/apex/FiuHomeDashboardService.loadDashboard';
import getProgramOptions from '@salesforce/apex/FiuProgramFilterService.getProgramOptions';
import getEventRecordTypeOptions from '@salesforce/apex/FiuEventsAccessService.getEventRecordTypeOptions';

const ATTENTION_PREVIEW_LIMIT = 5;
const UPCOMING_PREVIEW_LIMIT = 5;
const APP_SCOPE_KEY = 'fiuEventsAppScopeV1';

export default class FiuEventsHome extends NavigationMixin(LightningElement) {
    dashboard;
    userId = USER_ID;
    recordTypeId = '';
    availableRecordTypeOptions = [];
    recordTypeOptions = [{ label: 'All Record Types', value: '' }];
    programCode = '';
    programOptions = [{ label: 'All Programs', value: '' }];
    hasLoadedDashboardOnce = false;

    connectedCallback() {
        this.restoreAppScope();
    }

    @wire(loadDashboard, { programCode: '$programCode', recordTypeId: '$recordTypeId' })
    wiredDashboard({ data }) {
        if (data) {
            this.dashboard = data;
            this.hasLoadedDashboardOnce = true;
        }
    }

    @wire(getEventRecordTypeOptions)
    wiredRecordTypes({ data }) {
        if (data) {
            this.availableRecordTypeOptions = data;
            this.recordTypeOptions = data.length > 1 ? [{ label: 'All Record Types', value: '' }, ...data] : data;
            this.normalizeRecordTypeScope();
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

    @wire(getRecord, { recordId: '$userId', fields: [USER_FIRST_NAME_FIELD] })
    wiredUser;

    get currentUserFirstName() {
        return getFieldValue(this.wiredUser?.data, USER_FIRST_NAME_FIELD) || 'there';
    }

    get greetingTitle() {
        return `Welcome back, ${this.currentUserFirstName}`;
    }

    get greetingSubtitle() {
        return 'Here\'s what needs your attention today.';
    }

    get dashboardReady() { return this.hasLoadedDashboardOnce; }

    get kpiUpcoming() { return this.dashboard?.upcomingInstances ?? 0; }
    get kpiOpenRegs() { return this.dashboard?.openRegistrations ?? 0; }
    get kpiStartedRegs() { return this.dashboard?.startedRegistrations ?? 0; }
    get kpiNotReady() { return this.dashboard?.notReadyInstances ?? 0; }
    get kpiNotReadyEvents() { return this.dashboard?.notReadyEvents ?? 0; }
    get kpiActiveEvents() { return this.dashboard?.activeEvents ?? 0; }

    get attentionCount() {
        return this.kpiNotReady + this.kpiNotReadyEvents;
    }

    get hasAttention() { return this.attentionCount > 0; }
    get hasFollowUp() { return this.kpiStartedRegs > 0; }
    get hasOpenRegs() { return this.kpiOpenRegs > 0; }
    get hasUpcoming() { return this.kpiUpcoming > 0; }

    get isFirstRun() {
        // Surface the first-setup state whenever the org has no active events,
        // regardless of stray registrations or readiness issues from past activity.
        return this.dashboardReady && this.kpiActiveEvents === 0;
    }

    get showOperationalDashboard() {
        return this.dashboardReady && !this.isFirstRun;
    }

    get showSkeleton() {
        return !this.dashboardReady;
    }

    get scopeLabel() {
        const recordTypeLabel = this.recordTypeOptions.find((opt) => opt.value === this.recordTypeId)?.label || 'All Record Types';
        const programLabel = this.programOptions.find((opt) => opt.value === this.programCode)?.label || 'All Programs';
        return `${recordTypeLabel} / ${programLabel}`;
    }

    get scopeIsAll() {
        return !this.recordTypeId && !this.programCode;
    }

    get scopeChipLabel() {
        return this.scopeIsAll ? 'All Record Types / All Programs' : this.scopeLabel;
    }

    get showRecordTypePicker() {
        return this.availableRecordTypeOptions.length > 1;
    }

    get attentionRows() {
        const rows = this.dashboard?.attentionRows ?? [];
        return rows.slice(0, ATTENTION_PREVIEW_LIMIT).map((row, idx) => ({
            ...row,
            rowKey: row.instanceId || row.eventId || `row-${idx}`
        }));
    }

    get hasAttentionRows() { return this.attentionRows.length > 0; }

    get attentionOverflowCount() {
        const total = this.dashboard?.attentionRows?.length ?? 0;
        const extra = total - ATTENTION_PREVIEW_LIMIT;
        return extra > 0 ? extra : 0;
    }

    get hasAttentionOverflow() {
        return this.attentionOverflowCount > 0;
    }

    get attentionOverflowLabel() {
        return `View all ${this.attentionCount} →`;
    }

    get upcomingRows() {
        const rows = this.dashboard?.upcomingRows ?? [];
        return rows.slice(0, UPCOMING_PREVIEW_LIMIT);
    }

    get hasUpcomingRows() { return this.upcomingRows.length > 0; }

    get upcomingOverflowCount() {
        const total = this.dashboard?.upcomingRows?.length ?? 0;
        const extra = total - UPCOMING_PREVIEW_LIMIT;
        return extra > 0 ? extra : 0;
    }

    get hasUpcomingOverflow() {
        return this.upcomingOverflowCount > 0;
    }

    get upcomingOverflowLabel() {
        return `View all ${this.kpiUpcoming} →`;
    }

    get upcomingPanelSubtitle() {
        return this.scopeIsAll ? 'Next on the calendar' : `Next on the calendar · ${this.scopeLabel}`;
    }

    get attentionPanelSubtitle() {
        const base = 'Events and instances with readiness issues';
        return this.scopeIsAll ? base : `${base} · ${this.scopeLabel}`;
    }

    // KPI tile styling and hints
    get upcomingKpiClass() {
        return 'kpi-tile' + (this.hasUpcoming ? '' : ' kpi-tile--muted');
    }
    get upcomingKpiHint() {
        return this.hasUpcoming ? 'View calendar →' : 'Nothing scheduled';
    }

    get openRegsKpiClass() {
        return 'kpi-tile' + (this.hasOpenRegs ? '' : ' kpi-tile--muted');
    }
    get openRegsKpiHint() {
        return this.hasOpenRegs ? 'View registrants →' : 'None yet';
    }

    get followUpKpiClass() {
        if (this.hasFollowUp) return 'kpi-tile kpi-tile--warn';
        return 'kpi-tile kpi-tile--success';
    }
    get followUpKpiHint() {
        return this.hasFollowUp ? 'Recover started →' : 'All caught up ✓';
    }

    get attentionKpiClass() {
        if (this.hasAttention) return 'kpi-tile kpi-tile--warn';
        return 'kpi-tile kpi-tile--success';
    }
    get attentionKpiHint() {
        return this.hasAttention ? 'Review issues →' : 'All clear ✓';
    }

    handleRecordType(event) {
        this.recordTypeId = event.detail.value;
        this.programCode = '';
        this.persistAppScope();
    }

    handleProgram(event) {
        this.programCode = event.detail.value;
        this.persistAppScope();
    }

    get navigationScopeState() {
        return {
            c__program: this.programCode || '',
            c__recordType: this.recordTypeId || ''
        };
    }

    openInstances() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuInstanceBrowser' },
            state: { ...this.navigationScopeState, c__bucket: 'Upcoming' }
        });
    }

    openEvents() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuEventBrowser' },
            state: this.navigationScopeState
        });
    }

    openCreateWizard() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuEventCreateWizard' }
        });
    }

    openCloneWizard() {
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: { componentName: 'c__fiuEventCloneWizard' }
        });
    }

    openInstanceCreate() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuInstanceCreateWizard' }
        });
    }

    openNotReadyEvents() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuEventBrowser' },
            state: { ...this.navigationScopeState, c__readiness: 'NotReady' }
        });
    }

    openRegistrations() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuRegistrationBrowser' },
            state: { ...this.navigationScopeState, c__status: 'Open' }
        });
    }

    openRegistrationsMassUpdate() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuRegistrationBrowser' },
            state: { ...this.navigationScopeState, c__status: 'Open', c__openMassUpdate: '1' }
        });
    }

    openStartedRegistrations() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuRegistrationBrowser' },
            state: { ...this.navigationScopeState, c__status: 'Started' }
        });
    }

    openGuide() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuEventsGuide' }
        });
    }

    openAttentionFix(event) {
        const eventId = event.currentTarget?.dataset?.eventId;
        const instanceId = event.currentTarget?.dataset?.instanceId;
        if (eventId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: eventId, objectApiName: 'summit__Summit_Events__c', actionName: 'view' }
            });
            return;
        }
        if (instanceId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: instanceId, objectApiName: 'summit__Summit_Events_Instance__c', actionName: 'view' }
            });
        }
    }

    openUpcomingRow(event) {
        const instanceId = event.currentTarget?.dataset?.instanceId;
        if (!instanceId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: instanceId, objectApiName: 'summit__Summit_Events_Instance__c', actionName: 'view' }
        });
    }

    handleGuidedAction(event) {
        const action = event.currentTarget?.dataset?.action;
        if (action === 'instance') this.openInstanceCreate();
        if (action === 'create') this.openCreateWizard();
        if (action === 'clone') this.openCloneWizard();
        if (action === 'manage') this.openRegistrationsMassUpdate();
    }

    handleKpiClick(event) {
        const action = event.currentTarget?.dataset?.action;
        if (action === 'upcoming') this.openInstances();
        if (action === 'openRegs') this.openRegistrations();
        if (action === 'followUp') this.openStartedRegistrations();
        if (action === 'attention') this.openNotReadyEvents();
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

    normalizeRecordTypeScope() {
        if (this.availableRecordTypeOptions.length === 1) {
            const onlyRecordTypeId = this.availableRecordTypeOptions[0].value;
            if (this.recordTypeId !== onlyRecordTypeId) {
                this.recordTypeId = onlyRecordTypeId;
                this.programCode = '';
                this.persistAppScope();
            }
        } else if (this.recordTypeId && !this.availableRecordTypeOptions.some((option) => option.value === this.recordTypeId)) {
            this.recordTypeId = '';
            this.programCode = '';
            this.persistAppScope();
        }
    }
}
