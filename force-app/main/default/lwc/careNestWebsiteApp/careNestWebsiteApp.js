import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

// Apex Controllers
import getDashboardMetrics from '@salesforce/apex/CareNestDashboardController.getDashboardMetrics';
import searchPatients from '@salesforce/apex/CareNestAdmissionController.searchPatients';
import registerPatient from '@salesforce/apex/CareNestAdmissionController.registerPatient';
import getDoctorsWithAvailability from '@salesforce/apex/CareNestAdmissionController.getDoctorsWithAvailability';
import getUserContext from '@salesforce/apex/DoctorSearchController.getUserContext';

// Static Resources
import CARENEST_HERO_IMG from '@salesforce/resourceUrl/careNestHeroMedicalSuite';

export default class CareNestWebsiteApp extends NavigationMixin(LightningElement) {
    // Valid and Protected Route Constants
    VALID_SECTIONS = ['home', 'patients', 'doctors', 'appointments', 'wards', 'admissions', 'clinical', 'payments', 'agentforce', 'admin', 'specialties', 'facilities', 'visiting', 'contact', 'emergency'];
    PROTECTED_SECTIONS = ['clinical', 'payments', 'admin'];

    // Experience Mode: 'public' (Patient & Visitor Portal) vs 'staff' (Authenticated Hospital Workspace)
    @track currentExperience = 'public';
    @track publicSection = 'home'; // 'home', 'specialties', 'facilities', 'visiting', 'contact', 'emergency'

    // Navigation State
    @track activePage = 'home';
    @track isMobileMenuOpen = false;
    @track isAccessDenied = false;
    @track accessDeniedMessage = '';

    // User Context & Route Protection State
    @track userContext = { isPatient: false };
    @track isPatientPortalUser = false;

    // Operational Metrics (Wired dynamically from Real Salesforce Backend)
    @track metrics = {
        totalDoctors: 12,
        todayAppointments: 0,
        upcomingAppointments: 0,
        activeAdmissions: 41,
        pendingDischarges: 0,
        totalBeds: 42,
        occupiedBeds: 41,
        availableBeds: 1,
        activeClinicalAlerts: 0,
        totalBilled: 0,
        totalPaid: 0,
        totalOutstanding: 0,
        overallOccupancyRate: 98
    };
    @track isLoadingMetrics = true;

    get patientCount() {
        return this.patientsList ? this.patientsList.length : 0;
    }

    // Global Search & Autocomplete
    @track globalSearchKey = '';
    @track isSearchOpen = false;
    @track searchResults = [];

    // Role / Persona View Mode (UI Adaptation Only - Security strictly preserved)
    @track activeRole = 'Admin';
    roleOptions = [
        { label: 'System Administrator', value: 'Admin' },
        { label: 'Operations Manager', value: 'OpsManager' },
        { label: 'Attending Physician', value: 'Doctor' },
        { label: 'Inpatient Staff Nurse', value: 'Nurse' },
        { label: 'Front Desk & Admissions', value: 'FrontDesk' }
    ];

    // Public Specialties Roster
    specialties = [
        {
            id: 'genmed',
            name: 'General & Internal Medicine',
            icon: 'standard:stethoscope',
            badge: 'Primary Care',
            leadDoc: 'Dr. Kavita Rao',
            desc: 'Comprehensive adult medical care, chronic illness management, lifestyle disease mitigation, and executive wellness health checkups.'
        },
        {
            id: 'paed',
            name: 'Paediatrics & Neonatal Care',
            icon: 'standard:child_and_family',
            badge: 'Child Health',
            leadDoc: 'Dr. Anil Mehta',
            desc: 'Dedicated newborn, infant and adolescent care, routine immunizations, pediatric emergency services, and Level-3 NICU support.'
        },
        {
            id: 'ortho',
            name: 'Orthopaedics & Joint Surgery',
            icon: 'standard:action_list_component',
            badge: 'Surgical Excellence',
            leadDoc: 'Dr. Rajesh Pandey',
            desc: 'Advanced robotic arthroscopy, total knee and hip replacements, minimally invasive spine surgery, and sports injury rehabilitation.'
        },
        {
            id: 'derma',
            name: 'Dermatology & Skin Health',
            icon: 'standard:scan_card',
            badge: 'Clinical & Cosmetic',
            leadDoc: 'Dr. Neha Kapoor',
            desc: 'Comprehensive clinical dermatology, skin cancer screenings, allergy treatments, pediatric eczema management, and aesthetic lasers.'
        },
        {
            id: 'ent',
            name: 'Ear, Nose & Throat (ENT)',
            icon: 'standard:live_chat',
            badge: 'Head & Neck',
            leadDoc: 'Dr. Meena Iyer',
            desc: 'Endoscopic sinus surgeries, microscopic ear reconstructive procedures, pediatric audiology, vertigo clinic, and hearing rehabilitation.'
        },
        {
            id: 'critcare',
            name: 'Critical Care & Emergency (ICU)',
            icon: 'standard:service_territory_location',
            badge: '24/7 Level-1 Trauma',
            leadDoc: 'Dr. Imran Qureshi',
            desc: 'Advanced multidisciplinary 10-bed ICU with 1:1 nursing ratios, invasive hemodynamic monitoring, and 24/7 cardiac resuscitation.'
        }
    ];

