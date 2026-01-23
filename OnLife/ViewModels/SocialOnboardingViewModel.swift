import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

// MARK: - Social Onboarding View Model

@MainActor
final class SocialOnboardingViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var currentPage: SocialOnboardingPage = .welcome
    @Published var principles: [SocialCommitmentPrinciple] = SocialCommitmentPrinciple.allPrinciples
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var hasCompletedOnboarding: Bool = false

    // Animation states
    @Published var isAnimatingTransition: Bool = false
    @Published var contentOpacity: Double = 1.0

    // MARK: - Computed Properties

    var progress: Double {
        let totalPages = Double(SocialOnboardingPage.allCases.count)
        let currentIndex = Double(currentPage.rawValue)
        return (currentIndex + 1) / totalPages
    }

    var canProceed: Bool {
        if currentPage == .commitment {
            return allPrinciplesAccepted
        }
        return true
    }

    var allPrinciplesAccepted: Bool {
        principles.allSatisfy { $0.isAccepted }
    }

    var acceptedPrinciplesCount: Int {
        principles.filter { $0.isAccepted }.count
    }

    var isFirstPage: Bool {
        currentPage == .welcome
    }

    var isLastPage: Bool {
        currentPage == .commitment
    }

    var nextButtonTitle: String {
        switch currentPage {
        case .welcome:
            return "Show Me the Science"
        case .flowIsSacred:
            return "This Makes Sense"
        case .learnFromEachOther:
            return "I Want to Learn"
        case .trajectoriesOverTrophies:
            return "I Want Healthy Comparison"
        case .commitment:
            return "I Commit to This"
        }
    }

    // MARK: - Private Properties

    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // Load any saved state if needed
    }

    // MARK: - Navigation

    func nextPage() {
        guard canProceed else { return }

        if isLastPage {
            completeOnboarding()
            return
        }

        animateTransition {
            if let nextIndex = SocialOnboardingPage(rawValue: self.currentPage.rawValue + 1) {
                self.currentPage = nextIndex
            }
        }

        HapticManager.shared.impact(style: .light)
    }

    func previousPage() {
        guard !isFirstPage else { return }

        animateTransition {
            if let prevIndex = SocialOnboardingPage(rawValue: self.currentPage.rawValue - 1) {
                self.currentPage = prevIndex
            }
        }

        HapticManager.shared.impact(style: .light)
    }

    func goToPage(_ page: SocialOnboardingPage) {
        guard page != currentPage else { return }

        animateTransition {
            self.currentPage = page
        }
    }

    private func animateTransition(completion: @escaping () -> Void) {
        isAnimatingTransition = true

        withAnimation(.easeOut(duration: 0.15)) {
            contentOpacity = 0.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            completion()

            withAnimation(.easeIn(duration: 0.2)) {
                self.contentOpacity = 1.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.isAnimatingTransition = false
            }
        }
    }

    // MARK: - Commitment Principles

    func togglePrinciple(_ principle: SocialCommitmentPrinciple) {
        guard let index = principles.firstIndex(where: { $0.id == principle.id }) else { return }

        principles[index].isAccepted.toggle()

        if principles[index].isAccepted {
            HapticManager.shared.impact(style: .medium)
        } else {
            HapticManager.shared.impact(style: .light)
        }
    }

    func acceptAllPrinciples() {
        for index in principles.indices {
            principles[index].isAccepted = true
        }
        HapticManager.shared.notificationOccurred(.success)
    }

    // MARK: - Onboarding Completion

    func completeOnboarding() {
        guard allPrinciplesAccepted else {
            errorMessage = "Please accept all principles to continue"
            HapticManager.shared.notificationOccurred(.error)
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await saveOnboardingCompletion()
                hasCompletedOnboarding = true
                HapticManager.shared.notificationOccurred(.success)
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                HapticManager.shared.notificationOccurred(.error)
            }
            isLoading = false
        }
    }

    private func saveOnboardingCompletion() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw SocialOnboardingError.notAuthenticated
        }

        let acceptedPrincipleIds = principles.filter { $0.isAccepted }.map { $0.id }

        let data: [String: Any] = [
            "socialOnboardingCompleted": true,
            "socialOnboardingCompletedAt": Timestamp(date: Date()),
            "acceptedPrinciples": acceptedPrincipleIds,
            "updatedAt": Timestamp(date: Date())
        ]

        try await db.collection("users").document(userId).setData(data, merge: true)

        // Also save to UserDefaults for quick local access
        UserDefaults.standard.set(true, forKey: "socialOnboardingCompleted")
        UserDefaults.standard.set(Date(), forKey: "socialOnboardingCompletedAt")
    }

    // MARK: - Skip (for testing/development)

    #if DEBUG
    func skipOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "socialOnboardingCompleted")
    }
    #endif
}

// MARK: - Errors

enum SocialOnboardingError: LocalizedError {
    case notAuthenticated
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to complete onboarding"
        case .saveFailed(let error):
            return "Failed to save progress: \(error.localizedDescription)"
        }
    }
}

// MARK: - Haptic Manager Extension (if not already defined)

extension HapticManager {
    func notificationOccurred(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
