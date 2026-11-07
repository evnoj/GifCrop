import AppKit
import ArgumentParser
import GifCropShared

@main
struct GifCropCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gifcrop",
        abstract: "Open a GIF in GifCrop and wait until its window is closed.",
        discussion: """
            Opens <file> in the GifCrop app, launching it if it isn't already running, \
            then waits. When you close the window showing <file>, or quit GifCrop, \
            gifcrop exits with status 0. If the file can't be opened, it exits with status 1.

            Because it waits, gifcrop works like an editor command: a script can open a GIF, \
            let you crop it, and carry on once you're done.

            In GifCrop: drag to select an area, ⌘K to crop, ⌘Z to undo, \
            ⌘S to save in place, ⇧⌘S to save to a new file.

            Examples:
              gifcrop animation.gif
              gifcrop animation.gif && gifsicle --info animation.gif
            """)

    @Argument(
        help: ArgumentHelp("The GIF file to open.", valueName: "file"),
        completion: .file(extensions: ["gif"]))
    var file: String

    func validate() throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: file, isDirectory: &isDirectory) else {
            throw ValidationError("No such file: \(file)")
        }
        guard !isDirectory.boolValue else {
            throw ValidationError("\(file) is a directory, not a GIF.")
        }
    }

    func run() throws {
        let fileURL = URL(fileURLWithPath: file)
        let appURL = try Self.locateApp()
        var appPID: pid_t?

        // Subscribe before opening so the close can't be missed.
        DistributedNotificationCenter.default().addObserver(
            forName: DocumentClosedNotification.name,
            object: DocumentClosedNotification.path(for: fileURL),
            queue: .main
        ) { note in
            if let error = note.userInfo?[DocumentClosedNotification.errorKey] as? String {
                Self.fail(error)
            }
            Darwin.exit(0)
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if let app, app.processIdentifier == appPID {
                Darwin.exit(0)
            }
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: configuration) { app, error in
            DispatchQueue.main.async {
                if let error {
                    Self.fail("Couldn't open \(file) in GifCrop: \(error.localizedDescription)")
                }
                appPID = app?.processIdentifier
            }
        }

        RunLoop.main.run()
    }

    /// The GifCrop.app this tool ships in (following the /usr/local/bin symlink),
    /// falling back to wherever Launch Services knows GifCrop to be installed.
    private static func locateApp() throws -> URL {
        if let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() {
            let app = executable
                .deletingLastPathComponent()  // Helpers
                .deletingLastPathComponent()  // Contents
                .deletingLastPathComponent()
            if app.pathExtension == "app" {
                return app
            }
        }
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.evanjohnson.GifCrop") {
            return app
        }
        throw ValidationError("Couldn't find GifCrop.app.")
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("gifcrop: \(message)\n".utf8))
        Darwin.exit(1)
    }
}
