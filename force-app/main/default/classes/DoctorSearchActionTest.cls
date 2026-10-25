/**
 * @description Unit tests for DoctorSearchAction invocable action.
 * Verifies department filter, specialty filter, keyword search, combinations,
 * inactive doctor exclusion, empty/null input handling, and structured JSON output.
 */
@isTest
private class DoctorSearchActionTest {

    private static Integer regSeq = 5000;

    private static Doctor__c createDoctor(String name, String dept, String spec, Decimal fee, Boolean isActive) {
        regSeq++;
        Doctor__c d = new Doctor__c(
            Name = name,
            Department__c = dept,
            Specialty__c = spec,
            Consultation_Fee__c = fee,
            Registration_No__c = 'REG-' + regSeq,
            Is_Active__c = isActive
        );
        insert d;
        return d;
    }

    @TestSetup
    static void setupTestData() {
        createDoctor('Dr. Alice Smith', 'General Medicine', 'Family Medicine', 750, true);
        createDoctor('Dr. Bob Jones', 'Paediatrics', 'Pediatrician', 850, true);
        createDoctor('Dr. Carol White', 'General Medicine', 'Internal Medicine', 900, true);
        createDoctor('Dr. Dave Inactive', 'General Medicine', 'General Physician', 600, false);
    }

    @isTest
    static void testSearchByDepartment() {
        DoctorSearchAction.Request req = new DoctorSearchAction.Request();
        req.department = 'General Medicine';

        Test.startTest();
        List<DoctorSearchAction.Response> responses = DoctorSearchAction.search(new List<DoctorSearchAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        DoctorSearchAction.Response res = responses[0];
        System.assert(res.isSuccess, 'Search should succeed');
        System.assertEquals(2, res.doctorCount, 'Should return 2 active General Medicine doctors (excluding inactive)');
        System.assert(res.resultJson.contains('Dr. Alice Smith'), 'Should include Alice Smith');
        System.assert(res.resultJson.contains('Dr. Carol White'), 'Should include Carol White');
        System.assert(!res.resultJson.contains('Dr. Dave Inactive'), 'Must not include inactive doctor');
    }

    @isTest
    static void testSearchBySpecialty() {
        DoctorSearchAction.Request req = new DoctorSearchAction.Request();
        req.specialty = 'Pediatrician';

        Test.startTest();
        List<DoctorSearchAction.Response> responses = DoctorSearchAction.search(new List<DoctorSearchAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        DoctorSearchAction.Response res = responses[0];
        System.assert(res.isSuccess, 'Search should succeed');
        System.assertEquals(1, res.doctorCount, 'Should match 1 doctor');
        System.assert(res.resultJson.contains('Dr. Bob Jones'), 'Should match Bob Jones');
    }

    @isTest
    static void testSearchByNameKeyword() {
        DoctorSearchAction.Request req = new DoctorSearchAction.Request();
        req.searchKey = 'Alice';

        Test.startTest();
        List<DoctorSearchAction.Response> responses = DoctorSearchAction.search(new List<DoctorSearchAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        DoctorSearchAction.Response res = responses[0];
        System.assert(res.isSuccess, 'Search should succeed');
        System.assertEquals(1, res.doctorCount, 'Should match 1 doctor');
        System.assert(res.resultJson.contains('Dr. Alice Smith'), 'Should match Alice Smith');
    }

    @isTest
    static void testSearchByDeptAndSpecialtyAndKey() {
        DoctorSearchAction.Request req = new DoctorSearchAction.Request();
        req.department = 'General Medicine';
        req.specialty = 'Family';
        req.searchKey = 'Alice';

        Test.startTest();
        List<DoctorSearchAction.Response> responses = DoctorSearchAction.search(new List<DoctorSearchAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        DoctorSearchAction.Response res = responses[0];
        System.assert(res.isSuccess, 'Search should succeed');
        System.assertEquals(1, res.doctorCount, 'Should match Alice');
    }

    @isTest
    static void testSearchByDeptAndSpecialty() {
        DoctorSearchAction.Request req = new DoctorSearchAction.Request();
        req.department = 'General Medicine';
        req.specialty = 'Internal';

        Test.startTest();
        List<DoctorSearchAction.Response> responses = DoctorSearchAction.search(new List<DoctorSearchAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        DoctorSearchAction.Response res = responses[0];
        System.assert(res.isSuccess, 'Search should succeed');
        System.assertEquals(1, res.doctorCount, 'Should match Carol');
    }

    @isTest
    static void testSearchByDeptAndKey() {
        DoctorSearchAction.Request req = new DoctorSearchAction.Request();
        req.department = 'General Medicine';
        req.searchKey = 'Carol';

        Test.startTest();
        List<DoctorSearchAction.Response> responses = DoctorSearchAction.search(new List<DoctorSearchAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        DoctorSearchAction.Response res = responses[0];
        System.assert(res.isSuccess, 'Search should succeed');
        System.assertEquals(1, res.doctorCount, 'Should match Carol');
    }

    @isTest
    static void testSearchBySpecAndKey() {
        DoctorSearchAction.Request req = new DoctorSearchAction.Request();
        req.specialty = 'Family';
        req.searchKey = 'Alice';

        Test.startTest();
        List<DoctorSearchAction.Response> responses = DoctorSearchAction.search(new List<DoctorSearchAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        DoctorSearchAction.Response res = responses[0];
        System.assert(res.isSuccess, 'Search should succeed');
        System.assertEquals(1, res.doctorCount, 'Should match Alice');
    }

    @isTest
    static void testSearchAll() {
        DoctorSearchAction.Request req = new DoctorSearchAction.Request();

        Test.startTest();
        List<DoctorSearchAction.Response> responses = DoctorSearchAction.search(new List<DoctorSearchAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        DoctorSearchAction.Response res = responses[0];
        System.assert(res.isSuccess, 'Search should succeed');
        System.assertEquals(3, res.doctorCount, 'Should return all 3 active doctors');
    }

    @isTest
    static void testSearchNoMatch() {
        DoctorSearchAction.Request req = new DoctorSearchAction.Request();
        req.department = 'ENT';

        Test.startTest();
        List<DoctorSearchAction.Response> responses = DoctorSearchAction.search(new List<DoctorSearchAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        DoctorSearchAction.Response res = responses[0];
        System.assert(res.isSuccess, 'Search should succeed');
        System.assertEquals(0, res.doctorCount, 'Should return 0 doctors');
        System.assert(res.message.contains('No active doctors found'), 'Should indicate no doctors found');
    }

    @isTest
    static void testNullAndEmptyRequests() {
        Test.startTest();
        List<DoctorSearchAction.Response> emptyRes = DoctorSearchAction.search(new List<DoctorSearchAction.Request>());
        List<DoctorSearchAction.Response> nullRes = DoctorSearchAction.search(null);
        Test.stopTest();

        System.assertEquals(0, emptyRes.size(), 'Empty request list should return empty response list');
        System.assertEquals(0, nullRes.size(), 'Null request list should return empty response list');
    }
}
