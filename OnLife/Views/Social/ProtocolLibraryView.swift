import SwiftUI

// MARK: - Protocol Library View

struct ProtocolLibraryView: View {
    let userProfile: UserProfile?
    let onProtocolSelect: (FlowProtocol) -> Void
    let onPhilosophyTap: (PhilosophyMoment) -> Void

    @StateObject private var protocolService = ProtocolService.shared
    @State private var searchText = ""
    @State private var selectedTab: LibraryTab = .forYou
    @State private var showingCreateProtocol = false
    @State private var selectedProtocol: FlowProtocol?

    enum LibraryTab: String, CaseIterable {
        case forYou = "For You"
        case trending = "Trending"
        case newest = "New"
        case saved = "Saved"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Header
                headerSection

                // Search bar
                searchBar

                // Tab pills
                tabPills

                // Content based on tab
                contentSection
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .background(OnLifeColors.deepForest.ignoresSafeArea())
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
                    onPhilosophyTap(PhilosophyMomentsLibrary.socialLearning)
                }

                Spacer()
            }

            Text("Substance and timing strategies from the community")
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

    // MARK: - Tab Pills

    private var tabPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(LibraryTab.allCases, id: \.self) { tab in
                    tabPill(tab)
                }
            }
        }
    }

    private func tabPill(_ tab: LibraryTab) -> some View {
        Button(action: {
            withAnimation(.spring(duration: 0.2)) {
                selectedTab = tab
            }
            HapticManager.shared.impact(style: .light)
        }) {
            Text(tab.rawValue)
                .font(OnLifeFont.label())
                .foregroundColor(selectedTab == tab ? OnLifeColors.textPrimary : OnLifeColors.textTertiary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(selectedTab == tab ? OnLifeColors.socialTeal : OnLifeColors.cardBackground)
                )
        }
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(spacing: Spacing.lg) {
            let protocols = filteredProtocols

            if protocolService.isLoading {
                loadingView
            } else if protocols.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(protocols) { proto in
                        ProtocolCard(
                            flowProtocol: proto,
                            onTap: {
                                selectedProtocol = proto
                            },
                            onFork: nil,
                            onPhilosophyTap: nil
                        )
                    }
                }
            }
        }
    }

    private var filteredProtocols: [FlowProtocol] {
        let baseProtocols: [FlowProtocol]
        switch selectedTab {
        case .forYou:
            baseProtocols = protocolService.recommendedProtocols.isEmpty
                ? protocolService.publicProtocols
                : protocolService.recommendedProtocols
        case .trending:
            baseProtocols = protocolService.publicProtocols.sorted { $0.tryCount > $1.tryCount }
        case .newest:
            baseProtocols = protocolService.publicProtocols.sorted { $0.createdAt > $1.createdAt }
        case .saved:
            baseProtocols = protocolService.savedProtocols
        }

        if searchText.isEmpty {
            return baseProtocols
        }

        return baseProtocols.filter { proto in
            proto.title.localizedCaseInsensitiveContains(searchText) ||
            proto.description.localizedCaseInsensitiveContains(searchText) ||
            proto.creatorUsername.localizedCaseInsensitiveContains(searchText)
        }
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
                Text(selectedTab == .saved ? "No saved protocols" : "No protocols found")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(selectedTab == .saved
                    ? "Save protocols to quickly access them later"
                    : "Try adjusting your search or check back later")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if selectedTab != .saved {
                Button(action: { showingCreateProtocol = true }) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "plus")
                        Text("Create Protocol")
                    }
                    .font(OnLifeFont.button())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .padding(.horizontal, Spacing.xl)
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

    // MARK: - Load Protocols

    private func loadProtocols() async {
        await protocolService.loadPublicProtocols()

        if userProfile != nil {
            await protocolService.loadRecommendedProtocols()
            await protocolService.loadSavedProtocols()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ProtocolLibraryView_Previews: PreviewProvider {
    static let userProfile = UserProfile(
        id: "me",
        username: "flowmaster",
        displayName: "You",
        chronotype: .moderateMorning,
        gardenAgeDays: 90,
        thirtyDayTrajectory: 23,
        consistencyPercentile: 75,
        totalPlantsGrown: 28,
        speciesUnlocked: 8
    )

    static var previews: some View {
        NavigationStack {
            ProtocolLibraryView(
                userProfile: userProfile,
                onProtocolSelect: { _ in },
                onPhilosophyTap: { _ in }
            )
        }
        .preferredColorScheme(.dark)
    }
}
#endif
