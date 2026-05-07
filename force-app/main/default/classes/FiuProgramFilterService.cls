public with sharing class FiuProgramFilterService {
    public class ProgramOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class ProgramFilterConfig {
        public List<String> eventProgramFields = new List<String>();
        public Boolean hasDefaultPlanLookup = false;
        public Map<String, String> codeToName = new Map<String, String>();
    }

    @AuraEnabled(cacheable=true)
    public static List<ProgramOption> getProgramOptions() {
        ProgramFilterConfig config = getConfig();
        if (config.eventProgramFields.isEmpty()) return new List<ProgramOption>();

        Set<Id> allowedRt = FiuEventsAccessService.getAllowedEventRecordTypeIds();
        if (allowedRt.isEmpty()) return new List<ProgramOption>();

        String eventObject = FiuEventsAccessService.resolveEventObject();
        List<String> selectFields = new List<String>(config.eventProgramFields);
        if (config.hasDefaultPlanLookup) selectFields.add('Default_Plan__r.Plan_Code__c');
        String soql = 'SELECT ' + String.join(selectFields, ',') + ' FROM ' + eventObject + ' WHERE RecordTypeId IN :allowedRt LIMIT 5000';

        Set<String> usedCodes = new Set<String>();
        for (SObject row : Database.query(soql)) {
            usedCodes.addAll(extractProgramCodesFromEvent(row, config));
        }

        List<String> sortedCodes = new List<String>(usedCodes);
        sortedCodes.sort();

        List<ProgramOption> options = new List<ProgramOption>();
        for (String code : sortedCodes) {
            ProgramOption option = new ProgramOption();
            option.value = code;
            option.label = config.codeToName.containsKey(code) ? config.codeToName.get(code) + ' (' + code + ')' : code;
            options.add(option);
        }
        return options;
    }

    public static ProgramFilterConfig getConfig() {
        ProgramFilterConfig config = new ProgramFilterConfig();
        String eventObject = FiuEventsAccessService.resolveEventObject();
        if (eventObject == null) return config;

        Map<String, Schema.SObjectField> eventFields = Schema.getGlobalDescribe().get(eventObject).getDescribe().fields.getMap();
        for (String candidate : new List<String>{ 'summit__Program_Filter__c', 'summit__Program_Filter_2__c', 'summit__Program_Filter_3__c' }) {
            if (eventFields.containsKey(candidate)) config.eventProgramFields.add(candidate);
        }
        config.hasDefaultPlanLookup = eventFields.containsKey('Default_Plan__c');
        if (config.eventProgramFields.isEmpty() && !config.hasDefaultPlanLookup) return config;

        Schema.SObjectType planType = Schema.getGlobalDescribe().get('Plan__c');
        if (planType == null) return config;
        Map<String, Schema.SObjectField> planFields = planType.getDescribe().fields.getMap();
        if (!planFields.containsKey('Plan_Code__c') || !planFields.containsKey('Name')) return config;

        for (SObject plan : Database.query('SELECT Name, Plan_Code__c FROM Plan__c WHERE Plan_Code__c != NULL LIMIT 5000')) {
            String code = normalizeCode((String) plan.get('Plan_Code__c'));
            if (!String.isBlank(code) && !config.codeToName.containsKey(code)) {
                config.codeToName.put(code, (String) plan.get('Name'));
            }
        }
        return config;
    }

    public static String buildProgramWhereClause(String eventPathPrefix, String selectedProgramCode, ProgramFilterConfig config) {
        if (String.isBlank(selectedProgramCode) || config == null) return null;
        if (config.eventProgramFields.isEmpty() && !config.hasDefaultPlanLookup) return null;

        String normalizedCode = String.escapeSingleQuotes(selectedProgramCode.trim());
        List<String> predicates = new List<String>();
        for (String fieldApi : config.eventProgramFields) {
            predicates.add(
                '(' +
                eventPathPrefix + fieldApi + ' = \'' + normalizedCode + '\'' +
                ' OR ' + eventPathPrefix + fieldApi + ' LIKE \'' + normalizedCode + ',%\'' +
                ' OR ' + eventPathPrefix + fieldApi + ' LIKE \'%,' + normalizedCode + ',%\'' +
                ' OR ' + eventPathPrefix + fieldApi + ' LIKE \'%,' + normalizedCode + '\'' +
                ' OR ' + eventPathPrefix + fieldApi + ' LIKE \'' + normalizedCode + ', %\'' +
                ' OR ' + eventPathPrefix + fieldApi + ' LIKE \'%, ' + normalizedCode + ',%\'' +
                ' OR ' + eventPathPrefix + fieldApi + ' LIKE \'%, ' + normalizedCode + '\'' +
                ')'
            );
        }
        if (config.hasDefaultPlanLookup) {
            predicates.add(eventPathPrefix + 'Default_Plan__r.Plan_Code__c = \'' + normalizedCode + '\'');
        }
        return '(' + String.join(predicates, ' OR ') + ')';
    }

    public static Set<String> extractProgramCodesFromEvent(SObject eventRecord, ProgramFilterConfig config) {
        Set<String> codes = new Set<String>();
        if (eventRecord == null || config == null) return codes;

        for (String fieldApi : config.eventProgramFields) {
            String raw = (String) eventRecord.get(fieldApi);
            if (String.isBlank(raw)) continue;
            for (String token : raw.split('[,;\\n]')) {
                String normalized = normalizeCode(token);
                if (!String.isBlank(normalized)) codes.add(normalized);
            }
        }

        if (config.hasDefaultPlanLookup) {
            SObject defaultPlan = eventRecord.getSObject('Default_Plan__r');
            if (defaultPlan != null) {
                String normalized = normalizeCode((String) defaultPlan.get('Plan_Code__c'));
                if (!String.isBlank(normalized)) codes.add(normalized);
            }
        }
        return codes;
    }

    public static Boolean eventMatchesSelectedProgram(SObject eventRecord, ProgramFilterConfig config, String selectedProgramCode) {
        String selectedNormalized = normalizeCode(selectedProgramCode);
        if (String.isBlank(selectedNormalized)) return true;
        Set<String> codes = extractProgramCodesFromEvent(eventRecord, config);
        return codes.contains(selectedNormalized);
    }

    public static String normalizeCode(String raw) {
        if (String.isBlank(raw)) return null;
        String out = raw.trim().toUpperCase();
        while (!String.isBlank(out) && (out.endsWith(',') || out.endsWith(';'))) {
            out = out.substring(0, out.length() - 1).trim();
        }
        return String.isBlank(out) ? null : out;
    }
}
