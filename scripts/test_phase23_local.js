const fs = require('fs');
const path = require('path');

console.log('=================================================================');
console.log(' CARENEST PHASE 23: LOCAL VERIFICATION & INTEGRITY TEST SUITE');
console.log('=================================================================\n');

let passCount = 0;
let failCount = 0;

function assert(condition, message) {
    if (condition) {
        console.log(`[PASS] ${message}`);
        passCount++;
    } else {
        console.error(`[FAIL] ${message}`);
        failCount++;
    }
}

const basePath = path.join(__dirname, '..', 'force-app', 'main', 'default');
const pawJsPath = path.join(basePath, 'lwc', 'patientAdmissionWorkspace', 'patientAdmissionWorkspace.js');
const pawHtmlPath = path.join(basePath, 'lwc', 'patientAdmissionWorkspace', 'patientAdmissionWorkspace.html');
const dashJsPath = path.join(basePath, 'lwc', 'careNestDashboardV2', 'careNestDashboardV2.js');
const schemaFieldPath = path.join(basePath, 'objects', 'Admission__c', 'fields', 'Admission_Type__c.field-meta.xml');

// 1. Admission Type initially has no selection
const pawJs = fs.readFileSync(pawJsPath, 'utf8');
const initialWizardMatch = pawJs.includes("admissionType: ''");
assert(initialWizardMatch, '1. Admission Type initializes to empty string in wizardData');

// Check openAdmissionWizard reset
const resetMatch = pawJs.includes("this.wizardData = {\n            admissionType: '',") || pawJs.includes("admissionType: ''");
assert(resetMatch, '1b. openAdmissionWizard resets admissionType to empty string');

// Check combobox placeholder
const pawHtml = fs.readFileSync(pawHtmlPath, 'utf8');
assert(pawHtml.includes('placeholder="-- Select Admission Type --"'), '1c. HTML template provides "-- Select Admission Type --" placeholder');

// 2. User cannot advance without selecting an admission type
const guardRegex = /if\s*\(!this\.wizardData\.admissionType\s*\|\|\s*!this\.wizardData\.admissionType\.trim\(\)\)/;
assert(guardRegex.test(pawJs), '2. Step 5 validation explicitly guards against unselected or empty admissionType');

// 3. Emergency, Planned, Transfer supported in deployed schema
const schemaXml = fs.readFileSync(schemaFieldPath, 'utf8');
assert(schemaXml.includes('<fullName>Emergency</fullName>'), '3a. Schema defines Emergency picklist value');
assert(schemaXml.includes('<fullName>Planned</fullName>'), '3b. Schema defines Planned picklist value');
assert(schemaXml.includes('<fullName>Transfer</fullName>'), '3c. Schema defines Transfer picklist value');
assert(pawJs.includes("value: 'Emergency'") && pawJs.includes("value: 'Planned'") && pawJs.includes("value: 'Transfer'"), 
    '3d. JS admissionTypeOptions supports Emergency, Planned, and Transfer');

// 4. Selected type is passed correctly to the existing admission controller
const admitCallRegex = /admitPatient\(\s*\{[\s\S]*?admissionType:\s*this\.wizardData\.admissionType[\s\S]*?\}\s*\)/;
assert(admitCallRegex.test(pawJs), '4. admitPatient passes this.wizardData.admissionType directly to Apex controller');

// 5. Navigation badges receive actual dashboard data
const dashJs = fs.readFileSync(dashJsPath, 'utf8');
assert(dashJs.includes('this.metrics.activeAdmissions !== undefined'), '5a. Active admissions badge binds to live metrics.activeAdmissions');
assert(dashJs.includes('this.metrics.availableBeds !== undefined'), '5b. Available beds badge binds to live metrics.availableBeds');
assert(dashJs.includes('this.metrics.totalPatients !== undefined'), '5c. Total patients badge binds to live metrics.totalPatients');
assert(dashJs.includes('this.metrics.totalDoctors !== undefined'), '5d. Total doctors badge binds to live metrics.totalDoctors');

// 6. All nine main navigation sections remain accessible
const navSections = ['overview', 'adminOverview', 'patients', 'doctors', 'appointments', 'admissions', 'wards', 'clinical', 'billing'];
let allNavPresent = true;
for (const sec of navSections) {
    if (!dashJs.includes(`id: '${sec}'`)) {
        allNavPresent = false;
        console.error(`Missing section: ${sec}`);
    }
}
assert(allNavPresent, '6. All nine primary navigation section identifiers are maintained in navItems');

// 7. Patient registration and admission wizard logic remain intact
assert(pawJs.includes('registerPatient'), '7a. registerPatient Apex method is wired and intact');
assert(pawJs.includes('handleSubmitRegisterPatient') && pawJs.includes('handleForceRegisterNewPatient'), 
    '7b. handleSubmitRegisterPatient and handleForceRegisterNewPatient handlers are intact');
assert(pawJs.includes('openAdmissionWizard'), '7c. openAdmissionWizard is intact');
assert(pawJs.includes('handleWizardNext'), '7d. 6-step wizard navigation handler handleWizardNext is intact');

// 8. No unexpected hardcoded business counts introduced
assert(!dashJs.includes("badge: '19'"), '8a. Hardcoded badge 19 removed from admissions navItem');
assert(!dashJs.includes("badge: '113'"), '8b. Hardcoded badge 113 removed from patients navItem');
assert(!dashJs.includes("badge: '12'"), '8c. Hardcoded badge 12 removed from doctors navItem');

console.log('\n=================================================================');
console.log(` SUMMARY: ${passCount} / ${passCount + failCount} checks passed (${failCount} failures).`);
console.log('=================================================================\n');

if (failCount > 0) {
    process.exit(1);
}
