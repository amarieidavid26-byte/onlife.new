import Foundation

// MARK: - Philosophy Moment Category

enum PhilosophyMomentCategory: String, Codable, CaseIterable {
    case social = "Social Psychology"
    case behavioral = "Behavioral Psychology"
    case flow = "Flow Science"
    case meta = "Meta"

    var icon: String {
        switch self {
        case .social: return "person.3.fill"
        case .behavioral: return "brain"
        case .flow: return "waveform.path"
        case .meta: return "lightbulb.fill"
        }
    }
}

// MARK: - Philosophy Moment Trigger

enum PhilosophyMomentTrigger: String, Codable {
    case firstComparison = "first_comparison"
    case firstProtocolView = "first_protocol_view"
    case comparisonModeToggle = "comparison_mode_toggle"
    case connectionLimitReached = "connection_limit_reached"
    case sessionWithFriendsOnline = "session_with_friends_online"
    case firstBadgeEarned = "first_badge_earned"
    case joiningChallenge = "joining_challenge"
    case bonusRewardReceived = "bonus_reward_received"
    case plantWiltingWarning = "plant_wilting_warning"
    case streakFreezeUsed = "streak_freeze_used"
    case sessionCompleted = "session_completed"
    case firstPlantGrown = "first_plant_grown"
    case firstSettingsVisit = "first_settings_visit"
    case firstHeatmapView = "first_heatmap_view"
    case chronotypeOnProfile = "chronotype_on_profile"
    case firstWhoopSession = "first_whoop_session"
    case flowScoreExplanation = "flow_score_explanation"
    case firstSubstanceLog = "first_substance_log"
    case firstPhilosophyMomentSeen = "first_philosophy_moment_seen"
    case after30Days = "after_30_days"
    case firstPrivacySettingsView = "first_privacy_settings_view"
    case afterThirdCitation = "after_third_citation"
    case philosophyMomentSystemExplained = "philosophy_moment_system_explained"
}

// MARK: - Philosophy Moment

struct PhilosophyMoment: Identifiable, Codable {
    let id: String
    let category: PhilosophyMomentCategory
    let trigger: PhilosophyMomentTrigger
    let icon: String
    let title: String
    let body: String
    let citation: String?
    let actionText: String
    let learnMoreURL: URL?

    // Display
    var formattedCitation: String? {
        guard let citation = citation else { return nil }
        return "— \(citation)"
    }
}

// MARK: - Philosophy Moments Library

struct PhilosophyMomentsLibrary {

    // MARK: - Social Psychology Moments (1.x)

    static let trajectoriesMatterMore = PhilosophyMoment(
        id: "1.1_trajectories",
        category: .social,
        trigger: .firstComparison,
        icon: "chart.line.uptrend.xyaxis",
        title: "Why We Show Growth, Not Standing",
        body: """
        Psychologist Carol Dweck spent decades studying why some people thrive under challenge while others crumble.

        Her discovery: It's all about what you compare.

        Fixed mindset: "How do I rank against others?"
        Growth mindset: "Am I improving?"

        People who focus on growth rate become more resilient, take more risks, and ultimately achieve more. People who focus on standing become fragile and avoid challenge.

        That's why OnLife shows your trajectory—your improvement over time—before your absolute score. Where you're going matters more than where you are.
        """,
        citation: "Carol Dweck, \"Mindset: The New Psychology of Success\" (2006)",
        actionText: "Compare trajectories, not positions",
        learnMoreURL: URL(string: "https://en.wikipedia.org/wiki/Mindset#Fixed_and_growth_mindsets")
    )

