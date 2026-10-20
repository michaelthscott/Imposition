import Foundation

// imposition — rearranges a PDF's pages into signatures of 8 nested folios
// (32 pages each), two pages per side of each sheet, ready for duplex
// printing flipped on the short edge.

let toolName = "imposition"
let toolVersion = "1.1.0"
let arguments = Array(CommandLine.arguments.dropFirst())

if arguments == ["--version"] {
    print("\(toolName) \(toolVersion)")
    exit(0)
}

guard (1...2).contains(arguments.count), !arguments.contains(where: { $0 == "-h" || $0 == "--help" }) else {
    let usage = "Usage: \(toolName) <input.pdf> [output.pdf]\n       \(toolName) --version\n"
    FileHandle.standardError.write(Data(usage.utf8))
    exit(1)
}

let inputURL = URL(fileURLWithPath: arguments[0])
let outputURL: URL
if arguments.count == 2 {
    outputURL = URL(fileURLWithPath: arguments[1])
} else {
    // Default: "<input>-imposition.pdf" alongside the input.
    let baseName = inputURL.deletingPathExtension().lastPathComponent
    outputURL = inputURL.deletingLastPathComponent()
        .appendingPathComponent("\(baseName)-imposition.pdf")
}

do {
    let summary = try imposePDF(at: inputURL, to: outputURL)
    print("""
    Input pages:  \(summary.inputPages)
    Padded pages: \(summary.paddedPages) (\(summary.paddedPages - summary.inputPages) blank)
    Signatures:   \(summary.signatures) of \(foliosPerSignature) folios
    Output pages: \(summary.outputPages)
    Wrote \(outputURL.path)
    """)
} catch {
    FileHandle.standardError.write(Data("\(toolName): \(error.localizedDescription)\n".utf8))
    exit(1)
}
