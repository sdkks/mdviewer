import SwiftUI

private struct FocusedDocumentStateKey: FocusedValueKey {
    typealias Value = DocumentState
}

extension FocusedValues {
    var documentState: DocumentState? {
        get { self[FocusedDocumentStateKey.self] }
        set { self[FocusedDocumentStateKey.self] = newValue }
    }
}
