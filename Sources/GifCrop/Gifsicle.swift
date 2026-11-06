import Foundation

enum Gifsicle {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { "The GIF couldn’t be cropped." }
        var failureReason: String? { message }
    }

    static func crop(_ gif: Data, to rect: CGRect) throws -> Data {
        guard let executable = Bundle.main.url(forAuxiliaryExecutable: "gifsicle") else {
            throw Failure(message: "gifsicle was not found in the app bundle.")
        }

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GifCrop-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let input = temp.appendingPathComponent("in.gif")
        let output = temp.appendingPathComponent("out.gif")
        try gif.write(to: input)

        let process = Process()
        process.executableURL = executable
        process.arguments = [
            "--crop", "\(Int(rect.minX)),\(Int(rect.minY))+\(Int(rect.width))x\(Int(rect.height))",
            "-o", output.path, input.path,
        ]
        let stderr = Pipe()
        process.standardError = stderr
        try process.run()
        let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw Failure(message: String(decoding: errorOutput, as: UTF8.self))
        }
        return try Data(contentsOf: output)
    }
}
