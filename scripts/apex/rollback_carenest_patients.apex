/**
 * @description Rollback Script for CareNest Patient Reparenting.
 * Restores the 113 CareNest patient contacts back to their original orphan state (AccountId = null).
 * Safe, idempotent, and leaves all 14 legacy MC demo contacts and 37 business contacts untouched.
 */

List<Account> regAccounts = [
    SELECT Id, Name
    FROM Account
    WHERE Name = 'CareNest Inpatient Registry'
    LIMIT 1
];

if (regAccounts.isEmpty()) {
    System.debug('Registry Account does not exist. No records to roll back.');
} else {
    Id registryAccountId = regAccounts[0].Id;

    List<Contact> reparentedContacts = [
        SELECT Id, Name, Patient_Code__c, AccountId
        FROM Contact
        WHERE AccountId = :registryAccountId
          AND Patient_Code__c LIKE 'CN-%'
    ];

    System.debug('Found ' + reparentedContacts.size() + ' CareNest contacts linked to registry for rollback.');

    if (!reparentedContacts.isEmpty()) {
        for (Contact c : reparentedContacts) {
            c.AccountId = null;
        }
        update reparentedContacts;
        System.debug('Successfully rolled back ' + reparentedContacts.size() + ' contacts to orphan state.');
    }

    // Verify rollback state
    Integer orphanCount = [SELECT count() FROM Contact WHERE AccountId = null];
    System.debug('Current orphan Contact count (Expected: 127 after rollback): ' + orphanCount);
    System.assertEquals(127, orphanCount, 'Rollback assertion failed: Expected exactly 127 orphan contacts.');
}
