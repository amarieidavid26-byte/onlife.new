import SwiftUI

/// Test view for OpenFoodFacts API integration
struct OpenFoodFactsTestView: View {
    @State private var barcode = "737628064502" // Coca-Cola can
    @State private var isLoading = false
    @State private var foundProduct: ScannedProduct?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AppColors.richSoil
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "globe")
                            .font(.system(size: 80))
                            .foregroundColor(AppColors.healthy)

                        Text("OpenFoodFacts Test")
                            .font(AppFont.heading1())
                            .foregroundColor(AppColors.textPrimary)

                        Text("Test API integration with fallback lookup")
                            .font(AppFont.body())
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Barcode input
                    VStack(spacing: Spacing.md) {
                        TextField("Enter barcode", text: $barcode)
                            .font(AppFont.body())
                            .foregroundColor(AppColors.textPrimary)
                            .padding()
                            .background(AppColors.lightSoil)
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
                            .font(AppFont.button())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.healthy)
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
                                .font(AppFont.body())
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .padding()
                        .background(AppColors.lightSoil)
                        .cornerRadius(CornerRadius.medium)
                        .padding(.horizontal)
                    }

                    // Product result
                    if let product = foundProduct {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("Found Product")
                                .font(AppFont.heading3())
                                .foregroundColor(AppColors.textPrimary)

                            ProductDetailCard(product: product)

                            // Source badge
                            HStack {
                                Image(systemName: product.source == .localDatabase ? "internaldrive" : "globe")
                                    .foregroundColor(product.source == .localDatabase ? AppColors.healthy : .blue)
                                Text("Source: \(product.source.rawValue)")
                                    .font(AppFont.bodySmall())
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .padding()
                            .background(AppColors.lightSoil)
                            .cornerRadius(CornerRadius.medium)
                        }
                        .padding()
                    }

                    // Example barcodes
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Try these barcodes:")
                            .font(AppFont.label())
                            .foregroundColor(AppColors.textTertiary)

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
                .font(AppFont.body())
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)

            // Barcode
            HStack {
                Image(systemName: "barcode")
                    .foregroundColor(AppColors.textTertiary)
                Text(product.barcode)
                    .font(AppFont.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
            }

            Divider()
                .background(AppColors.darkSoil)

            // Caffeine info
            if let caffeine = product.caffeineAmount {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(AppColors.healthy)
                    Text("Caffeine: \(Int(caffeine))mg")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textPrimary)
                }
            } else {
                HStack {
                    Image(systemName: "bolt.slash")
                        .foregroundColor(AppColors.textTertiary)
                    Text("No caffeine data")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            // L-theanine info
            if let theanine = product.lTheanineAmount {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                    Text("L-Theanine: \(Int(theanine))mg")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textPrimary)
                }
            }

            // Volume
            if let volume = product.volumeAmount {
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundColor(.blue)
                    Text("Volume: \(Int(volume))ml")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textPrimary)
                }
            }

            // Category
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(AppColors.textTertiary)
                Text("Category: \(product.category.rawValue)")
                    .font(AppFont.body())
                    .foregroundColor(AppColors.textSecondary)
            }

            // Ingredients
            if !product.ingredients.isEmpty {
                Divider()
                    .background(AppColors.darkSoil)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Ingredients:")
                        .font(AppFont.bodySmall())
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textSecondary)

                    ForEach(product.ingredients, id: \.self) { ingredient in
                        HStack {
                            Text("•")
                            Text(ingredient)
                        }
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding()
        .background(AppColors.lightSoil)
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
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textPrimary)
                    Text(barcode)
                        .font(AppFont.labelSmall())
                        .foregroundColor(AppColors.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal)
            .background(AppColors.lightSoil)
            .cornerRadius(CornerRadius.small)
        }
    }
}

#Preview {
    OpenFoodFactsTestView()
}
