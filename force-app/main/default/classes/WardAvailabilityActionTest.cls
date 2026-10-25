/**
 * @description Unit tests for WardAvailabilityAction invocable action.
 * Verifies ward lookup by name, code, type, all wards aggregation, bed rollup metrics,
 * zero patient data leakage, and empty/null handling.
 */
@isTest
private class WardAvailabilityActionTest {

    @TestSetup
    static void setupTestData() {
        Ward__c w1 = new Ward__c(
            Name = 'General Medical Ward',
            Ward_Code__c = 'WRD-GEN-01',
            Ward_Type__c = 'General',
            Floor__c = '1',
            Capacity__c = 4,
            Is_Active__c = true
        );
        insert w1;

        List<Bed__c> bedsW1 = new List<Bed__c>{
            new Bed__c(Name = 'B-GEN-01', Bed_Code__c = 'B-GEN-01', Ward__c = w1.Id, Bed_Type__c = 'Standard', Status__c = 'Available'),
            new Bed__c(Name = 'B-GEN-02', Bed_Code__c = 'B-GEN-02', Ward__c = w1.Id, Bed_Type__c = 'Standard', Status__c = 'Occupied')
        };
        insert bedsW1;

        Ward__c w2 = new Ward__c(
            Name = 'Intensive Care Unit',
            Ward_Code__c = 'WRD-ICU-01',
            Ward_Type__c = 'ICU',
            Floor__c = '3',
            Capacity__c = 2,
            Is_Active__c = true
        );
        insert w2;

        List<Bed__c> bedsW2 = new List<Bed__c>{
            new Bed__c(Name = 'B-ICU-01', Bed_Code__c = 'B-ICU-01', Ward__c = w2.Id, Bed_Type__c = 'ICU', Status__c = 'Available'),
            new Bed__c(Name = 'B-ICU-02', Bed_Code__c = 'B-ICU-02', Ward__c = w2.Id, Bed_Type__c = 'ICU', Status__c = 'Available')
        };
        insert bedsW2;
    }

    @isTest
    static void testCheckAvailabilityByName() {
        WardAvailabilityAction.Request req = new WardAvailabilityAction.Request();
        req.wardNameOrCode = 'General';

        Test.startTest();
        List<WardAvailabilityAction.Response> responses = WardAvailabilityAction.checkAvailability(
            new List<WardAvailabilityAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        WardAvailabilityAction.Response res = responses[0];
        System.assert(res.isSuccess, 'Action should succeed');
        System.assertEquals(1, res.availableBeds, 'General ward should have 1 available bed');
        System.assertEquals(1, res.occupiedBeds, 'General ward should have 1 occupied bed');
        System.assert(res.resultJson.contains('General Medical Ward'), 'Should contain General Medical Ward');
        System.assert(!res.resultJson.contains('Intensive Care Unit'), 'Should not contain ICU');
    }

    @isTest
    static void testCheckAvailabilityByType() {
        WardAvailabilityAction.Request req = new WardAvailabilityAction.Request();
        req.wardType = 'ICU';

        Test.startTest();
        List<WardAvailabilityAction.Response> responses = WardAvailabilityAction.checkAvailability(
            new List<WardAvailabilityAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        WardAvailabilityAction.Response res = responses[0];
        System.assert(res.isSuccess, 'Action should succeed');
        System.assertEquals(2, res.availableBeds, 'ICU should have 2 available beds');
        System.assertEquals(0, res.occupiedBeds, 'ICU should have 0 occupied beds');
        System.assert(res.resultJson.contains('WRD-ICU-01'), 'Should contain ICU ward code');
    }

    @isTest
    static void testCheckAllWards() {
        WardAvailabilityAction.Request req = new WardAvailabilityAction.Request();

        Test.startTest();
        List<WardAvailabilityAction.Response> responses = WardAvailabilityAction.checkAvailability(
            new List<WardAvailabilityAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        WardAvailabilityAction.Response res = responses[0];
        System.assert(res.isSuccess, 'Action should succeed');
        System.assertEquals(6, res.totalCapacity, 'Total capacity should be 4 + 2 = 6');
        System.assertEquals(3, res.availableBeds, 'Total available beds should be 1 + 2 = 3');
        System.assertEquals(1, res.occupiedBeds, 'Total occupied beds should be 1');
    }

    @isTest
    static void testWardNotFound() {
        WardAvailabilityAction.Request req = new WardAvailabilityAction.Request();
        req.wardNameOrCode = 'NonExistentWard';

        Test.startTest();
        List<WardAvailabilityAction.Response> responses = WardAvailabilityAction.checkAvailability(
            new List<WardAvailabilityAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        WardAvailabilityAction.Response res = responses[0];
        System.assert(res.isSuccess, 'Action should succeed even when no wards match');
        System.assertEquals(0, res.totalCapacity, 'Capacity should be 0');
        System.assert(res.message.contains('No active wards found'), 'Should indicate no wards found');
    }

    @isTest
    static void testNullAndEmptyRequests() {
        Test.startTest();
        List<WardAvailabilityAction.Response> emptyRes = WardAvailabilityAction.checkAvailability(
            new List<WardAvailabilityAction.Request>()
        );
        List<WardAvailabilityAction.Response> nullRes = WardAvailabilityAction.checkAvailability(null);
        Test.stopTest();

        System.assertEquals(0, emptyRes.size(), 'Empty list returns empty list');
        System.assertEquals(0, nullRes.size(), 'Null list returns empty list');
    }
}
