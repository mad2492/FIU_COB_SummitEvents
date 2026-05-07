import LightningDatatable from 'lightning/datatable';
import pillTemplate from './pillType.html';

export default class FiuDatatable extends LightningDatatable {
    static customTypes = {
        pill: {
            template: pillTemplate,
            standardCellLayout: true,
            typeAttributes: ['label', 'theme']
        }
    };
}
