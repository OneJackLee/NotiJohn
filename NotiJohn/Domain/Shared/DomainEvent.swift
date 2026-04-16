import Foundation

/// Base protocol for all domain events published on the `DomainEventBus`.
public protocol DomainEvent {
    var occurredAt: Date { get }
}
