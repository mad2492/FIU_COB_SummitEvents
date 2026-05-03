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
}
