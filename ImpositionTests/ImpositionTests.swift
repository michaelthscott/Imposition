//
//  ImpositionTests.swift
//  ImpositionTests
//
//  Created by Michael Scott on 19/10/2026.
//

import Testing
import Foundation
import CoreGraphics

// Imposition.swift is compiled into this test target directly (a command-line
// tool can't be imported by a test bundle), so its declarations are in scope.

/// Converts spreads to 1-based page numbers, with `nil` for blanks, for readable comparisons.
private func pageNumbers(_ spreads: [Spread]) -> [[Int?]] {
    spreads.map { [$0.left.map { $0 + 1 }, $0.right.map { $0 + 1 }] }
}

struct PageOrderTests {

    @Test func singleSignatureOrder() {
        let expected: [[Int?]] = [
            [32, 1], [2, 31], [30, 3], [4, 29], [28, 5], [6, 27], [26, 7], [8, 25],
            [24, 9], [10, 23], [22, 11], [12, 21], [20, 13], [14, 19], [18, 15], [16, 17],
        ]
        #expect(pageNumbers(impose(pageCount: 32)) == expected)
    }

    @Test func emptyDocumentHasNoSpreads() {
        #expect(impose(pageCount: 0).isEmpty)
    }

    @Test(arguments: [1, 31, 32, 33, 64, 65, 100])
    func padsToWholeSignatures(pageCount: Int) {
        let signatures = (pageCount + 31) / 32
        #expect(impose(pageCount: pageCount).count == signatures * 16)
    }

    @Test(arguments: [1, 17, 32, 33, 64, 100])
    func everyPageAppearsExactlyOnce(pageCount: Int) {
        let pages = impose(pageCount: pageCount)
            .flatMap { [$0.left, $0.right] }
            .compactMap { $0 }
        #expect(pages.sorted() == Array(0..<pageCount))
    }

    @Test func paddingIsBlank() {
        // 33 pages: the second signature holds only page 33, on the front of its outer sheet.
        let second = Array(pageNumbers(impose(pageCount: 33))[16...])
        #expect(second.first == [nil, 33])
        #expect(second.dropFirst().allSatisfy { $0 == [nil, nil] })
    }

    @Test(arguments: [32, 96])
    func facingPagesSumToSignatureEnd(pageCount: Int) throws {
        // On every side of every sheet, the two local page indices add up to 31.
        for (index, spread) in impose(pageCount: pageCount).enumerated() {
            let base = (index / 16) * 32
            let left = try #require(spread.left) - base
            let right = try #require(spread.right) - base
            #expect(left + right == 31)
        }
    }
}

struct PDFOutputTests {

    /// Writes a PDF with `count` blank pages of the given size and returns its URL.
    private func makePDF(pages count: Int, size: CGSize) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImpositionTests-\(UUID().uuidString).pdf")
        var box = CGRect(origin: .zero, size: size)
        let context = try #require(CGContext(url as CFURL, mediaBox: &box, nil))
        for _ in 0..<count {
            context.beginPDFPage(nil)
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }

    @Test func writesDoubleWidthSpreads() throws {
        let input = try makePDF(pages: 40, size: CGSize(width: 420, height: 595))
        let output = input.deletingPathExtension().appendingPathExtension("imposition.pdf")
        defer {
            try? FileManager.default.removeItem(at: input)
            try? FileManager.default.removeItem(at: output)
        }

        let summary = try imposePDF(at: input, to: output)
        #expect(summary.inputPages == 40)
        #expect(summary.paddedPages == 64)
        #expect(summary.signatures == 2)
        #expect(summary.outputPages == 32)

        let document = try #require(CGPDFDocument(output as CFURL))
        #expect(document.numberOfPages == 32)
        let mediaBox = try #require(document.page(at: 1)).getBoxRect(.mediaBox)
        #expect(mediaBox.size == CGSize(width: 840, height: 595))
    }

    @Test func missingInputThrows() {
        let missing = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).pdf")
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("unused.pdf")
        #expect(throws: ImpositionError.self) {
            try imposePDF(at: missing, to: output)
        }
    }
}
