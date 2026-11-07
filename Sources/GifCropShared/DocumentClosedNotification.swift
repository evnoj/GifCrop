import Foundation

/// Broadcast by the app when a document's window closes (or the file fails to open),
/// so `gifcrop` can wait for the file it opened. The notification's object is the file's resolved path.
public enum DocumentClosedNotification {
    public static let name = Notification.Name("com.evanjohnson.GifCrop.documentClosed")
    public static let errorKey = "error"

    public static func path(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    public static func post(for url: URL, error: String? = nil) {
        DistributedNotificationCenter.default().postNotificationName(
            name, object: path(for: url), userInfo: error.map { [errorKey: $0] }, deliverImmediately: true)
    }
}
