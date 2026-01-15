import SwiftUI

struct MainTabView: View {
    @StateObject private var profileManager = MetabolismProfileManager.shared
    @State private var selectedTab = 0
    @State private var showingOnboarding = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // Gardens tab
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "leaf.fill" : "leaf")
                    Text("Gardens")
                }
                .tag(0)

            // Insights tab
            NavigationView {
                AnalyticsView()
            }
            .tabItem {
                Image(systemName: selectedTab == 1 ? "chart.bar.fill" : "chart.bar")
                Text("Insights")
            }
            .tag(1)

            // Substances tab
            NavigationView {
                SubstanceTrackingView()
            }
            .tabItem {
                Image(systemName: selectedTab == 2 ? "cup.and.saucer.fill" : "cup.and.saucer")
                Text("Substances")
            }
            .tag(2)

            // History tab
            SessionHistoryView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "clock.fill" : "clock")
                    Text("History")
                }
                .tag(3)

            // Settings tab
            SettingsView()
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "gearshape.fill" : "gearshape")
                    Text("Settings")
                }
                .tag(4)
        }
        .accentColor(AppColors.healthy)
        .onAppear {
            // Customize tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(AppColors.darkSoil)

            // Unselected item color
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppColors.textTertiary)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor(AppColors.textTertiary)
            ]

            // Selected item color
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppColors.healthy)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(AppColors.healthy)
            ]

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance

            // Check if user has completed metabolism onboarding
            if !profileManager.hasCompletedOnboarding {
                showingOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            MetabolismOnboardingFlow()
        }
    }
}
