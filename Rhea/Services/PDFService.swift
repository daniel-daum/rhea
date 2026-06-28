import PDFKit
import AppKit

enum PDFService {
    static func renderFirstPage(of url: URL) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            guard let document = PDFDocument(url: url),
                  let page = document.page(at: 0) else { return nil }

            let mediaBox = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0
            let width = Int(ceil(mediaBox.width * scale))
            let height = Int(ceil(mediaBox.height * scale))

            guard let ctx = CGContext(
                data: nil,
                width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
            ) else { return nil }

            ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            ctx.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: ctx)

            guard let cgImage = ctx.makeImage() else { return nil }
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            return bitmapRep.representation(using: .png, properties: [:])
        }.value
    }
}
