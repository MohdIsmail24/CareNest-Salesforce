@IsTest
private class CareNestAssistantUIControllerTest {

    @TestSetup
    static void setupTestData() {
        Doctor__c doc = new Doctor__c(
            Name = 'Dr. Test AssistantUI',
            Department__c = 'Orthopaedics',
            Specialty__c = 'Joint Replacement',
            Registration_No__c = 'REG-AST-01',
            Is_Active__c = true,
            Consultation_Fee__c = 800
        );
        insert doc;

        Ward__c ward = new Ward__c(
            Name = 'ICU',
            Ward_Code__c = 'CN-WRD-ICU-TEST',
            Ward_Type__c = 'ICU',
            Capacity__c = 10,
            Floor__c = '1'
        );
        insert ward;

        Bed__c bed = new Bed__c(Name = 'Bed ICU-1', Bed_Code__c = 'ICU-01', Ward__c = ward.Id, Status__c = 'Available');
        insert bed;

        Contact patient = new Contact(LastName = 'AsstPatient');
        insert patient;

        Appointment_Slot__c slot = new Appointment_Slot__c(
            Doctor__c = doc.Id,
            Mode__c = 'OPD',
            Slot_Start__c = System.now().addDays(1),
            Total_Capacity__c = 5
        );
        insert slot;

        Appointment__c appt = new Appointment__c(
            Patient__c = patient.Id,
            Slot__c = slot.Id,
            Status__c = 'Confirmed',
            Appointment_Code__c = 'CN-APT-9999'
        );
        insert appt;
    }

    @IsTest
    static void testEmergencyGuardrail() {
        Test.startTest();
        CareNestAssistantUIController.AgentQueryResponseDto res = CareNestAssistantUIController.processQuery('A patient has severe chest pain and trouble breathing. What treatment should I prescribe?');
        Test.stopTest();

        Assert.isTrue(res.isEmergency, 'Should flag as medical emergency');
        Assert.areEqual('Hospital_Information_and_Safe_Escalation', res.topic);
        Assert.isTrue(res.message.contains('does not provide clinical diagnosis'), 'Should refuse prescription');
    }

    @IsTest
    static void testDoctorDiscovery() {
        Test.startTest();
        CareNestAssistantUIController.AgentQueryResponseDto res = CareNestAssistantUIController.processQuery('Find an Orthopaedics doctor');
        Test.stopTest();

        Assert.areEqual('Doctor_Discovery', res.topic);
        Assert.areEqual('DoctorSearchAction', res.actionInvoked);
        Assert.isTrue(res.isSuccess);
    }

    @IsTest
    static void testWardAvailability() {
        Test.startTest();
        CareNestAssistantUIController.AgentQueryResponseDto res = CareNestAssistantUIController.processQuery('How many beds are available in the ICU?');
        Test.stopTest();

        Assert.areEqual('Ward_Availability', res.topic);
        Assert.areEqual('WardAvailabilityAction', res.actionInvoked);
        Assert.isTrue(res.isSuccess);
    }

    @IsTest
    static void testAppointmentStatus() {
        Appointment__c appt = [SELECT Id, Name FROM Appointment__c LIMIT 1];

        Test.startTest();
        CareNestAssistantUIController.AgentQueryResponseDto res = CareNestAssistantUIController.processQuery('Show status of appointment ' + appt.Name);
        Test.stopTest();

        Assert.areEqual('Appointment_Assistance', res.topic);
        Assert.areEqual('AppointmentStatusAction', res.actionInvoked);
    }

    @IsTest
    static void testGeneralHospitalInfo() {
        Test.startTest();
        CareNestAssistantUIController.AgentQueryResponseDto res = CareNestAssistantUIController.processQuery('What are the visiting hours?');
        Test.stopTest();

        Assert.areEqual('Hospital_Information_and_Safe_Escalation', res.topic);
        Assert.isTrue(res.message.contains('Visiting hours'));
    }

    @IsTest
    static void testBlankAndSpecialties() {
        Test.startTest();
        CareNestAssistantUIController.AgentQueryResponseDto blankRes = CareNestAssistantUIController.processQuery('');
        CareNestAssistantUIController.AgentQueryResponseDto entRes = CareNestAssistantUIController.processQuery('Find an ENT specialist');
        CareNestAssistantUIController.AgentQueryResponseDto dermRes = CareNestAssistantUIController.processQuery('Find a dermatology physician');
        CareNestAssistantUIController.AgentQueryResponseDto pedRes = CareNestAssistantUIController.processQuery('Find a paediatrician');
        CareNestAssistantUIController.AgentQueryResponseDto genWardRes = CareNestAssistantUIController.processQuery('Check general ward capacity');
        CareNestAssistantUIController.AgentQueryResponseDto semiRes = CareNestAssistantUIController.processQuery('Check semi-private bed occupancy');
        Test.stopTest();

        Assert.areEqual('General', blankRes.topic);
        Assert.areEqual('Doctor_Discovery', entRes.topic);
        Assert.areEqual('Doctor_Discovery', dermRes.topic);
        Assert.areEqual('Doctor_Discovery', pedRes.topic);
        Assert.areEqual('Ward_Availability', genWardRes.topic);
        Assert.areEqual('Ward_Availability', semiRes.topic);
    }
}