    // Public Hospital Facilities (Qualitative Accommodation Standards)
    facilities = [
        {
            id: 'gw',
            name: 'General Inpatient Wards',
            capacity: 'Multi-Bed Recovery',
            type: 'Continuous Vital Monitoring',
            desc: 'Spacious, well-ventilated recovery wards equipped with central oxygen and 24/7 rapid nurse call stations.',
            badge: 'Monitored Care'
        },
        {
            id: 'sp',
            name: 'Semi-Private Suites',
            capacity: 'Twin-Sharing Suite',
            type: 'Dual Occupancy',
            desc: 'Quiet shared suites featuring motorized clinical beds, privacy curtains, companion recliners, and ensuite washrooms.',
            badge: 'Dual Occupancy'
        },
        {
            id: 'pr',
            name: 'Executive Private Rooms',
            capacity: 'Single Patient Suite',
            type: 'Private Healing Suite',
            desc: 'Private healing suites with ensuite bathrooms, companion couch, smart monitoring, and personalized dietary service.',
            badge: 'Private Suite'
        },
        {
            id: 'icu',
            name: 'Intensive Care Unit (ICU)',
            capacity: 'Critical Care Bay',
            type: '1:1 Nurse-Patient Ratio',
            desc: 'Critical care ward featuring advanced mechanical ventilators, invasive arterial lines, and defibrillators.',
            badge: 'Critical Care'
        },
        {
            id: 'pw',
            name: 'Paediatric Inpatient Wing',
            capacity: 'Family Accompanied',
            type: 'Specialized Child Care',
            desc: 'Warm, child-friendly pediatric ward tailored for children with dedicated parent accommodation and isolation units.',
            badge: 'Pediatric Wing'
        }
    ];

    // Public Patient Inquiry Form
    @track inquiryForm = {
        name: '',
        phone: '',
        email: '',
        department: 'General Medicine',
        message: ''
    };
    @track isSubmittingInquiry = false;
    @track inquirySubmitted = false;

    // Fast Booking Modal / Pill Selector
    @track selectedFastSpecialty = 'General Medicine';
    @track selectedFastDate = '';

    // Patients Directory Page State
    @track patientSearchTerm = '';
    @track patientsList = [];
    @track isLoadingPatients = false;
    @track selectedPatientProfile = null;
    @track isPatientProfileModalOpen = false;

    // Patient Registration Modal State
    @track isRegisterPatientModalOpen = false;
    @track newPatientForm = {
        firstName: '',
        lastName: '',
        phone: '',
        email: '',
        birthdate: ''
    };
    @track isSubmittingRegistration = false;
    @track registrationSuccessData = null;

    // Doctors Directory Page State
    @track doctorDeptFilter = 'All';
    @track doctorSearchKey = '';
    @track allDoctors = [];
    @track filteredDoctors = [];
    @track isLoadingDoctors = false;
    doctorDeptOptions = [
        { label: 'All Specialties', value: 'All' },
        { label: 'General Medicine', value: 'General Medicine' },
        { label: 'Paediatrics', value: 'Paediatrics' },
        { label: 'Orthopaedics', value: 'Orthopaedics' },
        { label: 'Dermatology', value: 'Dermatology' },
        { label: 'ENT', value: 'ENT' }
    ];