    static let socialLearning = PhilosophyMoment(
        id: "1.2_social_learning",
        category: .social,
        trigger: .firstProtocolView,
        icon: "arrow.triangle.2.circlepath",
        title: "The Science of Learning from Others",
        body: """
        Albert Bandura won psychology's most prestigious prize for a simple but profound discovery:

        Humans learn fastest by watching successful people who are similar to them.

        Not by reading instructions. Not by trial and error. By observation.

        The Protocol Library isn't just a collection of tips—it's structured observational learning. When you see someone with your chronotype and HRV pattern succeed with a specific protocol, you're not starting from scratch. You're standing on their shoulders.
        """,
        citation: "Albert Bandura, Social Learning Theory (1977)",
        actionText: "Your Flow Twin's discoveries are your shortcuts",
        learnMoreURL: nil
    )

    static let howYouCompareMatters = PhilosophyMoment(
        id: "1.3_comparison_modes",
        category: .social,
        trigger: .comparisonModeToggle,
        icon: "scale.3d",
        title: "Two Ways to Compare (One Helps, One Hurts)",
        body: """
        Leon Festinger discovered that social comparison is unavoidable—but its effects depend entirely on framing.

        State comparison: "They scored 92, I scored 78"
        → Creates anxiety, threatens ego, triggers defense

        Growth comparison: "They improved 18%, I improved 23%"
        → Inspires learning, focuses on controllable factors

        OnLife defaults to Inspiration Mode because growth-focused comparison builds skill. Competition Mode is available, but we want you to use it mindfully.
        """,
        citation: "Leon Festinger, Social Comparison Theory (1954)",
        actionText: "Compare for learning, not for ego",
        learnMoreURL: nil
    )

    static let lessIsMoreRelationships = PhilosophyMoment(
        id: "1.4_dunbar_number",
        category: .social,
        trigger: .connectionLimitReached,
        icon: "link",
        title: "The Science of Meaningful Connections",
        body: """
        Anthropologist Robin Dunbar studied primate brains and discovered something universal: there's a cognitive limit to how many meaningful relationships any social creature can maintain.

        For humans, it's about 150 for acquaintances—and only 5 for truly intimate relationships.

        By limiting Flow Partners to 5, we're not restricting you. We're protecting the value of those connections. Being someone's Flow Partner means something because the slot is scarce.
        """,
        citation: "Robin Dunbar, \"Neocortex Size as a Constraint on Group Size in Primates\" (1992)",
        actionText: "Choose deeply, not widely",
        learnMoreURL: nil
    )

    static let presenceDisruptsFlow = PhilosophyMoment(
        id: "1.5_flow_isolation",
        category: .social,
        trigger: .sessionWithFriendsOnline,
        icon: "brain.head.profile",
        title: "Why We Protect Your Solitude",
        body: """
        Csikszentmihalyi's original research on flow states identified a crucial ingredient: loss of self-consciousness.

        The moment you become aware of being observed—even by friends—you shift from flow state to performance mode. Your attention splits between the task and your image.

        That's why OnLife shows you which friends are also focusing before your session, but provides zero presence indicators during. We connect you before and after. During, you're alone with your focus.
        """,
        citation: "Mihaly Csikszentmihalyi, \"Flow: The Psychology of Optimal Experience\" (1990)",
        actionText: "Focus alone, celebrate together",
        learnMoreURL: nil
    )

    static let skillsNotHours = PhilosophyMoment(
        id: "1.6_skills_badges",
        category: .social,
        trigger: .firstBadgeEarned,
        icon: "target",
        title: "Capabilities Beat Accumulation",
        body: """
        Anders Ericsson studied world-class performers for 30 years. His conclusion? Mastery isn't about time spent—it's about deliberate practice with feedback.

        10,000 hours of mindless repetition builds nothing. 100 hours of focused, intentional practice builds expertise.

        Your badges represent capabilities you've developed—entering flow quickly, maintaining extended sessions, optimizing your protocols. These are skills you'll keep forever, not just numbers you've accumulated.
        """,
        citation: "Anders Ericsson, \"Peak: Secrets from the New Science of Expertise\" (2016)",
        actionText: "Build skills that transfer to life",
        learnMoreURL: nil
    )

