# Pilot deployment checklist

Scope the app and configuration profile to a small group of enrolled test Macs before wider deployment. Use Display-Only Mode to validate the packaged app and reminder scenarios before creating DDM policy; use a real DDM enforcement policy for final acceptance.

| Check | Expected result |
| --- | --- |
| Install and open | App runs in the user session; Preferences is accessible even when the idle icon is hidden. |
| Apply the app profile | Intended controls are locked and settings apply; unmanaged controls remain editable. |
| Branding | Logo is readable and the support link opens the intended HTTPS destination. |
| Display-Only Mode | The packaged Release app shows the selected simulated scenario, and both the status and reminder clearly say Display Only. Disable it and restart before live DDM testing. |
| Start at login | App appears after logout/login with your chosen startup method. |
| Send a DDM enforcement policy | Preferences shows the same target and deadline as the effective MDM policy after local state arrives. |
| Change the deadline | The countdown changes on a later refresh; the old deferral does not suppress the new target. |
| Remind Later | Popup pauses without changing the enforcement deadline. |
| Quiet hours | Automatic popups follow quiet hours and urgent-override settings. |
| Update Now | Software Update opens; the app pauses popups temporarily. |
| Complete the update | Reminder clears once the installed target is recognized. |
| Remove the declaration | Reminder clears after local state confirms removal, subject to the missing-file grace period. |
| Change/remove app settings | Managed values refresh; previously saved local values may return after removal. |

Use MDM reporting to confirm actual installation. Keep a record of the MDM product, policy type, device platform, expected deadline, and observed result so your team knows which deployment combinations it has validated.

Do not edit or change permissions on macOS's DDM state file to force a test. Follow [Troubleshooting](Troubleshooting.md) if the app does not detect your policy.
