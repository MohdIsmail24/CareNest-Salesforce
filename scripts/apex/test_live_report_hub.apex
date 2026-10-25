List<CareNestDashboardController.ReportLinkDto> listRep = CareNestDashboardController.getReportsHubReports();
System.debug('=== LIVE REPORTS HUB DISCOVERY AUDIT ===');
System.debug('TOTAL_REPORTS_COUNT=' + listRep.size());
Integer finCount = 0;
Integer opsCount = 0;
Integer clinCount = 0;
Integer addCount = 0;
for (CareNestDashboardController.ReportLinkDto r : listRep) {
    if (r.categoryKey == 'financial') finCount++;
    else if (r.categoryKey == 'operations') opsCount++;
    else if (r.categoryKey == 'clinical') clinCount++;
    else if (r.categoryKey == 'additional') addCount++;
    System.debug('LIVE_REP: ' + r.categoryKey + ' | ' + r.developerName + ' | ' + r.id + ' | ' + r.url + ' | isFin=' + r.isFinancial);
}
System.debug('COUNTS: Financial=' + finCount + ', Operations=' + opsCount + ', Clinical=' + clinCount + ', Additional=' + addCount);
System.debug('=== AUDIT COMPLETE ===');
