import Foundation

/// Manager for local product database and user-contributed products
class ProductDatabaseManager {
    static let shared = ProductDatabaseManager()

    private var localProducts: [String: ScannedProduct] = [:]
    private var userProducts: [String: ScannedProduct] = [:]

    private let userProductsKey = "user_contributed_products"

    private init() {
        loadLocalDatabase()
        loadUserProducts()
        // Auto-migrate cached products with missing caffeine data
        migrateUserProductsWithMissingCaffeine()
    }

    // MARK: - Local Database

    /// Load products from bundled ProductDatabase.json
    private func loadLocalDatabase() {
        guard let url = Bundle.main.url(forResource: "ProductDatabase", withExtension: "json") else {
            print("⚠️ ProductDatabase.json not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let json = try decoder.decode(ProductDatabaseJSON.self, from: data)

            // Convert to dictionary for fast O(1) lookup by barcode
            for product in json.products {
                var scannedProduct = product
                scannedProduct.lastUpdated = Date()
                localProducts[product.barcode] = scannedProduct
            }

            print("✅ Loaded \(localProducts.count) products from local database")
        } catch {
            print("⚠️ Could not load ProductDatabase.json: \(error.localizedDescription)")
        }
    }

    // MARK: - User Products

    /// Load user-contributed products from UserDefaults
    private func loadUserProducts() {
        guard let data = UserDefaults.standard.data(forKey: userProductsKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let products = try decoder.decode([ScannedProduct].self, from: data)

            for product in products {
                userProducts[product.barcode] = product
            }

            print("✅ Loaded \(userProducts.count) user-contributed products")
        } catch {
            print("⚠️ Could not load user products: \(error.localizedDescription)")
        }
    }

    /// Save user products to UserDefaults
    private func saveUserProducts() {
        let products = Array(userProducts.values)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(products)
            UserDefaults.standard.set(data, forKey: userProductsKey)
        } catch {
            print("⚠️ Could not save user products: \(error.localizedDescription)")
        }
    }

    // MARK: - Lookup

    /// Find product by barcode (synchronous - local only)
    /// - Parameter barcode: Barcode string to lookup
    /// - Returns: ScannedProduct if found in local/user databases, nil otherwise
    func findProduct(barcode: String) -> ScannedProduct? {
        var product: ScannedProduct?

        // Check user products first (they might have corrected/updated data)
        if let userProduct = userProducts[barcode] {
            product = userProduct
        }
        // Then check local database
        else if let localProduct = localProducts[barcode] {
            product = localProduct
        }

        // Apply caffeine fallback if product has no caffeine data
        if var foundProduct = product {
            if (foundProduct.caffeineAmount ?? 0) == 0 {
                if let estimatedCaffeine = estimateCaffeineForKnownProduct(foundProduct) {
                    print("🔧 [ProductDB] Applying caffeine fallback: \(foundProduct.displayName) → \(estimatedCaffeine)mg")
                    foundProduct = ScannedProduct(
                        barcode: foundProduct.barcode,
                        brand: foundProduct.brand,
                        productName: foundProduct.productName,
                        caffeineAmount: estimatedCaffeine,
                        lTheanineAmount: foundProduct.lTheanineAmount,
                        volumeAmount: foundProduct.volumeAmount,
                        servingSize: foundProduct.servingSize,
                        category: foundProduct.category,
                        ingredients: foundProduct.ingredients,
                        imageURL: foundProduct.imageURL,
                        source: foundProduct.source,
                        lastUpdated: foundProduct.lastUpdated
                    )
                    return foundProduct
                }
            }
            return foundProduct
        }

        return nil
    }

    /// Estimate caffeine for well-known products when data is missing
    /// Mirrors the logic in OpenFoodFactsService for consistency
    private func estimateCaffeineForKnownProduct(_ product: ScannedProduct) -> Double? {
        let productName = product.productName.lowercased()
        let brand = (product.brand ?? "").lowercased()
        let category = product.category

        // Known caffeine amounts per standard serving
        // Sources: FDA, product labels, caffeineinformer.com

        // Monster Energy (~160mg per 16oz can)
        if brand.contains("monster") || productName.contains("monster") {
            if category == .energyDrink {
                return 160.0
            }
        }

        // Red Bull (~80mg per 8.4oz can)
        if brand.contains("red bull") || productName.contains("red bull") {
            return 80.0
        }

        // Rockstar (~160mg per 16oz can)
        if brand.contains("rockstar") || productName.contains("rockstar") {
            return 160.0
        }

        // Coca-Cola products (~34mg per 12oz/355ml)
        if brand.contains("coca-cola") || brand.contains("coca cola") || productName.contains("coca-cola") || productName.contains("coca cola") {
            return 34.0
        }

        // Pepsi (~38mg per 12oz)
        if brand.contains("pepsi") || productName.contains("pepsi") {
            return 38.0
        }

        // Starbucks drinks
        if brand.contains("starbucks") || productName.contains("starbucks") {
            if productName.contains("doubleshot") {
                return 135.0
            }
            if productName.contains("frappuccino") {
                return 75.0
            }
            return 100.0
        }

        // Dr Pepper (~41mg per 12oz)
        if brand.contains("dr pepper") || brand.contains("dr. pepper") || productName.contains("dr pepper") {
            return 41.0
        }

        // Mountain Dew (~54mg per 12oz)
        if brand.contains("mountain dew") || productName.contains("mountain dew") {
            return 54.0
        }

        // Bang Energy (~300mg per 16oz)
        if brand.contains("bang") || productName.contains("bang") {
            return 300.0
        }

        // Celsius (~200mg per can)
        if brand.contains("celsius") || productName.contains("celsius") {
            return 200.0
        }

        // C4 Energy (~150-200mg per can)
        if brand.contains("c4") || productName.contains("c4") {
            return 150.0
        }

        // Generic energy drink category fallback
        if category == .energyDrink {
            return 80.0  // Conservative estimate
        }

        return nil
    }

