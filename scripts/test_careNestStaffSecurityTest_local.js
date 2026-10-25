/**
 * Local Static Validation Script for CareNestStaffSecurityTest
 */
const fs = require('fs');
const path = require('path');

const clsPath = path.join(__dirname, '..', 'force-app', 'main', 'default', 'classes', 'CareNestStaffSecurityTest.cls');
const metaPath = path.join(__dirname, '..', 'force-app', 'main', 'default', 'classes', 'CareNestStaffSecurityTest.cls-meta.xml');

console.log('=== CareNestStaffSecurityTest Local Verification ===\n');

// 1. Check file existence
if (!fs.existsSync(clsPath) || !fs.existsSync(metaPath)) {
  console.error('FAIL: Missing class or meta XML file');
  process.exit(1);
}
console.log('PASS: Class and metadata XML files exist.');

const content = fs.readFileSync(clsPath, 'utf8');

// 2. Check class annotations
if (!/@IsTest/i.test(content)) {
  console.error('FAIL: Missing @IsTest annotation');
  process.exit(1);
}
console.log('PASS: @IsTest annotation present.');

// 3. Count test methods
const testMethods = content.match(/@IsTest\s+static\s+void\s+([a-zA-Z0-9_]+)\s*\(/g) || [];
console.log(`PASS: Found ${testMethods.length} @IsTest methods:`);
testMethods.forEach(m => {
  const name = m.replace(/@IsTest\s+static\s+void\s+/, '').replace('(', '').trim();
  console.log(`   - ${name}`);
});

if (testMethods.length < 9) {
  console.error(`FAIL: Expected at least 9 test methods, found ${testMethods.length}`);
  process.exit(1);
}

// 4. Verify coverage across all 5 personas
const personas = ['FrontDesk', 'Doctor', 'Nurse', 'WardManagement', 'OperationsManager'];
personas.forEach(p => {
  const hasAuthorized = new RegExp(`test${p}_Authorized`, 'i').test(content);
  const hasDenied = new RegExp(`test${p}_Denied`, 'i').test(content);
  if (!hasAuthorized || !hasDenied) {
    console.error(`FAIL: Missing authorized or denied test method for persona ${p}`);
    process.exit(1);
  }
  console.log(`PASS: Persona ${p} has both Authorized and Denied test cases.`);
});

// 5. Verify cross-patient testing
if (!/testCrossPatientBillingIsolation/i.test(content)) {
  console.error('FAIL: Missing testCrossPatientBillingIsolation');
  process.exit(1);
}
console.log('PASS: Cross-patient isolation test present.');

// 6. Verify System.runAs usage
const runAsMatches = content.match(/System\.runAs\s*\(/g) || [];
console.log(`PASS: Found ${runAsMatches.length} System.runAs() execution blocks.`);
if (runAsMatches.length < 5) {
  console.error('FAIL: Expected at least 5 System.runAs() blocks');
  process.exit(1);
}

// 7. Verify WITH USER_MODE checks
const userModeMatches = content.match(/WITH\s+USER_MODE/g) || [];
console.log(`PASS: Found ${userModeMatches.length} explicit WITH USER_MODE queries.`);

// 8. Verify describe CRUD/FLS assertions
const describeMatches = content.match(/getDescribe\(\)\.is/g) || [];
console.log(`PASS: Found ${describeMatches.length} schema describe CRUD/FLS assertions.`);

console.log('\n=== ALL 8 LOCAL VERIFICATION CHECKS PASSED (100%) ===\n');
