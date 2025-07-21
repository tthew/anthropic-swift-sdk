import Foundation

/// Helper struct for decoding arbitrary JSON keys
internal struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// Represents a tool that Claude can use during conversations
public struct Tool: Codable {
    /// The name of the tool (must be unique)
    public let name: String
    /// A description of what the tool does
    public let description: String
    /// JSON schema defining the input parameters for the tool
    public let inputSchema: [String: Any]
    
    /// Creates a new tool definition
    /// - Parameters:
    ///   - name: The unique name of the tool
    ///   - description: What the tool does
    ///   - inputSchema: JSON schema for input validation
    public init(name: String, description: String, inputSchema: [String: Any]) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
    
    /// Creates a new tool definition with a Codable schema type
    /// - Parameters:
    ///   - name: The unique name of the tool
    ///   - description: What the tool does
    ///   - inputType: A Codable type that defines the input structure
    public init<T: Codable>(name: String, description: String, inputType: T.Type) throws {
        self.name = name
        self.description = description
        
        // Generate JSON schema from Codable type (simplified approach)
        // In a production implementation, this would use reflection or a schema generator
        let encoder = JSONEncoder()
        _ = try JSONSerialization.jsonObject(with: encoder.encode([:] as [String: String]), options: []) as? [String: Any] ?? [:]
        
        // For now, create a basic object schema
        // This can be enhanced with proper JSON Schema generation from Swift types
        self.inputSchema = [
            "type": "object",
            "description": "Input parameters for \(name)"
        ]
    }
    
    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case inputSchema = "input_schema"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        
        // Properly decode the input schema
        if container.contains(.inputSchema) {
            let schemaContainer = try container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .inputSchema)
            inputSchema = try Self.decodeAnyDictionary(from: schemaContainer)
        } else {
            inputSchema = ["type": "object"]
        }
    }
    
    internal static func decodeAnyDictionary(from container: KeyedDecodingContainer<AnyCodingKey>) throws -> [String: Any] {
        var result: [String: Any] = [:]
        
        for key in container.allKeys {
            if let stringValue = try? container.decode(String.self, forKey: key) {
                result[key.stringValue] = stringValue
            } else if let intValue = try? container.decode(Int.self, forKey: key) {
                result[key.stringValue] = intValue
            } else if let doubleValue = try? container.decode(Double.self, forKey: key) {
                result[key.stringValue] = doubleValue
            } else if let boolValue = try? container.decode(Bool.self, forKey: key) {
                result[key.stringValue] = boolValue
            } else if let dictValue = try? container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: key) {
                result[key.stringValue] = try Self.decodeAnyDictionary(from: dictValue)
            } else if var arrayValue = try? container.nestedUnkeyedContainer(forKey: key) {
                result[key.stringValue] = try Self.decodeAnyArray(from: &arrayValue)
            }
        }
        
        return result
    }
    
    private static func decodeAnyArray(from container: inout UnkeyedDecodingContainer) throws -> [Any] {
        var result: [Any] = []
        
        while !container.isAtEnd {
            if let stringValue = try? container.decode(String.self) {
                result.append(stringValue)
            } else if let intValue = try? container.decode(Int.self) {
                result.append(intValue)
            } else if let doubleValue = try? container.decode(Double.self) {
                result.append(doubleValue)
            } else if let boolValue = try? container.decode(Bool.self) {
                result.append(boolValue)
            }
        }
        
        return result
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        
        // Properly encode the input schema
        var schemaContainer = container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .inputSchema)
        try Self.encodeAnyDictionary(inputSchema, to: &schemaContainer)
    }
    
    internal static func encodeAnyDictionary(_ dict: [String: Any], to container: inout KeyedEncodingContainer<AnyCodingKey>) throws {
        for (key, value) in dict {
            let codingKey = AnyCodingKey(stringValue: key)!
            
            if let stringValue = value as? String {
                try container.encode(stringValue, forKey: codingKey)
            } else if let intValue = value as? Int {
                try container.encode(intValue, forKey: codingKey)
            } else if let doubleValue = value as? Double {
                try container.encode(doubleValue, forKey: codingKey)
            } else if let boolValue = value as? Bool {
                try container.encode(boolValue, forKey: codingKey)
            } else if let dictValue = value as? [String: Any] {
                var nestedContainer = container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: codingKey)
                try Self.encodeAnyDictionary(dictValue, to: &nestedContainer)
            } else if let arrayValue = value as? [Any] {
                var nestedContainer = container.nestedUnkeyedContainer(forKey: codingKey)
                try Self.encodeAnyArray(arrayValue, to: &nestedContainer)
            }
        }
    }
    
    private static func encodeAnyArray(_ array: [Any], to container: inout UnkeyedEncodingContainer) throws {
        for value in array {
            if let stringValue = value as? String {
                try container.encode(stringValue)
            } else if let intValue = value as? Int {
                try container.encode(intValue)
            } else if let doubleValue = value as? Double {
                try container.encode(doubleValue)
            } else if let boolValue = value as? Bool {
                try container.encode(boolValue)
            }
        }
    }
    
    /// Validates the tool definition
    /// - Throws: AnthropicError if validation fails
    public func validate() throws {
        guard !name.isEmpty else {
            throw AnthropicError.invalidParameter("Tool name cannot be empty")
        }
        
        guard !description.isEmpty else {
            throw AnthropicError.invalidParameter("Tool description cannot be empty")
        }
        
        // Basic schema validation
        guard let schemaType = inputSchema["type"] as? String else {
            throw AnthropicError.invalidParameter("Tool input schema must have a 'type' field")
        }
        
        guard schemaType == "object" else {
            throw AnthropicError.invalidParameter("Tool input schema type must be 'object'")
        }
    }
}

