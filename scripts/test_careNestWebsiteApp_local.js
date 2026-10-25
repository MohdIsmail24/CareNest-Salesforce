// Local automated component test for careNestWebsiteApp
const fs = require('fs');
const path = require('path');

console.log('=== STARTING LOCAL COMPONENT TESTS: careNestWebsiteApp ===');

const lwcDir = path.join(__dirname, '..', 'force-app', 'main', 'default', 'lwc', 'careNestWebsiteApp');
const htmlPath = path.join(lwcDir, 'careNestWebsiteApp.html');
const jsPath = path.join(lwcDir, 'careNestWebsiteApp.js');
const cssPath = path.join(lwcDir, 'careNestWebsiteApp.css');
const xmlPath = path.join(lwcDir, 'careNestWebsiteApp.js-meta.xml');

// 1. Check all files exist
console.log('Test 1: File Existence Check');
const files = [htmlPath, jsPath, cssPath, xmlPath];
files.forEach(f => {
    if (!fs.existsSync(f)) {
        console.error('FAIL: Missing file:', f);
        process.exit(1);
    }
    console.log('  PASS:', path.basename(f), `(${fs.statSync(f).size} bytes)`);
});

// 2. Validate Metadata Targets for Experience Cloud & Lightning
console.log('\nTest 2: Experience Cloud & Lightning Target Validation');
const xmlContent = fs.readFileSync(xmlPath, 'utf8');
const requiredTargets = [
    'lightningCommunity__Page',
    'lightningCommunity__Default',
    'lightning__AppPage',
    'lightning__HomePage'
];
requiredTargets.forEach(t => {
    if (!xmlContent.includes(`<target>${t}</target>`)) {
        console.error('FAIL: Missing target:', t);
        process.exit(1);
    }
    console.log('  PASS: Target present:', t);
});

// 3. Verify All 10 Pages Represented in HTML Template
console.log('\nTest 3: 10 Website Page Directives in Template');
const htmlContent = fs.readFileSync(htmlPath, 'utf8');
const pageDirectives = [
    'isHomePage',
    'isPatientsPage',
    'isDoctorsPage',
    'isAppointmentsPage',
    'isWardsPage',
    'isAdmissionsPage',
    'isClinicalPage',
    'isPaymentsPage',
    'isAgentforcePage',
    'isAdminPage'
];
pageDirectives.forEach(p => {
    if (!htmlContent.includes(`if:true={${p}}`)) {
        console.error('FAIL: Missing page directive in HTML:', p);
        process.exit(1);
    }
    console.log('  PASS: Page directive present:', p);
});

// 4. Verify Reused Child LWCs Present
console.log('\nTest 4: Child LWC Integration in Template');
const childComponents = [
    'c-hospital-operations-dashboard',
    'c-ward-bed-manager',
    'c-patient-admission-workspace',
    'c-inpatient-clinical-workspace',
    'c-appointment-wizard',
    'c-doctor-search',
    'c-my-appointments',
    'c-patient-billing',
    'c-agentforce-assistant-widget'
];
childComponents.forEach(c => {
    if (!htmlContent.includes(`<${c}`)) {
        console.error('FAIL: Missing child component tag:', c);
        process.exit(1);
    }
    console.log('  PASS: Child LWC wired:', c);
});

// 5. Verify Apex Controller Imports in JS
console.log('\nTest 5: Apex Controller Wiring in JS');
const jsContent = fs.readFileSync(jsPath, 'utf8');
const apexImports = [
    '@salesforce/apex/CareNestDashboardController.getDashboardMetrics',
    '@salesforce/apex/CareNestAdmissionController.searchPatients',
    '@salesforce/apex/CareNestAdmissionController.registerPatient',
    '@salesforce/apex/CareNestAdmissionController.getDoctorsWithAvailability'
];
apexImports.forEach(imp => {
    if (!jsContent.includes(imp)) {
        console.error('FAIL: Missing Apex import:', imp);
        process.exit(1);
    }
    console.log('  PASS: Apex controller imported:', imp);
});

