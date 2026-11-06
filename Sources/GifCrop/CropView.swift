import AppKit

/// Shows the animated GIF and lets the user drag out a crop rectangle, Preview-style.
/// The selection is stored in GIF pixel coordinates (top-left origin), so it survives window resizes.
final class CropView: NSView, NSMenuItemValidation {
    private struct Handle {
        let dx: Int  // -1 = left edge, 0 = middle, 1 = right edge
        let dy: Int  // -1 = top edge, 0 = middle, 1 = bottom edge
    }

    private enum Drag {
        case create(anchor: CGPoint)
        case move(start: CGPoint, original: CGRect)
        case resize(handle: Handle, original: CGRect)
    }

    // Corners first so they win over edge handles on tiny selections.
    private static let handles = [(-1, -1), (1, -1), (-1, 1), (1, 1), (0, -1), (-1, 0), (1, 0), (0, 1)]
        .map(Handle.init)
    private static let handleRadius: CGFloat = 4
    private static let handleHitRadius: CGFloat = 7

    private let imageView = NSImageView()
    private let overlay = OverlayView()
    private(set) var pixelSize = CGSize.zero
    private(set) var selection: CGRect? {
        didSet { selectionDidChange() }
    }
    private(set) var aspectRatio: AspectRatio?
    private var drag: Drag?
    private var antPhase: CGFloat = 0
    private var antTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView.imageScaling = .scaleAxesIndependently
        imageView.animates = true
        imageView.isEditable = false
        addSubview(imageView)
        overlay.cropView = self
        addSubview(overlay)
        addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseMoved, .cursorUpdate, .activeInKeyWindow, .inVisibleRect],
            owner: self))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // All mouse events go to this view rather than its subviews.
    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) != nil ? self : nil
    }

    func setImage(_ image: NSImage, pixelSize: CGSize) {
        imageView.image = image
        self.pixelSize = pixelSize
        selection = nil
        needsLayout = true
    }

    override func layout() {
        super.layout()
        imageView.frame = imageRect
        overlay.frame = bounds
        overlay.needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.underPageBackgroundColor.setFill()
        dirtyRect.fill()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            antTimer?.invalidate()
            antTimer = nil
        }
    }

    // MARK: Geometry

    var imageRect: CGRect {
        guard pixelSize.width > 0, pixelSize.height > 0 else { return .zero }
        let scale = min(bounds.width / pixelSize.width, bounds.height / pixelSize.height)
        let size = CGSize(width: pixelSize.width * scale, height: pixelSize.height * scale)
        return CGRect(
            x: ((bounds.width - size.width) / 2).rounded(), y: ((bounds.height - size.height) / 2).rounded(),
            width: size.width, height: size.height)
    }

    var displayScale: CGFloat {
        pixelSize.width > 0 ? imageRect.width / pixelSize.width : 1
    }

    func viewRect(forPixelRect rect: CGRect) -> CGRect {
        let origin = imageRect.origin
        let scale = displayScale
        return CGRect(
            x: origin.x + rect.minX * scale, y: origin.y + rect.minY * scale,
            width: rect.width * scale, height: rect.height * scale)
    }

    private func pixelPoint(_ point: CGPoint, clamped: Bool = true) -> CGPoint {
        let origin = imageRect.origin
        let scale = displayScale
        var x = ((point.x - origin.x) / scale).rounded()
        var y = ((point.y - origin.y) / scale).rounded()
        if clamped {
            x = min(max(x, 0), pixelSize.width)
            y = min(max(y, 0), pixelSize.height)
        }
        return CGPoint(x: x, y: y)
    }

    private func rect(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    /// A locked ratio wins; otherwise Shift constrains to a square.
    private func activeRatio(for event: NSEvent) -> CGFloat? {
        if let aspectRatio { return aspectRatio.value }
        return event.modifierFlags.contains(.shift) ? 1 : nil
    }

    /// The rect of the given ratio with one corner at `anchor`, following `q` and staying inside the image.
    private func constrainedRect(anchor a: CGPoint, to q: CGPoint, ratio r: CGFloat) -> CGRect {
        let dx = q.x - a.x, dy = q.y - a.y
        let availableWidth = dx < 0 ? a.x : pixelSize.width - a.x
        let availableHeight = dy < 0 ? a.y : pixelSize.height - a.y
        let w = min(max(abs(dx), abs(dy) * r), availableWidth, availableHeight * r)
        let size = CGSize(width: w.rounded(), height: (w / r).rounded())
        return CGRect(x: dx < 0 ? a.x - size.width : a.x, y: dy < 0 ? a.y - size.height : a.y,
                      width: size.width, height: size.height)
    }

    /// Dragging an edge handle with a locked ratio: the opposite edge stays put and the other axis grows from the center.
    private func constrainedEdgeRect(handle: Handle, original o: CGRect, to q: CGPoint, ratio r: CGFloat) -> CGRect {
        let W = pixelSize.width, H = pixelSize.height
        if handle.dy == 0 {
            let fixed = handle.dx == 1 ? o.minX : o.maxX
            let d = q.x - fixed
            let w = min(abs(d), d < 0 ? fixed : W - fixed, H * r)
            let h = (w / r).rounded()
            let y = min(max((o.midY - h / 2).rounded(), 0), H - h)
            return CGRect(x: d < 0 ? fixed - w.rounded() : fixed, y: y, width: w.rounded(), height: h)
        } else {
            let fixed = handle.dy == 1 ? o.minY : o.maxY
            let d = q.y - fixed
            let h = min(abs(d), d < 0 ? fixed : H - fixed, W / r)
            let w = (h * r).rounded()
            let x = min(max((o.midX - w / 2).rounded(), 0), W - w)
            return CGRect(x: x, y: d < 0 ? fixed - h.rounded() : fixed, width: w, height: h.rounded())
        }
    }

    /// Reshapes the selection (or the whole image) to the ratio, keeping its area and center where possible.
    private func fitSelection(to ratio: AspectRatio) {
        guard pixelSize != .zero else { return }
        let base = selection ?? CGRect(origin: .zero, size: pixelSize)
        let r = ratio.value
        var w = (base.width * base.height * r).squareRoot()
        var h = w / r
        let shrink = min(1, pixelSize.width / w, pixelSize.height / h)
        w = max((w * shrink).rounded(), 1)
        h = max((h * shrink).rounded(), 1)
        let x = min(max((base.midX - w / 2).rounded(), 0), pixelSize.width - w)
        let y = min(max((base.midY - h / 2).rounded(), 0), pixelSize.height - h)
        selection = CGRect(x: x, y: y, width: w, height: h)
    }

    private func handlePoint(_ handle: Handle, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX + CGFloat(handle.dx) * rect.width / 2,
                y: rect.midY + CGFloat(handle.dy) * rect.height / 2)
    }

    private func handle(at point: CGPoint, in rect: CGRect) -> Handle? {
        Self.handles.first {
            let p = handlePoint($0, in: rect)
            return hypot(p.x - point.x, p.y - point.y) <= Self.handleHitRadius
        }
    }

    private func location(of event: NSEvent) -> CGPoint {
        convert(event.locationInWindow, from: nil)
    }

    // MARK: Actions

    override func selectAll(_ sender: Any?) {
        guard pixelSize != .zero else { return }
        selection = CGRect(origin: .zero, size: pixelSize)
    }

    @objc func deselect(_ sender: Any?) {
        selection = nil
    }

    @objc func lockAspectRatio(_ sender: NSMenuItem) {
        guard let title = sender.representedObject as? String, let ratio = AspectRatio(title) else { return }
        aspectRatio = ratio
        fitSelection(to: ratio)
    }

    @objc func lockCurrentAspectRatio(_ sender: Any?) {
        guard let selection else { return }
        aspectRatio = AspectRatio(reducing: selection.size)
    }

    @objc func unlockAspectRatio(_ sender: Any?) {
        aspectRatio = nil
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(lockAspectRatio(_:)):
            let ratio = (menuItem.representedObject as? String).flatMap { AspectRatio($0) }
            menuItem.state = ratio != nil && ratio == aspectRatio ? .on : .off
            return pixelSize != .zero
        case #selector(lockCurrentAspectRatio(_:)):
            let isCustomLock = aspectRatio.map { !AspectRatio.presets.contains($0) } ?? false
            menuItem.title = isCustomLock ? "Lock Current Aspect Ratio (\(aspectRatio!.title))" : "Lock Current Aspect Ratio"
            menuItem.state = isCustomLock ? .on : .off
            return selection != nil
        case #selector(unlockAspectRatio(_:)):
            menuItem.state = aspectRatio == nil ? .on : .off
            return true
        default:
            return true
        }
    }

    override func cancelOperation(_ sender: Any?) {
        selection = nil
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // Escape
            selection = nil
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        guard pixelSize != .zero else { return }
        window?.makeFirstResponder(self)
        let p = location(of: event)

        if let selection {
            let r = viewRect(forPixelRect: selection)
            if let handle = handle(at: p, in: r) {
                drag = .resize(handle: handle, original: selection)
                return
            }
            if r.contains(p) {
                drag = .move(start: pixelPoint(p, clamped: false), original: selection)
                NSCursor.closedHand.set()
                return
            }
        }
        drag = .create(anchor: pixelPoint(p))
        selection = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let drag else { return }
        let p = location(of: event)

        switch drag {
        case .create(let anchor):
            let q = pixelPoint(p)
            if let ratio = activeRatio(for: event) {
                selection = constrainedRect(anchor: anchor, to: q, ratio: ratio)
            } else {
                selection = rect(anchor, q)
            }

        case .move(let start, let original):
            let q = pixelPoint(p, clamped: false)
            let x = min(max(original.minX + q.x - start.x, 0), pixelSize.width - original.width)
            let y = min(max(original.minY + q.y - start.y, 0), pixelSize.height - original.height)
            selection = CGRect(origin: CGPoint(x: x, y: y), size: original.size)

        case .resize(let handle, let original):
            let q = pixelPoint(p)
            if let ratio = activeRatio(for: event) {
                if handle.dx != 0 && handle.dy != 0 {
                    let anchor = CGPoint(x: handle.dx == 1 ? original.minX : original.maxX,
                                         y: handle.dy == 1 ? original.minY : original.maxY)
                    selection = constrainedRect(anchor: anchor, to: q, ratio: ratio)
                } else {
                    selection = constrainedEdgeRect(handle: handle, original: original, to: q, ratio: ratio)
                }
                return
            }
            let a = CGPoint(x: handle.dx == -1 ? q.x : original.minX, y: handle.dy == -1 ? q.y : original.minY)
            let b = CGPoint(x: handle.dx == 1 ? q.x : original.maxX, y: handle.dy == 1 ? q.y : original.maxY)
            selection = rect(a, b)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if let selection, selection.width < 1 || selection.height < 1 {
            self.selection = nil
        }
        drag = nil
        updateCursor(at: location(of: event))
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(at: location(of: event))
    }

    override func cursorUpdate(with event: NSEvent) {
        updateCursor(at: location(of: event))
    }

    private func updateCursor(at point: CGPoint) {
        if let selection {
            let r = viewRect(forPixelRect: selection)
            if let handle = handle(at: point, in: r) {
                cursor(for: handle).set()
                return
            }
            if r.contains(point) {
                NSCursor.openHand.set()
                return
            }
        }
        NSCursor.crosshair.set()
    }

    private func cursor(for handle: Handle) -> NSCursor {
        if #available(macOS 15, *) {
            let position: NSCursor.FrameResizePosition
            switch (handle.dx, handle.dy) {
            case (-1, -1): position = .topLeft
            case (0, -1): position = .top
            case (1, -1): position = .topRight
            case (-1, 0): position = .left
            case (1, 0): position = .right
            case (-1, 1): position = .bottomLeft
            case (0, 1): position = .bottom
            default: position = .bottomRight
            }
            return .frameResize(position: position, directions: .all)
        }
        if handle.dx == 0 { return .resizeUpDown }
        if handle.dy == 0 { return .resizeLeftRight }
        return .crosshair
    }

    // MARK: Drawing

    private func selectionDidChange() {
        overlay.needsDisplay = true
        if selection == nil {
            antTimer?.invalidate()
            antTimer = nil
        } else if antTimer == nil {
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self else { return }
                antPhase = (antPhase + 1).truncatingRemainder(dividingBy: 8)
                overlay.needsDisplay = true
            }
            RunLoop.main.add(timer, forMode: .common)
            antTimer = timer
        }
    }

    fileprivate func drawOverlay() {
        guard let selection, selection.width > 0 || selection.height > 0 else { return }
        let r = viewRect(forPixelRect: selection)

        let dimmed = NSBezierPath(rect: imageRect)
        dimmed.append(NSBezierPath(rect: r))
        dimmed.windingRule = .evenOdd
        NSColor(white: 0, alpha: 0.45).setFill()
        dimmed.fill()

        let border = NSBezierPath(rect: r.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        NSColor.white.setStroke()
        border.stroke()
        border.setLineDash([4, 4], count: 2, phase: antPhase)
        NSColor.black.setStroke()
        border.stroke()

        for handle in Self.handles {
            let c = handlePoint(handle, in: r)
            let radius = Self.handleRadius
            let dot = NSBezierPath(ovalIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
            NSColor.white.setFill()
            dot.fill()
            NSColor.darkGray.setStroke()
            dot.lineWidth = 1
            dot.stroke()
        }

        drawDimensions(of: selection, near: r)
    }

    private func drawDimensions(of selection: CGRect, near r: CGRect) {
        let text = "\(Int(selection.width)) × \(Int(selection.height))" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let textSize = text.size(withAttributes: attributes)
        var box = CGRect(x: r.maxX + 8, y: r.maxY + 8, width: textSize.width + 12, height: textSize.height + 4)
        box.origin.x = max(min(box.minX, bounds.maxX - box.width - 4), 4)
        box.origin.y = max(min(box.minY, bounds.maxY - box.height - 4), 4)

        NSColor(white: 0, alpha: 0.7).setFill()
        NSBezierPath(roundedRect: box, xRadius: 4, yRadius: 4).fill()
        text.draw(at: CGPoint(x: box.minX + 6, y: box.minY + 2), withAttributes: attributes)
    }
}

private final class OverlayView: NSView {
    weak var cropView: CropView?

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        cropView?.drawOverlay()
    }
}
