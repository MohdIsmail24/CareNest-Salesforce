import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMyAppointments from '@salesforce/apex/DoctorSearchController.getMyAppointments';
import cancelAppointment from '@salesforce/apex/DoctorSearchController.cancelAppointment';

export default class MyAppointments extends LightningElement {
    @track appointments = [];
    isLoading = true;
    isUnauthenticated = false;
    showGeneralError = false;
    error = '';

    isCancelModalOpen = false;
    selectedApptId = null;
    cancelReason = '';
    cancelError = '';
    isCancelling = false;

    isBillingModalOpen = false;
    selectedBillingApptId = null;

    wiredAppointmentsResult;

    @wire(getMyAppointments)
    wiredAppointments(result) {
        this.wiredAppointmentsResult = result;
        const { data, error } = result;

        this.isLoading = false;

        if (data) {
            this.isUnauthenticated = false;
            this.showGeneralError = false;
            this.error = '';
            this.appointments = data.map(appt => {
                const slot = appt.Slot__r || {};
                const doctor = slot.Doctor__r || {};
                const slotStart = slot.Slot_Start__c;

                let formattedTime = 'N/A';
                if (slotStart) {
                    try {
                        const d = new Date(slotStart);
                        formattedTime = new Intl.DateTimeFormat('en-US', {
                            weekday: 'short',
                            year: 'numeric',
                            month: 'short',
                            day: 'numeric',
                            hour: 'numeric',
                            minute: '2-digit',
                            hour12: true
                        }).format(d);
                    } catch (e) {
                        formattedTime = slotStart;
                    }
                }

                let badgeClass = 'slds-badge';
                if (appt.Status__c === 'Confirmed') {
                    badgeClass = 'slds-badge slds-theme_success';
                } else if (appt.Status__c === 'Pending') {
                    badgeClass = 'slds-badge slds-badge_inverse';
                } else if (appt.Status__c === 'Cancelled') {
                    badgeClass = 'slds-badge slds-theme_error';
                } else if (appt.Status__c === 'Completed') {
                    badgeClass = 'slds-badge';
                } else if (appt.Status__c === 'No Show') {
                    badgeClass = 'slds-badge slds-theme_warning';
                }

                const canCancel = appt.Status__c === 'Pending' || appt.Status__c === 'Confirmed';
                const showPayBill = appt.Status__c !== 'Cancelled';

                return {
                    Id: appt.Id,
                    Name: appt.Name,
                    DoctorName: doctor.Name || 'Assigned Doctor',
                    Department: doctor.Department__c || 'General',
                    Mode: slot.Mode__c || 'OPD',
                    Status__c: appt.Status__c,
                    Total_Amount__c: appt.Total_Amount__c != null ? appt.Total_Amount__c : 0,
                    Amount_Paid__c: appt.Amount_Paid__c != null ? appt.Amount_Paid__c : 0,
                    Balance_Due__c: appt.Balance_Due__c != null ? appt.Balance_Due__c : 0,
                    formattedTime: formattedTime,
                    statusBadgeClass: badgeClass,
                    canCancel: canCancel,
                    showPayBill: showPayBill
                };
            });
        } else if (error) {
            this.appointments = [];
            const msg = error.body && error.body.message ? error.body.message : (error.message || 'Unknown error');
            if (msg.includes('patient profile') || msg.includes('patient portal user') || msg.includes('ContactId')) {
                this.isUnauthenticated = true;
                this.showGeneralError = false;
            } else {
                this.isUnauthenticated = false;
                this.showGeneralError = true;
                this.error = msg;
            }
        }
    }

    get hasAppointments() {
        return !this.isLoading && !this.isUnauthenticated && !this.showGeneralError && this.appointments && this.appointments.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && !this.isUnauthenticated && !this.showGeneralError && (!this.appointments || this.appointments.length === 0);
    }

    handleOpenBillingModal(event) {
        this.selectedBillingApptId = event.target.dataset.id;
        this.isBillingModalOpen = true;
    }

    handleCloseBillingModal() {
        this.isBillingModalOpen = false;
        this.selectedBillingApptId = null;
    }

    handleOpenCancelModal(event) {
        this.selectedApptId = event.target.dataset.id;
        this.cancelReason = '';
        this.cancelError = '';
        this.isCancelModalOpen = true;
    }

    handleCloseCancelModal() {
        this.isCancelModalOpen = false;
        this.selectedApptId = null;
        this.cancelReason = '';
        this.cancelError = '';
        this.isCancelling = false;
    }

    handleReasonChange(event) {
        this.cancelReason = event.target.value;
        this.cancelError = '';
    }

    async handleConfirmCancellation() {
        if (!this.cancelReason || !this.cancelReason.trim()) {
            this.cancelError = 'Please specify a reason for cancellation.';
            return;
        }

        this.isCancelling = true;
        this.cancelError = '';

        try {
            const result = await cancelAppointment({
                appointmentId: this.selectedApptId,
                reason: this.cancelReason.trim()
            });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Appointment Cancelled',
                message: `Cancellation fee: ₹${result.fee != null ? result.fee : 0}. Refund amount: ₹${result.refund != null ? result.refund : 0}.`,
                variant: 'success'
            }));

            this.handleCloseCancelModal();
            await refreshApex(this.wiredAppointmentsResult);
        } catch (err) {
            this.cancelError = err.body && err.body.message ? err.body.message : (err.message || 'Failed to cancel appointment.');
        } finally {
            this.isCancelling = false;
        }
    }
}
