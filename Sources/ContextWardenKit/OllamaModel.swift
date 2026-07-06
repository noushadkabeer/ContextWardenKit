import Foundation

public struct OllamaModel: Identifiable, Codable, Equatable {
    public let id: String          // digest or unique name
    public let name: String        // e.g. "llama3:70b"
    public let sizeGB: Double      // size of the model file/vram usage in GB
    public let isLoaded: Bool
    public let lastUsed: Date?
    public var estimatedRAMFootprintGB: Double  // size in RAM in GB
    
    public init(
        id: String,
        name: String,
        sizeGB: Double,
        isLoaded: Bool,
        lastUsed: Date?,
        estimatedRAMFootprintGB: Double
    ) {
        self.id = id
        self.name = name
        self.sizeGB = sizeGB
        self.isLoaded = isLoaded
        self.lastUsed = lastUsed
        self.estimatedRAMFootprintGB = estimatedRAMFootprintGB
    }
}
