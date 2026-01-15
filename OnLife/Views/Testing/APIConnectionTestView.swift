import SwiftUI

/// Comprehensive API testing interface to verify OpenFoodFacts connection
struct APIConnectionTestView: View {
    @State private var testResults: [APITestResult] = []
    @State private var isRunningTests = false
    @State private var selectedBarcode = ""
    @State private var customTestResult: APITestResult?

    // Test barcodes - some in local DB, some only in API
    let testBarcodes: [(name: String, barcode: String, expectedSource: String)] = [
        ("Monster Ultra (Local)", "070847811800", "Local"),
        ("Red Bull (Local)", "9002490100070", "Local"),
        ("Coca-Cola Classic (API)", "0049000042559", "API"),
        ("Pepsi (API)", "0012000001765", "API"),
        ("Random (Unknown)", "9999999999999", "Not Found")
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Header
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "network")
                            .font(.system(size: 60))
                            .foregroundColor(AppColors.healthy)

                        Text("API Connection Test")
                            .font(AppFont.heading2())
                            .foregroundColor(AppColors.textPrimary)

                        Text("Verify OpenFoodFacts API integration")
                            .font(AppFont.body())
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top)

                    // Quick Tests Section
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Quick Tests")
                            .font(AppFont.heading3())
                            .foregroundColor(AppColors.textPrimary)

                        Button(action: runAllTests) {
                            HStack {
                                if isRunningTests {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "play.circle.fill")
                                }
                                Text(isRunningTests ? "Running Tests..." : "Run All Tests")
                            }
                            .font(AppFont.button())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.healthy)
                            .foregroundColor(.white)
                            .cornerRadius(CornerRadius.medium)
                        }
                        .disabled(isRunningTests)

                        ForEach(testBarcodes, id: \.barcode) { test in
                            Button(action: { testSingleBarcode(test.barcode, name: test.name) }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(test.name)
                                            .font(AppFont.body())
                                            .fontWeight(.semibold)
                                        Text(test.barcode)
                                            .font(AppFont.bodySmall())
                                        Text("Expected: \(test.expectedSource)")
                                            .font(AppFont.bodySmall())
                                            .foregroundColor(AppColors.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "arrow.right.circle")
                                }
                                .foregroundColor(AppColors.textPrimary)
                                .padding()
                                .background(AppColors.lightSoil)
                                .cornerRadius(CornerRadius.medium)
                            }
                            .disabled(isRunningTests)
                        }
                    }
                    .padding(.horizontal)

                    // Custom Barcode Test
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Custom Barcode Test")
                            .font(AppFont.heading3())
                            .foregroundColor(AppColors.textPrimary)

                        HStack {
                            TextField("Enter barcode", text: $selectedBarcode)
                                .font(AppFont.body())
                                .keyboardType(.numberPad)
                                .padding()
                                .background(AppColors.lightSoil)
                                .cornerRadius(CornerRadius.small)

                            Button(action: { testSingleBarcode(selectedBarcode, name: "Custom") }) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(AppColors.healthy)
                            }
                            .disabled(selectedBarcode.isEmpty || isRunningTests)
                        }
                    }
                    .padding(.horizontal)

                    // Results Section
                    if !testResults.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            HStack {
                                Text("Test Results")
                                    .font(AppFont.heading3())
                                    .foregroundColor(AppColors.textPrimary)

                                Spacer()

                                Button("Clear") {
                                    testResults.removeAll()
                                }
                                .font(AppFont.bodySmall())
                                .foregroundColor(.red)
                            }

                            ForEach(testResults) { result in
                                TestResultCard(result: result)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Custom Test Result (Detailed View)
                    if let result = customTestResult {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("Detailed Result")
                                .font(AppFont.heading3())
                                .foregroundColor(AppColors.textPrimary)

                            DetailedResultCard(result: result)
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 50)
                }
            }
            .background(AppColors.richSoil)
            .navigationTitle("API Test")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Test Functions

    private func runAllTests() {
        isRunningTests = true
        testResults.removeAll()

        Task {
            for test in testBarcodes {
                await performTest(barcode: test.barcode, name: test.name, expectedSource: test.expectedSource)
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay between tests
            }

            await MainActor.run {
                isRunningTests = false
            }
        }
    }

    private func testSingleBarcode(_ barcode: String, name: String) {
        guard !barcode.isEmpty else { return }

        isRunningTests = true

        Task {
            await performTest(barcode: barcode, name: name, expectedSource: "Unknown")

            await MainActor.run {
                isRunningTests = false
            }
        }
    }

    private func performTest(barcode: String, name: String, expectedSource: String) async {
        let startTime = Date()

        // First, check local database
        let localProduct = ProductDatabaseManager.shared.findProduct(barcode: barcode)
        let localTime = Date().timeIntervalSince(startTime)

        if localProduct != nil {
            let result = APITestResult(
                testName: name,
                barcode: barcode,
                source: .localDatabase,
                success: true,
                responseTime: localTime,
                productName: localProduct?.displayName,
                caffeineAmount: localProduct?.caffeineAmount,
                errorMessage: nil,
                timestamp: Date(),
                rawResponse: "Found in local database"
            )

            await MainActor.run {
                testResults.append(result)
                customTestResult = result
            }
            return
        }

        // Try API
        let apiStartTime = Date()

        do {
            let product = try await OpenFoodFactsService.shared.fetchProduct(barcode: barcode)
            let apiTime = Date().timeIntervalSince(apiStartTime)

            if let product = product {
                let result = APITestResult(
                    testName: name,
                    barcode: barcode,
                    source: .api,
                    success: true,
                    responseTime: apiTime,
                    productName: product.displayName,
                    caffeineAmount: product.caffeineAmount,
                    errorMessage: nil,
                    timestamp: Date(),
                    rawResponse: "✅ API returned product successfully"
                )

                await MainActor.run {
                    testResults.append(result)
                    customTestResult = result
                }
            } else {
                // API returned, but product not found
                let apiTime = Date().timeIntervalSince(apiStartTime)
                let result = APITestResult(
                    testName: name,
                    barcode: barcode,
                    source: .api,
                    success: false,
                    responseTime: apiTime,
                    productName: nil,
                    caffeineAmount: nil,
                    errorMessage: "Product not found in OpenFoodFacts database",
                    timestamp: Date(),
                    rawResponse: "API responded but product does not exist"
                )

                await MainActor.run {
                    testResults.append(result)
                    customTestResult = result
                }
            }
        } catch {
            let apiTime = Date().timeIntervalSince(apiStartTime)
            let result = APITestResult(
                testName: name,
                barcode: barcode,
                source: .api,
                success: false,
                responseTime: apiTime,
                productName: nil,
                caffeineAmount: nil,
                errorMessage: error.localizedDescription,
                timestamp: Date(),
                rawResponse: "❌ ERROR: \(error.localizedDescription)"
            )

            await MainActor.run {
                testResults.append(result)
                customTestResult = result
            }
        }
    }
}