// MARK: - Equatable implementation for Tool
extension Tool: Equatable {
    public static func == (lhs: Tool, rhs: Tool) -> Bool {
        return lhs.name == rhs.name &&
               lhs.description == rhs.description &&
               NSDictionary(dictionary: lhs.inputSchema).isEqual(to: rhs.inputSchema)
    }
}

/// Represents a tool use request from Claude
public struct ToolUse: Codable {
    /// Unique identifier for this tool use
    public let id: String
    /// Name of the tool being used
    public let name: String
    /// Input parameters for the tool
    public let input: [String: Any]
    
    /// Creates a new tool use
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - name: Tool name
    ///   - input: Input parameters
    public init(id: String, name: String, input: [String: Any]) {
        self.id = id
        self.name = name
        self.input = input
    }
    
    /// Parses the input parameters as a specific Codable type
    /// - Parameter type: The expected input type
    /// - Returns: Parsed input of the specified type
    /// - Throws: DecodingError if parsing fails
    public func parseInput<T: Codable>(_ type: T.Type) throws -> T {
        let inputData = try JSONSerialization.data(withJSONObject: input)
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: inputData)
    }
    
    /// Extracts a string parameter from the input
    /// - Parameter key: The parameter key
    /// - Returns: The string value or nil if not found
    public func stringParameter(_ key: String) -> String? {
        return input[key] as? String
    }
    
    /// Extracts an integer parameter from the input
    /// - Parameter key: The parameter key
    /// - Returns: The integer value or nil if not found
    public func intParameter(_ key: String) -> Int? {
        return input[key] as? Int
    }
    
    /// Extracts a double parameter from the input
    /// - Parameter key: The parameter key
    /// - Returns: The double value or nil if not found
    public func doubleParameter(_ key: String) -> Double? {
        return input[key] as? Double
    }
    
    /// Extracts a boolean parameter from the input
    /// - Parameter key: The parameter key
    /// - Returns: The boolean value or nil if not found
    public func boolParameter(_ key: String) -> Bool? {
        return input[key] as? Bool
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        // Decode the input dictionary
        if container.contains(.input) {
            let inputContainer = try container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .input)
            input = try Tool.decodeAnyDictionary(from: inputContainer)
        } else {
            input = [:]
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        
        // Encode the input dictionary
        var inputContainer = container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .input)
        try Tool.encodeAnyDictionary(input, to: &inputContainer)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case input
    }
}

// MARK: - Equatable implementation for ToolUse
extension ToolUse: Equatable {
    public static func == (lhs: ToolUse, rhs: ToolUse) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               NSDictionary(dictionary: lhs.input).isEqual(to: rhs.input)
    }
}

/// Represents the result of a tool execution
public struct ToolResult: Codable, Equatable {
    /// The ID of the tool use this result corresponds to
    public let toolUseId: String
    /// The result content from the tool execution
    public let content: String
    /// Whether the tool execution was successful
    public let isError: Bool
    
    /// Creates a successful tool result
    /// - Parameters:
    ///   - toolUseId: The tool use ID this responds to
    ///   - content: The result content
    public init(toolUseId: String, content: String) {
        self.toolUseId = toolUseId
        self.content = content
        self.isError = false
    }
    
    /// Creates a tool result (success or error)
    /// - Parameters:
    ///   - toolUseId: The tool use ID this responds to
    ///   - content: The result content or error message
    ///   - isError: Whether this represents an error
    public init(toolUseId: String, content: String, isError: Bool) {
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
    }
    
    private enum CodingKeys: String, CodingKey {
        case toolUseId = "tool_use_id"
        case content
        case isError = "is_error"
    }
}

/// Tool choice options for controlling when Claude uses tools
public enum ToolChoice: Codable, Equatable {
    /// Claude chooses whether to use tools (default)
    case auto
    /// Claude must use at least one tool
    case any
    /// Claude must use the specified tool
    case tool(String)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            switch stringValue {
            case "auto":
                self = .auto
            case "any":
                self = .any
            default:
                // Assume it's a tool name for .tool case
                self = .tool(stringValue)
            }
        } else {
            // Handle object form: {"type": "tool", "name": "tool_name"}
            let objectContainer = try decoder.container(keyedBy: ObjectCodingKeys.self)
            let type = try objectContainer.decode(String.self, forKey: .type)
            
            if type == "tool" {
                let name = try objectContainer.decode(String.self, forKey: .name)
                self = .tool(name)
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid tool choice type: \(type)"
                )
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .auto:
            var container = encoder.singleValueContainer()
            try container.encode("auto")
        case .any:
            var container = encoder.singleValueContainer()
            try container.encode("any")
        case .tool(let name):
            var container = encoder.container(keyedBy: ObjectCodingKeys.self)
            try container.encode("tool", forKey: .type)
            try container.encode(name, forKey: .name)
        }
    }
    
    private enum ObjectCodingKeys: String, CodingKey {
        case type
        case name
    }
}