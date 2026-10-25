import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getWardSummaries from '@salesforce/apex/CareNestWardBedController.getWardSummaries';
import getBeds from '@salesforce/apex/CareNestWardBedController.getBeds';

export default class WardBedManager extends LightningElement {
    @track isLoading = true;
    @track wardMetrics = [];
    @track allBeds = [];
    @track filteredBeds = [];
    @track selectedWardId = 'ALL';
    @track selectedStatusFilter = 'ALL';
    @track selectedBedModal = null;

    wiredWardsResult;
    wiredBedsResult;

    @wire(getWardSummaries)
    wiredWards(result) {
        this.wiredWardsResult = result;
        if (result.data) {
            this.wardMetrics = result.data.map(w => ({
                ...w,
                cardClass: this.selectedWardId === w.wardId ? 'ward-summary-card ward-card-active' : 'ward-summary-card'
            }));
        } else if (result.error) {
            this.showError('Error loading ward capacity', result.error);
        }
    }

    @wire(getBeds, { wardId: '$targetWardIdForApex', statusFilter: '$selectedStatusFilter' })
    wiredBeds(result) {
        this.wiredBedsResult = result;
        if (result.data) {
            this.allBeds = result.data.map(b => this.decorateBed(b));
            this.filteredBeds = [...this.allBeds];
            this.isLoading = false;
        } else if (result.error) {
            this.showError('Error loading bed inventory', result.error);
            this.isLoading = false;
        }
    }

    get targetWardIdForApex() {
        return this.selectedWardId === 'ALL' ? null : this.selectedWardId;
    }

    get wardOptions() {
        const options = [{ label: 'All Hospital Wards (42 Beds)', value: 'ALL' }];
        if (this.wardMetrics) {
            this.wardMetrics.forEach(w => {
                options.push({
                    label: `${w.name} (${w.availableBeds} Avail / ${w.totalBeds} Total)`,
                    value: w.wardId
                });
            });
        }
        return options;
    }

    get filterAllVariant() {
        return this.selectedStatusFilter === 'ALL' ? 'brand' : 'neutral';
    }

    get filterAvailableVariant() {
        return this.selectedStatusFilter === 'Available' ? 'brand' : 'neutral';
    }

    get filterOccupiedVariant() {
        return this.selectedStatusFilter === 'Occupied' ? 'brand' : 'neutral';
    }

    get filterMaintenanceVariant() {
        return this.selectedStatusFilter === 'Maintenance' ? 'brand' : 'neutral';
    }

    get hasBeds() {
        return this.filteredBeds && this.filteredBeds.length > 0;
    }

    decorateBed(b) {
        let cardCssClass = 'bed-tile bed-tile-available';
        let badgeCssClass = 'slds-badge slds-theme_success';

        if (b.status === 'Occupied') {
            cardCssClass = 'bed-tile bed-tile-occupied';
            badgeCssClass = 'slds-badge slds-theme_error';
        } else if (b.status === 'Maintenance') {
            cardCssClass = 'bed-tile bed-tile-maintenance';
            badgeCssClass = 'slds-badge slds-theme_warning';
        }

        return {
            ...b,
            cardCssClass,
            badgeCssClass
        };
    }

    handleWardChange(event) {
        this.selectedWardId = event.detail.value;
        this.updateWardCardsHighlight();
        this.isLoading = true;
    }

    handleSelectWardCard(event) {
        const clickedWardId = event.currentTarget.dataset.wardId;
        if (this.selectedWardId === clickedWardId) {
            this.selectedWardId = 'ALL';
        } else {
            this.selectedWardId = clickedWardId;
        }
        this.updateWardCardsHighlight();
        this.isLoading = true;
    }

    updateWardCardsHighlight() {
        this.wardMetrics = this.wardMetrics.map(w => ({
            ...w,
            cardClass: this.selectedWardId === w.wardId ? 'ward-summary-card ward-card-active' : 'ward-summary-card'
        }));
    }

    handleFilterAll() {
        this.selectedStatusFilter = 'ALL';
        this.isLoading = true;
    }

    handleFilterAvailable() {
        this.selectedStatusFilter = 'Available';
        this.isLoading = true;
    }

    handleFilterOccupied() {
        this.selectedStatusFilter = 'Occupied';
        this.isLoading = true;
    }

    handleFilterMaintenance() {
        this.selectedStatusFilter = 'Maintenance';
        this.isLoading = true;
    }

    handleBedClick(event) {
        const bedId = event.currentTarget.dataset.bedId;
        const found = this.allBeds.find(b => b.bedId === bedId);
        if (found) {
            this.selectedBedModal = found;
        }
    }

    handleCloseModal() {
        this.selectedBedModal = null;
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            await Promise.all([
                refreshApex(this.wiredWardsResult),
                refreshApex(this.wiredBedsResult)
            ]);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Refreshed',
                    message: 'Ward and Bed status updated successfully',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.showError('Error refreshing beds', error);
        } finally {
            this.isLoading = false;
        }
    }

    showError(title, error) {
        let msg = 'Unknown error';
        if (error && error.body && error.body.message) {
            msg = error.body.message;
        } else if (error && error.message) {
            msg = error.message;
        }
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message: msg,
                variant: 'error'
            })
        );
    }
}