    /// Find product by barcode with OpenFoodFacts fallback (async)
    /// - Parameter barcode: Barcode string to lookup
    /// - Returns: ScannedProduct from local database or OpenFoodFacts API
    /// - Throws: ProductError if lookup fails
    func findProductWithFallback(barcode: String) async throws -> ScannedProduct? {
        // First try local lookup
        if let product = findProduct(barcode: barcode) {
            return product
        }

        // If not found locally, try OpenFoodFacts API
        print("🌐 Product not found locally, checking OpenFoodFacts...")
        if let product = try await OpenFoodFactsService.shared.fetchProduct(barcode: barcode) {
            print("✅ Found product in OpenFoodFacts: \(product.displayName)")
            // Cache it as user product for future lookups
            addUserProduct(product)
            return product
        }

        return nil
    }

    /// Add or update a user-contributed product
    /// - Parameter product: Product to add/update
    func addUserProduct(_ product: ScannedProduct) {
        var updatedProduct = product
        updatedProduct.lastUpdated = Date()
        userProducts[product.barcode] = updatedProduct
        saveUserProducts()

        print("✅ Added user product: \(product.displayName)")
    }

    /// Get all products (local + user)
    /// - Returns: Array of all products sorted by name
    func getAllProducts() -> [ScannedProduct] {
        let all = Array(localProducts.values) + Array(userProducts.values)
        return all.sorted { $0.productName < $1.productName }
    }

    /// Get products by category
    /// - Parameter category: Product category to filter
    /// - Returns: Array of products in category
    func getProducts(in category: ScannedProduct.ProductCategory) -> [ScannedProduct] {
        return getAllProducts().filter { $0.category == category }
    }

    /// Delete a user product
    /// - Parameter barcode: Barcode of product to delete
    func deleteUserProduct(barcode: String) {
        userProducts.removeValue(forKey: barcode)
        saveUserProducts()
    }

    /// Get database statistics
    func getDatabaseStats() -> (local: Int, user: Int, total: Int) {
        return (
            local: localProducts.count,
            user: userProducts.count,
            total: localProducts.count + userProducts.count
        )
    }

    /// Clear all cached user products (useful for fixing bad data)
    /// Call this to force re-fetch from OpenFoodFacts with corrected parsing
    func clearUserProductsCache() {
        let count = userProducts.count
        userProducts.removeAll()
        saveUserProducts()
        print("🧹 [ProductDB] Cleared \(count) cached user products")
    }

    /// Migrate user products with 0 caffeine - apply brand fallbacks
    /// Returns count of products that were updated
    @discardableResult
    func migrateUserProductsWithMissingCaffeine() -> Int {
        var updatedCount = 0

        for (barcode, product) in userProducts {
            if (product.caffeineAmount ?? 0) == 0 {
                if let estimatedCaffeine = estimateCaffeineForKnownProduct(product) {
                    let updatedProduct = ScannedProduct(
                        barcode: product.barcode,
                        brand: product.brand,
                        productName: product.productName,
                        caffeineAmount: estimatedCaffeine,
                        lTheanineAmount: product.lTheanineAmount,
                        volumeAmount: product.volumeAmount,
                        servingSize: product.servingSize,
                        category: product.category,
                        ingredients: product.ingredients,
                        imageURL: product.imageURL,
                        source: product.source,
                        lastUpdated: Date()
                    )
                    userProducts[barcode] = updatedProduct
                    updatedCount += 1
                    print("🔧 [ProductDB] Migrated: \(product.displayName) → \(estimatedCaffeine)mg caffeine")
                }
            }
        }

        if updatedCount > 0 {
            saveUserProducts()
            print("🔧 [ProductDB] Migration complete: updated \(updatedCount) products")
        }

        return updatedCount
    }
}

// MARK: - Helper Struct

/// Helper struct for JSON decoding of product database
struct ProductDatabaseJSON: Codable {
    let products: [ScannedProduct]
}
