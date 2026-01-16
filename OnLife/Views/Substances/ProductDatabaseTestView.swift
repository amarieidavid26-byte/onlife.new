import SwiftUI

/// Test view for product database functionality
struct ProductDatabaseTestView: View {
    @State private var stats = ProductDatabaseManager.shared.getDatabaseStats()
    @State private var allProducts: [ScannedProduct] = []
    @State private var testBarcode = "070847811800" // Monster Ultra
    @State private var foundProduct: ScannedProduct?

    var body: some View {
        ZStack {
            OnLifeColors.deepForest
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "cylinder.split.1x2.fill")
                            .font(.system(size: 80))
                            .foregroundColor(OnLifeColors.sage)

                        Text("Product Database Test")
                            .font(OnLifeFont.heading1())
                            .foregroundColor(OnLifeColors.textPrimary)
                    }

                    // Statistics
                    VStack(spacing: Spacing.sm) {
                        Text("Database Statistics")
                            .font(OnLifeFont.heading3())
                            .foregroundColor(OnLifeColors.textPrimary)

                        HStack(spacing: Spacing.md) {
                            DatabaseStatCard(label: "Local", value: "\(stats.local)")
                            DatabaseStatCard(label: "User", value: "\(stats.user)")
                            DatabaseStatCard(label: "Total", value: "\(stats.total)")
                        }
                    }
                    .padding()

                    // Barcode lookup test
                    VStack(spacing: Spacing.md) {
                        Text("Barcode Lookup Test")
                            .font(OnLifeFont.heading3())
                            .foregroundColor(OnLifeColors.textPrimary)

                        TextField("Enter barcode", text: $testBarcode)
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textPrimary)
                            .padding()
                            .background(OnLifeColors.cardBackground)
                            .cornerRadius(CornerRadius.medium)

                        Button(action: searchBarcode) {
                            Text("Search")
                                .font(OnLifeFont.button())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(OnLifeColors.sage)
                                .cornerRadius(CornerRadius.medium)
                        }

                        if let product = foundProduct {
                            ProductCard(product: product)
                        }
                    }
                    .padding()

                    // All products list
                    VStack(spacing: Spacing.md) {
                        HStack {
                            Text("All Products (\(allProducts.count))")
                                .font(OnLifeFont.heading3())
                                .foregroundColor(OnLifeColors.textPrimary)

                            Spacer()

                            Button(action: loadAllProducts) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(OnLifeColors.sage)
                            }
                        }

                        if allProducts.isEmpty {
                            Button(action: loadAllProducts) {
                                Text("Load All Products")
                                    .font(OnLifeFont.button())
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(OnLifeColors.sage)
                                    .cornerRadius(CornerRadius.medium)
                            }
                        } else {
                            ForEach(allProducts.prefix(10)) { product in
                                ProductCard(product: product)
                            }

                            if allProducts.count > 10 {
                                Text("... and \(allProducts.count - 10) more")
                                    .font(OnLifeFont.bodySmall())
                                    .foregroundColor(OnLifeColors.textTertiary)
                            }
                        }
                    }
                    .padding()
                }
                .padding()
            }
        }
        .onAppear {
            stats = ProductDatabaseManager.shared.getDatabaseStats()
        }
    }

    private func searchBarcode() {
        foundProduct = ProductDatabaseManager.shared.findProduct(barcode: testBarcode)
    }

    private func loadAllProducts() {
        allProducts = ProductDatabaseManager.shared.getAllProducts()
    }
}

struct DatabaseStatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(OnLifeFont.heading2())
                .foregroundColor(OnLifeColors.sage)

            Text(label)
                .font(OnLifeFont.label())
                .foregroundColor(OnLifeColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(OnLifeColors.cardBackground)
        .cornerRadius(CornerRadius.medium)
    }
}

struct ProductCard: View {
    let product: ScannedProduct

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(product.displayName)
                        .font(OnLifeFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text(product.barcode)
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textTertiary)
                }

                Spacer()

                Text(product.category.rawValue)
                    .font(OnLifeFont.labelSmall())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(OnLifeColors.surface)
                    .cornerRadius(CornerRadius.small)
            }

            if let caffeine = product.caffeineAmount {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(OnLifeColors.sage)
                    Text("\(Int(caffeine))mg caffeine")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)

                    if let volume = product.volumeAmount {
                        Text("•")
                            .foregroundColor(OnLifeColors.textTertiary)
                        Text("\(Int(volume))ml")
                            .font(OnLifeFont.bodySmall())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                }
            }

            if let theanine = product.lTheanineAmount {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                    Text("\(Int(theanine))mg L-theanine")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
            }
        }
        .padding()
        .background(OnLifeColors.cardBackground)
        .cornerRadius(CornerRadius.medium)
    }
}

#Preview {
    ProductDatabaseTestView()
}
