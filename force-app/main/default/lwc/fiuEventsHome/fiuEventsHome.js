import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import USER_FIRST_NAME_FIELD from '@salesforce/schema/User.FirstName';
import loadDashboard from '@salesforce/apex/FiuHomeDashboardService.loadDashboard';
import getProgramOptions from '@salesforce/apex/FiuProgramFilterService.getProgramOptions';

const ATTENTION_PREVIEW_LIMIT = 5;
const UPCOMING_PREVIEW_LIMIT = 5;

export default class FiuEventsHome extends NavigationMixin(LightningElement) {
    dashboard;
    userId = USER_ID;
    programCode = '';
    programOptions = [{ label: 'All Programs', value: '' }];
    hasLoadedDashboardOnce = false;

    @wire(loadDashboard, { programCode: '$programCode' })
    wiredDashboard({ data }) {
        if (data) {
            this.dashboard = data;
            this.hasLoadedDashboardOnce = true;
        }
    }

    @wire(getProgramOptions)
    wiredPrograms({ data }) {
        if (data) this.programOptions = [{ label: 'All Programs', value: '' }, ...data];
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
        const selected = this.programOptions.find((opt) => opt.value === this.programCode);
        return selected ? selected.label : 'All Programs';
    }

    get scopeIsAll() {
        return !this.programCode;
    }

    get scopeChipLabel() {
        return this.scopeIsAll ? 'All Programs' : this.scopeLabel;
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

    handleProgram(event) {
        this.programCode = event.detail.value;
    }

    openInstances() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuInstanceBrowser' },
            state: { c__bucket: 'Upcoming', c__program: this.programCode || '' }
        });
    }

    openEvents() {
        this[NavigationMixin.Navigate]({ type: 'standard__navItemPage', attributes: { apiName: 'fiuEventBrowser' } });
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
            state: { c__readiness: 'NotReady', c__program: this.programCode || '' }
        });
    }

    openRegistrations() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuRegistrationBrowser' },
            state: { c__status: 'Open', c__program: this.programCode || '' }
        });
    }

    openRegistrationsMassUpdate() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuRegistrationBrowser' },
            state: { c__status: 'Open', c__program: this.programCode || '', c__openMassUpdate: '1' }
        });
    }

    openStartedRegistrations() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuRegistrationBrowser' },
            state: { c__status: 'Started', c__program: this.programCode || '' }
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
}
