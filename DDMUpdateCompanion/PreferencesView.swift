import SwiftUI

struct PreferencesView: View {
    @Bindable var model: PreferencesModel
    @State private var preview: UpdateReminder? = nil

    var body: some View {
        VStack(spacing: 0) {
            Form {
                PopupPreferences(model: model)
                SchedulePreferences(model: model)
                LoginPreferences(model: model)
                BrandingPreferences(model: model)
                DDMStatusSection(model: model)
            }
            .formStyle(.grouped)

            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text(model.feedback).foregroundStyle(.secondary)
                    .accessibilityIdentifier("preferencesFeedback")
                HStack {
                    Button("Reload") { model.reload(); model.feedback = "Preferences reloaded." }
                    Button("Copy Settings") { model.copySettings() }
                    Spacer()
                    Button("Save & Preview") {
                        if model.save() { preview = model.previewReminder() }
                    }
                    Button("Save") { model.save() }
                        .keyboardShortcut("s", modifiers: .command)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("savePreferences")
                }
            }
            .padding()
        }
        .frame(minWidth: 600, idealWidth: 640, minHeight: 640, idealHeight: 740)
        .sheet(item: $preview) { reminder in
            VStack(spacing: 16) {
                Text("Preview — sample update").font(.headline)
                ReminderView(reminder: reminder, updateNow: { preview = nil }, dismiss: { preview = nil })
                Button("Close Preview") { preview = nil }
            }
            .padding(24)
        }
    }
}

extension UpdateReminder: Identifiable {
    var id: String { identifier }
}

private struct PopupPreferences: View {
    @Bindable var model: PreferencesModel

    var body: some View {
        Section("Popup reminders") {
            ManagedField(model: model, key: ManagedConfiguration.Key.popupEnabled) {
                Toggle("Show automatic popups", isOn: $model.popupEnabled)
            }
            ManagedField(model: model, key: ManagedConfiguration.Key.popupTitle) {
                TextField("Title", text: $model.popupTitle)
                    .accessibilityIdentifier("popupTitle")
            }
            ManagedField(model: model, key: ManagedConfiguration.Key.popupMessage) {
                TextField("Message", text: $model.popupMessage, axis: .vertical)
                    .lineLimit(2...5)
            }
            ManagedField(model: model, key: ManagedConfiguration.Key.popupLeadDays) {
                Stepper("Begin reminders: \(model.popupLeadDays) days before deadline", value: $model.popupLeadDays, in: 0...365)
            }
            Text("Within 24 hours, Remind Later is fixed at one hour; within eight hours, it is fixed at 15 minutes. The interval below applies only earlier.")
                .font(.caption).foregroundStyle(.secondary)
            Text("Set 0 to begin as soon as a managed update is detected.").font(.caption).foregroundStyle(.secondary)
            ManagedField(model: model, key: ManagedConfiguration.Key.reminderIntervalMinutes) {
                Stepper("Remind later (24+ hours remaining): \(model.reminderIntervalMinutes) minutes", value: $model.reminderIntervalMinutes, in: 1...1440)
            }
            ManagedField(model: model, key: ManagedConfiguration.Key.hideRemindLaterButton) {
                Toggle("Hide the Remind Later button", isOn: $model.hideRemindLaterButton)
            }
            ManagedField(model: model, key: ManagedConfiguration.Key.hideRemindLaterButtonDays) {
                Stepper("Hide with \(model.hideRemindLaterButtonDays) days remaining", value: $model.hideRemindLaterButtonDays, in: 0...365)
            }
            ManagedField(model: model, key: ManagedConfiguration.Key.hideRemindLaterButtonHours) {
                Stepper("Plus \(model.hideRemindLaterButtonHours) hours", value: $model.hideRemindLaterButtonHours, in: 0...23)
            }
            Text("When hiding is enabled, days and hours are combined. Set both to 0 to hide the button for the entire reminder.")
                .font(.caption).foregroundStyle(.secondary)
            ManagedField(model: model, key: ManagedConfiguration.Key.hideIconWhenInactive) {
                Toggle("Hide menu bar icon when no update is pending", isOn: $model.hideIconWhenInactive)
            }
            Text("If the icon is hidden, open the app again to access Preferences. Remind Later never changes the enforced update deadline.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct SchedulePreferences: View {
    @Bindable var model: PreferencesModel

    var body: some View {
        Section("Quiet hours") {
            ManagedField(model: model, key: ManagedConfiguration.Key.quietHoursEnabled) {
                Toggle("Pause automatic popups during quiet hours", isOn: $model.quietHoursEnabled)
            }
            ManagedField(model: model, key: ManagedConfiguration.Key.quietHoursStartHour) {
                Stepper("Start hour: \(model.quietHoursStartHour):00", value: $model.quietHoursStartHour, in: 0...23)
            }
            ManagedField(model: model, key: ManagedConfiguration.Key.quietHoursEndHour) {
                Stepper("End hour: \(model.quietHoursEndHour):00", value: $model.quietHoursEndHour, in: 0...23)
            }
            ManagedField(model: model, key: ManagedConfiguration.Key.quietHoursUrgentOverride) {
                Toggle("Allow reminders in the final eight hours and while overdue", isOn: $model.quietHoursUrgentOverride)
            }
            Text("Uses this Mac’s local time and a 24-hour clock. The menu bar remains available. Show Update Reminder can still open the popup manually.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct LoginPreferences: View {
    @Bindable var model: PreferencesModel

    var body: some View {
        Section("Startup") {
            ManagedField(model: model, key: ManagedConfiguration.Key.launchAtLogin) {
                Toggle("Launch at login", isOn: $model.launchAtLogin)
            }
            Text(model.loginStatus).foregroundStyle(.secondary)
            if model.loginNeedsApproval {
                Button("Open Login Items Settings") { model.onOpenLoginSettings?() }
            }
            Text("Save to apply. macOS may require approval in Login Items. Use either this setting or the deployed LaunchAgent.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct BrandingPreferences: View {
    @Bindable var model: PreferencesModel

    var body: some View {
        Section("Branding and support") {
            ManagedField(model: model, key: ManagedConfiguration.Key.supportURL) {
                TextField("Support URL (HTTPS)", text: $model.supportURL)
                    .accessibilityIdentifier("supportURL")
            }
            ManagedField(model: model, key: ManagedConfiguration.Key.customLogoPath) {
                TextField("Logo file path", text: $model.customLogoPath)
            }
            Text("Use an absolute path to an image up to 5 MB. Deploy the image separately when using MDM.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct DDMStatusSection: View {
    let model: PreferencesModel

    var body: some View {
        Section("Managed update status") {
            Text(model.status).textSelection(.enabled)
            if let version = model.activeVersion {
                LabeledContent("Required version", value: version)
            }
            if let deadline = model.activeDeadline {
                LabeledContent("Deadline") { Text(deadline, format: .dateTime) }
            }
            if let checked = model.lastChecked {
                LabeledContent("Last checked") { Text(checked, format: .dateTime) }
            }
            Text(model.reminderStatus)
            if let date = model.deferredUntil {
                LabeledContent("Deferred until") { Text(date, format: .dateTime) }
            }
            HStack {
                Button("Refresh Now") { model.onRefresh?() }
                Button("Reset Deferral") { model.onResetDeferral?() }
                    .disabled(model.activeVersion == nil)
            }
            Text("The app checks every 60 seconds. macOS and your MDM enforce the update.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct ManagedField<Content: View>: View {
    let model: PreferencesModel
    let key: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content.disabled(model.isManaged(key))
            if model.isManaged(key) {
                Label("Managed by your organization", systemImage: "lock.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
