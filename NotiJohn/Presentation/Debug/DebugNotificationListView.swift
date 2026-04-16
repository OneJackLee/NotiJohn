#if DEBUG
import SwiftUI

/// Iphone-side mirror of the CarPlay notification list. Exists to validate the
/// Unit 2 → Unit 4 pipeline without depending on a working CarPlay UI.
///
/// Functionally equivalent to the CarPlay screens:
/// - List shows captured notifications, most-recent first, with an unread dot.
/// - Tapping a row pushes a detail view that auto-marks-as-read.
/// - Swipe-to-delete dismisses a single notification.
/// - "Clear All" toolbar button (with confirmation) deletes everything.
struct DebugNotificationListView: View {
    @Bindable var viewModel: DebugNotificationListViewModel

    @State private var selectedNotificationId: NotificationId?
    @State private var showClearAllConfirm = false

    var body: some View {
        Group {
            if viewModel.summaries.isEmpty {
                ContentUnavailableView(
                    "No notifications",
                    systemImage: "bell.slash",
                    description: Text(
                        "Use \"Simulate Notification\" above to send one through the pipeline."
                    )
                )
            } else {
                List {
                    ForEach(viewModel.summaries) { summary in
                        Button {
                            selectedNotificationId = summary.notificationId
                        } label: {
                            row(for: summary)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.dismiss(id: summary.notificationId) }
                            } label: {
                                Label("Dismiss", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Captured")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear All", role: .destructive) {
                    showClearAllConfirm = true
                }
                .disabled(viewModel.summaries.isEmpty)
            }
        }
        .confirmationDialog(
            "Clear all notifications?",
            isPresented: $showClearAllConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                Task { await viewModel.clearAll() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .navigationDestination(item: $selectedNotificationId) { id in
            DebugNotificationDetailView(viewModel: viewModel, notificationId: id)
        }
        .task { await viewModel.onAppear() }
    }

    @ViewBuilder
    private func row(for summary: NotificationSummary) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(summary.readStatus == .unread ? Color.accentColor : Color.clear)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.title)
                    .font(.body)
                    .fontWeight(summary.readStatus == .unread ? .semibold : .regular)
                    .lineLimit(1)
                Text(summary.sourceAppName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(summary.capturedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

/// Pushed when a list row is tapped. Loading the detail also auto-marks the
/// notification as read (Unit 4's `AutoMarkAsReadOnViewPolicy`).
struct DebugNotificationDetailView: View {
    @Bindable var viewModel: DebugNotificationListViewModel
    let notificationId: NotificationId

    var body: some View {
        Form {
            if let detail = viewModel.detail, detail.notificationId == notificationId {
                Section("From") {
                    Text(detail.sourceAppName)
                }
                Section("Title") {
                    Text(detail.title)
                }
                Section("Message") {
                    Text(detail.body)
                        .textSelection(.enabled)
                }
                Section("Received") {
                    Text(detail.capturedAt, style: .relative) + Text(" ago")
                }
                Section("Status") {
                    Label(
                        detail.readStatus == .read ? "Read" : "Unread",
                        systemImage: detail.readStatus == .read
                            ? "envelope.open"
                            : "envelope.badge"
                    )
                }
            } else if let error = viewModel.detailError {
                Section { Text(error).foregroundStyle(.red) }
            } else {
                Section { ProgressView() }
            }
        }
        .navigationTitle("Detail")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: notificationId) {
            await viewModel.loadDetail(id: notificationId)
        }
    }
}

// MARK: - NotificationId conforms to Hashable already; no extra work needed
// for `navigationDestination(item:)`.
#endif
