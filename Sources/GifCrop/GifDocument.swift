import AppKit

@objc(GifDocument)
final class GifDocument: NSDocument {
    private(set) var gifData = Data()
    var onChange: (() -> Void)?

    // Explicit Save / Save As, so the original file is only overwritten when the user asks.
    override class var autosavesInPlace: Bool { false }

    override func makeWindowControllers() {
        addWindowController(GifWindowController())
    }

    override func data(ofType typeName: String) throws -> Data {
        gifData
    }

    override func read(from data: Data, ofType typeName: String) throws {
        guard NSImage(data: data) != nil else {
            throw CocoaError(.fileReadCorruptFile)
        }
        gifData = data
        onChange?()
    }

    override func revert(toContentsOf url: URL, ofType typeName: String) throws {
        try super.revert(toContentsOf: url, ofType: typeName)
        undoManager?.removeAllActions()
    }

    func crop(to rect: CGRect) throws {
        replaceData(with: try Gifsicle.crop(gifData, to: rect), actionName: "Crop")
    }

    private func replaceData(with data: Data, actionName: String) {
        let previous = gifData
        undoManager?.registerUndo(withTarget: self) { doc in
            doc.replaceData(with: previous, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
        gifData = data
        onChange?()
    }
}
