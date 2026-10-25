/**
 * Local Automated Verification Script for CareNest Executive Admin Overview & Revenue Analytics
 * Tests financial KPI card definitions, SVG graph generators, filters,
 * operational panels, CSV export, security checks, and responsive layouts.
 */
const fs = require('fs');
const path = require('path');

const lwcDir = path.join(__dirname, '..', 'force-app', 'main', 'default', 'lwc', 'careNestDashboardV2');
const htmlFile = path.join(lwcDir, 'careNestDashboardV2.html');
const jsFile = path.join(lwcDir, 'careNestDashboardV2.js');
const cssFile = path.join(lwcDir, 'careNestDashboardV2.css');
const controllerFile = path.join(__dirname, '..', 'force-app', 'main', 'default', 'classes', 'CareNestDashboardController.cls');

console.log('=================================================================');
console.log(' CARENEST: EXECUTIVE ADMIN OVERVIEW & REVENUE ANALYTICS TESTS');
console.log('=================================================================\n');

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function assert(condition, message) {
    totalTests++;
    if (condition) {
        console.log(`[PASS] ${message}`);
        passedTests++;
    } else {
        console.error(`[FAIL] ${message}`);
        failedTests++;
    }
}

const html = fs.readFileSync(htmlFile, 'utf8');
const js = fs.readFileSync(jsFile, 'utf8');
const css = fs.readFileSync(cssFile, 'utf8');
const controller = fs.readFileSync(controllerFile, 'utf8');

// 1. Controller Server-Side Method & Security
assert(controller.includes('getAdminOverviewAnalytics'), 'Controller defines getAdminOverviewAnalytics method');
assert(controller.includes('isUserAuthorizedAdmin'), 'Controller enforces isUserAuthorizedAdmin server-side check');
assert(controller.includes('ACCESS_DENIED'), 'Controller defines access denial exception message');
assert(controller.includes('WITH USER_MODE'), 'Controller queries enforce WITH USER_MODE');
assert(controller.includes('mockIsAdmin'), 'Controller exposes mockIsAdmin for test isolation');

// 2. 12 Executive Financial KPI Definitions in Controller & UI
const kpis = [
    'todayCollections',
    'yesterdayCollections',
    'thisMonthCollections',
    'lastMonthCollections',
    'ytdCollections',
    'totalInvoiced',
    'outstandingReceivables',
    'overdueReceivables',
    'collectionRate',
    'avgRevenuePerPatient',
    'avgInvoiceValue',
    'momGrowth'
];
kpis.forEach(kpi => {
    assert(controller.includes(kpi), `Controller calculates KPI '${kpi}'`);
    assert(html.includes(`adminKpi.${kpi}`) || js.includes(kpi), `UI binds KPI '${kpi}'`);
});

// 3. Indian Rupee Formatting (₹)
assert(html.includes('₹{adminKpi.todayCollections}'), 'HTML formats Today Collections with INR ₹');
assert(html.includes('₹{adminKpi.thisMonthCollections}'), 'HTML formats Month Collections with INR ₹');
assert(html.includes('₹{adminKpi.ytdCollections}'), 'HTML formats YTD Collections with INR ₹');
assert(controller.includes("currencySymbol = '₹'"), 'Controller provides INR ₹ currency symbol');

// 4. 7 Financial Graphs Inventory
assert(html.includes('Graph 1: Monthly Collections Trend'), 'Includes Graph 1: Monthly Collections Trend (Line & Area)');
assert(html.includes('Graph 2: Daily Collections Trend'), 'Includes Graph 2: Daily Collections Trend (Bars)');
assert(html.includes('Graph 3: Invoiced vs Recorded Successful Collections'), 'Includes Graph 3: Invoiced vs Recorded Successful Collections vs Outstanding');
assert(html.includes('Graph 4: Revenue by Specialty'), 'Includes Graph 4: Revenue by Specialty / Department');
assert(html.includes('Graph 5: Settlement Methods'), 'Includes Graph 5: Payment Settlement Methods');
assert(html.includes('Graph 6: Receivables Aging (By Consultation Date)'), 'Includes Graph 6: Receivables Aging Breakdown (By Consultation Date)');
assert(html.includes('Graph 7: Physician Revenue Leaderboard'), 'Includes Graph 7: Physician Revenue Leaderboard');

