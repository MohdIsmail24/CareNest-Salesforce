/**
 * Local Automated Verification Script for careNestDashboardV2
 * Tests component markup, script logic, CSS responsiveness,
 * data models, error handling, and server dependencies.
 */
const fs = require('fs');
const path = require('path');

const lwcDir = path.join(__dirname, '..', 'force-app', 'main', 'default', 'lwc', 'careNestDashboardV2');
const htmlFile = path.join(lwcDir, 'careNestDashboardV2.html');
const jsFile = path.join(lwcDir, 'careNestDashboardV2.js');
const cssFile = path.join(lwcDir, 'careNestDashboardV2.css');
const metaFile = path.join(lwcDir, 'careNestDashboardV2.js-meta.xml');

console.log('=================================================================');
console.log(' CARENEST PHASE 33: HOSPITAL ADMIN COMMAND CENTER LOCAL TEST SUITE');
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

// 1. Component File Structure
assert(fs.existsSync(htmlFile), 'HTML file exists');
assert(fs.existsSync(jsFile), 'JavaScript file exists');
assert(fs.existsSync(cssFile), 'CSS file exists');
assert(fs.existsSync(metaFile), 'Component metadata XML exists');

const html = fs.readFileSync(htmlFile, 'utf8');
const js = fs.readFileSync(jsFile, 'utf8');
const css = fs.readFileSync(cssFile, 'utf8');
const meta = fs.readFileSync(metaFile, 'utf8');

// 2. Metadata Targets
assert(meta.includes('<isExposed>true</isExposed>'), 'Component is exposed in metadata');
assert(meta.includes('<target>lightning__AppPage</target>'), 'Targets lightning__AppPage');
assert(meta.includes('<target>lightning__HomePage</target>'), 'Targets lightning__HomePage');

// 3. Photographic Hero Banner & Assets
assert(js.includes('CARENEST_HERO_IMG'), 'Imports CARENEST_HERO_IMG');
assert(js.includes('@salesforce/resourceUrl/careNestHeroMedicalSuite'), 'References careNestHeroMedicalSuite static resource');
assert(html.includes('care-hero-banner'), 'HTML contains care-hero-banner container');
assert(html.includes('care-hero-pill-teal'), 'HTML contains operational status badges');

// 4. Executive KPI Telemetry (12 Metrics from CareNestDashboardController & UI)
const kpis = [
    'metrics.activeAdmissions',
    'metrics.totalBeds',
    'metrics.occupiedBeds',
    'metrics.availableBeds',
    'metrics.totalDoctors',
    'metrics.activeClinicalAlerts',
    'metrics.todayAppointments',
    'metrics.overallOccupancyRate',
    'metrics.totalBilled',
    'metrics.totalPaid',
    'collectionRate',
    'hasActiveAlerts'
];
kpis.forEach(kpi => {
    assert(html.includes(kpi) || js.includes(kpi), `KPI metric handler '${kpi}' defined`);
});

// 5. 12 Operational Modules Navigation
const modules = [
    'overview',
    'patients',
    'doctors',
    'appointments',
    'admissions',
    'wards',
    'clinical',
    'billing',
    'reports',
    'assistant',
    'automation',
    'system'
];
modules.forEach(mod => {
    assert(js.includes(`id: '${mod}'`) || html.includes(`data-id="${mod}"`) || js.includes(`'${mod}'`), `Operational module '${mod}' supported`);
});

// 6. Child LWC Integration
const childLWCs = [
    'c-patient-admission-workspace',
    'c-doctor-search',
    'c-appointment-wizard',
    'c-ward-bed-manager',
    'c-inpatient-clinical-workspace',
    'c-patient-billing',
    'c-agentforce-assistant-widget'
];
childLWCs.forEach(comp => {
    assert(html.includes(comp), `Embeds or launches child LWC '${comp}'`);
});

// 7. Loading, Error, and Access-Denied Handling
assert(html.includes('care-spinner') || html.includes('isLoading'), 'Includes loading indicator state');
assert(js.includes('Error loading metrics') || js.includes('error'), 'Handles error states');
assert(js.includes('refreshApex'), 'Supports refreshApex for live data updates');

// 8. Responsive Design & CSS Breakpoints
assert(css.includes('@media (max-width: 1024px)'), 'Contains Tablet responsive breakpoint (@media max-width: 1024px)');
assert(css.includes('@media (max-width: 768px)'), 'Contains Mobile responsive breakpoint (@media max-width: 768px)');
assert(css.includes('rgba(15, 23, 42') || css.includes('#0a2540') || css.includes('#0f172a'), 'Deep navy theme color tokens defined in CSS');
assert(css.includes('#0d9488') || css.includes('#14b8a6'), 'Teal medical brand accents defined in CSS');

// 9. Server-Side Apex Dependencies Resolution
const apexDependencies = [
    'getDashboardMetrics',
    'getWardSummaries',
    'getRecentActivities'
];
apexDependencies.forEach(dep => {
    assert(js.includes(dep), `Wires server-side controller method '${dep}'`);
});

console.log('\n=================================================================');
console.log(` SUMMARY: ${passedTests} / ${totalTests} tests passed (${failedTests} failures).`);
console.log('=================================================================\n');

if (failedTests > 0) {
    process.exit(1);
} else {
    process.exit(0);
}
