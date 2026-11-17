import AppKit
import SwiftUI

struct ReminderView: View {
    let reminder: UpdateReminder
    let updateNow: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReminderHeader(
                title: reminder.title,
                customLogoData: reminder.customLogoData
            )
            Text(reminder.message)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            details
            TimelineView(.periodic(from: .now, by: 60)) { context in
                ReminderActions(
                    allowsDeferral: reminder.canDefer(at: context.date),
                    supportURL: reminder.supportURL,
                    updateNow: updateNow,
                    dismiss: dismiss
                )
            }
        }
        .padding(16)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var details: some View {
        VStack(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top) {
                    requiredVersion

                    Spacer(minLength: 24)

                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        timeRemaining(at: context.date, alignment: .trailing)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    requiredVersion

                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        timeRemaining(at: context.date, alignment: .leading)
                    }
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Text("Deadline")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Text(reminder.deadline, format: .dateTime.month(.abbreviated).day().year().hour().minute())
            }
        }
        .font(.subheadline)
    }

    private var requiredVersion: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Required version")
                .foregroundStyle(.secondary)
            Text(reminder.requiredVersion)
                .font(.headline)
        }
    }

    private func timeRemaining(at date: Date, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text("Time remaining")
                .foregroundStyle(.secondary)
            Text(reminder.remainingTime(at: date))
                .font(.title3)
                .fontWeight(.semibold)
        }
    }

}

private struct ReminderHeader: View {
    let title: String
    let customLogoData: Data?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ReminderIcon(customLogoData: customLogoData)

            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ReminderIcon: View {
    let customLogoData: Data?

    var body: some View {
        if let customLogoData,
           let image = NSImage(data: customLogoData) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .accessibilityLabel("Organization logo")
        } else {
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.circle.fill")
                .font(.title)
                .foregroundStyle(.tint)
                .accessibilityLabel("Software Update")
        }
    }
}

private struct ReminderActions: View {
    let allowsDeferral: Bool
    let supportURL: URL?
    let updateNow: () -> Void
    let dismiss: () -> Void

    var body: some View {
        Group {
            if allowsDeferral {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        Spacer()
                        Button("Remind Later", action: dismiss)
                        Button("Update Now", action: updateNow)
                            .buttonStyle(.borderedProminent)
                        SupportLink(url: supportURL)
                    }

                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Spacer()
                            Button("Update Now", action: updateNow)
                                .buttonStyle(.borderedProminent)
                            SupportLink(url: supportURL)
                        }
                        Button("Remind Later", action: dismiss)
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Spacer()
                    Button("Update Now", action: updateNow)
                        .buttonStyle(.borderedProminent)
                    SupportLink(url: supportURL)
                }
            }
        }
        .controlSize(.large)
    }
}

private struct SupportLink: View {
    let url: URL?

    var body: some View {
        if let url {
            Link(destination: url) {
                Image(systemName: "questionmark")
                    .font(.caption2)
                    .frame(width: 10, height: 10)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .controlSize(.small)
            .help("Open support website")
            .accessibilityLabel("Help")
            .accessibilityHint("Opens the support website")
        }
    }
}

#Preview("Normal deadline") {
    ReminderView(
        reminder: previewReminder(deadline: .now.addingTimeInterval(3 * 24 * 60 * 60)),
        updateNow: {},
        dismiss: {}
    )
    .padding()
}

#Preview("Less than 24 hours") {
    ReminderView(
        reminder: previewReminder(deadline: .now.addingTimeInterval(8 * 60 * 60)),
        updateNow: {},
        dismiss: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Overdue") {
    ReminderView(
        reminder: previewReminder(deadline: .now.addingTimeInterval(-60)),
        updateNow: {},
        dismiss: {}
    )
    .padding()
}

private func previewReminder(deadline: Date) -> UpdateReminder {
    UpdateReminder(
        requiredVersion: "macOS 27.1",
        deadline: deadline,
        title: "macOS Update Required",
        message: "A software update is required for your Mac.",
        isRequired: true
    )
}
