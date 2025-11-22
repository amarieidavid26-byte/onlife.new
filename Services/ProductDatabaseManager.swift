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
        // Check user products first (they might have corrected/updated data)
        if let product = userProducts[barcode] {
            return product
        }

        // Then check local database
        if let product = localProducts[barcode] {
            return product
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
}

// MARK: - Helper Struct

/// Helper struct for JSON decoding of product database
struct ProductDatabaseJSON: Codable {
    let products: [ScannedProduct]
}
