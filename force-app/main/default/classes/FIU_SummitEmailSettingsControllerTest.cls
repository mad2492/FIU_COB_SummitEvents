@IsTest
private class FIU_SummitEmailSettingsControllerTest {
    @IsTest
    static void getAndSaveSettingsUseConfiguredOptions() {
        Id emailSettingsId = fakeId(summit__Summit_Events_Email__c.SObjectType);
        Id orgWideEmailId = fakeId(OrgWideEmailAddress.SObjectType);
        Id letterheadId = fakeId(BrandTemplate.SObjectType);
        FIU_SummitEmailSettingsController.mockEmailSettings = new summit__Summit_Events_Email__c(
            Id = emailSettingsId,
            summit__Org_Email_Id__c = null,
            summit__Org_Email__c = null,
            summit__Letterhead_Id__c = null,
            summit__Letterhead_Name__c = null
        );
        FIU_SummitEmailSettingsController.mockAllowedOrgWideEmailsById = new Map<Id, OrgWideEmailAddress>{
            orgWideEmailId => new OrgWideEmailAddress(
                Id = orgWideEmailId,
                Address = 'events@fiu.edu',
                DisplayName = 'FIU Events'
            )
        };
        FIU_SummitEmailSettingsController.mockActiveLetterheadsById = new Map<Id, BrandTemplate>{
            letterheadId => new BrandTemplate(
                Id = letterheadId,
                Name = 'FIU Classic Letterhead',
                DeveloperName = 'FIU_Classic_Letterhead',
                Value = sampleBrandTemplateValue()
            )
        };
        FIU_SummitEmailSettingsController.skipUpdateForTest = true;

        Test.startTest();
        FIU_SummitEmailSettingsController.SettingsResponse initialSettings =
            FIU_SummitEmailSettingsController.getSettings(emailSettingsId);
        FIU_SummitEmailSettingsController.SettingsResponse savedSettings =
            FIU_SummitEmailSettingsController.saveSettings(
                emailSettingsId,
                String.valueOf(orgWideEmailId),
                String.valueOf(letterheadId)
            );
        FIU_SummitEmailSettingsController.SettingsResponse clearedSettings =
            FIU_SummitEmailSettingsController.saveSettings(emailSettingsId, null, null);
        Test.stopTest();

        System.assertEquals(emailSettingsId, initialSettings.recordId);
        System.assert(!initialSettings.orgWideEmails.isEmpty(), 'Org-wide email options should be returned.');
        System.assert(!initialSettings.letterheads.isEmpty(), 'Letterhead options should be returned.');
        System.assertEquals(String.valueOf(orgWideEmailId), savedSettings.orgWideEmailId);
        System.assertEquals('events@fiu.edu', savedSettings.orgWideEmailAddress);
        System.assertEquals(String.valueOf(letterheadId), savedSettings.letterheadId);
        System.assertEquals('FIU Classic Letterhead', savedSettings.letterheadName);
        System.assertEquals(null, clearedSettings.orgWideEmailId);
        System.assertEquals(null, clearedSettings.letterheadId);
    }

    @IsTest
    static void savingOneChoicePreservesTheOtherSavedChoice() {
        Id emailSettingsId = fakeId(summit__Summit_Events_Email__c.SObjectType);
        Id orgWideEmailId = fakeId(OrgWideEmailAddress.SObjectType);
        Id letterheadId = fakeId(BrandTemplate.SObjectType);
        FIU_SummitEmailSettingsController.mockEmailSettings = new summit__Summit_Events_Email__c(
            Id = emailSettingsId,
            summit__Org_Email_Id__c = String.valueOf(orgWideEmailId),
            summit__Org_Email__c = 'events@example.com',
            summit__Letterhead_Id__c = String.valueOf(letterheadId),
            summit__Letterhead_Name__c = 'Previously selected letterhead',
            summit__Letterhead_HTML__c = '<html>Previously saved letterhead</html>'
        );
        FIU_SummitEmailSettingsController.mockAllowedOrgWideEmailsById = new Map<Id, OrgWideEmailAddress>{
            orgWideEmailId => new OrgWideEmailAddress(Id = orgWideEmailId, Address = 'events@example.com')
        };
        FIU_SummitEmailSettingsController.mockActiveLetterheadsById = new Map<Id, BrandTemplate>();
        FIU_SummitEmailSettingsController.skipUpdateForTest = true;

        Test.startTest();
        FIU_SummitEmailSettingsController.SettingsResponse clearedSender =
            FIU_SummitEmailSettingsController.saveSelection(emailSettingsId, 'orgWideEmail', null);
        String retainedLetterheadHtml =
            FIU_SummitEmailSettingsController.mockEmailSettings.summit__Letterhead_HTML__c;
        FIU_SummitEmailSettingsController.saveSelection(emailSettingsId, 'orgWideEmail', String.valueOf(orgWideEmailId));
        FIU_SummitEmailSettingsController.SettingsResponse clearedLetterhead =
            FIU_SummitEmailSettingsController.saveSelection(emailSettingsId, 'letterhead', null);
        Test.stopTest();

        System.assertEquals(null, clearedSender.orgWideEmailId, 'The sender should be cleared.');
        System.assertEquals(String.valueOf(letterheadId), clearedSender.letterheadId, 'An existing letterhead can be retained even if it is outside the choices.');
        System.assertEquals('<html>Previously saved letterhead</html>', retainedLetterheadHtml, 'The saved letterhead HTML should be preserved.');
        System.assertEquals(String.valueOf(orgWideEmailId), clearedLetterhead.orgWideEmailId, 'The saved sender should be preserved.');
        System.assertEquals(null, clearedLetterhead.letterheadId, 'The letterhead should be cleared.');
    }

