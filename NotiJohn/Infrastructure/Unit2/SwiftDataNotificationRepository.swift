import Foundation
import SwiftData

/// SwiftData-backed `NotificationRepository`.
///
/// SwiftData's `ModelContext` is not `Sendable`, so every operation that
/// touches it is funnelled through `MainActor.run`. The class itself stays
/// non-isolated so it can be constructed and stored from any context (e.g.
/// the `AppContainer.init` initializer chain).
public final class SwiftDataNotificationRepository: NotificationRepository, @unchecked Sendable {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Writes

    public func save(_ notification: Notification) async throws {
        try await MainActor.run {
            let model = NotificationModel(from: notification)
            modelContext.insert(model)
            try modelContext.save()
        }
    }

    public func pruneOldest(exceeding limit: Int) async throws -> Int {
        try await MainActor.run {
            let descriptor = FetchDescriptor<NotificationModel>(
                sortBy: [SortDescriptor(\.capturedAt, order: .forward)]
            )
            let all = try modelContext.fetch(descriptor)
            let toPrune = max(0, all.count - limit)
            guard toPrune > 0 else { return 0 }
            for model in all.prefix(toPrune) {
                modelContext.delete(model)
            }
            try modelContext.save()
            return toPrune
        }
    }

    // MARK: - Reads

    public func findById(_ id: NotificationId) async -> Notification? {
        await MainActor.run {
            let target = id.value
            var descriptor = FetchDescriptor<NotificationModel>(
                predicate: #Predicate { $0.id == target }
            )
            descriptor.fetchLimit = 1
            let models = (try? modelContext.fetch(descriptor)) ?? []
            return models.first?.toDomain()
        }
    }

    public func findAll(sortedBy: NotificationSortOrder) async -> [Notification] {
        await MainActor.run {
            let descriptor: FetchDescriptor<NotificationModel>
            switch sortedBy {
            case .mostRecent:
                descriptor = FetchDescriptor<NotificationModel>(
                    sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
                )
            }
            let models = (try? modelContext.fetch(descriptor)) ?? []
            return models.map { $0.toDomain() }
        }
    }

    public func findAllUnread() async -> [Notification] {
        await MainActor.run {
            let unreadRaw = ReadStatus.unread.rawValue
            let descriptor = FetchDescriptor<NotificationModel>(
                predicate: #Predicate { $0.readStatusRaw == unreadRaw },
                sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
            )
            let models = (try? modelContext.fetch(descriptor)) ?? []
            return models.map { $0.toDomain() }
        }
    }

    public func count() async -> Int {
        await MainActor.run {
            let descriptor = FetchDescriptor<NotificationModel>()
            return (try? modelContext.fetchCount(descriptor)) ?? 0
        }
    }

    public func oldestRemainingTimestamp() async -> CaptureTimestamp? {
        await MainActor.run {
            var descriptor = FetchDescriptor<NotificationModel>(
                sortBy: [SortDescriptor(\.capturedAt, order: .forward)]
            )
            descriptor.fetchLimit = 1
            let models = (try? modelContext.fetch(descriptor)) ?? []
            return models.first.map { CaptureTimestamp($0.capturedAt) }
        }
    }

    // MARK: - Deletes

    public func delete(_ id: NotificationId) async throws {
        try await MainActor.run {
            let target = id.value
            let descriptor = FetchDescriptor<NotificationModel>(
                predicate: #Predicate { $0.id == target }
            )
            let models = try modelContext.fetch(descriptor)
            for model in models {
                modelContext.delete(model)
            }
            try modelContext.save()
        }
    }

    public func deleteAll() async throws -> Int {
        try await MainActor.run {
            let descriptor = FetchDescriptor<NotificationModel>()
            let all = try modelContext.fetch(descriptor)
            let count = all.count
            for model in all {
                modelContext.delete(model)
            }
            try modelContext.save()
            return count
        }
    }
}
