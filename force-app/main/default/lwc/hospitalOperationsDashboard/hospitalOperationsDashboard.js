import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDashboardMetrics from '@salesforce/apex/CareNestDashboardController.getDashboardMetrics';
import getWardSummaries from '@salesforce/apex/CareNestDashboardController.getWardSummaries';
import getRecentActivities from '@salesforce/apex/CareNestDashboardController.getRecentActivities';

export default class HospitalOperationsDashboard extends LightningElement {
    @track isLoading = true;
    @track metrics = {
        totalDoctors: 0,
        activeAdmissions: 0,
        totalBeds: 0,
        occupiedBeds: 0,
        availableBeds: 0,
        activeClinicalAlerts: 0,
        overallOccupancyRate: 0
    };
    @track wardSummaries = [];
    @track activities = [];

    wiredMetricsResult;
    wiredWardsResult;
    wiredActivitiesResult;

    @wire(getDashboardMetrics)
    wiredMetrics(result) {
        this.wiredMetricsResult = result;
        if (result.data) {
            this.metrics = result.data;
            this.checkLoading();
        } else if (result.error) {
            this.showError('Error loading dashboard metrics', result.error);
            this.checkLoading();
        }
    }

    @wire(getWardSummaries)
    wiredWards(result) {
        this.wiredWardsResult = result;
        if (result.data) {
            this.wardSummaries = result.data;
            this.checkLoading();
        } else if (result.error) {
            this.showError('Error loading ward summaries', result.error);
            this.checkLoading();
        }
    }

    @wire(getRecentActivities)
    wiredActivities(result) {
        this.wiredActivitiesResult = result;
        if (result.data) {
            this.activities = result.data.map(act => {
                let badgeClass = 'care-activity-bullet care-bullet-navy';
                if (act.type === 'Encounter') {
                    badgeClass = 'care-activity-bullet care-bullet-teal';
                } else if (act.type === 'Alert') {
                    badgeClass = 'care-activity-bullet care-bullet-red';
                }
                return {
                    ...act,
                    badgeClass
                };
            });
            this.checkLoading();
        } else if (result.error) {
            this.showError('Error loading activities', result.error);
            this.checkLoading();
        }
    }

    get hasActiveAlerts() {
        return this.metrics && this.metrics.activeClinicalAlerts > 0;
    }

    get hasActivities() {
        return this.activities && this.activities.length > 0;
    }

    checkLoading() {
        if (this.wiredMetricsResult && this.wiredWardsResult && this.wiredActivitiesResult) {
            this.isLoading = false;
        }
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            await Promise.all([
                refreshApex(this.wiredMetricsResult),
                refreshApex(this.wiredWardsResult),
                refreshApex(this.wiredActivitiesResult)
            ]);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Refreshed',
                    message: 'Hospital operations dashboard data refreshed',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.showError('Error refreshing dashboard', error);
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
