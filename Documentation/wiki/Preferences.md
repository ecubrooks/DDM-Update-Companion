# Preferences

## Popup reminders

**Show automatic popups** controls automatic presentation. Manual Show Update Reminder remains available for a pending update.

**Title** and **Message** replace popup copy and must be nonempty. Version, deadline, and remaining time remain separate. Text is literal; variables are not expanded.

**Begin reminders** accepts 0–365 days. Zero starts as soon as an update is detected. Otherwise automatic presentation starts that many days before the deadline; the menu bar can show the update earlier.

**Remind later** accepts 1–1440 minutes for deadlines more than 24 hours away. Within 24 hours the interval is 60 minutes; within eight hours it is 15 minutes. Deferrals survive relaunch, are tied to the target version/build/deadline, and cannot extend past the deadline. Remind Later disappears when the deadline is reached.

**Hide the Remind Later button** removes that action once the combined days-and-hours threshold is reached. For example, 1 day plus 6 hours hides it during the final 30 hours. Setting both values to 0 hides it for the entire reminder. The option defaults to off and does not change popup timing or the enforced update deadline. Managed controls are locked like other profile-backed preferences.

**Hide menu bar icon when no update is pending** defaults to enabled. Reopen the app to access Preferences when the icon is hidden.

## Branding

Use an absolute path to a readable image up to 5 MB. Leave empty for the default symbol. The optional support URL must use HTTPS and include a host; leave empty to hide the help link.

## Actions

- **Save** validates editable fields before writing and refreshes the reminder.
- **Reload** discards unsaved edits and loads effective preferences.
- **Save & Preview** saves first and shows a labeled sample. Sample buttons close the preview; they do not open Software Update.
- **Copy Settings** saves first and copies an XML preferences dictionary. It includes effective managed values for the 16 GUI fields but excludes runtime state and the nine profile-only settings. See the [configuration reference](../../Configuration/README.md).

Managed controls have a lock label and are disabled. Save never writes forced keys. Profile changes are checked on the refresh cycle. Removing a profile can reveal a previously saved local value.

## Status

Preferences shows the latest check time, detected version/deadline, and read errors. **Refresh Now** checks immediately. No pending managed update does not mean the Mac has no optional Apple updates.

## Scheduling and startup

Quiet hours pause automatic popups between the configured local hours (22:00–08:00 by default). The urgent override, enabled by default, allows reminders during the final eight hours and after the deadline. Manual Show Update Reminder remains available.

**Reset Deferral** clears the saved deferral and the ten-minute Software Update pause, then refreshes and applies the current popup and quiet-hour rules. Status shows why a reminder is paused and its deferred-until time.

**Launch at login** registers the installed app as a macOS login item after Save. Preferences shows registration status and provides access to Login Items when approval is needed. Use either this option or the deployment LaunchAgent.

## Menu bar controls

These controls are configured through a profile or local defaults, not the Preferences form: `HidePreferences`, `AllowQuit`, `StatusDotEnabled`, `StatusDotLeadDays`, and `StatusDotFlashHours`.

The optional red status dot can start a configured number of days before the deadline and flash during the final configured hours. Reduce Motion keeps it steady. Managed settings can hide the Preferences menu item or disable Quit; these are interface controls, not access restrictions.
