# Summit Events 0.41.0.1 Upgrade Plan

Target package install path:

```text
/packaging/installPackage.apexp?p0=04tVs000000GDJ3IAO
```

Use the org My Domain in front of that path, for example:

```text
https://<my-domain>.my.salesforce.com/packaging/installPackage.apexp?p0=04tVs000000GDJ3IAO
```

Release notes reviewed:

- https://sfdo-community-sprints.github.io/summit-events-app-documentation/docs/release-notes/36-0-5/
- https://sfdo-community-sprints.github.io/summit-events-app-documentation/docs/release-notes/37-0-2/
- https://sfdo-community-sprints.github.io/summit-events-app-documentation/docs/release-notes/38-0-1/
- https://sfdo-community-sprints.github.io/summit-events-app-documentation/docs/release-notes/40-0-1/
- https://sfdo-community-sprints.github.io/summit-events-app-documentation/docs/release-notes/41-0-1/

## Upgrade Scope

Partial UAT is currently on Summit Events `0.35.0.1`, so the upgrade to `0.41.0.1` includes the changes from 0.36, 0.37, 0.38, 0.40, and 0.41.

The most important upgrade themes are:

- Guest user security and public rich-text image access from 0.37.
- QR code URL and transactional email QR rendering from 0.36 and 0.41.
- Payment completion and appointment auto-add/linking reliability from 0.38.
- Person Account/contact matching and guest matching controls from 0.40.
- Logged-in community user address mapping and expanded Registration address fields from 0.41.

## FIU Layer Impact

The FIU Events app is an internal management layer over Summit Event, Instance, and Registration data. The managed package upgrade should not directly replace the FIU LWCs, tabs, custom fields, readiness services, or FIU Visualforce templates, but it can affect behavior that the FIU layer previews, validates, or depends on.

Areas to watch:

- Public registration pages rendered by FIU Visualforce templates may display broken rich-text images if images are embedded from Salesforce record/file URLs rather than public file links.
- FIU readiness logic now warns about likely Salesforce-hosted images in key Summit rich text fields.
- FIU Registration Browser, roster/export behavior, and downstream flows should be tested against changed Registration address field lengths and the new `Registrant_Country_Text__c` field.
- Any FIU registration confirmation or transactional email template using `Registrant_Id_QR_Code__c` must be retested for QR image rendering.
- Any FIU event using payment must be tested end to end after the payment gateway return.
- Any FIU event using appointments/options must be tested, especially auto-add appointment types and required appointments.
- Contact/Lead matching, Person Account behavior, and `Matching_Only__c` custom metadata should be reviewed because matching logic changed in 0.40 and 0.41.
- Guest registration cancellation should be tested because 0.40 fixes capacity updates when guest registrations are canceled.

## Pre-Upgrade Checks

1. Confirm the installed Summit Events version.

   ```powershell
   sf data query --target-org "Partial UAT" --use-tooling-api --query "SELECT SubscriberPackage.NamespacePrefix, SubscriberPackage.Name, SubscriberPackageVersion.Name, SubscriberPackageVersion.MajorVersion, SubscriberPackageVersion.MinorVersion, SubscriberPackageVersion.PatchVersion, SubscriberPackageVersion.BuildNumber FROM InstalledSubscriberPackage"
   ```

2. Run the FIU rich-text image preflight scan.

   ```powershell
   sf apex run --target-org "Partial UAT" --file scripts/apex/preflight_summit_037_partial_uat.apex
   ```

3. For each flagged active event, make embedded rich-text images public before upgrading:

   - Upload the original image as a Salesforce File.
   - Create a Public Link from the File record.
   - Open the public link, copy the rendered image, and paste it back into the rich text field.
   - Re-test the public registration page unauthenticated.

4. Confirm whether `https://api.qrserver.com` already exists as an active Trusted URL. Add it if missing.

5. Identify active events using these features for regression testing:

   - Payments.
   - Appointments/options, especially auto-add and required appointments.
   - Guest registrations and guest cancellations.
   - Custom questions, lookup questions, and portal/community user registration.
   - Contact/Lead matching mappings, especially `Matching_Only__c`.
   - Transactional emails containing `Registrant_Id_QR_Code__c`.

