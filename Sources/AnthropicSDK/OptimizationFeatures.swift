import Foundation

/// Configuration options for client performance optimization
public struct ClientConfiguration {
    /// Connection timeout in seconds (default: 60)
    public let connectionTimeout: TimeInterval
    /// Resource timeout in seconds (default: 300)
    public let resourceTimeout: TimeInterval
    /// Maximum number of concurrent requests (default: 10)
    public let maxConcurrentRequests: Int
    /// Enable request/response caching (default: false)
    public let enableCaching: Bool
    /// Cache size limit in bytes (default: 50MB)
    public let cacheSizeLimit: Int
    /// Enable retry logic for failed requests (default: true)
    public let enableRetry: Bool
    /// Maximum retry attempts (default: 3)
    public let maxRetryAttempts: Int
    /// Base delay for exponential backoff in seconds (default: 1.0)
    public let retryBaseDelay: TimeInterval
    /// Enable request compression (default: true)
    public let enableCompression: Bool
    
    /// Default configuration with recommended settings
    public static let `default` = ClientConfiguration()
    
    /// Configuration optimized for mobile devices
    public static let mobile = ClientConfiguration(
        connectionTimeout: 30,
        resourceTimeout: 120,
        maxConcurrentRequests: 5,
        enableCaching: true,
        cacheSizeLimit: 25 * 1024 * 1024, // 25MB
        enableRetry: true,
        maxRetryAttempts: 2,
        retryBaseDelay: 2.0
    )
    
    /// Configuration for high-throughput server environments
    public static let server = ClientConfiguration(
        connectionTimeout: 90,
        resourceTimeout: 600,
        maxConcurrentRequests: 50,
        enableCaching: false,
        enableRetry: true,
        maxRetryAttempts: 5,
        retryBaseDelay: 0.5
    )
    
    public init(
        connectionTimeout: TimeInterval = 60,
        resourceTimeout: TimeInterval = 300,
        maxConcurrentRequests: Int = 10,
        enableCaching: Bool = false,
        cacheSizeLimit: Int = 50 * 1024 * 1024,
        enableRetry: Bool = true,
        maxRetryAttempts: Int = 3,
        retryBaseDelay: TimeInterval = 1.0,
        enableCompression: Bool = true
    ) {
        self.connectionTimeout = connectionTimeout
        self.resourceTimeout = resourceTimeout
        self.maxConcurrentRequests = maxConcurrentRequests
        self.enableCaching = enableCaching
        self.cacheSizeLimit = cacheSizeLimit
        self.enableRetry = enableRetry
        self.maxRetryAttempts = maxRetryAttempts
        self.retryBaseDelay = retryBaseDelay
        self.enableCompression = enableCompression
    }
}

/// Connection pooling for efficient HTTP request management
public actor ConnectionPool {
    private let maxConnections: Int
    private let keepAliveTimeout: TimeInterval
    private var activeConnections: Set<String> = []
    private var lastUsed: [String: Date] = [:]
    
    public init(maxConnections: Int = 10, keepAliveTimeout: TimeInterval = 120) {
        self.maxConnections = maxConnections
        self.keepAliveTimeout = keepAliveTimeout
    }
    
    /// Acquires a connection slot for the given host
    /// - Parameter host: The target host
    /// - Returns: Whether a connection slot was acquired
    public func acquireConnection(for host: String) async -> Bool {
        // Clean up expired connections
        await cleanupExpiredConnections()
        
        if activeConnections.contains(host) {
            // Reuse existing connection
            lastUsed[host] = Date()
            return true
        }
        
        if activeConnections.count >= maxConnections {
            return false // No available slots
        }
        
        activeConnections.insert(host)
        lastUsed[host] = Date()
        return true
    }
    
    /// Releases a connection for the given host
    /// - Parameter host: The target host
    public func releaseConnection(for host: String) {
        // Keep connection alive for potential reuse
        lastUsed[host] = Date()
    }
    
    /// Cleans up expired connections
    private func cleanupExpiredConnections() {
        let now = Date()
        let expiredConnections = lastUsed.compactMap { (host, lastUsedDate) -> String? in
            if now.timeIntervalSince(lastUsedDate) > keepAliveTimeout {
                return host
            }
            return nil
        }
        
        for host in expiredConnections {
            activeConnections.remove(host)
            lastUsed.removeValue(forKey: host)
        }
    }
}

/// Retry strategy for handling transient failures
public struct RetryStrategy {
    public let maxAttempts: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let retryableStatusCodes: Set<Int>
    
    public static let `default` = RetryStrategy(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        retryableStatusCodes: [408, 429, 500, 502, 503, 504]
    )
    
    public static let aggressive = RetryStrategy(
        maxAttempts: 5,
        baseDelay: 0.5,
        maxDelay: 60.0,
        retryableStatusCodes: [408, 429, 500, 502, 503, 504]
    )
    
    public static let conservative = RetryStrategy(
        maxAttempts: 2,
        baseDelay: 2.0,
        maxDelay: 15.0,
        retryableStatusCodes: [429, 503, 504]
    )
    
    public init(
        maxAttempts: Int,
        baseDelay: TimeInterval,
        maxDelay: TimeInterval,
        retryableStatusCodes: Set<Int>
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.retryableStatusCodes = retryableStatusCodes
    }
    
