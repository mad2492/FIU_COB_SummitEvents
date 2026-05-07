import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class FiuEventsLauncher extends NavigationMixin(LightningElement) {
    mode;
    isModalOpen = false;

    handleRoute(event) {
        const mode = event.currentTarget.dataset.mode;
        if (mode === 'create') {
            this[NavigationMixin.Navigate]({
                type: 'standard__navItemPage',
                attributes: { apiName: 'fiuEventCreateWizard' }
            });
            return;
        }
        this.mode = mode;
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    get isCreate() {
        return this.mode === 'create';
    }

    get isClone() {
        return this.mode === 'clone';
    }

    get isInstance() {
        return this.mode === 'instance';
    }

    get selectedHeading() {
        if (this.mode === 'clone') {
            return 'Clone Existing Event';
        }
        if (this.mode === 'instance') {
            return 'Add New Instance to Existing Event';
        }
        return 'Create New Event';
    }
}
