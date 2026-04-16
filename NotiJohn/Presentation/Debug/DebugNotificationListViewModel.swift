#if DEBUG
import Foundation
import Combine
import Observation

/// Drives the iPhone-side debug list of captured notifications.
///
/// Reuses Unit 4's three application services so this view exercises the
/// **exact** code paths that drive CarPlay — list query, observe-changes
/// pipeline, auto-mark-as-read on detail view, dismiss, clear-all. If
/// notifications appear here, the cross-unit wiring (capture → persist →
/// publish → list refresh) is working independently of CarPlay.
@Observable
@MainActor
final class DebugNotificationListViewModel {
    private let listService: NotificationListAppService
    private let detailService: NotificationDetailAppService
    private let managementService: NotificationManagementAppService

    /// Most-recent-first list of summaries. Refreshed both on `onAppear` and
    /// in response to any notification-affecting domain event.
    var summaries: [NotificationSummary] = []

    /// Currently-loaded detail (for the pushed detail screen). `viewDetail`
    /// also publishes `NotificationMarkedAsRead` as a side effect, mirroring
    /// the CarPlay detail flow.
    var detail: NotificationDetail?
    var detailError: String?

    @ObservationIgnored
    private var cancellable: AnyCancellable?

    init(
        listService: NotificationListAppService,
        detailService: NotificationDetailAppService,
        managementService: NotificationManagementAppService
    ) {
        self.listService = listService
        self.detailService = detailService
        self.managementService = managementService
    }

    func onAppear() async {
        await refresh()
        // Subscribe once. Subsequent .onAppear calls (e.g. returning from
        // the detail screen) won't double-subscribe because `cancellable`
        // is overwritten — Combine drops the previous subscription.
        cancellable = listService.observeListChanges()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
    }

    func refresh() async {
        summaries = await listService.fetchNotificationList()
    }

    func loadDetail(id: NotificationId) async {
        do {
            detail = try await detailService.viewNotificationDetail(id: id)
            detailError = nil
        } catch {
            detail = nil
            detailError = "Could not load detail: \(error.localizedDescription)"
        }
    }

    func dismiss(id: NotificationId) async {
        try? await managementService.dismiss(id: id)
        // List refresh happens via the observeListChanges subscription.
    }

    func clearAll() async {
        try? await managementService.clearAll()
    }
}
#endif
