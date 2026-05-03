import { LightningElement } from 'lwc';

export default class FiuEventsLauncher extends LightningElement {
    mode = 'create';

    handleRoute(event) {
        this.mode = event.currentTarget.dataset.mode;
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
