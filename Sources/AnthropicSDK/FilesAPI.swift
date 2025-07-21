import Foundation

/// Resource for managing file operations with the Anthropic API
///
/// The Files API allows you to upload documents, images, and other files that Claude can
/// analyze and reference in conversations. Files are processed asynchronously and can be
/// used across multiple conversations.
///
/// ## Basic Usage Example
///
/// ```swift
/// // Upload a document for analysis
/// let documentData = try Data(contentsOf: documentURL)
/// let uploadRequest = FileUploadRequest(
///     file: documentData,
///     filename: "research_paper.pdf",
///     contentType: "application/pdf",
///     purpose: .document
/// )
///
/// let uploadResponse = try await client.files.upload(uploadRequest)
/// print("Uploaded file: \(uploadResponse.file.id)")
///
/// // Use the file in a conversation
/// let response = try await client.messages.create(
///     model: .claude3_5Sonnet,
///     messages: [.user("Please analyze this document and provide key insights")],
///     maxTokens: 1000,
///     files: [FileReference(fileId: uploadResponse.file.id)]
/// )
///
/// // List all uploaded files
/// let filesList = try await client.files.list(purpose: .document)
/// print("Total files: \(filesList.data.count)")
///
/// // Download file content when needed
/// let content = try await client.files.downloadContent(uploadResponse.file.id)
/// ```
///
/// ## Vision Analysis Example
///
/// ```swift
/// // Upload an image for vision analysis
/// let imageData = try Data(contentsOf: imageURL)
/// let imageRequest = FileUploadRequest(
///     file: imageData,
///     filename: "chart.png",
///     contentType: "image/png",
///     purpose: .vision
/// )
///
/// let imageUpload = try await client.files.upload(imageRequest)
///
/// // Analyze the image
/// let analysis = try await client.messages.create(
///     model: .claude3_5Sonnet,
///     messages: [.user("What trends do you see in this chart?")],
///     maxTokens: 500,
///     files: [FileReference(fileId: imageUpload.file.id)]
/// )
/// ```
public actor FilesResource {
    private let httpClient: HTTPClient
    private let apiKey: String
    private let baseURL: URL
    
    /// Creates a new files resource
    /// - Parameters:
    ///   - httpClient: The HTTP client to use for requests
    ///   - apiKey: The API key for authentication
    ///   - baseURL: The base URL for the API
    init(httpClient: HTTPClient, apiKey: String, baseURL: URL) {
        self.httpClient = httpClient
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
    
    /// Uploads a file to Anthropic's servers
    /// - Parameter request: The file upload request containing file data and metadata
    /// - Returns: Upload response with file information and processing status
    /// - Throws: AnthropicError for validation errors, HTTPError for network issues, or decoding errors
    public func upload(_ request: FileUploadRequest) async throws -> FileUploadResponse {
        // Validate the upload request
        try request.validate()
        
        let url = baseURL.appendingPathComponent("v1/files")
        
        // Build multipart form data
        var formData = MultipartFormData()
        formData.addFileField(
            name: "file",
            filename: request.filename,
            contentType: request.contentType,
            fileData: request.file
        )
        formData.addTextField(name: "purpose", value: request.purpose.rawValue)
        
        let httpRequest = HTTPRequest(
            url: url,
            method: .POST,
            headers: [
                "x-api-key": apiKey,
                "Content-Type": formData.contentType,
                "anthropic-version": "2023-06-01",
                "User-Agent": "AnthropicSDK/1.0.0"
            ],
            body: formData.httpBody
        )
        
        do {
            return try await httpClient.send(httpRequest)
        } catch let httpError as HTTPError {
            // Map specific HTTP status codes to more meaningful errors
            switch httpError {
            case .httpError(let statusCode):
                switch statusCode {
                case 400:
                    throw AnthropicError.invalidParameter("Invalid file upload parameters")
                case 401:
                    throw AnthropicError.invalidAPIKey
                case 413:
                    throw AnthropicError.invalidParameter("File too large")
                case 415:
                    throw AnthropicError.invalidParameter("Unsupported file type")
                case 429:
                    throw AnthropicError.invalidParameter("Rate limit exceeded")
                case 500...599:
                    throw AnthropicError.invalidParameter("Server error occurred")
                default:
                    throw httpError
                }
            default:
                throw httpError
            }
        }
    }
    
    /// Convenience method to upload a file with basic parameters
    /// - Parameters:
    ///   - fileData: The file data to upload
    ///   - filename: The original filename
    ///   - contentType: MIME type of the file
    ///   - purpose: Purpose for the file upload
    /// - Returns: Upload response with file information and processing status
    /// - Throws: AnthropicError for validation errors, HTTPError for network issues, or decoding errors
    public func upload(fileData: Data, filename: String, contentType: String, purpose: FilePurpose) async throws -> FileUploadResponse {
        let request = FileUploadRequest(file: fileData, filename: filename, contentType: contentType, purpose: purpose)
        return try await upload(request)
    }
    
    /// Retrieves information about a specific file
    /// - Parameter fileId: The unique identifier of the file
    /// - Returns: File information including metadata and status
    /// - Throws: HTTPError for network issues or decoding errors
    public func retrieve(_ fileId: String) async throws -> AnthropicFile {
        let url = baseURL.appendingPathComponent("v1/files/\(fileId)")
        
        let httpRequest = HTTPRequest(
            url: url,
            method: .GET,
            headers: [
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
                "User-Agent": "AnthropicSDK/1.0.0"
            ],
            body: nil
        )
        
        return try await httpClient.send(httpRequest)
    }
    
    /// Lists all files for the account
    /// - Parameters:
    ///   - purpose: Filter files by purpose (optional)
    ///   - beforeId: List files before this ID (for pagination)
    ///   - afterId: List files after this ID (for pagination)
    ///   - limit: Maximum number of files to return (1-100, default 20)
    /// - Returns: Paginated list of files
    /// - Throws: HTTPError for network issues or decoding errors
    public func list(purpose: FilePurpose? = nil, beforeId: String? = nil, afterId: String? = nil, limit: Int = 20) async throws -> FileListResponse {
        var urlComponents = URLComponents(string: baseURL.appendingPathComponent("v1/files").absoluteString)!
        var queryItems: [URLQueryItem] = []
        
        if let purpose = purpose {
            queryItems.append(URLQueryItem(name: "purpose", value: purpose.rawValue))
        }
        if let beforeId = beforeId {
            queryItems.append(URLQueryItem(name: "before_id", value: beforeId))
        }
        if let afterId = afterId {
            queryItems.append(URLQueryItem(name: "after_id", value: afterId))
        }
        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        
        urlComponents.queryItems = queryItems
        
        let httpRequest = HTTPRequest(
            url: urlComponents.url!,
            method: .GET,
            headers: [
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
                "User-Agent": "AnthropicSDK/1.0.0"
            ],
            body: nil
        )
        
        return try await httpClient.send(httpRequest)
    }
    
    /// Deletes a file from Anthropic's servers
    /// - Parameter fileId: The unique identifier of the file to delete
    /// - Returns: Deletion response confirming the operation
    /// - Throws: HTTPError for network issues or decoding errors
    public func delete(_ fileId: String) async throws -> FileDeletionResponse {
        let url = baseURL.appendingPathComponent("v1/files/\(fileId)")
        
        let httpRequest = HTTPRequest(
            url: url,
            method: .DELETE,
            headers: [
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
                "User-Agent": "AnthropicSDK/1.0.0"
            ],
            body: nil
        )
        
        do {
            return try await httpClient.send(httpRequest)
        } catch let httpError as HTTPError {
            // Map specific HTTP status codes to more meaningful errors
            switch httpError {
            case .httpError(let statusCode):
                switch statusCode {
                case 404:
                    throw AnthropicError.invalidParameter("File not found")
                case 401:
                    throw AnthropicError.invalidAPIKey
                case 403:
                    throw AnthropicError.invalidParameter("File cannot be deleted")
                case 429:
                    throw AnthropicError.invalidParameter("Rate limit exceeded")
                case 500...599:
                    throw AnthropicError.invalidParameter("Server error occurred")
                default:
                    throw httpError
                }
            default:
                throw httpError
            }
        }
    }
    
    /// Downloads the content of a file
    /// - Parameter fileId: The unique identifier of the file to download
    /// - Returns: The file content as Data
    /// - Throws: HTTPError for network issues or if file cannot be downloaded
    public func downloadContent(_ fileId: String) async throws -> Data {
        let url = baseURL.appendingPathComponent("v1/files/\(fileId)/content")
        
        let httpRequest = HTTPRequest(
            url: url,
            method: .GET,
            headers: [
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
                "User-Agent": "AnthropicSDK/1.0.0"
            ],
            body: nil
        )
        
        do {
            // For file downloads, we expect raw data, not JSON
            let response = try await httpClient.sendRaw(httpRequest)
            return response.data
        } catch let httpError as HTTPError {
            // Map specific HTTP status codes to more meaningful errors
            switch httpError {
            case .httpError(let statusCode):
                switch statusCode {
                case 404:
                    throw AnthropicError.invalidParameter("File not found or content not available")
                case 401:
                    throw AnthropicError.invalidAPIKey
                case 403:
                    throw AnthropicError.invalidParameter("File content cannot be accessed")
                case 410:
                    throw AnthropicError.invalidParameter("File has expired and content is no longer available")
                case 429:
                    throw AnthropicError.invalidParameter("Rate limit exceeded")
                case 500...599:
                    throw AnthropicError.invalidParameter("Server error occurred")
                default:
                    throw httpError
                }
            default:
                throw httpError
            }
        }
    }
    
    /// Creates a file reference for use in message content
    /// - Parameters:
    ///   - fileId: The file ID to reference
    ///   - usage: Optional description of how the file should be used
    /// - Returns: File reference that can be included in message content
    public func createReference(fileId: String, usage: String? = nil) -> FileReference {
        return FileReference(fileId: fileId, usage: usage)
    }
}