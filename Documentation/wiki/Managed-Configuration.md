# Managed settings

Preference domain: `com.ecubrooks.DDMUpdateCompanion`.

## Choose a configuration method

Install the app separately. Then choose **one** method below for each group of settings; do not deploy overlapping profiles for the same keys.

| Method | What you need | Result |
| --- | --- | --- |
| Configure in Jamf Pro | [JSON schema](../../Configuration/com.ecubrooks.DDMUpdateCompanion.json) | A form containing all 21 production settings and four Display-Only Mode settings |
| Configure in the app | Preferences → Copy Settings | XML plist containing the 16 GUI settings, ready for a custom preferences payload |
| Start with a complete profile | [Example mobileconfig](../../Configuration/DDMUpdateCompanion.example.mobileconfig) | An editable profile containing all 25 settings |

The JSON is a form schema, not a configuration profile. A preferences plist is also not a complete `.mobileconfig`; renaming its extension does not convert it.

## Option A: Jamf JSON schema (Recommended method)

1. Open the linked JSON file on GitHub and download its raw contents, not the HTML page.
2. Create a macOS computer configuration profile in Jamf Pro.
3. In Application & Custom Settings, configure an External Application using a Custom Schema. Enter `com.ecubrooks.DDMUpdateCompanion` as the preference domain, without `.plist`.
4. Import or paste the JSON schema into the schema editor, then configure the resulting fields.
5. Include only settings you intend to enforce. Review the generated preferences before saving; a default value in a deployed payload is still managed.
6. Scope the profile to a pilot Mac, then perform the verification below.

Jamf documents [custom schemas](https://developer.jamf.com/jamf-pro/docs/application-custom-settings) and [PLIST upload](https://learn.jamf.com/r/en-US/technical-articles/Deploying_Custom_Computer_Configuration_Profiles_Using_the_Application_and_Custom_Settings_Payload). Console labels may differ by release.

## Option B: Create a plist using the app

1. Install and open the app on an administrator's test Mac. Reopen it if the inactive menu icon is hidden.
2. Open Preferences, set the desired values, and use Save & Preview to check the appearance. Existing managed fields cannot be edited; Copy Settings includes their effective values.
3. Click **Copy Settings** and confirm the app reports that the settings were copied. This also saves those settings locally.
4. Paste into a plain-text document and save as `com.ecubrooks.DDMUpdateCompanion.plist`. Alternatively, immediately after copying, run this in Terminal to create a new temporary folder and validate the clipboard XML:

```sh
settings_dir=$(mktemp -d /tmp/DDMUpdateCompanion-settings.XXXXXX)
pbpaste > "$settings_dir/com.ecubrooks.DDMUpdateCompanion.plist"
plutil -lint "$settings_dir/com.ecubrooks.DDMUpdateCompanion.plist"
open "$settings_dir"
```

5. Review the file and remove keys you want users to control. Copy Settings includes all GUI fields, including default values.
6. In Jamf Pro, use Application & Custom Settings → Upload with preference domain `com.ecubrooks.DDMUpdateCompanion` and upload the plist. In other MDMs, use their supported custom macOS preferences workflow with that same domain. If your MDM accepts only complete profiles, use Option C or its profile editor; do not upload the raw plist as a `.mobileconfig`.
7. Scope to a pilot Mac and verify the result below.

Copy Settings does not include the four `DisplayOnly…` keys, `HidePreferences`, `AllowQuit`, `StatusDotEnabled`, `StatusDotLeadDays`, or `StatusDotFlashHours`. Add those through the schema/profile if needed. It also does not bundle a logo or include the DDM update deadline.

## Option C: Customize the example profile

Download the raw [example mobileconfig](../../Configuration/DDMUpdateCompanion.example.mobileconfig). Edit the app settings inside its settings payload, remove unwanted keys, and replace or remove the example support URL and logo path. Assign unique profile/payload UUIDs and your own organization/display metadata. Upload through your MDM's supported custom-profile workflow.

Use the [settings reference](../../Configuration/README.md) for types, defaults, and ranges. Preserve booleans and integers as those plist types, not strings. Never replace the app's preference domain with your organization's domain.

## Verify on a pilot Mac

1. Confirm the app and profile are installed and any custom image exists at the configured path on that Mac.
2. Open Preferences and use Reload after the profile arrives. Managed GUI controls should be locked and show the intended values. Allow approximately 60 seconds for automatic refresh.
3. Check profile-only menu controls by opening the menu and, for the status dot, testing with a pending DDM update.
4. Choose one startup method: `LaunchAtLogin` or the supplied LaunchAgent. A profile does not initially launch the app; run it once per user for app login-item registration.
5. Separately send a DDM update enforcement policy through your MDM and confirm the displayed target/deadline. No pending target means no real reminder, even when the app settings profile is installed.
6. Complete the [pilot checklist](Testing.md) before widening scope.

Changing a GUI value on the administrator's Mac does not update the fleet profile. Export again and update the MDM payload. Avoid separate profiles managing the same keys.

## Decide what to manage

| Area | Keys |
| --- | --- |
| Popup content and timing | `PopupEnabled`, `PopupTitle`, `PopupMessage`, `PopupLeadDays`, `ReminderIntervalMinutes`, `HideRemindLaterButton`, `HideRemindLaterButtonDays`, `HideRemindLaterButtonHours` |
| Branding and help | `CustomLogoPath`, `SupportURL` |
| Menu visibility and quitting | `HideIconWhenInactive`, `HidePreferences`, `AllowQuit` |
| Status dot | `StatusDotEnabled`, `StatusDotLeadDays`, `StatusDotFlashHours` |
| Startup | `LaunchAtLogin` |
| Quiet hours | `QuietHoursEnabled`, `QuietHoursStartHour`, `QuietHoursEndHour`, `QuietHoursUrgentOverride` |
| Display-only simulation | `DisplayOnlyModeEnabled`, `DisplayOnlyRequiredVersion`, `DisplayOnlyScenario`, `DisplayOnlyDeadline` |

## Managed and local values

Managed values take priority. Their Preferences controls are locked and Save cannot override them. Changes are checked approximately every 60 seconds. Removing a profile can reveal a previously saved local value.

Copy Settings exports the 16 GUI fields as a plist dictionary, not a complete configuration profile. Add the nine profile-only keys through your profile: the four `DisplayOnly…` keys, `HidePreferences`, `AllowQuit`, `StatusDotEnabled`, `StatusDotLeadDays`, and `StatusDotFlashHours`.

Do not manage `com.ecubrooks.DDMUpdateCompanion.state`; it stores user deferrals and the temporary pause after opening Software Update.

Existing SUMB or DDM OS Reminder profiles are not interchangeable with this app's profile. Translate settings to this domain and its exact key names.
