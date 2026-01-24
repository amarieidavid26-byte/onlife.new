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

            // Social tab
            SocialTabView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "person.2.fill" : "person.2")
                    Text("Social")
                }
                .tag(3)

            // History tab
            SessionHistoryView()
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "clock.fill" : "clock")
                    Text("History")
                }
                .tag(4)
        }
        .accentColor(OnLifeColors.sage)
        .onAppear {
            // Customize tab bar appearance with forest green theme
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(OnLifeColors.surface)

            // Unselected item color
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(OnLifeColors.textTertiary)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor(OnLifeColors.textTertiary)
            ]

            // Selected item color - sage green
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(OnLifeColors.sage)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(OnLifeColors.sage)
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