    // Wire Metrics
    wiredMetricsResult;
    @wire(getDashboardMetrics)
    wiredMetrics(result) {
        this.wiredMetricsResult = result;
        if (result.data) {
            this.metrics = result.data;
            this.isLoadingMetrics = false;
        } else if (result.error) {
            this.isLoadingMetrics = false;
        }
    }

    // Wire CurrentPageReference (Supports browser back/forward and URL deep-linking)
    currentPageRef;
    @wire(CurrentPageReference)
    wiredPageReference(pageRef) {
        this.currentPageRef = pageRef;
        if (pageRef && pageRef.state) {
            const sectionParam = pageRef.state.c__section || pageRef.state.section;
            const expParam = pageRef.state.c__exp || pageRef.state.exp;
            if (expParam === 'staff') {
                this.currentExperience = 'staff';
            }
            if (sectionParam) {
                this.applySectionFromUrl(sectionParam);
            }
        }
    }

    // Wire User Security Context (Verify patient portal vs internal staff permissions)
    @wire(getUserContext)
    wiredUserContext({ error, data }) {
        if (data) {
            this.userContext = data;
            this.isPatientPortalUser = data.isPatient === true;
            // If already on a protected section, verify authorization
            if (this.PROTECTED_SECTIONS.includes(this.activePage) && !this.isAuthorizedForSection(this.activePage)) {
                this.accessDeniedMessage = `Access to the ${this.getSectionLabel(this.activePage)} workspace is restricted to authorized hospital clinical staff.`;
                this.isAccessDenied = true;
                this.activePage = 'home';
                this.currentExperience = 'public';
            }
        } else if (error) {
            this.userContext = { isPatient: false };
        }
    }

    connectedCallback() {
        this.loadPatientsDirectory();
        this.loadDoctorsDirectory();

        // Fallback: Read initial URL query or hash on cold page load before CurrentPageReference resolves
        if (typeof window !== 'undefined' && window.location) {
            const params = new URLSearchParams(window.location.search);
            const urlSection = params.get('c__section') || params.get('section');
            const expParam = params.get('c__exp') || params.get('exp');
            if (expParam === 'staff') {
                this.currentExperience = 'staff';
            }
            if (urlSection && this.VALID_SECTIONS.includes(urlSection.toLowerCase())) {
                this.applySectionFromUrl(urlSection);
            } else if (window.location.hash) {
                const hashSection = window.location.hash.replace('#', '').toLowerCase();
                if (this.VALID_SECTIONS.includes(hashSection)) {
                    this.applySectionFromUrl(hashSection);
                }
            }
        }
    }

    // =========================================================================
    // EXPERIENCE & NAVIGATION GETTERS
    // =========================================================================
    get isPublicExperience() { return this.currentExperience === 'public'; }
    get isStaffExperience() { return this.currentExperience === 'staff'; }
    get heroImageUrl() {
        return CARENEST_HERO_IMG || 'https://images.unsplash.com/photo-1629909613654-28e377c37b09?auto=format&fit=crop&w=800&q=80';
    }

    // Page Getters (Backward Compatible with all existing local tests)
    get isHomePage() { return this.activePage === 'home'; }
    get isPatientsPage() { return this.activePage === 'patients'; }
    get isDoctorsPage() { return this.activePage === 'doctors'; }
    get isAppointmentsPage() { return this.activePage === 'appointments'; }
    get isWardsPage() { return this.activePage === 'wards'; }
    get isAdmissionsPage() { return this.activePage === 'admissions'; }
    get isClinicalPage() { return this.activePage === 'clinical'; }
    get isPaymentsPage() { return this.activePage === 'payments'; }
    get isAgentforcePage() { return this.activePage === 'agentforce'; }
    get isAdminPage() { return this.activePage === 'admin'; }

    // Public Specific Sub-Getters
    get isPublicHome() { return this.isPublicExperience && this.publicSection === 'home' && this.activePage === 'home'; }
    get isPublicSpecialties() { return this.isPublicExperience && this.publicSection === 'specialties'; }
    get isPublicFacilities() { return this.isPublicExperience && this.publicSection === 'facilities'; }
    get isPublicVisiting() { return this.isPublicExperience && this.publicSection === 'visiting'; }
    get isPublicContact() { return this.isPublicExperience && this.publicSection === 'contact'; }
    get isPublicEmergency() { return this.isPublicExperience && this.publicSection === 'emergency'; }

