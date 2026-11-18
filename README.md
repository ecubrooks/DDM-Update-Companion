# DDM Update Companion

<p align="center">
  <img src="Images/DDMUpdateCompanion.png" alt="DDM Update Companion dog mascot wearing a pirate hat" width="360">
</p>

Your macOS update companion: a lightweight "watchdog" that keeps an eye on software update deadlines, barks when they are due, and points to Software Update, helping your Mac stay secure.

A macOS menu bar app that shows a compact popup for updates enforced through Declarative Device Management (DDM).
The reminder stays near the upper-right corner of the active screen and shows the required macOS version, deadline, and time remaining. Users can open Software Update, request another reminder, or visit your support website. macOS and the MDM service enforce installation; this app provides the reminder interface.
## Features

- Automatic detection of pending DDM software updates.
- Compact floating reminders and a menu bar countdown.
- Customizable reminder text, branding, and timing.
- Deadline-aware reminders, persistent deferrals, and quiet hours.
- Managed configuration support, settings export, and reminder previews.

See the [Wiki](https://github.com/ecubrooks/DDM-Update-Companion/wiki) for configuration options and detailed behavior.

![DDM Update Companion Preferences preview](images/screenshots/DDM-preferences-preview.png)

## Quick start for macOS administrators
1. Deploy the release app or installer to `/Applications`.
2. Choose your settings workflow:
   - **Jamf Pro:** Download the raw [JSON schema](Configuration/com.ecubrooks.DDMUpdateCompanion.json) and use it in Application & Custom Settings.
   - **Configure visually:** Open Preferences → Save & Preview → Copy Settings, save the copied XML as a `.plist`, and upload it to your MDM's custom preferences payload.
   - **Complete profile:** Customize the [example mobileconfig](Configuration/DDMUpdateCompanion.example.mobileconfig).
3. Use preference domain **`com.ecubrooks.DDMUpdateCompanion`**. Include only keys you want to enforce.
4. Configure login startup and deploy any logo separately.
5. Send the actual macOS update enforcement policy through MDM and validate on a pilot Mac.
Follow the [step-by-step configuration guide](https://github.com/ecubrooks/DDM-Update-Companion/wiki/Managed-Configuration). JSON/PLIST settings alone do not install the app, start it, or schedule an OS update.
## Requirements and status

- macOS 15 or later; run in the logged-in user's desktop session.
- Source builds have been verified with Xcode 27.1. Older toolchains have not been verified; Xcode is not needed to run a distributed app.
- An MDM-managed test Mac with an applicable software update enforcement declaration for live validation.
A signed release build has been produced and verified by the maintainer. Initial live testing has been performed with an Xcode build. Packaging and further testing of the installed release are in progress; broad fleet and cross-MDM compatibility are not yet established.

## Build from source
1. Open `DDMUpdateCompanion.xcodeproj` in Xcode and select the **DDMUpdateCompanion** scheme.
2. Select your own signing team or **Sign to Run Locally** in Signing & Capabilities, then build and run on **My Mac**. The shared scheme has Display-Only Mode arguments disabled for live DDM testing.
3. Open the menu bar menu and choose **Preferences…**. If the icon is hidden because no update is pending, open the app again. The `--preferences` launch argument opens Preferences directly.
4. Configure and save your preferences, or deploy a managed profile from [Configuration](Configuration/README.md).
5. Schedule an applicable DDM update through your MDM and allow up to 60 seconds after the local state arrives for the app to refresh.
To preview the design without a real update, choose **Save & Preview** in Preferences. Preview buttons close the sample; they do not start an update.
## Wiki

Documentation is available in the [GitHub Wiki](https://github.com/ecubrooks/DDM-Update-Companion/wiki). These files are not needed inside the app or installer. Installation, Preferences, managed configuration, and troubleshooting are the main administrator guides; the pilot checklist helps validate your deployment.
- [Wiki home](https://github.com/ecubrooks/DDM-Update-Companion/wiki)
- [Setup and deployment](https://github.com/ecubrooks/DDM-Update-Companion/wiki/Setup)
- [Preferences/Settings](https://github.com/ecubrooks/DDM-Update-Companion/wiki/Preferences)
- [Managed configuration](https://github.com/ecubrooks/DDM-Update-Companion/wiki/Managed-Configuration)
- [DDM behavior](https://github.com/ecubrooks/DDM-Update-Companion/wiki/DDM-Integration)
- [Testing deployment checklist](https://github.com/ecubrooks/DDM-Update-Companion/wiki/Testing)
- [Troubleshooting](https://github.com/ecubrooks/DDM-Update-Companion/wiki/Troubleshooting)
## Configuration files

| File | Purpose |
| --- | --- |
| `Configuration/com.ecubrooks.DDMUpdateCompanion.json` | Jamf custom settings schema |
| `Configuration/DDMUpdateCompanion.example.mobileconfig` | Example managed app preferences |
| `Configuration/com.ecubrooks.DDMUpdateCompanion.agent.plist` | Optional example login LaunchAgent |

Preference domain: `com.ecubrooks.DDMUpdateCompanion`. Runtime deferrals are kept separately in `com.ecubrooks.DDMUpdateCompanion.state`.
## How detection works

The app reads `/var/db/softwareupdate/SoftwareUpdateDDMStatePersistence.plist`, extracts applicable target versions and deadlines, and ignores entries under `invalidDeclarations`. It filters installed targets and chooses the earliest upcoming deadline, or the most recent overdue deadline when none are upcoming.
This persistence file is an internal macOS implementation detail, not a public app API. Validate readability and parsing on every macOS release you deploy. A read failure appears in Preferences and does not discard a previously detected update. A successful read with no applicable target clears the reminder immediately. A previously detected reminder survives two consecutive missing-file checks and clears on the third.
## History

DDMUpdateCompanion implements macOS update reminders with a focus on popup presentation and menu bar interaction.
DDM Update Companion grew out of my work on my own Software Update Prompt project and a GitHub fork of [DDM OS Reminder](https://github.com/dan-snelson/DDM-OS-Reminder). I wanted a smaller popup notification that could sit in the upper-right corner of the screen rather than interrupting the user with a large, in-your-face popup. While I worked on fork and looking over my previous project, I started to realize the project's scope had become more complex than I wanted for a simple macOS update reminder.
I decided to take a different direction and build a native Swift app. Around that time, I had started spending more time in Xcode and experimenting with its Codex integration. That gave me an opportunity to rethink the interface and build what I felt would be a better more streamlined experience.
The [SUMB project](https://github.com/jeremy4971/sumb_public) also influenced the development of DDM Update Companion, particularly by helping me streamline some of the application's Preferences settings. The goal was to let macOS administrators customize its behavior for their environments.

See Apple's [software update enforcement documentation](https://developer.apple.com/documentation/devicemanagement/softwareupdateenforcementspecific) for the underlying MDM declaration.
## Acknowledgments

- Thanks to Dan Snelson's [DDM OS Reminder](https://github.com/dan-snelson/DDM-OS-Reminder) for inspiring the idea for this project's update reminders.
- Thanks to the [SUMB project's wiki](https://github.com/jeremy4971/sumb_public/wiki) for helpful guidance on configuring software update enforcement profiles.
## Privacy and local data

The current app reads local DDM state and the installed macOS version/build. It stores preferences and reminder deferrals locally and writes DDM read failures to macOS unified logging. It contains no analytics uploader or direct MDM-server client. Opening the configured support link uses the default browser; that website has its own privacy practices. Software Update and MDM network activity are handled by macOS and your management tools.
## Limitations and compatibility
- The internal DDM persistence file may change between macOS releases. A configured minimum of macOS 15 is not a claim of fleet validation on every later OS.
- The app does not install macOS updates, postpone the MDM deadline, or prove installation/compliance. Removing a declaration also clears its reminder.
- No Notification Center notifications, meeting/Focus detection, or weekly scheduling.
- Profiles must use this app's domain and case-sensitive keys; similar settings in other reminder tools are not interchangeable.
- During DDM read failures, the countdown and reminder rules continue using the last known deadline and current profile settings. Preferences reports the error and last successful read time. This cache lasts only for the running app session.
- Copy Settings exports the 16 GUI fields. Nine additional profile-only settings are configured through profiles or local defaults; see the configuration reference.
## License and redistribution

Released under the [MIT License](LICENSE). Copyright (c) 2026 Brooks Person. Anyone may use, modify, and redistribute the software, including commercially, provided the copyright and license notice are retained. The software is provided without warranty.
