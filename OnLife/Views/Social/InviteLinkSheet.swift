import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Invite Link Sheet

struct InviteLinkSheet: View {
    let userId: String
    let username: String
    let onDismiss: () -> Void

    @State private var inviteLink: String = ""
    @State private var isGenerating = false
    @State private var showingCopiedFeedback = false
    @State private var selectedTab: InviteTab = .link

    enum InviteTab {
        case link
        case qrCode
    }

    var body: some View {
        NavigationView {
            VStack(spacing: Spacing.lg) {
                // Tab picker
                Picker("Invite Method", selection: $selectedTab) {
                    Text("Link").tag(InviteTab.link)
                    Text("QR Code").tag(InviteTab.qrCode)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.lg)

                // Content
                if selectedTab == .link {
                    linkContent
                } else {
                    qrCodeContent
                }

                Spacer()
            }
            .padding(.top, Spacing.lg)
            .background(OnLifeColors.deepForest.ignoresSafeArea())
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundColor(OnLifeColors.socialTeal)
                }
            }
            .onAppear {
                generateInviteLink()
            }
        }
    }

    // MARK: - Link Content

    private var linkContent: some View {
        VStack(spacing: Spacing.xl) {
            // Illustration
            VStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(OnLifeColors.socialTeal.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(OnLifeColors.socialTeal)
                }

                Text("Share your invite link")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Friends who join with your link will be automatically connected to you")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            // Link display
            VStack(spacing: Spacing.md) {
                HStack {
                    Text(inviteLink.isEmpty ? "Generating..." : inviteLink)
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: OnLifeColors.socialTeal))
                    }
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(OnLifeColors.cardBackgroundElevated)
                )

                // Action buttons
                HStack(spacing: Spacing.md) {
                    // Copy button
                    Button(action: copyLink) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: showingCopiedFeedback ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 14))

                            Text(showingCopiedFeedback ? "Copied!" : "Copy Link")
                                .font(OnLifeFont.button())
                        }
                        .foregroundColor(OnLifeColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                .fill(showingCopiedFeedback ? OnLifeColors.healthy : OnLifeColors.socialTeal)
                        )
                    }
                    .disabled(inviteLink.isEmpty)

                    // Share button
                    ShareLink(item: inviteLink) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14))

                            Text("Share")
                                .font(OnLifeFont.button())
                        }
                        .foregroundColor(OnLifeColors.socialTeal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                .stroke(OnLifeColors.socialTeal, lineWidth: 2)
                        )
                    }
                    .disabled(inviteLink.isEmpty)
                }
            }
            .padding(.horizontal, Spacing.lg)

            // Expiry note
            HStack(spacing: Spacing.xs) {
                Image(systemName: "clock")
                    .font(.system(size: 12))

                Text("Link expires in 7 days")
                    .font(OnLifeFont.caption())
            }
            .foregroundColor(OnLifeColors.textMuted)
        }
    }

    // MARK: - QR Code Content

    private var qrCodeContent: some View {
        VStack(spacing: Spacing.xl) {
            // QR Code
            if !inviteLink.isEmpty {
                qrCodeImage
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .padding(Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                            .fill(.white)
                    )
            } else {
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(OnLifeColors.cardBackgroundElevated)
                    .frame(width: 232, height: 232)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: OnLifeColors.socialTeal))
                    )
            }

            VStack(spacing: Spacing.sm) {
                Text("Scan to connect")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Friends can scan this code with their OnLife app to instantly connect with you")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            // Username badge
            HStack(spacing: Spacing.sm) {
                Image(systemName: "at")
                    .font(.system(size: 14))

                Text(username)
                    .font(OnLifeFont.body())
            }
            .foregroundColor(OnLifeColors.socialTeal)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(OnLifeColors.socialTeal.opacity(0.15))
            )

            // Save QR button
            Button(action: saveQRCode) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14))

                    Text("Save QR Code")
                        .font(OnLifeFont.button())
                }
                .foregroundColor(OnLifeColors.socialTeal)
            }
        }
    }

    // MARK: - QR Code Generation

    private var qrCodeImage: Image {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(inviteLink.utf8)
        filter.correctionLevel = "M"

        if let outputImage = filter.outputImage,
           let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return Image(uiImage: UIImage(cgImage: cgImage))
        }

        return Image(systemName: "qrcode")
    }

    // MARK: - Actions

    private func generateInviteLink() {
        isGenerating = true

        // Simulate link generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            inviteLink = "https://onlife.app/invite/\(userId.prefix(8))?ref=\(username)"
            isGenerating = false
        }
    }

    private func copyLink() {
        UIPasteboard.general.string = inviteLink
        HapticManager.shared.notificationOccurred(.success)

        withAnimation {
            showingCopiedFeedback = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingCopiedFeedback = false
            }
        }
    }

    private func saveQRCode() {
        // In a real app, this would save to photo library
        HapticManager.shared.notificationOccurred(.success)
    }
}

// MARK: - Invite Card (for sharing in-app)

struct InviteCard: View {
    let username: String
    let onShare: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(OnLifeColors.socialTeal.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 18))
                        .foregroundColor(OnLifeColors.socialTeal)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Invite Friends")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("Grow your flow community")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }

                Spacer()

                Button(action: onShare) {
                    Text("Invite")
                        .font(OnLifeFont.label())
                        .foregroundColor(OnLifeColors.textPrimary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            Capsule()
                                .fill(OnLifeColors.socialTeal)
                        )
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

// MARK: - Preview

#if DEBUG
struct InviteLinkSheet_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            InviteLinkSheet(
                userId: "user123",
                username: "flowmaster",
                onDismiss: {}
            )

            InviteCard(username: "flowmaster", onShare: {})
                .padding()
                .background(OnLifeColors.deepForest)
        }
        .preferredColorScheme(.dark)
    }
}
#endif
