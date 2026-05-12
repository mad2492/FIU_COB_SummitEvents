String eventObject = Schema.getGlobalDescribe().containsKey('summit__Summit_Events__c')
    ? 'summit__Summit_Events__c'
    : null;

System.debug('Summit Events 0.37 preflight started.');

for (PackageLicense pkg : [
    SELECT NamespacePrefix, Status
    FROM PackageLicense
    WHERE NamespacePrefix = 'summit'
]) {
    System.debug('Installed package namespace=' + pkg.NamespacePrefix + ', status=' + pkg.Status);
}

if (eventObject == null) {
    System.debug('No managed Summit Events object found.');
} else {
    Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe().get(eventObject).getDescribe().fields.getMap();
    List<String> richTextFields = new List<String>{
        'summit__Event_description__c',
        'summit__Event_Short_Listing_Description__c',
        'summit__Event_Footer__c',
        'summit__Event_Full_Text__c',
        'summit__Event_Additional_Questions_Description__c',
        'summit__Event_Confirmation_Description__c'
    };
    List<String> selectFields = new List<String>{ 'Id', 'Name' };
    if (fields.containsKey('summit__Event_Status__c')) selectFields.add('summit__Event_Status__c');
    for (String fieldName : richTextFields) {
        if (fields.containsKey(fieldName)) selectFields.add(fieldName);
    }

    String soql =
        'SELECT ' + String.join(selectFields, ',') +
        ' FROM ' + eventObject +
        (fields.containsKey('summit__Event_Status__c') ? ' WHERE summit__Event_Status__c = \'Active\'' : '') +
        ' ORDER BY LastModifiedDate DESC LIMIT 500';

    Integer scanned = 0;
    Integer flagged = 0;
    for (SObject eventRow : Database.query(soql)) {
        scanned++;
        List<String> affectedFields = new List<String>();
        for (String fieldName : richTextFields) {
            if (!fields.containsKey(fieldName)) continue;
            if (FiuEventsReadinessService.hasSalesforceHostedRichTextImage((String) eventRow.get(fieldName))) {
                affectedFields.add(fieldName);
            }
        }
        if (!affectedFields.isEmpty()) {
            flagged++;
            System.debug('Review public rich-text images: ' + eventRow.get('Name') + ' (' + eventRow.get('Id') + ') fields=' + String.join(affectedFields, ','));
        }
    }
    System.debug('Scanned active events=' + scanned + ', events needing rich-text image review=' + flagged);
}

System.debug('Summit Events 0.37 preflight finished.');
