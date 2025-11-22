import Foundation

// MARK: - Scanned Product Model

/// Represents a product scanned via barcode with nutritional information
struct ScannedProduct: Codable, Identifiable {
    // Use barcode as ID for uniqueness
    var id: String { barcode }

    let barcode: String
    let brand: String?
    let productName: String
    let caffeineAmount: Double?      // mg
    let lTheanineAmount: Double?     // mg
    let volumeAmount: Double?        // ml
    let servingSize: String?
    let category: ProductCategory
    let ingredients: [String]
    let imageURL: String?
    let source: DataSource
    var lastUpdated: Date

    // Custom coding keys to exclude computed property
    enum CodingKeys: String, CodingKey {
        case barcode, brand, productName, caffeineAmount
        case lTheanineAmount, volumeAmount, servingSize
        case category, ingredients, imageURL, source, lastUpdated
    }

    enum ProductCategory: String, Codable, CaseIterable {
        case energyDrink = "Energy Drink"
        case coffee = "Coffee"
        case tea = "Tea"
        case supplement = "Supplement"
        case preworkout = "Pre-Workout"
        case soda = "Soda"
        case other = "Other"
    }

    enum DataSource: String, Codable {
        case localDatabase = "Local Database"
        case openFoodFacts = "OpenFoodFacts"
        case userContributed = "User Contributed"
        case manual = "Manual Entry"
    }

    // MARK: - Conversion Methods

    /// Convert product to substance logs for tracking
    /// - Returns: Array of SubstanceLog entries (caffeine, L-theanine)
    func toSubstanceLogs() -> [SubstanceLog] {
        var logs: [SubstanceLog] = []

        // Add caffeine if present
        if let caffeine = caffeineAmount, caffeine > 0 {
            logs.append(SubstanceLog(
                timestamp: Date(),
                substanceType: .caffeine,
                amount: caffeine,
                unit: .mg,
                source: "\(brand ?? "") \(productName)"
            ))
        }

        // Add L-theanine if present
        if let theanine = lTheanineAmount, theanine > 0 {
            logs.append(SubstanceLog(
                timestamp: Date(),
                substanceType: .lTheanine,
                amount: theanine,
                unit: .mg,
                source: "\(brand ?? "") \(productName)"
            ))
        }

        return logs
    }

    // MARK: - Display Properties

    /// Full display name including brand and product name
    var displayName: String {
        if let brand = brand, !brand.isEmpty {
            return "\(brand) \(productName)"
        }
        return productName
    }
}
