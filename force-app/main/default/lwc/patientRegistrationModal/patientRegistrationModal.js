import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import registerPatient from '@salesforce/apex/CareNestAdmissionController.registerPatient';

export default class PatientRegistrationModal extends LightningElement {
    @api isOpen = false;

    @track isLoading = false;
    @track isDuplicateWarning = false;
    @track duplicateMessage = '';
    @track duplicateInfo = { name: '', code: '', contactId: '' };

    @track form = {
        firstName: '',
        lastName: '',
        phone: '',
        email: '',
        birthdate: ''
    };

    @api
    open() {
        this.resetForm();
        this.isOpen = true;
    }

    @api
    close() {
        this.isOpen = false;
        this.resetForm();
        this.dispatchEvent(new CustomEvent('close'));
    }

    resetForm() {
        this.form = {
            firstName: '',
            lastName: '',
            phone: '',
            email: '',
            birthdate: ''
        };
        this.isDuplicateWarning = false;
        this.duplicateMessage = '';
        this.duplicateInfo = { name: '', code: '', contactId: '' };
        this.isLoading = false;
    }

    handleClose() {
        this.close();
    }

    handleInputChange(event) {
        const field = event.target.name;
        this.form = { ...this.form, [field]: event.target.value };
    }

    get isSubmitDisabled() {
        return this.isLoading || !this.form.lastName || !this.form.lastName.trim();
    }

    async handleSubmit() {
        if (!this.form.lastName || !this.form.lastName.trim()) {
            this.showToast('Validation Error', 'Last Name is required to register a patient.', 'warning');
            return;
        }

        await this.executeRegistration(false);
    }

    async handleForceRegister() {
        await this.executeRegistration(true);
    }

    async executeRegistration(allowDuplicate) {
        this.isLoading = true;
        try {
            const res = await registerPatient({
                firstName: this.form.firstName ? this.form.firstName.trim() : '',
                lastName: this.form.lastName.trim(),
                phone: this.form.phone ? this.form.phone.trim() : '',
                email: this.form.email ? this.form.email.trim() : '',
                birthdate: this.form.birthdate || null,
                allowDuplicate: allowDuplicate
            });

            if (res.isDuplicate && !allowDuplicate) {
                this.isDuplicateWarning = true;
                this.duplicateMessage = res.message;
                this.duplicateInfo = {
                    name: res.duplicateContactName,
                    code: res.duplicatePatientCode,
                    contactId: res.duplicateContactId
                };
            } else if (res.isSuccess) {
                const fullName = (this.form.firstName ? this.form.firstName.trim() + ' ' : '') + this.form.lastName.trim();
                const detail = {
                    patientId: res.contactId,
                    patientName: res.patientName || fullName,
                    patientCode: res.patientCode,
                    phone: this.form.phone,
                    email: this.form.email
                };

                this.showToast('Patient Registered', `Successfully created patient: ${detail.patientName} (${res.patientCode})`, 'success');

                // Notify parent components with the registered patient data
                this.dispatchEvent(new CustomEvent('patientcreated', { detail }));
                this.close();
            } else {
                this.showToast('Registration Error', res.message || 'Unable to register patient.', 'error');
            }
        } catch (error) {
            const msg = error.body ? error.body.message : (error.message || 'Error executing registration.');
            this.showToast('Registration Failed', msg, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleSelectExistingPatient() {
        if (this.duplicateInfo && this.duplicateInfo.contactId) {
            const detail = {
                patientId: this.duplicateInfo.contactId,
                patientName: this.duplicateInfo.name,
                patientCode: this.duplicateInfo.code,
                phone: this.form.phone,
                email: this.form.email
            };

            this.showToast('Patient Selected', `Using existing patient profile: ${this.duplicateInfo.name}`, 'info');
            this.dispatchEvent(new CustomEvent('patientcreated', { detail }));
            this.close();
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
