/**
 * @description Centralized, durable, bulk-conscious error logging service for CareNest HMS.
 * Publishes High-Volume Platform Events (PublishImmediately) to ensure diagnostic logs
 * survive rollbacks of originating transactions, with seamless asynchronous persistence into Error_Log__c.
 * Includes comprehensive PII, credential, and clinical free-text sanitization.
 */
public without sharing class ErrorLogService {

    @TestVisible
    private static Boolean isProcessingEvents = false;

    public class LogEntry {
        public String source;
        public String message;
        public Id recordId;
        public String correlationId;

        public LogEntry(String source, String message, Id recordId) {
            this(source, message, recordId, null);
        }

        public LogEntry(String source, String message, Id recordId, String correlationId) {
            this.source = source;
            this.message = message;
            this.recordId = recordId;
            this.correlationId = correlationId;
        }

        public LogEntry(String source, Exception ex, Id recordId) {
            this(source, ex, recordId, null);
        }

        public LogEntry(String source, Exception ex, Id recordId, String correlationId) {
            this.source = source;
            this.message = (ex != null) ? formatException(ex) : 'Unknown exception';
            this.recordId = recordId;
            this.correlationId = correlationId;
        }
    }

    /**
     * @description Logs a single Exception with source and related record ID.
     */
    public static Error_Log__c log(String source, Exception ex, Id recordId) {
        return log(source, ex, recordId, null);
    }

    /**
     * @description Logs a single Exception with source, related record ID, and correlation ID.
     */
    public static Error_Log__c log(String source, Exception ex, Id recordId, String correlationId) {
        List<Error_Log__c> logs = log(new List<LogEntry>{ new LogEntry(source, ex, recordId, correlationId) });
        return logs.isEmpty() ? null : logs[0];
    }

    /**
     * @description Logs a raw message string with source and related record ID.
     */
    public static Error_Log__c log(String source, String message, Id recordId) {
        return log(source, message, recordId, null);
    }

    /**
     * @description Logs a raw message string with source, related record ID, and correlation ID.
     */
    public static Error_Log__c log(String source, String message, Id recordId, String correlationId) {
        List<Error_Log__c> logs = log(new List<LogEntry>{ new LogEntry(source, message, recordId, correlationId) });
        return logs.isEmpty() ? null : logs[0];
    }

    /**
     * @description Converts Database.SaveResult array from partial-update operations into durable error logs.
     */
    public static List<Error_Log__c> logSaveResults(String source, Database.SaveResult[] srList, List<sObject> records) {
        return logSaveResults(source, srList, records, null);
    }

    /**
     * @description Converts Database.SaveResult array from partial-update operations into durable error logs with correlation ID.
     */
    public static List<Error_Log__c> logSaveResults(String source, Database.SaveResult[] srList, List<sObject> records, String correlationId) {
        List<LogEntry> entries = new List<LogEntry>();
        if (srList == null) {
            return new List<Error_Log__c>();
        }
        for (Integer i = 0; i < srList.size(); i++) {
            Database.SaveResult sr = srList[i];
            if (!sr.isSuccess()) {
                Id recId = (sr.getId() != null) 
                    ? sr.getId() 
                    : (records != null && records.size() > i && records[i].Id != null ? records[i].Id : null);
                List<String> errMsgs = new List<String>();
                for (Database.Error err : sr.getErrors()) {
                    String fields = err.getFields().isEmpty() ? '' : ' (Fields: ' + String.join(err.getFields(), ',') + ')';
                    errMsgs.add('[' + err.getStatusCode() + '] ' + err.getMessage() + fields);
                }
                entries.add(new LogEntry(source, String.join(errMsgs, ' | '), recId, correlationId));
            }
        }
        return log(entries);
    }

    /**
     * @description Publishes durable high-volume platform events (PublishImmediately)
     * so logs survive transaction rollbacks. Falls back to synchronous sObject DML if publishing fails.
     */
    public static List<Error_Log__c> log(List<LogEntry> entries) {
        List<Error_Log__c> representedLogs = new List<Error_Log__c>();
        if (entries == null || entries.isEmpty()) {
            return representedLogs;
        }

        List<Error_Log_Event__e> eventsToPublish = new List<Error_Log_Event__e>();

        for (LogEntry entry : entries) {
            if (entry == null) {
                continue;
            }
            Error_Log_Event__e evt = new Error_Log_Event__e();
            evt.Source__c = truncate(entry.source, 80);
            evt.Message__c = sanitize(truncate(entry.message, 5000));
            evt.Record_Id__c = entry.recordId != null ? truncate(String.valueOf(entry.recordId), 18) : null;
            evt.Correlation_Id__c = truncate(entry.correlationId, 80);
            eventsToPublish.add(evt);

            // Maintain represented sObject for caller return compatibility
            Error_Log__c logRec = new Error_Log__c();
            logRec.Source__c = evt.Source__c;
            String prefix = String.isNotBlank(evt.Correlation_Id__c) ? '[Correlation: ' + evt.Correlation_Id__c + '] ' : '';
            logRec.Message__c = truncate(prefix + evt.Message__c, 5000);
            logRec.Record_Id__c = evt.Record_Id__c;
            representedLogs.add(logRec);
        }

        if (!eventsToPublish.isEmpty()) {
            try {
                Database.SaveResult[] pubResults = EventBus.publish(eventsToPublish);
                List<Error_Log__c> fallbackLogs = new List<Error_Log__c>();
                for (Integer i = 0; i < pubResults.size(); i++) {
                    if (!pubResults[i].isSuccess()) {
                        fallbackLogs.add(representedLogs[i]);
                    }
                }
                // Resilient fallback: If platform event publishing fails, insert directly into Error_Log__c
                if (!fallbackLogs.isEmpty()) {
                    Database.insert(fallbackLogs, false);
                }
            } catch (Exception ex) {
                // Fail-safe secondary fallback
                System.debug(LoggingLevel.ERROR, 'CareNest ErrorLogService event publish failure: ' + ex.getMessage());
                try {
                    Database.insert(representedLogs, false);
                } catch (Exception dmlEx) {
                    System.debug(LoggingLevel.ERROR, 'CareNest ErrorLogService fallback DML failure: ' + dmlEx.getMessage());
                }
            }
        }
        return representedLogs;
    }

    /**
     * @description Asynchronously processes published Error_Log_Event__e events into Error_Log__c.
     * Guarded against recursion and fail-safe against uncaught DML exceptions.
     */
    public static void handleEvents(List<Error_Log_Event__e> events) {
        if (events == null || events.isEmpty() || isProcessingEvents) {
            return;
        }

        isProcessingEvents = true;
        try {
            List<Error_Log__c> logsToInsert = new List<Error_Log__c>();
            for (Error_Log_Event__e evt : events) {
                if (evt == null) {
                    continue;
                }
                Error_Log__c logRec = new Error_Log__c();
                logRec.Source__c = truncate(evt.Source__c, 80);
                String prefix = String.isNotBlank(evt.Correlation_Id__c) ? '[Correlation: ' + evt.Correlation_Id__c + '] ' : '';
                logRec.Message__c = sanitize(truncate(prefix + evt.Message__c, 5000));
                logRec.Record_Id__c = truncate(evt.Record_Id__c, 18);
                logsToInsert.add(logRec);
            }

            if (!logsToInsert.isEmpty()) {
                Database.insert(logsToInsert, false);
            }
        } catch (Exception ex) {
            // Never re-publish or throw from event consumer to prevent infinite recursion
            System.debug(LoggingLevel.ERROR, 'CareNest ErrorLogService event consumer error: ' + ex.getMessage());
        } finally {
            isProcessingEvents = false;
        }
    }

    /**
     * @description Standardizes an Exception into an error string with structured type, message, and stack trace.
     */
    private static String formatException(Exception ex) {
        String msg = '[' + ex.getTypeName() + '] ' + ex.getMessage();
        String trace = ex.getStackTraceString();
        if (String.isNotBlank(trace) && !trace.equalsIgnoreCase('()')) {
            msg += '\nStack: ' + trace;
        }
        return msg;
    }

    /**
     * @description Truncates a string to maximum allowable length safely.
     */
    @TestVisible
    private static String truncate(String val, Integer maxLen) {
        if (val == null) {
            return null;
        }
        return (val.length() > maxLen) ? val.substring(0, maxLen) : val;
    }

    /**
     * @description Strips sensitive access tokens, secrets, credentials, API keys,
     * email addresses, Indian phone numbers, and clinical/patient free-text patterns.
     */
    public static String sanitize(String msg) {
        if (msg == null) {
            return null;
        }
        // 1. Redact credentials, tokens, bearer headers, api keys, passwords, secrets
        msg = msg.replaceAll('(?i)(password|bearer|secret|credential|api[_-]?key)\\s*[:=]\\s*\\S{1,200}', '$1: [REDACTED]');
        msg = msg.replaceAll('(?i)\\btoken\\s*[:=]\\s*\\S{1,200}', 'token: [REDACTED]');
        msg = msg.replaceAll('(?i)Bearer\\s+[A-Za-z0-9\\-\\._~\\+\\/]{1,500}=*', 'Bearer [REDACTED]');

        // 2. Redact email addresses
        msg = msg.replaceAll('(?i)[a-zA-Z0-9._%+-]{1,100}@[a-zA-Z0-9.-]{1,100}\\.[a-zA-Z]{2,10}', '[EMAIL_REDACTED]');

        // 3. Redact Indian phone numbers (10 digits starting with 6-9, optional +91) and standard formatted 10-digit phone numbers
        msg = msg.replaceAll('(?i)(?:\\+91[\\-\\s]?)?[6-9]\\d{9}\\b', '[PHONE_REDACTED]');
        msg = msg.replaceAll('(?i)\\b\\d{3}[-.\\s]\\d{3}[-.\\s]\\d{4}\\b', '[PHONE_REDACTED]');

        // 4. Redact free-text clinical notes and patient names (bounded to prevent regex complexity)
        msg = msg.replaceAll('(?i)(patient\\s*name\\s*[:=]\\s*)[^\\n\\r,;]{1,100}', '$1[REDACTED]');
        msg = msg.replaceAll('(?i)(clinical\\s*notes?\\s*[:=]\\s*)[^\\n\\r,;]{1,200}', '$1[REDACTED]');
        msg = msg.replaceAll('(?i)(chief\\s*complaint\\s*[:=]\\s*)[^\\n\\r,;]{1,200}', '$1[REDACTED]');
        msg = msg.replaceAll('(?i)(assessment\\s*[:=]\\s*)[^\\n\\r,;]{1,200}', '$1[REDACTED]');

        return msg;
    }
}
