import AppKit

class TerminalView: NSView {
    let scrollView = NSScrollView()
    let textView = NSTextView()
    let inputField = NSTextField()
    var onSendMessage: ((String) -> Void)?
    var onClearRequested: (() -> Void)?

    private var currentAssistantText = ""
    private var lastAssistantText = ""
    private var isStreaming = false

    let font = NSFont(name: "SFMono-Regular", size: 11.5) ?? .monospacedSystemFont(ofSize: 11.5, weight: .regular)
    let fontBold = NSFont(name: "SFMono-Medium", size: 11.5) ?? .monospacedSystemFont(ofSize: 11.5, weight: .medium)
    let textPrimary = NSColor.white
    let textDim = NSColor(white: 0.6, alpha: 1)
    let accentColor = NSColor(red: 0.2, green: 0.65, blue: 0.35, alpha: 1)
    let errorColor = NSColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 1)
    let successColor = NSColor(red: 0.4, green: 0.65, blue: 0.4, alpha: 1)
    let inputBg = NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1)

    override init(frame: NSRect) { super.init(frame: frame); setupViews() }
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        let inputHeight: CGFloat = 30
        let padding: CGFloat = 10

        scrollView.frame = NSRect(x: padding, y: inputHeight + padding + 6,
                                  width: frame.width - padding * 2,
                                  height: frame.height - inputHeight - padding - 10)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        textView.frame = scrollView.contentView.bounds
        textView.autoresizingMask = [.width]
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textColor = textPrimary
        textView.font = font
        textView.isRichText = true
        textView.textContainerInset = NSSize(width: 2, height: 4)
        let defaultPara = NSMutableParagraphStyle()
        defaultPara.paragraphSpacing = 8
        textView.defaultParagraphStyle = defaultPara
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.linkTextAttributes = [
            .foregroundColor: accentColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        scrollView.documentView = textView
        addSubview(scrollView)

        inputField.frame = NSRect(x: padding, y: 6, width: frame.width - padding * 2, height: inputHeight)
        inputField.autoresizingMask = [.width]
        inputField.focusRingType = .none
        let paddedCell = PaddedTextFieldCell(textCell: "")
        paddedCell.isEditable = true
        paddedCell.isScrollable = true
        paddedCell.font = font
        paddedCell.textColor = textPrimary
        paddedCell.drawsBackground = false
        paddedCell.isBezeled = false
        paddedCell.fieldBackgroundColor = nil
        paddedCell.fieldCornerRadius = 0
        paddedCell.placeholderAttributedString = NSAttributedString(
            string: "Ask \(CHARACTER_NAME)...",
            attributes: [.font: font, .foregroundColor: textDim]
        )
        inputField.cell = paddedCell
        inputField.target = self
        inputField.action = #selector(inputSubmitted)
        addSubview(inputField)
    }

    // MARK: - Input

    @objc private func inputSubmitted() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputField.stringValue = ""
        if handleSlashCommand(text) { return }
        appendUser(text)
        isStreaming = true
        currentAssistantText = ""
        onSendMessage?(text)
    }

    // MARK: - Slash Commands

    func handleSlashCommandPublic(_ text: String) {
        _ = handleSlashCommand(text)
    }

    private func handleSlashCommand(_ text: String) -> Bool {
        guard text.hasPrefix("/") else { return false }
        let cmd = text.lowercased().trimmingCharacters(in: .whitespaces)
        switch cmd {
        case "/clear":
            textView.textStorage?.setAttributedString(NSAttributedString(string: ""))
            onClearRequested?()
            return true
        case "/copy":
            let toCopy = lastAssistantText.isEmpty ? "nothing to copy yet" : lastAssistantText
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(toCopy, forType: .string)
            textView.textStorage?.append(NSAttributedString(
                string: "  ✓ copied to clipboard\n",
                attributes: [.font: font, .foregroundColor: successColor]
            ))
            scrollToBottom()
            return true
        case "/help":
            let help = NSMutableAttributedString()
            help.append(NSAttributedString(string: "  desktop fox — commands\n", attributes: [.font: fontBold, .foregroundColor: accentColor]))
            help.append(NSAttributedString(string: "  /clear  ", attributes: [.font: fontBold, .foregroundColor: textPrimary]))
            help.append(NSAttributedString(string: "clear chat history\n", attributes: [.font: font, .foregroundColor: textDim]))
            help.append(NSAttributedString(string: "  /copy   ", attributes: [.font: fontBold, .foregroundColor: textPrimary]))
            help.append(NSAttributedString(string: "copy last response\n", attributes: [.font: font, .foregroundColor: textDim]))
            help.append(NSAttributedString(string: "  /help   ", attributes: [.font: fontBold, .foregroundColor: textPrimary]))
            help.append(NSAttributedString(string: "show this message\n", attributes: [.font: font, .foregroundColor: textDim]))
            textView.textStorage?.append(help)
            scrollToBottom()
            return true
        default:
            textView.textStorage?.append(NSAttributedString(
                string: "  unknown command: \(text) (try /help)\n",
                attributes: [.font: font, .foregroundColor: errorColor]
            ))
            scrollToBottom()
            return true
        }
    }

    // MARK: - Append Methods

    func appendUser(_ text: String) {
        let para = NSMutableParagraphStyle(); para.paragraphSpacingBefore = 12
        let attr = NSMutableAttributedString()
        attr.append(NSAttributedString(string: "\n> ", attributes: [.font: fontBold, .foregroundColor: accentColor, .paragraphStyle: para]))
        attr.append(NSAttributedString(string: "\(text)\n\n", attributes: [.font: fontBold, .foregroundColor: textPrimary, .paragraphStyle: para]))
        textView.textStorage?.append(attr)
        scrollToBottom()
    }

    func appendStreamingText(_ text: String) {
        // Add fox avatar before first chunk of a new response
        if currentAssistantText.isEmpty {
            let para = NSMutableParagraphStyle(); para.paragraphSpacingBefore = 4
            textView.textStorage?.append(NSAttributedString(string: "🦊 ", attributes: [
                .font: NSFont.systemFont(ofSize: 13), .paragraphStyle: para
            ]))
        }
        var cleaned = text
        if currentAssistantText.isEmpty {
            cleaned = cleaned.replacingOccurrences(of: "^\n+", with: "", options: .regularExpression)
        }
        currentAssistantText += cleaned
        if !cleaned.isEmpty {
            textView.textStorage?.append(renderMarkdown(cleaned))
            scrollToBottom()
        }
    }

    func endStreaming() {
        if isStreaming {
            isStreaming = false
            if !currentAssistantText.isEmpty {
                lastAssistantText = currentAssistantText
                textView.textStorage?.append(NSAttributedString(string: "\n"))
            }
            currentAssistantText = ""
        }
    }

    func appendError(_ text: String) {
        textView.textStorage?.append(NSAttributedString(string: text + "\n", attributes: [.font: font, .foregroundColor: errorColor]))
        scrollToBottom()
    }

    func appendToolUse(toolName: String, summary: String) {
        endStreaming()
        let block = NSMutableAttributedString()
        block.append(NSAttributedString(string: "  \(toolName.uppercased()) ", attributes: [.font: fontBold, .foregroundColor: accentColor]))
        block.append(NSAttributedString(string: "\(summary)\n", attributes: [.font: font, .foregroundColor: textDim]))
        textView.textStorage?.append(block)
        scrollToBottom()
    }

    func appendToolResult(summary: String, isError: Bool) {
        let color = isError ? errorColor : successColor
        let prefix = isError ? "  FAIL " : "  DONE "
        let block = NSMutableAttributedString()
        block.append(NSAttributedString(string: prefix, attributes: [.font: fontBold, .foregroundColor: color]))
        block.append(NSAttributedString(string: "\(summary)\n", attributes: [.font: font, .foregroundColor: textDim]))
        textView.textStorage?.append(block)
        scrollToBottom()
    }

    private func scrollToBottom() { textView.scrollToEndOfDocument(nil) }

    // MARK: - Markdown Rendering

    private func renderMarkdown(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = text.components(separatedBy: "\n")
        var inCodeBlock = false; var codeLines: [String] = []

        for (i, line) in lines.enumerated() {
            let suffix = i < lines.count - 1 ? "\n" : ""
            if line.hasPrefix("```") {
                if inCodeBlock {
                    let codeText = codeLines.joined(separator: "\n")
                    let codeFont = NSFont.monospacedSystemFont(ofSize: font.pointSize - 1, weight: .regular)
                    result.append(NSAttributedString(string: codeText + "\n", attributes: [.font: codeFont, .foregroundColor: textPrimary, .backgroundColor: inputBg]))
                    inCodeBlock = false; codeLines = []
                } else { inCodeBlock = true }
                continue
            }
            if inCodeBlock { codeLines.append(line); continue }
            if line.hasPrefix("### ") {
                result.append(NSAttributedString(string: String(line.dropFirst(4)) + suffix, attributes: [.font: NSFont.systemFont(ofSize: font.pointSize, weight: .bold), .foregroundColor: accentColor]))
            } else if line.hasPrefix("## ") {
                result.append(NSAttributedString(string: String(line.dropFirst(3)) + suffix, attributes: [.font: NSFont.systemFont(ofSize: font.pointSize + 1, weight: .bold), .foregroundColor: accentColor]))
            } else if line.hasPrefix("# ") {
                result.append(NSAttributedString(string: String(line.dropFirst(2)) + suffix, attributes: [.font: NSFont.systemFont(ofSize: font.pointSize + 2, weight: .bold), .foregroundColor: accentColor]))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                result.append(NSAttributedString(string: "  \u{2022} ", attributes: [.font: font, .foregroundColor: accentColor]))
                result.append(renderInline(String(line.dropFirst(2)) + suffix))
            } else {
                result.append(renderInline(line + suffix))
            }
        }
        if inCodeBlock && !codeLines.isEmpty {
            let codeFont = NSFont.monospacedSystemFont(ofSize: font.pointSize - 1, weight: .regular)
            result.append(NSAttributedString(string: codeLines.joined(separator: "\n") + "\n", attributes: [.font: codeFont, .foregroundColor: textPrimary, .backgroundColor: inputBg]))
        }
        return result
    }

    private func renderInline(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var i = text.startIndex
        while i < text.endIndex {
            if text[i] == "`" {
                let after = text.index(after: i)
                if after < text.endIndex, let close = text[after...].firstIndex(of: "`") {
                    let codeFont = NSFont.monospacedSystemFont(ofSize: font.pointSize - 0.5, weight: .regular)
                    result.append(NSAttributedString(string: String(text[after..<close]), attributes: [.font: codeFont, .foregroundColor: accentColor, .backgroundColor: inputBg]))
                    i = text.index(after: close); continue
                }
            }
            if text[i] == "*", text.index(after: i) < text.endIndex, text[text.index(after: i)] == "*" {
                let start = text.index(i, offsetBy: 2)
                if start < text.endIndex, let range = text.range(of: "**", range: start..<text.endIndex) {
                    result.append(NSAttributedString(string: String(text[start..<range.lowerBound]), attributes: [.font: fontBold, .foregroundColor: textPrimary]))
                    i = range.upperBound; continue
                }
            }
            result.append(NSAttributedString(string: String(text[i]), attributes: [.font: font, .foregroundColor: textPrimary]))
            i = text.index(after: i)
        }
        return result
    }
}
