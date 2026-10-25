// Test non-admin simulation by querying without admin permission set
User nonAdminUser = [SELECT Id, Name, Profile.Name FROM User WHERE IsActive = true AND Profile.Name != 'System Administrator' LIMIT 1];
System.runAs(nonAdminUser) {
    List<CareNestDashboardController.ReportLinkDto> listRep = CareNestDashboardController.getReportsHubReports();
    System.debug('NON_ADMIN_TOTAL_REPORTS=' + listRep.size());
    Integer finCount = 0;
    for (CareNestDashboardController.ReportLinkDto r : listRep) {
        if (r.isFinancial == true || r.categoryKey == 'financial') finCount++;
    }
    System.debug('NON_ADMIN_FINANCIAL_REPORTS=' + finCount);
    System.assert(finCount == 0, 'Non-admin must receive 0 financial reports!');
}
System.debug('=== NON-ADMIN RBAC TEST PASSED ===');
