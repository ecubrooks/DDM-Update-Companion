# MDM compatibility and update behavior

## Can I use another MDM?

The reader is not tied to Jamf. It reads the Mac's local DDM update state and does not connect to an MDM server or require vendor API credentials.

Apple defines a specific update-enforcement declaration with a target OS and deadline. This is the kind of enforcement data the reader expects. See [Apple's DDM update guidance](https://developer.apple.com/documentation/devicemanagement/deploying-software-updates-using-declarative-management).

**Cross-MDM compatibility is conditional, not verified fleet support.** Code review confirms no vendor-specific dependency. The maintainer has performed initial live testing with an Xcode build; packaged deployment testing is still in progress. Vendor-specific results have not yet been documented for the products below. Their documentation verifies DDM capabilities, not this app. Pilot the exact policy you use before deployment.

| MDM | Vendor documents DDM update enforcement | This app's verification status |
| --- | --- | --- |
| Jamf Pro | [Managed software updates and Blueprints](https://learn.jamf.com/r/en-US/jamf-pro-documentation-current/Declarative_Device_Management) | Live pilot required |
| Microsoft Intune | [Apple update policies using DDM](https://learn.microsoft.com/en-us/mem/intune/protect/software-updates-declarative-ios-macos) | Live pilot required |
| Kandji | [DDM and Managed OS](https://support.kandji.io/kb/declarative-device-management-and-managed-os) | Live pilot required |
| SimpleMDM | [Managed Software Updates profile](https://simplemdm.pdq.com/hc/en-us/articles/41831217946779-Profile-Managed-Software-Updates) | Live pilot required |
| Other MDMs | Confirm support for Apple DDM update enforcement with a deadline | Not verified |

## Conditions and limitations

The app depends on macOS's internal local DDM state file, not a supported public reader API. Vendor DDM support alone cannot guarantee that the file is readable or contains the target in a form this app recognizes. No live environments for those products were available during this review.

Use a DDM enforcement policy that supplies a target and deadline. Legacy update commands, deferral-only profiles, automatic-update settings, or a vendor's own update agent do not by themselves supply the data this reader needs. Policies described as “latest version” or “minimum version” need a pilot: the reader requires a concrete target and deadline in local state; it does not resolve such policies itself.

A missing reminder does not prove the Mac is compliant. Verify installation and enforcement in your MDM. The app does not report compliance, change the deadline, or suppress Apple's update interface.

## What users see

The app checks for pending updates approximately every 60 seconds. It counts down to the deadline received through DDM, using local time for a deadline without an explicit timezone. If several applicable targets exist, it shows the earliest upcoming deadline, or the most recent overdue deadline if all have passed.

Remind Later delays this app's popup only. It does not postpone enforcement. Update Now opens Software Update and pauses automatic popups for ten minutes; opening Settings does not confirm installation started.

## Missing or unreadable state

A successful read confirming no pending target clears the reminder. A temporarily missing file retains an existing reminder for two consecutive checks and clears it on the third; manual refreshes also count.

Other read errors retain the last known deadline while countdown and profile-controlled reminder rules continue. Preferences shows the error and last successful read time. A successful read or a different read error resets the missing-file count. The cached deadline lasts only while the app is running.

Complete the [pilot checklist](Testing.md) with your MDM. If it fails, use [Troubleshooting](Troubleshooting.md) and report sanitized observations rather than assuming vendor compatibility.
