import { LightningElement } from 'lwc';

export default class FiuEventsLauncher extends LightningElement {
    mode;

    handleRoute(event) {
        this.mode = event.target.dataset.mode;
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
}
