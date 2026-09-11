import { api, LightningElement } from 'lwc';

export default class BusSearchEditor extends LightningElement {
    @api readOnly = false;

    _value = {};

    @api
    get value() {
        return this._value;
    }
    set value(val) {
        this._value = val;
        if (val) {
            this.originCity = val.originCity ?? '';
            this.destinationCity = val.destinationCity ?? '';
            this.dateOfTravel = val.dateOfTravel ?? '';
        }
    }

    originCity = '';
    destinationCity = '';
    dateOfTravel = '';

    handleInputChange(event) {
        event.stopPropagation();
        const { name, value } = event.target;
        this[name] = value;

        this.dispatchEvent(
            new CustomEvent('valuechange', {
                detail: {
                    value: {
                        originCity: this.originCity,
                        destinationCity: this.destinationCity,
                        dateOfTravel: this.dateOfTravel
                    }
                }
            })
        );
    }
}
