trigger FiuEventReadinessRecalc on summit__Summit_Events__c (after insert, after update) {
    if (FiuReadinessRecalcService.isInternalUpdateInProgress()) return;
    Set<Id> eventIds = new Set<Id>();
    for (summit__Summit_Events__c row : Trigger.new) {
        eventIds.add(row.Id);
    }
    FiuReadinessRecalcService.enqueueForEvents(eventIds);
}
