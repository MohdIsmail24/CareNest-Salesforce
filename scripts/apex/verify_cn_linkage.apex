/**
 * @description Verification of CareNest vs MiniCare linkage on Payments, Cancellations, Vitals
 */

Integer paymentsOnCN = [
    SELECT count()
    FROM Payment__c
    WHERE Appointment__r.Patient__r.Patient_Code__c LIKE 'CN-%'
];
Integer totalPayments = [SELECT count() FROM Payment__c];
System.debug('Payments on CareNest (Expected: ' + totalPayments + '): ' + paymentsOnCN);

Integer cancelsOnCN = [
    SELECT count()
    FROM Cancellation__c
    WHERE Appointment__r.Patient__r.Patient_Code__c LIKE 'CN-%'
];
Integer totalCancels = [SELECT count() FROM Cancellation__c];
System.debug('Cancellations on CareNest (Expected: ' + totalCancels + '): ' + cancelsOnCN);

Integer vitalsOnCN = [
    SELECT count()
    FROM Patient_Vital__c
    WHERE Inpatient_Encounter__r.Admission__r.Patient__r.Patient_Code__c LIKE 'CN-%'
];
Integer totalVitals = [SELECT count() FROM Patient_Vital__c];
System.debug('Vitals on CareNest (Expected: ' + totalVitals + '): ' + vitalsOnCN);
