import SwiftUI

struct InitialRatingPromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var contact: ContactSnapshot
    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: K.Layout.sectionSpacing) {
                    header
                    ratingSection
                    actions
                }
                .kScreenPadding()
            }
            .background(K.Color.screenBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        finishPrompt()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(K.Color.tileBackground, in: Circle())
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
    }

    private var header: some View {
        VStack(spacing: K.Spacing.md) {
            ContactPromptAvatar(contact: contact, size: K.Size.Avatar.lg)

            VStack(spacing: K.Spacing.xs) {
                Text(contact.primaryLabel)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                if contact.isNewlyAdded {
                    ContactTagPill(
                        icon: "sparkles",
                        title: "New contact",
                        tint: K.Color.primary,
                        style: .regular
                    )
                }

                Text("Rate this person on three traits. You can skip and come back anytime.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .kCardSurface(radius: K.Radius.lg)
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: K.Spacing.md) {
            Text("Trait Ratings")
                .font(K.Typography.sectionTitle)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: K.Spacing.md) {
                TraitRatingSlider(title: "Intelligence", value: $contact.intelligenceRating)
                TraitRatingSlider(title: "Integrity", value: $contact.integrityRating)
                TraitRatingSlider(title: "Drive", value: $contact.driveRating)
            }
        }
        .kCardSurface()
    }

    private var actions: some View {
        VStack(spacing: K.Spacing.sm) {
            Button {
                finishPrompt()
            } label: {
                Text("Save Rating")
            }
            .buttonStyle(.kPrimary(size: .large, corner: .prominent, expands: true))

            Button {
                finishPrompt()
            } label: {
                Text("Skip for Now")
            }
            .buttonStyle(.kTertiary(size: .medium, corner: .standard, expands: true))
        }
    }

    private func finishPrompt() {
        onComplete()
        dismiss()
    }
}

private struct ContactPromptAvatar: View {
    let contact: ContactSnapshot
    let size: CGFloat

    var body: some View {
        if let data = contact.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(.circle)
        } else {
            Text(contact.initials)
                .font(.title2.weight(.semibold))
                .foregroundStyle(K.Color.primary)
                .frame(width: size, height: size)
                .background(K.Color.primarySoft, in: .circle)
        }
    }
}
