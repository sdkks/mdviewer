import SwiftUI
import AppKit

final class PickerTextField: NSTextField {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            DispatchQueue.main.async { [weak self] in
                self?.window?.makeFirstResponder(self)
            }
        }
    }
}

// MARK: - NSViewRepresentable wrapping PickerTextField

struct PickerTextFieldRepresentable: NSViewRepresentable {
    @ObservedObject var state: FilePickerState

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeNSView(context: Context) -> PickerTextField {
        let field = PickerTextField()
        field.delegate = context.coordinator
        field.placeholderString = "Type a path… (Tab to complete, ↑↓ to select, Return to open)"
        field.bezelStyle = .squareBezel
        field.isBezeled = false
        field.drawsBackground = false
        field.font = NSFont.systemFont(ofSize: 14)
        field.focusRingType = .none

        context.coordinator.textField = field

        return field
    }

    func updateNSView(_ nsView: PickerTextField, context: Context) {
        if nsView.stringValue != state.inputText {
            nsView.stringValue = state.inputText
        }
    }

    // MARK: - Coordinator (NSTextFieldDelegate)

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let state: FilePickerState
        weak var textField: PickerTextField?

        init(state: FilePickerState) {
            self.state = state
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            state.inputText = field.stringValue
            state.enumerateForCurrentInput()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertTab(_:)):
                state.tabComplete(); return true
            case #selector(NSResponder.moveDown(_:)):
                state.selectNext(); return true
            case #selector(NSResponder.moveUp(_:)):
                state.selectPrev(); return true
            case #selector(NSResponder.insertNewline(_:)):
                state.commit(); return true
            case #selector(NSResponder.cancelOperation(_:)):
                state.dismiss(); return true
            default:
                return false
            }
        }
    }
}

// MARK: - Suggestion row view

private struct CandidateRowView: View {
    let candidate: PathCandidate
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if isSelected {
                Rectangle()
                    .frame(width: 4)
                    .foregroundColor(.accentColor)
            } else {
                Rectangle()
                    .frame(width: 4)
                    .foregroundColor(.clear)
            }

            if candidate.isDirectory {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
                    .frame(width: 16)
            } else {
                Image(systemName: "doc.text")
                    .foregroundColor(.primary)
                    .frame(width: 16)
            }

            highlightedName(
                candidate.displayName,
                indices: Set(candidate.matchedIndices),
                defaultColor: candidate.isDirectory ? .secondary : .primary,
                isDirectory: candidate.isDirectory
            )
            .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.trailing, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityLabel(candidate.isDirectory
            ? "\(candidate.displayName) directory"
            : "\(candidate.displayName) markdown file")
    }

    private func highlightedName(_ name: String, indices: Set<Int>, defaultColor: Color, isDirectory: Bool) -> Text {
        var result = Text("")
        var currentIndex = name.startIndex
        while currentIndex < name.endIndex {
            let offset = name.distance(from: name.startIndex, to: currentIndex)
            let isMatch = indices.contains(offset)
            var endIndex = currentIndex
            while endIndex < name.endIndex {
                let endOffset = name.distance(from: name.startIndex, to: endIndex)
                if indices.contains(endOffset) != isMatch { break }
                name.formIndex(after: &endIndex)
            }
            let chunk = String(name[currentIndex..<endIndex])
            let text: Text
            if isMatch {
                text = Text(chunk)
                    .foregroundColor(.accentColor)
                    .font(.body.weight(.bold))
            } else {
                text = Text(chunk)
                    .foregroundColor(defaultColor)
                    .font(isDirectory ? .body.weight(.semibold) : .body)
            }
            result = result + text
            currentIndex = endIndex
        }
        return result
    }
}

// MARK: - Main FilePickerView

struct FilePickerView: View {
    @ObservedObject var state: FilePickerState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Text field area
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                PickerTextFieldRepresentable(state: state)
                    .frame(height: 22)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if !state.candidates.isEmpty {
                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(state.candidates.enumerated()), id: \.element.id) { index, candidate in
                                CandidateRowView(
                                    candidate: candidate,
                                    isSelected: state.selectedIndex == index,
                                    onTap: { state.commit(candidate: candidate) }
                                )
                                .id(index)
                            }
                        }
                    }
                    .frame(maxHeight: 360)
                    .onChange(of: state.selectedIndex, perform: { idx in
                        if let idx {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.1)) {
                                proxy.scrollTo(idx, anchor: .center)
                            }
                        }
                    })
                }
            }
        }
        .frame(width: 520)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
        .accessibilityLabel("Open File")
        .accessibilityValue("\(state.candidates.count) results")
    }
}