    static let cohortsBeatLeaderboards = PhilosophyMoment(
        id: "1.7_cohorts",
        category: .social,
        trigger: .joiningChallenge,
        icon: "person.3",
        title: "Learning Together vs. Racing Against",
        body: """
        Research on group learning shows that cohort-based programs dramatically outperform competitive structures for skill development.

        Why? When you're racing against others, you take fewer risks. You hide struggles. You optimize for looking good, not for learning.

        When you're learning alongside others—everyone on the same curriculum, success defined as completion—you share openly, ask for help, and actually improve.

        OnLife challenges are cohorts, not competitions. Everyone can win.
        """,
        citation: nil,
        actionText: "Your cohort wants you to succeed",
        learnMoreURL: nil
    )

    // MARK: - Behavioral Psychology Moments (2.x)

    static let variableRewards = PhilosophyMoment(
        id: "2.1_variable_rewards",
        category: .behavioral,
        trigger: .bonusRewardReceived,
        icon: "sparkles",
        title: "The Science of Variable Rewards",
        body: """
        B.F. Skinner discovered something counterintuitive: unpredictable rewards create stronger motivation than predictable ones.

        When you know exactly what you'll get, you calculate. When there's a chance of something extra, you hope.

        OnLife's 20% bonus chance isn't arbitrary—it's the scientifically optimal rate for sustained engagement without addictive patterns. Enough unpredictability to excite, not enough to manipulate.
        """,
        citation: "B.F. Skinner, \"Schedules of Reinforcement\" (1957)",
        actionText: "The surprise keeps you coming back",
        learnMoreURL: nil
    )

    static let lossAversion = PhilosophyMoment(
        id: "2.2_loss_aversion",
        category: .behavioral,
        trigger: .plantWiltingWarning,
        icon: "leaf.arrow.triangle.circlepath",
        title: "Loss Aversion (And How We Use It Carefully)",
        body: """
        Nobel laureates Daniel Kahneman and Amos Tversky proved that humans feel losses about 2.25x more intensely than equivalent gains.

        Losing $100 hurts more than gaining $100 feels good.

        We use this carefully: A wilting plant creates urgency to protect what you've built. But we give you time. Your plant won't die instantly—it'll warn you, giving you chance to save it.

        We harness loss aversion for motivation, not punishment.
        """,
        citation: "Kahneman & Tversky, Prospect Theory (1979)",
        actionText: "Protect what you've grown",
        learnMoreURL: nil
    )

    static let forgivenessBuildHabits = PhilosophyMoment(
        id: "2.3_streak_freezes",
        category: .behavioral,
        trigger: .streakFreezeUsed,
        icon: "snowflake",
        title: "The Science of Self-Compassion",
        body: """
        BJ Fogg at Stanford found something surprising: self-criticism after failure makes you MORE likely to quit entirely. Self-compassion keeps you going.

        When you miss a day and beat yourself up, your brain associates the habit with negative emotion. When you forgive yourself and continue, the habit stays positive.

        Streak freezes aren't cheating—they're scientifically optimal. One missed day shouldn't erase weeks of progress. Use your freeze without guilt.
        """,
        citation: "BJ Fogg, \"Tiny Habits\" (2019)",
        actionText: "Forgive and continue",
        learnMoreURL: nil
    )

    static let celebrateProcess = PhilosophyMoment(
        id: "2.4_celebrate_process",
        category: .behavioral,
        trigger: .sessionCompleted,
        icon: "star",
        title: "Why Showing Up Matters",
        body: """
        Research on habit formation shows that reinforcing the behavior (showing up) is more important than reinforcing the outcome (perfect results).

        If you only celebrate when you hit flow, you'll avoid sessions where flow feels unlikely. If you celebrate showing up, you'll show up more—and eventually hit flow more often.

        That's why OnLife celebrates your session completion, not just your flow score. The session itself is the win. Flow is the bonus.
        """,
        citation: nil,
        actionText: "Every session counts",
        learnMoreURL: nil
    )

