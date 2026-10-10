import { LightningElement, track, wire } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import DOCTOR_SELECTED_CHANNEL from '@salesforce/messageChannel/Doctor_Selected__c';
import getDoctors from '@salesforce/apex/DoctorSearchController.getDoctors';

export default class DoctorSearch extends LightningElement {
    @track searchKey = '';
    @track selectedDepartment = 'All';
    @track rawDoctors = [];
    @track selectedDoctorId = '';
    @track isLoading = true;
    @track error = null;

    searchTimeout;

    @wire(MessageContext)
    messageContext;

    departmentOptions = [
        { label: 'All Departments', value: 'All' },
        { label: 'General Medicine', value: 'General Medicine' },
        { label: 'Paediatrics', value: 'Paediatrics' },
        { label: 'Orthopaedics', value: 'Orthopaedics' },
        { label: 'Dermatology', value: 'Dermatology' },
        { label: 'ENT', value: 'ENT' }
    ];

    @wire(getDoctors, { department: '$selectedDepartment', searchKey: '$searchKey' })
    wiredDoctors({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.rawDoctors = data;
            this.error = null;
        } else if (error) {
            this.rawDoctors = [];
            this.error = error.body ? error.body.message : 'Error fetching doctors';
        }
    }

    get doctors() {
        return this.rawDoctors.map(doc => {
            const isSelected = doc.Id === this.selectedDoctorId;
            return {
                ...doc,
                cardClass: isSelected
                    ? 'slds-card doctor-card doctor-card_selected'
                    : 'slds-card doctor-card',
                buttonLabel: isSelected ? 'Doctor Selected' : 'Select Doctor',
                buttonVariant: isSelected ? 'brand' : 'neutral',
                buttonIcon: isSelected ? 'utility:check' : 'utility:add'
            };
        });
    }

    get hasDoctors() {
        return !this.isLoading && this.doctors.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && this.doctors.length === 0 && !this.error;
    }

    handleSearchChange(event) {
        clearTimeout(this.searchTimeout);
        const value = event.target.value;
        this.searchTimeout = setTimeout(() => {
            this.searchKey = value;
            this.isLoading = true;
        }, 300);
    }

    handleDepartmentChange(event) {
        this.selectedDepartment = event.detail.value;
        this.isLoading = true;
    }

    handleSelectDoctor(event) {
        const doctorId = event.currentTarget.dataset.id;
        const doctorName = event.currentTarget.dataset.name;
        this.selectedDoctorId = doctorId;

        // Publish to Lightning Message Service
        const payload = {
            doctorId: doctorId,
            doctorName: doctorName
        };
        publish(this.messageContext, DOCTOR_SELECTED_CHANNEL, payload);

        // Also dispatch component event
        this.dispatchEvent(new CustomEvent('doctorselected', {
            detail: payload,
            bubbles: true,
            composed: true
        }));
    }
}
