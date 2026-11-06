import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let customRatiosMenu = NSMenu(title: "Custom")

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // Like Preview: launching without a file shows the Open panel instead of an empty window.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { true }

    // Quits if the panel is cancelled (or nothing could be opened), since there's no window to close.
    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        let controller = NSDocumentController.shared
        let quitIfEmpty = { if controller.documents.isEmpty { NSApp.terminate(nil) } }
        controller.beginOpenPanel { urls in
            guard let urls, !urls.isEmpty else { return quitIfEmpty() }
            for url in urls {
                controller.openDocument(withContentsOf: url, display: true) { _, _, error in
                    if let error { NSApp.presentError(error) }
                    quitIfEmpty()
                }
            }
        }
        return true
    }

    private func makeMainMenu() -> NSMenu {
        let appName = ProcessInfo.processInfo.processName
        let main = NSMenu()

        main.addSubmenu(NSMenu(title: appName), items: [
            item("About \(appName)", #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
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