    // Shareable URL Getters (Inspectable & Shareable Href for Every Section)
    get homeUrl() { return this.getSectionUrl('home'); }
    get patientsUrl() { return this.getSectionUrl('patients'); }
    get doctorsUrl() { return this.getSectionUrl('doctors'); }
    get appointmentsUrl() { return this.getSectionUrl('appointments'); }
    get wardsUrl() { return this.getSectionUrl('wards'); }
    get admissionsUrl() { return this.getSectionUrl('admissions'); }
    get clinicalUrl() { return this.getSectionUrl('clinical'); }
    get paymentsUrl() { return this.getSectionUrl('payments'); }
    get agentforceUrl() { return this.getSectionUrl('agentforce'); }
    get adminUrl() { return this.getSectionUrl('admin'); }

    getSectionUrl(section) {
        if (this.isStaffExperience) {
            return `?c__exp=staff&c__section=${section}`;
        }
        return section === 'home' ? '?' : `?c__section=${section}`;
    }

    // Nav Item Class Getters
    get navHomeClass() { return `care-nav-item ${this.activePage === 'home' && this.publicSection === 'home' ? 'is-active' : ''}`; }
    get navSpecialtiesClass() { return `care-nav-item ${this.publicSection === 'specialties' ? 'is-active' : ''}`; }
    get navPatientsClass() { return `care-nav-item ${this.activePage === 'patients' ? 'is-active' : ''}`; }
    get navDoctorsClass() { return `care-nav-item ${this.activePage === 'doctors' ? 'is-active' : ''}`; }
    get navAppointmentsClass() { return `care-nav-item ${this.activePage === 'appointments' ? 'is-active' : ''}`; }
    get navWardsClass() { return `care-nav-item ${this.activePage === 'wards' || this.publicSection === 'facilities' ? 'is-active' : ''}`; }
    get navAdmissionsClass() { return `care-nav-item ${this.activePage === 'admissions' ? 'is-active' : ''}`; }
    get navClinicalClass() { return `care-nav-item ${this.activePage === 'clinical' ? 'is-active' : ''}`; }
    get navPaymentsClass() { return `care-nav-item ${this.activePage === 'payments' ? 'is-active' : ''}`; }
    get navAgentforceClass() { return `care-nav-item ${this.activePage === 'agentforce' ? 'is-active' : ''}`; }
    get navAdminClass() { return `care-nav-item ${this.activePage === 'admin' ? 'is-active' : ''}`; }
    get navVisitingClass() { return `care-nav-item ${this.publicSection === 'visiting' ? 'is-active' : ''}`; }
    get navContactClass() { return `care-nav-item ${this.publicSection === 'contact' ? 'is-active' : ''}`; }

    // =========================================================================
    // EXPERIENCE SWITCHING & ROUTING
    // =========================================================================
    handleSwitchToStaffWorkspace() {
        this.currentExperience = 'staff';
        this.isMobileMenuOpen = false;
        this.showToast('Staff Workspace Active', 'Entered Authenticated Hospital Operations Suite', 'info');
        this.navigateToSection(this.activePage === 'home' ? 'home' : this.activePage);
    }

    handleSwitchToPublicWebsite() {
        this.currentExperience = 'public';
        this.publicSection = 'home';
        this.activePage = 'home';
        this.isMobileMenuOpen = false;
        this.navigateToSection('home');
    }

    handleNavSelect(event) {
        event.preventDefault();
        const targetPage = event.currentTarget.dataset.page;
        if (!targetPage) return;

        this.isMobileMenuOpen = false;

        // If in public mode and user clicked a public sub-section
        if (this.isPublicExperience && ['specialties', 'facilities', 'visiting', 'contact', 'emergency'].includes(targetPage)) {
            this.publicSection = targetPage;
            this.activePage = 'home';
            this.scrollToPublicSection(targetPage);
            return;
        }

        // Check protected route permissions
        if (this.PROTECTED_SECTIONS.includes(targetPage) && !this.isAuthorizedForSection(targetPage)) {
            this.accessDeniedMessage = `Access to the ${this.getSectionLabel(targetPage)} workspace is restricted to authorized hospital clinical staff.`;
            this.isAccessDenied = true;
            return;
        }

        this.isAccessDenied = false;
        this.publicSection = 'home';
        this.navigateToSection(targetPage);
    }

