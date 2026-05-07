public with sharing class FiuEventsAccessService {
    public static Set<Id> getAllowedEventRecordTypeIds() {
        Set<Id> allowed = new Set<Id>();
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        String eventObjectName = gd.containsKey('summit__Summit_Events__c') ? 'summit__Summit_Events__c' : (gd.containsKey('summit__Summit_Event__c') ? 'summit__Summit_Event__c' : null);
        if (eventObjectName == null) {
            return allowed;
        }

        Schema.DescribeSObjectResult d = gd.get(eventObjectName).getDescribe();
        for (Schema.RecordTypeInfo rti : d.getRecordTypeInfos()) {
            if (rti.isAvailable()) {
                allowed.add(rti.getRecordTypeId());
            }
        }
        return allowed;
    }

    public static String resolveEventObject() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey('summit__Summit_Events__c')) return 'summit__Summit_Events__c';
        if (gd.containsKey('summit__Summit_Event__c')) return 'summit__Summit_Event__c';
        if (gd.containsKey('summit__Event__c')) return 'summit__Event__c';
        return null;
    }

    public static String resolveEventPreviewField() {
        String eventObjectName = resolveEventObject();
        if (eventObjectName == null) return null;
        Schema.SObjectType eventType = Schema.getGlobalDescribe().get(eventObjectName);
        if (eventType == null) return null;
        Map<String, Schema.SObjectField> fields = eventType.getDescribe().fields.getMap();
        if (fields.containsKey('Preview_Event__c')) return 'Preview_Event__c';
        if (fields.containsKey('Is_Preview__c')) return 'Is_Preview__c';
        return null;
    }

    public static String resolveEventUrlField() {
        String eventObjectName = resolveEventObject();
        if (eventObjectName == null) return null;
        Schema.SObjectType eventType = Schema.getGlobalDescribe().get(eventObjectName);
        if (eventType == null) return null;
        Map<String, Schema.SObjectField> fields = eventType.getDescribe().fields.getMap();
        if (fields.containsKey('summit__Event_URL__c')) return 'summit__Event_URL__c';
        if (fields.containsKey('Event_URL__c')) return 'Event_URL__c';
        return null;
    }

    public static String resolveEventQuestionObject() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey('summit__Summit_Events_Question__c')) return 'summit__Summit_Events_Question__c';
        if (gd.containsKey('summit__Summit_Events_Questions__c')) return 'summit__Summit_Events_Questions__c';
        if (gd.containsKey('summit__Summit_Event_Questions__c')) return 'summit__Summit_Event_Questions__c';
        if (gd.containsKey('summit__Event_Questions__c')) return 'summit__Event_Questions__c';
        return null;
    }

    public static String resolveEventQuestionLookupField() {
        String questionObject = resolveEventQuestionObject();
        if (questionObject == null) return null;
        Schema.SObjectType qType = Schema.getGlobalDescribe().get(questionObject);
        if (qType == null) return null;
        Map<String, Schema.SObjectField> fields = qType.getDescribe().fields.getMap();
        if (fields.containsKey('summit__Event__c')) return 'summit__Event__c';
        if (fields.containsKey('summit__Summit_Event__c')) return 'summit__Summit_Event__c';
        if (fields.containsKey('Event__c')) return 'Event__c';
        return null;
    }

    public static String resolveInstanceObject() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey('summit__Summit_Events_Instance__c')) return 'summit__Summit_Events_Instance__c';
        if (gd.containsKey('summit__Summit_Event_Instance__c')) return 'summit__Summit_Event_Instance__c';
        if (gd.containsKey('summit__Event_Instance__c')) return 'summit__Event_Instance__c';
        return null;
    }

    public static String resolveInstancePreviewField() {
        String instanceObjectName = resolveInstanceObject();
        if (instanceObjectName == null) return null;
        Schema.SObjectType instanceType = Schema.getGlobalDescribe().get(instanceObjectName);
        if (instanceType == null) return null;
        Map<String, Schema.SObjectField> fields = instanceType.getDescribe().fields.getMap();
        if (fields.containsKey('Preview_Instance__c')) return 'Preview_Instance__c';
        if (fields.containsKey('Is_Preview__c')) return 'Is_Preview__c';
        return null;
    }
}
