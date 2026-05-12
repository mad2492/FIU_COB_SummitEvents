Integer eventChunkSize = 200;
List<Id> eventBuffer = new List<Id>();
Integer eventEnqueued = 0;

for (summit__Summit_Events__c evt : [
    SELECT Id
    FROM summit__Summit_Events__c
    ORDER BY CreatedDate ASC
    LIMIT 50000
]) {
    eventBuffer.add(evt.Id);
    if (eventBuffer.size() == eventChunkSize) {
        FiuReadinessRecalcService.enqueueForEvents(new Set<Id>(eventBuffer));
        eventEnqueued++;
        eventBuffer.clear();
    }
}
if (!eventBuffer.isEmpty()) {
    FiuReadinessRecalcService.enqueueForEvents(new Set<Id>(eventBuffer));
    eventEnqueued++;
}

Integer instanceChunkSize = 200;
List<Id> instanceBuffer = new List<Id>();
Integer instanceEnqueued = 0;

for (summit__Summit_Events_Instance__c inst : [
    SELECT Id
    FROM summit__Summit_Events_Instance__c
    ORDER BY CreatedDate ASC
    LIMIT 50000
]) {
    instanceBuffer.add(inst.Id);
    if (instanceBuffer.size() == instanceChunkSize) {
        FiuReadinessRecalcService.enqueueForInstances(new Set<Id>(instanceBuffer));
        instanceEnqueued++;
        instanceBuffer.clear();
    }
}
if (!instanceBuffer.isEmpty()) {
    FiuReadinessRecalcService.enqueueForInstances(new Set<Id>(instanceBuffer));
    instanceEnqueued++;
}

System.debug(LoggingLevel.WARN, 'FIU Backfill enqueued event jobs: ' + eventEnqueued + ', instance jobs: ' + instanceEnqueued);
