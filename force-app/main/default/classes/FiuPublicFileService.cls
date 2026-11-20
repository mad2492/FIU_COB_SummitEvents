public with sharing class FiuPublicFileService {
    // ~1.5 MB of base64 text. Keeps the inbound Apex request and the decoded
    // Blob comfortably inside the synchronous heap limit.
    private static final Integer MAX_BASE64_LENGTH = 2000000;

    public class PublicFileResult {
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public Id contentDistributionId;
        @AuraEnabled public String fileName;
        @AuraEnabled public String distributionPublicUrl;
        @AuraEnabled public String contentDownloadUrl;
        @AuraEnabled public String publicImageUrl;
    }

    @AuraEnabled
    public static PublicFileResult createPublicLinkForContentDocument(Id contentDocumentId) {
        if (contentDocumentId == null) {
            throw new AuraHandledException('Upload a file first.');
        }
        assertCanCreatePublicLinks();

        List<ContentVersion> versions = [
            SELECT Id, Title, FileExtension, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            AND IsLatest = true
            LIMIT 1
        ];
        if (versions.isEmpty()) {
            throw new AuraHandledException('The uploaded file could not be found.');
        }
        return buildPublicResult(versions[0].Id);
    }

    @AuraEnabled
    public static PublicFileResult createPublicLinkForContentVersion(Id contentVersionId) {
        if (contentVersionId == null) {
            throw new AuraHandledException('No uploaded image version was provided.');
        }
        assertCanCreatePublicLinks();
        return buildPublicResult(contentVersionId);
    }

    // Accepts an image embedded in rich text as a base64 data URI, stores it as
    // a Salesforce File, and returns a public URL the FIU wizard can swap into
    // the rich text in place of the data URI. This lets users insert images
    // with the normal rich-text image button while the public-link plumbing
    // happens behind the scenes.
    @AuraEnabled
    public static PublicFileResult createPublicImageFromBase64(String base64Data, String fileName, String contentType) {
        if (String.isBlank(base64Data)) {
            throw new AuraHandledException('No image data was provided.');
        }
        assertCanCreatePublicLinks();

        String cleaned = base64Data.replaceAll('\\s+', '');
        if (cleaned.length() > MAX_BASE64_LENGTH) {
            throw new AuraHandledException('That image is too large. Please use an image under about 1 MB.');
        }

        Blob fileBody;
        try {
            fileBody = EncodingUtil.base64Decode(cleaned);
        } catch (Exception e) {
            throw new AuraHandledException('The image data could not be read.');
        }
        if (fileBody == null || fileBody.size() == 0) {
            throw new AuraHandledException('The image data could not be read.');
        }

        String safeName = buildImageFileName(fileName, contentType);
        ContentVersion version = new ContentVersion(
            Title = safeName,
            PathOnClient = safeName,
            VersionData = fileBody
        );
        insert version;

        Id versionId = [
            SELECT Id FROM ContentVersion WHERE Id = :version.Id LIMIT 1
        ].Id;
        return buildPublicResult(versionId);
    }

    private static void assertCanCreatePublicLinks() {
        if (!Test.isRunningTest() && !FeatureManagement.checkPermission('FIU_Events_Create_Public_File_Links')) {
            throw new AuraHandledException('You do not have permission to create public file links.');
        }
    }

    private static PublicFileResult buildPublicResult(Id contentVersionId) {
        ContentVersion version = [
            SELECT Id, Title, FileExtension, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ];

        List<ContentDistribution> existing = [
            SELECT Id, DistributionPublicUrl, ContentDownloadUrl
            FROM ContentDistribution
            WHERE ContentVersionId = :version.Id
            LIMIT 1
        ];

        ContentDistribution distribution;
        if (existing.isEmpty()) {
            distribution = new ContentDistribution(
                Name = buildDistributionName(version),
                ContentVersionId = version.Id,
                PreferencesAllowViewInBrowser = true,
                PreferencesAllowOriginalDownload = true,
                PreferencesLinkLatestVersion = true,
                PreferencesNotifyOnVisit = false,
                PreferencesPasswordRequired = false
            );
            insert distribution;
            distribution = [
                SELECT Id, DistributionPublicUrl, ContentDownloadUrl
                FROM ContentDistribution
                WHERE Id = :distribution.Id
                LIMIT 1
            ];
        } else {
            distribution = existing[0];
        }

        PublicFileResult result = new PublicFileResult();
        result.contentDocumentId = version.ContentDocumentId;
        result.contentVersionId = version.Id;
        result.contentDistributionId = distribution.Id;
        result.fileName = buildDistributionName(version);
        result.distributionPublicUrl = distribution.DistributionPublicUrl;
        result.contentDownloadUrl = distribution.ContentDownloadUrl;
        result.publicImageUrl = String.isNotBlank(distribution.ContentDownloadUrl)
            ? distribution.ContentDownloadUrl
            : distribution.DistributionPublicUrl;
        return result;
    }

    private static String buildDistributionName(ContentVersion version) {
        String title = String.isBlank(version.Title) ? 'FIU Event Image' : version.Title;
        if (!String.isBlank(version.FileExtension) && !title.toLowerCase().endsWith('.' + version.FileExtension.toLowerCase())) {
            title += '.' + version.FileExtension;
        }
        return title;
    }

    private static String buildImageFileName(String fileName, String contentType) {
        String ext = 'png';
        if (String.isNotBlank(contentType) && contentType.contains('/')) {
            ext = contentType.substringAfterLast('/').toLowerCase();
            if (ext == 'jpeg') {
                ext = 'jpg';
            }
            if (ext == 'svg+xml') {
                ext = 'svg';
            }
        }
        String base = String.isBlank(fileName) ? 'FIU Event Image' : fileName;
        if (base.contains('.')) {
            base = base.substringBeforeLast('.');
        }
        return base + '-' + String.valueOf(Datetime.now().getTime()) + '.' + ext;
    }
}
