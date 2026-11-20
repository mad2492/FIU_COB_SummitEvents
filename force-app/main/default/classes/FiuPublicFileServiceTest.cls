@IsTest
private class FiuPublicFileServiceTest {
    @IsTest
    static void createsReusablePublicDistribution() {
        ContentVersion version = new ContentVersion(
            Title = 'event-image',
            PathOnClient = 'event-image.png',
            VersionData = Blob.valueOf('fake image bytes')
        );
        insert version;

        Id documentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :version.Id
        ].ContentDocumentId;

        Test.startTest();
        FiuPublicFileService.PublicFileResult firstResult =
            FiuPublicFileService.createPublicLinkForContentDocument(documentId);
        FiuPublicFileService.PublicFileResult secondResult =
            FiuPublicFileService.createPublicLinkForContentDocument(documentId);
        Test.stopTest();

        System.assertEquals(documentId, firstResult.contentDocumentId);
        System.assertNotEquals(null, firstResult.contentDistributionId);
        System.assertEquals(firstResult.contentDistributionId, secondResult.contentDistributionId);
    }

    @IsTest
    static void createsPublicImageFromBase64() {
        String base64 = EncodingUtil.base64Encode(Blob.valueOf('fake png bytes'));

        Test.startTest();
        FiuPublicFileService.PublicFileResult result =
            FiuPublicFileService.createPublicImageFromBase64(base64, 'Landing Description', 'image/png');
        Test.stopTest();

        System.assertNotEquals(null, result.contentDocumentId, 'A file should have been created.');
        System.assertNotEquals(null, result.contentDistributionId, 'A public distribution should exist.');
        System.assertNotEquals(null, result.publicImageUrl, 'A public image URL should be returned.');
    }

    @IsTest
    static void createsPublicLinkFromContentVersion() {
        ContentVersion version = new ContentVersion(
            Title = 'rich-text-image',
            PathOnClient = 'rich-text-image.png',
            VersionData = Blob.valueOf('fake image bytes')
        );
        insert version;

        Test.startTest();
        FiuPublicFileService.PublicFileResult result =
            FiuPublicFileService.createPublicLinkForContentVersion(version.Id);
        Test.stopTest();

        System.assertEquals(version.Id, result.contentVersionId);
        System.assertNotEquals(null, result.contentDistributionId);
        System.assertNotEquals(null, result.publicImageUrl);
    }

    @IsTest
    static void rejectsBlankBase64() {
        Test.startTest();
        try {
            FiuPublicFileService.createPublicImageFromBase64('', 'image', 'image/png');
            System.assert(false, 'Blank image data should have been rejected.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}
