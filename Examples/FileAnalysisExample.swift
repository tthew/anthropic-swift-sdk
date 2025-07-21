import Foundation
import AnthropicSDK

/// Comprehensive file analysis example
///
/// This example demonstrates:
/// - Uploading different file types (documents, images, data files)
/// - File management operations (list, retrieve, delete)
/// - Using files in Claude conversations
/// - Error handling for file operations
/// - File validation and processing

@main 
struct FileAnalysisExample {
    static func main() async {
        do {
            let client = try AnthropicClient()
            
            print("📁 Anthropic Swift SDK - File Analysis Example")
            print("=" * 60)
            
            await demonstrateDocumentAnalysis(client)
            await demonstrateImageAnalysis(client)
            await demonstrateFileManagement(client)
            
        } catch {
            print("❌ Failed to initialize client: \(error)")
        }
    }
    
    /// Demonstrates uploading and analyzing documents
    private static func demonstrateDocumentAnalysis(_ client: AnthropicClient) async {
        print("\n📄 Document Analysis Example")
        print("-" * 40)
        
        // Create a sample document content
        let sampleDocument = createSampleDocument()
        
        do {
            // Upload the document
            let uploadRequest = FileUploadRequest(
                file: sampleDocument,
                filename: "sample_report.txt",
                contentType: "text/plain",
                purpose: .document
            )
            
            print("📤 Uploading document...")
            let uploadResponse = try await client.files.upload(uploadRequest)
            let file = uploadResponse.file
            
            print("✅ Document uploaded successfully:")
            print("   File ID: \(file.id)")
            print("   Filename: \(file.filename)")
            print("   Size: \(file.formattedSize)")
            print("   Upload Status: \(uploadResponse.uploadStatus)")
            
            // Wait for processing if needed
            if uploadResponse.isProcessing {
                print("⏳ Waiting for file processing...")
                try await Task.sleep(nanoseconds: 3_000_000_000)
            }
            
            // Analyze the document using Claude
            print("\n🔍 Analyzing document with Claude...")
            // Note: In the actual Anthropic API, files would be referenced through the content
            // For this example, we'll simulate document analysis
            let analysisResponse = try await client.messages.create(
                model: .claude3_5Sonnet,
                messages: [.user("Please analyze this document content and provide a summary of its key points, main themes, and any recommendations mentioned. [File ID: \(file.id)]")],
                maxTokens: 500
            )
            
            if let textContent = analysisResponse.content.first,
               case .text(let analysis) = textContent {
                print("📊 Analysis Result:")
                print(analysis)
            }
            
            print("\n💰 Token Usage:")
            print("   Input: \(analysisResponse.usage.inputTokens)")
            print("   Output: \(analysisResponse.usage.outputTokens)")
            
            // Clean up: delete the uploaded file
            let deleteResponse = try await client.files.delete(file.id)
            if deleteResponse.deleted {
                print("🗑️ Document cleaned up successfully")
            }
            
        } catch {
            print("❌ Document analysis error: \(error)")
        }
    }
    
