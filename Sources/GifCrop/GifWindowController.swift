import AppKit

final class GifWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation {
    private let cropView = CropView()
    private var pendingTopLeft: NSPoint?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.contentMinSize = NSSize(width: 160, height: 100)
        window.contentView = cropView
        window.initialFirstResponder = cropView
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var gifDocument: GifDocument? { document as? GifDocument }

    override var document: AnyObject? {
        didSet {
            gifDocument?.onChange = { [weak self] in self?.reload(initial: false) }
            reload(initial: true)
        }
    }

    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        gifDocument?.undoManager
    }

    @objc func crop(_ sender: Any?) {
        guard let doc = gifDocument, let window, let selection = cropView.selection else { return }
        let rectInWindow = cropView.convert(cropView.viewRect(forPixelRect: selection), to: nil)
        let screenRect = window.convertToScreen(rectInWindow)
        pendingTopLeft = NSPoint(x: screenRect.minX, y: screenRect.maxY)
        defer { pendingTopLeft = nil }
        do {
            try doc.crop(to: selection)
        } catch {
            doc.presentError(error, modalFor: window, delegate: nil, didPresent: nil, contextInfo: nil)
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(crop(_:)) {
            return cropView.selection != nil
        }
        return true
    }

    private func reload(initial: Bool) {
        guard let window, let doc = gifDocument, let image = NSImage(data: doc.gifData) else { return }

        let oldScale = cropView.displayScale
        let pixelSize = Self.pixelSize(of: image)
        cropView.setImage(image, pixelSize: pixelSize)
        window.subtitle = "\(Int(pixelSize.width)) × \(Int(pixelSize.height))"

        // Show at actual size (or the current zoom level after a crop), shrunk to fit the screen.
        let visible = (window.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let maxContent = window.contentRect(forFrameRect: visible).size
        let scale = min(initial ? 1 : oldScale,
                        maxContent.width / pixelSize.width,
                        maxContent.height / pixelSize.height)
        let size = NSSize(width: max((pixelSize.width * scale).rounded(), window.contentMinSize.width),
                          height: max((pixelSize.height * scale).rounded(), window.contentMinSize.height))

        if initial {
            window.setContentSize(size)
            window.center()
            return
        }

        // Keep the cropped region where it was on screen.
        let current = window.contentRect(forFrameRect: window.frame)
        let topLeft = pendingTopLeft ?? NSPoint(x: current.minX, y: current.maxY)
        var frame = window.frameRect(forContentRect: NSRect(
            x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height))
        frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
        window.setFrame(frame, display: true, animate: true)
    }

    private static func pixelSize(of image: NSImage) -> CGSize {
        if let rep = image.representations.first, rep.pixelsWide > 0, rep.pixelsHigh > 0 {
            return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        return image.size
    }
}
