/**
 * @description Controller for the CareNest Hospital Operations Dashboard and Executive Admin Overview.
 * Exposes authorized aggregate metrics, bed summaries, recent activity timeline,
 * executive financial analytics, revenue charts, and operational KPIs.
 * Enforces WITH USER_MODE, strict server-side admin authorization, and Stage 2 zero-trust security.
 */
public with sharing class CareNestDashboardController {

    @TestVisible private static Boolean mockIsAdmin = null;

    // =========================================================================
    // DTO DEFINITIONS
    // =========================================================================

    public class DashboardMetricsDto {
        @AuraEnabled public Integer totalDoctors { get; set; }
        @AuraEnabled public Integer todayAppointments { get; set; }
        @AuraEnabled public Integer upcomingAppointments { get; set; }
        @AuraEnabled public Integer activeAdmissions { get; set; }
        @AuraEnabled public Integer pendingDischarges { get; set; }
        @AuraEnabled public Integer totalBeds { get; set; }
        @AuraEnabled public Integer occupiedBeds { get; set; }
        @AuraEnabled public Integer availableBeds { get; set; }
        @AuraEnabled public Integer activeClinicalAlerts { get; set; }
        @AuraEnabled public Decimal totalBilled { get; set; }
        @AuraEnabled public Decimal totalPaid { get; set; }
        @AuraEnabled public Decimal totalOutstanding { get; set; }
        @AuraEnabled public Decimal overallOccupancyRate { get; set; }
    }

    public class WardSummaryDto {
        @AuraEnabled public Id wardId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String wardCode { get; set; }
        @AuraEnabled public String wardType { get; set; }
        @AuraEnabled public String floor { get; set; }
        @AuraEnabled public Integer capacity { get; set; }
        @AuraEnabled public Integer totalBeds { get; set; }
        @AuraEnabled public Integer occupiedBeds { get; set; }
        @AuraEnabled public Integer availableBeds { get; set; }
        @AuraEnabled public Decimal occupancyRate { get; set; }
    }

    public class ActivityItemDto {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String type { get; set; } // 'Admission', 'Appointment', 'Clinical', 'Alert'
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String subtitle { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Datetime timestamp { get; set; }
        @AuraEnabled public String badgeClass { get; set; }
    }

    public class AdminAnalyticsDto {
        @AuraEnabled public FinancialKpiDto kpi { get; set; }
        @AuraEnabled public FinancialChartsDto charts { get; set; }
        @AuraEnabled public OperationalAnalyticsDto operations { get; set; }
        @AuraEnabled public List<TransactionItemDto> recentTransactions { get; set; }
        @AuraEnabled public List<ReportLinkDto> reportLinks { get; set; }
        @AuraEnabled public Boolean hasAdminAccess { get; set; }
        @AuraEnabled public Boolean isDemoData { get; set; }
        @AuraEnabled public String currencySymbol { get; set; }
        @AuraEnabled public Datetime generatedAt { get; set; }
    }

    public class FinancialKpiDto {
        @AuraEnabled public Decimal todayCollections { get; set; }
        @AuraEnabled public Decimal yesterdayCollections { get; set; }
        @AuraEnabled public Decimal thisMonthCollections { get; set; }
        @AuraEnabled public Decimal lastMonthCollections { get; set; }
        @AuraEnabled public Decimal ytdCollections { get; set; }
        @AuraEnabled public Decimal totalInvoiced { get; set; }
        @AuraEnabled public Decimal totalCollections { get; set; }
        @AuraEnabled public Decimal netCollections { get; set; }
        @AuraEnabled public Decimal totalRefunds { get; set; }
        @AuraEnabled public Decimal outstandingReceivables { get; set; }
        @AuraEnabled public Decimal overdueReceivables { get; set; }
        @AuraEnabled public Decimal collectionRate { get; set; }
        @AuraEnabled public Decimal avgRevenuePerPatient { get; set; }
        @AuraEnabled public Decimal avgInvoiceValue { get; set; }
        @AuraEnabled public Decimal momGrowth { get; set; }
        @AuraEnabled public Decimal inpatientChargesPotential { get; set; }
    }

    public class FinancialChartsDto {
        @AuraEnabled public List<ChartDataPointDto> monthlyRevenueTrend { get; set; }
        @AuraEnabled public List<ChartDataPointDto> dailyCollections { get; set; }
        @AuraEnabled public InvoicedVsCollectedDto invoicedVsCollected { get; set; }
        @AuraEnabled public List<CategorySliceDto> revenueByDepartment { get; set; }
        @AuraEnabled public List<CategorySliceDto> revenueByPaymentMethod { get; set; }
        @AuraEnabled public List<AgingBracketDto> receivablesAging { get; set; }
        @AuraEnabled public List<DoctorRevenueDto> doctorRevenue { get; set; }
    }

    public class OperationalAnalyticsDto {
        @AuraEnabled public Integer totalAppointments { get; set; }
        @AuraEnabled public Integer dailyAppointments { get; set; }
        @AuraEnabled public Integer weeklyAppointments { get; set; }
        @AuraEnabled public Integer monthlyAppointments { get; set; }
        @AuraEnabled public Integer confirmedAppointments { get; set; }
        @AuraEnabled public Integer cancelledAppointments { get; set; }
        @AuraEnabled public Integer completedAppointments { get; set; }
        @AuraEnabled public Integer pendingAppointments { get; set; }
        @AuraEnabled public Integer newPatientsCount { get; set; }
        @AuraEnabled public Integer activeAdmissions { get; set; }
        @AuraEnabled public Integer dischargedCount { get; set; }
        @AuraEnabled public Integer totalBeds { get; set; }
        @AuraEnabled public Integer occupiedBeds { get; set; }
        @AuraEnabled public Integer availableBeds { get; set; }
        @AuraEnabled public Integer cleaningBeds { get; set; }
        @AuraEnabled public Integer maintenanceBeds { get; set; }
        @AuraEnabled public Decimal wardOccupancyRate { get; set; }
        @AuraEnabled public Integer totalAlerts { get; set; }
        @AuraEnabled public Integer newAlerts { get; set; }
        @AuraEnabled public Integer acknowledgedAlerts { get; set; }
        @AuraEnabled public Integer resolvedAlerts { get; set; }
        @AuraEnabled public Integer pendingReviews { get; set; }
        @AuraEnabled public List<DoctorUtilizationDto> doctorUtilization { get; set; }
    }

    public class ChartDataPointDto {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public Decimal value { get; set; }
        @AuraEnabled public Decimal secondaryValue { get; set; }
        @AuraEnabled public Integer count { get; set; }
    }

    public class InvoicedVsCollectedDto {
        @AuraEnabled public Decimal invoiced { get; set; }
        @AuraEnabled public Decimal collected { get; set; }
        @AuraEnabled public Decimal outstanding { get; set; }
        @AuraEnabled public Decimal refunded { get; set; }
    }

    public class CategorySliceDto {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public Decimal percentage { get; set; }
        @AuraEnabled public Integer count { get; set; }
        @AuraEnabled public String color { get; set; }
    }

    public class AgingBracketDto {
        @AuraEnabled public String bracket { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public Integer count { get; set; }
        @AuraEnabled public String status { get; set; }
    }

    public class DoctorRevenueDto {
        @AuraEnabled public Id doctorId { get; set; }
        @AuraEnabled public String doctorName { get; set; }
        @AuraEnabled public String department { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public Integer paymentCount { get; set; }
        @AuraEnabled public Decimal avgTicket { get; set; }
    }

    public class DoctorUtilizationDto {
        @AuraEnabled public Id doctorId { get; set; }
        @AuraEnabled public String doctorName { get; set; }
        @AuraEnabled public String department { get; set; }
        @AuraEnabled public Integer totalSlots { get; set; }
        @AuraEnabled public Integer bookedSlots { get; set; }
        @AuraEnabled public Decimal utilizationRate { get; set; }
    }

    public class TransactionItemDto {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String transactionCode { get; set; }
        @AuraEnabled public String appointmentCode { get; set; }
        @AuraEnabled public String patientName { get; set; }
        @AuraEnabled public String doctorName { get; set; }
        @AuraEnabled public String department { get; set; }
        @AuraEnabled public String method { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Datetime paidOn { get; set; }
        @AuraEnabled public String formattedPaidOn { get; set; }
    }

    public class ReportLinkDto {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String developerName { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public String categoryKey { get; set; }
        @AuraEnabled public String url { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String iconName { get; set; }
        @AuraEnabled public String badgeClass { get; set; }
        @AuraEnabled public Boolean isFinancial { get; set; }
    }

    public class FilterCriteria {
        public String period;
        public Date startDate;
        public Date endDate;
        public String department;
        public Id doctorId;
    }

    // =========================================================================
    // SECURITY HELPER
    // =========================================================================

    /**
     * @description Enforces strict server-side admin check for financial data access.
     */
    public static Boolean isUserAuthorizedAdmin(Id userId) {
        if (Test.isRunningTest() && mockIsAdmin != null) {
            return mockIsAdmin;
        }
        if (userId == null) {
            return false;
        }

        // 1. Check PermissionSetAssignment for CareNest_Admin (Ops Manager not automatically granted financial telemetry)
        List<PermissionSetAssignment> assignments = [
            SELECT PermissionSet.Name 
            FROM PermissionSetAssignment 
            WHERE AssigneeId = :userId 
              AND PermissionSet.Name = 'CareNest_Admin'
            LIMIT 1
        ];
        if (!assignments.isEmpty()) {
            return true;
        }

        // 2. Check System Administrator profile or Modify All Data / View All Data
        List<User> users = [
            SELECT Profile.Name, Profile.PermissionsModifyAllData, Profile.PermissionsViewAllData
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];
        if (!users.isEmpty() && (
            users[0].Profile.Name == 'System Administrator' || 
            users[0].Profile.PermissionsModifyAllData == true ||
            users[0].Profile.PermissionsViewAllData == true
        )) {
            return true;
        }

        return false;
    }

    // =========================================================================
    // EXISTING DASHBOARD METRICS METHODS (PRESERVED 100%)
    // =========================================================================

    @AuraEnabled(cacheable=true)
    public static DashboardMetricsDto getDashboardMetrics() {
        DashboardMetricsDto dto = new DashboardMetricsDto();
        dto.totalDoctors = 0;
        dto.todayAppointments = 0;
        dto.upcomingAppointments = 0;
        dto.activeAdmissions = 0;
        dto.pendingDischarges = 0;
        dto.totalBeds = 0;
        dto.occupiedBeds = 0;
        dto.availableBeds = 0;
        dto.activeClinicalAlerts = 0;
        dto.totalBilled = 0.0;
        dto.totalPaid = 0.0;
        dto.totalOutstanding = 0.0;
        dto.overallOccupancyRate = 0.0;

        try {
            // Doctors
            dto.totalDoctors = [SELECT count() FROM Doctor__c WHERE Is_Active__c = true WITH USER_MODE];

            // Appointments (CareNest Only)
            dto.todayAppointments = [
                SELECT count() 
                FROM Appointment__c 
                WHERE Slot__r.Slot_Start__c = TODAY 
                  AND Status__c NOT IN ('Cancelled', 'Expired') 
                  AND Patient__r.Patient_Code__c LIKE 'CN-%'
                WITH USER_MODE
            ];
            dto.upcomingAppointments = [
                SELECT count() 
                FROM Appointment__c 
                WHERE Slot__r.Slot_Start__c >= TODAY 
                  AND Status__c IN ('Booked', 'Confirmed') 
                  AND Patient__r.Patient_Code__c LIKE 'CN-%'
                WITH USER_MODE
            ];

            // Inpatient Admissions (CareNest Only)
            dto.activeAdmissions = [
                SELECT count() 
                FROM Admission__c 
                WHERE Status__c = 'Admitted' 
                  AND Patient__r.Patient_Code__c LIKE 'CN-%'
                WITH USER_MODE
            ];

            // Beds & Wards aggregation (CareNest Only)
            List<AggregateResult> bedStats = [
                SELECT Status__c st, count(Id) cnt 
                FROM Bed__c 
                WHERE Ward__r.Ward_Code__c LIKE 'CN-%'
                WITH USER_MODE 
                GROUP BY Status__c
            ];
            for (AggregateResult ar : bedStats) {
                String st = (String) ar.get('st');
                Integer cnt = (Integer) ar.get('cnt');
                dto.totalBeds += cnt;
                if (st == 'Occupied') {
                    dto.occupiedBeds += cnt;
                } else if (st == 'Available') {
                    dto.availableBeds += cnt;
                }
            }
            if (dto.totalBeds > 0) {
                dto.overallOccupancyRate = ((Decimal) dto.occupiedBeds / (Decimal) dto.totalBeds * 100).setScale(1);
            }

            // Clinical Alerts (Excludes Resolved alerts, CareNest Only)
            dto.activeClinicalAlerts = [
                SELECT count() 
                FROM Patient_Vital__c 
                WHERE Alert_Flag__c = true 
                  AND (Alert_Status__c = null OR Alert_Status__c != 'Resolved')
                  AND Admission__r.Patient__r.Patient_Code__c LIKE 'CN-%'
                WITH USER_MODE
            ];

            // Billing Summary from Payment__c (CareNest Only)
            List<AggregateResult> payStats = [
                SELECT sum(Amount__c) totalAmt, Status__c st 
                FROM Payment__c 
                WHERE Appointment__r.Patient__r.Patient_Code__c LIKE 'CN-%'
                WITH USER_MODE 
                GROUP BY Status__c
            ];
            for (AggregateResult ar : payStats) {
                Decimal amt = (Decimal) ar.get('totalAmt');
                String st = (String) ar.get('st');
                if (amt != null) {
                    if (st == 'Completed' || st == 'Success' || st == 'Verified') {
                        dto.totalPaid += amt;
                    }
                    dto.totalBilled += amt;
                }
            }
            dto.totalOutstanding = (dto.totalBilled - dto.totalPaid) > 0 ? (dto.totalBilled - dto.totalPaid) : 0.0;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CareNestDashboardController.getDashboardMetrics error: ' + e.getMessage());
        }

        return dto;
    }

    @AuraEnabled(cacheable=true)
    public static List<WardSummaryDto> getWardSummaries() {
        List<WardSummaryDto> results = new List<WardSummaryDto>();
        try {
            List<Ward__c> wards = [
                SELECT Id, Name, Ward_Code__c, Ward_Type__c, Floor__c, Capacity__c,
                       (SELECT Id, Status__c FROM Beds__r)
                FROM Ward__c
                WHERE Ward_Code__c LIKE 'CN-%'
                WITH USER_MODE
                ORDER BY Name ASC
            ];

            for (Ward__c w : wards) {
                WardSummaryDto dto = new WardSummaryDto();
                dto.wardId = w.Id;
                dto.name = w.Name;
                dto.wardCode = w.Ward_Code__c;
                dto.wardType = w.Ward_Type__c;
                dto.floor = String.isNotBlank(w.Floor__c) ? w.Floor__c : '1';
                dto.capacity = w.Capacity__c != null ? Integer.valueOf(w.Capacity__c) : 0;
                dto.totalBeds = w.Beds__r != null ? w.Beds__r.size() : 0;
                dto.occupiedBeds = 0;
                dto.availableBeds = 0;

                if (w.Beds__r != null) {
                    for (Bed__c b : w.Beds__r) {
                        if (b.Status__c == 'Occupied') {
                            dto.occupiedBeds++;
                        } else if (b.Status__c == 'Available') {
                            dto.availableBeds++;
                        }
                    }
                }

                dto.occupancyRate = (dto.totalBeds > 0)
                    ? ((Decimal) dto.occupiedBeds / (Decimal) dto.totalBeds * 100).setScale(1)
                    : 0.0;

                results.add(dto);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CareNestDashboardController.getWardSummaries error: ' + e.getMessage());
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<ActivityItemDto> getRecentActivities() {
        List<ActivityItemDto> activities = new List<ActivityItemDto>();
        try {
            // Recent admissions
            List<Admission__c> recentAdmissions = [
                SELECT Id, Name, Admission_Date__c, Status__c,
                       Patient__r.Name, Contact__r.Name,
                       Attending_Doctor__r.Name, Doctor__r.Name,
                       Bed__r.Name, Bed__r.Bed_Code__c
                FROM Admission__c
                WHERE Patient__r.Patient_Code__c LIKE 'CN-%'
                WITH USER_MODE
                ORDER BY Admission_Date__c DESC NULLS LAST
                LIMIT 5
            ];
            for (Admission__c adm : recentAdmissions) {
                ActivityItemDto item = new ActivityItemDto();
                item.id = adm.Id;
                item.type = 'Admission';
                String pName = adm.Contact__c != null ? adm.Contact__r.Name : (adm.Patient__c != null ? adm.Patient__r.Name : 'Patient');
                String bedCode = adm.Bed__r != null ? (adm.Bed__r.Bed_Code__c != null ? adm.Bed__r.Bed_Code__c : adm.Bed__r.Name) : 'Unassigned';
                item.title = 'Inpatient Admission: ' + pName;
                item.subtitle = 'Bed ' + bedCode + ' • Status: ' + adm.Status__c;
                item.status = adm.Status__c;
                item.timestamp = adm.Admission_Date__c;
                item.badgeClass = adm.Status__c == 'Admitted' ? 'slds-theme_success' : 'slds-theme_shade';
                activities.add(item);
            }

            // Recent clinical alerts (Excludes Resolved alerts)
            List<Patient_Vital__c> recentAlerts = [
                SELECT Id, Name, Recorded_Date__c, Recorded_At__c, Alert_Flag__c, Alert_Status__c,
                       Admission__r.Contact__r.Name, Admission__r.Patient__r.Name,
                       Pulse__c, Pulse_BPM__c,
                       Systolic_BP__c, Diastolic_BP__c
                FROM Patient_Vital__c
                WHERE Alert_Flag__c = true
                  AND (Alert_Status__c = null OR Alert_Status__c != 'Resolved')
                  AND Admission__r.Patient__r.Patient_Code__c LIKE 'CN-%'
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT 3
            ];
            for (Patient_Vital__c vit : recentAlerts) {
                ActivityItemDto item = new ActivityItemDto();
                item.id = vit.Id;
                item.type = 'Alert';
                String pName = vit.Admission__r != null 
                    ? (vit.Admission__r.Contact__c != null ? vit.Admission__r.Contact__r.Name : (vit.Admission__r.Patient__c != null ? vit.Admission__r.Patient__r.Name : 'Patient'))
                    : 'Inpatient';
                item.title = 'Clinical Alert: ' + pName;
                item.subtitle = 'BP ' + vit.Systolic_BP__c + '/' + vit.Diastolic_BP__c + ' mmHg • Pulse ' + (vit.Pulse__c != null ? vit.Pulse__c : vit.Pulse_BPM__c) + ' bpm';
                item.status = 'Abnormal Vital';
                item.timestamp = vit.Recorded_Date__c != null ? vit.Recorded_Date__c : vit.Recorded_At__c;
                item.badgeClass = 'slds-theme_error';
                activities.add(item);
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CareNestDashboardController.getRecentActivities error: ' + e.getMessage());
        }
        return activities;
    }

    // =========================================================================
    // NEW: COMPLETE EXECUTIVE ADMIN OVERVIEW & REVENUE ANALYTICS
    // =========================================================================

    /**
     * @description Core endpoint for executive financial and operational analytics.
     * Enforces administrator privilege verification and user-mode queries.
     */
    @AuraEnabled(cacheable=true)
    public static AdminAnalyticsDto getAdminOverviewAnalytics(String filterJson) {
        // 1. Strict Server-side Admin Authorization
        if (!isUserAuthorizedAdmin(UserInfo.getUserId())) {
            throw new AuraHandledException('ACCESS_DENIED: Executive Hospital Financial Analytics require CareNest Administrator privileges.');
        }

        AdminAnalyticsDto dto = new AdminAnalyticsDto();
        dto.hasAdminAccess = true;
        dto.isDemoData = false;
        dto.currencySymbol = '₹';
        dto.generatedAt = System.now();

        // Parse Filter Criteria
        FilterCriteria criteria = new FilterCriteria();
        if (String.isNotBlank(filterJson)) {
            try {
                criteria = (FilterCriteria) JSON.deserialize(filterJson, FilterCriteria.class);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Filter criteria parsing failed, defaulting: ' + e.getMessage());
            }
        }

        // Initialize sub-DTOs
        dto.kpi = new FinancialKpiDto();
        dto.charts = new FinancialChartsDto();
        dto.operations = new OperationalAnalyticsDto();
        dto.recentTransactions = new List<TransactionItemDto>();
        dto.reportLinks = new List<ReportLinkDto>();

        // Default zero values for KPIs
        dto.kpi.todayCollections = 0.0;
        dto.kpi.yesterdayCollections = 0.0;
        dto.kpi.thisMonthCollections = 0.0;
        dto.kpi.lastMonthCollections = 0.0;
        dto.kpi.ytdCollections = 0.0;
        dto.kpi.totalInvoiced = 0.0;
        dto.kpi.totalCollections = 0.0;
        dto.kpi.netCollections = 0.0;
        dto.kpi.totalRefunds = 0.0;
        dto.kpi.outstandingReceivables = 0.0;
        dto.kpi.overdueReceivables = 0.0;
        dto.kpi.collectionRate = 0.0;
        dto.kpi.avgRevenuePerPatient = 0.0;
        dto.kpi.avgInvoiceValue = 0.0;
        dto.kpi.momGrowth = 0.0;
        dto.kpi.inpatientChargesPotential = 0.0;

        try {
            Date today = Date.today();
            Date startOfThisMonth = today.toStartOfMonth();
            Date startOfLastMonth = startOfThisMonth.addMonths(-1);
            Date endOfLastMonth = startOfThisMonth.addDays(-1);
            Integer currentYear = today.year();

            // -------------------------------------------------------------
            // A. EXECUTIVE FINANCIAL KPIS (ACTUAL SALESFORCE AGGREGATES)
            // -------------------------------------------------------------

            // All successful payments (CareNest Only: verified patient codes)
            List<Payment__c> successfulPayments = [
                SELECT Id, Name, Amount__c, Method__c, Status__c, Paid_On__c,
                       Appointment__c, Appointment__r.Name, Appointment__r.Patient__c,
                       Appointment__r.Patient__r.Name,
                       Appointment__r.Slot__r.Doctor__c,
                       Appointment__r.Slot__r.Doctor__r.Name,
                       Appointment__r.Slot__r.Doctor__r.Department__c
                FROM Payment__c
                WHERE Status__c = 'Success'
                  AND Appointment__r.Patient__r.Patient_Code__c LIKE 'CN-%'
                WITH USER_MODE
                ORDER BY Paid_On__c DESC NULLS LAST
            ];

            Set<Id> distinctPatientsBilled = new Set<Id>();

            for (Payment__c p : successfulPayments) {
                Decimal amt = p.Amount__c != null ? p.Amount__c : 0.0;
                dto.kpi.totalCollections += amt;

                if (p.Appointment__r != null && p.Appointment__r.Patient__c != null) {
                    distinctPatientsBilled.add(p.Appointment__r.Patient__c);
                }

                if (p.Paid_On__c != null) {
                    Date pDate = p.Paid_On__c.date();
                    if (pDate == today) {
                        dto.kpi.todayCollections += amt;
                    }
                    if (pDate == today.addDays(-1)) {
                        dto.kpi.yesterdayCollections += amt;
                    }
                    if (pDate >= startOfThisMonth && pDate <= today) {
                        dto.kpi.thisMonthCollections += amt;
                    }
                    if (pDate >= startOfLastMonth && pDate <= endOfLastMonth) {
                        dto.kpi.lastMonthCollections += amt;
                    }
                    if (p.Paid_On__c.year() == currentYear) {
                        dto.kpi.ytdCollections += amt;
                    }
                }
            }

            // Cancellations and Refunds (CareNest Only)
            for (Cancellation__c c : [
                SELECT Id, Refund_Amount__c, Cancellation_Fee__c
                FROM Cancellation__c
                WHERE Appointment__r.Patient__r.Patient_Code__c LIKE 'CN-%'
                WITH USER_MODE
            ]) {
                if (c.Refund_Amount__c != null) {
                    dto.kpi.totalRefunds += c.Refund_Amount__c;
                }
            }

            // Net Collections = Total Collections - Refunds
            dto.kpi.netCollections = dto.kpi.totalCollections - dto.kpi.totalRefunds;
            if (dto.kpi.netCollections < 0) {
                dto.kpi.netCollections = 0.0;
            }

            // Month-over-Month Growth
            if (dto.kpi.lastMonthCollections > 0) {
                dto.kpi.momGrowth = (((dto.kpi.thisMonthCollections - dto.kpi.lastMonthCollections) / dto.kpi.lastMonthCollections) * 100).setScale(1);
            } else if (dto.kpi.thisMonthCollections > 0) {
                dto.kpi.momGrowth = 100.0;
            }

            // Appointments & Invoicing Aggregates (CareNest Only)
            List<Appointment__c> allAppointments = [
                SELECT Id, Name, Status__c, Total_Amount__c, Amount_Paid__c, Balance_Due__c,
                       CreatedDate, Slot__r.Slot_Start__c, Patient__c,
                       Slot__r.Doctor__c, Slot__r.Doctor__r.Name, Slot__r.Doctor__r.Department__c
                FROM Appointment__c
                WHERE Patient__r.Patient_Code__c LIKE 'CN-%'
                WITH USER_MODE
            ];

            Integer totalAppointmentCount = allAppointments.size();
            for (Appointment__c appt : allAppointments) {
                if (appt.Total_Amount__c != null) {
                    dto.kpi.totalInvoiced += appt.Total_Amount__c;
                }
                if (appt.Status__c != 'Cancelled' && appt.Balance_Due__c != null && appt.Balance_Due__c > 0) {
                    dto.kpi.outstandingReceivables += appt.Balance_Due__c;

                    Date apptDate = appt.Slot__r != null && appt.Slot__r.Slot_Start__c != null
                        ? appt.Slot__r.Slot_Start__c.date()
                        : appt.CreatedDate.date();

                    if (apptDate < today) {
                        dto.kpi.overdueReceivables += appt.Balance_Due__c;
                    }
                }
            }

            // Collection Rate
            if (dto.kpi.totalInvoiced > 0) {
                dto.kpi.collectionRate = ((dto.kpi.totalCollections / dto.kpi.totalInvoiced) * 100).setScale(1);
            }

            // Average Revenue per Patient
            if (!distinctPatientsBilled.isEmpty()) {
                dto.kpi.avgRevenuePerPatient = (dto.kpi.totalCollections / distinctPatientsBilled.size()).setScale(2);
            }

            // Average Invoice Value
            if (totalAppointmentCount > 0) {
                dto.kpi.avgInvoiceValue = (dto.kpi.totalInvoiced / totalAppointmentCount).setScale(2);
            }

            // Inpatient Charges Potential (CareNest Only)
            for (AggregateResult ar : [
                SELECT sum(Total_Bed_Charge__c) totalBedCharge 
                FROM Admission__c 
                WHERE Patient__r.Patient_Code__c LIKE 'CN-%'
                WITH USER_MODE
            ]) {
                Decimal charge = (Decimal) ar.get('totalBedCharge');
                dto.kpi.inpatientChargesPotential = charge != null ? charge : 0.0;
            }

            // -------------------------------------------------------------
            // B. INTERACTIVE FINANCIAL CHARTS
            // -------------------------------------------------------------

            // Graph 1: Monthly Revenue Trend (Last 12 Months)
            dto.charts.monthlyRevenueTrend = buildMonthlyRevenueTrend();

            // Graph 2: Daily Collections (Last 30 Days)
            dto.charts.dailyCollections = buildDailyCollections();

            // Graph 3: Invoiced vs Collected
            InvoicedVsCollectedDto ivc = new InvoicedVsCollectedDto();
            ivc.invoiced = dto.kpi.totalInvoiced;
            ivc.collected = dto.kpi.totalCollections;
            ivc.outstanding = dto.kpi.outstandingReceivables;
            ivc.refunded = dto.kpi.totalRefunds;
            dto.charts.invoicedVsCollected = ivc;

            // Graph 4: Revenue by Department / Service
            dto.charts.revenueByDepartment = buildDepartmentRevenue(dto.kpi.totalCollections);

            // Graph 5: Payment Methods Breakdown
            dto.charts.revenueByPaymentMethod = buildPaymentMethods(dto.kpi.totalCollections);

            // Graph 6: Receivables Aging
            dto.charts.receivablesAging = buildReceivablesAging(allAppointments, today);

            // Graph 7: Doctor / Specialty Revenue
            dto.charts.doctorRevenue = buildDoctorRevenue();

            // -------------------------------------------------------------
            // C. HOSPITAL OPERATIONS ANALYTICS
            // -------------------------------------------------------------
            dto.operations = buildOperationalAnalytics(allAppointments, today);

            // -------------------------------------------------------------
            // D. RECENT FINANCIAL TRANSACTIONS
            // -------------------------------------------------------------
            dto.recentTransactions = buildRecentTransactions(successfulPayments, 25);

            // -------------------------------------------------------------
            // E. SALESFORCE REPORT LINKS
            // -------------------------------------------------------------
            dto.reportLinks = buildReportLinks();

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CareNestDashboardController.getAdminOverviewAnalytics error: ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Error generating CareNest Admin Analytics: ' + e.getMessage());
        }

        return dto;
    }

    // =========================================================================
    // CHART BUILDERS & ANALYTICS HELPERS
    // =========================================================================

    private static List<ChartDataPointDto> buildMonthlyRevenueTrend() {
        List<ChartDataPointDto> points = new List<ChartDataPointDto>();
        Map<String, Decimal> monthCollectionsMap = new Map<String, Decimal>();
        Map<String, Integer> monthCountMap = new Map<String, Integer>();

        for (AggregateResult ar : [
            SELECT CALENDAR_YEAR(Paid_On__c) yr, CALENDAR_MONTH(Paid_On__c) mo, sum(Amount__c) sm, count(Id) cnt
            FROM Payment__c
            WHERE Status__c = 'Success'
              AND Appointment__r.Patient__r.Patient_Code__c LIKE 'CN-%'
            WITH USER_MODE
            GROUP BY CALENDAR_YEAR(Paid_On__c), CALENDAR_MONTH(Paid_On__c)
            ORDER BY CALENDAR_YEAR(Paid_On__c) ASC, CALENDAR_MONTH(Paid_On__c) ASC
        ]) {
            Integer y = (Integer) ar.get('yr');
            Integer m = (Integer) ar.get('mo');
            Decimal sm = (Decimal) ar.get('sm');
            Integer cnt = (Integer) ar.get('cnt');
            String key = y + '-' + (m < 10 ? '0' + m : String.valueOf(m));
            monthCollectionsMap.put(key, sm != null ? sm : 0.0);
            monthCountMap.put(key, cnt != null ? cnt : 0);
        }

        // Build last 6-12 months display timeline
        Date d = Date.today().toStartOfMonth().addMonths(-5);
        for (Integer i = 0; i < 6; i++) {
            Integer yr = d.year();
            Integer mo = d.month();
            String key = yr + '-' + (mo < 10 ? '0' + mo : String.valueOf(mo));
            String label = getMonthShortName(mo) + ' ' + yr;

            ChartDataPointDto pt = new ChartDataPointDto();
            pt.label = label;
            pt.value = monthCollectionsMap.containsKey(key) ? monthCollectionsMap.get(key) : 0.0;
            pt.count = monthCountMap.containsKey(key) ? monthCountMap.get(key) : 0;
            points.add(pt);

            d = d.addMonths(1);
        }

        return points;
    }

    private static List<ChartDataPointDto> buildDailyCollections() {
        List<ChartDataPointDto> points = new List<ChartDataPointDto>();
        Map<Date, Decimal> dailyMap = new Map<Date, Decimal>();
        Map<Date, Integer> countMap = new Map<Date, Integer>();

        Date cutoff = Date.today().addDays(-29);
        for (AggregateResult ar : [
            SELECT DAY_ONLY(Paid_On__c) dy, sum(Amount__c) sm, count(Id) cnt
            FROM Payment__c
            WHERE Status__c = 'Success' 
              AND Paid_On__c >= :cutoff
              AND Appointment__r.Patient__r.Patient_Code__c LIKE 'CN-%'
            WITH USER_MODE
            GROUP BY DAY_ONLY(Paid_On__c)
            ORDER BY DAY_ONLY(Paid_On__c) ASC
        ]) {
            Date dt = (Date) ar.get('dy');
            Decimal sm = (Decimal) ar.get('sm');
            Integer cnt = (Integer) ar.get('cnt');
            if (dt != null) {
                dailyMap.put(dt, sm != null ? sm : 0.0);
                countMap.put(dt, cnt != null ? cnt : 0);
            }
        }

        // Build 30-day timeline
        Date cursor = cutoff;
        Date today = Date.today();
        while (cursor <= today) {
            ChartDataPointDto pt = new ChartDataPointDto();
            pt.label = getMonthShortName(cursor.month()) + ' ' + cursor.day();
            pt.value = dailyMap.containsKey(cursor) ? dailyMap.get(cursor) : 0.0;
            pt.count = countMap.containsKey(cursor) ? countMap.get(cursor) : 0;
            points.add(pt);
            cursor = cursor.addDays(1);
        }

        return points;
    }

    private static List<CategorySliceDto> buildDepartmentRevenue(Decimal totalCollections) {
        List<CategorySliceDto> slices = new List<CategorySliceDto>();
        Map<String, String> colors = new Map<String, String>{
            'Orthopaedics' => '#0d9488', // Teal
            'Dermatology' => '#0284c7',  // Sky Blue
            'ENT' => '#6366f1',          // Indigo
            'General Medicine' => '#10b981', // Emerald
            'Paediatrics' => '#f59e0b',  // Amber
            'Cardiology' => '#ef4444',   // Rose
            'Neurology' => '#8b5cf6',    // Violet
            'Other' => '#64748b'         // Slate
        };

        for (AggregateResult ar : [
            SELECT Appointment__r.Slot__r.Doctor__r.Department__c dept, sum(Amount__c) sm, count(Id) cnt
            FROM Payment__c
            WHERE Status__c = 'Success'
              AND Appointment__r.Patient__r.Patient_Code__c LIKE 'CN-%'
            WITH USER_MODE
            GROUP BY Appointment__r.Slot__r.Doctor__r.Department__c
            ORDER BY sum(Amount__c) DESC
        ]) {
            String dept = (String) ar.get('dept');
            if (String.isBlank(dept)) dept = 'General Services';
            Decimal amt = (Decimal) ar.get('sm');
            Integer cnt = (Integer) ar.get('cnt');

            CategorySliceDto slice = new CategorySliceDto();
            slice.label = dept;
            slice.amount = amt != null ? amt : 0.0;
            slice.count = cnt != null ? cnt : 0;
            slice.percentage = (totalCollections > 0) ? ((slice.amount / totalCollections) * 100).setScale(1) : 0.0;
            slice.color = colors.containsKey(dept) ? colors.get(dept) : colors.get('Other');
            slices.add(slice);
        }

        return slices;
    }

    private static List<CategorySliceDto> buildPaymentMethods(Decimal totalCollections) {
        List<CategorySliceDto> slices = new List<CategorySliceDto>();
        Map<String, String> colors = new Map<String, String>{
            'UPI' => '#0d9488',   // Teal
            'Card' => '#3b82f6',  // Blue
            'Cash' => '#10b981',  // Green
            'Bank' => '#f59e0b',  // Amber
            'Other' => '#64748b'  // Slate
        };

        for (AggregateResult ar : [
            SELECT Method__c m, sum(Amount__c) sm, count(Id) cnt
            FROM Payment__c
            WHERE Status__c = 'Success'
              AND Appointment__r.Patient__r.Patient_Code__c LIKE 'CN-%'
            WITH USER_MODE
            GROUP BY Method__c
            ORDER BY sum(Amount__c) DESC
        ]) {
            String method = (String) ar.get('m');
            if (String.isBlank(method)) method = 'Direct Desk Settlement';
            Decimal amt = (Decimal) ar.get('sm');
            Integer cnt = (Integer) ar.get('cnt');

            CategorySliceDto slice = new CategorySliceDto();
            slice.label = method;
            slice.amount = amt != null ? amt : 0.0;
            slice.count = cnt != null ? cnt : 0;
            slice.percentage = (totalCollections > 0) ? ((slice.amount / totalCollections) * 100).setScale(1) : 0.0;
            slice.color = colors.containsKey(method) ? colors.get(method) : colors.get('Other');
            slices.add(slice);
        }

        return slices;
    }

    private static List<AgingBracketDto> buildReceivablesAging(List<Appointment__c> appts, Date today) {
        Map<String, AgingBracketDto> brackets = new Map<String, AgingBracketDto>{
            'Current' => new AgingBracketDto(),
            '1-30 Days (Post-Service)' => new AgingBracketDto(),
            '31-60 Days (Post-Service)' => new AgingBracketDto(),
            '61-90 Days (Post-Service)' => new AgingBracketDto(),
            'Over 90 Days (Post-Service)' => new AgingBracketDto()
        };

        for (String k : brackets.keySet()) {
            brackets.get(k).bracket = k;
            brackets.get(k).amount = 0.0;
            brackets.get(k).count = 0;
            brackets.get(k).status = k == 'Current' ? 'Current' : 'Post-Service';
        }

        for (Appointment__c appt : appts) {
            if (appt.Status__c != 'Cancelled' && appt.Balance_Due__c != null && appt.Balance_Due__c > 0) {
                Date d = appt.Slot__r != null && appt.Slot__r.Slot_Start__c != null
                    ? appt.Slot__r.Slot_Start__c.date()
                    : appt.CreatedDate.date();

                Integer daysPast = d.daysBetween(today);
                String targetKey = 'Current';

                if (daysPast <= 0) {
                    targetKey = 'Current';
                } else if (daysPast <= 30) {
                    targetKey = '1-30 Days (Post-Service)';
                } else if (daysPast <= 60) {
                    targetKey = '31-60 Days (Post-Service)';
                } else if (daysPast <= 90) {
                    targetKey = '61-90 Days (Post-Service)';
                } else {
                    targetKey = 'Over 90 Days (Post-Service)';
                }

                AgingBracketDto target = brackets.get(targetKey);
                target.amount += appt.Balance_Due__c;
                target.count++;
            }
        }

        return new List<AgingBracketDto>{
            brackets.get('Current'),
            brackets.get('1-30 Days (Post-Service)'),
            brackets.get('31-60 Days (Post-Service)'),
            brackets.get('61-90 Days (Post-Service)'),
            brackets.get('Over 90 Days (Post-Service)')
        };
    }

    private static List<DoctorRevenueDto> buildDoctorRevenue() {
        List<DoctorRevenueDto> listDto = new List<DoctorRevenueDto>();

        for (AggregateResult ar : [
            SELECT Appointment__r.Slot__r.Doctor__c docId,
                   Appointment__r.Slot__r.Doctor__r.Name docName,
                   Appointment__r.Slot__r.Doctor__r.Department__c dept,
                   sum(Amount__c) sm, count(Id) cnt
            FROM Payment__c
            WHERE Status__c = 'Success'
              AND Appointment__r.Patient__r.Patient_Code__c LIKE 'CN-%'
            WITH USER_MODE
            GROUP BY Appointment__r.Slot__r.Doctor__c,
                     Appointment__r.Slot__r.Doctor__r.Name,
                     Appointment__r.Slot__r.Doctor__r.Department__c
            ORDER BY sum(Amount__c) DESC
        ]) {
            DoctorRevenueDto dr = new DoctorRevenueDto();
            dr.doctorId = (Id) ar.get('docId');
            dr.doctorName = (String) ar.get('docName');
            dr.department = (String) ar.get('dept');
            dr.amount = (Decimal) ar.get('sm');
            dr.paymentCount = (Integer) ar.get('cnt');
            dr.avgTicket = (dr.paymentCount > 0 && dr.amount != null)
                ? (dr.amount / dr.paymentCount).setScale(2)
                : 0.0;
            listDto.add(dr);
        }

        return listDto;
    }

    private static OperationalAnalyticsDto buildOperationalAnalytics(List<Appointment__c> allAppointments, Date today) {
        OperationalAnalyticsDto op = new OperationalAnalyticsDto();
        op.totalAppointments = allAppointments.size();
        op.dailyAppointments = 0;
        op.weeklyAppointments = 0;
        op.monthlyAppointments = 0;
        op.confirmedAppointments = 0;
        op.cancelledAppointments = 0;
        op.completedAppointments = 0;
        op.pendingAppointments = 0;

        Date weekAgo = today.addDays(-7);
        Date startOfMonth = today.toStartOfMonth();

        for (Appointment__c a : allAppointments) {
            Date apptDate = a.Slot__r != null && a.Slot__r.Slot_Start__c != null
                ? a.Slot__r.Slot_Start__c.date()
                : a.CreatedDate.date();

            if (apptDate == today) op.dailyAppointments++;
            if (apptDate >= weekAgo) op.weeklyAppointments++;
            if (apptDate >= startOfMonth) op.monthlyAppointments++;

            if (a.Status__c == 'Confirmed' || a.Status__c == 'Booked') op.confirmedAppointments++;
            else if (a.Status__c == 'Cancelled') op.cancelledAppointments++;
            else if (a.Status__c == 'Completed') op.completedAppointments++;
            else if (a.Status__c == 'Pending') op.pendingAppointments++;
        }

        // New Patients Count (CareNest Only: verified patient codes)
        op.newPatientsCount = [SELECT count() FROM Contact WHERE Patient_Code__c LIKE 'CN-%' WITH USER_MODE];

        // Inpatient Admissions & Discharges (CareNest Only)
        op.activeAdmissions = [SELECT count() FROM Admission__c WHERE Status__c = 'Admitted' AND Patient__r.Patient_Code__c LIKE 'CN-%' WITH USER_MODE];
        op.dischargedCount = [SELECT count() FROM Admission__c WHERE Status__c = 'Discharged' AND Patient__r.Patient_Code__c LIKE 'CN-%' WITH USER_MODE];

        // Bed Telemetry (CareNest Only)
        op.totalBeds = 0;
        op.occupiedBeds = 0;
        op.availableBeds = 0;
        op.cleaningBeds = 0;
        op.maintenanceBeds = 0;

        for (AggregateResult ar : [
            SELECT Status__c st, count(Id) cnt
            FROM Bed__c
            WHERE Ward__r.Ward_Code__c LIKE 'CN-%'
            WITH USER_MODE
            GROUP BY Status__c
        ]) {
            String st = (String) ar.get('st');
            Integer cnt = (Integer) ar.get('cnt');
            op.totalBeds += cnt;
            if (st == 'Occupied') op.occupiedBeds += cnt;
            else if (st == 'Available') op.availableBeds += cnt;
            else if (st == 'Cleaning') op.cleaningBeds += cnt;
            else if (st == 'Maintenance') op.maintenanceBeds += cnt;
        }

        op.wardOccupancyRate = (op.totalBeds > 0)
            ? ((Decimal) op.occupiedBeds / (Decimal) op.totalBeds * 100).setScale(1)
            : 0.0;

        // Clinical Alerts Telemetry (CareNest Only)
        op.totalAlerts = 0;
        op.newAlerts = 0;
        op.acknowledgedAlerts = 0;
        op.resolvedAlerts = 0;
        op.pendingReviews = 0;

        for (AggregateResult ar : [
            SELECT Alert_Status__c st, count(Id) cnt
            FROM Patient_Vital__c
            WHERE Alert_Flag__c = true
              AND Admission__r.Patient__r.Patient_Code__c LIKE 'CN-%'
            WITH USER_MODE
            GROUP BY Alert_Status__c
        ]) {
            String st = (String) ar.get('st');
            Integer cnt = (Integer) ar.get('cnt');
            op.totalAlerts += cnt;

            if (st == null || st == 'New') {
                op.newAlerts += cnt;
                op.pendingReviews += cnt;
            } else if (st == 'Acknowledged' || st == 'Under Review') {
                op.acknowledgedAlerts += cnt;
                op.pendingReviews += cnt;
            } else if (st == 'Resolved') {
                op.resolvedAlerts += cnt;
            }
        }

        // Doctor Utilization
        op.doctorUtilization = new List<DoctorUtilizationDto>();
        for (AggregateResult ar : [
            SELECT Doctor__c docId, Doctor__r.Name docName, Doctor__r.Department__c dept,
                   sum(Total_Capacity__c) totalCap, sum(Booked_Count__c) totalBooked
            FROM Appointment_Slot__c
            WITH USER_MODE
            GROUP BY Doctor__c, Doctor__r.Name, Doctor__r.Department__c
            ORDER BY Doctor__r.Name ASC
            LIMIT 12
        ]) {
            DoctorUtilizationDto u = new DoctorUtilizationDto();
            u.doctorId = (Id) ar.get('docId');
            u.doctorName = (String) ar.get('docName');
            u.department = (String) ar.get('dept');
            Decimal cap = (Decimal) ar.get('totalCap');
            Decimal bkd = (Decimal) ar.get('totalBooked');
            u.totalSlots = cap != null ? Integer.valueOf(cap) : 0;
            u.bookedSlots = bkd != null ? Integer.valueOf(bkd) : 0;
            u.utilizationRate = (u.totalSlots > 0)
                ? ((Decimal) u.bookedSlots / (Decimal) u.totalSlots * 100).setScale(1)
                : 0.0;
            op.doctorUtilization.add(u);
        }

        return op;
    }

    private static List<TransactionItemDto> buildRecentTransactions(List<Payment__c> payments, Integer limitCount) {
        List<TransactionItemDto> items = new List<TransactionItemDto>();
        Integer cnt = 0;

        for (Payment__c p : payments) {
            if (cnt >= limitCount) break;
            TransactionItemDto it = new TransactionItemDto();
            it.id = p.Id;
            it.transactionCode = p.Name;
            it.appointmentCode = (p.Appointment__r != null) ? p.Appointment__r.Name : '-';
            it.patientName = (p.Appointment__r != null && p.Appointment__r.Patient__r != null) ? p.Appointment__r.Patient__r.Name : 'Patient';
            it.doctorName = (p.Appointment__r != null && p.Appointment__r.Slot__r != null && p.Appointment__r.Slot__r.Doctor__r != null)
                ? p.Appointment__r.Slot__r.Doctor__r.Name : 'Hospital Desk';
            it.department = (p.Appointment__r != null && p.Appointment__r.Slot__r != null && p.Appointment__r.Slot__r.Doctor__r != null)
                ? p.Appointment__r.Slot__r.Doctor__r.Department__c : 'Outpatient';
            it.method = String.isNotBlank(p.Method__c) ? p.Method__c : 'Cash Desk';
            it.amount = p.Amount__c != null ? p.Amount__c : 0.0;
            it.status = p.Status__c;
            it.paidOn = p.Paid_On__c;
            it.formattedPaidOn = p.Paid_On__c != null ? p.Paid_On__c.format('dd MMM yyyy, hh:mm a') : '-';
            items.add(it);
            cnt++;
        }

        return items;
    }

    // =========================================================================
    // CARENEST REPORTS HUB & ALLOWLIST REGISTRY
    // =========================================================================

    public static final Set<String> FINANCIAL_REPORT_DEV_NAMES = new Set<String>{
        'CareNest_Daily_Collections_Settlements',
        'CareNest_Department_Specialty_Revenue',
        'CareNest_Doctor_Revenue_Contribution',
        'CareNest_Outstanding_Receivables_Aging'
    };

    public static final Set<String> OPERATIONS_REPORT_DEV_NAMES = new Set<String>{
        'CareNest_Active_Admissions_Census',
        'CareNest_Appointments_Volume_by_Status',
        'CareNest_Inpatient_Bed_Occupancy_Capacity'
    };

    public static final Set<String> CLINICAL_REPORT_DEV_NAMES = new Set<String>{
        'CareNest_Clinical_Alerts_Vitals_Review',
        'CareNest_Doctor_Consultation_Workload',
        'CareNest_Inpatient_Encounters_by_Doctor'
    };

    public static final Set<String> ADDITIONAL_OPERATIONAL_DEV_NAMES = new Set<String>{
        'Available_Bed_Capacity_by_Ward',
        'Current_Admissions_by_Status',
        'Inpatient_Encounters_by_Doctor_Date',
        'Appointment_Volume_by_Date',
        'Appointments_by_Doctor',
        'Patient_Vitals_by_Date'
    };

    @AuraEnabled(cacheable=true)
    public static List<ReportLinkDto> getReportsHubReports() {
        return buildReportLinks();
    }

    public static List<ReportLinkDto> buildReportLinks() {
        List<ReportLinkDto> links = new List<ReportLinkDto>();
        Boolean isAdmin = isUserAuthorizedAdmin(UserInfo.getUserId());

        Set<String> allowedDevNames = new Set<String>();
        // Strict Security: Financial reports are only returned to authorized administrators
        if (isAdmin) {
            allowedDevNames.addAll(FINANCIAL_REPORT_DEV_NAMES);
        }
        allowedDevNames.addAll(OPERATIONS_REPORT_DEV_NAMES);
        allowedDevNames.addAll(CLINICAL_REPORT_DEV_NAMES);
        allowedDevNames.addAll(ADDITIONAL_OPERATIONAL_DEV_NAMES);

        // Strict Allowlist Query - Zero MiniCare reports can ever be queried
        List<Report> reports = [
            SELECT Id, Name, DeveloperName, Description
            FROM Report
            WHERE DeveloperName IN :allowedDevNames
            WITH USER_MODE
            ORDER BY Name ASC
        ];

        Map<String, Report> reportByDevName = new Map<String, Report>();
        for (Report r : reports) {
            reportByDevName.put(r.DeveloperName, r);
        }

        // Maintain prioritized category ordering
        List<String> orderedDevNames = new List<String>();
        if (isAdmin) {
            orderedDevNames.addAll(new List<String>{
                'CareNest_Daily_Collections_Settlements',
                'CareNest_Department_Specialty_Revenue',
                'CareNest_Doctor_Revenue_Contribution',
                'CareNest_Outstanding_Receivables_Aging'
            });
        }
        orderedDevNames.addAll(new List<String>{
            'CareNest_Active_Admissions_Census',
            'CareNest_Appointments_Volume_by_Status',
            'CareNest_Inpatient_Bed_Occupancy_Capacity'
        });
        orderedDevNames.addAll(new List<String>{
            'CareNest_Clinical_Alerts_Vitals_Review',
            'CareNest_Doctor_Consultation_Workload',
            'CareNest_Inpatient_Encounters_by_Doctor'
        });
        orderedDevNames.addAll(new List<String>{
            'Available_Bed_Capacity_by_Ward',
            'Current_Admissions_by_Status',
            'Inpatient_Encounters_by_Doctor_Date',
            'Appointment_Volume_by_Date',
            'Appointments_by_Doctor',
            'Patient_Vitals_by_Date'
        });

        for (String devName : orderedDevNames) {
            if (reportByDevName.containsKey(devName)) {
                Report r = reportByDevName.get(devName);
                ReportLinkDto rl = new ReportLinkDto();
                rl.id = r.Id;
                rl.name = r.Name;
                rl.developerName = r.DeveloperName;
                rl.url = '/lightning/r/Report/' + r.Id + '/view';
                rl.description = String.isNotBlank(r.Description) ? r.Description : getDefaultReportDescription(devName);

                if (FINANCIAL_REPORT_DEV_NAMES.contains(devName)) {
                    rl.category = 'Financial Analytics';
                    rl.categoryKey = 'financial';
                    rl.isFinancial = true;
                    rl.iconName = 'standard:currency';
                    rl.badgeClass = 'care-pill-badge-emerald';
                } else if (OPERATIONS_REPORT_DEV_NAMES.contains(devName)) {
                    rl.category = 'Hospital Operations';
                    rl.categoryKey = 'operations';
                    rl.isFinancial = false;
                    rl.iconName = 'standard:asset_relationship';
                    rl.badgeClass = 'care-pill-badge-teal';
                } else if (CLINICAL_REPORT_DEV_NAMES.contains(devName)) {
                    rl.category = 'Clinical & Physician Analytics';
                    rl.categoryKey = 'clinical';
                    rl.isFinancial = false;
                    rl.iconName = 'standard:stethoscope';
                    rl.badgeClass = 'care-pill-badge-amber';
                } else {
                    rl.category = 'Additional Operational Reports';
                    rl.categoryKey = 'additional';
                    rl.isFinancial = false;
                    rl.iconName = 'standard:report';
                    rl.badgeClass = 'care-pill-badge-navy';
                }
                links.add(rl);
            }
        }

        return links;
    }

    private static String getDefaultReportDescription(String devName) {
        if (devName == 'CareNest_Daily_Collections_Settlements') {
            return 'Daily breakdown of successful CareNest patient settlements, cash desk receipts, and collections.';
        } else if (devName == 'CareNest_Department_Specialty_Revenue') {
            return 'Revenue aggregation across clinical departments, medical specialties, and outpatient services.';
        } else if (devName == 'CareNest_Doctor_Revenue_Contribution') {
            return 'Revenue contributions and collected consultation receipts attributed to doctors and clinical staff.';
        } else if (devName == 'CareNest_Outstanding_Receivables_Aging') {
            return 'Open patient receivables, post-service consultation balances, and uncollected outpatient invoices.';
        } else if (devName == 'CareNest_Active_Admissions_Census') {
            return 'Active inpatient census, bed allocations, attending clinicians, and accrued bed charges.';
        } else if (devName == 'CareNest_Appointments_Volume_by_Status') {
            return 'Total outpatient appointment booking volume, breakdown by confirmation status, and attendance.';
        } else if (devName == 'CareNest_Inpatient_Bed_Occupancy_Capacity') {
            return 'Inpatient bed occupancy and available capacity across CareNest hospital wards.';
        } else if (devName == 'CareNest_Clinical_Alerts_Vitals_Review') {
            return 'Audit of physiological clinical alerts, vital abnormalities, and clinician review status.';
        } else if (devName == 'CareNest_Doctor_Consultation_Workload') {
            return 'Consultation workload and slot utilization across CareNest doctors and departments.';
        } else if (devName == 'CareNest_Inpatient_Encounters_by_Doctor') {
            return 'Daily inpatient clinical rounds and encounters grouped by attending physician.';
        } else if (devName == 'Available_Bed_Capacity_by_Ward') {
            return 'Active ward capacity, current bed count, and real-time available bed count.';
        } else if (devName == 'Current_Admissions_by_Status') {
            return 'Active inpatient admissions currently admitted or pending discharge.';
        } else if (devName == 'Inpatient_Encounters_by_Doctor_Date') {
            return 'Inpatient clinical encounter workload grouped by attending doctor and date.';
        } else if (devName == 'Appointment_Volume_by_Date') {
            return 'Daily volume of outpatient appointment bookings.';
        } else if (devName == 'Appointments_by_Doctor') {
            return 'Booked appointment volume grouped by attending doctor.';
        } else if (devName == 'Patient_Vitals_by_Date') {
            return 'Confidential clinical vitals recorded over time for authorized clinical staff.';
        }
        return 'Standard CareNest verified operational report.';
    }

    private static String getMonthShortName(Integer m) {
        switch on m {
            when 1 { return 'Jan'; }
            when 2 { return 'Feb'; }
            when 3 { return 'Mar'; }
            when 4 { return 'Apr'; }
            when 5 { return 'May'; }
            when 6 { return 'Jun'; }
            when 7 { return 'Jul'; }
            when 8 { return 'Aug'; }
            when 9 { return 'Sep'; }
            when 10 { return 'Oct'; }
            when 11 { return 'Nov'; }
            when 12 { return 'Dec'; }
            when else { return ''; }
        }
    }
}
