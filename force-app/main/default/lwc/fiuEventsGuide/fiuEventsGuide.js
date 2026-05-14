import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class FiuEventsGuide extends NavigationMixin(LightningElement) {
    navigateHome() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuEventsHome' }
        });
    }

    navigateEvents() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuEventBrowser' }
        });
    }

    navigateCreateWizard() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'fiuEventCreateWizard' }
        });
    }

    handleTocClick(event) {
        const anchor = event.currentTarget?.dataset?.anchor;
        if (!anchor) return;
        const target = this.template.querySelector(`[data-section="${anchor}"]`);
        if (target && typeof target.scrollIntoView === 'function') {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }
}
