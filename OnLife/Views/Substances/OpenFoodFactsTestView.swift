import SwiftUI

/// Test view for OpenFoodFacts API integration
struct OpenFoodFactsTestView: View {
    @State private var barcode = "737628064502" // Coca-Cola can
    @State private var isLoading = false
    @State private var foundProduct: ScannedProduct?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            OnLifeColors.deepForest
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "globe")
                            .font(.system(size: 80))
                            .foregroundColor(OnLifeColors.sage)

                        Text("OpenFoodFacts Test")
                            .font(OnLifeFont.heading1())
                            .foregroundColor(OnLifeColors.textPrimary)

                        Text("Test API integration with fallback lookup")
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Barcode input
                    VStack(spacing: Spacing.md) {
                        TextField("Enter barcode", text: $barcode)
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textPrimary)
                            .padding()
                            .background(OnLifeColors.cardBackground)
                            .cornerRadius(CornerRadius.medium)
                            .keyboardType(.numberPad)

                        Button(action: searchProduct) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "magnifyingglass")
                                }
                                Text(isLoading ? "Searching..." : "Search with Fallback")
                            }
                            .font(OnLifeFont.button())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(OnLifeColors.sage)
                            .cornerRadius(CornerRadius.medium)
                        }
                        .disabled(isLoading || barcode.isEmpty)
                    }
                    .padding()

                    // Error message
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(OnLifeFont.body())
                                .foregroundColor(OnLifeColors.textPrimary)
                        }
                        .padding()
                        .background(OnLifeColors.cardBackground)
                        .cornerRadius(CornerRadius.medium)
                        .padding(.horizontal)
                    }

                    // Product result
                    if let product = foundProduct {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("Found Product")
                                .font(OnLifeFont.heading3())
                                .foregroundColor(OnLifeColors.textPrimary)

                            ProductDetailCard(product: product)

                            // Source badge
                            HStack {
                                Image(systemName: product.source == .localDatabase ? "internaldrive" : "globe")
                                    .foregroundColor(product.source == .localDatabase ? OnLifeColors.sage : .blue)
                                Text("Source: \(product.source.rawValue)")
                                    .font(OnLifeFont.bodySmall())
                                    .foregroundColor(OnLifeColors.textSecondary)
                            }
                            .padding()
                            .background(OnLifeColors.cardBackground)
                            .cornerRadius(CornerRadius.medium)
                        }
                        .padding()
                    }

                    // Example barcodes
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Try these barcodes:")
                            .font(OnLifeFont.label())
                            .foregroundColor(OnLifeColors.textTertiary)

                        ExampleBarcodeRow(
                            barcode: "070847811800",
                            label: "Monster Ultra (local)",
                            onSelect: { barcode = $0 }
                        )

                        ExampleBarcodeRow(
                            barcode: "737628064502",
                            label: "Coca-Cola (OpenFoodFacts)",
                            onSelect: { barcode = $0 }
                        )

                        ExampleBarcodeRow(
                            barcode: "5449000000996",
                            label: "Coca-Cola Europe (OpenFoodFacts)",
                            onSelect: { barcode = $0 }
                        )
                    }
                    .padding()
                }
                .padding()
            }
        }
    }

    private func searchProduct() {
        errorMessage = nil
        foundProduct = nil
        isLoading = true

        Task {
            do {
                foundProduct = try await ProductDatabaseManager.shared.findProductWithFallback(barcode: barcode)
                if foundProduct == nil {
                    errorMessage = "Product not found in local database or OpenFoodFacts"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct ProductDetailCard: View {
    let product: ScannedProduct

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Title
            Text(product.displayName)
                .font(OnLifeFont.body())
                .fontWeight(.semibold)
                .foregroundColor(OnLifeColors.textPrimary)

            // Barcode
            HStack {
                Image(systemName: "barcode")
                    .foregroundColor(OnLifeColors.textTertiary)
                Text(product.barcode)
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)
            }

            Divider()
                .background(OnLifeColors.surface)

            // Caffeine info
            if let caffeine = product.caffeineAmount {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(OnLifeColors.sage)
                    Text("Caffeine: \(Int(caffeine))mg")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)
                }
            } else {
                HStack {
                    Image(systemName: "bolt.slash")
                        .foregroundColor(OnLifeColors.textTertiary)
                    Text("No caffeine data")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
            }

            // L-theanine info
            if let theanine = product.lTheanineAmount {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                    Text("L-Theanine: \(Int(theanine))mg")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)
                }
            }

            // Volume
            if let volume = product.volumeAmount {
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundColor(.blue)
                    Text("Volume: \(Int(volume))ml")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)
                }
            }

            // Category
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(OnLifeColors.textTertiary)
                Text("Category: \(product.category.rawValue)")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
            }

            // Ingredients
            if !product.ingredients.isEmpty {
                Divider()
                    .background(OnLifeColors.surface)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Ingredients:")
                        .font(OnLifeFont.bodySmall())
                        .fontWeight(.semibold)
                        .foregroundColor(OnLifeColors.textSecondary)

                    ForEach(product.ingredients, id: \.self) { ingredient in
                        HStack {
                            Text("•")
                            Text(ingredient)
                        }
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                    }
                }
            }
        }
        .padding()
        .background(OnLifeColors.cardBackground)
        .cornerRadius(CornerRadius.medium)
    }
}

struct ExampleBarcodeRow: View {
    let barcode: String
    let label: String
    let onSelect: (String) -> Void

    var body: some View {
        Button(action: { onSelect(barcode) }) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(label)
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textPrimary)
                    Text(barcode)
                        .font(OnLifeFont.labelSmall())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(OnLifeColors.textTertiary)
            }
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal)
            .background(OnLifeColors.cardBackground)
            .cornerRadius(CornerRadius.small)
        }
    }
}

#Preview {
    OpenFoodFactsTestView()
}
