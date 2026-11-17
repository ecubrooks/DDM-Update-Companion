# Troubleshooting

## Nothing appears

Open the app again or launch with --preferences. HideIconWhenInactive defaults to true. Check status and choose Refresh Now.

A settings profile alone does not schedule an OS update. Confirm a software update enforcement declaration has reached the Mac and targets a version/build newer than the installed one. The app does not show optional catalog updates.

## Preferences are locked

The lock label means the key is forced by management. Change or remove the relevant MDM profile. Save does not override it. A previous local value may return after removal.

## Preferences seem ignored

Save the form; profile changes can take up to the next 60-second refresh. Use Reload for form fields and Refresh Now for DDM. Remove a --support-url launch override when testing local support changes. Forced keys always take precedence.

## Logo or support link missing

Use an absolute readable image path, maximum 5 MB. Deploy the image separately. The URL must be HTTPS with a host. Invalid managed values fall back safely.

## DDM read error

Preferences displays the error and last successful DDM read time. The countdown keeps using the last known deadline while current profile rules still apply. A missing file has a three-consecutive-check grace period before clearing an existing reminder; parsing/permission errors do not count as missing checks. Check that the system file is readable in the logged-in session, and verify macOS compatibility. The app logs read failures using subsystem com.ecubrooks.DDMUpdateCompanion and category DDM:

```sh
log show --last 15m --predicate 'subsystem == "com.ecubrooks.DDMUpdateCompanion" AND category == "DDM"'
```

Do not change permissions or modify the system file as a routine workaround. If the issue persists, report it with sanitized diagnostics.

## Popup returns after Update Now

Opening Software Update does not start installation automatically. The ten-minute pause ends while the target remains pending. macOS handles actual installation and enforcement.

## App does not start at login

Enable Launch at login in Preferences and Save, or manage `LaunchAtLogin`. Run the installed app once in each user session so it can register. Check the registration status in Preferences and approve it in System Settings if requested. Alternatively, deploy the optional LaunchAgent through your management system. Use one startup method, not both; the app does not install the LaunchAgent itself.
