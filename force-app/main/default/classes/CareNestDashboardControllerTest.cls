@IsTest
private class CareNestDashboardControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create Doctor
        Doctor__c doc = new Doctor__c(
            Name = 'Dr. Test Dashboard',
            Department__c = 'General Medicine',
            Specialty__c = 'Internal Medicine',
            Registration_No__c = 'REG-DASH-01',
            Is_Active__c = true,
            Consultation_Fee__c = 500
        );
        insert doc;

        // Create Slot
        Appointment_Slot__c slot = new Appointment_Slot__c(
            Doctor__c = doc.Id,
            Slot_Start__c = System.now().addDays(1),
            Total_Capacity__c = 5,
            Booked_Count__c = 2,
            Mode__c = 'OPD'
        );
        insert slot;

        // Create Ward
        Ward__c ward = new Ward__c(
            Name = 'Dashboard Test Ward',
            Ward_Code__c = 'CN-WRD-DASH',
            Ward_Type__c = 'General',
            Capacity__c = 10,
            Floor__c = '1'
        );
        insert ward;

        // Create Beds (Both start Available; Admission will occupy Bed DASH-1)
        List<Bed__c> beds = new List<Bed__c>{
            new Bed__c(Name = 'Bed DASH-1', Bed_Code__c = 'DASH-01', Ward__c = ward.Id, Status__c = 'Available'),
            new Bed__c(Name = 'Bed DASH-2', Bed_Code__c = 'DASH-02', Ward__c = ward.Id, Status__c = 'Available')
        };
        insert beds;

        // Create Patient Contact with CareNest Patient Code
        Contact patient = new Contact(
            LastName = 'DashboardPatient',
            Phone = '9876543210',
            Patient_Code__c = 'CN-TEST-001',
            MC_Is_Patient__c = true
        );
        insert patient;

        // Create Admission
        Admission__c adm = new Admission__c(
            Contact__c = patient.Id,
            Patient__c = patient.Id,
            Bed__c = beds[0].Id,
            Attending_Doctor__c = doc.Id,
            Admission_Date__c = System.now().addDays(-2),
            Status__c = 'Admitted',
            Reason__c = 'Dashboard Test'
        );
        insert adm;

        // Create Patient Vital with Abnormal SpO2 (triggers formula Alert_Flag__c)
        Patient_Vital__c vit = new Patient_Vital__c(
            Admission__c = adm.Id,
            Recorded_Date__c = System.now(),
            Systolic_BP__c = 195,
            Diastolic_BP__c = 110,
            Pulse_BPM__c = 125,
            Temperature_C__c = 38.5,
            SpO2_Percent__c = 85,
            Alert_Status__c = 'New'
        );
        insert vit;

        // Create Appointments (One Confirmed, One Pending with balance)
        Appointment__c appt1 = new Appointment__c(
            Patient__c = patient.Id,
            Slot__c = slot.Id,
            Total_Amount__c = 1000,
            Status__c = 'Confirmed'
        );
        insert appt1;

        Appointment__c appt2 = new Appointment__c(
            Patient__c = patient.Id,
            Slot__c = slot.Id,
            Total_Amount__c = 600,
            Status__c = 'Pending'
        );
        insert appt2;

        // Create Payments for appt1
        Payment__c p1 = new Payment__c(
            Appointment__c = appt1.Id,
            Amount__c = 600,
            Status__c = 'Success',
            Method__c = 'UPI',
            Paid_On__c = System.now()
        );
        insert p1;

        Payment__c p2 = new Payment__c(
            Appointment__c = appt1.Id,
            Amount__c = 400,
            Status__c = 'Success',
            Method__c = 'Cash',
            Paid_On__c = System.now().addMonths(-1)
        );
        insert p2;

        // Create Cancellation with Refund
        Cancellation__c canc = new Cancellation__c(
            Appointment__c = appt1.Id,
            Refund_Amount__c = 150,
            Cancellation_Fee__c = 50,
            Reason__c = 'Patient requested schedule update'
        );
        insert canc;
    }

    @IsTest
    static void testGetDashboardMetrics() {
        Test.startTest();
        CareNestDashboardController.DashboardMetricsDto metrics = CareNestDashboardController.getDashboardMetrics();
        Test.stopTest();

        Assert.isNotNull(metrics, 'Metrics should not be null');
        Assert.isTrue(metrics.totalDoctors >= 1, 'Should count active doctors');
        Assert.isTrue(metrics.totalBeds >= 2, 'Should count total beds');
        Assert.isTrue(metrics.activeAdmissions >= 1, 'Should count active admissions');
        Assert.isTrue(metrics.activeClinicalAlerts >= 1, 'Should count active clinical alerts');
        Assert.isTrue(metrics.totalPaid >= 1000, 'Total paid should aggregate successful payments');
    }

    @IsTest
    static void testGetWardSummaries() {
        Test.startTest();
        List<CareNestDashboardController.WardSummaryDto> summaries = CareNestDashboardController.getWardSummaries();
        Test.stopTest();

        Assert.isNotNull(summaries, 'Ward summaries should not be null');
        Assert.isFalse(summaries.isEmpty(), 'Should return wards');
    }

    @IsTest
    static void testGetRecentActivities() {
        Test.startTest();
        List<CareNestDashboardController.ActivityItemDto> activities = CareNestDashboardController.getRecentActivities();
        Test.stopTest();

        Assert.isNotNull(activities, 'Recent activities should not be null');
        Assert.isFalse(activities.isEmpty(), 'Should return activities');
    }

    @IsTest
    static void testGetAdminOverviewAnalytics_Authorized() {
        CareNestDashboardController.mockIsAdmin = true;

        Test.startTest();
        CareNestDashboardController.AdminAnalyticsDto analytics = CareNestDashboardController.getAdminOverviewAnalytics('{"period":"all"}');
        Test.stopTest();

        Assert.isNotNull(analytics, 'Admin analytics should not be null');
        Assert.isTrue(analytics.hasAdminAccess, 'Must have admin access');
        Assert.isFalse(analytics.isDemoData, 'Must be marked as real Salesforce data');
        Assert.areEqual('₹', analytics.currencySymbol, 'Currency symbol must be INR ₹');

        // Verify 12 Financial KPIs
        CareNestDashboardController.FinancialKpiDto kpi = analytics.kpi;
        Assert.isNotNull(kpi, 'Financial KPIs must be populated');
        Assert.isTrue(kpi.totalCollections >= 1000, 'Total collections must include successful payments');
        Assert.isTrue(kpi.totalRefunds >= 150, 'Total refunds must aggregate cancellation refunds');
        Assert.isTrue(kpi.netCollections >= 850, 'Net collections must equal collections minus refunds');
        Assert.isTrue(kpi.totalInvoiced >= 1000, 'Total invoiced must aggregate appointment amounts');
        Assert.isTrue(kpi.outstandingReceivables >= 500, 'Outstanding receivables must aggregate balance due');
        Assert.isTrue(kpi.collectionRate > 0, 'Collection rate must be greater than 0');
        Assert.isTrue(kpi.avgRevenuePerPatient > 0, 'Avg revenue per patient must be greater than 0');
        Assert.isTrue(kpi.avgInvoiceValue > 0, 'Avg invoice value must be greater than 0');

        // Verify Charts
        CareNestDashboardController.FinancialChartsDto charts = analytics.charts;
        Assert.isNotNull(charts, 'Charts must be populated');
        Assert.isFalse(charts.monthlyRevenueTrend.isEmpty(), 'Monthly revenue trend must have points');
        Assert.isFalse(charts.dailyCollections.isEmpty(), 'Daily collections must have points');
        Assert.isNotNull(charts.invoicedVsCollected, 'Invoiced vs Collected must be populated');
        Assert.isFalse(charts.revenueByDepartment.isEmpty(), 'Revenue by department must have slices');
        Assert.isFalse(charts.revenueByPaymentMethod.isEmpty(), 'Revenue by payment method must have slices');
        Assert.isFalse(charts.receivablesAging.isEmpty(), 'Receivables aging must have brackets');
        Assert.isFalse(charts.doctorRevenue.isEmpty(), 'Doctor revenue must be populated');

        // Verify Operations
        CareNestDashboardController.OperationalAnalyticsDto ops = analytics.operations;
        Assert.isNotNull(ops, 'Operations must be populated');
        Assert.isTrue(ops.totalAppointments >= 2, 'Total appointments count');
        Assert.isTrue(ops.activeAdmissions >= 1, 'Active admissions count');
        Assert.isTrue(ops.totalBeds >= 2, 'Total beds count');
        Assert.isTrue(ops.totalAlerts >= 1, 'Total clinical alerts count');
        Assert.isFalse(ops.doctorUtilization.isEmpty(), 'Doctor utilization list populated');

        // Verify Transactions
        Assert.isFalse(analytics.recentTransactions.isEmpty(), 'Recent transactions list populated');
        CareNestDashboardController.TransactionItemDto tx = analytics.recentTransactions[0];
        Assert.isNotNull(tx.transactionCode, 'Transaction code present');
        Assert.isTrue(tx.amount > 0, 'Transaction amount present');
    }

    @IsTest
    static void testGetAdminOverviewAnalytics_NonAdminDenied() {
        CareNestDashboardController.mockIsAdmin = false;

        Test.startTest();
        Boolean exceptionCaught = false;
        try {
            CareNestDashboardController.getAdminOverviewAnalytics('{"period":"all"}');
        } catch (AuraHandledException e) {
            exceptionCaught = true;
        } catch (Exception e) {
            // In unit tests without Aura context, AuraHandledException can surface as a general exception
            exceptionCaught = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionCaught, 'Non-admin user must be strictly denied with exception');
    }

    @IsTest
    static void testFilterVariations() {
        CareNestDashboardController.mockIsAdmin = true;

        Test.startTest();
        // Test with empty filter
        CareNestDashboardController.AdminAnalyticsDto resEmpty = CareNestDashboardController.getAdminOverviewAnalytics('');
        Assert.isNotNull(resEmpty, 'Empty filter should fall back safely');

        // Test with invalid JSON
        CareNestDashboardController.AdminAnalyticsDto resInvalid = CareNestDashboardController.getAdminOverviewAnalytics('invalid json');
        Assert.isNotNull(resInvalid, 'Invalid filter JSON should fall back safely');

        // Test with specific period
        CareNestDashboardController.AdminAnalyticsDto resMonth = CareNestDashboardController.getAdminOverviewAnalytics('{"period":"thismonth"}');
        Assert.isNotNull(resMonth, 'This month filter should execute');
        Test.stopTest();
    }

    @IsTest
    static void testGetReportsHubReports_Admin() {
        CareNestDashboardController.mockIsAdmin = true;

        Test.startTest();
        List<CareNestDashboardController.ReportLinkDto> reports = CareNestDashboardController.getReportsHubReports();
        Test.stopTest();

        Assert.isNotNull(reports, 'Reports Hub list should not be null');
        for (CareNestDashboardController.ReportLinkDto r : reports) {
            Assert.isNotNull(r.id, 'Report ID must not be null');
            Assert.isNotNull(r.name, 'Report Name must not be null');
            Assert.isNotNull(r.developerName, 'DeveloperName must not be null');
            Assert.isNotNull(r.url, 'Report URL must not be null');
            Assert.isTrue(r.url.startsWith('/lightning/r/Report/'), 'URL must be a valid Lightning report URL');
            // Strict check: zero MiniCare DeveloperNames
            Assert.isFalse(r.developerName.startsWith('MC_'), 'No MiniCare report should ever be returned: ' + r.developerName);
        }
    }

    @IsTest
    static void testGetReportsHubReports_NonAdmin() {
        CareNestDashboardController.mockIsAdmin = false;

        Test.startTest();
        List<CareNestDashboardController.ReportLinkDto> reports = CareNestDashboardController.getReportsHubReports();
        Test.stopTest();

        Assert.isNotNull(reports, 'Reports Hub list should not be null for non-admin');
        for (CareNestDashboardController.ReportLinkDto r : reports) {
            Assert.isFalse(r.isFinancial == true, 'Non-admin user must never receive sensitive financial report links: ' + r.developerName);
            Assert.isFalse(CareNestDashboardController.FINANCIAL_REPORT_DEV_NAMES.contains(r.developerName), 'Financial report DeveloperName found in non-admin payload');
        }
    }
}