// 4b. Accounting Terminology Assertions (Task 1 & Task 2 & Task 3)
assert(html.includes('Recorded Successful Collections'), 'Displays "Recorded Successful Collections"');
assert(html.includes('Collections Less Refund Obligations'), 'Displays "Collections Less Refund Obligations"');
assert(html.includes('Post-Service Open Balances'), 'Displays "Post-Service Open Balances"');
assert(html.includes('Accrued Inpatient Bed Charges'), 'Displays "Accrued Inpatient Bed Charges"');
assert(html.includes('18 active appts (19 total, 1 cancelled ₹600 excluded)'), 'Accurately reconciles 18 active appts with 1 cancelled ₹600 excluded');
assert(html.includes('Historical Abnormal:'), 'Displays Historical Abnormal telemetry count');
assert(html.includes('Unresolved Alerts:'), 'Displays Unresolved Alerts active count');
assert(html.includes('Recorded Resolutions:'), 'Displays Recorded Resolutions count');
assert(js.includes('Refund Entitlements'), 'JS includes "Refund Entitlements" in comparative bars');

// 5. SVG Chart Computations in JS
assert(js.includes('monthlyTrendSvg'), 'JS computes monthly trend SVG path and coordinates');
assert(js.includes('dailyCollectionsBars'), 'JS computes daily collections bar coordinates');
assert(js.includes('invoicedVsCollectedList'), 'JS computes comparative invoiced vs collected bars');
assert(js.includes('departmentRevenueSlices'), 'JS computes department revenue breakdown');
assert(js.includes('paymentMethodSlices'), 'JS computes payment method breakdown');
assert(js.includes('receivablesAgingList'), 'JS computes receivables aging brackets');
assert(js.includes('doctorRevenueRanked'), 'JS computes ranked doctor revenue list');

// 6. Hospital Operations Analytics Panels
assert(html.includes('adminOperations.totalAppointments'), 'Binds OPD Appointment volume telemetry');
assert(html.includes('adminOperations.wardOccupancyRate'), 'Binds Inpatient Bed Utilization rate');
assert(html.includes('adminOperations.totalAlerts'), 'Binds Clinical Alerts Lifecycle telemetry');
assert(html.includes('adminKpi.inpatientChargesPotential'), 'Binds Incurred Bed Charges telemetry');

// 7. Interactive Filter Controls
const periods = ['all', 'today', 'last7days', 'last30days', 'thismonth', 'lastmonth', 'thisquarter', 'thisyear', 'custom'];
periods.forEach(p => {
    assert(html.includes(`data-period="${p}"`), `Supports filter period '${p}'`);
});
assert(html.includes('care-dropdown-select'), 'Includes Department filter dropdown');
assert(html.includes('care-date-picker'), 'Includes Custom date range inputs');

// 8. Recent Financial Transactions & CSV Export
assert(html.includes('care-data-table'), 'Includes Recent Financial Transactions table');
assert(html.includes('handleTransactionSearch'), 'Includes live transaction search filter');
assert(js.includes('handleExportCsv'), 'Implements CSV export handler');
assert(html.includes('care-btn-export-csv'), 'HTML contains Export CSV button');

// 9. Salesforce Report Navigation & Strict Allowlist Registry
assert(controller.includes('getReportsHubReports'), 'Controller exposes getReportsHubReports endpoint');
assert(controller.includes('FINANCIAL_REPORT_DEV_NAMES'), 'Controller defines FINANCIAL_REPORT_DEV_NAMES allowlist');
assert(controller.includes('OPERATIONS_REPORT_DEV_NAMES'), 'Controller defines OPERATIONS_REPORT_DEV_NAMES allowlist');
assert(controller.includes('CLINICAL_REPORT_DEV_NAMES'), 'Controller defines CLINICAL_REPORT_DEV_NAMES allowlist');
assert(controller.includes('ADDITIONAL_OPERATIONAL_DEV_NAMES'), 'Controller defines ADDITIONAL_OPERATIONAL_DEV_NAMES allowlist');
assert(controller.includes("WHERE DeveloperName IN :allowedDevNames"), 'Controller queries exclusively through explicit allowlist');
assert(controller.includes("Patient_Code__c LIKE 'CN-%'"), 'Controller enforces strict CareNest patient code isolation');

