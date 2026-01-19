import SwiftUI
import Combine

struct SessionHistoryView: View {
    @StateObject private var viewModel = SessionHistoryViewModel()
    @State private var contentAppeared = false
    @State private var sessionToDelete: FocusSession?
    @State private var selectedSession: FocusSession?

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [OnLifeColors.deepForest, OnLifeColors.surface],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        // Stats Header
                        StatsHeader(
                            totalSessions: viewModel.filteredSessions.count,
                            totalFocusTime: viewModel.totalFocusTime
                        )
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)

                        // Garden Filter Chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                GardenFilterChip(
                                    title: "All Gardens",
                                    icon: "🌿",
                                    isSelected: viewModel.selectedGardenId == nil
                                ) {
                                    Haptics.selection()
                                    withAnimation(OnLifeAnimation.quick) {
                                        viewModel.selectedGardenId = nil
                                    }
                                }

                                ForEach(viewModel.gardens) { garden in
                                    GardenFilterChip(
                                        title: garden.name,
                                        icon: garden.icon,
                                        isSelected: viewModel.selectedGardenId == garden.id
                                    ) {
                                        Haptics.selection()
                                        withAnimation(OnLifeAnimation.quick) {
                                            viewModel.selectedGardenId = garden.id
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, Spacing.lg)
                        }
                        .padding(.horizontal, -Spacing.lg)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)
                        .animation(OnLifeAnimation.elegant.delay(0.05), value: contentAppeared)

                        // Search Bar
                        SearchBar(searchText: $viewModel.searchText)
                            .opacity(contentAppeared ? 1 : 0)
                            .offset(y: contentAppeared ? 0 : 20)
                            .animation(OnLifeAnimation.elegant.delay(0.1), value: contentAppeared)

                        // Sessions List or Empty State
                        if viewModel.filteredSessions.isEmpty {
                            HistoryEmptyStateView(
                                hasSearchText: !viewModel.searchText.isEmpty,
                                hasGardenFilter: viewModel.selectedGardenId != nil
                            )
                            .opacity(contentAppeared ? 1 : 0)
                            .animation(OnLifeAnimation.elegant.delay(0.15), value: contentAppeared)
                        } else {
                            LazyVStack(spacing: Spacing.md) {
                                ForEach(Array(viewModel.filteredSessions.enumerated()), id: \.element.id) { index, session in
                                    SessionCard(
                                        session: session,
                                        gardenName: viewModel.gardenName(for: session.gardenId)
                                    ) {
                                        sessionToDelete = session
                                    }
                                    .onTapGesture {
                                        Haptics.selection()
                                        selectedSession = session
                                    }
                                    .opacity(contentAppeared ? 1 : 0)
                                    .offset(y: contentAppeared ? 0 : 20)
                                    .animation(
                                        OnLifeAnimation.elegant.delay(0.15 + Double(index) * 0.03),
                                        value: contentAppeared
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.xxl)
                }
                .refreshable {
                    Haptics.light()
                    viewModel.loadData()
                }
            }
            .navigationTitle("Session History")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(OnLifeColors.deepForest, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            viewModel.loadData()
            withAnimation(OnLifeAnimation.elegant) {
                contentAppeared = true
            }
        }
        .confirmationDialog(
            "Delete Session",
            isPresented: Binding(
                get: { sessionToDelete != nil },
                set: { if !$0 { sessionToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    Haptics.warning()
                    withAnimation(OnLifeAnimation.quick) {
                        viewModel.deleteSession(session)
                    }
                }
                sessionToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                sessionToDelete = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailView(
                session: session,
                gardenName: viewModel.gardenName(for: session.gardenId)
            )
        }
    }
}

// MARK: - Stats Header

struct StatsHeader: View {
    let totalSessions: Int
    let totalFocusTime: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            StatBox(
                icon: "clock.fill",
                value: totalFocusTime,
                label: "Total Time"
            )

            StatBox(
                icon: "flame.fill",
                value: "\(totalSessions)",
                label: "Sessions"
            )
        }
    }
}

struct StatBox: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(OnLifeColors.sage)

            Text(value)
                .font(OnLifeFont.heading1())
                .foregroundColor(OnLifeColors.textPrimary)

            Text(label)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 8,
            y: 4
        )
    }
}

// MARK: - Garden Filter Chip

