import Foundation

public actor DigestEngine {
    private let digestsKey = "com.contextwarden.digestengine.digests"
    private var digests: [WeeklyDigest] = []
    
    public init() {
        if let data = UserDefaults.standard.data(forKey: digestsKey),
           let decoded = try? JSONDecoder().decode([WeeklyDigest].self, from: data) {
            self.digests = decoded
        }
    }
    
    public func getDigests() -> [WeeklyDigest] {
        return digests
    }
    
    public func addDigest(_ digest: WeeklyDigest) {
        digests.insert(digest, at: 0)
        // Keep last 12 weeks
        if digests.count > 12 {
            digests = Array(digests.prefix(12))
        }
        save()
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(digests) {
            UserDefaults.standard.set(encoded, forKey: digestsKey)
        }
    }
}
