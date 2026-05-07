import { LightningElement, api } from 'lwc';

export default class FiuDatatablePillCell extends LightningElement {
    @api label;
    @api theme;

    get computedClass() {
        return `fiu-pill fiu-pill--${this.theme || 'neutral'}`;
    }
}
