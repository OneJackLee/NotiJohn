import Foundation

/// `UserDefaults`-backed repository for `OnboardingProgress`.
public final class UserDefaultsOnboardingRepository: OnboardingProgressRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "onboarding_progress"

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
            ?? UserDefaults(suiteName: "group.com.onejacklee.notijohn")
            ?? .standard
    }

    public func get() async -> OnboardingProgress {
        guard let data = defaults.data(forKey: key) else {
            return OnboardingProgress()
        }
        do {
            return try JSONDecoder().decode(OnboardingProgress.self, from: data)
        } catch {
            return OnboardingProgress()
        }
    }

    public func save(_ progress: OnboardingProgress) async throws {
        let data = try JSONEncoder().encode(progress)
        defaults.set(data, forKey: key)
    }
}