    // SetupEntityAccess, OrgWideEmailAddress, and BrandTemplate cannot be seeded with test DML.
    @IsTest(SeeAllData=true)
    static void setupLookupsWorkWithoutViewSetup() {
        PermissionSet profilePermissions = [
            SELECT ProfileId, PermissionsViewSetup
            FROM PermissionSet
            WHERE IsOwnedByProfile = true AND Profile.Name = 'Minimum Access - Salesforce'
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        System.assertEquals(false, profilePermissions.PermissionsViewSetup, 'The test profile must not grant View Setup.');
        User staff = new User(
            LastName = 'Summit Picker Test',
            Alias = 'smpick',
            Email = 'summit-picker@example.com',
            Username = 'summit-picker-' + UserInfo.getOrganizationId() + '-' + System.now().getTime() + '@example.com',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profilePermissions.ProfileId
        );
        insert as system staff;
        Integer expectedSenderCount = FIU_SummitEmailSettingsController.getOrgWideEmailOptions().size();
        Integer expectedLetterheadCount = FIU_SummitEmailSettingsController.getLetterheadOptions().size();

        Test.startTest();
        System.runAs(staff) {
            System.assertEquals(
                expectedSenderCount,
                FIU_SummitEmailSettingsController.getOrgWideEmailOptions().size(),
                'Staff should see the same allowlisted sender choices without Setup access.'
            );
            System.assertEquals(
                expectedLetterheadCount,
                FIU_SummitEmailSettingsController.getLetterheadOptions().size(),
                'Staff should see active letterhead choices without Setup access.'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void renderLetterheadHtmlConvertsBrandTemplateValue() {
        BrandTemplate letterhead = new BrandTemplate(
            Name = 'Test Letterhead',
            Value = sampleBrandTemplateValue()
        );

        Test.startTest();
        String html = FIU_SummitEmailSettingsController.renderLetterheadHtml(letterhead);
        Test.stopTest();

        System.assert(html.contains('[[DONT_DELETE_CONTENT_HERE]]'), 'Rendered HTML should preserve Summit content token.');
        System.assert(html.contains('background-color:#CCCCCC'), 'Rendered HTML should include body background color.');
        System.assert(html.contains('/servlet/servlet.ImageServer?id=015TEST'), 'Rendered HTML should include the letterhead image path.');
        System.assert(html.contains('id="footer"'), 'Rendered HTML should include the footer section.');
    }

    @IsTest
    static void renderLetterheadHtmlHandlesBlankValue() {
        System.assertEquals(null, FIU_SummitEmailSettingsController.renderLetterheadHtml(new BrandTemplate(Name = 'Blank')));
    }

    private static Id fakeId(Schema.SObjectType objectType) {
        return (Id) (objectType.getDescribe().getKeyPrefix() + '000000000001');
    }

    private static String sampleBrandTemplateValue() {
        return '<body class="setupTab" >'
            + '<style background-color="#CCCCCC" bEditID="b1st1" bLabel="body" ></style>'
            + '<style background-color="#FFFFFF" bEditID="r1st1" bLabel="header" vertical-align="top" height="100px" text-align="left" ></style>'
            + '<img border="0" bEditID="r1sp1" bLabel="headerImage" id="r1sp1"><![CDATA[/servlet/servlet.ImageServer?id=015TEST&oid=00DTEST]]></img>'
            + '<style background-color="#FFFFFF" bEditID="r2st1" bLabel="accent1" height="0px" ></style>'
            + '<style background-color="#FFFFFF" bEditID="r3st1" color="#000000" bLabel="main" font-size="12pt" font-family="arial" ></style>'
            + '<style background-color="#B6862C" bEditID="r4st1" bLabel="accent2" height="5px" ></style>'
            + '<style background-color="#081E3F" bEditID="r5st1" bLabel="footer" vertical-align="top" height="100px" text-align="center" ></style>'
            + '<img border="0" bEditID="r5sp1" bLabel="footerImage" id="r5sp1"><![CDATA[]]></img>'
            + '<style background-color="#FFFFFF" bEditID="r6st1" bLabel="accent3" height="0px" ></style>'
            + '</body>';
    }
}
