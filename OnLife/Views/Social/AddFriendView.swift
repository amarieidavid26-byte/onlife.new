import SwiftUI

// MARK: - Add Friend View

struct AddFriendView: View {
    let currentUserId: String
    let currentUsername: String
    let onPhilosophyTap: (PhilosophyMoment) -> Void
    let onDismiss: () -> Void

    @StateObject private var socialService = SocialService.shared
    @State private var searchText = ""
    @State private var searchResults: [UserProfile] = []
    @State private var isSearching = false
    @State private var selectedTab: AddFriendTab = .search
    @State private var showingScanner = false
    @State private var showingInviteSheet = false
    @State private var scannedUserId: String?

    enum AddFriendTab: String, CaseIterable {
        case search = "Search"
        case scan = "Scan"
        case invite = "Invite"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab picker
                tabPicker

                // Content based on tab
                switch selectedTab {
                case .search:
                    searchContent
                case .scan:
                    scanContent
                case .invite:
                    inviteContent
                }
            }
            .background(OnLifeColors.deepForest.ignoresSafeArea())
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                QRCodeScannerView(
                    onCodeScanned: handleScannedCode,
                    onDismiss: { showingScanner = false }
                )
            }
            .sheet(isPresented: $showingInviteSheet) {
                InviteLinkSheet(
                    userId: currentUserId,
                    username: currentUsername,
                    onDismiss: { showingInviteSheet = false }
                )
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(AddFriendTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(Spacing.xs)
        .background(OnLifeColors.cardBackground)
    }

    private func tabButton(_ tab: AddFriendTab) -> some View {
        Button(action: {
            withAnimation(.spring(duration: 0.2)) {
                selectedTab = tab
            }
            HapticManager.shared.impact(style: .light)
        }) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: tabIcon(tab))
                    .font(.system(size: 14))

                Text(tab.rawValue)
                    .font(OnLifeFont.label())
            }
            .foregroundColor(selectedTab == tab ? OnLifeColors.textPrimary : OnLifeColors.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                    .fill(selectedTab == tab ? OnLifeColors.socialTeal : Color.clear)
            )
        }
    }

    private func tabIcon(_ tab: AddFriendTab) -> String {
        switch tab {
        case .search: return "magnifyingglass"
        case .scan: return "qrcode.viewfinder"
        case .invite: return "link"
        }
    }

    // MARK: - Search Content

    private var searchContent: some View {
        VStack(spacing: Spacing.lg) {
            // Search bar
            searchBar

            // Results or suggestions
            if searchText.isEmpty {
                searchSuggestions
            } else if isSearching {
                searchLoadingView
            } else if searchResults.isEmpty {
                noResultsView
            } else {
                searchResultsList
            }
        }
        .padding(.top, Spacing.lg)
    }

    private var searchBar: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(OnLifeColors.textTertiary)

            TextField("Search by username...", text: $searchText)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onChange(of: searchText) { _, newValue in
                    performSearch(query: newValue)
                }

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    searchResults = []
                }) {
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
        .padding(.horizontal, Spacing.lg)
    }

    private var searchSuggestions: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Tips section
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Find friends by")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)

                    suggestionRow(
                        icon: "at",
                        title: "Username",
                        description: "Search for their exact @username"
                    )

                    suggestionRow(
                        icon: "qrcode.viewfinder",
                        title: "QR Code",
                        description: "Scan their profile QR code"
                    )

                    suggestionRow(
                        icon: "link",
                        title: "Invite Link",
                        description: "Share your link with friends"
                    )
                }

                // Suggested (could be based on mutual connections)
                // For now, show empty state
            }
            .padding(Spacing.lg)
        }
    }

    private func suggestionRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(OnLifeColors.socialTeal.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(OnLifeColors.socialTeal)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(description)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private var searchLoadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: OnLifeColors.socialTeal))

            Text("Searching...")
                .font(OnLifeFont.bodySmall())
                .foregroundColor(OnLifeColors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xxl)
    }

    private var noResultsView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "person.fill.questionmark")
                .font(.system(size: 48))
                .foregroundColor(OnLifeColors.textMuted)

            VStack(spacing: Spacing.sm) {
                Text("No users found")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Try a different username or invite them to OnLife")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { selectedTab = .invite }) {
                Text("Invite a Friend")
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
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxl)
    }

    private var searchResultsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: Spacing.md) {
                ForEach(searchResults) { profile in
                    UserSearchResultCard(
                        profile: profile,
                        existingConnection: socialService.connections.first { $0.user1Id == profile.id || $0.user2Id == profile.id },
                        pendingRequest: socialService.pendingRequests.first {
                            $0.toUserId == profile.id || $0.fromUserId == profile.id
                        },
                        onConnect: { level in
                            sendConnectionRequest(to: profile, level: level)
                        },
                        onViewProfile: {
                            // Navigate to profile
                        }
                    )
                }
            }
            .padding(Spacing.lg)
        }
    }

    // MARK: - Scan Content

    private var scanContent: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Illustration
            ZStack {
                Circle()
                    .fill(OnLifeColors.socialTeal.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 56))
                    .foregroundColor(OnLifeColors.socialTeal)
            }

            VStack(spacing: Spacing.sm) {
                Text("Scan a QR Code")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Point your camera at a friend's OnLife QR code to connect instantly")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            Button(action: { showingScanner = true }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16))

                    Text("Open Scanner")
                        .font(OnLifeFont.button())
                }
                .foregroundColor(OnLifeColors.textPrimary)
                .padding(.horizontal, Spacing.xxl)
                .padding(.vertical, Spacing.md)
                .background(
                    Capsule()
                        .fill(OnLifeColors.socialTeal)
                )
            }

            Spacer()
        }
        .padding(Spacing.lg)
    }

    // MARK: - Invite Content

    private var inviteContent: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Illustration
            ZStack {
                Circle()
                    .fill(OnLifeColors.socialTeal.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 56))
                    .foregroundColor(OnLifeColors.socialTeal)
            }

            VStack(spacing: Spacing.sm) {
                Text("Invite Friends")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Share your invite link or QR code to help friends join OnLife and connect with you")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            Button(action: { showingInviteSheet = true }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))

                    Text("Get Invite Link")
                        .font(OnLifeFont.button())
                }
                .foregroundColor(OnLifeColors.textPrimary)
                .padding(.horizontal, Spacing.xxl)
                .padding(.vertical, Spacing.md)
                .background(
                    Capsule()
                        .fill(OnLifeColors.socialTeal)
                )
            }

            // Philosophy note
            Button(action: {
                onPhilosophyTap(PhilosophyMomentsLibrary.dunbarNumber)
            }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(OnLifeColors.amber)

                    Text("Why quality connections matter")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(Spacing.lg)
    }

    // MARK: - Actions

    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        Task {
            let results = await socialService.searchProfiles(query: query)
            await MainActor.run {
                searchResults = results.filter { $0.id != currentUserId }
                isSearching = false
            }
        }
    }

    private func sendConnectionRequest(to profile: UserProfile, level: ConnectionLevel) {
        Task {
            do {
                try await socialService.sendConnectionRequest(
                    toUserId: profile.id,
                    level: level
                )
                HapticManager.shared.notificationOccurred(.success)
            } catch {
                HapticManager.shared.notificationOccurred(.error)
            }
        }
    }

    private func handleScannedCode(_ code: String) {
        showingScanner = false

        // Parse user ID from invite link
        if let userId = extractUserId(from: code) {
            scannedUserId = userId
            // Fetch profile and show connection options
            Task {
                if let profile = await socialService.fetchProfile(userId: userId) {
                    await MainActor.run {
                        searchResults = [profile]
                        selectedTab = .search
                    }
                }
            }
        }
    }

    private func extractUserId(from url: String) -> String? {
        // Parse onlife.app/invite/{userId}?ref={username}
        guard let urlComponents = URLComponents(string: url),
              let path = urlComponents.path.split(separator: "/").last else {
            return nil
        }
        return String(path)
    }
}

// MARK: - Preview

#if DEBUG
struct AddFriendView_Previews: PreviewProvider {
    static var previews: some View {
        AddFriendView(
            currentUserId: "me",
            currentUsername: "flowmaster",
            onPhilosophyTap: { _ in },
            onDismiss: {}
        )
        .preferredColorScheme(.dark)
    }
}
#endif
