import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import confirmBusBooking from '@salesforce/apex/BusAgent.confirmBusBooking';

export default class BusResultsRenderer extends LightningElement {
    @track busData = [];
    @track searchRequest = {
        originCity: '',
        destinationCity: '',
        dateOfTravel: ''
    };
    @track confirmedBooking = {};
    @track showBookingConfirmation = false;

    selectedBusId = null;
    passengerName = '';
    passengerEmail = '';
    passengerPhone = '';
    seatNumbers = '';

    @track passengerNameError = false;
    @track passengerEmailError = false;
    @track seatNumbersError = false;

    @api
    get value() {
        return this._value;
    }
    set value(value) {
        this._value = value;
        this.processBusData(value);
    }

    processBusData(value) {
        if (!value) {
            return;
        }
        this.busData = (value.buses || []).map((bus) => ({
            ...bus,
            durationInHr: this.formattedDuration(bus.durationInMin),
            isSelected: false,
            cssClass: 'bus-card'
        }));

        this.searchRequest = {
            originCity: value.originCity || '',
            destinationCity: value.destinationCity || '',
            dateOfTravel: value.dateOfTravel || null
        };
    }

    formattedDuration(durationInMin) {
        if (!durationInMin) {
            return '';
        }
        const hours = Math.floor(durationInMin / 60);
        const minutes = durationInMin % 60;
        return `${hours} hr ${minutes} min`;
    }

    handleSelectBus(event) {
        const busId = event.target.dataset.busId;
        this.selectedBusId = busId;

        this.busData = this.busData.map((bus) => ({
            ...bus,
            isSelected: bus.busId === busId,
            cssClass: bus.busId === busId ? 'bus-card selected' : 'bus-card'
        }));

        this.resetForm();
        this.clearErrors();
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
        this.clearFieldError(field);
    }

    clearFieldError(field) {
        const errorMap = {
            passengerName: 'passengerNameError',
            passengerEmail: 'passengerEmailError',
            seatNumbers: 'seatNumbersError'
        };
        if (errorMap[field]) {
            this[errorMap[field]] = false;
        }
    }

    clearErrors() {
        this.passengerNameError = false;
        this.passengerEmailError = false;
        this.seatNumbersError = false;
    }

    get passengerNameClass() {
        return this.passengerNameError ? 'input-error' : '';
    }

    get passengerEmailClass() {
        return this.passengerEmailError ? 'input-error' : '';
    }

    get seatNumbersClass() {
        return this.seatNumbersError ? 'input-error' : '';
    }

    validateForm() {
        let isValid = true;
        this.clearErrors();

        if (!this.passengerName || this.passengerName.trim() === '') {
            this.passengerNameError = true;
            isValid = false;
        }

        const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!this.passengerEmail || !emailPattern.test(this.passengerEmail)) {
            this.passengerEmailError = true;
            isValid = false;
        }

        if (!this.seatNumbers || this.seatNumbers.trim() === '') {
            this.seatNumbersError = true;
            isValid = false;
        }

        return isValid;
    }

    async handleConfirmBooking() {
        if (!this.selectedBusId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please select a bus by clicking "Select".',
                    variant: 'error'
                })
            );
            return;
        }

        if (!this.validateForm()) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please fill in all required fields correctly.',
                    variant: 'error'
                })
            );
            return;
        }

        const selectedBus = this.busData.find((bus) => bus.busId === this.selectedBusId);

        const bookingDetails = {
            busId: selectedBus.busId,
            busOperator: selectedBus.operator,
            departureTime: selectedBus.departureTime,
            originCity: this.searchRequest.originCity,
            destinationCity: this.searchRequest.destinationCity,
            dateOfTravel: this.searchRequest.dateOfTravel,
            seatNumbers: this.seatNumbers.trim(),
            price: selectedBus.price,
            passengerName: this.passengerName.trim(),
            passengerEmail: this.passengerEmail.trim(),
            passengerPhone: this.passengerPhone ? this.passengerPhone.trim() : ''
        };

        try {
            const result = await confirmBusBooking({ bookingDetails });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: `Booking confirmed! Reference ID: ${result.referenceId}`,
                    variant: 'success'
                })
            );

            this.confirmedBooking = {
                ...bookingDetails,
                referenceId: result.referenceId
            };
            this.showBookingConfirmation = true;
            this.resetForm();
            this.clearErrors();
        } catch (error) {
            const errorMessage = error?.body?.message || error?.message || 'An unexpected error occurred.';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Booking Error',
                    message: 'Failed to create booking: ' + errorMessage,
                    variant: 'error'
                })
            );
        }
    }

    handleBookAnotherBus() {
        this.showBookingConfirmation = false;
        this.confirmedBooking = {};
        this.resetForm();
        this.clearErrors();

        this.busData = this.busData.map((bus) => ({
            ...bus,
            isSelected: false,
            cssClass: 'bus-card'
        }));
    }

    resetForm() {
        this.passengerName = '';
        this.passengerEmail = '';
        this.passengerPhone = '';
        this.seatNumbers = '';
    }
}
