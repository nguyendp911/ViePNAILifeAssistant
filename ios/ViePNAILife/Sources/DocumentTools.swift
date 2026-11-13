import Foundation
import PDFKit
import UIKit

/// PDF extraction and export occur on device. No file is uploaded automatically.
enum DocumentTools {
    static func extractPDF(_ data: Data, maxPages: Int = 150) throws -> String {
        guard data.count <= 25_000_000, let document = PDFDocument(data: data) else {
            throw APIError.text("PDF không hợp lệ hoặc vượt quá 25 MB.")
        }
        guard document.pageCount <= maxPages else {
            throw APIError.text("Tài liệu vượt quá \(maxPages) trang.")
        }
        let result = (0..<document.pageCount).map { index in
            "[Trang \(index + 1)]\n" + (document.page(at: index)?.string ?? "")
        }.joined(separator: "\n\n")
        guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.text("PDF không có lớp văn bản. Hãy dùng OCR ảnh để nhận dạng.")
        }
        return result
    }
    @MainActor
    static func createPDF(title: String, text: String) throws -> URL {
        guard !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else {
            throw APIError.text("Chưa có nội dung để xuất PDF.")
        }
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 48
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let data = renderer.pdfData { context in
            var y: CGFloat = 52
            func newPage() {
                context.beginPage()
                y = 52
            }
            newPage()
            let titleStyle: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20), .foregroundColor: UIColor.black
            ]
            let titleBox = NSAttributedString(string: title, attributes: titleStyle)
                .boundingRect(with: CGSize(width:page.width-margin*2,height:200),options:[.usesLineFragmentOrigin],context:nil)
            (title as NSString).draw(in:CGRect(x:margin,y:y,width:page.width-margin*2,height:titleBox.height+4),withAttributes:titleStyle)
            y += titleBox.height + 26
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 4
            let bodyStyle: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12), .paragraphStyle: paragraph, .foregroundColor: UIColor.black
            ]
            for raw in text.components(separatedBy:.newlines) {
                // Use at most a screen-sized line per PDF segment to guarantee pagination.
                let line = raw.isEmpty ? " " : raw
                let chunks = stride(from:0,to:line.count,by:220).map { offset -> String in
                    let lower=line.index(line.startIndex,offsetBy:offset)
                    let upper=line.index(lower,offsetBy:min(220,line.distance(from:lower,to:line.endIndex)))
                    return String(line[lower..<upper])
                }
                for chunk in chunks {
                    let ns = chunk as NSString
                    let bounds = ns.boundingRect(with:CGSize(width:page.width-margin*2,height:1000),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:bodyStyle,context:nil)
                    let h = max(17,ceil(bounds.height)+3)
                    if y + h > page.height - margin {newPage()}
                    ns.draw(in:CGRect(x:margin,y:y,width:page.width-margin*2,height:h),withAttributes:bodyStyle)
                    y += h + 3
                }
            }
        }
        let url=FileManager.default.temporaryDirectory.appendingPathComponent("ViePN-Report-\(UUID().uuidString).pdf")
        try data.write(to:url,options:.atomic)
        return url
    }
}
