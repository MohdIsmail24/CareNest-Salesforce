import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInpatientAdmissions from '@salesforce/apex/CareNestClinicalController.getInpatientAdmissions';
import getEncounters from '@salesforce/apex/CareNestClinicalController.getEncounters';
import getVitals from '@salesforce/apex/CareNestClinicalController.getVitals';
import recordVital from '@salesforce/apex/CareNestClinicalController.recordVital';
import createEncounter from '@salesforce/apex/CareNestClinicalController.createEncounter';
import getDevMalhotraIcuVital from '@salesforce/apex/CareNestClinicalController.getDevMalhotraIcuVital';
import acknowledgeVitalAlert from '@salesforce/apex/CareNestClinicalController.acknowledgeVitalAlert';
import resolveVitalAlert from '@salesforce/apex/CareNestClinicalController.resolveVitalAlert';

export default class InpatientClinicalWorkspace extends LightningElement {
    @track isLoadingPatients = true;
    @track isLoadingVitals = false;
    @track isLoadingEncounters = false;
    @track searchTerm = '';
    @track patients = [];
    @track selectedPatient = null;
    @track vitals = [];
    @track encounters = [];

    // Modals
    @track isRecordVitalModalOpen = false;
    @track isNewEncounterModalOpen = false;
    @track isResolveAlertModalOpen = false;
    @track selectedVitalForResolution = null;
    @track resolutionNotesInput = '';
    @track isSubmittingResolution = false;

    // Vital Form
    @track newVital = {
        systolic: 120,
        diastolic: 80,
        pulse: 72,
        temperature: 36.8,
        spO2: 98,
        respiratoryRate: 16,
        notes: ''
    };
    @track isSubmittingVital = false;

    // Encounter Form
    @track newEncounter = {
        encounterType: 'Daily Ward Round',
        chiefComplaint: '',
        notes: '',
        assessment: ''
    };
    @track isSubmittingEncounter = false;

    encounterTypeOptions = [
        { label: 'Daily Ward Round', value: 'Daily Ward Round' },
        { label: 'Doctor Round', value: 'Doctor Round' },
        { label: 'Initial Assessment', value: 'Initial Assessment' },
        { label: 'Nursing Assessment', value: 'Nursing Assessment' },
        { label: 'Consultation', value: 'Consultation' },
        { label: 'Emergency', value: 'Emergency' },
        { label: 'Pre-Discharge', value: 'Pre-Discharge' },
        { label: 'Discharge Review', value: 'Discharge Review' }
    ];

    wiredPatientsResult;

    @wire(getInpatientAdmissions, { searchTerm: '$searchTerm' })
    wiredAdmissions(result) {
        this.wiredPatientsResult = result;
        if (result.data) {
            this.patients = result.data.map(p => ({
                ...p,
                cardClass: this.selectedPatient && this.selectedPatient.admissionId === p.admissionId 
                    ? 'patient-card patient-card-active' 
                    : 'patient-card'
            }));
            this.isLoadingPatients = false;

            // Select first patient or keep current selected
            if (this.patients.length > 0 && !this.selectedPatient) {
                this.selectPatient(this.patients[0]);
            }
        } else if (result.error) {
            this.showError('Error loading inpatients', result.error);
            this.isLoadingPatients = false;
        }
    }

    get hasPatients() {
        return this.patients && this.patients.length > 0;
    }

    get hasVitals() {
        return this.vitals && this.vitals.length > 0;
    }

    get hasEncounters() {
        return this.encounters && this.encounters.length > 0;
    }

