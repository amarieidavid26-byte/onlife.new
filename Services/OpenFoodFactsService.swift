import Foundation

/// Service for fetching product data from OpenFoodFacts API
class OpenFoodFactsService {
    static let shared = OpenFoodFactsService()

    private let baseURL = "https://world.openfoodfacts.org/api/v0/product"

    private init() {}

    // MARK: - Public API

    /// Fetch product information from OpenFoodFacts
    /// - Parameter barcode: Product barcode to lookup
    /// - Returns: ScannedProduct if found, nil if not in database
    /// - Throws: ProductError for network/parsing issues
    func fetchProduct(barcode: String) async throws -> ScannedProduct? {
        let urlString = "\(baseURL)/\(barcode).json"

        guard let url = URL(string: urlString) else {
            throw ProductError.invalidBarcode
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ProductError.networkError
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(OpenFoodFactsResponse.self, from: data)

        // Check if product was found
        guard apiResponse.status == 1,
              let product = apiResponse.product else {
            return nil
        }

        // Parse to our ScannedProduct model
        return parseOpenFoodFactsProduct(product, barcode: barcode)
    }

    // MARK: - Parsing

    /// Convert OpenFoodFacts product to our ScannedProduct model
    private func parseOpenFoodFactsProduct(
        _ product: OpenFoodFactsProduct,
        barcode: String
    ) -> ScannedProduct {
        // Extract caffeine amount from various possible fields
        let caffeineAmount = extractCaffeineAmount(from: product)

        // Determine category
        let category = determineCategory(from: product)

        // Extract ingredients list
        let ingredients = extractIngredients(from: product)

        return ScannedProduct(
            barcode: barcode,
            brand: product.brands,
            productName: product.productName ?? "Unknown Product",
            caffeineAmount: caffeineAmount,
            lTheanineAmount: nil,  // Usually not in OpenFoodFacts
            volumeAmount: extractVolume(from: product),
            servingSize: product.servingSize,
            category: category,
            ingredients: ingredients,
            imageURL: product.imageFrontURL,
            source: .openFoodFacts,
            lastUpdated: Date()
        )
    }

    /// Extract caffeine amount from product data
    private func extractCaffeineAmount(from product: OpenFoodFactsProduct) -> Double? {
        // OpenFoodFacts stores caffeine in GRAMS, not milligrams!
        // caffeine_100g is grams per 100g/100ml
        // We need to convert to milligrams (multiply by 1000)

        let nutriments = product.nutriments
        let caffeineUnit = nutriments?.caffeine_unit ?? "g"
        let isGrams = caffeineUnit.lowercased() == "g"
        let conversionFactor = isGrams ? 1000.0 : 1.0  // Convert g to mg

        print("🔬 [OpenFoodFacts] Parsing caffeine - unit: \(caffeineUnit), conversion: \(conversionFactor)x")
        print("🔬 [OpenFoodFacts] Raw values - caffeine_100g: \(nutriments?.caffeine_100g ?? -1), caffeine_serving: \(nutriments?.caffeine_serving ?? -1)")

        // Check nutriments for caffeine per 100g/100ml
        if let caffeinePer100 = nutriments?.caffeine_100g, caffeinePer100 > 0 {
            let caffeineMgPer100 = caffeinePer100 * conversionFactor
            print("🔬 [OpenFoodFacts] caffeine_100g: \(caffeinePer100)\(caffeineUnit) = \(caffeineMgPer100)mg per 100ml")

            // Convert to total amount if we have serving size
            if let servingQuantity = product.servingQuantity, servingQuantity > 0 {
                let totalCaffeine = (caffeineMgPer100 / 100.0) * servingQuantity
                print("🔬 [OpenFoodFacts] With serving \(servingQuantity)ml: \(totalCaffeine)mg total")
                return totalCaffeine
            }
            // Return per 100ml value if no serving size
            return caffeineMgPer100
        }

        // Check for caffeine per serving (also in grams usually)
        if let caffeineServing = nutriments?.caffeine_serving, caffeineServing > 0 {
            let caffeineMg = caffeineServing * conversionFactor
            print("🔬 [OpenFoodFacts] caffeine_serving: \(caffeineServing)\(caffeineUnit) = \(caffeineMg)mg")
            return caffeineMg
        }

        // Try to parse from ingredients text using regex
        if let ingredientsText = product.ingredientsText?.lowercased() {
            // Pattern: "caffeine: 150mg" or "caffeine 150 mg"
            let pattern = #"caffeine[:\s]+(\d+\.?\d*)\s*mg"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsString = ingredientsText as NSString
                if let match = regex.firstMatch(in: ingredientsText, range: NSRange(location: 0, length: nsString.length)) {
                    if match.numberOfRanges > 1 {
                        let numberRange = match.range(at: 1)
                        let numberString = nsString.substring(with: numberRange)
                        if let amount = Double(numberString) {
                            print("🔬 [OpenFoodFacts] Found caffeine in ingredients text: \(amount)mg")
                            return amount
                        }
                    }
                }
            }
        }

        // Fallback: Estimate caffeine for known brands/categories
        if let estimatedCaffeine = estimateCaffeineForKnownProduct(product) {
            print("🔬 [OpenFoodFacts] Using estimated caffeine for known product: \(estimatedCaffeine)mg")
            return estimatedCaffeine
        }

        print("🔬 [OpenFoodFacts] No caffeine data found")
        return nil
    }