    /// Calculates the delay for a retry attempt using exponential backoff with jitter
    /// - Parameter attempt: The attempt number (starting from 1)
    /// - Returns: Delay in seconds before the retry
    public func delayForAttempt(_ attempt: Int) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt - 1))
        let cappedDelay = min(exponentialDelay, maxDelay)
        
        // Add jitter to prevent thundering herd
        let jitter = Double.random(in: 0.0...0.1) * cappedDelay
        return cappedDelay + jitter
    }
    
    /// Whether the given HTTP status code should be retried
    /// - Parameter statusCode: HTTP status code from the response
    /// - Returns: True if the status code indicates a retryable error
    public func shouldRetry(statusCode: Int) -> Bool {
        return retryableStatusCodes.contains(statusCode)
    }
}

/// Circuit breaker pattern for preventing cascade failures
public actor CircuitBreaker {
    public enum State {
        case closed    // Normal operation
        case open      // Failures detected, requests blocked
        case halfOpen  // Testing if service recovered
    }
    
    private let failureThreshold: Int
    private let recoveryTimeout: TimeInterval
    private let monitoringWindow: TimeInterval
    
    private var state: State = .closed
    private var failureCount = 0
    private var lastFailureTime: Date?
    private var successCount = 0
    
    public init(
        failureThreshold: Int = 5,
        recoveryTimeout: TimeInterval = 60,
        monitoringWindow: TimeInterval = 300
    ) {
        self.failureThreshold = failureThreshold
        self.recoveryTimeout = recoveryTimeout
        self.monitoringWindow = monitoringWindow
    }
    
    /// Current state of the circuit breaker
    public var currentState: State {
        return state
    }
    
    /// Checks if a request should be allowed through
    /// - Returns: True if request should proceed, false if blocked
    public func shouldAllowRequest() async -> Bool {
        await updateState()
        
        switch state {
        case .closed:
            return true
        case .open:
            return false
        case .halfOpen:
            return true  // Allow limited requests to test recovery
        }
    }
    
    /// Records a successful request
    public func recordSuccess() {
        successCount += 1
        
        if state == .halfOpen && successCount >= 3 {
            // Service appears to have recovered
            state = .closed
            failureCount = 0
            successCount = 0
        }
    }
    
    /// Records a failed request
    public func recordFailure() {
        failureCount += 1
        lastFailureTime = Date()
        successCount = 0
        
        if failureCount >= failureThreshold {
            state = .open
        }
    }
    
    /// Updates the circuit breaker state based on time and conditions
    private func updateState() {
        guard let lastFailure = lastFailureTime else { return }
        
        let timeSinceFailure = Date().timeIntervalSince(lastFailure)
        
        switch state {
        case .open:
            if timeSinceFailure >= recoveryTimeout {
                state = .halfOpen
                successCount = 0
            }
        case .closed:
            // Reset failure count if enough time has passed
            if timeSinceFailure >= monitoringWindow {
                failureCount = 0
            }
        case .halfOpen:
            // Already allowing limited requests
            break
        }
    }
}

/// Memory-efficient request/response caching
public actor ResponseCache {
    private struct CacheEntry {
        let data: Data
        let timestamp: Date
        let contentType: String?
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 300 // 5 minutes
        }
    }
    
    private var cache: [String: CacheEntry] = [:]
    private let maxSize: Int
    private var currentSize = 0
    
    public init(maxSize: Int = 50 * 1024 * 1024) { // 50MB default
        self.maxSize = maxSize
    }
    
    /// Stores a response in the cache
    /// - Parameters:
    ///   - key: Cache key (typically the request URL)
    ///   - data: Response data
    ///   - contentType: Content type of the response
    public func store(key: String, data: Data, contentType: String?) {
        let entry = CacheEntry(data: data, timestamp: Date(), contentType: contentType)
        
        // Remove existing entry if present
        if let existingEntry = cache[key] {
            currentSize -= existingEntry.data.count
        }
        
        // Ensure we don't exceed cache size
        while currentSize + data.count > maxSize && !cache.isEmpty {
            evictOldestEntry()
        }
        
        cache[key] = entry
        currentSize += data.count
    }
    
    /// Retrieves a response from the cache if present and not expired
    /// - Parameter key: Cache key
    /// - Returns: Cached data if available and valid, nil otherwise
    public func retrieve(key: String) -> Data? {
        guard let entry = cache[key] else { return nil }
        
        if entry.isExpired {
            cache.removeValue(forKey: key)
            currentSize -= entry.data.count
            return nil
        }
        
        return entry.data
    }
    
    /// Clears expired entries from the cache
    public func cleanupExpiredEntries() {
        let expiredKeys = cache.compactMap { (key, entry) in
            entry.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            if let entry = cache.removeValue(forKey: key) {
                currentSize -= entry.data.count
            }
        }
    }
    
    /// Evicts the oldest cache entry
    private func evictOldestEntry() {
        guard let oldestKey = cache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key else {
            return
        }
        
        if let entry = cache.removeValue(forKey: oldestKey) {
            currentSize -= entry.data.count
        }
    }
    
    /// Current cache statistics
    public var statistics: (entryCount: Int, totalSize: Int, hitRate: Double) {
        return (cache.count, currentSize, 0.0) // Hit rate tracking could be added
    }
}