# Imposition

`imposition` is a macOS command-line tool that rearranges the pages of a PDF
so they can be printed, folded and bound into a book.

## What it's for

To bind a book by hand (for example, a sewn or perfect-bound hardback), you
print several pages on each sheet of paper, fold the sheets in half, and nest
them inside one another to form a *signature*. Then you stack and sew the
signatures together to make the book block.

Only one arrangement of pages works: once the sheets are folded and nested,
the pages have to read in order. Laying out the pages in that arrangement is
called *imposition*. `imposition` does it for you. You give it an ordinary PDF
with one page per page, and it writes a new PDF ready to send to a duplex
printer.

## How it works

- **Signatures of 8 folios.** Each signature is 8 sheets of paper nested
  together. Each sheet (folio) carries 4 pages, two on the front and two on
  the back, so a signature holds 32 pages.
- **Padding.** If the page count isn't a multiple of 32, the tool adds blank
  pages at the end to fill the last signature.
- **Two pages per side.** Each output page is a spread twice the width of
  the first input page, with one input page on the left half and one on the
  right. Input pages of other sizes are scaled to fit and centred, and page
  rotation is respected.
- **Print order.** Spreads are written front, then back, for each sheet,
  starting with the outermost sheet of each signature.

For the first signature, the first few output pages contain:

| Output page | Sheet | Side | Left | Right |
| --- | --- | --- | --- | --- |
| 1 | 1 (outermost) | Front | 32 | 1 |
| 2 | 1 (outermost) | Back | 2 | 31 |
| 3 | 2 | Front | 30 | 3 |
| 4 | 2 | Back | 4 | 29 |
| … | … | … | … | … |
| 15 | 8 (innermost) | Front | 18 | 15 |
| 16 | 8 (innermost) | Back | 16 | 17 |

## Usage

```
imposition <input.pdf> [output.pdf]
imposition --version
```

If you don't give an output path, the tool writes `<input>-imposition.pdf` next
to the input file:

```
$ imposition novel.pdf
Input pages:  70
Padded pages: 96 (26 blank)
Signatures:   3 of 8 folios
Output pages: 48
Wrote /Users/me/Documents/novel-imposition.pdf
```

### Printing

1. Print the output PDF **double-sided, flipped on the short edge**, at
   100% scale (or "fit to page" if your paper is a different size).
2. Take the sheets in groups of 8. Each group is one signature.
3. Fold each group in half along the middle, keeping the sheets in order.
4. Stack the signatures in order, then sew or glue them into the binding.

Encrypted PDFs are supported only if they open without a password.

## Building

You need Xcode on a Mac running macOS 26.3 or later.

### From the command line

Run this from the project folder to make a Release build:

```
xcodebuild -project Imposition.xcodeproj -scheme Imposition \
    -configuration Release -destination 'platform=macOS' \
    -derivedDataPath build
```

The tool is written to `build/Build/Products/Release/imposition`, inside the
project folder. To use it from anywhere, copy it into a folder on your `PATH`:

```
sudo cp build/Build/Products/Release/imposition /usr/local/bin/
```

### In Xcode

Open `Imposition.xcodeproj` and choose the **Imposition** scheme.

- **Product › Build** (⌘B) makes a Debug build in Xcode's DerivedData folder,
  not in the project folder. Choose **Product › Show Build Folder in Finder**
  and look in `Products/Debug/imposition`.
- **Product › Archive** makes a Release build. In the Organizer, right-click
  the archive, choose **Show in Finder**, then **Show Package Contents**. The
  tool is at `Products/usr/local/bin/imposition`.

### Tests

The tests use Swift Testing. Run them in Xcode with **Product › Test** (⌘U).

## License

MIT. See [LICENSE](LICENSE).
