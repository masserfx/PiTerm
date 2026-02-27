#if os(iOS)
import SwiftUI
import SwiftTerm
import UIKit

/// UIViewRepresentable wrapper for SwiftTerm's TerminalView
struct TerminalRepresentable: UIViewRepresentable {
    let onData: (Data) -> Void
    let onSizeChanged: (Int, Int) -> Void

    @Binding var terminalView: TerminalViewReference?

    func makeUIView(context: Context) -> TerminalView {
        let terminal = TerminalView(frame: .zero)
        terminal.terminalDelegate = context.coordinator

        let fontSize: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 14 : 12
        terminal.font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        DispatchQueue.main.async {
            self.terminalView = TerminalViewReference(view: terminal)
        }

        return terminal
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onData: onData, onSizeChanged: onSizeChanged)
    }

    class Coordinator: NSObject, TerminalViewDelegate {
        let onData: (Data) -> Void
        let onSizeChanged: (Int, Int) -> Void

        init(onData: @escaping (Data) -> Void, onSizeChanged: @escaping (Int, Int) -> Void) {
            self.onData = onData
            self.onSizeChanged = onSizeChanged
        }

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            onData(Data(data))
        }

        func scrolled(source: TerminalView, position: Double) {}
        func setTerminalTitle(source: TerminalView, title: String) {}

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            onSizeChanged(newCols, newRows)
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func bell(source: TerminalView) {}
        func clipboardCopy(source: TerminalView, content: Data) {}
        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}

        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
            guard let url = URL(string: link) else { return }
            Task { @MainActor in
                UIApplication.shared.open(url)
            }
        }
    }
}

/// Reference wrapper to allow feeding data into the terminal from SwiftUI
@Observable
@MainActor
class TerminalViewReference {
    private(set) weak var view: TerminalView?

    init(view: TerminalView) {
        self.view = view
    }

    func feed(data: Data) {
        let bytes = ArraySlice([UInt8](data))
        view?.feed(byteArray: bytes)
    }

    func feed(text: String) {
        view?.feed(text: text)
    }

    var terminalSize: (cols: Int, rows: Int) {
        guard let terminal = view?.getTerminal() else {
            return (80, 24)
        }
        return (terminal.cols, terminal.rows)
    }
}
#endif
