import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// HTTP methods supported by the Anthropic API
public enum HTTPMethod: String, Codable, CaseIterable, Equatable {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

/// Represents an HTTP request with all necessary components
public struct HTTPRequest: Equatable {
    /// The URL to send the request to
    public let url: URL
    /// The HTTP method to use
    public let method: HTTPMethod
    /// HTTP headers to include
    public let headers: [String: String]
    /// The request body data
    public let body: Data?
    
    /// Creates a new HTTP request
    /// - Parameters:
    ///   - url: The URL to send the request to
    ///   - method: The HTTP method to use
    ///   - headers: HTTP headers to include
    ///   - body: The request body data
    public init(url: URL, method: HTTPMethod, headers: [String: String], body: Data?) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
    
    /// Converts this HTTPRequest to a URLRequest with proper configuration
    public var urlRequest: URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        // Set default timeout
        request.timeoutInterval = 60.0
        
        // Add headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Ensure proper content type for POST requests with body
        if method == .POST && body != nil && headers["Content-Type"] == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return request
    }
    
    /// Converts this HTTPRequest to a URLRequest for streaming operations
    /// - Throws: HTTPError.invalidURL if URL is invalid
    public func toURLRequest() throws -> URLRequest {
        return urlRequest
    }
}

/// Errors that can occur during HTTP operations
public enum HTTPError: Error, LocalizedError {
    /// Invalid HTTP response received
    case invalidResponse
    /// HTTP error with status code
    case httpError(Int)
    /// Network connectivity issue
    case networkError(Error)
    /// Request timeout
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid HTTP response received"
        case .httpError(let statusCode):
            return "HTTP error with status code: \(statusCode)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Request timeout"
        }
    }
}

/// Actor-based HTTP client for thread-safe networking operations
public actor HTTPClient {
    /// The URL session to use for requests
    private let session: URLSession
    /// Client configuration
    private let configuration: ClientConfiguration
    
    /// Creates a new HTTP client with default configuration
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 300.0
        self.session = URLSession(configuration: config)
        self.configuration = .default
    }
    
    /// Creates a new HTTP client with custom configuration
    /// - Parameter configuration: Client configuration for performance optimization
    public init(configuration: ClientConfiguration) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.connectionTimeout
        config.timeoutIntervalForResource = configuration.resourceTimeout
        config.httpMaximumConnectionsPerHost = configuration.maxConcurrentRequests
        
        if configuration.enableCompression {
            config.requestCachePolicy = configuration.enableCaching ? .returnCacheDataElseLoad : .reloadIgnoringLocalCacheData
        }
        
        self.session = URLSession(configuration: config)
        self.configuration = configuration
    }
    
    /// Creates a new HTTP client with custom URLSession
    /// - Parameter session: Custom URLSession to use
    public init(session: URLSession) {
        self.session = session
        self.configuration = .default
    }
    
    /// Sends an HTTP request and returns the decoded response
    /// - Parameter request: The HTTP request to send
    /// - Returns: The decoded response of type T
    /// - Throws: HTTPError or decoding errors
    public func send<T: Codable>(_ request: HTTPRequest) async throws -> T {
        let urlRequest = request.urlRequest
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPError.invalidResponse
            }
            
            // Check for HTTP errors
            guard 200...299 ~= httpResponse.statusCode else {
                throw HTTPError.httpError(httpResponse.statusCode)
            }
            
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as HTTPError {
            throw error
        } catch let urlError as URLError {
            throw HTTPError.networkError(urlError)
        } catch {
            throw error
        }
    }
    
    /// Raw HTTP response for non-JSON endpoints
    public struct RawHTTPResponse {
        public let data: Data
        public let statusCode: Int
        public let headers: [String: String]
        
        public init(data: Data, statusCode: Int, headers: [String: String]) {
            self.data = data
            self.statusCode = statusCode
            self.headers = headers
        }
    }
    
    /// Sends an HTTP request and returns the raw response data
    /// - Parameter request: The HTTP request to send
    /// - Returns: The raw response data and metadata
    /// - Throws: HTTPError for network issues
    public func sendRaw(_ request: HTTPRequest) async throws -> RawHTTPResponse {
        let urlRequest = request.urlRequest
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPError.invalidResponse
            }
            
            // Check for HTTP errors
            guard 200...299 ~= httpResponse.statusCode else {
                throw HTTPError.httpError(httpResponse.statusCode)
            }
            
            // Convert headers to dictionary
            var headers: [String: String] = [:]
            for (key, value) in httpResponse.allHeaderFields {
                if let keyString = key as? String, let valueString = value as? String {
                    headers[keyString] = valueString
                }
            }
            
            return RawHTTPResponse(data: data, statusCode: httpResponse.statusCode, headers: headers)
        } catch let error as HTTPError {
            throw error
        } catch let urlError as URLError {
            throw HTTPError.networkError(urlError)
        } catch {
            throw HTTPError.networkError(error)
        }
    }
}