// Verify All 10 New CareNest Reports
const tenNewCareNestReports = [
    'CareNest_Active_Admissions_Census',
    'CareNest_Appointments_Volume_by_Status',
    'CareNest_Inpatient_Bed_Occupancy_Capacity',
    'CareNest_Clinical_Alerts_Vitals_Review',
    'CareNest_Daily_Collections_Settlements',
    'CareNest_Department_Specialty_Revenue',
    'CareNest_Doctor_Consultation_Workload',
    'CareNest_Doctor_Revenue_Contribution',
    'CareNest_Inpatient_Encounters_by_Doctor',
    'CareNest_Outstanding_Receivables_Aging'
];
tenNewCareNestReports.forEach(rep => {
    assert(controller.includes(rep), `Controller references New CareNest Report '${rep}'`);
});

// Verify 6 Established CareNest Operational Reports
const sixEstablishedCareNestReports = [
    'Available_Bed_Capacity_by_Ward',
    'Current_Admissions_by_Status',
    'Inpatient_Encounters_by_Doctor_Date',
    'Appointment_Volume_by_Date',
    'Appointments_by_Doctor',
    'Patient_Vitals_by_Date'
];
sixEstablishedCareNestReports.forEach(rep => {
    assert(controller.includes(rep), `Controller references Established CareNest Report '${rep}'`);
});

// Strict Data Isolation: Zero MiniCare report IDs
const forbiddenMiniCareIds = [
    '00Og700000AiDFBEA3',
    '00Og700000AvzH7EAJ',
    '00Og700000Avzx3EAB',
    '00Og700000Avzx4EAB',
    '00Og700000Avzx5EAB',
    '00Og700000AwzlJEAR',
    '00Og700000B0zVMEAZ',
    '00Og700000B0zVNEAZ',
    '00Og700000B0zVOEAZ',
    '00Og700000B0zVPEAZ',
    '00Og700000B0zVQEAZ',
    '00Og700000B0zVREAZ'
];
forbiddenMiniCareIds.forEach(id => {
    assert(!controller.includes(id), `Controller contains no forbidden MiniCare ID '${id}'`);
    assert(!html.includes(id), `HTML contains no forbidden MiniCare ID '${id}'`);
    assert(!js.includes(id), `JS contains no forbidden MiniCare ID '${id}'`);
});

// 10. Professional Reports Hub UI Validation
assert(html.includes('care-reports-hub-grid'), 'HTML defines care-reports-hub-grid');
assert(html.includes('care-report-hub-card'), 'HTML defines care-report-hub-card');
assert(html.includes('care-report-search-input'), 'HTML provides search input for reports');
assert(html.includes('care-reports-filter-pills'), 'HTML provides category filter buttons');
assert(html.includes('care-btn-open-report'), 'HTML provides direct Open Report links');
assert(html.includes('care-reports-empty-state'), 'HTML provides clean empty search state');
assert(js.includes('loadReportsHub'), 'JS implements loadReportsHub loader');
assert(js.includes('filteredReportsList'), 'JS computes filtered and searched reports list');
assert(js.includes('handleReportSearch'), 'JS implements report search handler');
assert(js.includes('handleSelectReportCategory'), 'JS implements category selection handler');

// 11. Responsive CSS Breakpoints
assert(css.includes('.care-admin-kpi-grid'), 'CSS defines care-admin-kpi-grid');
assert(css.includes('.care-admin-charts-grid'), 'CSS defines care-admin-charts-grid (58% / 40%)');
assert(css.includes('.care-reports-hub-grid'), 'CSS defines care-reports-hub-grid');
assert(css.includes('.care-report-hub-card'), 'CSS defines care-report-hub-card');
assert(css.includes('@media (max-width: 1200px)'), 'CSS defines 1200px responsive layout');
assert(css.includes('@media (max-width: 1024px)'), 'CSS defines 1024px tablet reports layout');
assert(css.includes('@media (max-width: 820px)'), 'CSS defines 820px tablet layout');
assert(css.includes('@media (max-width: 640px)'), 'CSS defines 640px mobile reports layout');
assert(css.includes('@media (max-width: 480px)'), 'CSS defines 480px mobile layout');

console.log('\n=================================================================');
console.log(` SUMMARY: ${passedTests} / ${totalTests} tests passed (${failedTests} failures).`);
console.log('=================================================================\n');

if (failedTests > 0) {
    process.exit(1);
} else {
    process.exit(0);
}
