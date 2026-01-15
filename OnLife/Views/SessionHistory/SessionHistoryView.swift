import SwiftUI
import Combine

struct SessionHistoryView: View {
    @StateObject private var viewModel = SessionHistoryViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.richSoil
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Stats Header
                    StatsHeader(
                        totalSessions: viewModel.filteredSessions.count,
                        totalFocusTime: viewModel.totalFocusTime
                    )
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.xl)

                    // Garden Filter Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.md) {
                            GardenFilterChip(
                                title: "All Gardens",
                                icon: "🌿",
                                isSelected: viewModel.selectedGardenId == nil
                            ) {
                                viewModel.selectedGardenId = nil
                            }

                            ForEach(viewModel.gardens) { garden in
                                GardenFilterChip(
                                    title: garden.name,
                                    icon: garden.icon,
                                    isSelected: viewModel.selectedGardenId == garden.id
                                ) {
                                    viewModel.selectedGardenId = garden.id
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.xl)
                    }
                    .padding(.vertical, Spacing.lg)

                    // Search Bar
                    HStack(spacing: Spacing.md) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.textTertiary)

                        TextField("Search by task...", text: $viewModel.searchText)
                            .font(AppFont.body())
                            .foregroundColor(AppColors.textPrimary)

                        if !viewModel.searchText.isEmpty {
                            Button(action: {
                                viewModel.searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                    .padding(Spacing.lg)
                    .background(AppColors.lightSoil)
                    .cornerRadius(CornerRadius.medium)
                    .padding(.horizontal, Spacing.xl)

                    // Sessions List
                    if viewModel.filteredSessions.isEmpty {
                        EmptyStateView(
                            hasSearchText: !viewModel.searchText.isEmpty,
                            hasGardenFilter: viewModel.selectedGardenId != nil
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: Spacing.md) {
                                ForEach(viewModel.filteredSessions) { session in
                                    SessionCard(
                                        session: session,
                                        gardenName: viewModel.gardenName(for: session.gardenId)
                                    ) {
                                        viewModel.deleteSession(session)
                                    }
                                }
                            }
                            .padding(.horizontal, Spacing.xl)
                            .padding(.vertical, Spacing.lg)
                        }
                    }
                }
            }
            .navigationTitle("Session History")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            viewModel.loadData()
        }
    }
}

// MARK: - Stats Header
struct StatsHeader: View {
    let totalSessions: Int
    let totalFocusTime: String

    var body: some View {
        HStack(spacing: Spacing.lg) {
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
        CardView {
            VStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.healthy)

                Text(value)
                    .font(AppFont.heading2())
                    .foregroundColor(AppColors.textPrimary)

                Text(label)
                    .font(AppFont.bodySmall())
                    .foregroundColor(AppColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.lg)
        }
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
                    .font(.system(size: 18))

                Text(title)
                    .font(AppFont.body())
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(isSelected ? AppColors.healthy : AppColors.lightSoil)
            .cornerRadius(CornerRadius.medium)
        }
    }
}

// MARK: - Session Card
struct SessionCard: View {
    let session: FocusSession
    let gardenName: String
    let onDelete: () -> Void

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Header: Task + Delete
                HStack {
                    Text(session.taskDescription)
                        .font(AppFont.heading3())
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)

                    Spacer()

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                // Date & Duration
                HStack(spacing: Spacing.md) {
                    Label(relativeDate(session.startTime), systemImage: "calendar")
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textSecondary)

                    Label(session.formattedDuration, systemImage: "clock")
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textSecondary)
                }

                // Garden & Plant
                HStack(spacing: Spacing.md) {
                    HStack(spacing: Spacing.xs) {
                        Text(plantEmoji(for: session.plantSpecies))
                            .font(.system(size: 16))
                        Text(session.plantSpecies.rawValue.capitalized)
                            .font(AppFont.bodySmall())
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Text("•")
                        .foregroundColor(AppColors.textTertiary)

                    Text(gardenName)
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textSecondary)
                }

                // Badges
                HStack(spacing: Spacing.sm) {
                    Badge(
                        icon: session.environment.icon,
                        text: session.environment.displayName
                    )

                    Badge(
                        icon: timeOfDayIcon(session.timeOfDay),
                        text: session.timeOfDay.rawValue.capitalized
                    )
                }
            }
            .padding(Spacing.lg)
        }
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

struct Badge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(text)
                .font(AppFont.bodySmall())
        }
        .foregroundColor(AppColors.textTertiary)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(AppColors.lightSoil)
        .cornerRadius(CornerRadius.small)
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let hasSearchText: Bool
    let hasGardenFilter: Bool

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Text(emptyIcon)
                .font(.system(size: 60))

            Text(emptyTitle)
                .font(AppFont.heading2())
                .foregroundColor(AppColors.textPrimary)

            Text(emptyMessage)
                .font(AppFont.body())
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxxl)

            Spacer()
        }
    }

    var emptyIcon: String {
        if hasSearchText || hasGardenFilter {
            return "🔍"
        }
        return "⏱️"
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
        return "Complete your first focus session to see it here!"
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
            .sorted { $0.startTime > $1.startTime } // Most recent first
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
        print("📊 Loaded \(sessions.count) sessions and \(gardens.count) gardens")
    }

    func gardenName(for gardenId: UUID) -> String {
        gardens.first(where: { $0.id == gardenId })?.name ?? "Unknown Garden"
    }

    func deleteSession(_ session: FocusSession) {
        GardenDataManager.shared.deleteSession(session.id)
        loadData()
        HapticManager.shared.impact(style: .medium)
    }
}
