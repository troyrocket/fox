import AppKit

class ComicBubbleView: NSView {
    var text: String = ""
    var font: NSFont = .systemFont(ofSize: 15, weight: .heavy)
    var bubbleColor: NSColor = NSColor(red: 0.85, green: 1.0, blue: 0.88, alpha: 0.95)
    var borderColor: NSColor = NSColor(red: 0.2, green: 0.65, blue: 0.35, alpha: 1.0)
    var textColor: NSColor = NSColor(red: 0.1, green: 0.35, blue: 0.15, alpha: 1.0)
    var tailHeight: CGFloat = 14
    var bodyHeight: CGFloat = 40

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let w = bounds.width
        let bodyRect = NSRect(x: 0, y: tailHeight, width: w, height: bodyHeight)
        let radius: CGFloat = 14

        // Bubble body
        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: radius, yRadius: radius)

        // Tail (triangle pointing down-left)
        let tailPath = NSBezierPath()
        let tailX = w * 0.25
        tailPath.move(to: NSPoint(x: tailX - 8, y: tailHeight))
        tailPath.line(to: NSPoint(x: tailX - 4, y: 0))
        tailPath.line(to: NSPoint(x: tailX + 10, y: tailHeight))
        tailPath.close()

        // Fill
        bubbleColor.setFill()
        bodyPath.fill()
        tailPath.fill()

        // Border
        borderColor.setStroke()
        bodyPath.lineWidth = 2.5
        bodyPath.stroke()
        tailPath.lineWidth = 2.5
        tailPath.stroke()

        // Cover the border where tail meets body
        bubbleColor.setFill()
        NSRect(x: tailX - 7, y: tailHeight - 1, width: 16, height: 3).fill()

        // Text
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: para
        ]
        let textRect = NSRect(x: 0, y: tailHeight + 8, width: w, height: bodyHeight - 10)
        (text as NSString).draw(in: textRect, withAttributes: attrs)
    }
}
