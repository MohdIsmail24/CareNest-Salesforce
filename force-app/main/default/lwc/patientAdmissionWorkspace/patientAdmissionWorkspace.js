import { LightningElement, track, wire, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveAdmissions from '@salesforce/apex/CareNestAdmissionController.getActiveAdmissions';
import searchPatients from '@salesforce/apex/CareNestAdmissionController.searchPatients';
import getPatientDirectory from '@salesforce/apex/CareNestAdmissionController.getPatientDirectory';
import registerPatient from '@salesforce/apex/CareNestAdmissionController.registerPatient';
import getWardsWithAvailability from '@salesforce/apex/CareNestAdmissionController.getWardsWithAvailability';
import getAvailableBedDetails from '@salesforce/apex/CareNestAdmissionController.getAvailableBedDetails';
import getDoctorsWithAvailability from '@salesforce/apex/CareNestAdmissionController.getDoctorsWithAvailability';
import admitPatient from '@salesforce/apex/CareNestAdmissionController.admitPatient';
import dischargePatient from '@salesforce/apex/CareNestAdmissionController.dischargePatient';

export default class PatientAdmissionWorkspace extends LightningElement {
    @api mode = 'all'; // 'all' | 'registry' | 'admissions'
    @track activeWorkspaceSubTab = 'registry'; // for dual mode
    @track isLoading = true;
    @track admissions = [];
    @track searchTerm = '';

    // Patient Directory State
    @track patientDirectory = [];
    @track directorySearchKey = '';
    @track isDirectoryLoading = false;
    wiredDirectoryResult;

    // Modals state
    @track isRegisterPatientModalOpen = false;
    @track isNewAdmissionModalOpen = false;
    @track isDischargeModalOpen = false;

    // Dedicated Registration State
    @track isSubmittingRegistration = false;
    @track duplicateWarning = false;
    @track duplicateWarningMessage = '';
    @track duplicateInfo = null;
    @track registrationSuccessData = null;
    @track newPatientForm = {
        firstName: '',
        lastName: '',
        phone: '',
        email: '',
        birthdate: ''
    };

    // 6-Step Inpatient Admission Wizard State
    @track wizardStep = '1';
    @track isSubmittingAdmission = false;
    @track admissionSuccessResult = null;

    // Step 1: Patient
    @track patientSearchQuery = '';
    @track patientSearchResults = [];
    @track selectedPatient = null;

    // Step 2: Ward
    @track wardsList = [];
    @track selectedWard = null;

    // Step 3: Bed
    @track availableBedCards = [];
    @track selectedBed = null;

    // Step 4: Doctor
    @track doctorDeptFilter = 'All';
    @track doctorSearchKey = '';
    @track allDoctors = [];
    @track filteredDoctors = [];
    @track selectedDoctor = null;

    // Step 5: Clinical Details
    @track wizardData = {
        admissionType: '',
        admissionDateDisplay: '',
        reason: ''
    };

    // Discharge Form state
    @track selectedAdmissionForDischarge = null;
    @track dischargeDisposition = 'Routine Discharge Home';
    @track dischargeSummary = '';
    @track isSubmittingDischarge = false;

    wiredAdmissionsResult;

    admissionTypeOptions = [
        { label: '-- Select Admission Type --', value: '' },
        { label: 'Emergency', value: 'Emergency' },
        { label: 'Planned', value: 'Planned' },
        { label: 'Transfer', value: 'Transfer' }
    ];

    dispositionOptions = [
        { label: 'Routine Discharge Home', value: 'Routine Discharge Home' },
        { label: 'Transferred to Specialized Facility', value: 'Transferred to Specialized Facility' },
        { label: 'Home Health Care', value: 'Home Health Care' },
        { label: 'Left Against Medical Advice (AMA)', value: 'Left Against Medical Advice' }
    ];

    departmentOptions = [
        { label: 'All Medical Departments', value: 'All' },
        { label: 'Cardiology', value: 'Cardiology' },
        { label: 'Internal Medicine', value: 'Internal Medicine' },
        { label: 'Neurology', value: 'Neurology' },
        { label: 'Orthopedics', value: 'Orthopedics' },
        { label: 'Pediatrics', value: 'Pediatrics' },
        { label: 'General Surgery', value: 'General Surgery' }
    ];

    @wire(getActiveAdmissions, { searchTerm: '$searchTerm' })
    wiredAdmissions(result) {
        this.wiredAdmissionsResult = result;
        if (result.data) {
            this.admissions = result.data;
            this.isLoading = false;
        } else if (result.error) {
            this.showError('Error loading admissions', result.error);
            this.isLoading = false;
        }
    }

    @wire(getPatientDirectory, { searchTerm: '$directorySearchKey' })
    wiredDirectory(result) {
        this.wiredDirectoryResult = result;
        if (result.data) {
            this.patientDirectory = result.data.map(p => ({
                ...p,
                formattedBirthdate: p.birthdate ? p.birthdate : 'Not recorded',
                statusClass: p.isAdmitted ? 'slds-badge slds-theme_success' : 'slds-badge slds-badge_lightest'
            }));
            this.isDirectoryLoading = false;
        } else if (result.error) {
            this.showError('Error loading patient directory', result.error);
            this.isDirectoryLoading = false;
        }
    }

    get isRegistryMode() {
        return this.mode === 'registry' || (this.mode === 'all' && this.activeWorkspaceSubTab === 'registry');
    }

    get isAdmissionsMode() {
        return this.mode === 'admissions' || (this.mode === 'all' && this.activeWorkspaceSubTab === 'admissions');
    }

    get isDualMode() {
        return this.mode === 'all';
    }

    get registryTabClass() {
        return this.activeWorkspaceSubTab === 'registry'
            ? 'slds-button slds-button_brand slds-m-right_x-small'
            : 'slds-button slds-button_neutral slds-m-right_x-small';
    }

    get admissionsTabClass() {
        return this.activeWorkspaceSubTab === 'admissions'
            ? 'slds-button slds-button_brand slds-m-right_x-small'
            : 'slds-button slds-button_neutral slds-m-right_x-small';
    }

    get hasPatientsInDirectory() {
        return this.patientDirectory && this.patientDirectory.length > 0;
    }

    get totalPatientsCount() {
        return this.patientDirectory ? this.patientDirectory.length : 0;
    }

    get hasAdmissions() {
        return this.admissions && this.admissions.length > 0;
    }

    get activeAdmissionCount() {
        return this.admissions ? this.admissions.length : 0;
    }

    get hasPatientSearchResults() {
        return this.patientSearchResults && this.patientSearchResults.length > 0;
    }

    get hasAvailableBeds() {
        return this.availableBedCards && this.availableBedCards.length > 0;
    }

    get selectedWardName() {
        return this.selectedWard ? this.selectedWard.name : '';
    }

    get isStep1() { return this.wizardStep === '1' && !this.admissionSuccessResult; }
    get isStep2() { return this.wizardStep === '2' && !this.admissionSuccessResult; }
    get isStep3() { return this.wizardStep === '3' && !this.admissionSuccessResult; }
    get isStep4() { return this.wizardStep === '4' && !this.admissionSuccessResult; }
    get isStep5() { return this.wizardStep === '5' && !this.admissionSuccessResult; }
    get isStep6() { return this.wizardStep === '6' && !this.admissionSuccessResult; }

    get canGoBack() {
        return parseInt(this.wizardStep, 10) > 1 && !this.admissionSuccessResult;
    }

    get canGoNext() {
        return parseInt(this.wizardStep, 10) < 6 && !this.admissionSuccessResult;
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handleDirectorySearchChange(event) {
        this.directorySearchKey = event.target.value;
    }

    handleClearDirectorySearch() {
        this.directorySearchKey = '';
    }

    handleSwitchSubTab(event) {
        this.activeWorkspaceSubTab = event.currentTarget.dataset.tab;
    }

    handleAdmitPatientFromDirectory(event) {
        const pId = event.currentTarget.dataset.patientId;
        const pName = event.currentTarget.dataset.patientName;
        const pCode = event.currentTarget.dataset.patientCode;
        const pPhone = event.currentTarget.dataset.patientPhone;
        const pEmail = event.currentTarget.dataset.patientEmail;

        this.selectedPatient = {
            id: pId,
            name: pName,
            patientCode: pCode,
            phone: pPhone,
            email: pEmail
        };
        this.openAdmissionWizardAtStep('2');
    }

    handleBookOpdFromDirectory(event) {
        const pId = event.currentTarget.dataset.patientId;
        const pName = event.currentTarget.dataset.patientName;
        this.dispatchEvent(new CustomEvent('navigateworkspace', {
            bubbles: true,
            composed: true,
            detail: {
                tab: 'appointments',
                patientId: pId,
                patientName: pName
            }
        }));
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            await Promise.all([
                refreshApex(this.wiredAdmissionsResult),
                refreshApex(this.wiredDirectoryResult)
            ]);
            this.showToast('Refreshed', 'Workspace updated', 'success');
        } catch (error) {
            this.showError('Error refreshing workspace', error);
        } finally {
            this.isLoading = false;
        }
    }

    // =========================================================================
    // 1. DEDICATED NEW PATIENT REGISTRATION
    // =========================================================================

    @api
    handleOpenRegisterPatientModal() {
        this.resetPatientRegistrationForm();
        this.isRegisterPatientModalOpen = true;
    }

    handleCloseRegisterPatientModal() {
        this.isRegisterPatientModalOpen = false;
        this.resetPatientRegistrationForm();
    }

    resetPatientRegistrationForm() {
        this.newPatientForm = {
            firstName: '',
            lastName: '',
            phone: '',
            email: '',
            birthdate: ''
        };
        this.duplicateWarning = false;
        this.duplicateWarningMessage = '';
        this.duplicateInfo = null;
        this.registrationSuccessData = null;
        this.isSubmittingRegistration = false;
    }

    handleNewPatientInputChange(event) {
        const field = event.target.name;
        this.newPatientForm = { ...this.newPatientForm, [field]: event.target.value };
    }

    async handleSubmitRegisterPatient() {
        if (!this.newPatientForm.lastName || !this.newPatientForm.lastName.trim()) {
            this.showToast('Validation Error', 'Last Name is required to register a patient', 'warning');
            return;
        }

        this.isSubmittingRegistration = true;
        try {
            const res = await registerPatient({
                firstName: this.newPatientForm.firstName ? this.newPatientForm.firstName.trim() : '',
                lastName: this.newPatientForm.lastName.trim(),
                phone: this.newPatientForm.phone ? this.newPatientForm.phone.trim() : '',
                email: this.newPatientForm.email ? this.newPatientForm.email.trim() : '',
                birthdate: this.newPatientForm.birthdate || null,
                allowDuplicate: false
            });

            if (res.isDuplicate) {
                this.duplicateWarning = true;
                this.duplicateWarningMessage = res.message;
                this.duplicateInfo = {
                    contactId: res.contactId,
                    name: res.existingPatientName,
                    code: res.existingPatientCode,
                    phone: this.newPatientForm.phone,
                    email: this.newPatientForm.email
                };
            } else if (res.isSuccess) {
                const fullName = (this.newPatientForm.firstName ? this.newPatientForm.firstName.trim() + ' ' : '') + this.newPatientForm.lastName.trim();
                this.registrationSuccessData = {
                    contactId: res.contactId,
                    patientCode: res.patientCode,
                    patientName: fullName,
                    phone: this.newPatientForm.phone,
                    email: this.newPatientForm.email
                };
                this.duplicateWarning = false;
                this.showToast('Patient Registered', `Patient Code: ${res.patientCode}`, 'success');
            } else {
                this.showToast('Registration Error', res.message, 'error');
            }
        } catch (error) {
            this.showError('Failed to register patient', error);
        } finally {
            this.isSubmittingRegistration = false;
        }
    }

    handlePatientCreatedFromModal(event) {
        const detail = event.detail;
        if (detail && detail.patientId) {
            this.selectedPatient = {
                id: detail.patientId,
                name: detail.patientName,
                patientCode: detail.patientCode,
                phone: detail.phone,
                email: detail.email
            };
            this.handleCloseRegisterPatientModal();
            this.openAdmissionWizardAtStep('2');
            if (this.wiredDirectoryResult) {
                refreshApex(this.wiredDirectoryResult);
            }
        }
    }

    handleUseExistingPatient() {
        if (this.duplicateInfo) {
            this.selectedPatient = {
                id: this.duplicateInfo.contactId,
                name: this.duplicateInfo.name,
                patientCode: this.duplicateInfo.code,
                phone: this.duplicateInfo.phone,
                email: this.duplicateInfo.email
            };
            this.handleCloseRegisterPatientModal();
            this.openAdmissionWizardAtStep('2');
        }
    }

    async handleForceRegisterNewPatient() {
        this.isSubmittingRegistration = true;
        try {
            const res = await registerPatient({
                firstName: this.newPatientForm.firstName ? this.newPatientForm.firstName.trim() : '',
                lastName: this.newPatientForm.lastName.trim(),
                phone: this.newPatientForm.phone ? this.newPatientForm.phone.trim() : '',
                email: this.newPatientForm.email ? this.newPatientForm.email.trim() : '',
                birthdate: this.newPatientForm.birthdate || null,
                allowDuplicate: true
            });

            if (res.isSuccess) {
                const fullName = (this.newPatientForm.firstName ? this.newPatientForm.firstName.trim() + ' ' : '') + this.newPatientForm.lastName.trim();
                this.registrationSuccessData = {
                    contactId: res.contactId,
                    patientCode: res.patientCode,
                    patientName: fullName,
                    phone: this.newPatientForm.phone,
                    email: this.newPatientForm.email
                };
                this.duplicateWarning = false;
                this.showToast('Patient Registered', `Patient Code: ${res.patientCode}`, 'success');
            } else {
                this.showToast('Registration Error', res.message, 'error');
            }
        } catch (error) {
            this.showError('Failed to register patient', error);
        } finally {
            this.isSubmittingRegistration = false;
        }
    }

    handleAdmitNewlyRegisteredPatient() {
        if (this.registrationSuccessData) {
            this.selectedPatient = {
                id: this.registrationSuccessData.contactId,
                name: this.registrationSuccessData.patientName,
                patientCode: this.registrationSuccessData.patientCode,
                phone: this.registrationSuccessData.phone,
                email: this.registrationSuccessData.email
            };
            this.handleCloseRegisterPatientModal();
            this.openAdmissionWizardAtStep('2');
        }
    }

    // =========================================================================
    // 2. GUIDED 6-STEP INPATIENT ADMISSION WIZARD
    // =========================================================================

    @api
    handleOpenNewAdmissionWizard() {
        this.resetAdmissionWizard();
        this.isNewAdmissionModalOpen = true;
    }

    openAdmissionWizardAtStep(step) {
        this.wizardStep = step;
        this.isNewAdmissionModalOpen = true;
        if (step === '2') {
            this.loadWards();
        }
    }

    handleCloseNewAdmissionModal() {
        this.isNewAdmissionModalOpen = false;
        this.resetAdmissionWizard();
    }

    resetAdmissionWizard() {
        this.wizardStep = '1';
        this.selectedPatient = null;
        this.patientSearchQuery = '';
        this.patientSearchResults = [];
        this.wardsList = [];
        this.selectedWard = null;
        this.availableBedCards = [];
        this.selectedBed = null;
        this.allDoctors = [];
        this.filteredDoctors = [];
        this.selectedDoctor = null;
        this.doctorDeptFilter = 'All';
        this.doctorSearchKey = '';
        this.wizardData = {
            admissionType: '',
            admissionDateDisplay: new Date().toISOString(),
            reason: ''
        };
        this.admissionSuccessResult = null;
        this.isSubmittingAdmission = false;
    }

    handleOpenRegisterPatientFromWizard() {
        this.resetPatientRegistrationForm();
        this.isRegisterPatientModalOpen = true;
    }

    // --- STEP 1: PATIENT SELECTION ---

    async handlePatientSearchInput(event) {
        this.patientSearchQuery = event.target.value;
        if (this.patientSearchQuery && this.patientSearchQuery.length >= 2) {
            try {
                this.patientSearchResults = await searchPatients({ searchTerm: this.patientSearchQuery });
            } catch (error) {
                this.showError('Error searching patients', error);
            }
        } else {
            this.patientSearchResults = [];
        }
    }

    handleSelectPatientDirect(event) {
        const pId = event.currentTarget.dataset.patientId;
        const pName = event.currentTarget.dataset.patientName;
        const pCode = event.currentTarget.dataset.patientCode;
        const pPhone = event.currentTarget.dataset.patientPhone;
        const pEmail = event.currentTarget.dataset.patientEmail;

        this.selectedPatient = {
            id: pId,
            name: pName,
            patientCode: pCode,
            phone: pPhone,
            email: pEmail
        };
        this.patientSearchResults = [];
        this.patientSearchQuery = '';
    }

    handleClearSelectedPatient() {
        this.selectedPatient = null;
    }

    // --- STEP 2: WARD SELECTION ---

    async loadWards() {
        try {
            const wards = await getWardsWithAvailability();
            this.wardsList = wards.map(w => ({
                ...w,
                cardClass: this.selectedWard && this.selectedWard.wardId === w.wardId 
                    ? 'slds-box slds-p-around_small ward-card ward-card-selected' 
                    : 'slds-box slds-p-around_small ward-card'
            }));
        } catch (error) {
            this.showError('Error loading hospital wards', error);
        }
    }

    handleSelectWardCard(event) {
        const wardId = event.currentTarget.dataset.wardId;
        const found = this.wardsList.find(w => w.wardId === wardId);
        if (found) {
            this.selectedWard = found;
            // Deselect previously selected bed if ward changed
            this.selectedBed = null;
            this.wardsList = this.wardsList.map(w => ({
                ...w,
                cardClass: w.wardId === wardId 
                    ? 'slds-box slds-p-around_small ward-card ward-card-selected' 
                    : 'slds-box slds-p-around_small ward-card'
            }));
        }
    }

    // --- STEP 3: BED SELECTION ---

    async loadBedsForSelectedWard() {
        if (!this.selectedWard) return;
        try {
            const beds = await getAvailableBedDetails({ wardId: this.selectedWard.wardId });
            this.availableBedCards = beds.map(b => ({
                ...b,
                cardClass: this.selectedBed && this.selectedBed.bedId === b.bedId 
                    ? 'slds-box slds-p-around_small bed-card bed-card-selected' 
                    : 'slds-box slds-p-around_small bed-card'
            }));
        } catch (error) {
            this.showError('Error loading available beds', error);
        }
    }

    handleSelectBedCard(event) {
        const bedId = event.currentTarget.dataset.bedId;
        const found = this.availableBedCards.find(b => b.bedId === bedId);
        if (found) {
            this.selectedBed = found;
            this.availableBedCards = this.availableBedCards.map(b => ({
                ...b,
                cardClass: b.bedId === bedId 
                    ? 'slds-box slds-p-around_small bed-card bed-card-selected' 
                    : 'slds-box slds-p-around_small bed-card'
            }));
        }
    }

    // --- STEP 4: DOCTOR SELECTION ---

    async loadDoctors() {
        try {
            const doctors = await getDoctorsWithAvailability({ department: '', searchKey: '' });
            this.allDoctors = doctors.map(d => ({
                ...d,
                cardClass: this.selectedDoctor && this.selectedDoctor.doctorId === d.doctorId 
                    ? 'slds-box slds-p-around_small doctor-card doctor-card-selected' 
                    : 'slds-box slds-p-around_small doctor-card',
                badgeClass: d.availabilityStatus && d.availabilityStatus.includes('Verified OPD') 
                    ? 'slds-badge slds-theme_success' 
                    : 'slds-badge slds-badge_lightest'
            }));
            this.filterDoctors();
        } catch (error) {
            this.showError('Error loading attending physicians', error);
        }
    }

    handleDoctorDeptFilterChange(event) {
        this.doctorDeptFilter = event.detail.value;
        this.filterDoctors();
    }

    handleDoctorSearchKeyChange(event) {
        this.doctorSearchKey = event.target.value;
        this.filterDoctors();
    }

    filterDoctors() {
        let list = [...this.allDoctors];
        if (this.doctorDeptFilter && this.doctorDeptFilter !== 'All') {
            list = list.filter(d => d.department === this.doctorDeptFilter);
        }
        if (this.doctorSearchKey && this.doctorSearchKey.trim()) {
            const q = this.doctorSearchKey.toLowerCase().trim();
            list = list.filter(d => (d.name && d.name.toLowerCase().includes(q)) || (d.specialty && d.specialty.toLowerCase().includes(q)));
        }
        this.filteredDoctors = list;
    }

    handleSelectDoctorCard(event) {
        const docId = event.currentTarget.dataset.doctorId;
        const found = this.allDoctors.find(d => d.doctorId === docId);
        if (found) {
            this.selectedDoctor = found;
            this.allDoctors = this.allDoctors.map(d => ({
                ...d,
                cardClass: d.doctorId === docId 
                    ? 'slds-box slds-p-around_small doctor-card doctor-card-selected' 
                    : 'slds-box slds-p-around_small doctor-card'
            }));
            this.filterDoctors();
        }
    }

    // --- STEP 5: ADMISSION DETAILS ---

    handleAdmissionTypeChange(event) {
        this.wizardData = { ...this.wizardData, admissionType: event.detail.value };
    }

    handleAdmissionReasonChange(event) {
        this.wizardData = { ...this.wizardData, reason: event.target.value };
    }

    // --- WIZARD NAVIGATION ---

    handleWizardBack() {
        const cur = parseInt(this.wizardStep, 10);
        if (cur > 1) {
            this.wizardStep = String(cur - 1);
        }
    }

    async handleWizardNext() {
        const cur = parseInt(this.wizardStep, 10);

        if (cur === 1) {
            if (!this.selectedPatient) {
                this.showToast('Validation Error', 'Please select or register a patient before continuing', 'warning');
                return;
            }
            await this.loadWards();
            this.wizardStep = '2';
        } else if (cur === 2) {
            if (!this.selectedWard) {
                this.showToast('Validation Error', 'Please select a hospital ward to continue', 'warning');
                return;
            }
            await this.loadBedsForSelectedWard();
            this.wizardStep = '3';
        } else if (cur === 3) {
            if (!this.selectedBed) {
                this.showToast('Validation Error', 'Please select an available hospital bed to assign', 'warning');
                return;
            }
            await this.loadDoctors();
            this.wizardStep = '4';
        } else if (cur === 4) {
            if (!this.selectedDoctor) {
                this.showToast('Validation Error', 'Please select an attending physician for the patient', 'warning');
                return;
            }
            this.wizardData = {
                ...this.wizardData,
                admissionDateDisplay: new Date().toISOString()
            };
            this.wizardStep = '5';
        } else if (cur === 5) {
            if (!this.wizardData.admissionType || !this.wizardData.admissionType.trim()) {
                this.showToast('Validation Error', 'Please select an Admission Type before proceeding (Emergency, Planned, or Transfer)', 'warning');
                return;
            }
            if (!this.wizardData.reason || !this.wizardData.reason.trim()) {
                this.showToast('Validation Error', 'Please enter the admission reason or clinical diagnosis', 'warning');
                return;
            }
            this.wizardStep = '6';
        }
    }

    // --- STEP 6: CONFIRM & ADMIT PATIENT ---

    async handleConfirmAdmission() {
        if (!this.selectedPatient || !this.selectedBed || !this.selectedDoctor) {
            this.showToast('Validation Error', 'Missing required admission parameters', 'warning');
            return;
        }

        this.isSubmittingAdmission = true;
        try {
            const res = await admitPatient({
                patientId: this.selectedPatient.id,
                bedId: this.selectedBed.bedId,
                doctorId: this.selectedDoctor.doctorId,
                admissionType: this.wizardData.admissionType,
                reason: this.wizardData.reason.trim()
            });

            if (res.isSuccess) {
                this.admissionSuccessResult = res;
                this.showToast('Patient Admitted', `Admission #${res.admissionNumber} created successfully`, 'success');
                if (this.wiredAdmissionsResult) {
                    await refreshApex(this.wiredAdmissionsResult);
                }
                if (this.wiredDirectoryResult) {
                    await refreshApex(this.wiredDirectoryResult);
                }
            } else {
                this.showToast('Admission Failed', res.message, 'error');
            }
        } catch (error) {
            this.showError('Failed to confirm patient admission', error);
        } finally {
            this.isSubmittingAdmission = false;
        }
    }

    handleNavigateToClinicalWorkspace() {
        const admissionId = this.admissionSuccessResult ? this.admissionSuccessResult.admissionId : null;
        const patientId = this.selectedPatient ? this.selectedPatient.id : null;
        
        this.dispatchEvent(new CustomEvent('navigateworkspace', {
            bubbles: true,
            composed: true,
            detail: {
                tab: 'clinical',
                admissionId: admissionId,
                patientId: patientId
            }
        }));
        this.handleCloseNewAdmissionModal();
    }

    // =========================================================================
    // 3. DISCHARGE WORKFLOW
    // =========================================================================

    handleOpenDischargeModal(event) {
        const admissionId = event.currentTarget.dataset.admissionId;
        const found = this.admissions.find(a => a.admissionId === admissionId);
        if (found) {
            this.selectedAdmissionForDischarge = found;
            this.dischargeDisposition = 'Routine Discharge Home';
            this.dischargeSummary = 'Patient clinically stable for discharge. Routine follow-up scheduled.';
            this.isDischargeModalOpen = true;
        }
    }

    handleCloseDischargeModal() {
        this.isDischargeModalOpen = false;
        this.selectedAdmissionForDischarge = null;
    }

    handleDispositionChange(event) {
        this.dischargeDisposition = event.detail.value;
    }

    handleDischargeSummaryChange(event) {
        this.dischargeSummary = event.target.value;
    }

    async handleSubmitDischarge() {
        if (!this.dischargeSummary || !this.dischargeSummary.trim()) {
            this.showToast('Validation Error', 'Please provide a clinical discharge summary', 'warning');
            return;
        }

        this.isSubmittingDischarge = true;
        try {
            const res = await dischargePatient({
                admissionId: this.selectedAdmissionForDischarge.admissionId,
                summary: this.dischargeSummary.trim(),
                disposition: this.dischargeDisposition
            });

            if (res.isSuccess) {
                this.showToast('Discharge Complete', res.message, 'success');
                this.isDischargeModalOpen = false;
                await refreshApex(this.wiredAdmissionsResult);
            } else {
                this.showToast('Discharge Failed', res.message, 'error');
            }
        } catch (error) {
            this.showError('Failed to process discharge', error);
        } finally {
            this.isSubmittingDischarge = false;
        }
    }

    // =========================================================================
    // UTILITY TOAST NOTIFICATIONS
    // =========================================================================

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    showError(title, error) {
        let msg = 'Unknown error';
        if (error && error.body && error.body.message) {
            msg = error.body.message;
        } else if (error && error.message) {
            msg = error.message;
        }
        this.showToast(title, msg, 'error');
    }
}
