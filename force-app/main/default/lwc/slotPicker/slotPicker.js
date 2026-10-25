import { LightningElement, api, track, wire } from 'lwc';
import getDoctorSlots from '@salesforce/apex/DoctorSearchController.getDoctorSlots';
import searchSlots from '@salesforce/apex/DoctorSearchController.searchSlots';

export default class SlotPicker extends LightningElement {
    _doctorId = null;
    @api department = '';

    @api
    get doctorId() {
        return this._doctorId;
    }
    set doctorId(value) {
        this._doctorId = value || null;
        if (!this._doctorId && !this.department) {
            this.rawSlots = [];
            this.error = null;
        }
    }

    @api selectedSlotId;
    @track selectedDate = null;
    @track rawSlots = [];
    @track isLoading = false;
    @track error = null;

    get wireDoctorId() {
        return this._doctorId ? this._doctorId : undefined;
    }

    @wire(getDoctorSlots, { doctorId: '$wireDoctorId', slotDate: '$selectedDate' })
    wiredSlots({ error, data }) {
        if (this._doctorId) {
            this.isLoading = false;
            if (data) {
                this.rawSlots = data;
                this.error = null;
            } else if (error) {
                this.rawSlots = [];
                this.error = error.body ? error.body.message : 'Error fetching slots';
            }
        }
    }

    @wire(searchSlots, { department: '$department', mode: 'All', onDate: '$selectedDate' })
    wiredDeptSlots({ error, data }) {
        if (!this._doctorId && this.department) {
            this.isLoading = false;
            if (data) {
                this.rawSlots = data;
                this.error = null;
            } else if (error) {
                this.rawSlots = [];
                this.error = error.body ? error.body.message : 'Error fetching department slots';
            }
        }
    }

    get showNoDoctorSelected() {
        return !this.doctorId && !this.department;
    }

    get hasSlots() {
        return !this.isLoading && this.slots.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && (Boolean(this.doctorId) || Boolean(this.department)) && this.slots.length === 0 && !this.error;
    }

    get slots() {
        return this.rawSlots.map(s => {
            const isSelected = s.id === this.selectedSlotId;
            const formattedTime = s.slotStart ? new Date(s.slotStart).toLocaleString('en-US', {
                month: 'short',
                day: 'numeric',
                year: 'numeric',
                hour: 'numeric',
                minute: '2-digit',
                hour12: true
            }) : s.label;

            return {
                ...s,
                formattedTime,
                tileClass: isSelected
                    ? 'slot-tile slot-tile_selected'
                    : 'slot-tile',
                modeBadgeClass: s.mode === 'Teleconsult'
                    ? 'slds-badge slds-theme_success'
                    : 'slds-badge slds-badge_lightest'
            };
        });
    }

    handleDateChange(event) {
        this.selectedDate = event.target.value;
        this.isLoading = true;
    }

    handleSelectSlot(event) {
        const slotId = event.currentTarget.dataset.id;
        const slotLabel = event.currentTarget.dataset.label;
        const fee = Number(event.currentTarget.dataset.fee);
        const mode = event.currentTarget.dataset.mode;
        const seatsLeft = Number(event.currentTarget.dataset.seats);
        const slotStart = event.currentTarget.dataset.start;

        this.selectedSlotId = slotId;

        this.dispatchEvent(new CustomEvent('slotselected', {
            detail: {
                slotId,
                slotLabel,
                fee,
                mode,
                seatsLeft,
                slotStart
            },
            bubbles: true,
            composed: true
        }));
    }
}
