/**
 * @description Idempotent Contact Reparenting Script for CareNest Phase 24.
 * Links precisely the 113 CareNest patient contacts to the 'CareNest Inpatient Registry' Account.
 * Strictly excludes all 14 legacy MC demo patient contacts.
 * Safe to execute multiple times (idempotent).
 */

// 1. Resolve and verify the Registry Account
List<Account> regAccounts = [
    SELECT Id, Name
    FROM Account
    WHERE Name = 'CareNest Inpatient Registry'
    LIMIT 1
];

if (regAccounts.isEmpty()) {
    System.assert(false, 'FATAL: Registry Account "CareNest Inpatient Registry" does not exist. Halting execution.');
}
Id registryAccountId = regAccounts[0].Id;

// 2. Query target CareNest patient contacts needing reparenting
// Strictly filters on Patient_Code__c LIKE 'CN-%' and AccountId = null
List<Contact> targetContacts = [
    SELECT Id, Name, Patient_Code__c, AccountId
    FROM Contact
    WHERE Patient_Code__c LIKE 'CN-%'
      AND AccountId = null
    ORDER BY Patient_Code__c ASC
];

System.debug('Target CareNest Contacts requiring reparenting: ' + targetContacts.size());

if (targetContacts.isEmpty()) {
    System.debug('IDEMPOTENT NO-OP: All CareNest patient contacts are already linked to an Account.');
} else {
    // 3. Assign Registry AccountId
    for (Contact c : targetContacts) {
        c.AccountId = registryAccountId;
    }

    // 4. Execute atomic update
    Database.SaveResult[] results = Database.update(targetContacts, true); // fail atomic on error
    System.debug('Successfully reparented ' + results.size() + ' CareNest patient contacts to Account: ' + registryAccountId);
}

// 5. Post-Migration Verification Invariants
Integer linkedCount = [
    SELECT count()
    FROM Contact
    WHERE AccountId = :registryAccountId
      AND Patient_Code__c LIKE 'CN-%'
];
Integer remainingOrphans = [
    SELECT count()
    FROM Contact
    WHERE AccountId = null
];
Integer totalContacts = [
    SELECT count()
    FROM Contact
];

System.debug('=== POST-MIGRATION VERIFICATION ===');
System.debug('Linked CareNest Patients (Expected: 113): ' + linkedCount);
System.debug('Remaining Orphan Contacts (Expected: 14 MC Demo): ' + remainingOrphans);
System.debug('Total Contacts in Org (Expected: 164): ' + totalContacts);

System.assertEquals(113, linkedCount, 'Post-migration assertion failed: Expected exactly 113 linked CareNest patients.');
System.assertEquals(14, remainingOrphans, 'Post-migration assertion failed: Expected exactly 14 remaining orphan MC demo contacts.');
System.assertEquals(164, totalContacts, 'Post-migration assertion failed: Expected exactly 164 total contacts in org.');
