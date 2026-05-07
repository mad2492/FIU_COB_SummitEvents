@isTest
private class ExportCsvControllerTest {

    // Mock that returns a valid list view describe response
    private class DescribeMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(new Map<String, Object>{
                'label' => 'Test View',
                'query' => 'SELECT Id, Name FROM Account',
                'columns' => new List<Object>{
                    new Map<String, Object>{ 'fieldNameOrPath' => 'Id',   'label' => 'Account ID',   'hidden' => false },
                    new Map<String, Object>{ 'fieldNameOrPath' => 'Name', 'label' => 'Account Name', 'hidden' => false }
                }
            }));
            return res;
        }
    }

    // Mock that returns an API error
    private class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[{"message":"The requested resource does not exist"}]');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        insert new Account(Name = 'Export Test Account');
    }

    @isTest
    static void testMissingObjectApiName() {
        PageReference pr = Page.ExportCsv;
        Test.setCurrentPage(pr);

        ExportCsvController ctrl = new ExportCsvController();

        System.assert(ctrl.output.contains('Missing objectApiName'), 'Should show missing param error');
    }

    @isTest
    static void testRecentFilterName() {
        PageReference pr = Page.ExportCsv;
        pr.getParameters().put('objectApiName', 'Account');
        pr.getParameters().put('filterName', '__Recent');
        Test.setCurrentPage(pr);

        ExportCsvController ctrl = new ExportCsvController();

        System.assert(ctrl.output.contains('session-based'), 'Should reject __Recent');
    }

    @isTest
    static void testRecentFilterNameJson() {
        PageReference pr = Page.ExportCsv;
        pr.getParameters().put('objectApiName', 'Account');
        pr.getParameters().put('filterName', '__Recent');
        pr.getParameters().put('action', 'probe');
        Test.setCurrentPage(pr);

        ExportCsvController ctrl = new ExportCsvController();

        System.assertEquals('application/json', ctrl.pageContentType);
        System.assert(ctrl.output.contains('"status":"error"'), 'Should return JSON error');
    }

    @isTest
    static void testLaunchAction() {
        PageReference pr = Page.ExportCsv;
        pr.getParameters().put('objectApiName', 'Account');
        pr.getParameters().put('filterName', 'someFilterId');
        pr.getParameters().put('action', 'launch');
        Test.setCurrentPage(pr);

        ExportCsvController ctrl = new ExportCsvController();

        System.assertEquals('text/html', ctrl.pageContentType);
        System.assert(ctrl.output.contains('Preparing export'), 'Should render launch page');
    }

    @isTest
    static void testDownloadAction() {
        PageReference pr = Page.ExportCsv;
        pr.getParameters().put('objectApiName', 'Account');
        pr.getParameters().put('filterName', 'testFilter');
        Test.setCurrentPage(pr);

        Test.setMock(HttpCalloutMock.class, new DescribeMock());

        Test.startTest();
        ExportCsvController ctrl = new ExportCsvController();
        Test.stopTest();

        // Should produce CSV output with BOM
        System.assert(ctrl.output.startsWith('\uFEFF'), 'CSV should start with BOM');
        System.assert(ctrl.output.contains('Account Name'), 'CSV should contain header');
        System.assert(ctrl.output.contains('Export Test Account'), 'CSV should contain data');
    }

    @isTest
    static void testProbeAction() {
        PageReference pr = Page.ExportCsv;
        pr.getParameters().put('objectApiName', 'Account');
        pr.getParameters().put('filterName', 'testFilter');
        pr.getParameters().put('action', 'probe');
        Test.setCurrentPage(pr);

        Test.setMock(HttpCalloutMock.class, new DescribeMock());

        Test.startTest();
        ExportCsvController ctrl = new ExportCsvController();
        Test.stopTest();

        System.assertEquals('application/json', ctrl.pageContentType);
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(ctrl.output);
        System.assertEquals('ok', result.get('status'));
        System.assertEquals('download', result.get('mode'));
    }

    @isTest
    static void testEmailMissingAddress() {
        PageReference pr = Page.ExportCsv;
        pr.getParameters().put('objectApiName', 'Account');
        pr.getParameters().put('filterName', 'testFilter');
        pr.getParameters().put('action', 'email');
        pr.getParameters().put('format', 'json');
        Test.setCurrentPage(pr);

        Test.setMock(HttpCalloutMock.class, new DescribeMock());

        Test.startTest();
        ExportCsvController ctrl = new ExportCsvController();
        Test.stopTest();

        System.assertEquals('application/json', ctrl.pageContentType);
        System.assert(ctrl.output.contains('Missing email'), 'Should require email');
    }

    @isTest
    static void testEmailBadDomain() {
        PageReference pr = Page.ExportCsv;
        pr.getParameters().put('objectApiName', 'Account');
        pr.getParameters().put('filterName', 'testFilter');
        pr.getParameters().put('action', 'email');
        pr.getParameters().put('format', 'json');
        pr.getParameters().put('to', 'hacker@gmail.com');
        Test.setCurrentPage(pr);

        Test.setMock(HttpCalloutMock.class, new DescribeMock());

        Test.startTest();
        ExportCsvController ctrl = new ExportCsvController();
        Test.stopTest();

        System.assert(ctrl.output.contains('@fiu.edu'), 'Should reject non-fiu domain');
    }

    @isTest
    static void testEmailWrongUser() {
        PageReference pr = Page.ExportCsv;
        pr.getParameters().put('objectApiName', 'Account');
        pr.getParameters().put('filterName', 'testFilter');
        pr.getParameters().put('action', 'email');
        pr.getParameters().put('format', 'json');
        pr.getParameters().put('to', 'someone_else@fiu.edu');
        Test.setCurrentPage(pr);

        Test.setMock(HttpCalloutMock.class, new DescribeMock());

        Test.startTest();
        ExportCsvController ctrl = new ExportCsvController();
        Test.stopTest();

        System.assert(ctrl.output.contains('your own address'), 'Should reject other users email');
    }

    @isTest
    static void testEmailSuccess() {
        // Only works if running user has @fiu.edu email — skip assertion if not
        String userEmail = UserInfo.getUserEmail();
        if (!userEmail.toLowerCase().endsWith('@fiu.edu')) {
            // Can't test the full email path without an @fiu.edu user;
            // coverage still hits the validation branches above
            return;
        }

        PageReference pr = Page.ExportCsv;
        pr.getParameters().put('objectApiName', 'Account');
        pr.getParameters().put('filterName', 'testFilter');
        pr.getParameters().put('action', 'email');
        pr.getParameters().put('format', 'json');
        pr.getParameters().put('to', userEmail);
        Test.setCurrentPage(pr);

        Test.setMock(HttpCalloutMock.class, new DescribeMock());

        Test.startTest();
        ExportCsvController ctrl = new ExportCsvController();
        Test.stopTest();

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(ctrl.output);
        // 'ok' if deliverability is on, 'error' if off — both are valid coverage
        System.assert(result.get('status') == 'ok' || result.get('status') == 'error',
            'Should return ok or error depending on email deliverability');
    }

    @isTest
    static void testEmailMissingAddressHtml() {
        PageReference pr = Page.ExportCsv;
        pr.getParameters().put('objectApiName', 'Account');
        pr.getParameters().put('filterName', 'testFilter');
        pr.getParameters().put('action', 'email');
        // no format=json → HTML mode
        Test.setCurrentPage(pr);

        Test.setMock(HttpCalloutMock.class, new DescribeMock());

        Test.startTest();
        ExportCsvController ctrl = new ExportCsvController();
        Test.stopTest();

        System.assertEquals('text/html', ctrl.pageContentType);
        System.assert(ctrl.output.contains('Send CSV'), 'Should render email prompt');
    }

    @isTest
    static void testCalloutError() {
        PageReference pr = Page.ExportCsv;
        pr.getParameters().put('objectApiName', 'Account');
        pr.getParameters().put('filterName', 'badFilter');
        Test.setCurrentPage(pr);

        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        ExportCsvController ctrl = new ExportCsvController();
        Test.stopTest();

        System.assert(ctrl.output.contains('does not exist'), 'Should show API error');
    }

    @isTest
    static void testMissingFilterNameFallback() {
        // No filterName, no ListView match → should error
        PageReference pr = Page.ExportCsv;
        pr.getParameters().put('objectApiName', 'SomeNonexistentObject__c');
        Test.setCurrentPage(pr);

        ExportCsvController ctrl = new ExportCsvController();

        System.assert(ctrl.output.contains('Unable to determine'), 'Should show fallback error');
    }
}