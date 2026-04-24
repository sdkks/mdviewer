import SwiftUI

struct FindBarView: View {
    @ObservedObject var documentState: DocumentState
    @FocusState private var fieldFocused: Bool

    private var matchLabel: String? {
        guard !documentState.findText.isEmpty else { return nil }
        guard let found = documentState.findMatchFound else { return nil }
        if !found { return "Not found" }
        let total = documentState.findTotalCount
        let current = documentState.findCurrentIndex
        guard total > 0 else { return nil }
        return "\(current) of \(total)"
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField("Find", text: $documentState.findText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .focused($fieldFocused)
                .onSubmit { documentState.findNext() }
                .onChange(of: documentState.findText) { newValue in
                    documentState.startFind(query: newValue)
                }

            if let label = matchLabel {
                Text(label)
                    .foregroundColor(documentState.findMatchFound == false ? .red : .secondary)
                    .font(.callout)
                    .frame(minWidth: 52, alignment: .leading)
            }

            Spacer()

            Button(action: { documentState.findPrevious() }) {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(documentState.findText.isEmpty)
            .keyboardShortcut("g", modifiers: [.command, .shift])

            Button(action: { documentState.findNext() }) {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(documentState.findText.isEmpty)
            .keyboardShortcut("g", modifiers: .command)

            Button(action: { documentState.dismissFind() }) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .onAppear { fieldFocused = true }
    }
}
