import { LightningElement, track } from 'lwc';

export default class CareNestMasterWorkspace extends LightningElement {
    @track activeTab = 'dashboard';
    @track activePersona = 'all';

    personaOptions = [
        { label: 'Role View: All Hospital Modules', value: 'all' },
        { label: 'Role View: Hospital Administrator / Operations', value: 'admin' },
        { label: 'Role View: Ward Nurse / Bed Manager', value: 'nurse' },
        { label: 'Role View: Attending Physician / Clinician', value: 'physician' },
        { label: 'Role View: Patient Intake / Admissions Registrar', value: 'registrar' },
        { label: 'Role View: Billing & Accounts Officer', value: 'billing' }
    ];

    handlePersonaChange(event) {
        this.activePersona = event.detail.value;
        switch (this.activePersona) {
            case 'admin':
                this.activeTab = 'dashboard';
                break;
            case 'nurse':
                this.activeTab = 'wards';
                break;
            case 'physician':
                this.activeTab = 'clinical';
                break;
            case 'registrar':
                this.activeTab = 'admissions';
                break;
            case 'billing':
                this.activeTab = 'billing';
                break;
            default:
                this.activeTab = 'dashboard';
                break;
        }
    }

    handleQuickRegisterPatient() {
        this.activeTab = 'admissions';
        // Allow tab render cycle then open register modal on the child admissions workspace
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const admComp = this.template.querySelector('c-patient-admission-workspace');
            if (admComp && admComp.handleOpenRegisterPatientModal) {
                admComp.handleOpenRegisterPatientModal();
            }
        }, 150);
    }

    handleNavigateWorkspace(event) {
        if (event.detail && event.detail.tab) {
            this.activeTab = event.detail.tab;
        }
    }
}