    static let smallWinsCompound = PhilosophyMoment(
        id: "2.5_small_wins",
        category: .behavioral,
        trigger: .firstPlantGrown,
        icon: "leaf",
        title: "The Compound Effect of Progress",
        body: """
        Teresa Amabile's research on workplace motivation found that the single biggest driver of engagement is "making progress in meaningful work."

        Not bonuses. Not praise. Progress.

        Your growing garden is a visual record of progress. Each plant represents a session where you invested in yourself. Over time, the garden becomes proof that you're the kind of person who shows up.

        That identity shift—"I'm someone who focuses"—matters more than any single session.
        """,
        citation: "Teresa Amabile, \"The Progress Principle\" (2011)",
        actionText: "Watch your identity grow",
        learnMoreURL: nil
    )

    static let defaultsMatter = PhilosophyMoment(
        id: "2.6_defaults",
        category: .behavioral,
        trigger: .firstSettingsVisit,
        icon: "gearshape",
        title: "The Power of Default Choices",
        body: """
        Richard Thaler won the Nobel Prize for showing that default options dramatically shape behavior—even when people can change them.

        OnLife's defaults are intentional:
        • Inspiration Mode (not Competition)
        • Friends Only garden visibility (not Public)
        • Philosophy Moments on (not off)

        We've chosen defaults that research shows lead to better outcomes. You can always change them—but the defaults reflect what we believe is best for your growth.
        """,
        citation: "Richard Thaler, \"Nudge\" (2008)",
        actionText: "Our defaults are designed for you",
        learnMoreURL: nil
    )

    // MARK: - Flow Science Moments (3.x)

    static let flowNotActivity = PhilosophyMoment(
        id: "3.1_flow_not_activity",
        category: .flow,
        trigger: .firstHeatmapView,
        icon: "chart.bar.fill",
        title: "Why Quality Beats Quantity",
        body: """
        Most apps track "Did you open the app?" That's like tracking gym visits without checking if you exercised.

        OnLife's heatmap shows biometrically-verified flow states. A light square means you showed up. A dark square means you actually achieved flow.

        We care about what happened to your brain, not just that you were present.
        """,
        citation: nil,
        actionText: "Aim for dark squares",
        learnMoreURL: nil
    )

    static let peakWindows = PhilosophyMoment(
        id: "3.2_peak_windows",
        category: .flow,
        trigger: .chronotypeOnProfile,
        icon: "sunrise.fill",
        title: "Your Brain Has a Schedule",
        body: """
        Till Roenneberg's research on chronotypes shows that everyone has genetically-determined optimal times for cognitive performance.

        Night owls aren't lazy—their brains are wired for evening peak performance. Early birds aren't virtuous—they just peak earlier.

        OnLife identifies your chronotype from your flow patterns and shows your peak windows. Working with your biology—not against it—dramatically improves your chances of flow.
        """,
        citation: "Till Roenneberg, \"Internal Time\" (2012)",
        actionText: "Flow with your biology",
        learnMoreURL: nil
    )

    static let hrvPredictsFlow = PhilosophyMoment(
        id: "3.3_hrv_flow",
        category: .flow,
        trigger: .firstWhoopSession,
        icon: "heart.fill",
        title: "The Biometric Signature of Flow",
        body: """
        Peifer et al. (2014) discovered that heart rate variability (HRV) follows a specific pattern during flow states—an inverted-U curve.

        Too low HRV = stressed, anxious, overthinking
        Optimal HRV = calm alertness, ready for flow
        Too high HRV = disengaged, unfocused

        Your WHOOP's 99% HRV accuracy means OnLife can detect when you're actually in flow—not just when you think you are.
        """,
        citation: "Peifer et al., \"The Relation of Flow-Experience and Physiological Arousal\" (2014)",
        actionText: "Let your heart guide you",
        learnMoreURL: nil
    )

