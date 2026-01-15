import SwiftUI

/// Test view for product database functionality
struct ProductDatabaseTestView: View {
    @State private var stats = ProductDatabaseManager.shared.getDatabaseStats()
    @State private var allProducts: [ScannedProduct] = []
    @State private var testBarcode = "070847811800" // Monster Ultra
    @State private var foundProduct: ScannedProduct?

    var body: some View {
        ZStack {
            AppColors.richSoil
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "cylinder.split.1x2.fill")
                            .font(.system(size: 80))
                            .foregroundColor(AppColors.healthy)

                        Text("Product Database Test")
                            .font(AppFont.heading1())
                            .foregroundColor(AppColors.textPrimary)
                    }

                    // Statistics
                    VStack(spacing: Spacing.sm) {
                        Text("Database Statistics")
                            .font(AppFont.heading3())
                            .foregroundColor(AppColors.textPrimary)

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
                            .font(AppFont.heading3())
                            .foregroundColor(AppColors.textPrimary)

                        TextField("Enter barcode", text: $testBarcode)
                            .font(AppFont.body())
                            .foregroundColor(AppColors.textPrimary)
                            .padding()
                            .background(AppColors.lightSoil)
                            .cornerRadius(CornerRadius.medium)

                        Button(action: searchBarcode) {
                            Text("Search")
                                .font(AppFont.button())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.healthy)
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
                                .font(AppFont.heading3())
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()

                            Button(action: loadAllProducts) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(AppColors.healthy)
                            }
                        }

                        if allProducts.isEmpty {
                            Button(action: loadAllProducts) {
                                Text("Load All Products")
                                    .font(AppFont.button())
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppColors.healthy)
                                    .cornerRadius(CornerRadius.medium)
                            }
                        } else {
                            ForEach(allProducts.prefix(10)) { product in
                                ProductCard(product: product)
                            }

                            if allProducts.count > 10 {
                                Text("... and \(allProducts.count - 10) more")
                                    .font(AppFont.bodySmall())
                                    .foregroundColor(AppColors.textTertiary)
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
                .font(AppFont.heading2())
                .foregroundColor(AppColors.healthy)

            Text(label)
                .font(AppFont.label())
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppColors.lightSoil)
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
                        .font(AppFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)

                    Text(product.barcode)
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textTertiary)
                }

                Spacer()

                Text(product.category.rawValue)
                    .font(AppFont.labelSmall())
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(AppColors.darkSoil)
                    .cornerRadius(CornerRadius.small)
            }

            if let caffeine = product.caffeineAmount {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(AppColors.healthy)
                    Text("\(Int(caffeine))mg caffeine")
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textSecondary)

                    if let volume = product.volumeAmount {
                        Text("•")
                            .foregroundColor(AppColors.textTertiary)
                        Text("\(Int(volume))ml")
                            .font(AppFont.bodySmall())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            if let theanine = product.lTheanineAmount {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                    Text("\(Int(theanine))mg L-theanine")
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding()
        .background(AppColors.lightSoil)
        .cornerRadius(CornerRadius.medium)
    }
}

#Preview {
    ProductDatabaseTestView()
}
