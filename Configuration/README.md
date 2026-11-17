# Managed configuration

Preference domain: `com.ecubrooks.DDMUpdateCompanion`.

Use the JSON schema in this directory for a Jamf Application & Custom Settings profile, or customize the example mobileconfig. Deploy the app and logo separately. The settings profile does not create a DDM software update enforcement declaration.

Forced values disable their GUI controls and are never overwritten by Save. Production preferences refresh every 60 seconds; local saves trigger a refresh immediately. Display-Only Mode selection occurs at launch and requires an app restart.

For JSON import, saving the app's copied plist, and MDM upload instructions, follow the [step-by-step configuration guide](../Documentation/wiki/Managed-Configuration.md).

## Production keys

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `PopupEnabled` | Boolean | true | Enable automatic popups; manual Show Update Reminder remains available. |
| `PopupTitle` | String | macOS Update Required | Nonempty heading. |
| `PopupMessage` | String | A software update is required for your Mac. | Plain text; no template variables. |
| `PopupLeadDays` | Integer | 0 | 0 starts immediately; 1–365 begins that many days before the deadline. |
| `ReminderIntervalMinutes` | Integer | 60 | 1–1440 minutes when more than 24 hours remain; 60 minutes within 24 hours and 15 minutes within eight hours. |
| `HideRemindLaterButton` | Boolean | false | Hide Remind Later at the configured remaining-time threshold. |
| `HideRemindLaterButtonDays` | Integer | 0 | 0–365 days in the hide threshold. |
| `HideRemindLaterButtonHours` | Integer | 0 | 0–23 additional hours in the hide threshold. |
| `HideIconWhenInactive` | Boolean | true | Hide the icon without a pending update. |
| HidePreferences | Boolean | false | Hide the Preferences menu item; Command-comma remains available while the app or its menu is active. This does not restrict access. |
| AllowQuit | Boolean | true | Set false to grey out Quit and disable Command-Q in app menus. Does not block Force Quit, logout, or shutdown. |
| StatusDotEnabled | Boolean | false | Show a small red dot over the Software Update icon, independently of popups and deferrals. |
| StatusDotLeadDays | Integer | 0 | 0 shows immediately; 1–365 starts that many days before the deadline. |
| StatusDotFlashHours | Integer | 24 | Flash the visible dot during the final 1–8760 hours and while overdue; 0 disables flashing. Reduce Motion keeps it steady. |
| `CustomLogoPath` | String | Empty | Absolute local image path, up to 5 MB. |
| `SupportURL` | String | Empty | HTTPS help URL; empty hides the help button. |

Invalid timing values fall back to defaults. Empty title/message values use default copy. Unreadable or oversized images use the Software Update symbol. The GUI validates local input before saving.

**Copy Settings** saves and copies effective production settings as an XML preferences dictionary. It includes effective managed values for the 16 fields exposed in Preferences and omits Display-Only Mode keys and runtime state. It does not export the nine profile-only keys: the four `DisplayOnly…` keys, `HidePreferences`, `AllowQuit`, `StatusDotEnabled`, `StatusDotLeadDays`, and `StatusDotFlashHours`. Add those through the schema or example profile. This is not a complete mobileconfig; use your MDM's preferences payload for the domain above.

The schema and example mobileconfig contain all 21 production keys and four Display-Only Mode keys. Remove keys you do not intend to enforce: a profile containing defaults still locks those preferences. Replace the example support URL and logo path, or remove them. Generate unique profile and payload UUIDs for your deployment.

## Display-Only Mode keys

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `DisplayOnlyModeEnabled` | Boolean | false | Select a simulated reminder provider in Debug and Release builds. Requires an app restart. |
| `DisplayOnlyRequiredVersion` | String | Automatic | Version label for the simulated update. |
| `DisplayOnlyScenario` | String | days | days, hours, minutes, dueNow, overdue, farFuture, or custom. |
| `DisplayOnlyDeadline` | String | Empty | ISO 8601 timestamp for custom, such as 2027-12-31T17:00:00Z. |

Display-Only Mode does not read, create, or enforce a DDM declaration. Its reminder title and message clearly identify the simulation. Unknown scenarios and invalid custom deadlines fall back to three days. Launch arguments `--display-only --display-only-scenario hours` provide the same mode for local testing. Disable Display-Only Mode and restart the app before live DDM testing.

## Deployment

See [Jamf's Application & Custom Settings documentation](https://developer.jamf.com/jamf-pro/docs/application-custom-settings). Avoid overlapping profiles for the same keys.

Runtime state is separate: `com.ecubrooks.DDMUpdateCompanion.state`. Do not manage that domain. It stores deferrals and the ten-minute Update Now pause.

The optional LaunchAgent example assumes `/Applications/DDM Update Companion.app`. Deploy it to `/Library/LaunchAgents` with root ownership and mode 0644 through your management tooling. It launches in an Aqua session at login; the app does not install the agent itself.


## Reminder scheduling and startup

Remind Later uses ReminderIntervalMinutes while more than 24 hours remain, then 60 minutes at 24 hours and 15 minutes at eight hours. The deadline schedule overrides the configured interval. Saved deferrals are shortened at schedule boundaries, never extended by a refresh. Once overdue, the reminder cannot be deferred.

When HideRemindLaterButton is enabled, its days and hours are combined into one remaining-time threshold. For example, 1 day and 6 hours hides the button at 30 hours remaining. Both values at 0 hide it for the entire reminder lifecycle. These settings do not alter the schedule above, automatic popup presentation, or the DDM-enforced deadline.

PopupEnabled and PopupLeadDays still govern automatic presentation. Quiet hours can suppress it; manual Show Update Reminder remains available. Preferences shows the current reminder status and deferred-until time. Reset Deferral clears both Remind Later and the Update Now pause, then rereads DDM and applies the current presentation rules.

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| LaunchAtLogin | Boolean | false | Register the main app as a login item; macOS approval may be needed. |
| QuietHoursEnabled | Boolean | false | Pause automatic popups during quiet hours. |
| QuietHoursStartHour | Integer | 22 | Local start hour, 0–23 inclusive. |
| QuietHoursEndHour | Integer | 8 | Local end hour, 0–23 exclusive; may cross midnight. Equal hours disable quiet hours. |
| QuietHoursUrgentOverride | Boolean | true | Ignore quiet hours in the final eight hours and while overdue. |

Launch at login registers the installed app with macOS. Enable it in Preferences and Save, or deploy LaunchAtLogin through MDM. The app must run once for each user to register. Deploy the signed app to Applications; check Login Items in System Settings if approval is required. Use this mechanism OR the existing LaunchAgent, not both. The LaunchAtLogin preference alone does not grant macOS login-item approval; any managed approval policy is separate.

Completion remains based on the DDM target: the app rereads local DDM persistence every 60 seconds and compares the target version/build with the installed system. When no pending target remains, it clears the popup, dot, countdown, and saved deferral (or shows the inactive icon when configured). Removing a declaration also clears it and is not reported as proof of installation. Read errors preserve the last known pending update. This relies on softwareupdated's local persistence format, not a public DDM completion API.