    /// Estimate caffeine for well-known products when API data is missing
    private func estimateCaffeineForKnownProduct(_ product: OpenFoodFactsProduct) -> Double? {
        let productName = (product.productName ?? "").lowercased()
        let brand = (product.brands ?? "").lowercased()
        let categories = (product.categories ?? "").lowercased()

        // Known caffeine amounts per standard serving
        // Sources: FDA, product labels, caffeineinformer.com

        // Coca-Cola products (~34mg per 12oz/355ml, ~10mg per 100ml)
        if brand.contains("coca-cola") || brand.contains("coca cola") || productName.contains("coca-cola") || productName.contains("coca cola") {
            if productName.contains("zero") || productName.contains("diet") {
                return 34.0  // ~34mg per can
            }
            return 34.0  // Regular Coca-Cola: 34mg per 12oz can
        }

        // Pepsi (~38mg per 12oz)
        if brand.contains("pepsi") || productName.contains("pepsi") {
            return 38.0
        }

        // Red Bull (~80mg per 8.4oz can)
        if brand.contains("red bull") || productName.contains("red bull") {
            return 80.0
        }

        // Monster Energy (~160mg per 16oz can) - already handled by API but backup
        if brand.contains("monster") || productName.contains("monster") {
            if categories.contains("energy") {
                return 160.0
            }
        }

        // Rockstar (~160mg per 16oz can)
        if brand.contains("rockstar") || productName.contains("rockstar") {
            return 160.0
        }

        // Starbucks drinks (varies widely, estimate for bottled)
        if brand.contains("starbucks") || productName.contains("starbucks") {
            if productName.contains("doubleshot") {
                return 135.0  // Doubleshot Espresso
            }
            if productName.contains("frappuccino") {
                return 75.0  // Bottled Frappuccino
            }
            return 100.0  // Generic estimate
        }

        // Dr Pepper (~41mg per 12oz)
        if brand.contains("dr pepper") || brand.contains("dr. pepper") || productName.contains("dr pepper") {
            return 41.0
        }

        // Mountain Dew (~54mg per 12oz)
        if brand.contains("mountain dew") || productName.contains("mountain dew") {
            return 54.0
        }

        // Generic energy drink category fallback
        if categories.contains("energy drink") || categories.contains("energy drinks") {
            return 80.0  // Conservative estimate
        }

        return nil
    }

