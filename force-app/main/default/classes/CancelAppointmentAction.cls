/**
 * @description Invocable action exposing appointment cancellation to Flow and Agentforce.
 * Delegates all calculation and record operations to CancellationService.
 */
public with sharing class CancelAppointmentAction {

    public class Request {
        @InvocableVariable(required=true label='Appointment ID' description='ID of the appointment to cancel')
        public Id appointmentId;

        @InvocableVariable(label='Reason' description='Reason for cancellation')
        public String reason;
    }

    public class Result {
        @InvocableVariable(label='Cancellation Fee' description='Calculated cancellation fee')
        public Decimal fee;

        @InvocableVariable(label='Refund Amount' description='Calculated refund amount')
        public Decimal refund;
    }

    /**
     * @description Flow invocable method to execute cancellation.
     * @param requests List of cancellation requests.
     * @return List of cancellation results.
     */
    @InvocableMethod(label='Cancel Appointment' description='Cancels an appointment, evaluates cancellation policy, and calculates fee and refund.')
    public static List<Result> cancel(List<Request> requests) {
        List<Result> out = new List<Result>();
        if (requests == null || requests.isEmpty()) {
            return out;
        }

        List<CancellationService.CancellationRequest> serviceRequests = new List<CancellationService.CancellationRequest>();
        for (Request r : requests) {
            serviceRequests.add(new CancellationService.CancellationRequest(r.appointmentId, r.reason));
        }

        List<CancellationService.CancellationResult> serviceResults = CancellationService.cancel(serviceRequests);
        for (CancellationService.CancellationResult sr : serviceResults) {
            Result res = new Result();
            res.fee = sr.fee;
            res.refund = sr.refund;
            out.add(res);
        }
        return out;
    }
}
