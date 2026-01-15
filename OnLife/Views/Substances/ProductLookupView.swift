import SwiftUI

/// Complete product lookup flow after barcode scan
struct ProductLookupView: View {
    let barcode: String
    @Environment(\.dismiss) private var dismiss
    let onProductLogged: () -> Void

    @State private var product: ScannedProduct?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showManualEntry = false
    @State private var shouldLog = false

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.richSoil
                    .ignoresSafeArea()

                if isLoading {
                    VStack(spacing: Spacing.lg) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(AppColors.healthy)

                        Text("Looking up product...")
                            .font(AppFont.body())
                            .foregroundColor(AppColors.textSecondary)

                        Text(barcode)
                            .font(AppFont.labelSmall())
                            .foregroundColor(AppColors.textTertiary)
                    }
                } else if let product = product {
                    ProductDetailsView(
                        product: product,
                        onLog: {
                            print("🎯 [ProductLookup] onLog closure invoked! Setting shouldLog = true")
                            shouldLog = true
                        },
                        onCancel: {
                            dismiss()
                        }
                    )
                } else {
                    ProductNotFoundView(
                        barcode: barcode,
                        onManualEntry: {
                            showManualEntry = true
                        },
                        onCancel: {
                            dismiss()
                        }
                    )
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await lookupProduct()
        }
        .onChange(of: shouldLog) { _, newValue in
            if newValue, let product = product {
                print("🔄 [ProductLookup] onChange triggered - logging product")
                logProduct(product)
            }
        }
        .sheet(isPresented: $showManualEntry) {
            ManualProductEntryView(barcode: barcode) { product in
                self.product = product
                showManualEntry = false
            }
        }
    }

    // MARK: - Product Lookup

    private func lookupProduct() async {
        // 1. Check local database first (instant)
        if let localProduct = ProductDatabaseManager.shared.findProduct(barcode: barcode) {
            await MainActor.run {
                self.product = localProduct
                self.isLoading = false
            }
            return
        }

        // 2. Try OpenFoodFacts API (1-2 second delay)
        do {
            if let apiProduct = try await OpenFoodFactsService.shared.fetchProduct(barcode: barcode) {
                await MainActor.run {
                    self.product = apiProduct
                    self.isLoading = false
                }
                // Auto-save to user products for future instant lookup
                ProductDatabaseManager.shared.addUserProduct(apiProduct)
                return
            }
        } catch {
            print("⚠️ API lookup failed: \(error)")
        }

        // 3. Product not found anywhere
        await MainActor.run {
            self.product = nil
            self.isLoading = false
        }
    }

    // MARK: - Logging

    private func logProduct(_ product: ScannedProduct) {
        print("📝 [ProductLookup] User tapped Log button")
        print("📝 [ProductLookup] Logging: \(product.displayName)")
        print("📝 [ProductLookup] Caffeine: \(product.caffeineAmount ?? 0)mg, L-theanine: \(product.lTheanineAmount ?? 0)mg, Volume: \(product.volumeAmount ?? 0)ml")

        // Convert product to substance logs
        let substanceLogs = product.toSubstanceLogs()
        print("📝 [ProductLookup] Created \(substanceLogs.count) substance logs from product")

        // Log each substance
        for log in substanceLogs {
            print("📝 [ProductLookup] Logging to tracker: \(log.substanceType.rawValue) \(log.amount)\(log.unit.rawValue)")
            SubstanceTracker.shared.log(
                log.substanceType,
                amount: log.amount,
                source: log.source
            )
        }

        // If no substances to log, warn
        if substanceLogs.isEmpty {
            print("⚠️ [ProductLookup] WARNING: No substances to log from this product!")
        }

        // Haptic feedback
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)

        // Save to user products if from API (already done in lookupProduct, but defensive)
        if product.source == .openFoodFacts {
            ProductDatabaseManager.shared.addUserProduct(product)
        }

        print("📝 [ProductLookup] Calling onProductLogged callback")
        onProductLogged()

        print("📝 [ProductLookup] Dismissing view")
        dismiss()
    }
}

// MARK: - Product Details View

