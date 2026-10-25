@isTest
private class ErrorLogServiceTest {

    @isTest
    static void testLogSingleException() {
        Test.startTest();
        try {
            Integer divideByZero = 10 / 0;
        } catch (Exception ex) {
            Error_Log__c logRec = ErrorLogService.log('ErrorLogServiceTest.testDivide', ex, null);
            Assert.isNotNull(logRec, 'Error log representation should be instantiated');
        }
        Test.stopTest();

        List<Error_Log__c> logs = [SELECT Id, Source__c, Message__c, Record_Id__c FROM Error_Log__c WHERE Source__c = 'ErrorLogServiceTest.testDivide'];
        Assert.areEqual(1, logs.size(), 'Exactly one error log should be persisted via platform event');
        Assert.isTrue(logs[0].Message__c.contains('MathException'), 'Message should capture exception type');
        Assert.isTrue(logs[0].Message__c.contains('Divide by 0'), 'Message should capture exception message');
        Assert.isNull(logs[0].Record_Id__c, 'Record ID should be null');
    }

    @isTest
    static void testLogRawMessageAndRecordId() {
        Id fakeId = '001000000000001AAA';

        Test.startTest();
        Error_Log__c logRec = ErrorLogService.log('CustomBatchJob', 'Failed to process item', fakeId, 'CORR-123');
        Test.stopTest();

        Assert.isNotNull(logRec, 'Log representation should be returned');
        List<Error_Log__c> logs = [SELECT Id, Source__c, Message__c, Record_Id__c FROM Error_Log__c WHERE Source__c = 'CustomBatchJob'];
        Assert.areEqual(1, logs.size(), 'Log record should be persisted');
        Assert.isTrue(logs[0].Message__c.contains('Failed to process item'), 'Message content mismatch');
        Assert.isTrue(logs[0].Message__c.contains('CORR-123'), 'Correlation ID should be present');
        Assert.areEqual(String.valueOf(fakeId), logs[0].Record_Id__c, 'Record ID mismatch');
    }

    @isTest
    static void testLogBulkEntries() {
        List<ErrorLogService.LogEntry> entries = new List<ErrorLogService.LogEntry>();
        for (Integer i = 0; i < 5; i++) {
            entries.add(new ErrorLogService.LogEntry('BulkSource', 'Error message ' + i, null, 'BATCH-' + i));
        }

        Test.startTest();
        List<Error_Log__c> logs = ErrorLogService.log(entries);
        Test.stopTest();

        Assert.areEqual(5, logs.size(), 'Should return 5 log representations');
        List<Error_Log__c> savedLogs = [SELECT Id FROM Error_Log__c WHERE Source__c = 'BulkSource'];
        Assert.areEqual(5, savedLogs.size(), 'All 5 error logs should be saved');
    }

