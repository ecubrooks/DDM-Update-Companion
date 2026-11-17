# Testing

## Automated checks

Run Product > Test in the shared Xcode scheme. Swift Testing covers DDM plist parsing, local and explicit timezone deadlines, installed targets, invalid declarations, changed/removed files, preference persistence, validation, managed-lock behavior, export, and deferral persistence.

The UI test opens Preferences with --preferences. On a managed Mac it checks the locked control and label; on an unmanaged Mac it checks rejection of an invalid support URL.

## Display-Only Mode

In a Run action enable:

```text
--display-only --display-only-scenario days
```

Other scenarios: hours, minutes, dueNow, overdue, farFuture, custom. Custom uses `DisplayOnlyDeadline`. Packaged Release builds can select this simulated provider through `DisplayOnlyModeEnabled`. The reminder is visibly marked as Display Only and does not detect or enforce an update. Provider selection occurs at launch, so restart after changing the setting. Remove display-only arguments and disable `DisplayOnlyModeEnabled` before live testing. A managed false value prevents `--display-only` from overriding it.

The Preferences preview is a sample and works without selecting the mock provider.

## Live test matrix

| Test | Expected result |
| --- | --- |
| No applicable declaration | No popup; icon visibility follows preferences. |
| New declaration arrives | Version/deadline appear within the next refresh after local state arrives. |
| Deadline changes | New identity and countdown; old deferral does not suppress it. |
| Remind Later, then relaunch | Popup stays deferred until the saved time or deadline. |
| Deadline reached | Overdue state; no Remind Later button. |
| Update Now | Software Update opens; popup pauses ten minutes. |
| Installed target after reboot | Reminder clears once installed target is filtered. |
| Declaration removed | Reminder clears when local persistence reflects removal. |
| Unreadable/corrupt file | Error and last successful read time appear; cached countdown and current profile rules continue refreshing. |
| Temporarily missing file | Cached reminder survives two missing checks; third consecutive missing check clears it. A successful read or other error resets the count. |
| Managed settings changed | Effective production values refresh; forced fields stay locked. |
| Managed profile removed | Local/default values become effective. |
| External display changed | Popup remains within the selected display's visible frame. |

Use MDM to generate real state; do not overwrite the system persistence file to simulate an update. Fixture tests use temporary files. Record macOS build, MDM product, declaration target/deadline, and observed app status for fleet acceptance.

Signed/notarized distribution and live MDM delivery are not validated by unit tests.
