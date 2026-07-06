import Foundation

public actor OllamaEngine {
    private let baseURL = "http://localhost:11434"
    private let session: URLSession
    private var pollingTask: Task<Void, Never>?
    private var loadedModelsCache: [OllamaModel] = []
    private var onUpdateHandler: (([OllamaModel]) -> Void)?
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    public func registerOnUpdate(_ handler: @escaping ([OllamaModel]) -> Void) {
        self.onUpdateHandler = handler
    }
    
    public func isRunning() async -> Bool {
        guard let url = URL(string: baseURL) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 1.5
        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return (200...399).contains(httpResponse.statusCode)
            }
            return false
        } catch {
            return false
        }
    }
    
    public func loadedModels() async throws -> [OllamaModel] {
        guard let url = URL(string: "\(baseURL)/api/ps") else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let payload = try decoder.decode(OllamaApiResponse.self, from: data)
        let models = (payload.models ?? []).map { m in
            OllamaModel(
                id: m.digest,
                name: m.name,
                sizeGB: Double(m.size_vram ?? m.size) / 1_073_741_824.0,
                isLoaded: true,
                lastUsed: Date(),
                estimatedRAMFootprintGB: Double(m.size) / 1_073_741_824.0
            )
        }
        loadedModelsCache = models
        return models
    }
    
    public func installedModels() async throws -> [OllamaModel] {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let payload = try decoder.decode(OllamaApiResponse.self, from: data)
        let runningList = try? await loadedModels()
        
        return (payload.models ?? []).map { m in
            let isCurrentlyLoaded = runningList?.contains(where: { $0.id == m.digest }) ?? false
            return OllamaModel(
                id: m.digest,
                name: m.name,
                sizeGB: Double(m.size) / 1_073_741_824.0,
                isLoaded: isCurrentlyLoaded,
                lastUsed: isCurrentlyLoaded ? Date() : nil,
                estimatedRAMFootprintGB: Double(m.size) / 1_073_741_824.0
            )
        }
    }
    
    public func unloadModel(name: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/generate") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0
        
        let payload: [String: Any] = [
            "model": name,
            "keep_alive": 0
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Update local cache
        _ = try? await loadedModels()
    }
    
    public func startPolling() {
        stopPolling()
        
        pollingTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                if await self.isRunning() {
                    do {
                        let models = try await self.loadedModels()
                        if let handler = await self.onUpdateHandler {
                            handler(models)
                        }
                    } catch {
                        // Network error or timeout, ignore
                    }
                } else {
                    if await !self.loadedModelsCache.isEmpty {
                        await self.setLoadedModelsCache([])
                        if let handler = await self.onUpdateHandler {
                            handler([])
                        }
                    }
                }
                do {
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                } catch {
                    break
                }
            }
        }
    }
    
    public func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    private func setLoadedModelsCache(_ models: [OllamaModel]) {
        self.loadedModelsCache = models
    }
}

fileprivate struct OllamaApiResponse: Decodable {
    struct Model: Decodable {
        let name: String
        let digest: String
        let size: Int64
        let size_vram: Int64?
    }
    let models: [Model]?
}