struct GardenFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Text(icon)
                    .font(.system(size: 16))

                Text(title)
                    .font(OnLifeFont.body())
                    .foregroundColor(isSelected ? OnLifeColors.deepForest : OnLifeColors.textSecondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(isSelected ? OnLifeColors.sage : OnLifeColors.cardBackground)
            )
        }
        .buttonStyle(PressableChipStyle())
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(OnLifeColors.textTertiary)
                .font(.system(size: 16))

            TextField("Search by task...", text: $searchText)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textPrimary)

            if !searchText.isEmpty {
                Button(action: {
                    Haptics.light()
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(OnLifeColors.textTertiary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }
}

// MARK: - Session Card

struct SessionCard: View {
    let session: FocusSession
    let gardenName: String
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header: Task + Delete
            HStack(alignment: .top) {
                Text(session.taskDescription)
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .lineLimit(2)

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(OnLifeColors.textTertiary)
                }
                .buttonStyle(PressableChipStyle())
            }

            // Date & Duration
            HStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text(relativeDate(session.startTime))
                        .font(OnLifeFont.caption())
                }
                .foregroundColor(OnLifeColors.textSecondary)

                HStack(spacing: Spacing.xs) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text(session.formattedDuration)
                        .font(OnLifeFont.caption())
                }
                .foregroundColor(OnLifeColors.textSecondary)
            }

            // Garden & Plant
            HStack(spacing: Spacing.sm) {
                Text(plantEmoji(for: session.plantSpecies))
                    .font(.system(size: 16))

                Text(session.plantSpecies.rawValue.capitalized)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("•")
                    .foregroundColor(OnLifeColors.textTertiary)

                Text(gardenName)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
            }

            // Badges
            HStack(spacing: Spacing.sm) {
                HistoryBadge(
                    icon: session.environment.icon,
                    text: session.environment.displayName
                )

                HistoryBadge(
                    icon: timeOfDayIcon(session.timeOfDay),
                    text: session.timeOfDay.rawValue.capitalized
                )
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 6,
            y: 3
        )
    }

    func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func plantEmoji(for species: PlantSpecies) -> String {
        switch species {
        case .oak: return "🌳"
        case .rose: return "🌹"
        case .cactus: return "🌵"
        case .sunflower: return "🌻"
        case .fern: return "🌿"
        case .bamboo: return "🎋"
        case .lavender: return "💜"
        case .bonsai: return "🪴"
        }
    }

    func timeOfDayIcon(_ timeOfDay: TimeOfDay) -> String {
        switch timeOfDay {
        case .earlyMorning: return "sunrise.fill"
        case .morning: return "sun.and.horizon"
        case .midday: return "sun.max.fill"
        case .afternoon: return "sun.haze"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        case .lateNight: return "moon.fill"
        }
    }
}

struct HistoryBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .font(OnLifeFont.caption())
        }
        .foregroundColor(OnLifeColors.textTertiary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                .fill(OnLifeColors.surface)
        )
    }
}

// MARK: - Empty State

struct HistoryEmptyStateView: View {
    let hasSearchText: Bool
    let hasGardenFilter: Bool
    @State private var bounce = false
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
                .frame(height: 60)

            Text(emptyIcon)
                .font(.system(size: 56))
                .scaleEffect(bounce ? 1.05 : 1.0)
                .animation(
                    .easeInOut(duration: 1.2),
                    value: bounce
                )
                .onAppear {
                    isVisible = true
                    startBounceAnimation()
                }
                .onDisappear {
                    isVisible = false
                    bounce = false
                }

            Text(emptyTitle)
                .font(OnLifeFont.heading2())
                .foregroundColor(OnLifeColors.textPrimary)

            Text(emptyMessage)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Spacer()
        }
    }

    var emptyIcon: String {
        if hasSearchText || hasGardenFilter {
            return "🔍"
        }
        return "🌱"
    }

    var emptyTitle: String {
        if hasSearchText {
            return "No Results"
        } else if hasGardenFilter {
            return "No Sessions"
        }
        return "No Sessions Yet"
    }

    var emptyMessage: String {
        if hasSearchText {
            return "Try adjusting your search terms"
        } else if hasGardenFilter {
            return "No sessions recorded for this garden yet"
        }
        return "Start focusing to grow your history"
    }

    private func startBounceAnimation() {
        // Use a timer-based approach instead of repeatForever to avoid animation conflicts
        Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { timer in
            guard isVisible else {
                timer.invalidate()
                return
            }
            withAnimation(.easeInOut(duration: 1.2)) {
                bounce.toggle()
            }
        }
        // Trigger initial bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 1.2)) {
                bounce = true
            }
        }
    }
}

// MARK: - ViewModel

class SessionHistoryViewModel: ObservableObject {
    @Published var sessions: [FocusSession] = []
    @Published var gardens: [Garden] = []
    @Published var selectedGardenId: UUID? = nil
    @Published var searchText: String = ""

    var filteredSessions: [FocusSession] {
        sessions
            .filter { session in
                // Filter by garden
                if let gardenId = selectedGardenId {
                    guard session.gardenId == gardenId else { return false }
                }

                // Filter by search text
                if !searchText.isEmpty {
                    return session.taskDescription.localizedCaseInsensitiveContains(searchText)
                }

                return true
            }
            .sorted { $0.startTime > $1.startTime }
    }

    var totalFocusTime: String {
        let totalSeconds = filteredSessions.reduce(0.0) { $0 + $1.actualDuration }
        let hours = Int(totalSeconds / 3600)
        let minutes = Int((totalSeconds.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    func loadData() {
        sessions = GardenDataManager.shared.loadSessions()
        gardens = GardenDataManager.shared.loadGardens()
    }

    func gardenName(for gardenId: UUID) -> String {
        gardens.first(where: { $0.id == gardenId })?.name ?? "Unknown Garden"
    }

    func deleteSession(_ session: FocusSession) {
        GardenDataManager.shared.deleteSession(session.id)
        loadData()
    }
}
