import Foundation
import Combine
import SwiftUI
import FirebaseAuth

// MARK: - Account Type

enum AccountType: String {
    case apple = "Apple"
    case google = "Google"
    case email = "Email"
    case anonymous = "Anonymous"

    var icon: String {
        switch self {
        case .apple: return "apple.logo"
        case .google: return "g.circle.fill"
        case .email: return "envelope.fill"
        case .anonymous: return "person.crop.circle.badge.questionmark"
        }
    }

    var color: Color {
        switch self {
        case .apple: return .white
        case .google: return .red
        case .email: return OnLifeColors.sage
        case .anonymous: return OnLifeColors.textTertiary
        }
    }
}

// MARK: - Settings Profile View Model

@MainActor
class SettingsProfileViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var accountType: AccountType = .anonymous
    @Published var displayName: String = ""
    @Published var email: String = ""
    @Published var isAnonymous: Bool = true
    @Published var showingUpgrade: Bool = false
    @Published var showingSignOut: Bool = false
    @Published var showingDeleteAccount: Bool = false

    // MARK: - Private Properties

    private let authManager = AuthenticationManager.shared

    // MARK: - Initialization

    init() {
        updateFromCurrentUser()

        // Listen for auth changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(authStateChanged),
            name: .AuthStateDidChangeNotification,
            object: nil
        )
    }

    // MARK: - Update from Current User

    @objc private func authStateChanged() {
        Task { @MainActor in
            updateFromCurrentUser()
        }
    }

    private func updateFromCurrentUser() {
        guard let user = authManager.currentUser else {
            accountType = .anonymous
            displayName = "Guest"
            email = ""
            isAnonymous = true
            return
        }

        isAnonymous = user.isAnonymous
        displayName = user.displayName ?? "User"
        email = user.email ?? ""

        // Determine account type from provider
        if user.isAnonymous {
            accountType = .anonymous
            displayName = "Guest"
        } else if let providerID = user.providerData.first?.providerID {
            switch providerID {
            case "apple.com":
                accountType = .apple
            case "google.com":
                accountType = .google
            case "password":
                accountType = .email
            default:
                accountType = .email
            }
        }
    }

    // MARK: - Actions

    func signOut() {
        authManager.signOut()
        HapticManager.shared.notificationOccurred(.success)
    }

    func deleteAccount() async {
        await authManager.deleteAccount()
        HapticManager.shared.notificationOccurred(.warning)
    }
}

// MARK: - Auth State Notification

extension Notification.Name {
    static let AuthStateDidChangeNotification = Notification.Name("AuthStateDidChangeNotification")
}
