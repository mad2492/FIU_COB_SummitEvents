public with sharing class FIU_SummitEmailSettingsController {
    private static final String CONTENT_TOKEN = '[[DONT_DELETE_CONTENT_HERE]]';
    @TestVisible private static summit__Summit_Events_Email__c mockEmailSettings;
    @TestVisible private static Map<Id, OrgWideEmailAddress> mockAllowedOrgWideEmailsById;
    @TestVisible private static Map<Id, BrandTemplate> mockActiveLetterheadsById;
    @TestVisible private static Boolean skipUpdateForTest = false;

    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String detail;

        public Option(String label, String value, String detail) {
            this.label = label;
            this.value = value;
            this.detail = detail;
        }
    }

    public class SettingsResponse {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String orgWideEmailId;
        @AuraEnabled public String orgWideEmailAddress;
        @AuraEnabled public String letterheadId;
        @AuraEnabled public String letterheadName;
        @AuraEnabled public List<Option> orgWideEmails;
        @AuraEnabled public List<Option> letterheads;
    }

    @AuraEnabled
    public static SettingsResponse getSettings(Id recordId) {
        validateRecordId(recordId);

        return loadOptions(buildSettingsResponse(getEmailSettings(recordId)));
    }

    @AuraEnabled
    public static SettingsResponse saveSettings(Id recordId, String orgWideEmailId, String letterheadId) {
        return loadOptions(saveSelections(recordId, true, orgWideEmailId, true, letterheadId));
    }

    @AuraEnabled
    public static SettingsResponse saveSelection(Id recordId, String setting, String selectionId) {
        if (setting == 'orgWideEmail') {
            return saveSelections(recordId, true, selectionId, false, null);
        }
        if (setting == 'letterhead') {
            return saveSelections(recordId, false, null, true, selectionId);
        }
        throw new AuraHandledException('Choose an email setting to update.');
    }

    private static SettingsResponse saveSelections(
        Id recordId,
        Boolean changeSender,
        String orgWideEmailId,
        Boolean changeLetterhead,
        String letterheadId
    ) {
        validateRecordId(recordId);
        summit__Summit_Events_Email__c currentSettings = getEmailSettings(recordId);
        summit__Summit_Events_Email__c updateRecord = new summit__Summit_Events_Email__c(Id = recordId);
        Boolean mockUpdate = Test.isRunningTest() && skipUpdateForTest;
        if (mockUpdate) {
            updateRecord = currentSettings.clone(true, false, false, false);
        }

        if (changeSender) {
            setSender(updateRecord, orgWideEmailId);
        }
        if (changeLetterhead) {
            setLetterhead(updateRecord, letterheadId);
        }
        if (mockUpdate) {
            mockEmailSettings = updateRecord;
            return buildSettingsResponse(updateRecord);
        }

        update as user updateRecord;
        return buildSettingsResponse(getEmailSettings(recordId));
    }

    private static void setSender(summit__Summit_Events_Email__c updateRecord, String orgWideEmailId) {
        if (String.isBlank(orgWideEmailId)) {
            updateRecord.summit__Org_Email_Id__c = null;
            updateRecord.summit__Org_Email__c = null;
        } else {
            OrgWideEmailAddress orgWideEmail = getAllowedOrgWideEmail((Id) orgWideEmailId);
            updateRecord.summit__Org_Email_Id__c = orgWideEmail.Id;
            updateRecord.summit__Org_Email__c = orgWideEmail.Address;
        }
    }

    private static void setLetterhead(summit__Summit_Events_Email__c updateRecord, String letterheadId) {
        updateRecord.summit__Letterhead__c = null;
        if (String.isBlank(letterheadId)) {
            updateRecord.summit__Letterhead_Id__c = null;
            updateRecord.summit__Letterhead_Name__c = null;
            updateRecord.summit__Letterhead_HTML__c = null;
        } else {
            BrandTemplate letterhead = getActiveLetterhead((Id) letterheadId);
            updateRecord.summit__Letterhead_Id__c = letterhead.Id;
            updateRecord.summit__Letterhead_Name__c = letterhead.Name;
            updateRecord.summit__Letterhead_HTML__c = renderLetterheadHtml(letterhead);
        }
    }

    @TestVisible
    private static List<Option> getOrgWideEmailOptions() {
        if (Test.isRunningTest() && mockAllowedOrgWideEmailsById != null) {
            List<Option> mockOptions = new List<Option>();
            for (OrgWideEmailAddress address : mockAllowedOrgWideEmailsById.values()) {
                mockOptions.add(new Option(getOrgWideEmailLabel(address), String.valueOf(address.Id), address.Address));
            }
            return mockOptions;
        }

        Set<Id> allowedIds = getAllOrgWideEmailPermissionSetIds();
        if (allowedIds.isEmpty()) {
            return new List<Option>();
        }

        List<Option> options = new List<Option>();
        for (OrgWideEmailAddress address : [
            SELECT Id, Address, DisplayName
            FROM OrgWideEmailAddress
            WHERE Id IN :allowedIds
                AND IsVerified = true
            WITH SYSTEM_MODE
            ORDER BY DisplayName, Address
        ]) {
            options.add(new Option(getOrgWideEmailLabel(address), String.valueOf(address.Id), address.Address));
        }
        return options;
    }

    @TestVisible
    private static List<Option> getLetterheadOptions() {
        List<Option> options = new List<Option>();
        if (Test.isRunningTest() && mockActiveLetterheadsById != null) {
            for (BrandTemplate letterhead : mockActiveLetterheadsById.values()) {
                options.add(new Option(letterhead.Name, String.valueOf(letterhead.Id), letterhead.DeveloperName));
            }
            return options;
        }

        for (BrandTemplate letterhead : [
            SELECT Id, Name, DeveloperName
            FROM BrandTemplate
            WHERE IsActive = true
            WITH SYSTEM_MODE
            ORDER BY Name
        ]) {
            options.add(new Option(letterhead.Name, String.valueOf(letterhead.Id), letterhead.DeveloperName));
        }
        return options;
    }

    private static OrgWideEmailAddress getAllowedOrgWideEmail(Id orgWideEmailId) {
        if (Test.isRunningTest() && mockAllowedOrgWideEmailsById != null) {
            if (!mockAllowedOrgWideEmailsById.containsKey(orgWideEmailId)) {
                throw new AuraHandledException('Choose an active org-wide email from AllOrgWideEmails.');
            }
            return mockAllowedOrgWideEmailsById.get(orgWideEmailId);
        }

        if (!getAllOrgWideEmailPermissionSetIds().contains(orgWideEmailId)) {
            throw new AuraHandledException('Choose an active org-wide email from AllOrgWideEmails.');
        }

        List<OrgWideEmailAddress> addresses = [
            SELECT Id, Address, DisplayName
            FROM OrgWideEmailAddress
            WHERE Id = :orgWideEmailId
                AND IsVerified = true
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (addresses.isEmpty()) {
            throw new AuraHandledException('Choose an active org-wide email from AllOrgWideEmails.');
        }
        return addresses[0];
    }

    private static BrandTemplate getActiveLetterhead(Id letterheadId) {
        if (Test.isRunningTest() && mockActiveLetterheadsById != null) {
            if (!mockActiveLetterheadsById.containsKey(letterheadId)) {
                throw new AuraHandledException('Choose an active classic letterhead.');
            }
            return mockActiveLetterheadsById.get(letterheadId);
        }

        List<BrandTemplate> letterheads = [
            SELECT Id, Name, Value
            FROM BrandTemplate
            WHERE Id = :letterheadId
                AND IsActive = true
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (letterheads.isEmpty()) {
            throw new AuraHandledException('Choose an active classic letterhead.');
        }
        return letterheads[0];
    }

    private static Set<Id> getAllOrgWideEmailPermissionSetIds() {
        if (Test.isRunningTest() && mockAllowedOrgWideEmailsById != null) {
            return mockAllowedOrgWideEmailsById.keySet();
        }

        // Use the existing sender allowlist without requiring Setup access from staff.
        Set<Id> orgWideEmailIds = new Set<Id>();
        for (SetupEntityAccess access : [
            SELECT SetupEntityId
            FROM SetupEntityAccess
            WHERE Parent.Name = 'AllOrgWideEmails'
                AND SetupEntityType = 'OrgWideEmailAddress'
            WITH SYSTEM_MODE
        ]) {
            orgWideEmailIds.add(access.SetupEntityId);
        }
        return orgWideEmailIds;
    }

    @TestVisible
    private static String renderLetterheadHtml(BrandTemplate letterhead) {
        if (letterhead == null || String.isBlank(letterhead.Value)) {
            return null;
        }

        String bodyColor = getStyleAttribute(letterhead.Value, 'body', 'background-color', '#FFFFFF');
        SectionStyle header = getSectionStyle(letterhead.Value, 'header');
        SectionStyle accent1 = getSectionStyle(letterhead.Value, 'accent1');
        SectionStyle main = getSectionStyle(letterhead.Value, 'main');
        SectionStyle accent2 = getSectionStyle(letterhead.Value, 'accent2');
        SectionStyle footer = getSectionStyle(letterhead.Value, 'footer');
        SectionStyle accent3 = getSectionStyle(letterhead.Value, 'accent3');
        String headerImage = getImageSource(letterhead.Value, 'headerImage');
        String footerImage = getImageSource(letterhead.Value, 'footerImage');

        List<String> lines = new List<String>{
            '<html>',
            '<style> p { margin-top: 0px; margin-bottom: 0px;} </style>',
            '<body  id="body"  style=" background-color:' + bodyColor + ';  color:' + bodyColor + '; " >',
            '<center>',
            '<table cellpadding="0" width="500" cellspacing="0" height="450">',
            '    <tr valign="top">',
            '        <td  id="header"  style=" background-color:' + header.backgroundColor + ';  color:' + header.backgroundColor + ';  height:' + header.height + '; " >',
            imageTag(headerImage) + '        </td>',
            '    </tr>',
            accentRow('accent1', accent1),
            '<tr valign="top">',
            '<td height="300"  style=" background-color:' + main.backgroundColor + ';  font-family:' + main.fontFamily + ';  font-size:' + main.fontSize + ';  color:' + main.color + '; " >',
            '<table border="0" cellpadding="5" width="550" cellspacing="5" height="400">',
            '<tr valign="top" height="400">',
            '<td  id="main"  style=" background-color:' + main.backgroundColor + ';  font-family:' + main.fontFamily + ';  font-size:' + main.fontSize + ';  color:' + main.color + '; " >',
            CONTENT_TOKEN,
            '</td>',
            '</tr>',
            '</table>',
            '</td>',
            '</tr>',
            accentRow('accent2', accent2),
            '    <tr valign="top">',
            '        <td  id="footer"  style=" background-color:' + footer.backgroundColor + ';  color:' + footer.backgroundColor + ';  height:' + footer.height + '; " >',
            imageTag(footerImage) + '        </td>',
            '    </tr>',
            accentRow('accent3', accent3),
            '</table>',
            '</center>',
            '</body>'
        };
        return String.join(lines, '\n');
    }

    private static void validateRecordId(Id recordId) {
        if (recordId == null || recordId.getSObjectType() != summit__Summit_Events_Email__c.SObjectType) {
            throw new AuraHandledException('Open this picker from a Summit Events Email record.');
        }
    }

    private static summit__Summit_Events_Email__c getEmailSettings(Id recordId) {
        if (Test.isRunningTest() && mockEmailSettings != null) {
            return mockEmailSettings;
        }

        return [
            SELECT Id,
                summit__Org_Email_Id__c,
                summit__Org_Email__c,
                summit__Letterhead_Id__c,
                summit__Letterhead_Name__c
            FROM summit__Summit_Events_Email__c
            WHERE Id = :recordId
            WITH USER_MODE
            LIMIT 1
        ];
    }

    private static SettingsResponse buildSettingsResponse(summit__Summit_Events_Email__c emailSettings) {
        SettingsResponse response = new SettingsResponse();
        response.recordId = emailSettings.Id;
        response.orgWideEmailId = emailSettings.summit__Org_Email_Id__c;
        response.orgWideEmailAddress = emailSettings.summit__Org_Email__c;
        response.letterheadId = emailSettings.summit__Letterhead_Id__c;
        response.letterheadName = emailSettings.summit__Letterhead_Name__c;
        return response;
    }

    private static SettingsResponse loadOptions(SettingsResponse response) {
        // A null list means its lookup failed. An empty list means there were no choices.
        try {
            response.orgWideEmails = getOrgWideEmailOptions();
        } catch (QueryException e) {
            response.orgWideEmails = null;
        }
        try {
            response.letterheads = getLetterheadOptions();
        } catch (QueryException e) {
            response.letterheads = null;
        }
        return response;
    }

    private static String getOrgWideEmailLabel(OrgWideEmailAddress address) {
        if (String.isBlank(address.DisplayName)) {
            return address.Address;
        }
        return address.DisplayName + ' <' + address.Address + '>';
    }

    private static SectionStyle getSectionStyle(String value, String label) {
        SectionStyle style = new SectionStyle();
        style.backgroundColor = getStyleAttribute(value, label, 'background-color', '#FFFFFF');
        style.color = getStyleAttribute(value, label, 'color', '#000000');
        style.height = normalizeHeight(getStyleAttribute(value, label, 'height', '0'));
        style.fontFamily = getStyleAttribute(value, label, 'font-family', 'arial');
        style.fontSize = getStyleAttribute(value, label, 'font-size', '12pt');
        return style;
    }

    private static String getStyleAttribute(String value, String label, String attributeName, String defaultValue) {
        String styleTag = getTagByLabel(value, 'style', label);
        if (String.isBlank(styleTag)) {
            return defaultValue;
        }

        Matcher matcher = Pattern.compile(attributeName + '="([^"]*)"').matcher(styleTag);
        return matcher.find() && String.isNotBlank(matcher.group(1)) ? matcher.group(1) : defaultValue;
    }

    private static String getImageSource(String value, String label) {
        String imageTag = getTagByLabel(value, 'img', label);
        if (String.isBlank(imageTag)) {
            return '';
        }

        Integer startIndex = value.indexOf(imageTag) + imageTag.length();
        Integer endIndex = value.indexOf('</img>', startIndex);
        if (endIndex <= startIndex) {
            return '';
        }

        String rawContent = value.substring(startIndex, endIndex);
        rawContent = rawContent.replace('<![CDATA[', '').replace(']]>', '').trim();
        if (String.isBlank(rawContent)) {
            return '';
        }
        if (rawContent.startsWith('http')) {
            return rawContent;
        }
        return URL.getOrgDomainUrl().toExternalForm() + rawContent;
    }

    private static String getTagByLabel(String value, String tagName, String label) {
        Matcher matcher = Pattern.compile('<' + tagName + '\\s+[^>]*bLabel="' + label + '"[^>]*>').matcher(value);
        return matcher.find() ? matcher.group(0) : null;
    }

    private static String imageTag(String source) {
        if (String.isBlank(source)) {
            return '';
        }
        return '<img src="' + source.escapeHtml4() + '"/>';
    }

    private static String accentRow(String id, SectionStyle style) {
        return '<tr valign="top">\n'
            + '<td  id="' + id + '"  style=" background-color:' + style.backgroundColor + ';  color:' + style.backgroundColor + ';  height:' + style.height + '; " >\n'
            + '</tr>';
    }

    private static String normalizeHeight(String height) {
        if (String.isBlank(height)) {
            return '0px';
        }
        return height.endsWith('px') ? height : height + 'px';
    }

    private class SectionStyle {
        String backgroundColor = '#FFFFFF';
        String color = '#000000';
        String height = '0px';
        String fontFamily = 'arial';
        String fontSize = '12pt';
    }
}
