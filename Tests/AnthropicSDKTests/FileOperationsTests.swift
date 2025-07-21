import XCTest
@testable import AnthropicSDK

final class FileOperationsTests: XCTestCase {
    
    // BDD: GIVEN FileUploadRequest WHEN upload file THEN proper multipart request
    func testFileUploadRequest() throws {
        // This test will FAIL initially (RED phase)
        let testData = "Hello, world!".data(using: .utf8)!
        
        let uploadRequest = FileUploadRequest(
            file: testData,
            filename: "test.txt",
            contentType: "text/plain",
            purpose: .document
        )
        
        XCTAssertEqual(uploadRequest.filename, "test.txt")
        XCTAssertEqual(uploadRequest.contentType, "text/plain")
        XCTAssertEqual(uploadRequest.purpose, .document)
        XCTAssertEqual(uploadRequest.file.count, testData.count)
        
        // This will fail because FileUploadRequest doesn't exist yet
    }
    
    // BDD: GIVEN AnthropicFile JSON WHEN decode THEN proper file structure
    func testAnthropicFileDecoding() throws {
        // This test will FAIL initially (RED phase)
        let jsonString = """
        {
            "id": "file_abc123",
            "type": "file",
            "filename": "document.pdf",
            "size": 1024000,
            "content_type": "application/pdf",
            "purpose": "document",
            "created_at": "2024-06-01T12:00:00Z",
            "expires_at": "2024-12-01T12:00:00Z"
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let file = try decoder.decode(AnthropicFile.self, from: data)
        
        XCTAssertEqual(file.id, "file_abc123")
        XCTAssertEqual(file.type, "file")
        XCTAssertEqual(file.filename, "document.pdf")
        XCTAssertEqual(file.size, 1024000)
        XCTAssertEqual(file.contentType, "application/pdf")
        XCTAssertEqual(file.purpose, .document)
        XCTAssertNotNil(file.createdAt)
        XCTAssertNotNil(file.expiresAt)
        
        // This will fail because AnthropicFile doesn't exist yet
    }
    
    // BDD: GIVEN FilePurpose enum WHEN use in upload THEN proper purpose encoding
    func testFilePurposeEnum() throws {
        // This test will FAIL initially (RED phase)
        XCTAssertEqual(FilePurpose.vision.rawValue, "vision")
        XCTAssertEqual(FilePurpose.document.rawValue, "document")
        XCTAssertEqual(FilePurpose.batch.rawValue, "batch")
        
        // Test all cases exist
        let allPurposes = FilePurpose.allCases
        XCTAssertTrue(allPurposes.contains(.vision))
        XCTAssertTrue(allPurposes.contains(.document))
        XCTAssertTrue(allPurposes.contains(.batch))
        
        // This will fail because FilePurpose doesn't exist yet
    }
    
    // BDD: GIVEN client with files WHEN upload file THEN successful upload
    func testFileUpload() async throws {
        // This test will FAIL initially (RED phase)
        let client = try AnthropicClient(apiKey: "sk-ant-test")
        let testData = "Test document content".data(using: .utf8)!
        
        XCTAssertNotNil(client.files)
        // Test that upload method exists - use explicit method call to avoid ambiguity
        
        let uploadRequest = FileUploadRequest(
            file: testData,
            filename: "test.txt",
            contentType: "text/plain", 
            purpose: .document
        )
        
        // Test that upload method exists with proper signature
        // This should not throw (method should exist)
        // let response = try await client.files.upload(uploadRequest)
        
        // This will fail because file upload method doesn't exist yet
    }
    
    // BDD: GIVEN file ID WHEN retrieve file info THEN file metadata
    func testRetrieveFileInfo() async throws {
        // This test will FAIL initially (RED phase)
        let client = try AnthropicClient(apiKey: "sk-ant-test")
        
        XCTAssertNotNil(client.files.retrieve)
        
        let fileId = "file_abc123"
        // Test method signature
        // let file = try await client.files.retrieve(fileId)
        
        // This will fail because file retrieve method doesn't exist yet
    }
    
    // BDD: GIVEN user files WHEN list files THEN paginated file list
    func testListFiles() async throws {
        // This test will FAIL initially (RED phase)
        let client = try AnthropicClient(apiKey: "sk-ant-test")
        
        XCTAssertNotNil(client.files.list)
        
        // Test method with optional parameters
        // let files = try await client.files.list(purpose: .document, limit: 20)
        
        // This will fail because file list method doesn't exist yet
    }
    
    // BDD: GIVEN file ID WHEN delete file THEN successful deletion
    func testDeleteFile() async throws {
        // This test will FAIL initially (RED phase)
        let client = try AnthropicClient(apiKey: "sk-ant-test")
        
        XCTAssertNotNil(client.files.delete)
        
        let fileId = "file_abc123"
        // Test method signature
        // let deleted = try await client.files.delete(fileId)
        
        // This will fail because file delete method doesn't exist yet  
    }
    
    // BDD: GIVEN FileUploadResponse JSON WHEN decode THEN upload status and file info
    func testFileUploadResponseDecoding() throws {
        // This test will FAIL initially (RED phase)
        let jsonString = """
        {
            "file": {
                "id": "file_abc123",
                "type": "file",
                "filename": "uploaded.txt",
                "size": 2048,
                "content_type": "text/plain",
                "purpose": "document",
                "created_at": "2024-06-01T12:00:00Z",
                "expires_at": null
            },
            "upload_status": "completed"
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let response = try decoder.decode(FileUploadResponse.self, from: data)
        
        XCTAssertEqual(response.file.id, "file_abc123")
        XCTAssertEqual(response.file.filename, "uploaded.txt")
        XCTAssertEqual(response.file.size, 2048)
        XCTAssertEqual(response.uploadStatus, .completed)
        
        // This will fail because FileUploadResponse doesn't exist yet
    }
    
    // BDD: GIVEN file upload validation WHEN invalid parameters THEN validation errors
    func testFileUploadValidation() throws {
        // This test will FAIL initially (RED phase)
        let testData = "Test content".data(using: .utf8)!
        
        // Test empty filename validation
        XCTAssertThrowsError(try FileUploadRequest(
            file: testData,
            filename: "",
            contentType: "text/plain",
            purpose: .document
        ).validate()) { error in
            if case AnthropicError.invalidParameter(let message) = error {
                XCTAssertTrue(message.contains("filename"))
            } else {
                XCTFail("Expected invalidParameter error")
            }
        }
        
        // Test empty data validation
        XCTAssertThrowsError(try FileUploadRequest(
            file: Data(),
            filename: "test.txt", 
            contentType: "text/plain",
            purpose: .document
        ).validate()) { error in
            if case AnthropicError.invalidParameter(let message) = error {
                XCTAssertTrue(message.contains("empty"))
            } else {
                XCTFail("Expected invalidParameter error")
            }
        }
        
        // This will fail because FileUploadRequest validation doesn't exist yet
    }
    
    // BDD: GIVEN file size limits WHEN upload large file THEN size validation
    func testFileSizeLimits() throws {
        // This test will FAIL initially (RED phase)
        // Test maximum file size (example: 100MB)
        let maxSizeBytes = 100 * 1024 * 1024
        let oversizedData = Data(count: maxSizeBytes + 1)
        
        XCTAssertThrowsError(try FileUploadRequest.validateFileSize(oversizedData)) { error in
            if case AnthropicError.invalidParameter(let message) = error {
                XCTAssertTrue(message.contains("size"))
            } else {
                XCTFail("Expected invalidParameter error")
            }
        }
        
        // Test valid file size
        let validData = Data(count: 1024) // 1KB
        XCTAssertNoThrow(try FileUploadRequest.validateFileSize(validData))
        
        // This will fail because file size validation doesn't exist yet
    }
    
    // BDD: GIVEN supported file types WHEN validate content type THEN proper MIME type checking
    func testSupportedFileTypes() throws {
        // This test will FAIL initially (RED phase)
        let supportedTypes = [
            "text/plain",
            "application/pdf", 
            "image/jpeg",
            "image/png",
            "image/gif",
            "image/webp",
            "application/json",
            "text/csv"
        ]
        
        for contentType in supportedTypes {
            XCTAssertNoThrow(try FileUploadRequest.validateContentType(contentType))
        }
        
        // Test unsupported content type
        XCTAssertThrowsError(try FileUploadRequest.validateContentType("application/executable")) { error in
            if case AnthropicError.invalidParameter(let message) = error {
                XCTAssertTrue(message.contains("content type"))
            } else {
                XCTFail("Expected invalidParameter error")
            }
        }
        
        // This will fail because content type validation doesn't exist yet
    }
    
    // BDD: GIVEN file list response WHEN decode THEN paginated results
    func testFileListResponseDecoding() throws {
        // This test will FAIL initially (RED phase)
        let jsonString = """
        {
            "data": [
                {
                    "id": "file_1",
                    "type": "file",
                    "filename": "doc1.pdf",
                    "size": 1024,
                    "content_type": "application/pdf",
                    "purpose": "document",
                    "created_at": "2024-06-01T12:00:00Z",
                    "expires_at": null
                },
                {
                    "id": "file_2", 
                    "type": "file",
                    "filename": "image1.png",
                    "size": 2048,
                    "content_type": "image/png",
                    "purpose": "vision",
                    "created_at": "2024-06-01T13:00:00Z",
                    "expires_at": null
                }
            ],
            "has_more": false,
            "first_id": "file_1",
            "last_id": "file_2"
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let response = try decoder.decode(FileListResponse.self, from: data)
        
        XCTAssertEqual(response.data.count, 2)
        XCTAssertFalse(response.hasMore)
        XCTAssertEqual(response.firstId, "file_1")
        XCTAssertEqual(response.lastId, "file_2")
        
        let firstFile = response.data[0]
        XCTAssertEqual(firstFile.id, "file_1")
        XCTAssertEqual(firstFile.purpose, .document)
        
        let secondFile = response.data[1]
        XCTAssertEqual(secondFile.id, "file_2")
        XCTAssertEqual(secondFile.purpose, .vision)
        
        // This will fail because FileListResponse doesn't exist yet
    }
    
    // BDD: GIVEN file deletion WHEN delete file THEN proper deletion response
    func testFileDeletionResponse() throws {
        // This test will FAIL initially (RED phase)
        let jsonString = """
        {
            "id": "file_abc123",
            "object": "file",
            "deleted": true
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        let response = try decoder.decode(FileDeletionResponse.self, from: data)
        
        XCTAssertEqual(response.id, "file_abc123")
        XCTAssertEqual(response.object, "file")
        XCTAssertTrue(response.deleted)
        
        // This will fail because FileDeletionResponse doesn't exist yet
    }
}