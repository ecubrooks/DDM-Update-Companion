# Setup and startup

## Requirements

- macOS 15 or later.
- A logged-in user session for the menu bar and reminder window.
- An MDM-delivered DDM update enforcement policy with a pending target and deadline. See [compatibility](DDM-Integration.md).

## Install

1. Obtain the app ZIP or installer from the project's published release assets. The automatic source-code download is not an installable app.
2. Deploy the installer through your management tool, or extract the app ZIP and install `DDM Update Companion.app` in `/Applications`.
3. Deploy the [app settings profile](Managed-Configuration.md) and any custom logo separately. The current installer contains only the app.
4. Choose one startup method below.
5. Optional: Review [testing checklist](Testing.md).

## Start at login

**App login item:** Enable `LaunchAtLogin` through the settings profile or Preferences. The app must run once per user to register. Check Preferences for registration status and approve it in System Settings if required. The app preference alone does not approve a managed login item.

**Managed LaunchAgent:** Alternatively deploy the supplied [LaunchAgent example](../../Configuration/com.ecubrooks.DDMUpdateCompanion.agent.plist) to `/Library/LaunchAgents` with root ownership and mode `0644`. It expects the app in `/Applications`, starts in the user's desktop session at login, and does not continuously restart the app after Quit. Your deployment tooling must handle starting it for an already logged-in user if needed.

Use one startup method, not both. A settings profile does not install or initially launch the app.

## Open Preferences

Choose Preferences from the menu bar, or reopen the app if its icon is hidden. You can also run:

```sh
open -a /Applications/DDM\ Update\ Companion.app
```

The app does not show a normal Dock icon. Hiding the Preferences menu is not an access restriction.

## Remove the app

Disable its login item or unload/remove the deployed LaunchAgent through management, quit the app, and remove the app and its settings profile. Remove separately deployed branding files if no longer needed. Removing the companion does not remove your MDM's update enforcement policy.