    get selectedPatientHasAlert() {
        return this.selectedPatient && this.vitals.some(v => v.alertFlag && v.alertStatus !== 'Resolved');
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handleSelectPatientCard(event) {
        const admId = event.currentTarget.dataset.admissionId;
        const found = this.patients.find(p => p.admissionId === admId);
        if (found) {
            this.selectPatient(found);
        }
    }

    selectPatient(patient) {
        this.selectedPatient = patient;
        this.patients = this.patients.map(p => ({
            ...p,
            cardClass: p.admissionId === patient.admissionId ? 'patient-card patient-card-active' : 'patient-card'
        }));
        this.loadPatientDetails(patient.admissionId);
    }

    async loadPatientDetails(admissionId) {
        this.isLoadingVitals = true;
        this.isLoadingEncounters = true;

        try {
            const [vits, encs] = await Promise.all([
                getVitals({ admissionId }),
                getEncounters({ admissionId })
            ]);

            this.vitals = vits.map(v => {
                const isAlert = v.alertFlag && v.alertStatus !== 'Resolved';
                const isAck = v.alertStatus === 'Acknowledged';
                const isResolved = v.alertStatus === 'Resolved';

                let formattedDate = 'Not Recorded';
                if (v.recordedAt) {
                    try {
                        formattedDate = new Date(v.recordedAt).toLocaleString('en-US', {
                            month: 'short',
                            day: 'numeric',
                            hour: 'numeric',
                            minute: '2-digit',
                            hour12: true
                        });
                    } catch (e) {
                        formattedDate = v.recordedAt;
                    }
                }

                return {
                    ...v,
                    vitalId: v.id,
                    recordedDateDisplay: formattedDate,
                    bpDisplay: v.bpFormatted || 'Not Recorded',
                    pulseDisplay: v.pulseBpm != null ? `${v.pulseBpm} bpm` : 'Not Recorded',
                    tempDisplay: v.temperatureC != null ? `${v.temperatureC} °C` : 'Not Recorded',
                    spo2Display: v.spo2Percent != null ? `${v.spo2Percent}%` : 'Not Recorded',
                    respRateDisplay: v.respiratoryRate != null ? `${v.respiratoryRate} /min` : 'Not Recorded',
                    rowClass: isAlert ? 'vital-row vital-row-alert' : (isResolved ? 'vital-row vital-row-resolved' : 'vital-row'),
                    bpClass: isAlert ? 'vital-val-alert font-bold' : '',
                    spo2Class: isAlert ? 'vital-val-alert font-bold' : '',
                    isActionableAlert: isAlert,
                    isAcknowledged: isAck,
                    isResolved: isResolved
                };
            });

            this.encounters = encs;
        } catch (error) {
            this.showError('Error loading patient details', error);
        } finally {
            this.isLoadingVitals = false;
            this.isLoadingEncounters = false;
        }
    }

    async handleJumpToDevMalhotra() {
        try {
            const icuInfo = await getDevMalhotraIcuVital();
            if (icuInfo && icuInfo.admissionId) {
                // Find patient in list or set up patient
                const found = this.patients.find(p => p.admissionId === icuInfo.admissionId);
                if (found) {
                    this.selectPatient(found);
                } else {
                    // Create simulated patient item
                    const patient = {
                        admissionId: icuInfo.admissionId,
                        admissionNumber: 'ICU-RECORD',
                        patientName: icuInfo.patientName,
                        wardName: 'Intensive Care Unit (ICU)',
                        bedCode: 'ICU-B1',
                        room: 'ICU-1',
                        doctorName: 'Dr. Neha Sharma',
                        doctorSpecialty: 'Critical Care',
                        hasActiveAlerts: true,
                        alertCount: 1,
                        admissionDate: 'Current Inpatient',
                        cardClass: 'patient-card patient-card-active'
                    };
                    this.selectedPatient = patient;
                    await this.loadPatientDetails(icuInfo.admissionId);
                }
                this.showToast('ICU Critical Alert', `Loaded critical vitals for ${icuInfo.patientName}`, 'error');
            } else {
                this.showToast('Notice', 'Dev Malhotra critical ICU record not found in system', 'info');
            }
        } catch (error) {
            this.showError('Error jumping to Dev Malhotra alert', error);
        }
    }

    // Record Vital Modal Handlers
    handleOpenRecordVitalModal() {
        this.newVital = {
            systolic: 120,
            diastolic: 80,
            pulse: 72,
            temperature: 36.8,
            spO2: 98,
            respiratoryRate: 16,
            notes: ''
        };
        this.isRecordVitalModalOpen = true;
    }

    handleCloseRecordVitalModal() {
        this.isRecordVitalModalOpen = false;
    }

    handleVitalInput(event) {
        const field = event.target.dataset.field;
        this.newVital[field] = event.target.value;
    }

    async handleSubmitRecordVital() {
        if (!this.newVital.systolic || !this.newVital.diastolic || !this.newVital.pulse) {
            this.showToast('Validation Error', 'Please complete systolic, diastolic, and pulse fields', 'warning');
            return;
        }

        this.isSubmittingVital = true;
        try {
            const res = await recordVital({
                admissionId: this.selectedPatient.admissionId,
                systolic: parseFloat(this.newVital.systolic),
                diastolic: parseFloat(this.newVital.diastolic),
                pulse: parseFloat(this.newVital.pulse),
                temp: parseFloat(this.newVital.temperature),
                spO2: parseFloat(this.newVital.spO2),
                respRate: parseFloat(this.newVital.respiratoryRate),
                notes: this.newVital.notes
            });

            if (res.isSuccess) {
                this.showToast(
                    res.alertFlag ? 'Vital Recorded (ALERT)' : 'Vital Recorded', 
                    res.message, 
                    res.alertFlag ? 'error' : 'success'
                );
                this.isRecordVitalModalOpen = false;
                await this.loadPatientDetails(this.selectedPatient.admissionId);
            } else {
                this.showToast('Save Failed', res.message, 'error');
            }
        } catch (error) {
            this.showError('Error recording vitals', error);
        } finally {
            this.isSubmittingVital = false;
        }
    }

    // New Encounter Modal Handlers
    handleOpenNewEncounterModal() {
        this.newEncounter = {
            encounterType: 'Daily Rounds',
            chiefComplaint: '',
            notes: '',
            assessment: ''
        };
        this.isNewEncounterModalOpen = true;
    }

    handleCloseNewEncounterModal() {
        this.isNewEncounterModalOpen = false;
    }

    handleEncounterTypeChange(event) {
        this.newEncounter.encounterType = event.detail.value;
    }

    handleEncounterInput(event) {
        const field = event.target.dataset.field;
        this.newEncounter[field] = event.target.value;
    }

    async handleSubmitNewEncounter() {
        if (!this.newEncounter.chiefComplaint || !this.newEncounter.notes) {
            this.showToast('Validation Error', 'Please provide chief complaint and clinical notes', 'warning');
            return;
        }

        this.isSubmittingEncounter = true;
        try {
            const res = await createEncounter({
                admissionId: this.selectedPatient.admissionId,
                encounterType: this.newEncounter.encounterType,
                chiefComplaint: this.newEncounter.chiefComplaint,
                notes: this.newEncounter.notes,
                assessment: this.newEncounter.assessment
            });

            if (res.isSuccess) {
                this.showToast('Encounter Logged', res.message, 'success');
                this.isNewEncounterModalOpen = false;
                await this.loadPatientDetails(this.selectedPatient.admissionId);
            } else {
                this.showToast('Error', res.message, 'error');
            }
        } catch (error) {
            this.showError('Error logging encounter', error);
        } finally {
            this.isSubmittingEncounter = false;
        }
    }

    // =========================================================================
    // ALERT LIFECYCLE HANDLERS (Acknowledge & Resolve)
    // =========================================================================

    async handleTableAcknowledgeAlert(event) {
        const vitalId = event.target.dataset.vitalId;
        if (!vitalId) return;

        try {
            await acknowledgeVitalAlert({ vitalId, notes: 'Acknowledged at clinical station' });
            this.showToast('Alert Acknowledged', 'Clinical vital alert status transitioned to Acknowledged.', 'warning');
            if (this.selectedPatient) {
                await this.loadPatientDetails(this.selectedPatient.admissionId);
            }
        } catch (err) {
            this.showError('Failed to acknowledge alert', err);
        }
    }

    handleTableResolveAlert(event) {
        const vitalId = event.target.dataset.vitalId;
        this.selectedVitalForResolution = this.vitals.find(v => v.vitalId === vitalId) || { vitalId };
        this.resolutionNotesInput = 'Clinical intervention administered; patient hemodynamics stabilized.';
        this.isResolveAlertModalOpen = true;
    }

    handleQuickAcknowledgeAlert() {
        const unack = this.vitals.find(v => v.isActionableAlert && !v.isAcknowledged);
        if (unack) {
            this.handleTableAcknowledgeAlert({ target: { dataset: { vitalId: unack.vitalId } } });
        } else {
            const firstAlert = this.vitals.find(v => v.isActionableAlert);
            if (firstAlert) {
                this.handleTableAcknowledgeAlert({ target: { dataset: { vitalId: firstAlert.vitalId } } });
            }
        }
    }

    handleOpenResolveAlertModal() {
        const alert = this.vitals.find(v => v.isActionableAlert);
        if (alert) {
            this.selectedVitalForResolution = alert;
            this.resolutionNotesInput = 'Clinical intervention completed; vitals stabilized and continuous monitoring maintained.';
            this.isResolveAlertModalOpen = true;
        }
    }

    handleCloseResolveAlertModal() {
        this.isResolveAlertModalOpen = false;
        this.selectedVitalForResolution = null;
        this.resolutionNotesInput = '';
    }

    handleResolutionNotesChange(e) {
        this.resolutionNotesInput = e.target.value;
    }

    async handleSubmitResolveAlert() {
        if (!this.resolutionNotesInput || !this.resolutionNotesInput.trim()) {
            this.showToast('Validation Error', 'Clinical resolution notes and action plan are required.', 'warning');
            return;
        }
        if (!this.selectedVitalForResolution || !this.selectedVitalForResolution.vitalId) {
            this.showToast('Error', 'No vital record targeted for resolution.', 'error');
            return;
        }

        this.isSubmittingResolution = true;
        try {
            await resolveVitalAlert({
                vitalId: this.selectedVitalForResolution.vitalId,
                resolutionNotes: this.resolutionNotesInput.trim()
            });

            this.showToast('Alert Resolved', 'Clinical alert successfully resolved and removed from urgent queue.', 'success');
            this.handleCloseResolveAlertModal();

            if (this.selectedPatient) {
                await this.loadPatientDetails(this.selectedPatient.admissionId);
                await refreshApex(this.wiredPatientsResult);
            }
        } catch (err) {
            this.showError('Failed to resolve alert', err);
        } finally {
            this.isSubmittingResolution = false;
        }
    }

    async handleRefresh() {
        this.isLoadingPatients = true;
        try {
            await refreshApex(this.wiredPatientsResult);
            if (this.selectedPatient) {
                await this.loadPatientDetails(this.selectedPatient.admissionId);
            }
            this.showToast('Refreshed', 'Clinical workspace refreshed', 'success');
        } catch (error) {
            this.showError('Error refreshing workspace', error);
        } finally {
            this.isLoadingPatients = false;
        }
    }

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
