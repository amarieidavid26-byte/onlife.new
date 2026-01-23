import SwiftUI

// MARK: - Protocol Library View

struct ProtocolLibraryView: View {
    let userProfile: UserProfile?
    let onProtocolSelect: (FlowProtocol) -> Void
    let onPhilosophyTap: (PhilosophyMoment) -> Void

    @StateObject private var protocolService = ProtocolService.shared
    @State private var searchText = ""
    @State private var selectedFilter: ProtocolFilter = .recommended
    @State private var showingCreateProtocol = false
    @State private var selectedProtocol: FlowProtocol?

    enum ProtocolFilter: String, CaseIterable {
        case recommended = "For You"
        case trending = "Trending"
        case newest = "New"
        case verified = "Verified"
        case saved = "Saved"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Header
                headerSection

                // Search bar
                searchBar

                // Filter pills
                filterPills

                // Content based on filter
                contentSection
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .background(OnLifeColors.deepForest.ignoresSafeArea())
        .navigationTitle("Protocol Library")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingCreateProtocol = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(OnLifeColors.socialTeal)
                }
            }
        }
        .sheet(isPresented: $showingCreateProtocol) {
            CreateProtocolView(
                forkingFrom: nil,
                userProfile: userProfile,
                onSave: { newProtocol in
                    Task {
                        try? await protocolService.createProtocol(newProtocol)
                    }
                    showingCreateProtocol = false
                },
                onCancel: { showingCreateProtocol = false }
            )
        }
        .sheet(item: $selectedProtocol) { proto in
            ProtocolDetailView(
                flowProtocol: proto,
                currentUserProfile: userProfile,
                onTryProtocol: {
                    selectedProtocol = nil
                    // Navigate to session start with protocol
                },
                onFork: {
                    selectedProtocol = nil
                },
                onSave: {
                    Task {
                        try? await protocolService.saveProtocol(proto.id)
                    }
                },
                onPhilosophyTap: onPhilosophyTap,
                onDismiss: { selectedProtocol = nil }
            )
        }
        .task {
            await loadProtocols()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Discover Protocols")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)

                PhilosophyButton {
                    onPhilosophyTap(PhilosophyMomentsLibrary.substanceOptimization)
                }

                Spacer()
            }

            Text("Find substance and timing strategies that work for people like you")
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textSecondary)
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(OnLifeColors.textTertiary)

            TextField("Search protocols...", text: $searchText)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textPrimary)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Filter Pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(ProtocolFilter.allCases, id: \.self) { filter in
                    filterPill(filter)
                }
            }
        }
    }

    private func filterPill(_ filter: ProtocolFilter) -> some View {
        let isSelected = selectedFilter == filter

        return Button(action: {
            withAnimation(.spring(duration: 0.2)) {
                selectedFilter = filter
            }
            HapticManager.shared.impact(style: .light)
            Task {
                await loadProtocols()
            }
        }) {
            Text(filter.rawValue)
                .font(OnLifeFont.label())
                .foregroundColor(isSelected ? OnLifeColors.textPrimary : OnLifeColors.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? OnLifeColors.socialTeal : OnLifeColors.cardBackground)
                )
        }
    }

    // MARK: - Content Section

    @ViewBuilder
    private var contentSection: some View {
        if protocolService.isLoading {
            loadingView
        } else if filteredProtocols.isEmpty {
            emptyStateView
        } else {
            switch selectedFilter {
            case .recommended:
                recommendedSection
            default:
                protocolsList
            }
        }
    }

    // MARK: - Recommended Section

    private var recommendedSection: some View {
        VStack(spacing: Spacing.lg) {
            // Perfect matches for chronotype
            if let profile = userProfile {
                chronotypeMatchSection(profile)
            }

            // Popular in your experience level
            popularSection

            // Recently added
            recentSection
        }
    }

    private func chronotypeMatchSection(_ profile: UserProfile) -> some View {
        let matchingProtocols = protocolService.protocols.filter {
            $0.targetChronotype == profile.chronotype || $0.targetChronotype == nil
        }.prefix(5)

        guard !matchingProtocols.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Image(systemName: profile.chronotype.icon)
                        .foregroundColor(chronotypeColor(profile.chronotype))

                    Text("Perfect for \(profile.chronotype.rawValue)s")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Spacer()

                    Button(action: {}) {
                        Text("See all")
                            .font(OnLifeFont.label())
                            .foregroundColor(OnLifeColors.socialTeal)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.md) {
                        ForEach(Array(matchingProtocols)) { proto in
                            ProtocolCardCompact(flowProtocol: proto) {
                                selectedProtocol = proto
                            }
                            .frame(width: 280)
                        }
                    }
                }
            }
        )
    }

    private func chronotypeColor(_ chronotype: Chronotype) -> Color {
        switch chronotype {
        case .earlyBird: return OnLifeColors.amber
        case .nightOwl: return Color(hex: "7B68EE")
        case .flexible: return OnLifeColors.sage
        }
    }

    private var popularSection: some View {
        let popularProtocols = protocolService.protocols
            .sorted { ($0.trialCount) > ($1.trialCount) }
            .prefix(3)

        guard !popularProtocols.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(OnLifeColors.socialTeal)

                    Text("Most Tried")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Spacer()
                }

                ForEach(Array(popularProtocols)) { proto in
                    ProtocolCard(
                        flowProtocol: proto,
                        onTap: { selectedProtocol = proto },
                        onFork: nil,
                        onPhilosophyTap: nil
                    )
                }
            }
        )
    }

    private var recentSection: some View {
        let recentProtocols = protocolService.protocols
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(3)

        guard !recentProtocols.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Image(systemName: "sparkle")
                        .foregroundColor(OnLifeColors.amber)

                    Text("Recently Added")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Spacer()
                }

                ForEach(Array(recentProtocols)) { proto in
                    ProtocolCardCompact(flowProtocol: proto) {
                        selectedProtocol = proto
                    }
                }
            }
        )
    }

    // MARK: - Protocols List

    private var protocolsList: some View {
        LazyVStack(spacing: Spacing.md) {
            ForEach(filteredProtocols) { proto in
                ProtocolCard(
                    flowProtocol: proto,
                    onTap: { selectedProtocol = proto },
                    onFork: {
                        // Handle fork
                    },
                    onPhilosophyTap: nil
                )
            }
        }
    }

    // MARK: - Filtered Protocols

    private var filteredProtocols: [FlowProtocol] {
        var result = protocolService.protocols

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.creatorName.localizedCaseInsensitiveContains(searchText) ||
                $0.substances.contains { $0.substance.localizedCaseInsensitiveContains(searchText) }
            }
        }

        // Apply category filter
        switch selectedFilter {
        case .recommended:
            // Already handled in recommendedSection
            break
        case .trending:
            result = result.sorted { $0.forkCount + $0.saveCount > $1.forkCount + $1.saveCount }
        case .newest:
            result = result.sorted { $0.createdAt > $1.createdAt }
        case .verified:
            result = result.filter { $0.isVerified }
        case .saved:
            result = result.filter { protocolService.savedProtocolIds.contains($0.id) }
        }

        return result
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: OnLifeColors.socialTeal))

            Text("Loading protocols...")
                .font(OnLifeFont.bodySmall())
                .foregroundColor(OnLifeColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxl)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "flask")
                .font(.system(size: 48))
                .foregroundColor(OnLifeColors.textMuted)

            VStack(spacing: Spacing.sm) {
                Text(emptyStateTitle)
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(emptyStateSubtitle)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if selectedFilter == .saved {
                Button(action: { selectedFilter = .recommended }) {
                    Text("Browse Protocols")
                        .font(OnLifeFont.button())
                        .foregroundColor(OnLifeColors.textPrimary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .background(
                            Capsule()
                                .fill(OnLifeColors.socialTeal)
                        )
                }
            } else {
                Button(action: { showingCreateProtocol = true }) {
                    Text("Create First Protocol")
                        .font(OnLifeFont.button())
                        .foregroundColor(OnLifeColors.textPrimary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .background(
                            Capsule()
                                .fill(OnLifeColors.socialTeal)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxl)
    }

    private var emptyStateTitle: String {
        if !searchText.isEmpty {
            return "No results found"
        }
        switch selectedFilter {
        case .saved: return "No saved protocols"
        case .verified: return "No verified protocols yet"
        default: return "No protocols found"
        }
    }

    private var emptyStateSubtitle: String {
        if !searchText.isEmpty {
            return "Try a different search term"
        }
        switch selectedFilter {
        case .saved: return "Save protocols you want to try later"
        case .verified: return "Verified protocols will appear here"
        default: return "Be the first to create one!"
        }
    }

    // MARK: - Load Protocols

    private func loadProtocols() async {
        do {
            switch selectedFilter {
            case .recommended, .trending, .newest:
                try await protocolService.fetchPublicProtocols()
            case .verified:
                try await protocolService.fetchPublicProtocols()
            case .saved:
                try await protocolService.fetchSavedProtocols()
            }
        } catch {
            // Handle error
        }
    }
}

// MARK: - Protocol Library Entry Point

struct ProtocolLibraryEntryView: View {
    let userProfile: UserProfile?
    let onPhilosophyTap: (PhilosophyMoment) -> Void

    @State private var selectedProtocol: FlowProtocol?

    var body: some View {
        NavigationView {
            ProtocolLibraryView(
                userProfile: userProfile,
                onProtocolSelect: { proto in
                    selectedProtocol = proto
                },
                onPhilosophyTap: onPhilosophyTap
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ProtocolLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProtocolLibraryView(
                userProfile: UserProfile(
                    id: "test",
                    username: "testuser",
                    chronotype: .earlyBird,
                    thirtyDayTrajectory: 20,
                    consistencyPercentile: 75,
                    totalPlantsGrown: 30,
                    speciesUnlocked: 8,
                    gardenAgeDays: 60
                ),
                onProtocolSelect: { _ in },
                onPhilosophyTap: { _ in }
            )
        }
        .preferredColorScheme(.dark)
    }
}
#endif
