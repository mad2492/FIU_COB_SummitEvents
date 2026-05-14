public with sharing class FiuInstanceWizardService {
    public class WizardContext {
        @AuraEnabled public Id eventId;
        @AuraEnabled public Id sourceInstanceId;
        @AuraEnabled public String eventName;
        @AuraEnabled public String accountName;
        @AuraEnabled public String title;
        @AuraEnabled public String shortDescription;
        @AuraEnabled public Datetime startDateTime;
        @AuraEnabled public Datetime endDateTime;
        @AuraEnabled public String locationType;
        @AuraEnabled public String locationTitle;
        @AuraEnabled public String locationAddress;
        @AuraEnabled public String locationMapLink;
        @AuraEnabled public String parkingInfo;
        @AuraEnabled public String virtualMeetingLink;
        @AuraEnabled public String meetingId;
        @AuraEnabled public String meetingPasscode;
        @AuraEnabled public String buildingOverride;
        @AuraEnabled public Decimal capacity;
        @AuraEnabled public Boolean privateInstance;
        @AuraEnabled public String templateLogoOverride;
        @AuraEnabled public Decimal eventFeeOverride;
        @AuraEnabled public Decimal eventFeeAdditionalOverride;
        @AuraEnabled public Boolean canCloneReminders;
        @AuraEnabled public Integer sourceReminderCount;
        @AuraEnabled public Boolean defaultCreateReminders;
        @AuraEnabled public String reminderMode;
        @AuraEnabled public String reminderHelpText;
        @AuraEnabled public String timeZoneLabel;
    }

    public class SaveRequest {
        @AuraEnabled public Id eventId;
        @AuraEnabled public Id sourceInstanceId;
        @AuraEnabled public String mode;
        @AuraEnabled public String title;
        @AuraEnabled public String shortDescription;
        @AuraEnabled public Datetime startDateTime;
        @AuraEnabled public Datetime endDateTime;
        @AuraEnabled public Decimal capacity;
        @AuraEnabled public Boolean privateInstance;
        @AuraEnabled public String locationType;
        @AuraEnabled public String locationTitle;
        @AuraEnabled public String locationAddress;
        @AuraEnabled public String locationMapLink;
        @AuraEnabled public String parkingInfo;
        @AuraEnabled public String virtualMeetingLink;
        @AuraEnabled public String meetingId;
        @AuraEnabled public String meetingPasscode;
        @AuraEnabled public String buildingOverride;
        @AuraEnabled public String templateLogoOverride;
        @AuraEnabled public Decimal eventFeeOverride;
        @AuraEnabled public Decimal eventFeeAdditionalOverride;
        @AuraEnabled public Boolean createDefaultReminders;
        @AuraEnabled public String reminderMode;
    }

    public class SaveResult {
        @AuraEnabled public Id instanceId;
        @AuraEnabled public Integer remindersCreated;
        @AuraEnabled public String mode;
    }

    @AuraEnabled(cacheable=true)
    public static WizardContext getContext(Id eventId, Id sourceInstanceId) {
        WizardContext context = new WizardContext();
        context.eventId = eventId;
        context.sourceInstanceId = sourceInstanceId;
        context.privateInstance = false;
        context.canCloneReminders = false;
        context.sourceReminderCount = 0;
        context.defaultCreateReminders = false;
        context.reminderMode = 'NONE';
        context.timeZoneLabel = getEasternTimeZoneLabel();

        if (sourceInstanceId != null) {
            SObject source = [
                SELECT Id, summit__Event__c, summit__Instance_Title__c, summit__Instance_Short_Description__c,
                       summit__Instance_Start_Date__c, summit__Instance_End_Date__c, summit__Capacity__c,
                       summit__Private_Instance__c, summit__Location_Type_Override__c, summit__Location_Title_Override__c,
                       summit__Location_Address_Override__c, summit__Location_Map_Link_Override__c, Parking_info__c,
                       summit__Virtual_Meeting_Link__c, Virtual_Meeting_ID__c, Virtual_Meeting_Password__c,
                       summit__Building_Override__c, summit__Instance_Time_Zone__c,
                       Template_Logo_Override__c,
                       summit__Event_Fee_Override__c, summit__Event_Fee_Additional_Override__c,
                       summit__Event__r.Name, summit__Event__r.summit__Account__r.Name
                FROM summit__Summit_Events_Instance__c
                WHERE Id = :sourceInstanceId
                LIMIT 1
            ];
            context.eventId = (Id) source.get('summit__Event__c');
            context.eventName = (String) source.getSObject('summit__Event__r').get('Name');
            SObject acct = source.getSObject('summit__Event__r') != null
                ? source.getSObject('summit__Event__r').getSObject('summit__Account__r')
                : null;
            context.accountName = acct == null ? null : (String) acct.get('Name');
            context.title = (String) source.get('summit__Instance_Title__c');
            context.shortDescription = (String) source.get('summit__Instance_Short_Description__c');
            context.startDateTime = (Datetime) source.get('summit__Instance_Start_Date__c');
            context.endDateTime = (Datetime) source.get('summit__Instance_End_Date__c');
            context.capacity = (Decimal) source.get('summit__Capacity__c');
            context.privateInstance = (Boolean) source.get('summit__Private_Instance__c');
            context.locationType = (String) source.get('summit__Location_Type_Override__c');
            context.locationTitle = (String) source.get('summit__Location_Title_Override__c');
            context.locationAddress = (String) source.get('summit__Location_Address_Override__c');
            context.locationMapLink = (String) source.get('summit__Location_Map_Link_Override__c');
            context.parkingInfo = (String) source.get('Parking_info__c');
            context.virtualMeetingLink = (String) source.get('summit__Virtual_Meeting_Link__c');
            context.meetingId = (String) source.get('Virtual_Meeting_ID__c');
            context.meetingPasscode = (String) source.get('Virtual_Meeting_Password__c');
            context.buildingOverride = (String) source.get('summit__Building_Override__c');
            context.templateLogoOverride = (String) source.get('Template_Logo_Override__c');
            context.eventFeeOverride = (Decimal) source.get('summit__Event_Fee_Override__c');
            context.eventFeeAdditionalOverride = (Decimal) source.get('summit__Event_Fee_Additional_Override__c');
            String reminderLookupField = resolveReminderInstanceLookup(reminderTypeFields());
            if (reminderLookupField != null) {
                context.sourceReminderCount = Integer.valueOf(String.valueOf(Database.countQuery(
                    'SELECT COUNT() FROM Summit_Events_Instance_Reminder__c WHERE ' + reminderLookupField + ' = :sourceInstanceId'
                )));
            } else {
                context.sourceReminderCount = 0;
            }
            context.canCloneReminders = context.sourceReminderCount > 0;
            applyDepartmentDefaults(context);
        } else if (eventId != null) {
            SObject evt = [
                SELECT Id, Name, summit__Account__r.Name
                FROM summit__Summit_Events__c
                WHERE Id = :eventId
                LIMIT 1
            ];
            context.eventName = (String) evt.get('Name');
            SObject acct = evt.getSObject('summit__Account__r');
            context.accountName = acct == null ? null : (String) acct.get('Name');
            applyDepartmentDefaults(context);
        }
        return context;
    }

    @AuraEnabled
    public static SaveResult saveInstance(SaveRequest req) {
        if (req == null) throw new AuraHandledException('Missing request.');
        if (req.eventId == null) throw new AuraHandledException('Event is required.');
        if (req.capacity == null || req.capacity <= 0) throw new AuraHandledException('Capacity must be greater than zero.');
        if (req.startDateTime == null || req.endDateTime == null) throw new AuraHandledException('Start and end date/time are required.');
        if (req.endDateTime <= req.startDateTime) throw new AuraHandledException('End date/time must be after start date/time.');
        validateTextLength(req.shortDescription, 255, 'Instance Short Description');
        validateTextLength(req.meetingId, 100, 'Meeting ID');
        validateTextLength(req.meetingPasscode, 100, 'Meeting Passcode');
        validateTextLength(req.locationTitle, 255, 'Location Title Override');
        validateTextLength(req.locationAddress, 255, 'Location Address Override');
        validateTextLength(req.locationMapLink, 255, 'Location Map Link Override');
        validateTextLength(req.virtualMeetingLink, 255, 'Virtual Meeting Link');
        validateTextLength(req.parkingInfo, 1000, 'Parking Info');
        validateFee(req.eventFeeOverride, 'Event Fee Override');
        validateFee(req.eventFeeAdditionalOverride, 'Event Fee Additional Override');

        Boolean isOnline = req.locationType == 'Online' || req.locationType == 'Virtual';
        if (!isOnline) {
            if (String.isBlank(req.locationTitle)) throw new AuraHandledException('Location Title Override is required.');
            if (String.isBlank(req.locationAddress)) throw new AuraHandledException('Location Address Override is required.');
            if (String.isBlank(req.locationMapLink)) throw new AuraHandledException('Location Map Link Override is required.');
            if (String.isBlank(req.parkingInfo)) throw new AuraHandledException('Parking Info is required.');
        } else {
            if (String.isBlank(req.virtualMeetingLink)) throw new AuraHandledException('Virtual Meeting Link is required for Online/Virtual instances.');
        }

        Schema.SObjectType instType = Schema.getGlobalDescribe().get('summit__Summit_Events_Instance__c');
        if (instType == null) throw new AuraHandledException('Instance object is not available.');
        Map<String, Schema.SObjectField> fields = instType.getDescribe().fields.getMap();

        SObject newInstance = instType.newSObject();
        putWritable(newInstance, fields, 'summit__Event__c', req.eventId);
        putWritable(newInstance, fields, 'summit__Instance_Title__c', req.title);
        putWritable(newInstance, fields, 'summit__Instance_Short_Description__c', req.shortDescription);
        putWritable(newInstance, fields, 'summit__Instance_Start_Date__c', req.startDateTime);
        putWritable(newInstance, fields, 'summit__Instance_End_Date__c', req.endDateTime);
        putWritable(newInstance, fields, 'summit__Capacity__c', req.capacity);
        putWritable(newInstance, fields, 'summit__Private_Instance__c', req.privateInstance == true);
        putWritable(newInstance, fields, 'summit__Active_Status__c', 'Active');
        putWritable(newInstance, fields, 'summit__Location_Type_Override__c', req.locationType);
        putWritable(newInstance, fields, 'summit__Location_Title_Override__c', req.locationTitle);
        putWritable(newInstance, fields, 'summit__Location_Address_Override__c', req.locationAddress);
        putWritable(newInstance, fields, 'summit__Location_Map_Link_Override__c', req.locationMapLink);
        putWritable(newInstance, fields, 'Parking_info__c', req.parkingInfo);
        putWritable(newInstance, fields, 'summit__Virtual_Meeting_Link__c', req.virtualMeetingLink);
        putWritable(newInstance, fields, 'Virtual_Meeting_ID__c', req.meetingId);
        putWritable(newInstance, fields, 'Virtual_Meeting_Password__c', req.meetingPasscode);
        putWritable(newInstance, fields, 'summit__Building_Override__c', req.buildingOverride);
        putWritable(newInstance, fields, 'Template_Logo_Override__c', req.templateLogoOverride);
        putWritable(newInstance, fields, 'summit__Event_Fee_Override__c', req.eventFeeOverride);
        putWritable(newInstance, fields, 'summit__Event_Fee_Additional_Override__c', req.eventFeeAdditionalOverride);
        putWritable(newInstance, fields, 'summit__Capacity_Control__c', 'Individual Registrants');
        putWritable(newInstance, fields, 'summit__Instance_Time_Zone__c', getEasternTimeZoneLabel());
        putWritableDateTimeCompatible(newInstance, fields, 'summit__Instance_Start_Time__c', req.startDateTime);
        putWritableDateTimeCompatible(newInstance, fields, 'summit__Instance_End_Time__c', req.endDateTime);
        insert newInstance;

        Integer remindersCreated = 0;
        if (req.createDefaultReminders == true) {
            remindersCreated = createRemindersForNewInstance((Id) newInstance.get('Id'), req.sourceInstanceId, req.reminderMode);
        }

        SaveResult result = new SaveResult();
        result.instanceId = (Id) newInstance.get('Id');
        result.remindersCreated = remindersCreated;
        result.mode = req.mode;
        return result;
    }

    private static Integer createRemindersForNewInstance(Id newInstanceId, Id sourceInstanceId, String reminderMode) {
        if (newInstanceId == null) return 0;
        if (reminderMode == 'DEFAULT' || sourceInstanceId == null) {
            return runDefaultReminderFlow(newInstanceId);
        }
        if (reminderMode != 'SOURCE') return 0;
        Schema.SObjectType reminderType = Schema.getGlobalDescribe().get('Summit_Events_Instance_Reminder__c');
        if (reminderType == null) return 0;
        Map<String, Schema.SObjectField> reminderFields = reminderType.getDescribe().fields.getMap();
        String reminderLookupField = resolveReminderInstanceLookup(reminderFields);
        if (String.isBlank(reminderLookupField)) return 0;
        List<SObject> existing = Database.query(
            'SELECT ' + getCloneableReminderFields(reminderFields) +
            ' FROM Summit_Events_Instance_Reminder__c WHERE ' + reminderLookupField + ' = :sourceInstanceId'
        );
        if (existing.isEmpty()) return 0;
        List<SObject> clones = new List<SObject>();
        List<String> fieldNames = new List<String>(reminderFields.keySet());
        for (SObject src : existing) {
            SObject dst = reminderType.newSObject();
            for (String api : fieldNames) {
                if (api == 'Id' || api == 'OwnerId' || api == 'CreatedById' || api == 'LastModifiedById') continue;
                Schema.DescribeFieldResult d = reminderFields.get(api).getDescribe();
                if (!d.isCreateable() || d.isCalculated() || d.isAutoNumber()) continue;
                if (api == reminderLookupField) continue;
                try {
                    dst.put(api, src.get(api));
                } catch (Exception ex) {
                    // Ignore non-queryable/non-cloneable fields.
                }
            }
            if (reminderFields.containsKey(reminderLookupField) && reminderFields.get(reminderLookupField).getDescribe().isCreateable()) {
                dst.put(reminderLookupField, newInstanceId);
            }
            clones.add(dst);
        }
        if (clones.isEmpty()) return 0;
        insert clones;
        return clones.size();
    }

    private static Integer runDefaultReminderFlow(Id newInstanceId) {
        try {
            SObject instanceRow = [
                SELECT Id, summit__Event__r.summit__Account__r.Name
                FROM summit__Summit_Events_Instance__c
                WHERE Id = :newInstanceId
                LIMIT 1
            ];
            Map<String, Object> vars = new Map<String, Object>{
                'rv_IncomingInstance' => instanceRow
            };
            Flow.Interview interview = Flow.Interview.createInterview(
                'SubFlow_Summit_Events_Instance_Reminders_Create_Default_Reminders',
                vars
            );
            interview.start();
        } catch (Exception ex) {
            // If flow isn't available in this org context, fail soft and proceed.
        }

        String reminderLookupField = resolveReminderInstanceLookup(reminderTypeFields());
        if (reminderLookupField == null) return 0;
        return Integer.valueOf(String.valueOf(Database.countQuery(
            'SELECT COUNT() FROM Summit_Events_Instance_Reminder__c WHERE ' + reminderLookupField + ' = :newInstanceId'
        )));
    }

    private static String getCloneableReminderFields(Map<String, Schema.SObjectField> reminderFields) {
        String reminderLookupField = resolveReminderInstanceLookup(reminderFields);
        List<String> names = new List<String>{ 'Id' };
        if (reminderLookupField != null) names.add(reminderLookupField);
        for (String api : reminderFields.keySet()) {
            if (api == 'Id' || api == reminderLookupField) continue;
            Schema.DescribeFieldResult d = reminderFields.get(api).getDescribe();
            if (d.isCreateable() && !d.isCalculated() && !d.isAutoNumber()) names.add(api);
        }
        return String.join(names, ',');
    }

    private static Map<String, Schema.SObjectField> reminderTypeFields() {
        Schema.SObjectType reminderType = Schema.getGlobalDescribe().get('Summit_Events_Instance_Reminder__c');
        return reminderType == null ? new Map<String, Schema.SObjectField>() : reminderType.getDescribe().fields.getMap();
    }

    private static String resolveReminderInstanceLookup(Map<String, Schema.SObjectField> fields) {
        List<String> candidates = new List<String>{ 'Summit_Events_Instance__c', 'summit__Event_Instance__c', 'Event_Instance__c' };
        for (String api : candidates) {
            if (fields.containsKey(api)) return api;
        }
        return null;
    }

    private static void applyDepartmentDefaults(WizardContext context) {
        String accountName = context.accountName == null ? '' : context.accountName;
        Boolean isPino = accountName.contains('Pino');
        Boolean isEpe = accountName == 'Executive and Professional Education';

        if (context.sourceInstanceId != null) {
            if (isPino) {
                if (String.isBlank(context.parkingInfo)) context.parkingInfo = 'TBD';
            } else {
                context.locationTitle = null;
                context.locationAddress = null;
                context.locationMapLink = null;
                context.parkingInfo = null;
            }

            if (!isEpe) {
                context.meetingId = null;
                context.meetingPasscode = null;
            }

            context.virtualMeetingLink = null;
        }

        if (accountName == 'Chapman Graduate School') {
            context.defaultCreateReminders = true;
            context.reminderMode = 'DEFAULT';
            context.reminderHelpText = 'Create the Chapman default reminders: 1 day before and 1 hour before.';
        } else if (isEpe) {
            context.defaultCreateReminders = true;
            context.reminderMode = 'DEFAULT';
            context.reminderHelpText = 'Create the EPE default reminders: 1 day before and 8:00 AM on the day of event.';
        } else if (accountName.startsWith('Pino')) {
            context.defaultCreateReminders = true;
            context.reminderMode = 'DEFAULT';
            context.reminderHelpText = 'Create the Pino default reminders: 1 day before and 1 hour before.';
        } else if (context.sourceReminderCount != null && context.sourceReminderCount > 0) {
            context.defaultCreateReminders = false;
            context.reminderMode = 'SOURCE';
            context.reminderHelpText = 'Optionally clone ' + context.sourceReminderCount + ' reminder record(s) from the source instance.';
        } else {
            context.defaultCreateReminders = false;
            context.reminderMode = 'NONE';
            context.reminderHelpText = 'No department default reminder pattern was detected for this event.';
        }
    }

    private static String getEasternTimeZoneLabel() {
        return 'Eastern Daylight Time (America/New_York)';
    }

    private static void validateTextLength(String value, Integer maxLength, String label) {
        if (value != null && value.length() > maxLength) {
            throw new AuraHandledException(label + ' must be ' + maxLength + ' characters or fewer.');
        }
    }

    private static void validateFee(Decimal value, String label) {
        if (value != null && value > 999999.99) {
            throw new AuraHandledException(label + ' must be 999,999.99 or less.');
        }
    }

    private static void putWritable(SObject row, Map<String, Schema.SObjectField> fields, String apiName, Object value) {
        if (!fields.containsKey(apiName)) return;
        Schema.DescribeFieldResult d = fields.get(apiName).getDescribe();
        if (!d.isCreateable() || d.isCalculated()) return;
        row.put(apiName, value);
    }

    private static void putWritableDateTimeCompatible(SObject row, Map<String, Schema.SObjectField> fields, String apiName, Datetime value) {
        if (value == null || !fields.containsKey(apiName)) return;
        Schema.DescribeFieldResult d = fields.get(apiName).getDescribe();
        if (!d.isCreateable() || d.isCalculated()) return;

        Schema.DisplayType fieldType = d.getType();
        if (fieldType == Schema.DisplayType.Time) {
            row.put(apiName, value.time());
        } else if (fieldType == Schema.DisplayType.Date) {
            row.put(apiName, value.date());
        } else {
            row.put(apiName, value);
        }
    }
}
