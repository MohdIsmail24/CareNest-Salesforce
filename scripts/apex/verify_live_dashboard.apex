CareNestDashboardController.AdminAnalyticsDto data = CareNestDashboardController.getAdminOverviewAnalytics(null);
System.debug('=== CARENEST DASHBOARD LIVE FINANCIAL & OPERATIONAL AUDIT ===');
System.debug('Has Admin Access: ' + data.hasAdminAccess);
System.debug('Recorded Successful Collections: ' + data.kpi.totalCollections);
System.debug('Collections Less Refund Obligations: ' + data.kpi.netCollections);
System.debug('Refund Entitlements: ' + data.kpi.totalRefunds);
System.debug('Post-Service Open Balances: ' + data.kpi.overdueReceivables);
System.debug('Outstanding Receivables: ' + data.kpi.outstandingReceivables);
System.debug('Accrued Inpatient Bed Charges: ' + data.kpi.inpatientChargesPotential);
System.debug('Collection Rate: ' + data.kpi.collectionRate);
System.debug('New Patients Count: ' + data.operations.newPatientsCount);
System.debug('Total Appointments: ' + data.operations.totalAppointments);
System.debug('Active Admissions: ' + data.operations.activeAdmissions);
System.debug('Total Beds: ' + data.operations.totalBeds);
System.debug('Occupied Beds: ' + data.operations.occupiedBeds);
System.debug('Available Beds: ' + data.operations.availableBeds);
System.debug('Ward Occupancy Rate: ' + data.operations.wardOccupancyRate);
System.debug('Total Alerts: ' + data.operations.totalAlerts);
System.debug('New Alerts: ' + data.operations.newAlerts);
System.debug('Acknowledged Alerts: ' + data.operations.acknowledgedAlerts);
System.debug('Resolved Alerts: ' + data.operations.resolvedAlerts);
System.debug('Pending Reviews: ' + data.operations.pendingReviews);
System.debug('Report Links Count: ' + (data.reportLinks != null ? data.reportLinks.size() : 0));
if (data.reportLinks != null) {
    for (CareNestDashboardController.ReportLinkDto rl : data.reportLinks) {
        System.debug('Report Link: ' + rl.name + ' (' + rl.developerName + ') -> ' + rl.url);
    }
}
