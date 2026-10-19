import Foundation
import CoreGraphics

/// Number of folios (folded sheets) nested together in one signature.
let foliosPerSignature = 8

/// Each folio carries four pages: two on the front of the sheet and two on the back.
let pagesPerSignature = foliosPerSignature * 4

/// One side of a printed sheet: the input page indices placed on the left and
/// right halves. `nil` means that half is blank padding.
struct Spread: Equatable {
    let left: Int?
    let right: Int?
}

enum ImpositionError: LocalizedError {
    case cannotOpen(String)
    case locked(String)
    case emptyDocument
    case cannotCreateOutput(String)

    var errorDescription: String? {
        switch self {
        case .cannotOpen(let path): "Cannot open PDF at \(path)"
        case .locked(let path): "PDF at \(path) is encrypted and locked"
        case .emptyDocument: "Input PDF has no pages"
        case .cannotCreateOutput(let path): "Cannot create output PDF at \(path)"
        }
    }
}

/// Computes the order of spreads for printing `pageCount` pages as signatures of
/// nested folios. The page count is padded up to a whole number of signatures.
///
/// Within a signature of `n` pages (0-based local indices), sheet `s` (0 is the
/// outermost) carries:
///   front: left = n - 1 - 2s, right = 2s
///   back:  left = 2s + 1,     right = n - 2 - 2s
/// Spreads are emitted front then back for each sheet, outermost sheet first,
/// which suits duplex printing flipped on the short edge.
func impose(pageCount: Int) -> [Spread] {
    guard pageCount > 0 else { return [] }
    let signatureCount = (pageCount + pagesPerSignature - 1) / pagesPerSignature
    let n = pagesPerSignature

    // Indices past the end of the input become blank padding.
    func slot(_ index: Int) -> Int? { index < pageCount ? index : nil }

    var spreads: [Spread] = []
    for signature in 0..<signatureCount {
        let base = signature * n
        for sheet in 0..<foliosPerSignature {
            spreads.append(Spread(left: slot(base + n - 1 - 2 * sheet),
                                  right: slot(base + 2 * sheet)))
            spreads.append(Spread(left: slot(base + 2 * sheet + 1),
                                  right: slot(base + n - 2 - 2 * sheet)))
        }
    }
    return spreads
}

/// Summary of a completed imposition, for reporting to the user.
struct ImpositionSummary {
    let inputPages: Int
    let paddedPages: Int
    let signatures: Int
    let outputPages: Int
}

/// Visible size of a page after applying its crop box and rotation.
private func displaySize(of page: CGPDFPage) -> CGSize {
    let box = page.getBoxRect(.cropBox)
    let rotation = ((Int(page.rotationAngle) % 360) + 360) % 360
    return rotation == 90 || rotation == 270
        ? CGSize(width: box.height, height: box.width)
        : box.size
}

/// Draws `page` scaled to fit and centred within `rect`, honouring its rotation.
/// Unlike `CGPDFPage.getDrawingTransform`, this also scales pages up.
private func draw(_ page: CGPDFPage, in rect: CGRect, context: CGContext) {
    let box = page.getBoxRect(.cropBox)
    let size = displaySize(of: page)
    guard size.width > 0, size.height > 0 else { return }
    let scale = min(rect.width / size.width, rect.height / size.height)
    let rotation = CGFloat(((Int(page.rotationAngle) % 360) + 360) % 360)

    context.saveGState()
    context.clip(to: rect)
    context.translateBy(x: rect.midX, y: rect.midY)
    context.scaleBy(x: scale, y: scale)
    // PDF /Rotate is clockwise; Core Graphics rotation is counter-clockwise.
    context.rotate(by: -rotation * .pi / 180)
    context.translateBy(x: -box.midX, y: -box.midY)
    context.drawPDFPage(page)
    context.restoreGState()
}

/// Reads the PDF at `inputURL` and writes the imposed signatures to `outputURL`.
func imposePDF(at inputURL: URL, to outputURL: URL) throws -> ImpositionSummary {
    guard let document = CGPDFDocument(inputURL as CFURL) else {
        throw ImpositionError.cannotOpen(inputURL.path)
    }
    if document.isEncrypted && !document.isUnlocked && !document.unlockWithPassword("") {
        throw ImpositionError.locked(inputURL.path)
    }
    let pageCount = document.numberOfPages
    // CGPDFDocument page numbers are 1-based.
    guard pageCount > 0, let firstPage = document.page(at: 1) else {
        throw ImpositionError.emptyDocument
    }

    // Each half of an output sheet matches the first input page's visible size.
    let half = displaySize(of: firstPage)
    var mediaBox = CGRect(x: 0, y: 0, width: half.width * 2, height: half.height)
    guard let context = CGContext(outputURL as CFURL, mediaBox: &mediaBox, nil) else {
        throw ImpositionError.cannotCreateOutput(outputURL.path)
    }

    let leftRect = CGRect(x: 0, y: 0, width: half.width, height: half.height)
    let rightRect = CGRect(x: half.width, y: 0, width: half.width, height: half.height)
    let spreads = impose(pageCount: pageCount)

    for spread in spreads {
        context.beginPDFPage(nil)
        for (index, rect) in [(spread.left, leftRect), (spread.right, rightRect)] {
            if let index, let page = document.page(at: index + 1) {
                draw(page, in: rect, context: context)
            }
        }
        context.endPDFPage()
    }
    context.closePDF()

    return ImpositionSummary(inputPages: pageCount,
                             paddedPages: spreads.count * 2,
                             signatures: spreads.count / (2 * foliosPerSignature),
                             outputPages: spreads.count)
}