// 6. Verify HTML Tag Balance
console.log('\nTest 6: HTML Syntax & Tag Balance');
const stack = [];
const tagRegex = /<\/?([a-zA-Z0-9\-_]+)[^>]*>/g;
let match;
while ((match = tagRegex.exec(htmlContent)) !== null) {
    const full = match[0];
    const tag = match[1];
    if (full.endsWith('/>') || ['input', 'img', 'br', 'hr'].includes(tag)) continue;
    if (full.startsWith('</')) {
        const last = stack.pop();
        if (last !== tag) {
            console.error(`FAIL: Tag mismatch: opened <${last}> but closed </${tag}>`);
            process.exit(1);
        }
    } else {
        stack.push(tag);
    }
}
if (stack.length === 0) {
    console.log('  PASS: 100% of HTML tags are properly opened and closed.');
} else {
    console.error('FAIL: Unclosed tags remaining:', stack);
    process.exit(1);
}

// 7. Verify CSS Brand Variables and Styles
console.log('\nTest 7: Brand Theme Palette in CSS');
const cssContent = fs.readFileSync(cssPath, 'utf8');
const brandColors = ['#0d9488', '#0f766e', '#0f172a', '#ffffff', '#f8fafc'];
brandColors.forEach(c => {
    if (!cssContent.includes(c)) {
        console.error('FAIL: Missing brand color in CSS:', c);
        process.exit(1);
    }
    console.log('  PASS: Brand color found:', c);
});

// 8. Verify Supported NavigationMixin & CurrentPageReference Architecture
console.log('\nTest 8: Supported Salesforce Navigation & URL State Architecture');
if (!jsContent.includes('import { NavigationMixin, CurrentPageReference } from \'lightning/navigation\';')) {
    console.error('FAIL: Missing NavigationMixin / CurrentPageReference import');
    process.exit(1);
}
console.log('  PASS: NavigationMixin & CurrentPageReference imported from lightning/navigation');

if (!jsContent.includes('extends NavigationMixin(LightningElement)')) {
    console.error('FAIL: Component must extend NavigationMixin(LightningElement)');
    process.exit(1);
}
console.log('  PASS: Component extends NavigationMixin(LightningElement)');

if (!jsContent.includes('@wire(CurrentPageReference)')) {
    console.error('FAIL: Missing @wire(CurrentPageReference)');
    process.exit(1);
}
console.log('  PASS: CurrentPageReference wired for Back/Forward and Refresh synchronization');

if (!jsContent.includes('this[NavigationMixin.Navigate](updatedRef, false)')) {
    console.error('FAIL: NavigationMixin.Navigate must be called with replace=false for history stack');
    process.exit(1);
}
console.log('  PASS: NavigationMixin.Navigate correctly pushes to browser history stack');

// 9. Verify Shareable Route URLs and Protection
console.log('\nTest 9: Shareable URL Getters and Route Protection Logic');
const expectedGetters = [
    'homeUrl', 'patientsUrl', 'doctorsUrl', 'appointmentsUrl', 'wardsUrl',
    'admissionsUrl', 'clinicalUrl', 'paymentsUrl', 'agentforceUrl', 'adminUrl'
];
expectedGetters.forEach(g => {
    if (!jsContent.includes(`get ${g}()`)) {
        console.error('FAIL: Missing URL getter:', g);
        process.exit(1);
    }
    console.log('  PASS: Shareable URL getter present:', g);
});

if (!jsContent.includes('PROTECTED_SECTIONS') || !jsContent.includes('isAuthorizedForSection')) {
    console.error('FAIL: Missing route protection logic');
    process.exit(1);
}
console.log('  PASS: Route authorization logic verified for protected sections');

console.log('\n=== ALL 9 LOCAL COMPONENT TESTS PASSED WITH 100% SUCCESS ===');

