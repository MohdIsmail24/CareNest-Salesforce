import { LightningElement, api, track, wire } from 'lwc';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import DOCTOR_SELECTED_CHANNEL from '@salesforce/messageChannel/Doctor_Selected__c';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getUserContext from '@salesforce/apex/DoctorSearchController.getUserContext';
import searchPatients from '@salesforce/apex/DoctorSearchController.searchPatients';
import bookFlexibleAppointment from '@salesforce/apex/CareNestAppointmentController.bookFlexibleAppointment';
import getSchedulingInitData from '@salesforce/apex/CareNestAppointmentController.getSchedulingInitData';

export default class AppointmentWizard extends LightningElement {
    @api recordId; // Doctor__c record page context

    @track currentStep = '1';
    @track doctorId = null;
    @track doctorName = '';
    @track selectedDepartment = 'Cardiology';
    @track selectedDoctorId = null;
    @track allDoctors = [];
    @track departmentsList = [];

    // Scheduling Mode: 'slot' | 'manual'
    @track schedulingMode = 'slot';
    @track manualDate = '';
    @track manualTime = '10:30';
    @track manualMode = 'OPD';

    // Slot Selection
    @track selectedSlotId = '';
    @track selectedSlotLabel = '';
    @track selectedSlotFee = 800;
    @track selectedSlotMode = 'OPD';
    @track selectedSlotStart = '';

    // Conflict & Smart Alternatives
    @track bookingConflict = false;
    @track conflictMessage = '';
    @track alternativeSlots = [];

    // Patient State
    @track isPortalPatient = false;
    @track selectedPatientId = '';
    @track patientName = '';
    @track patientCode = '';
    @track patientSearchKey = '';
    @track patientSearchResults = [];

    // Modals
    @track isPatientRegModalOpen = false;
    @track isBillingModalOpen = false;

    @track isSubmitting = false;
    @track error = null;
    @track confirmedAppt = {};

    subscription = null;
    searchTimeout = null;

