/**
 * @description Core domain service for appointment booking, double-booking concurrency locking,
 * fee/discount calculations, and slot booked-count maintenance.
 */
public inherited sharing class AppointmentService {

    /**
     * @description Enforces concurrency-safe slot capacity using row-level locking (FOR UPDATE).
     * Prevents overbooking across simultaneous booking transactions.
     * @param appts Incoming list of Appointment records being created or updated.
     */
    public static void validateAndReserve(List<Appointment__c> appts) {
        validateAndReserve(appts, Trigger.isUpdate ? (Map<Id, Appointment__c>) Trigger.oldMap : null);
    }

    /**
     * @description Overloaded validateAndReserve supporting oldMap for update context.
     * @param appts Incoming list of Appointment records.
     * @param oldMap Map of old appointment states.
     */
    public static void validateAndReserve(List<Appointment__c> appts, Map<Id, Appointment__c> oldMap) {
        Set<Id> slotIds = new Set<Id>();
        for (Appointment__c a : appts) {
            if (a.Slot__c != null && isBookedStatus(a.Status__c)) {
                Appointment__c oldA = (oldMap != null) ? oldMap.get(a.Id) : null;
                Boolean alreadyBookedInSlot = (oldA != null && oldA.Slot__c == a.Slot__c && isBookedStatus(oldA.Status__c));
                if (!alreadyBookedInSlot) {
                    slotIds.add(a.Slot__c);
                }
            }
        }
        if (slotIds.isEmpty()) {
            return;
        }

        // Row lock: serializes concurrent transactions booking into the same slot
        Map<Id, Appointment_Slot__c> slots = new Map<Id, Appointment_Slot__c>(
            [SELECT Id, Total_Capacity__c, Booked_Count__c, Slot_Start__c
             FROM Appointment_Slot__c
             WHERE Id IN :slotIds
             FOR UPDATE]
        );

        Map<Id, Integer> requested = new Map<Id, Integer>();
        for (Appointment__c a : appts) {
            Appointment__c oldA = (oldMap != null) ? oldMap.get(a.Id) : null;
            Boolean alreadyBookedInSlot = (oldA != null && oldA.Slot__c == a.Slot__c && isBookedStatus(oldA.Status__c));
            if (!alreadyBookedInSlot && a.Slot__c != null && slots.containsKey(a.Slot__c) && isBookedStatus(a.Status__c)) {
                Integer currentCount = requested.containsKey(a.Slot__c) ? requested.get(a.Slot__c) : 0;
                requested.put(a.Slot__c, currentCount + 1);
            }
        }

        for (Appointment__c a : appts) {
            Appointment__c oldA = (oldMap != null) ? oldMap.get(a.Id) : null;
            Boolean alreadyBookedInSlot = (oldA != null && oldA.Slot__c == a.Slot__c && isBookedStatus(oldA.Status__c));
            if (!alreadyBookedInSlot && a.Slot__c != null && slots.containsKey(a.Slot__c) && isBookedStatus(a.Status__c)) {
                Appointment_Slot__c s = slots.get(a.Slot__c);
                Decimal booked = s.Booked_Count__c != null ? s.Booked_Count__c : 0;
                Decimal capacity = s.Total_Capacity__c != null ? s.Total_Capacity__c : 0;
                Decimal left = capacity - booked;

                if (requested.get(a.Slot__c) > left) {
                    a.addError('This slot is full. Please choose another time.');
                }
            }
        }
    }

    /**
     * @description Populates doctor consultation fee onto appointment if empty and calculates total amount.
     * @param appts List of appointments in before-insert context.
     */
    public static void populateFeesAndTotals(List<Appointment__c> appts) {
        Set<Id> slotIds = new Set<Id>();
        for (Appointment__c a : appts) {
            if (a.Fee_Amount__c == null && a.Slot__c != null) {
                slotIds.add(a.Slot__c);
            }
        }

        Map<Id, Appointment_Slot__c> slotMap = new Map<Id, Appointment_Slot__c>();
        if (!slotIds.isEmpty()) {
            slotMap = new Map<Id, Appointment_Slot__c>(
                [SELECT Id, Doctor__r.Consultation_Fee__c
                 FROM Appointment_Slot__c
                 WHERE Id IN :slotIds]
            );
        }

        for (Appointment__c a : appts) {
            if (a.Fee_Amount__c == null && a.Slot__c != null && slotMap.containsKey(a.Slot__c)) {
                a.Fee_Amount__c = slotMap.get(a.Slot__c).Doctor__r.Consultation_Fee__c;
            }
            calculateTotal(a);
        }
    }

    /**
     * @description Recalculates total amount whenever fee or discount changes.
     * @param appts List of appointments in before-update context.
     * @param oldMap Map of old appointment states.
     */
    public static void recalculateTotals(List<Appointment__c> appts, Map<Id, Appointment__c> oldMap) {
        for (Appointment__c a : appts) {
            Appointment__c oldAppt = oldMap != null ? oldMap.get(a.Id) : null;

            // Invalidate stale approval: If discount percentage is modified after approval, reset approval status
            if (oldAppt != null && a.Discount_Percent__c != oldAppt.Discount_Percent__c) {
                if (oldAppt.Approval_Status__c == 'Approved' && a.Discount_Percent__c > 10) {
                    a.Approval_Status__c = 'Pending';
                } else if (oldAppt.Approval_Status__c == 'Approved' && (a.Discount_Percent__c == null || a.Discount_Percent__c <= 10)) {
                    a.Approval_Status__c = 'None';
                }
            }

            if (oldAppt == null 
                || a.Fee_Amount__c != oldAppt.Fee_Amount__c 
                || a.Discount_Percent__c != oldAppt.Discount_Percent__c
                || a.Approval_Status__c != oldAppt.Approval_Status__c) {
                calculateTotal(a);
            }
        }
    }

    /**
     * @description Synchronizes Booked_Count__c on Appointment_Slot__c records based on active appointments.
     * @param currentList Current list of appointments (insert, update, undelete) or null on delete.
     * @param oldMap Old map of appointments (update, delete) or null on insert.
     */
    public static void updateBookedCounts(List<Appointment__c> currentList, Map<Id, Appointment__c> oldMap) {
        Set<Id> affectedSlotIds = new Set<Id>();

        if (currentList != null) {
            for (Appointment__c a : currentList) {
                if (a.Slot__c != null) {
                    Appointment__c oldA = oldMap != null ? oldMap.get(a.Id) : null;
                    if (oldA == null || a.Status__c != oldA.Status__c || a.Slot__c != oldA.Slot__c) {
                        affectedSlotIds.add(a.Slot__c);
                        if (oldA != null && oldA.Slot__c != null) {
                            affectedSlotIds.add(oldA.Slot__c);
                        }
                    }
                }
            }
        }

        if (oldMap != null && currentList == null) {
            for (Appointment__c a : oldMap.values()) {
                if (a.Slot__c != null) {
                    affectedSlotIds.add(a.Slot__c);
                }
            }
        }

        if (affectedSlotIds.isEmpty()) {
            return;
        }

        Map<Id, Integer> countMap = new Map<Id, Integer>();
        for (Id sid : affectedSlotIds) {
            countMap.put(sid, 0);
        }

        for (AggregateResult ar : [
            SELECT Slot__c sid, COUNT(Id) cnt
            FROM Appointment__c
            WHERE Slot__c IN :affectedSlotIds
              AND Status__c IN ('Confirmed', 'Pending')
            GROUP BY Slot__c
        ]) {
            countMap.put((Id) ar.get('sid'), (Integer) ar.get('cnt'));
        }

        List<Appointment_Slot__c> slotsToUpdate = new List<Appointment_Slot__c>();
        for (Id sid : countMap.keySet()) {
            slotsToUpdate.add(new Appointment_Slot__c(
                Id = sid,
                Booked_Count__c = countMap.get(sid)
            ));
        }

        if (!slotsToUpdate.isEmpty()) {
            update slotsToUpdate;
        }
    }

    private static void calculateTotal(Appointment__c a) {
        Decimal fee = a.Fee_Amount__c != null ? a.Fee_Amount__c : 0;
        Decimal rawDisc = a.Discount_Percent__c != null ? a.Discount_Percent__c : 0;
        Decimal effectiveDisc = 0;

        if (rawDisc > 0 && rawDisc <= 10) {
            effectiveDisc = rawDisc;
        } else if (rawDisc > 10 && a.Approval_Status__c == 'Approved') {
            effectiveDisc = rawDisc;
        } else {
            effectiveDisc = 0;
        }

        a.Total_Amount__c = (fee * (1 - (effectiveDisc / 100))).setScale(2, System.RoundingMode.HALF_UP);
    }

    private static Boolean isBookedStatus(String status) {
        return status == 'Confirmed' || status == 'Pending' || status == null;
    }
}
