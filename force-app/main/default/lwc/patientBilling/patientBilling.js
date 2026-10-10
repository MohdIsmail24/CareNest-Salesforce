import { LightningElement, api, track } from 'lwc';
import getBillingDetails from '@salesforce/apex/DoctorSearchController.getBillingDetails';

export default class PatientBilling extends LightningElement {
    @api recordId;
    @api appointmentId;
    @api appointmentData;
    @api showCloseButton = false;

    @track currentStep = '1';
    @track isLoading = false;
    @track error = '';

    // Appointment billing fields
    @track appointmentCode = 'AP-DEMO-2026';
    @track doctorName = 'Dr. Priya Sharma';
    @track doctorDepartment = 'General Medicine';
    @track slotMode = 'OPD';
    @track formattedSlotTime = 'Oct 15, 2026 - 10:30 AM';
    @track patientName = 'Demo Patient';
    @track feeAmount = 800;
    @track discountPercent = 10;
    @track totalAmount = 720;
    @track amountPaid = 0;
    @track balanceDue = 720;

    // Payment Selection State
    @track selectedMethod = 'UPI'; // 'UPI' | 'Card' | 'Cash'

    // Demo UPI fields
    @track demoUpiId = 'patient@okaxis';

    // Demo Card fields
    @track demoCardHolder = 'Demo Patient';
    @track demoCardNumber = '4111 2222 3333 4444';
    @track demoCardExpiry = '12/28';
    @track demoCardCvv = '123';

    // Demo Cash fields
    @track isCashAcknowledged = true;

    // Demo Confirmation Receipt
    @track demoTxnId = '';
    @track demoTimestamp = '';

    connectedCallback() {
        if (this.appointmentData) {
            this.populateFromData(this.appointmentData);
        } else if (this.effectiveAppointmentId) {
            this.fetchBillingDetails();
        } else {
            // Standalone demo preview fallback
            this.initDefaultDemoData();
        }
    }

    get effectiveAppointmentId() {
        return this.recordId || this.appointmentId;
    }

    async fetchBillingDetails() {
        if (!this.effectiveAppointmentId) return;

        this.isLoading = true;
        this.error = '';

        try {
            const data = await getBillingDetails({ appointmentId: this.effectiveAppointmentId });
            this.populateFromData(data);
        } catch (err) {
            this.error = err.body ? err.body.message : (err.message || 'Error loading billing details.');
        } finally {
            this.isLoading = false;
        }
    }

    populateFromData(data) {
        if (!data) return;

        this.appointmentCode = data.Name || this.appointmentCode;
        if (data.Slot__r) {
            if (data.Slot__r.Doctor__r) {
                this.doctorName = data.Slot__r.Doctor__r.Name || this.doctorName;
                this.doctorDepartment = data.Slot__r.Doctor__r.Department__c || this.doctorDepartment;
            }
            this.slotMode = data.Slot__r.Mode__c || this.slotMode;
            if (data.Slot__r.Slot_Start__c) {
                try {
                    const d = new Date(data.Slot__r.Slot_Start__c);
                    this.formattedSlotTime = new Intl.DateTimeFormat('en-US', {
                        weekday: 'short',
                        year: 'numeric',
                        month: 'short',
                        day: 'numeric',
                        hour: 'numeric',
                        minute: '2-digit',
                        hour12: true
                    }).format(d);
                } catch (e) {
                    this.formattedSlotTime = data.Slot__r.Slot_Start__c;
                }
            }
        }

        if (data.Patient__r && data.Patient__r.Name) {
            this.patientName = data.Patient__r.Name;
            this.demoCardHolder = data.Patient__r.Name;
        } else if (data.PatientName) {
            this.patientName = data.PatientName;
            this.demoCardHolder = data.PatientName;
        }

        this.feeAmount = data.Fee_Amount__c != null ? data.Fee_Amount__c : 0;
        this.discountPercent = data.Discount_Percent__c != null ? data.Discount_Percent__c : 0;
        this.totalAmount = data.Total_Amount__c != null ? data.Total_Amount__c : (this.feeAmount - (this.feeAmount * this.discountPercent / 100));
        this.amountPaid = data.Amount_Paid__c != null ? data.Amount_Paid__c : 0;
        this.balanceDue = data.Balance_Due__c != null ? data.Balance_Due__c : (this.totalAmount - this.amountPaid);
    }

    initDefaultDemoData() {
        this.appointmentCode = 'AP-DEMO-1001';
        this.doctorName = 'Dr. Priya Sharma';
        this.doctorDepartment = 'General Medicine';
        this.slotMode = 'OPD';
        this.formattedSlotTime = 'Scheduled Slot';
        this.patientName = 'Simulated Patient';
        this.feeAmount = 800;
        this.discountPercent = 10;
        this.totalAmount = 720;
        this.amountPaid = 0;
        this.balanceDue = 720;
        this.demoCardHolder = 'Simulated Patient';
    }