    modeOptions = [
        { label: 'OPD (In-Person Consultation)', value: 'OPD' },
        { label: 'Teleconsult (Video Call)', value: 'Teleconsult' }
    ];

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
            this.selectedDoctorId = this.recordId;
        }

        // Set default manual date to tomorrow
        const tmrw = new Date();
        tmrw.setDate(tmrw.getDate() + 1);
        this.manualDate = tmrw.toISOString().slice(0, 10);

        this.loadSchedulingData();
    }

    disconnectedCallback() {
        this.unsubscribeFromMessageChannel();
    }

    async loadSchedulingData() {
        try {
            const initData = await getSchedulingInitData();
            if (initData) {
                this.departmentsList = initData.departments || [];
                this.allDoctors = initData.doctors || [];

                if (this.recordId) {
                    const match = this.allDoctors.find(d => d.id === this.recordId);
                    if (match) {
                        this.selectedDoctorId = match.id;
                        this.doctorName = match.name;
                        this.selectedDepartment = match.department;
                        this.selectedSlotFee = match.consultationFee;
                    }
                }
            }
        } catch (e) {
            console.error('Error loading scheduling init data:', e);
        }
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
            this.selectedDoctorId = message.doctorId;
            this.doctorName = message.doctorName || 'Selected Doctor';
            this.selectedSlotId = '';
            this.error = null;
            this.bookingConflict = false;

            const doc = this.allDoctors.find(d => d.id === message.doctorId);
            if (doc) {
                this.selectedDepartment = doc.department;
                this.selectedSlotFee = doc.consultationFee;
            }
        }
    }

    // Getters for Selectors
    get departmentOptions() {
        const list = [{ label: 'All Medical Departments', value: 'All' }];
        (this.departmentsList || []).forEach(dep => {
            list.push({ label: dep, value: dep });
        });
        return list;
    }

    get doctorOptions() {
        const list = [{ label: 'Any Available Doctor (Auto-Assign)', value: '' }];
        const filtered = (this.selectedDepartment && this.selectedDepartment !== 'All')
            ? this.allDoctors.filter(d => d.department === this.selectedDepartment)
            : this.allDoctors;

        filtered.forEach(d => {
            list.push({ label: `${d.name} (${d.specialty || d.department})`, value: d.id });
        });
        return list;
    }

    get effectiveDoctorId() {
        return this.recordId || this.selectedDoctorId || null;
    }

    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }
    get isStep3() { return this.currentStep === '3'; }
    get isStep4() { return this.currentStep === '4'; }

    get isSlotPickerMode() { return this.schedulingMode === 'slot'; }
    get isManualTimeMode() { return this.schedulingMode === 'manual'; }

    get slotModeButtonClass() {
        return `slds-button ${this.isSlotPickerMode ? 'slds-button_brand' : 'slds-button_neutral'}`;
    }

    get manualModeButtonClass() {
        return `slds-button ${this.isManualTimeMode ? 'slds-button_brand' : 'slds-button_neutral'}`;
    }

    get showNavigationButtons() { return this.currentStep !== '4'; }
    get canGoBack() { return this.currentStep === '2' || this.currentStep === '3'; }

    get isNextDisabled() {
        if (this.isStep1) {
            if (this.isSlotPickerMode) {
                return !this.selectedSlotId;
            }
            if (this.isManualTimeMode) {
                return !this.manualDate || !this.manualTime;
            }
        }
        if (this.isStep2) {
            return !this.selectedPatientId;
        }
        return false;
    }

    get formattedSlotTime() {
        if (this.isManualTimeMode) {
            return `${this.manualDate} at ${this.manualTime} (${this.manualMode})`;
        }
        if (!this.selectedSlotStart) return this.selectedSlotLabel;
        try {
            return new Date(this.selectedSlotStart).toLocaleString('en-US', {
                weekday: 'short',
                month: 'short',
                day: 'numeric',
                year: 'numeric',
                hour: 'numeric',
                minute: '2-digit',
                hour12: true
            });
        } catch (e) {
            return this.selectedSlotLabel;
        }
    }

    get confirmedApptDoctor() {
        if (this.confirmedAppt && this.confirmedAppt.Slot__r && this.confirmedAppt.Slot__r.Doctor__r) {
            return this.confirmedAppt.Slot__r.Doctor__r.Name;
        }
        return this.doctorName || 'Assigned Doctor';
    }

    // Handlers
    handleDepartmentChange(e) {
        this.selectedDepartment = e.target.value;
        this.selectedSlotId = '';
        this.selectedDoctorId = null;
        this.doctorName = '';
        this.bookingConflict = false;
    }

    handleDoctorDropdownChange(e) {
        const val = e.target.value;
        this.selectedDoctorId = val || null;
        this.selectedSlotId = '';
        this.bookingConflict = false;

        if (val) {
            const doc = this.allDoctors.find(d => d.id === val);
            if (doc) {
                this.doctorName = doc.name;
                this.selectedDepartment = doc.department;
                this.selectedSlotFee = doc.consultationFee;
            }
        } else {
            this.doctorName = 'Any Available Doctor';
        }
    }

    handleSetSlotPickerMode() {
        this.schedulingMode = 'slot';
        this.bookingConflict = false;
    }

    handleSetManualTimeMode() {
        this.schedulingMode = 'manual';
        this.bookingConflict = false;
    }

    handleManualDateChange(e) { this.manualDate = e.target.value; this.bookingConflict = false; }
    handleManualTimeChange(e) { this.manualTime = e.target.value; this.bookingConflict = false; }
    handleManualModeChange(e) { this.manualMode = e.target.value; }

    handleSlotSelected(event) {
        const detail = event.detail;
        this.selectedSlotId = detail.slotId;
        this.selectedSlotLabel = detail.slotLabel;
        this.selectedSlotFee = detail.fee || this.selectedSlotFee;
        this.selectedSlotMode = detail.mode;
        this.selectedSlotStart = detail.slotStart;
        this.error = null;
        this.bookingConflict = false;
    }

    handleSelectAlternativeSlot(event) {
        const slotId = event.currentTarget.dataset.id;
        const slotLabel = event.currentTarget.dataset.label;
        const fee = Number(event.currentTarget.dataset.fee);
        const mode = event.currentTarget.dataset.mode;
        const slotStart = event.currentTarget.dataset.start;

        this.selectedSlotId = slotId;
        this.selectedSlotLabel = slotLabel;
        this.selectedSlotFee = fee || this.selectedSlotFee;
        this.selectedSlotMode = mode;
        this.selectedSlotStart = slotStart;
        this.schedulingMode = 'slot';
        this.bookingConflict = false;

        this.dispatchEvent(new ShowToastEvent({
            title: 'Alternative Slot Selected',
            message: `Selected open slot: ${slotLabel}`,
            variant: 'info'
        }));
    }

    // Patient Search and Registration
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

    handleOpenPatientRegistrationModal() {
        this.isPatientRegModalOpen = true;
    }

    handleClosePatientRegistrationModal() {
        this.isPatientRegModalOpen = false;
    }

    handlePatientCreated(event) {
        const detail = event.detail;
        if (detail && detail.patientId) {
            this.selectedPatientId = detail.patientId;
            this.patientName = detail.patientName;
            this.patientCode = detail.patientCode;
            this.patientSearchResults = [];
            this.error = null;
            this.isPatientRegModalOpen = false;

            this.dispatchEvent(new ShowToastEvent({
                title: 'Patient Ready',
                message: `Patient ${detail.patientName} (${detail.patientCode}) selected for appointment booking.`,
                variant: 'success'
            }));
        }
    }

    // Wizard Step Navigation
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

    // Booking Submission with Atomic Concurrency Protection
    async handleConfirmBooking() {
        if (this.isSubmitting) return;

        this.isSubmitting = true;
        this.error = null;
        this.bookingConflict = false;

        try {
            const slotToBook = this.isSlotPickerMode ? this.selectedSlotId : null;
            const res = await bookFlexibleAppointment({
                patientId: this.selectedPatientId,
                doctorId: this.selectedDoctorId,
                department: this.selectedDepartment,
                slotId: slotToBook,
                manualDate: this.isManualTimeMode ? this.manualDate : null,
                manualTimeStr: this.isManualTimeMode ? this.manualTime : null,
                mode: this.isManualTimeMode ? this.manualMode : this.selectedSlotMode
            });

            if (res.isConflict) {
                this.bookingConflict = true;
                this.conflictMessage = res.message;
                this.alternativeSlots = res.alternativeSlots || [];
                this.currentStep = '1';

                this.dispatchEvent(new ShowToastEvent({
                    title: 'Booking Conflict Detected',
                    message: res.message,
                    variant: 'warning'
                }));
                return;
            }

            if (res.isSuccess) {
                this.confirmedAppt = {
                    Id: res.appointmentId,
                    Name: res.appointmentCode,
                    DoctorName: res.doctorName,
                    Department: res.department,
                    PatientName: res.patientName,
                    SlotStart: res.slotStart,
                    FeeAmount: res.feeAmount,
                    TotalAmount: res.totalAmount
                };
                this.doctorName = res.doctorName;
                this.currentStep = '4';

                this.dispatchEvent(new ShowToastEvent({
                    title: 'Appointment Confirmed',
                    message: res.message,
                    variant: 'success'
                }));
            } else {
                this.error = res.message || 'Unable to confirm appointment';
            }
        } catch (err) {
            this.error = err.body ? err.body.message : (err.message || 'Error confirming appointment');
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
        this.selectedSlotFee = 800;
        this.confirmedAppt = {};
        this.bookingConflict = false;
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
