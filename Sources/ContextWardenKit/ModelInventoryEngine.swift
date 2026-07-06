import Foundation

public enum ModelSource: String, Codable {
    case ollama = "Ollama"
    case huggingFace = "Hugging Face"
}

public struct InventoryModel: Identifiable, Codable, Equatable {
    public var id: String { name + source.rawValue }
    public let name: String
    public let sizeGB: Double
    public let lastAccessed: Date
    public let source: ModelSource
    public let path: String
    
    public init(name: String, sizeGB: Double, lastAccessed: Date, source: ModelSource, path: String) {
        self.name = name
        self.sizeGB = sizeGB
        self.lastAccessed = lastAccessed
        self.source = source
        self.path = path
    }
}

public actor ModelInventoryEngine {
    public init() {}
    
    public func scanModels() async -> [InventoryModel] {
        var list: [InventoryModel] = []
        
        // 1. Scan Ollama local manifests (if exists)
        let ollamaHome = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ollama/models")
        if FileManager.default.fileExists(atPath: ollamaHome.path) {
            let manifestsDir = ollamaHome.appendingPathComponent("manifests")
            if let enumerator = FileManager.default.enumerator(at: manifestsDir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: [.skipsHiddenFiles]) {
                while let fileURL = enumerator.nextObject() as? URL {
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue {
                        // This represents an Ollama model registry tag
                        // e.g. .ollama/models/manifests/registry.ollama.ai/library/llama3/latest
                        let relPath = fileURL.path.replacingOccurrences(of: manifestsDir.path + "/", with: "")
                        // Clean up relPath to get model name
                        // e.g. registry.ollama.ai/library/llama3/latest -> llama3:latest
                        let components = relPath.components(separatedBy: "/")
                        if components.count >= 3 {
                            let name = components.suffix(2).joined(separator: ":")
                            let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                            let date = attrs?[.modificationDate] as? Date ?? Date()
                            
                            // Estimate size of manifest layers
                            var totalBytes: Int64 = 0
                            if let data = try? Data(contentsOf: fileURL),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let layers = json["layers"] as? [[String: Any]] {
                                for layer in layers {
                                    if let size = layer["size"] as? NSNumber {
                                        totalBytes += size.int64Value
                                    }
                                }
                            }
                            
                            list.append(InventoryModel(
                                name: name,
                                sizeGB: Double(totalBytes) / 1_073_741_824.0,
                                lastAccessed: date,
                                source: .ollama,
                                path: fileURL.path
                            ))
                        }
                    }
                }
            }
        }
        
        // 2. Scan Hugging Face cache
        let hfHome = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
        if FileManager.default.fileExists(atPath: hfHome.path) {
            if let contents = try? FileManager.default.contentsOfDirectory(at: hfHome, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for dir in contents {
                    if dir.lastPathComponent.hasPrefix("models--") {
                        // e.g. models--meta-llama--Meta-Llama-3-8B-Instruct
                        let rawName = dir.lastPathComponent.replacingOccurrences(of: "models--", with: "")
                        let name = rawName.replacingOccurrences(of: "--", with: "/")
                        
                        // Calculate folder size
                        var totalBytes: Int64 = 0
                        var newestDate = Date.distantPast
                        if let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: []) {
                            while let fileURL = enumerator.nextObject() as? URL {
                                if let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) {
                                    totalBytes += Int64(attrs.fileSize ?? 0)
                                    if let modDate = attrs.contentModificationDate, modDate > newestDate {
                                        newestDate = modDate
                                    }
                                }
                            }
                        }
                        
                        list.append(InventoryModel(
                            name: name,
                            sizeGB: Double(totalBytes) / 1_073_741_824.0,
                            lastAccessed: newestDate == Date.distantPast ? Date() : newestDate,
                            source: .huggingFace,
                            path: dir.path
                        ))
                    }
                }
            }
        }
        
        return list
    }
    
    public func deleteModel(_ model: InventoryModel) async throws {
        let url = URL(fileURLWithPath: model.path)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        
        // For Ollama, we should also clean up the associated blobs if possible,
        // or just let Ollama GC handle it. Since we deleted the manifest,
        // Ollama tags won't list it anymore.
    }
}