    /// Demonstrates uploading and analyzing images
    private static func demonstrateImageAnalysis(_ client: AnthropicClient) async {
        print("\n🖼️ Image Analysis Example")
        print("-" * 40)
        
        // Create a sample image (in practice, you'd load from file)
        let sampleImageData = createSampleImageData()
        
        do {
            // Upload the image
            let uploadRequest = FileUploadRequest(
                file: sampleImageData,
                filename: "chart_analysis.png",
                contentType: "image/png",
                purpose: .vision
            )
            
            print("📤 Uploading image...")
            let uploadResponse = try await client.files.upload(uploadRequest)
            let file = uploadResponse.file
            
            print("✅ Image uploaded successfully:")
            print("   File ID: \(file.id)")
            print("   Filename: \(file.filename)")
            print("   Size: \(file.formattedSize)")
            print("   Purpose: \(file.purpose)")
            
            // Analyze the image using Claude's vision capabilities
            print("\n👁️ Analyzing image with Claude...")
            // Note: For vision analysis, images would typically be included as base64 content
            // For this example, we'll simulate image analysis with file reference
            let visionResponse = try await client.messages.create(
                model: .claude3_5Sonnet, // Ensure this model supports vision
                messages: [.user("Please analyze this image. Describe what you see, identify any charts or data visualizations, and explain the key insights or trends shown. [Image File ID: \(file.id)]")],
                maxTokens: 400
            )
            
            if let textContent = visionResponse.content.first,
               case .text(let analysis) = textContent {
                print("👁️ Vision Analysis:")
                print(analysis)
            }
            
            // Follow-up question about the image
            print("\n❓ Follow-up analysis...")
            let followUpResponse = try await client.messages.create(
                model: .claude3_5Sonnet,
                messages: [
                    .user("Please analyze this image. Describe what you see, identify any charts or data visualizations, and explain the key insights or trends shown. [Image File ID: \(file.id)]"),
                    .assistant("I can see the image you've shared. Based on my analysis..."), // Simplified for example
                    .user("Based on your analysis, what recommendations would you make for improving the metrics shown?")
                ],
                maxTokens: 300
            )
            
            if let textContent = followUpResponse.content.first,
               case .text(let recommendations) = textContent {
                print("💡 Recommendations:")
                print(recommendations)
            }
            
            // Clean up
            let deleteResponse = try await client.files.delete(file.id)
            if deleteResponse.deleted {
                print("🗑️ Image cleaned up successfully")
            }
            
        } catch {
            print("❌ Image analysis error: \(error)")
        }
    }
    
    /// Demonstrates comprehensive file management operations
    private static func demonstrateFileManagement(_ client: AnthropicClient) async {
        print("\n🗂️ File Management Example")
        print("-" * 40)
        
        // Upload multiple files for demonstration
        let files = [
            ("data1.json", "application/json", FilePurpose.document, createSampleJSONData()),
            ("report.txt", "text/plain", FilePurpose.document, createSampleDocument()),
            ("chart.csv", "text/csv", FilePurpose.document, createSampleCSVData())
        ]
        
        var uploadedFiles: [AnthropicFile] = []
        
        do {
            // Upload all files
            print("📤 Uploading \(files.count) files...")
            for (filename, contentType, purpose, data) in files {
                let request = FileUploadRequest(
                    file: data,
                    filename: filename,
                    contentType: contentType,
                    purpose: purpose
                )
                
                let response = try await client.files.upload(request)
                uploadedFiles.append(response.file)
                print("   ✅ \(filename): \(response.file.formattedSize)")
            }
            
            // List all files
            print("\n📋 Listing all files...")
            let filesList = try await client.files.list()
            print("   Total files in account: \(filesList.data.count)")
            print("   Files on this page: \(filesList.data.count)")
            print("   Has more pages: \(filesList.hasMore)")
            
            // Filter files by purpose
            let documentFiles = filesList.files(withPurpose: .document)
            print("   Document files: \(documentFiles.count)")
            
            // Show file details
            print("\n📁 File Details:")
            for file in uploadedFiles.prefix(3) {
                print("   📄 \(file.filename):")
                print("      ID: \(file.id)")
                print("      Size: \(file.formattedSize)")
                print("      Purpose: \(file.purpose)")
                print("      Created: \(formatDate(file.createdAt))")
                print("      Expires: \(file.expiresAt.map(formatDate) ?? "Never")")
                
                // Retrieve individual file info
                let retrievedFile = try await client.files.retrieve(file.id)
                print("      Status: Retrieved successfully")
                
                // Download content for text files
                if file.contentType.hasPrefix("text/") {
                    let content = try await client.files.downloadContent(file.id)
                    let preview = String(data: content.prefix(100), encoding: .utf8) ?? "Unable to preview"
                    print("      Content preview: \(preview)...")
                }
            }
            
            // Batch operations example
            print("\n🚀 Batch File Analysis...")
            let batchRequests = uploadedFiles.map { file in
                BatchRequest(
                    customId: "analyze_\(file.filename)",
                    method: .POST,
                    url: "/v1/messages",
                    body: CreateMessageRequest(
                        model: .claude3_5Sonnet,
                        messages: [.user("Provide a brief summary of this file's content and its key information. [File ID: \(file.id)]")],
                        maxTokens: 200
                    )
                )
            }
            
            if !batchRequests.isEmpty {
                let batch = try await client.batches.create(
                    CreateBatchRequest(requests: batchRequests)
                )
                print("   Batch created: \(batch.id)")
                print("   Processing \(batch.requestCounts.total) file analysis requests...")
            }
            
            // Clean up all uploaded files
            print("\n🗑️ Cleaning up uploaded files...")
            for file in uploadedFiles {
                let deleteResponse = try await client.files.delete(file.id)
                if deleteResponse.deleted {
                    print("   ✅ Deleted: \(file.filename)")
                } else {
                    print("   ❌ Failed to delete: \(file.filename)")
                }
            }
            
        } catch {
            print("❌ File management error: \(error)")
            
            // Attempt cleanup even on error
            print("🧹 Attempting cleanup...")
            for file in uploadedFiles {
                do {
                    let _ = try await client.files.delete(file.id)
                    print("   ✅ Cleaned up: \(file.filename)")
                } catch {
                    print("   ❌ Cleanup failed for: \(file.filename)")
                }
            }
        }
    }
    
