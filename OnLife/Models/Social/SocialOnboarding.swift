import Foundation

// MARK: - Social Onboarding Page

enum SocialOnboardingPage: Int, CaseIterable, Identifiable {
    case welcome = 0
    case flowIsSacred = 1
    case learnFromEachOther = 2
    case trajectoriesOverTrophies = 3
    case commitment = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome:
            return "Welcome to the Flow Community"
        case .flowIsSacred:
            return "Flow Is Sacred"
        case .learnFromEachOther:
            return "Learn From Each Other"
        case .trajectoriesOverTrophies:
            return "Trajectories Over Trophies"
        case .commitment:
            return "Your Commitment"
        }
    }

    var subtitle: String? {
        switch self {
        case .welcome:
            return "A different kind of social"
        case .flowIsSacred:
            return "We protect your focus"
        case .learnFromEachOther:
            return "Positive-sum networking"
        case .trajectoriesOverTrophies:
            return "Non-toxic comparison"
        case .commitment:
            return nil
        }
    }

    var icon: String {
        switch self {
        case .welcome:
            return "person.3.fill"
        case .flowIsSacred:
            return "brain.head.profile"
        case .learnFromEachOther:
            return "arrow.triangle.2.circlepath"
        case .trajectoriesOverTrophies:
            return "chart.line.uptrend.xyaxis"
        case .commitment:
            return "checkmark.seal.fill"
        }
    }

    var bodyText: String {
        switch self {
        case .welcome:
            return """
            Most apps use social features to keep you addicted. We use them to help you master your own mind.

            Here's what makes OnLife different:

            • We show trajectories, not just scores
            • We explain the psychology behind every feature
            • We help your friends help you (and vice versa)
            • We designed for graduation, not addiction

            Ready to see how social learning really works?
            """
        case .flowIsSacred:
            return """
            Csikszentmihalyi's research showed that flow requires loss of self-consciousness. The moment you're aware of being observed, you shift from flow to performance mode.

            That's why OnLife shows zero friend activity during your sessions. We connect you before and after. During, you're alone with your focus.

            Focus alone. Celebrate together.
            """
        case .learnFromEachOther:
            return """
            Albert Bandura discovered that humans learn fastest by observing successful people similar to themselves.

            The Protocol Library shows you HOW others achieve flow, not just THAT they achieved it. Your friends' discoveries become your shortcuts.

            When someone finds what works, everyone benefits. This is positive-sum social—your success helps others succeed.
            """
        case .trajectoriesOverTrophies:
            return """
            Research shows comparison has two modes:

            TOXIC: "They scored 92, I scored 78"
            → Compares states, creates anxiety

            HEALTHY: "They improved 23% last month"
            → Compares growth, creates learning

            OnLife defaults to showing trajectories because your growth rate matters more than where you are right now. Where you're going beats where you've been.
            """
        case .commitment:
            return """
            By joining the Flow Community, you're agreeing to support a different kind of social experience—one built on mutual growth rather than competition.
            """
        }
    }

    var citation: String? {
        switch self {
        case .flowIsSacred:
            return "Csikszentmihalyi, \"Flow\" (1990)"
        case .learnFromEachOther:
            return "Bandura, Social Learning Theory (1977)"
        case .trajectoriesOverTrophies:
            return "Dweck, \"Mindset\" (2006)"
        default:
            return nil
        }
    }
}

// MARK: - Commitment Principles

struct SocialCommitmentPrinciple: Identifiable {
    let id: String
    let title: String
    let description: String
    var isAccepted: Bool

    static let allPrinciples: [SocialCommitmentPrinciple] = [
        SocialCommitmentPrinciple(
            id: "protect_flow",
            title: "I will protect others' flow",
            description: "No notifications or interruptions during sessions",
            isAccepted: false
        ),
        SocialCommitmentPrinciple(
            id: "share_learnings",
            title: "I will share what works",
            description: "Contributing discoveries helps everyone improve",
            isAccepted: false
        ),
        SocialCommitmentPrinciple(
            id: "healthy_comparison",
            title: "I will compare for learning, not ego",
            description: "Focus on trajectories over standings",
            isAccepted: false
        ),
        SocialCommitmentPrinciple(
            id: "support_growth",
            title: "I will support others' growth",
            description: "Celebrate progress, not just achievements",
            isAccepted: false
        )
    ]
}

// MARK: - Social Onboarding State

struct SocialOnboardingState: Codable {
    var hasCompletedOnboarding: Bool
    var completedAt: Date?
    var acceptedPrinciples: [String]  // IDs of accepted principles

    init() {
        self.hasCompletedOnboarding = false
        self.completedAt = nil
        self.acceptedPrinciples = []
    }

    var allPrinciplesAccepted: Bool {
        let requiredPrinciples = Set(SocialCommitmentPrinciple.allPrinciples.map { $0.id })
        return requiredPrinciples.isSubset(of: Set(acceptedPrinciples))
    }

    mutating func acceptPrinciple(_ id: String) {
        if !acceptedPrinciples.contains(id) {
            acceptedPrinciples.append(id)
        }
    }

    mutating func revokePrinciple(_ id: String) {
        acceptedPrinciples.removeAll { $0 == id }
    }

    mutating func completeOnboarding() {
        hasCompletedOnboarding = true
        completedAt = Date()
    }
}