    @isTest
    static void testLogSaveResultsWithErrors() {
        Appointment__c badAppt = new Appointment__c();
        Database.SaveResult[] srList = Database.insert(new List<Appointment__c>{ badAppt }, false);
        Assert.isFalse(srList[0].isSuccess(), 'Insert should fail on invalid appointment');

        Test.startTest();
        List<Error_Log__c> logs = ErrorLogService.logSaveResults('TestSaveResults', srList, new List<Appointment__c>{ badAppt });
        Test.stopTest();

        Assert.areEqual(1, logs.size(), 'Should generate one log for the failed row');
        List<Error_Log__c> savedLogs = [SELECT Id, Source__c, Message__c FROM Error_Log__c WHERE Source__c = 'TestSaveResults'];
        Assert.areEqual(1, savedLogs.size(), 'Log record should be saved in DB');
        Assert.isTrue(savedLogs[0].Message__c.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION') || savedLogs[0].Message__c.contains('patient contact'), 'Log should capture failure reason');
    }

    @isTest
    static void testNullAndBoundaryHandling() {
        Test.startTest();
        Error_Log__c nullEx = ErrorLogService.log('NullEx', (Exception) null, null);
        List<Error_Log__c> nullList = ErrorLogService.log((List<ErrorLogService.LogEntry>) null);
        List<Error_Log__c> emptyList = ErrorLogService.log(new List<ErrorLogService.LogEntry>());
        List<Error_Log__c> nullSr = ErrorLogService.logSaveResults('NullSR', null, null);
        ErrorLogService.handleEvents(null);
        ErrorLogService.handleEvents(new List<Error_Log_Event__e>());
        Test.stopTest();

        Assert.isNotNull(nullEx, 'Null exception should still create placeholder log record');
        Assert.areEqual(0, nullList.size(), 'Null list should return empty list');
        Assert.areEqual(0, emptyList.size(), 'Empty list should return empty list');
        Assert.areEqual(0, nullSr.size(), 'Null SaveResult array should return empty list');
    }

    @isTest
    static void testSanitizationOfSensitiveCredentials() {
        String sensitiveMsg = 'Callout failed with token: abc123SecretToken and password: SuperSecretPassword1! and api_key: secretKey99 and Bearer eyJhbGciOi';

        Test.startTest();
        ErrorLogService.log('SecurityTest', sensitiveMsg, null);
        Test.stopTest();

        Error_Log__c saved = [SELECT Message__c FROM Error_Log__c WHERE Source__c = 'SecurityTest' LIMIT 1];
        Assert.isFalse(saved.Message__c.contains('abc123SecretToken'), 'Token value should be redacted');
        Assert.isFalse(saved.Message__c.contains('SuperSecretPassword1!'), 'Password value should be redacted');
        Assert.isFalse(saved.Message__c.contains('secretKey99'), 'API key value should be redacted');
        Assert.isFalse(saved.Message__c.contains('eyJhbGciOi'), 'Bearer token value should be redacted');
        Assert.isTrue(saved.Message__c.contains('[REDACTED]'), 'Redaction placeholder should be present');
    }

    @isTest
    static void testSanitizationOfPiiAndClinicalNotes() {
        String piiMsg = 'Encounter error for patient name: Ramesh Kumar, email: ramesh.kumar@carenest.in, phone: 9876543210 or +91 9123456789. clinical notes: severe chest pain assessment: suspected angina';

        Test.startTest();
        ErrorLogService.log('PiiTest', piiMsg, null);
        Test.stopTest();

        Error_Log__c saved = [SELECT Message__c FROM Error_Log__c WHERE Source__c = 'PiiTest' LIMIT 1];
        Assert.isFalse(saved.Message__c.contains('ramesh.kumar@carenest.in'), 'Email should be redacted');
        Assert.isTrue(saved.Message__c.contains('[EMAIL_REDACTED]'), 'Email placeholder expected');
        Assert.isFalse(saved.Message__c.contains('9876543210'), 'Phone number should be redacted');
        Assert.isFalse(saved.Message__c.contains('9123456789'), '+91 Phone number should be redacted');
        Assert.isTrue(saved.Message__c.contains('[PHONE_REDACTED]'), 'Phone placeholder expected');
        Assert.isFalse(saved.Message__c.contains('Ramesh Kumar'), 'Patient name should be redacted');
        Assert.isFalse(saved.Message__c.contains('severe chest pain'), 'Clinical notes should be redacted');
        Assert.isFalse(saved.Message__c.contains('suspected angina'), 'Assessment should be redacted');
    }

    @isTest
    static void testFieldTruncationSafeguards() {
        String longSource = 'A'.repeat(120);
        String longMessage = 'M'.repeat(6000);

        Test.startTest();
        Error_Log__c logRec = ErrorLogService.log(longSource, longMessage, null);
        Test.stopTest();

        Error_Log__c saved = [SELECT Source__c, Message__c FROM Error_Log__c WHERE Source__c = :longSource.substring(0, 80) LIMIT 1];
        Assert.areEqual(80, saved.Source__c.length(), 'Source should be truncated to 80 chars');
        Assert.areEqual(5000, saved.Message__c.length(), 'Message should be truncated to 5000 chars');
    }

    @isTest
    static void testDurableLoggingSurvivesRollback() {
        Test.startTest();

        // 1. Establish transaction savepoint
        Savepoint sp = Database.setSavepoint();

        // 2. Perform business DML
        Doctor__c doc = new Doctor__c(
            Name = 'Dr. Rollback Test',
            Registration_No__c = 'REG-RBACK-' + String.valueOf(Crypto.getRandomInteger()).substring(0, 5),
            Department__c = 'General Medicine',
            Specialty__c = 'Family Physician',
            Consultation_Fee__c = 150,
            Is_Active__c = true
        );
        insert doc;

        // 3. Log diagnostic message via durable service
        ErrorLogService.log('RollbackDurableTest', 'Critical failure during transaction', doc.Id, 'TX-ROLLBACK-01');

        // 4. Rollback transaction to savepoint
        Database.rollback(sp);

        // Verify business record is rolled back
        List<Doctor__c> docs = [SELECT Id FROM Doctor__c WHERE Id = :doc.Id];
        Assert.areEqual(0, docs.size(), 'Doctor record must be rolled back');

        // 5. Conclude test to deliver High-Volume Platform Events
        Test.stopTest();

        // 6. Verify that Error_Log__c record SURVIVED the rollback!
        List<Error_Log__c> savedLogs = [SELECT Id, Source__c, Message__c, Record_Id__c FROM Error_Log__c WHERE Source__c = 'RollbackDurableTest'];
        Assert.areEqual(1, savedLogs.size(), 'Diagnostic log MUST survive originating transaction rollback');
        Assert.isTrue(savedLogs[0].Message__c.contains('Critical failure during transaction'), 'Log message must persist');
        Assert.isTrue(savedLogs[0].Message__c.contains('TX-ROLLBACK-01'), 'Correlation ID must persist');
        Assert.areEqual(String.valueOf(doc.Id), savedLogs[0].Record_Id__c, 'Record ID must persist');
    }

    @isTest
    static void testDirectEventHandlingAndRecursionGuard() {
        Error_Log_Event__e evt = new Error_Log_Event__e(
            Source__c = 'DirectEventTest',
            Message__c = 'Event message',
            Record_Id__c = '001000000000001AAA',
            Correlation_Id__c = 'CORR-DIR-1'
        );

        Test.startTest();
        // Invoke handler directly
        ErrorLogService.handleEvents(new List<Error_Log_Event__e>{ evt });

        // Test recursion guard
        ErrorLogService.isProcessingEvents = true;
        ErrorLogService.handleEvents(new List<Error_Log_Event__e>{ evt });
        ErrorLogService.isProcessingEvents = false;
        Test.stopTest();

        List<Error_Log__c> logs = [SELECT Id FROM Error_Log__c WHERE Source__c = 'DirectEventTest'];
        Assert.areEqual(1, logs.size(), 'Only 1 log should be created due to recursion guard');
    }
}
