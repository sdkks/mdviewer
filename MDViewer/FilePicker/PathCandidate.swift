import Foundation

struct PathCandidate: Identifiable, Equatable {
    let id: UUID = UUID()
    let url: URL
    let displayName: String   // "filename.md" or "dirname/"
    let isDirectory: Bool
}
