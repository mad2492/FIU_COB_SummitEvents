trigger FiuInstanceReadinessRecalc on summit__Summit_Events_Instance__c (after insert, after update) {
    if (FiuReadinessRecalcService.isInternalUpdateInProgress()) return;
    Set<Id> instanceIds = new Set<Id>();
    for (summit__Summit_Events_Instance__c row : Trigger.new) {
        instanceIds.add(row.Id);
    }
    FiuReadinessRecalcService.enqueueForInstances(instanceIds);
}