    scrollToPublicSection(sectionId) {
        if (typeof window !== 'undefined') {
            const el = this.template.querySelector(`[data-section="${sectionId}"]`);
            if (el) {
                el.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        }
    }

    navigateToSection(section) {
        if (!this.VALID_SECTIONS.includes(section)) return;
        this.activePage = section;

        // Synchronize with URL State without page reload
        if (this.currentPageRef) {
            const updatedRef = JSON.parse(JSON.stringify(this.currentPageRef));
            if (!updatedRef.state) updatedRef.state = {};
            updatedRef.state.c__section = section;
            if (this.isStaffExperience) {
                updatedRef.state.c__exp = 'staff';
            } else {
                delete updatedRef.state.c__exp;
            }
            this[NavigationMixin.Navigate](updatedRef, false);
        }

        if (typeof window !== 'undefined' && window.scrollTo) {
            window.scrollTo({ top: 0, behavior: 'smooth' });
        }
    }

    applySectionFromUrl(section) {
        const clean = section.toLowerCase();
        if (['specialties', 'facilities', 'visiting', 'contact', 'emergency'].includes(clean)) {
            this.publicSection = clean;
            this.activePage = 'home';
            return;
        }

        if (this.VALID_SECTIONS.includes(clean)) {
            if (this.PROTECTED_SECTIONS.includes(clean) && !this.isAuthorizedForSection(clean)) {
                this.accessDeniedMessage = `Access to the ${this.getSectionLabel(clean)} workspace is restricted to authorized hospital clinical staff.`;
                this.isAccessDenied = true;
                this.activePage = 'home';
                this.currentExperience = 'public';
                return;
            }
            this.activePage = clean;
            // If the section is strictly internal, switch to staff experience
            if (['patients', 'wards', 'admissions', 'clinical', 'payments', 'admin'].includes(clean)) {
                this.currentExperience = 'staff';
            }
        }
    }

    isAuthorizedForSection(section) {
        if (this.isPatientPortalUser && this.PROTECTED_SECTIONS.includes(section)) {
            return false;
        }
        return true;
    }

    getSectionLabel(section) {
        const labels = {
            clinical: 'Inpatient Clinical Documentation & Charts',
            payments: 'Hospital Billing & Invoicing',
            admin: 'Hospital Administration & Telemetry'
        };
        return labels[section] || section;
    }

    handleToggleMobileMenu() {
        this.isMobileMenuOpen = !this.isMobileMenuOpen;
    }

    handleDismissAccessDenied() {
        this.isAccessDenied = false;
        this.accessDeniedMessage = '';
    }

    handleRoleChange(event) {
        this.activeRole = event.detail.value;
    }

    // =========================================================================
    // PUBLIC PATIENT INQUIRY FORM
    // =========================================================================
    handleInquiryInputChange(event) {
        const field = event.target.name;
        this.inquiryForm = { ...this.inquiryForm, [field]: event.target.value };
    }

    handleInquirySubmit(event) {
        event.preventDefault();
        if (!this.inquiryForm.name || !this.inquiryForm.phone) {
            this.showToast('Validation Warning', 'Please provide your Full Name and Contact Phone to submit an inquiry', 'warning');
            return;
        }
        this.isSubmittingInquiry = true;
        setTimeout(() => {
            this.isSubmittingInquiry = false;
            this.inquirySubmitted = true;
            this.showToast('Demo Form Logged', 'Demonstration feedback captured in simulated mode. No production records or real patient data were created.', 'info');
        }, 300);
    }

    handleResetInquiry() {
        this.inquiryForm = { name: '', phone: '', email: '', department: 'General Medicine', message: '' };
        this.inquirySubmitted = false;
    }

    // =========================================================================
    // PATIENTS DIRECTORY & REGISTRATION
    // =========================================================================
    async loadPatientsDirectory() {
        this.isLoadingPatients = true;
        try {
            const results = await searchPatients({ searchTerm: this.patientSearchTerm || '' });
            this.patientsList = results.map(p => ({
                ...p,
                patientCode: p.patientCode || 'CN-PAT-GEN',
                badgeClass: p.isPatient ? 'status-badge-active' : 'status-badge-inactive'
            }));
        } catch (error) {
            this.patientsList = [];
        } finally {
            this.isLoadingPatients = false;
        }
    }

    handlePatientSearchChange(event) {
        this.patientSearchTerm = event.target.value;
        this.loadPatientsDirectory();
    }

    handleOpenRegisterModal() {
        this.newPatientForm = { firstName: '', lastName: '', phone: '', email: '', birthdate: '' };
        this.registrationSuccessData = null;
        this.isRegisterPatientModalOpen = true;
    }

    handleCloseRegisterModal() {
        this.isRegisterPatientModalOpen = false;
        this.loadPatientsDirectory();
    }

    handleNewPatientInputChange(event) {
        const field = event.target.name;
        this.newPatientForm = { ...this.newPatientForm, [field]: event.target.value };
    }

    async handleSubmitRegisterPatient() {
        if (!this.newPatientForm.lastName || !this.newPatientForm.lastName.trim()) {
            this.showToast('Validation Warning', 'Last Name is required to register a hospital patient', 'warning');
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

            if (res.isSuccess) {
                const fullName = (this.newPatientForm.firstName ? this.newPatientForm.firstName.trim() + ' ' : '') + this.newPatientForm.lastName.trim();
                this.registrationSuccessData = {
                    contactId: res.contactId,
                    patientCode: res.patientCode,
                    patientName: fullName
                };
                this.showToast('Patient Registered', `Sequential Code: ${res.patientCode}`, 'success');
                this.loadPatientsDirectory();
            } else {
                this.showToast('Registration Notice', res.message, 'warning');
            }
        } catch (error) {
            this.showToast('Registration Error', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isSubmittingRegistration = false;
        }
    }

    handleJumpToAdmissionsFromRegister() {
        this.handleCloseRegisterModal();
        this.currentExperience = 'staff';
        this.navigateToSection('admissions');
    }

    handleViewPatientProfile(event) {
        const patientId = event.currentTarget.dataset.id;
        const patient = this.patientsList.find(p => p.id === patientId);
        if (patient) {
            this.selectedPatientProfile = patient;
            this.isPatientProfileModalOpen = true;
        }
    }

    handleClosePatientProfile() {
        this.isPatientProfileModalOpen = false;
        this.selectedPatientProfile = null;
    }

    // =========================================================================
    // DOCTORS DIRECTORY
    // =========================================================================
    async loadDoctorsDirectory() {
        this.isLoadingDoctors = true;
        try {
            const docs = await getDoctorsWithAvailability({ department: '', searchKey: '' });
            this.allDoctors = docs.map(d => {
                const isVerified = d.availabilityStatus && d.availabilityStatus.includes('Verified OPD');
                return {
                    ...d,
                    initials: d.name ? d.name.replace('Dr. ', '').substring(0, 2).toUpperCase() : 'DR',
                    isOpdAvailable: isVerified,
                    badgeLabel: d.availabilityStatus || 'Inpatient On-Call',
                    badgeClass: isVerified ? 'badge-opd-available' : 'badge-inpatient-oncall'
                };
            });
            this.filterDoctors();
        } catch (error) {
            this.allDoctors = [];
        } finally {
            this.isLoadingDoctors = false;
        }
    }

    handleDoctorDeptChange(event) {
        this.doctorDeptFilter = event.detail.value;
        this.filterDoctors();
    }

    handleDoctorSearchChange(event) {
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

    handleBookWithDoctor() {
        this.navigateToSection('appointments');
    }

    handleAdmitWithDoctor() {
        this.currentExperience = 'staff';
        this.navigateToSection('admissions');
    }

    // =========================================================================
    // GLOBAL QUICK SHORTCUTS
    // =========================================================================
    handleQuickAdmit() {
        this.currentExperience = 'staff';
        this.navigateToSection('admissions');
    }

    handleQuickAppointments() {
        this.navigateToSection('appointments');
    }

    handleQuickWards() {
        if (this.isPublicExperience) {
            this.publicSection = 'facilities';
            this.scrollToPublicSection('facilities');
        } else {
            this.navigateToSection('wards');
        }
    }

    handleQuickClinical() {
        this.currentExperience = 'staff';
        this.navigateToSection('clinical');
    }

    handleQuickAgentforce() {
        this.navigateToSection('agentforce');
    }

    handleSimulatedAction(event) {
        if (event) {
            event.preventDefault();
        }
        this.showToast(
            'Simulated Demo Helpline',
            'This is a portfolio simulation. In a real-life medical emergency, call 911 / 112 / 108 immediately.',
            'info'
        );
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}