/// Display product details with nutrition info and log button
struct ProductDetailsView: View {
    let product: ScannedProduct
    let onLog: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Product image if available
                if let imageURL = product.imageURL,
                   let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .cornerRadius(CornerRadius.medium)
                    } placeholder: {
                        Rectangle()
                            .fill(AppColors.lightSoil.opacity(0.3))
                            .frame(height: 200)
                            .cornerRadius(CornerRadius.medium)
                            .overlay(
                                ProgressView()
                            )
                    }
                } else {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 80))
                        .foregroundColor(AppColors.healthy)
                        .frame(height: 150)
                }

                // Product name
                VStack(spacing: Spacing.xs) {
                    if let brand = product.brand {
                        Text(brand)
                            .font(AppFont.bodySmall())
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Text(product.productName)
                        .font(AppFont.heading2())
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                }

                // Category badge
                Text(product.category.rawValue)
                    .font(AppFont.labelSmall())
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(AppColors.darkSoil)
                    .cornerRadius(CornerRadius.small)

                // Nutrition info
                VStack(spacing: Spacing.sm) {
                    if let caffeine = product.caffeineAmount {
                        NutrientRow(
                            icon: "bolt.fill",
                            name: "Caffeine",
                            amount: "\(Int(caffeine))mg",
                            color: AppColors.healthy
                        )
                    }

                    if let theanine = product.lTheanineAmount {
                        NutrientRow(
                            icon: "leaf.fill",
                            name: "L-Theanine",
                            amount: "\(Int(theanine))mg",
                            color: .green
                        )
                    }

                    if let volume = product.volumeAmount {
                        NutrientRow(
                            icon: "drop.fill",
                            name: "Volume",
                            amount: "\(Int(volume))ml",
                            color: .blue
                        )
                    }
                }
                .padding()
                .background(AppColors.lightSoil)
                .cornerRadius(CornerRadius.medium)

                // Ingredients
                if !product.ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Ingredients")
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)

                        ForEach(product.ingredients, id: \.self) { ingredient in
                            HStack {
                                Circle()
                                    .fill(AppColors.healthy)
                                    .frame(width: 6, height: 6)

                                Text(ingredient)
                                    .font(AppFont.body())
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppColors.lightSoil)
                    .cornerRadius(CornerRadius.medium)
                }

                // Source indicator
                HStack {
                    Image(systemName: product.source == .localDatabase ? "internaldrive" : "globe")
                        .foregroundColor(AppColors.textTertiary)
                    Text("Source: \(product.source.rawValue)")
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textTertiary)
                }

                // Buttons
                VStack(spacing: Spacing.md) {
                    Button {
                        print("🔘 [ProductDetails] Log button tapped!")
                        onLog()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Log This Product")
                        }
                        .font(AppFont.button())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.healthy)
                        .cornerRadius(CornerRadius.medium)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())

                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(AppFont.body())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding()
        }
        .background(AppColors.richSoil)
    }
}

// MARK: - Nutrient Row

struct NutrientRow: View {
    let icon: String
    let name: String
    let amount: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(name)
                .font(AppFont.body())
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(amount)
                .font(AppFont.body())
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

// MARK: - Product Not Found View

/// Shown when product is not in any database
struct ProductNotFoundView: View {
    let barcode: String
    let onManualEntry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)

            VStack(spacing: Spacing.sm) {
                Text("Product Not Found")
                    .font(AppFont.heading2())
                    .foregroundColor(AppColors.textPrimary)

                Text("We couldn't find this product in our database or OpenFoodFacts")
                    .font(AppFont.body())
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Text("Barcode: \(barcode)")
                .font(AppFont.bodySmall())
                .foregroundColor(AppColors.textSecondary)
                .padding()
                .background(AppColors.lightSoil)
                .cornerRadius(CornerRadius.small)

            Spacer()

            VStack(spacing: Spacing.md) {
                Button(action: onManualEntry) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Enter Manually")
                    }
                    .font(AppFont.button())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.healthy)
                    .foregroundColor(.white)
                    .cornerRadius(CornerRadius.medium)
                }

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(AppColors.richSoil)
    }
}

// MARK: - Manual Product Entry View

/// Simplified manual entry for unknown products
struct ManualProductEntryView: View {
    let barcode: String
    let onSave: (ScannedProduct) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var productName = ""
    @State private var brand = ""
    @State private var caffeineAmount = ""
    @State private var category: ScannedProduct.ProductCategory = .other

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Product Info")) {
                    TextField("Product Name", text: $productName)
                    TextField("Brand (optional)", text: $brand)
                }

                Section(header: Text("Caffeine Content")) {
                    TextField("Caffeine (mg)", text: $caffeineAmount)
                        .keyboardType(.decimalPad)
                }

                Section(header: Text("Category")) {
                    Picker("Category", selection: $category) {
                        ForEach(ScannedProduct.ProductCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                }
            }
            .navigationTitle("Add Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProduct()
                    }
                    .foregroundColor(AppColors.healthy)
                    .disabled(productName.isEmpty || caffeineAmount.isEmpty)
                }
            }
        }
    }

    private func saveProduct() {
        let product = ScannedProduct(
            barcode: barcode,
            brand: brand.isEmpty ? nil : brand,
            productName: productName,
            caffeineAmount: Double(caffeineAmount),
            lTheanineAmount: nil,
            volumeAmount: nil,
            servingSize: nil,
            category: category,
            ingredients: caffeineAmount.isEmpty ? [] : ["Caffeine \(caffeineAmount)mg"],
            imageURL: nil,
            source: .userContributed,
            lastUpdated: Date()
        )

        ProductDatabaseManager.shared.addUserProduct(product)
        onSave(product)
        dismiss()
    }
}