    static let challengeMatchesSkill = PhilosophyMoment(
        id: "3.4_flow_channel",
        category: .flow,
        trigger: .flowScoreExplanation,
        icon: "bolt.fill",
        title: "The Flow Channel",
        body: """
        Csikszentmihalyi's core finding: Flow happens when challenge precisely matches current skill.

        Too easy → Boredom
        Too hard → Anxiety
        Just right → Flow

        OnLife tracks your progress so it can help you find tasks at the right difficulty. As you improve, what once challenged you becomes easy—and you need new challenges to stay in flow.
        """,
        citation: "Csikszentmihalyi, \"Flow\" (1990)",
        actionText: "Seek the edge of your ability",
        learnMoreURL: nil
    )

    static let substanceTiming = PhilosophyMoment(
        id: "3.5_pharmacokinetics",
        category: .flow,
        trigger: .firstSubstanceLog,
        icon: "cup.and.saucer.fill",
        title: "Pharmacokinetics: When Matters as Much as What",
        body: """
        Caffeine doesn't just "wake you up." It follows a precise pharmacokinetic curve:
        • Peak effect: 45-60 minutes after consumption
        • Half-life: 5-6 hours (varies by genetics)

        L-theanine peaks in 30 minutes and synergizes with caffeine to reduce jitters while preserving alertness.

        The Protocol Library shares timing strategies because when you consume matters as much as what you consume.
        """,
        citation: "White et al., \"Caffeine Pharmacokinetics\" (2016)",
        actionText: "Time your optimization",
        learnMoreURL: nil
    )

    // MARK: - Meta Moments (4.x)

    static let whyWeTeachYou = PhilosophyMoment(
        id: "4.1_transparency",
        category: .meta,
        trigger: .firstPhilosophyMomentSeen,
        icon: "brain",
        title: "Why OnLife Is Transparent",
        body: """
        Most apps hide their psychology. Duolingo doesn't tell you why streaks work. Instagram doesn't explain why you can't stop scrolling.

        We think you deserve to know.

        When you understand why something affects you, you can choose whether to engage with it. You become a partner in your own optimization, not a subject of manipulation.

        That's the OnLife difference: We don't just use psychology on you. We teach it to you.
        """,
        citation: nil,
        actionText: "Knowledge is power",
        learnMoreURL: nil
    )

    static let weWantYouToGraduate = PhilosophyMoment(
        id: "4.2_graduation",
        category: .meta,
        trigger: .after30Days,
        icon: "graduationcap.fill",
        title: "Our Goal Is Your Independence",
        body: """
        Most apps want you hooked forever. More engagement = more revenue.

        OnLife is different. Our goal is to teach you to achieve flow without us.

        Every feature is designed to build internal capacity—not external dependency. We want you to learn your chronotype, internalize your protocols, and eventually flow on command without opening the app.

        If you "graduate" from OnLife, we've succeeded.
        """,
        citation: nil,
        actionText: "We're training you to leave",
        learnMoreURL: nil
    )

    static let dataIsSacred = PhilosophyMoment(
        id: "4.3_privacy",
        category: .meta,
        trigger: .firstPrivacySettingsView,
        icon: "lock.fill",
        title: "Your Brain Data Belongs to You",
        body: """
        OnLife collects sensitive data: when you focus, how you feel, what substances you use, your biometric patterns.

        We believe this data is sacred. We will never:
        • Sell your data to advertisers
        • Use it for purposes you haven't approved
        • Store it without encryption
        • Share it without explicit consent

        You own your data. Period.
        """,
        citation: nil,
        actionText: "Your privacy is non-negotiable",
        learnMoreURL: nil
    )

