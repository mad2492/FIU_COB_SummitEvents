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
        if (value.data) this.dashboard = value.data;
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

    get attentionRows() {
        const rows = this.dashboard?.attentionRows ?? [];
        return rows.map((row, idx) => ({ ...row, rowKey: row.instanceId || row.eventId || `row-${idx}` }));
    }

    get upcomingRows() { return this.dashboard?.upcomingRows ?? []; }

    get selectedProgramLabel() {
        const selected = this.programOptions.find((opt) => opt.value === this.programCode);
        return selected ? selected.label : 'All Programs';
    }

    get attentionCount() { return this.attentionRows.length; }
    get upcomingCount() { return this.upcomingRows.length; }
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

    refreshDashboard() {
        if (this.dashboardWire) refreshApex(this.dashboardWire);
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

    resolveIssues() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuInstanceBrowser' },
            state: { c__bucket: 'Unpublished', c__program: this.programCode || '' }
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
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/lightning/n/fiuEventsGuide' }
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
        if (action === 'clone') this.openEvents();
        if (action === 'instance') this.openInstances();
        if (action === 'bulk') this.openRegistrationsMassUpdate();
    }
}