## Partial UAT Sequence

1. Deploy the FIU readiness/preflight updates to Partial UAT if they are not already deployed.

   ```powershell
   sf project deploy start --target-org "Partial UAT" --metadata ApexClass:FiuEventsReadinessService --metadata ApexClass:FiuEventBrowserService --metadata ApexClass:FiuHomeDashboardService --metadata ApexClass:FiuInstanceBrowserService --metadata ApexClass:FiuReadinessRecalcService --metadata ApexClass:FiuEventsServicesTest --test-level NoTestRun --wait 60
   ```

2. Run the preflight scan and remediate public images.

3. Upgrade Summit Events to `0.41.0.1` in Partial UAT using the org My Domain plus:

   ```text
   /packaging/installPackage.apexp?p0=04tVs000000GDJ3IAO
   ```

4. After the package upgrade:

   - Remove the Guest User Sharing Rule on `summit__Summit_Events__c`.
   - Confirm the Files related list is available for Summit Event record managers.
   - Add `https://api.qrserver.com` as a Trusted URL if it is not already present.
   - Add `summit__Lookup_Order_By__c` to the Summit Events Question layout if lookup question ordering is used.
   - Review whether custom Summit Events Registration page layouts should include `Registrant_Country_Text__c` and `Registrant_Id_QR_Code__c`.
   - Review Person Account/contact matching controls on Summit Event and Summit Event Registration layouts if FIU uses or plans to use Person Accounts or guest matching.

5. Regression test:

   - FIU Events Home, Event Browser, Instance Browser, Registration Browser.
   - Create/clone event and create/clone instance paths.
   - Public RSVP, payment, open enrollment, GSC, EPE, OGI, PINO, and Student Services templates.
   - End-to-end payment registration with gateway return.
   - Appointment registration, including auto-add, required, added-but-not-shown, and registration linkage.
   - QR code generation on registration and QR rendering in transactional emails.
   - Logged-in community user registration with long street/state/zip/country address values.
   - Guest registration creation and guest cancellation capacity changes.
   - Custom questions, lookup questions, portal/community users with custom questions, and contact/lead/person account matching.

## Prod Sequence

Only proceed after Partial UAT passes.

Pre-deploy:

1. Confirm current Prod Summit Events version.
2. Deploy FIU readiness/preflight code to Prod using the Prod deployment/test strategy.
3. Run the preflight scan against Prod and remediate public rich-text images before the managed-package upgrade.
4. Confirm `https://api.qrserver.com` Trusted URL plan.
5. Confirm active-event regression sample and business owners for payments, appointments, guest registration, matching, and emails.

Deploy:

1. Open the install URL with the Prod My Domain:

   ```text
   https://<prod-my-domain>.my.salesforce.com/packaging/installPackage.apexp?p0=04tVs000000GDJ3IAO
   ```

2. Install/upgrade Summit Events to `0.41.0.1`.

Post-deploy:

1. Remove the Summit Events Guest User Sharing Rule on `summit__Summit_Events__c`.
2. Confirm Files related list availability.
3. Add or confirm `https://api.qrserver.com` as an active Trusted URL.
4. Apply layout updates:

   - `summit__Lookup_Order_By__c` on Summit Events Question layout if used.
   - `Registrant_Country_Text__c` and `Registrant_Id_QR_Code__c` on custom Summit Events Registration layouts if useful.
   - Person Account/contact matching fields on Summit Event and Summit Events Registration layouts if FIU uses those controls.

5. Run public smoke tests unauthenticated and logged in:

   - Public registration opens and submits.
   - Payment registration returns and completes.
   - Appointment registration creates linked appointment records.
   - QR code appears on registration and in transactional email.
   - Guest cancellation updates capacity.
   - Matching behavior respects `Matching_Only__c`.

Do not remove the Prod Guest User Sharing Rule before remediating active rich-text images and validating the representative public registration flow in Partial UAT.
