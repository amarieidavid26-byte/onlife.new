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
        // Check nutriments for caffeine (in mg per 100g or 100ml)
        if let caffeinePer100 = product.nutriments?.caffeine_100g {
            // Convert to total amount if we have serving size
            if let servingQuantity = product.servingQuantity {
                return (caffeinePer100 / 100.0) * servingQuantity
            }
            return caffeinePer100
        }

        // Check for caffeine per serving
        if let caffeineServing = product.nutriments?.caffeine_serving {
            return caffeineServing
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
                            return amount
                        }
                    }
                }
            }
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

    enum CodingKeys: String, CodingKey {
        case caffeine_100g = "caffeine_100g"
        case caffeine_serving = "caffeine_serving"
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
