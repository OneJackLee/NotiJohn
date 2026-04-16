import Foundation
import Combine

/// Cross-unit event bus. All units share a single instance for intra-process integration.
public protocol DomainEventBus: AnyObject {
    func publish(_ event: DomainEvent)
    func subscribe<T: DomainEvent>(to eventType: T.Type) -> AnyPublisher<T, Never>
}

/// Combine-backed implementation. Events are passed through a single subject
/// and filtered to the requested concrete type via `compactMap`.
public final class CombineDomainEventBus: DomainEventBus {
    private let subject = PassthroughSubject<DomainEvent, Never>()

    public init() {}

    public func publish(_ event: DomainEvent) {
        subject.send(event)
    }

    public func subscribe<T: DomainEvent>(to eventType: T.Type) -> AnyPublisher<T, Never> {
        subject.compactMap { $0 as? T }.eraseToAnyPublisher()
    }
}
