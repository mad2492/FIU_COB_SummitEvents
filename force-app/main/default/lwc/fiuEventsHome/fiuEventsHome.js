import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import loadDashboard from '@salesforce/apex/FiuHomeDashboardService.loadDashboard';
import getProgramOptions from '@salesforce/apex/FiuProgramFilterService.getProgramOptions';

export default class FiuEventsHome extends NavigationMixin(LightningElement) {
    dashboard;
    programCode = '';
    programOptions = [{ label: 'All Programs', value: '' }];

    @wire(loadDashboard, { programCode: '$programCode' })
    wiredDashboard({ data }) {
        if (data) this.dashboard = data;
    }

    @wire(getProgramOptions)
    wiredPrograms({ data }) {
        if (data) this.programOptions = [{ label: 'All Programs', value: '' }, ...data];
    }

    get kpiUpcoming() { return this.dashboard?.upcomingInstances ?? 0; }
    get kpiOpenRegs() { return this.dashboard?.openRegistrations ?? 0; }
    get kpiNotReady() { return this.dashboard?.notReadyInstances ?? 0; }
    get kpiNotReadyEvents() { return this.dashboard?.notReadyEvents ?? 0; }
    get kpiActiveEvents() { return this.dashboard?.activeEvents ?? 0; }

    get attentionRows() { return this.dashboard?.attentionRows ?? []; }
    get upcomingRows() { return this.dashboard?.upcomingRows ?? []; }
    get selectedProgramLabel() {
        const selected = this.programOptions.find((opt) => opt.value === this.programCode);
        return selected ? selected.label : 'All Programs';
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

    reviewNotReadyEvents() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuEventBrowser' },
            state: { c__readiness: 'NotReady', c__program: this.programCode || '' }
        });
    }

    openRegistrations() {
        this[NavigationMixin.Navigate]({ type: 'standard__navItemPage', attributes: { apiName: 'fiuRegistrationBrowser' } });
    }
}