    static let scienceNotHype = PhilosophyMoment(
        id: "4.4_citations",
        category: .meta,
        trigger: .afterThirdCitation,
        icon: "books.vertical.fill",
        title: "Every Claim Has a Source",
        body: """
        The wellness industry is full of pseudoscience. "Ancient wisdom." "Revolutionary discoveries." Claims without evidence.

        OnLife is different. Every algorithm is backed by peer-reviewed research:
        • Flow detection: Peifer et al. (2014)
        • Gamification: Skinner (1957), Kahneman & Tversky (1979)
        • Habit formation: Fogg (2019)
        • Pharmacokinetics: White et al. (2016)

        When we cite research, you can look it up. We're not hiding behind vague claims. We're standing on the shoulders of scientists.
        """,
        citation: nil,
        actionText: "Verify everything we tell you",
        learnMoreURL: nil
    )

    static let whyLightbulbExists = PhilosophyMoment(
        id: "4.5_lightbulb_icon",
        category: .meta,
        trigger: .philosophyMomentSystemExplained,
        icon: "lightbulb.fill",
        title: "Learning Mode (Always Optional)",
        body: """
        The 💡 icons throughout OnLife open Philosophy Moments—brief explanations of the psychology behind features.

        You can:
        • Tap them to learn
        • Ignore them if you prefer
        • Turn them off entirely in settings

        We designed them for people who want to understand—not to lecture people who don't. The choice is always yours.
        """,
        citation: nil,
        actionText: "Curiosity is optional (but rewarded)",
        learnMoreURL: nil
    )

    // MARK: - All Moments

    static let all: [PhilosophyMoment] = [
        // Social
        trajectoriesMatterMore,
        socialLearning,
        howYouCompareMatters,
        lessIsMoreRelationships,
        presenceDisruptsFlow,
        skillsNotHours,
        cohortsBeatLeaderboards,
        // Behavioral
        variableRewards,
        lossAversion,
        forgivenessBuildHabits,
        celebrateProcess,
        smallWinsCompound,
        defaultsMatter,
        // Flow
        flowNotActivity,
        peakWindows,
        hrvPredictsFlow,
        challengeMatchesSkill,
        substanceTiming,
        // Meta
        whyWeTeachYou,
        weWantYouToGraduate,
        dataIsSacred,
        scienceNotHype,
        whyLightbulbExists
    ]

    static func moment(for id: String) -> PhilosophyMoment? {
        all.first { $0.id == id }
    }

    static func moment(for trigger: PhilosophyMomentTrigger) -> PhilosophyMoment? {
        all.first { $0.trigger == trigger }
    }

    static func moments(in category: PhilosophyMomentCategory) -> [PhilosophyMoment] {
        all.filter { $0.category == category }
    }
}

// MARK: - Philosophy Moment Settings

enum PhilosophyMomentsMode: String, Codable, CaseIterable {
    case on = "on"
    case subtle = "subtle"
    case off = "off"

    var displayName: String {
        switch self {
        case .on: return "On"
        case .subtle: return "Subtle"
        case .off: return "Off"
        }
    }

    var description: String {
        switch self {
        case .on: return "Show 💡 icons everywhere"
        case .subtle: return "Only first encounter with each feature"
        case .off: return "No philosophy moments"
        }
    }
}

// MARK: - User Philosophy Moment State

struct PhilosophyMomentUserState: Codable {
    var seenMomentIds: Set<String>
    var mode: PhilosophyMomentsMode

    init() {
        self.seenMomentIds = []
        self.mode = .on
    }

    var discoveredCount: Int {
        seenMomentIds.count
    }

    var totalCount: Int {
        PhilosophyMomentsLibrary.all.count
    }

    var progressDescription: String {
        "\(discoveredCount) of \(totalCount) moments"
    }

    mutating func markSeen(_ momentId: String) {
        seenMomentIds.insert(momentId)
    }

    mutating func reset() {
        seenMomentIds.removeAll()
    }

    func shouldShowMoment(_ momentId: String) -> Bool {
        switch mode {
        case .on:
            return true
        case .subtle:
            return !seenMomentIds.contains(momentId)
        case .off:
            return false
        }
    }
}