    // Step Getters
    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }
    get isStep3() { return this.currentStep === '3'; }
    get isStep4() { return this.currentStep === '4'; }

    get discountAmount() {
        return (this.feeAmount * this.discountPercent) / 100;
    }

    get payableAmount() {
        // If balance due is > 0, pay balance due; if 0 (e.g. fully paid), allow a demo ₹500 test payment
        return this.balanceDue > 0 ? this.balanceDue : (this.totalAmount > 0 ? this.totalAmount : 500);
    }

    // Payment Selection Getters
    get isUpiSelected() { return this.selectedMethod === 'UPI'; }
    get isCardSelected() { return this.selectedMethod === 'Card'; }
    get isCashSelected() { return this.selectedMethod === 'Cash'; }

    get upiCardClass() {
        return `payment-method-card ${this.isUpiSelected ? 'selected' : ''}`;
    }

    get cardCardClass() {
        return `payment-method-card ${this.isCardSelected ? 'selected' : ''}`;
    }

    get cashCardClass() {
        return `payment-method-card ${this.isCashSelected ? 'selected' : ''}`;
    }

    get isMethodNotSelected() {
        return !this.selectedMethod;
    }

    get selectedMethodLabel() {
        switch (this.selectedMethod) {
            case 'UPI': return 'UPI (Simulated)';
            case 'Card': return 'Credit/Debit Card (Simulated)';
            case 'Cash': return 'Cash at Clinic Desk (Simulated)';
            default: return '';
        }
    }

    get isCashMethod() {
        return this.selectedMethod === 'Cash';
    }

    get step4Headline() {
        return this.isCashMethod
            ? 'Cash Counter Payment Recorded'
            : 'Simulated Payment Confirmed!';
    }

    get step4Subtitle() {
        return this.isCashMethod
            ? 'Cash payment instruction voucher generated. Settle at the reception counter before consultation.'
            : 'This is a simulated transaction receipt for workflow presentation and testing.';
    }

    get step4IconName() {
        return this.isCashMethod ? 'standard:address' : 'action:approval';
    }

    get receiptStatusLabel() {
        return this.isCashMethod
            ? 'Pending Counter Settlement (Demo)'
            : 'Simulated Success (Demo)';
    }

    get receiptStatusBadgeClass() {
        return this.isCashMethod
            ? 'slds-text-color_warning font-bold'
            : 'slds-text-color_success font-bold';
    }

    // Method selection handlers
    handleSelectUpi() { this.selectedMethod = 'UPI'; }
    handleSelectCard() { this.selectedMethod = 'Card'; }
    handleSelectCash() { this.selectedMethod = 'Cash'; }

    // Step navigation
    handleNextStep() {
        if (this.currentStep === '1') {
            this.currentStep = '2';
        } else if (this.currentStep === '2') {
            this.currentStep = '3';
        }
    }

    handlePreviousStep() {
        if (this.currentStep === '2') {
            this.currentStep = '1';
        } else if (this.currentStep === '3') {
            this.currentStep = '2';
        }
    }

    // Input handlers
    handleUpiIdChange(e) { this.demoUpiId = e.target.value; }
    handleFillDemoUpi() { this.demoUpiId = 'demo.patient@upi'; }

    handleCardHolderChange(e) { this.demoCardHolder = e.target.value; }
    handleCardNumberChange(e) { this.demoCardNumber = e.target.value; }
    handleCardExpiryChange(e) { this.demoCardExpiry = e.target.value; }
    handleCardCvvChange(e) { this.demoCardCvv = e.target.value; }

    handleFillDemoCard() {
        this.demoCardHolder = this.patientName || 'Test Cardholder';
        this.demoCardNumber = '4111 2222 3333 1111';
        this.demoCardExpiry = '12/28';
        this.demoCardCvv = '123';
    }

    handleCashAcknowledgeChange(e) {
        this.isCashAcknowledged = e.target.checked;
    }

    get demoCardNumberDisplay() {
        if (!this.demoCardNumber) return '•••• •••• •••• ••••';
        const clean = this.demoCardNumber.replace(/\s+/g, '');
        if (clean.length >= 4) {
            const last4 = clean.slice(-4);
            return `•••• •••• •••• ${last4}`;
        }
        return this.demoCardNumber;
    }

    get isSimulateDisabled() {
        if (this.selectedMethod === 'UPI') {
            return !this.demoUpiId || !this.demoUpiId.trim();
        }
        if (this.selectedMethod === 'Card') {
            return !this.demoCardNumber || !this.demoCardExpiry || !this.demoCardCvv;
        }
        if (this.selectedMethod === 'Cash') {
            return !this.isCashAcknowledged;
        }
        return false;
    }

    get simulateButtonLabel() {
        if (this.selectedMethod === 'UPI') return 'Simulate UPI Payment';
        if (this.selectedMethod === 'Card') return 'Simulate Card Payment';
        if (this.selectedMethod === 'Cash') return 'Simulate Cash Counter Acknowledgment';
        return 'Simulate Payment';
    }

    // Simulation execution
    handleExecuteSimulation() {
        this.isLoading = true;

        // Generate demo reference
        const rand = Math.floor(10000 + Math.random() * 90000);
        const prefix = this.selectedMethod ? this.selectedMethod.toUpperCase() : 'DEMO';
        const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
        this.demoTxnId = `DEMO-TXN-${prefix}-${dateStr}-${rand}`;

        const now = new Date();
        this.demoTimestamp = new Intl.DateTimeFormat('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: 'numeric',
            minute: '2-digit',
            second: '2-digit',
            hour12: true
        }).format(now);

        // Simulated quick execution delay (400ms for realistic UI feel)
        setTimeout(() => {
            this.isLoading = false;
            this.currentStep = '4';

            // Dispatch event notifying parent if needed
            this.dispatchEvent(new CustomEvent('paymentsimulated', {
                detail: {
                    demoTxnId: this.demoTxnId,
                    method: this.selectedMethod,
                    amount: this.payableAmount,
                    appointmentCode: this.appointmentCode
                }
            }));
        }, 400);
    }

    handleRestartDemo() {
        this.currentStep = '1';
        this.demoTxnId = '';
    }

    handlePrintReceipt() {
        window.print();
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}
