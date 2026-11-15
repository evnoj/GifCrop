import AppKit
import GifCropShared

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let customRatiosMenu = NSMenu(title: "Custom")
    private var openPanelIsShowing = false
    private var documentsBeingOpened = 0

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
    }

    // Closing the launch Open panel counts as closing the last window, so don't quit while a file is on its way.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !openPanelIsShowing && documentsBeingOpened == 0
    }

    // Like Preview: launching without a file shows the Open panel instead of an empty window.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { true }

    // Also called on reactivation (e.g. a Dock click), which would stack a second panel on the first.
    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        guard !openPanelIsShowing else { return true }
        openPanelIsShowing = true
        NSDocumentController.shared.beginOpenPanel { [weak self] urls in
            self?.open(urls ?? [])
            self?.openPanelIsShowing = false
        }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        open(urls)
    }

    // Quits if nothing ends up open (e.g. the Open panel was cancelled), since there's no window to close.
    private func open(_ urls: [URL]) {
        let controller = NSDocumentController.shared
        let quitIfEmpty = { if controller.documents.isEmpty { NSApp.terminate(nil) } }
        guard !urls.isEmpty else { return quitIfEmpty() }
        for url in urls {
            documentsBeingOpened += 1
            controller.openDocument(withContentsOf: url, display: true) { _, _, error in
                self.documentsBeingOpened -= 1
                guard let error else { return }
                DocumentClosedNotification.post(for: url, error: error.localizedDescription)
                NSApp.presentError(error)
                quitIfEmpty()
            }
        }
    }

    // MARK: Command line tool

    private static let commandLineToolLink = URL(fileURLWithPath: "/usr/local/bin/gifcrop")

    @objc func installCommandLineTool(_ sender: Any?) {
        let tool = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/gifcrop")
        let link = Self.commandLineToolLink
        let fm = FileManager.default

        guard fm.isExecutableFile(atPath: tool.path) else {
            return showAlert("The gifcrop tool is missing from this copy of GifCrop.", style: .critical)
        }
        if let existing = try? fm.destinationOfSymbolicLink(atPath: link.path), existing == tool.path {
            return showAlert("The gifcrop command is already installed.", info: installedInfo)
        }
        if (try? fm.attributesOfItem(atPath: link.path)) != nil {
            let alert = NSAlert()
            alert.messageText = "Replace the existing \(link.path)?"
            alert.informativeText = "Something is already installed there. It will be replaced with a link to the gifcrop tool in this copy of GifCrop."
            alert.addButton(withTitle: "Replace")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        do {
            do {
                try fm.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fm.removeItem(at: link)
                try fm.createSymbolicLink(at: link, withDestinationURL: tool)
            } catch CocoaError.fileWriteNoPermission {
                try Self.linkAsAdministrator(tool: tool, link: link)
            }
            showAlert("The gifcrop command is installed.", info: installedInfo)
        } catch CocoaError.userCancelled {
            return
        } catch {
            NSApp.presentError(error)
        }
    }

    private var installedInfo: String {
        "\(Self.commandLineToolLink.path) links to the gifcrop tool inside \(Bundle.main.bundleURL.path). Run “gifcrop --help” in a new terminal window to get started."
    }

    /// /usr/local/bin is owned by root on a fresh Mac, so fall back to the standard admin password prompt.
    private static func linkAsAdministrator(tool: URL, link: URL) throws {
        func quoted(_ s: String) -> String {
            let escaped = s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            return "quoted form of \"\(escaped)\""
        }
        let dir = link.deletingLastPathComponent().path
        let command = "\"mkdir -p \" & \(quoted(dir)) & \" && ln -sfn \" & \(quoted(tool.path)) & \" \" & \(quoted(link.path))"
        let source = "do shell script \(command) with prompt \"GifCrop wants to install the gifcrop command.\" with administrator privileges"

        var errorInfo: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&errorInfo)
        guard let errorInfo else { return }
        if errorInfo[NSAppleScript.errorNumber] as? Int == -128 {
            throw CocoaError(.userCancelled)
        }
        throw CocoaError(.fileWriteNoPermission, userInfo: [
            NSLocalizedDescriptionKey: "The gifcrop command couldn’t be installed.",
            NSLocalizedFailureReasonErrorKey: errorInfo[NSAppleScript.errorMessage] as? String ?? "",
        ])
    }

    private func showAlert(_ message: String, info: String = "", style: NSAlert.Style = .informational) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.alertStyle = style
        alert.runModal()
    }

    private func makeMainMenu() -> NSMenu {
        let appName = ProcessInfo.processInfo.processName
        let main = NSMenu()

        main.addSubmenu(NSMenu(title: appName), items: [
            item("About \(appName)", #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
            .separator(),
            item("Install Command Line Tool…", #selector(installCommandLineTool(_:))),
            .separator(),
            item("Hide \(appName)", #selector(NSApplication.hide(_:)), "h"),
            item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
            item("Show All", #selector(NSApplication.unhideAllApplications(_:))),
            .separator(),
            item("Quit \(appName)", #selector(NSApplication.terminate(_:)), "q"),
        ])

        main.addSubmenu(NSMenu(title: "File"), items: [
            item("Open…", #selector(NSDocumentController.openDocument(_:)), "o"),
            .separator(),
            item("Close", #selector(NSWindow.performClose(_:)), "w"),
            item("Save", #selector(NSDocument.save(_:)), "s"),
            item("Save As…", #selector(NSDocument.saveAs(_:)), "S"),
            item("Revert to Saved", #selector(NSDocument.revertToSaved(_:))),
        ])

        main.addSubmenu(NSMenu(title: "Edit"), items: [
            item("Undo", Selector(("undo:")), "z"),
            item("Redo", Selector(("redo:")), "Z"),
            .separator(),
            item("Select All", #selector(NSResponder.selectAll(_:)), "a"),
            item("Deselect", #selector(CropView.deselect(_:)), "A"),
        ])

        main.addSubmenu(NSMenu(title: "Tools"), items: [
            item("Crop", #selector(GifWindowController.crop(_:)), "k"),
        ])

        let customItem = NSMenuItem(title: "Custom", action: nil, keyEquivalent: "")
        customItem.submenu = customRatiosMenu
        customRatiosMenu.delegate = self
        main.addSubmenu(NSMenu(title: "Aspect Ratio"), items: [
            item("Unlock Aspect Ratio", #selector(CropView.unlockAspectRatio(_:))),
            item("Lock Current Aspect Ratio", #selector(CropView.lockCurrentAspectRatio(_:))),
            .separator(),
        ] + AspectRatio.landscape.map(ratioItem) + [.separator()]
          + AspectRatio.portrait.map(ratioItem) + [.separator(), customItem])

        let windowMenu = NSMenu(title: "Window")
        main.addSubmenu(windowMenu, items: [
            item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
            item("Zoom", #selector(NSWindow.performZoom(_:))),
            .separator(),
            item("Bring All to Front", #selector(NSApplication.arrangeInFront(_:))),
        ])
        NSApp.windowsMenu = windowMenu

        return main
    }

    private func ratioItem(_ ratio: AspectRatio) -> NSMenuItem {
        let item = NSMenuItem(title: ratio.title, action: #selector(CropView.lockAspectRatio(_:)), keyEquivalent: "")
        item.representedObject = ratio.title
        return item
    }

    // MARK: Custom aspect ratios

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === customRatiosMenu else { return }
        menu.removeAllItems()
        let custom = AspectRatio.custom
        custom.map(ratioItem).forEach(menu.addItem)
        if !custom.isEmpty { menu.addItem(.separator()) }
        menu.addItem(item("Add Custom Aspect Ratio…", #selector(addCustomAspectRatio(_:))))
        if !custom.isEmpty {
            let removeMenu = NSMenu(title: "Remove")
            for ratio in custom {
                let remove = item(ratio.title, #selector(removeCustomAspectRatio(_:)))
                remove.representedObject = ratio.title
                removeMenu.addItem(remove)
            }
            let removeItem = NSMenuItem(title: "Remove", action: nil, keyEquivalent: "")
            removeItem.submenu = removeMenu
            menu.addItem(removeItem)
        }
    }

    @objc func addCustomAspectRatio(_ sender: Any?) {
        let cropView = NSApp.keyWindow?.contentView as? CropView
        let initial = cropView?.selection.flatMap { AspectRatio(reducing: $0.size) } ?? AspectRatio(width: 1, height: 1)!

        let widthField = NSTextField(string: "\(initial.width)")
        let heightField = NSTextField(string: "\(initial.height)")
        let colon = NSTextField(labelWithString: ":")
        for field in [widthField, heightField] {
            field.alignment = .center
            field.widthAnchor.constraint(equalToConstant: 60).isActive = true
        }
        let stack = NSStackView(views: [widthField, colon, heightField])
        stack.frame = NSRect(x: 0, y: 0, width: 160, height: 24)

        let alert = NSAlert()
        alert.messageText = "Add Custom Aspect Ratio"
        alert.informativeText = "Enter the width and height of the ratio."
        alert.accessoryView = stack
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = widthField
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        guard let ratio = AspectRatio(width: widthField.integerValue, height: heightField.integerValue) else {
            NSSound.beep()
            return
        }
        if !AspectRatio.presets.contains(ratio) {
            AspectRatio.custom.append(ratio)
        }
        NSApp.sendAction(#selector(CropView.lockAspectRatio(_:)), to: nil, from: ratioItem(ratio))
    }

    @objc func removeCustomAspectRatio(_ sender: NSMenuItem) {
        guard let title = sender.representedObject as? String, let ratio = AspectRatio(title) else { return }
        AspectRatio.custom.removeAll { $0.title == ratio.title }
    }

    private func item(
        _ title: String, _ action: Selector, _ key: String = "",
        _ modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        return item
    }
}

private extension NSMenu {
    func addSubmenu(_ submenu: NSMenu, items: [NSMenuItem]) {
        items.forEach(submenu.addItem)
        let parent = NSMenuItem()
        parent.submenu = submenu
        addItem(parent)
    }
}
