import Foundation

/// Purpose for which a file is uploaded
public enum FilePurpose: String, Codable, CaseIterable, Equatable {
    /// Files for vision/image analysis
    case vision = "vision"
    /// Document files for processing
    case document = "document"
    /// Files for batch operations
    case batch = "batch"
}

/// Status of file upload processing
public enum FileUploadStatus: String, Codable, CaseIterable, Equatable {
    /// File is being processed after upload
    case processing = "processing"
    /// File upload and processing completed successfully
    case completed = "completed"
    /// File upload or processing failed
    case failed = "failed"
    
    /// Whether the upload is still in progress
    public var isActive: Bool {
        return self == .processing
    }
    
    /// Whether the upload completed successfully
    public var isSuccessful: Bool {
        return self == .completed
    }
}

/// Represents a file stored in Anthropic's system
public struct AnthropicFile: Codable, Equatable {
    /// Unique identifier for the file
    public let id: String
    /// Object type (always "file")
    public let type: String
    /// Original filename as provided during upload
    public let filename: String
    /// File size in bytes
    public let size: Int
    /// MIME type of the file
    public let contentType: String
    /// Purpose for which the file was uploaded
    public let purpose: FilePurpose
    /// When the file was created/uploaded
    public let createdAt: Date
    /// When the file expires and will be deleted (if applicable)
    public let expiresAt: Date?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case filename
        case size
        case contentType = "content_type"
        case purpose
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
    
    public init(id: String, type: String, filename: String, size: Int, contentType: String,
                purpose: FilePurpose, createdAt: Date, expiresAt: Date?) {
        self.id = id
        self.type = type
        self.filename = filename
        self.size = size
        self.contentType = contentType
        self.purpose = purpose
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
    
    /// Whether the file has an expiration date
    public var hasExpiration: Bool {
        return expiresAt != nil
    }
    
    /// Time until the file expires (if it has an expiration)
    public var timeUntilExpiration: TimeInterval? {
        guard let expiresAt = expiresAt else { return nil }
        return expiresAt.timeIntervalSinceNow
    }
    
    /// Whether the file is expired
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
    
    /// File size formatted as a human-readable string
    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

/// Request to upload a file
public struct FileUploadRequest: Codable {
    /// The file data to upload
    public let file: Data
    /// Original filename 
    public let filename: String
    /// MIME content type
    public let contentType: String
    /// Purpose for the file upload
    public let purpose: FilePurpose
    
    public init(file: Data, filename: String, contentType: String, purpose: FilePurpose) {
        self.file = file
        self.filename = filename
        self.contentType = contentType
        self.purpose = purpose
    }
    
    /// Validates the file upload request
    /// - Throws: AnthropicError if validation fails
    public func validate() throws {
        guard !filename.isEmpty else {
            throw AnthropicError.invalidParameter("filename cannot be empty")
        }
        
        guard !file.isEmpty else {
            throw AnthropicError.invalidParameter("File data cannot be empty")
        }
        
        try Self.validateFileSize(file)
        try Self.validateContentType(contentType)
        
        // Validate filename doesn't contain path separators
        guard !filename.contains("/") && !filename.contains("\\") else {
            throw AnthropicError.invalidParameter("Filename cannot contain path separators")
        }
    }
    
    /// Validates file size constraints
    /// - Parameter data: File data to validate
    /// - Throws: AnthropicError if file is too large
    public static func validateFileSize(_ data: Data) throws {
        let maxSizeBytes = 100 * 1024 * 1024 // 100MB limit
        guard data.count <= maxSizeBytes else {
            let maxSizeMB = maxSizeBytes / (1024 * 1024)
            throw AnthropicError.invalidParameter("File size cannot exceed \(maxSizeMB)MB")
        }
    }
    
    /// Validates content type is supported
    /// - Parameter contentType: MIME type to validate
    /// - Throws: AnthropicError if content type is not supported
    public static func validateContentType(_ contentType: String) throws {
        let supportedTypes = [
            "text/plain",
            "application/pdf",
            "image/jpeg",
            "image/png", 
            "image/gif",
            "image/webp",
            "application/json",
            "text/csv",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        ]
        
        guard supportedTypes.contains(contentType.lowercased()) else {
            throw AnthropicError.invalidParameter("Unsupported content type: \(contentType)")
        }
    }
}

/// Response from file upload endpoint
public struct FileUploadResponse: Codable, Equatable {
    /// The uploaded file information
    public let file: AnthropicFile
    /// Current status of the upload processing
    public let uploadStatus: FileUploadStatus
    
    private enum CodingKeys: String, CodingKey {
        case file
        case uploadStatus = "upload_status"
    }
    
    public init(file: AnthropicFile, uploadStatus: FileUploadStatus) {
        self.file = file
        self.uploadStatus = uploadStatus
    }
    
    /// Whether the upload was successful
    public var isSuccessful: Bool {
        return uploadStatus.isSuccessful
    }
    
    /// Whether upload processing is still in progress
    public var isProcessing: Bool {
        return uploadStatus.isActive
    }
}

/// Response from file list endpoint
public struct FileListResponse: Codable, Equatable {
    /// Array of files
    public let data: [AnthropicFile]
    /// Whether there are more files available
    public let hasMore: Bool
    /// ID of the first file (for pagination)
    public let firstId: String?
    /// ID of the last file (for pagination)
    public let lastId: String?
    
    private enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case firstId = "first_id"
        case lastId = "last_id"
    }
    
    public init(data: [AnthropicFile], hasMore: Bool, firstId: String?, lastId: String?) {
        self.data = data
        self.hasMore = hasMore
        self.firstId = firstId
        self.lastId = lastId
    }
    
    /// Files filtered by purpose
    /// - Parameter purpose: The file purpose to filter by
    /// - Returns: Files matching the specified purpose
    public func files(withPurpose purpose: FilePurpose) -> [AnthropicFile] {
        return data.filter { $0.purpose == purpose }
    }
    
    /// Files that are not expired
    public var activeFiles: [AnthropicFile] {
        return data.filter { !$0.isExpired }
    }
    
    /// Total size of all files in bytes
    public var totalSize: Int {
        return data.reduce(0) { $0 + $1.size }
    }
}

/// Response from file deletion endpoint
public struct FileDeletionResponse: Codable, Equatable {
    /// ID of the deleted file
    public let id: String
    /// Object type (always "file")
    public let object: String
    /// Whether the file was successfully deleted
    public let deleted: Bool
    
    public init(id: String, object: String, deleted: Bool) {
        self.id = id
        self.object = object
        self.deleted = deleted
    }
}

/// File content reference for use in messages
public struct FileReference: Codable, Equatable {
    /// The file ID to reference
    public let fileId: String
    /// Optional description of how the file should be used
    public let usage: String?
    
    private enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case usage
    }
    
    public init(fileId: String, usage: String? = nil) {
        self.fileId = fileId
        self.usage = usage
    }
}

/// Multipart form data builder for file uploads
internal struct MultipartFormData {
    private let boundary = UUID().uuidString
    private var data = Data()
    
    var contentType: String {
        return "multipart/form-data; boundary=\(boundary)"
    }
    
    var httpBody: Data {
        var finalData = data
        finalData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return finalData
    }
    
    mutating func addTextField(name: String, value: String) {
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(value)\r\n".data(using: .utf8)!)
    }
    
    mutating func addFileField(name: String, filename: String, contentType: String, fileData: Data) {
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        data.append(fileData)
        data.append("\r\n".data(using: .utf8)!)
    }
}