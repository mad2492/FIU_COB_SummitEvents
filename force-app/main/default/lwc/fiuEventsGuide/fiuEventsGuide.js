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
}