    /// Extract volume from product quantity string
    private func extractVolume(from product: OpenFoodFactsProduct) -> Double? {
        if let quantity = product.quantity {
            // Try to extract ml from quantity string (e.g., "473 ml")
            let pattern = #"(\d+\.?\d*)\s*ml"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsString = quantity as NSString
                if let match = regex.firstMatch(in: quantity, range: NSRange(location: 0, length: nsString.length)) {
                    if match.numberOfRanges > 1 {
                        let numberRange = match.range(at: 1)
                        let numberString = nsString.substring(with: numberRange)
                        if let volume = Double(numberString) {
                            return volume
                        }
                    }
                }
            }
        }
        return nil
    }

    /// Determine product category from OpenFoodFacts data
    private func determineCategory(from product: OpenFoodFactsProduct) -> ScannedProduct.ProductCategory {
        let categories = (product.categories ?? "").lowercased()
        let productName = (product.productName ?? "").lowercased()

        if categories.contains("energy drink") || productName.contains("energy") {
            return .energyDrink
        } else if categories.contains("coffee") || productName.contains("coffee") {
            return .coffee
        } else if categories.contains("tea") || productName.contains("tea") {
            return .tea
        } else if categories.contains("supplement") || productName.contains("supplement") {
            return .supplement
        } else if categories.contains("soda") || categories.contains("soft drink") || productName.contains("soda") {
            return .soda
        }

        return .other
    }

    /// Extract notable ingredients from product data
    private func extractIngredients(from product: OpenFoodFactsProduct) -> [String] {
        var ingredients: [String] = []

        if let caffeine = extractCaffeineAmount(from: product) {
            ingredients.append("Caffeine \(Int(caffeine))mg")
        }

        // Add other notable ingredients if present in text
        if let text = product.ingredientsText?.lowercased() {
            if text.contains("taurine") {
                ingredients.append("Taurine")
            }
            if text.contains("guarana") {
                ingredients.append("Guarana")
            }
            if text.contains("l-theanine") || text.contains("theanine") {
                ingredients.append("L-Theanine")
            }
            if text.contains("ginseng") {
                ingredients.append("Ginseng")
            }
            if text.contains("b-vitamin") || text.contains("vitamin b") {
                ingredients.append("B-Vitamins")
            }
        }

        return ingredients
    }
}

// MARK: - API Models

/// OpenFoodFacts API response wrapper
struct OpenFoodFactsResponse: Codable {
    let status: Int
    let product: OpenFoodFactsProduct?
}

/// OpenFoodFacts product data
struct OpenFoodFactsProduct: Codable {
    let productName: String?
    let brands: String?
    let quantity: String?
    let servingSize: String?
    let servingQuantity: Double?
    let categories: String?
    let ingredientsText: String?
    let imageFrontURL: String?
    let nutriments: Nutriments?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case quantity
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case categories
        case ingredientsText = "ingredients_text"
        case imageFrontURL = "image_front_url"
        case nutriments
    }
}

/// Nutritional information from OpenFoodFacts
struct Nutriments: Codable {
    let caffeine_100g: Double?
    let caffeine_serving: Double?
    let caffeine_unit: String?
    let caffeine_value: Double?

    enum CodingKeys: String, CodingKey {
        case caffeine_100g = "caffeine_100g"
        case caffeine_serving = "caffeine_serving"
        case caffeine_unit = "caffeine_unit"
        case caffeine_value = "caffeine_value"
    }
}

// MARK: - Errors

/// Product lookup errors
enum ProductError: Error, LocalizedError {
    case invalidBarcode
    case networkError
    case productNotFound
    case parsingError

    var errorDescription: String? {
        switch self {
        case .invalidBarcode:
            return "Invalid barcode format"
        case .networkError:
            return "Network error occurred"
        case .productNotFound:
            return "Product not found in database"
        case .parsingError:
            return "Failed to parse product data"
        }
    }
}
