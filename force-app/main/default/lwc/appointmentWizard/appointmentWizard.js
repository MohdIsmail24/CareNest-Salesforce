import { LightningElement, api, track, wire } from 'lwc';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import DOCTOR_SELECTED_CHANNEL from '@salesforce/messageChannel/Doctor_Selected__c';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getUserContext from '@salesforce/apex/DoctorSearchController.getUserContext';
import searchPatients from '@salesforce/apex/DoctorSearchController.searchPatients';
import bookAppointment from '@salesforce/apex/DoctorSearchController.bookAppointment';

export default class AppointmentWizard extends LightningElement {
    @api recordId; // Available when placed on Doctor__c record page

    @track currentStep = '1';
    @track doctorId = null;
    @track doctorName = '';
    @track selectedSlotId = '';
    @track selectedSlotLabel = '';
    @track selectedSlotFee = 0;
    @track selectedSlotMode = '';
    @track selectedSlotStart = '';

    // Patient State
    @track isPortalPatient = false;
    @track selectedPatientId = '';
    @track patientName = '';
    @track patientCode = '';
    @track patientSearchKey = '';
    @track patientSearchResults = [];

    @track isSubmitting = false;
    @track error = null;
    @track confirmedAppt = {};
    @track isBillingModalOpen = false;

    subscription = null;
    searchTimeout = null;

    @wire(MessageContext)
    messageContext;

    @wire(getUserContext)
    wiredContext({ data }) {
        if (data && data.isPatient && data.contactId) {
            this.isPortalPatient = true;
            this.selectedPatientId = data.contactId;
            this.patientName = data.contactName;
        }
    }

    connectedCallback() {
        this.subscribeToMessageChannel();
        if (this.recordId) {
            this.doctorId = this.recordId;
        }
    }

    disconnectedCallback() {
        this.unsubscribeFromMessageChannel();
    }

    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                DOCTOR_SELECTED_CHANNEL,
                (message) => this.handleDoctorSelectedMessage(message)
            );
        }
    }

    unsubscribeFromMessageChannel() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
    }

    handleDoctorSelectedMessage(message) {
        if (message && message.doctorId) {
            this.doctorId = message.doctorId;
            this.doctorName = message.doctorName || 'Selected Doctor';
            this.selectedSlotId = '';
            this.error = null;
        }
    }

    get effectiveDoctorId() {
        return this.recordId || this.doctorId || null;
    }

    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }
    get isStep3() { return this.currentStep === '3'; }
    get isStep4() { return this.currentStep === '4'; }

    get showNavigationButtons() { return this.currentStep !== '4'; }
    get canGoBack() { return this.currentStep === '2' || this.currentStep === '3'; }

    get isNextDisabled() {
        if (this.isStep1) {
            return !this.effectiveDoctorId || !this.selectedSlotId;
        }
        if (this.isStep2) {
            return !this.selectedPatientId;
        }
        return false;
    }

    get formattedSlotTime() {
        if (!this.selectedSlotStart) return this.selectedSlotLabel;
        return new Date(this.selectedSlotStart).toLocaleString('en-US', {
            weekday: 'short',
            month: 'short',
            day: 'numeric',
            year: 'numeric',
            hour: 'numeric',
            minute: '2-digit',
            hour12: true
        });
    }

    get confirmedApptDoctor() {
        if (this.confirmedAppt && this.confirmedAppt.Slot__r && this.confirmedAppt.Slot__r.Doctor__r) {
            return this.confirmedAppt.Slot__r.Doctor__r.Name;
        }
        return this.doctorName;
    }

    handleSlotSelected(event) {
        const detail = event.detail;
        this.selectedSlotId = detail.slotId;
        this.selectedSlotLabel = detail.slotLabel;
        this.selectedSlotFee = detail.fee;
        this.selectedSlotMode = detail.mode;
        this.selectedSlotStart = detail.slotStart;
        this.error = null;
    }

    handlePatientSearchChange(event) {
        clearTimeout(this.searchTimeout);
        const searchVal = event.target.value;
        this.patientSearchKey = searchVal;

        if (!searchVal || searchVal.trim().length < 2) {
            this.patientSearchResults = [];
            return;
        }

        this.searchTimeout = setTimeout(() => {
            searchPatients({ searchKey: searchVal })
                .then(results => {
                    this.patientSearchResults = results;
                })
                .catch(err => {
                    this.error = err.body ? err.body.message : 'Error searching patients';
                });
        }, 300);
    }

    handleSelectPatient(event) {
        this.selectedPatientId = event.currentTarget.dataset.id;
        this.patientName = event.currentTarget.dataset.name;
        this.patientCode = event.currentTarget.dataset.code;
        this.patientSearchResults = [];
        this.error = null;
    }

    handleNext() {
        if (this.currentStep === '1') {
            this.currentStep = '2';
        } else if (this.currentStep === '2') {
            this.currentStep = '3';
        }
    }

    handleBack() {
        if (this.currentStep === '3') {
            this.currentStep = '2';
        } else if (this.currentStep === '2') {
            this.currentStep = '1';
        }
    }

    async handleConfirmBooking() {
        if (this.isSubmitting) return; // Prevent duplicate submission

        this.isSubmitting = true;
        this.error = null;

        try {
            const result = await bookAppointment({
                slotId: this.selectedSlotId,
                patientId: this.selectedPatientId
            });

            this.confirmedAppt = result;
            this.currentStep = '4';

            this.dispatchEvent(new ShowToastEvent({
                title: 'Booking Confirmed',
                message: `Appointment ${result.Name} has been booked successfully!`,
                variant: 'success'
            }));
        } catch (err) {
            this.error = err.body ? err.body.message : 'Error confirming appointment';
            this.dispatchEvent(new ShowToastEvent({
                title: 'Booking Failed',
                message: this.error,
                variant: 'error'
            }));
        } finally {
            this.isSubmitting = false;
        }
    }

    handleReset() {
        this.currentStep = '1';
        this.selectedSlotId = '';
        this.selectedSlotLabel = '';
        this.selectedSlotFee = 0;
        this.confirmedAppt = {};
        if (!this.isPortalPatient) {
            this.selectedPatientId = '';
            this.patientName = '';
            this.patientCode = '';
        }
        this.error = null;
    }

    handleOpenDemoPayment() {
        this.isBillingModalOpen = true;
    }

    handleCloseBillingModal() {
        this.isBillingModalOpen = false;
    }
}