// MARK: - Test Result Model

struct APITestResult: Identifiable {
    let id = UUID()
    let testName: String
    let barcode: String
    let source: TestSource
    let success: Bool
    let responseTime: TimeInterval
    let productName: String?
    let caffeineAmount: Double?
    let errorMessage: String?
    let timestamp: Date
    let rawResponse: String

    enum TestSource {
        case localDatabase
        case api
    }

    var sourceEmoji: String {
        switch source {
        case .localDatabase: return "💾"
        case .api: return "🌐"
        }
    }

    var statusEmoji: String {
        success ? "✅" : "❌"
    }

    var responseTimeFormatted: String {
        if responseTime < 0.01 {
            return "<10ms"
        } else if responseTime < 1 {
            return String(format: "%.0fms", responseTime * 1000)
        } else {
            return String(format: "%.2fs", responseTime)
        }
    }
}

// MARK: - Test Result Card

struct TestResultCard: View {
    let result: APITestResult

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("\(result.statusEmoji) \(result.testName)")
                    .font(AppFont.body())
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text("\(result.sourceEmoji) \(result.responseTimeFormatted)")
                    .font(AppFont.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
            }

            Text("Barcode: \(result.barcode)")
                .font(AppFont.bodySmall())
                .foregroundColor(AppColors.textSecondary)

            if result.success {
                if let name = result.productName {
                    Text("Product: \(name)")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textPrimary)
                }

                if let caffeine = result.caffeineAmount {
                    Text("Caffeine: \(Int(caffeine))mg")
                        .font(AppFont.body())
                        .foregroundColor(.brown)
                }
            } else {
                if let error = result.errorMessage {
                    Text("Error: \(error)")
                        .font(AppFont.bodySmall())
                        .foregroundColor(.red)
                }
            }

            Text(result.timestamp, style: .time)
                .font(AppFont.bodySmall())
                .foregroundColor(AppColors.textSecondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(result.success ? AppColors.lightSoil : Color.red.opacity(0.1))
        )
    }
}

// MARK: - Detailed Result Card

struct DetailedResultCard: View {
    let result: APITestResult

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Status
            HStack {
                Text(result.statusEmoji)
                    .font(.system(size: 40))

                VStack(alignment: .leading) {
                    Text(result.success ? "SUCCESS" : "FAILED")
                        .font(AppFont.heading3())
                        .foregroundColor(result.success ? .green : .red)

                    Text(result.testName)
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Divider()
                .background(AppColors.darkSoil)

            // Details
            VStack(alignment: .leading, spacing: Spacing.sm) {
                DetailRow(label: "Barcode", value: result.barcode)
                DetailRow(label: "Source", value: "\(result.sourceEmoji) \(result.source == .localDatabase ? "Local Database" : "OpenFoodFacts API")")
                DetailRow(label: "Response Time", value: result.responseTimeFormatted)
                DetailRow(label: "Timestamp", value: result.timestamp.formatted(date: .omitted, time: .standard))

                if let name = result.productName {
                    DetailRow(label: "Product Name", value: name)
                }

                if let caffeine = result.caffeineAmount {
                    DetailRow(label: "Caffeine", value: "\(Int(caffeine))mg")
                }

                if let error = result.errorMessage {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Error:")
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                        Text(error)
                            .font(AppFont.bodySmall())
                            .foregroundColor(.red)
                    }
                }
            }

            Divider()
                .background(AppColors.darkSoil)

            // Raw Response
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Raw Response:")
                    .font(AppFont.body())
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)

                Text(result.rawResponse)
                    .font(AppFont.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.darkSoil)
                    .cornerRadius(CornerRadius.small)
            }
        }
        .padding()
        .background(AppColors.lightSoil)
        .cornerRadius(CornerRadius.medium)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text("\(label):")
                .font(AppFont.body())
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(AppFont.body())
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

// MARK: - Preview

#Preview {
    APIConnectionTestView()
}