    // MARK: - Helper Functions for Sample Data
    
    private static func createSampleDocument() -> Data {
        let content = """
        QUARTERLY BUSINESS REPORT - Q3 2024
        =====================================
        
        EXECUTIVE SUMMARY
        -----------------
        This quarter has shown significant growth across all key metrics, with revenue increasing by 23% compared to Q2 2024.
        
        KEY ACHIEVEMENTS
        ----------------
        • Revenue Growth: $2.4M (23% increase)
        • Customer Acquisition: 1,200 new customers
        • Product Launches: Successfully launched 3 new features
        • Team Expansion: Hired 15 new employees
        
        CHALLENGES & SOLUTIONS
        ----------------------
        Challenge: Supply chain disruptions in August
        Solution: Diversified supplier base and increased inventory buffers
        
        Challenge: Increased customer support volume
        Solution: Implemented AI chatbot reducing response time by 40%
        
        RECOMMENDATIONS FOR Q4
        ----------------------
        1. Invest in additional marketing channels to sustain growth
        2. Expand customer success team to improve retention
        3. Focus on product optimization based on user feedback
        4. Prepare for holiday season demand spike
        
        FINANCIAL METRICS
        -----------------
        • Revenue: $2,400,000
        • Gross Margin: 65%
        • Operating Expenses: $1,200,000
        • Net Profit: $360,000
        • Cash Flow: +$180,000
        
        This report demonstrates strong business fundamentals with promising growth trajectory.
        """
        
        return content.data(using: .utf8) ?? Data()
    }
    
    private static func createSampleJSONData() -> Data {
        let jsonData = [
            "analytics": [
                "monthly_active_users": 45000,
                "conversion_rate": 3.2,
                "average_session_duration": 480,
                "bounce_rate": 0.24
            ],
            "performance": [
                "api_response_time": 120,
                "uptime_percentage": 99.9,
                "error_rate": 0.01
            ],
            "growth": [
                "month_over_month": 12.5,
                "year_over_year": 67.3
            ]
        ]
        
        return try! JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)
    }
    
    private static func createSampleCSVData() -> Data {
        let csvContent = """
        Month,Revenue,Customers,Churn Rate
        January,180000,850,2.1
        February,195000,920,1.8
        March,210000,1050,1.9
        April,225000,1180,2.0
        May,240000,1320,1.7
        June,255000,1450,1.6
        July,270000,1580,1.8
        August,285000,1720,1.5
        September,300000,1860,1.4
        """
        
        return csvContent.data(using: .utf8) ?? Data()
    }
    
    private static func createSampleImageData() -> Data {
        // In a real application, you would load actual image data
        // For this example, we'll create minimal PNG data
        // This is just placeholder data - use actual image files in production
        let pngHeader = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        return pngHeader + Data(repeating: 0, count: 1000) // Minimal PNG-like data
    }
    
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Helper extensions
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}