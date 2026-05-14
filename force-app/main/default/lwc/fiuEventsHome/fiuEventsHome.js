import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import USER_FIRST_NAME_FIELD from '@salesforce/schema/User.FirstName';
import loadDashboard from '@salesforce/apex/FiuHomeDashboardService.loadDashboard';
import getProgramOptions from '@salesforce/apex/FiuProgramFilterService.getProgramOptions';

export default class FiuEventsHome extends NavigationMixin(LightningElement) {
    dashboard;
    dashboardWire;
    userId = USER_ID;
    programCode = '';
    programOptions = [{ label: 'All Programs', value: '' }];
    showWelcome = true;
    isRefreshing = false;
    hasLoadedDashboardOnce = false;

    connectedCallback() {
        try {
            this.showWelcome = window.localStorage.getItem('fiuEventsHomeWelcomeDismissed') !== '1';
        } catch (e) {
            this.showWelcome = true;
        }
    }

    @wire(loadDashboard, { programCode: '$programCode' })
    wiredDashboard(value) {
        this.dashboardWire = value;
        if (value.data) {
            this.dashboard = value.data;
            this.hasLoadedDashboardOnce = true;
        }
        if (value.data || value.error) {
            this.isRefreshing = false;
        }
    }

    @wire(getProgramOptions)
    wiredPrograms({ data }) {
        if (data) this.programOptions = [{ label: 'All Programs', value: '' }, ...data];
    }

    @wire(getRecord, { recordId: '$userId', fields: [USER_FIRST_NAME_FIELD] })
    wiredUser;

    get kpiUpcoming() { return this.dashboard?.upcomingInstances ?? 0; }
    get kpiOpenRegs() { return this.dashboard?.openRegistrations ?? 0; }
    get kpiStartedRegs() { return this.dashboard?.startedRegistrations ?? 0; }
    get kpiNotReady() { return this.dashboard?.notReadyInstances ?? 0; }
    get kpiNotReadyEvents() { return this.dashboard?.notReadyEvents ?? 0; }
    get kpiActiveEvents() { return this.dashboard?.activeEvents ?? 0; }
    get dashboardReady() { return this.hasLoadedDashboardOnce; }
    get isFirstRun() {
        return this.dashboardReady &&
            this.kpiActiveEvents === 0 &&
            this.kpiUpcoming === 0 &&
            this.kpiOpenRegs === 0 &&
            this.kpiStartedRegs === 0 &&
            this.kpiNotReady === 0 &&
            this.kpiNotReadyEvents === 0;
    }
    get showOperationalDashboard() {
        return this.dashboardReady && !this.isFirstRun;
    }
    get readinessIssueCount() {
        return this.kpiNotReady + this.kpiNotReadyEvents;
    }
    get hasReadinessIssues() {
        return this.readinessIssueCount > 0;
    }
    get hasStartedFollowUp() {
        return this.kpiStartedRegs > 0;
    }

    get attentionRows() {
        const rows = this.dashboard?.attentionRows ?? [];
        return rows.map((row, idx) => ({ ...row, rowKey: row.instanceId || row.eventId || `row-${idx}` }));
    }

    get upcomingRows() { return this.dashboard?.upcomingRows ?? []; }
    get hasAttentionRows() { return this.attentionRows.length > 0; }
    get hasUpcomingRows() { return this.upcomingRows.length > 0; }

    get selectedProgramLabel() {
        const selected = this.programOptions.find((opt) => opt.value === this.programCode);
        return selected ? selected.label : 'All Programs';
    }

    get attentionCount() { return this.readinessIssueCount; }
    get upcomingCount() { return this.upcomingRows.length; }
    get registrationFollowUpClass() {
        return this.hasStartedFollowUp ? 'kpi-tile kpi-tile--follow-up' : 'kpi-tile';
    }
    get readinessKpiClass() {
        return this.hasReadinessIssues ? 'kpi-tile kpi-tile--warn' : 'kpi-tile';
    }
    get registrationFollowUpHint() {
        return this.hasStartedFollowUp ? 'Review started' : 'No follow-up';
    }
    get readinessKpiHint() {
        return this.hasReadinessIssues ? 'Review list' : 'All clear';
    }
    get currentUserFirstName() {
        return getFieldValue(this.wiredUser?.data, USER_FIRST_NAME_FIELD) || 'there';
    }

    dismissWelcome() {
        this.showWelcome = false;
        try {
            window.localStorage.setItem('fiuEventsHomeWelcomeDismissed', '1');
        } catch (e) {
            // no-op
        }
    }

    async refreshDashboard() {
        if (!this.dashboardWire || this.isRefreshing) return;
        this.isRefreshing = true;
        try {
            await refreshApex(this.dashboardWire);
        } catch (e) {
            this.isRefreshing = false;
        }
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

    reviewNotReadyEvents() {
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
        // Use navItemPage for in-app Lightning tabs; webPage is for external URLs.
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

    handleGuidedAction(event) {
        const action = event.currentTarget?.dataset?.action;
        if (action === 'create') this.openCreateWizard();
        if (action === 'clone') this.openCloneWizard();
        if (action === 'instance') this.openInstances();
        if (action === 'bulk') this.openRegistrationsMassUpdate();
    }

    handleKpiClick(event) {
        const action = event.currentTarget?.dataset?.action;
        if (action === 'events') this.openEvents();
        if (action === 'instances') this.openInstances();
        if (action === 'registrationFollowUp') this.openStartedRegistrations();
        if (action === 'readinessIssues') this.focusReadinessIssues();
    }

    focusReadinessIssues() {
        const panel = this.template.querySelector('.attention-panel');
        if (panel) panel.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
}
