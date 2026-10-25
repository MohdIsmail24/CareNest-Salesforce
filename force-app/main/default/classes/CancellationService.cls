/**
 * @description Service for managing appointment cancellations, evaluating tiered cancellation policies
 * from Cancellation_Policy__mdt, calculating fees and refunds, and creating cancellation records.
 */
public with sharing class CancellationService {

    public class CancellationRequest {
        public Id appointmentId;
        public String reason;

        public CancellationRequest() {}
        public CancellationRequest(Id appointmentId, String reason) {
            this.appointmentId = appointmentId;
            this.reason = reason;
        }
    }

    public class CancellationResult {
        public Id appointmentId;
        public Id cancellationId;
        public Decimal fee;
        public Decimal refund;
        public Boolean isSuccess;
        public String errorMessage;
    }

    /**
     * @description Cancels a single appointment by Id with reason.
     * @param appointmentId ID of the Appointment__c record.
     * @param reason Explanation for cancellation.
     * @return CancellationResult containing calculated fee, refund, and cancellation Id.
     */
    public static CancellationResult cancel(Id appointmentId, String reason) {
        List<CancellationRequest> requests = new List<CancellationRequest>{
            new CancellationRequest(appointmentId, reason)
        };
        List<CancellationResult> results = cancel(requests);
        if (!results.isEmpty() && !results[0].isSuccess) {
            throw new AuraHandledException(results[0].errorMessage);
        }
        return results[0];
    }

    /**
     * @description Bulk-safe method to cancel multiple appointments according to custom metadata policies.
     * @param requests List of CancellationRequest records.
     * @return List of CancellationResult records.
     */
    public static List<CancellationResult> cancel(List<CancellationRequest> requests) {
        List<CancellationResult> results = new List<CancellationResult>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        Set<Id> apptIds = new Set<Id>();
        for (CancellationRequest r : requests) {
            if (r.appointmentId != null) {
                apptIds.add(r.appointmentId);
            }
        }

        Map<Id, Appointment__c> apptMap = new Map<Id, Appointment__c>(
            [SELECT Id, Name, Status__c, Total_Amount__c, Slot__r.Slot_Start__c
             FROM Appointment__c
             WHERE Id IN :apptIds
             FOR UPDATE]
        );

        // Retrieve metadata policies ordered descending by minimum hours
        List<Cancellation_Policy__mdt> policies = [
            SELECT DeveloperName, MasterLabel, Min_Hours__c, Fee_Percent__c
            FROM Cancellation_Policy__mdt
            ORDER BY Min_Hours__c DESC
        ];

        Datetime now = Datetime.now();
        List<Cancellation__c> cancellationsToInsert = new List<Cancellation__c>();
        List<Appointment__c> appointmentsToUpdate = new List<Appointment__c>();
        Map<Id, CancellationResult> resMap = new Map<Id, CancellationResult>();

        for (CancellationRequest r : requests) {
            CancellationResult res = new CancellationResult();
            res.appointmentId = r.appointmentId;
            res.isSuccess = false;

            if (r.appointmentId == null || !apptMap.containsKey(r.appointmentId)) {
                res.errorMessage = 'Appointment not found or invalid ID.';
                results.add(res);
                continue;
            }

            Appointment__c appt = apptMap.get(r.appointmentId);
            if (appt.Status__c == 'Cancelled') {
                res.errorMessage = 'Appointment is already cancelled.';
                results.add(res);
                continue;
            }

            if (appt.Status__c == 'Completed') {
                res.errorMessage = 'Completed appointments cannot be cancelled.';
                results.add(res);
                continue;
            }

            // Calculate hours remaining before appointment slot start
            Datetime slotStart = appt.Slot__r != null ? appt.Slot__r.Slot_Start__c : null;
            Decimal hoursLeft = 0;
            if (slotStart != null && slotStart > now) {
                Long millis = slotStart.getTime() - now.getTime();
                hoursLeft = Decimal.valueOf(millis).divide(3600000, 1, System.RoundingMode.HALF_UP);
            }

            // Determine fee percentage from policies
            Decimal feePercent = 100; // default for under minimum hours
            for (Cancellation_Policy__mdt p : policies) {
                if (hoursLeft >= p.Min_Hours__c) {
                    feePercent = p.Fee_Percent__c != null ? p.Fee_Percent__c : 0;
                    break;
                }
            }

            Decimal total = appt.Total_Amount__c != null ? appt.Total_Amount__c : 0;
            Decimal fee = (total * (feePercent / 100)).setScale(2, System.RoundingMode.HALF_UP);
            Decimal refund = (total - fee).setScale(2, System.RoundingMode.HALF_UP);

            res.fee = fee;
            res.refund = refund;
            res.isSuccess = true;
            resMap.put(appt.Id, res);

            Cancellation__c canc = new Cancellation__c(
                Appointment__c = appt.Id,
                Reason__c = r.reason,
                Hours_Before_Appointment__c = hoursLeft,
                Cancellation_Fee__c = fee,
                Refund_Amount__c = refund
            );
            cancellationsToInsert.add(canc);

            appt.Status__c = 'Cancelled';
            appointmentsToUpdate.add(appt);
        }

        try {
            if (!cancellationsToInsert.isEmpty()) {
                insert cancellationsToInsert;
                for (Cancellation__c c : cancellationsToInsert) {
                    if (resMap.containsKey(c.Appointment__c)) {
                        resMap.get(c.Appointment__c).cancellationId = c.Id;
                    }
                }
            }

            if (!appointmentsToUpdate.isEmpty()) {
                update appointmentsToUpdate;
            }
        } catch (Exception ex) {
            ErrorLogService.log('CancellationService.cancel', ex, null);
            throw ex;
        }

        for (CancellationRequest r : requests) {
            if (resMap.containsKey(r.appointmentId)) {
                results.add(resMap.get(r.appointmentId));
            }
        }

        return results;
    }
}
