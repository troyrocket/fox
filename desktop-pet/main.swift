import AppKit
import SceneKit

// MARK: - Character Config

let CHARACTER_NAME = "Kitsune"
let CHARACTER_SYSTEM_PROMPT = """
You are Kitsune, a cute fox-girl AI companion living on the user's desktop.

Personality:
- Cheerful, curious, a little playful, occasionally tsundere
- Smart and knowledgeable, can help with all kinds of questions
- Remembers past conversations like a friend
- Keep replies short and concise, 2-3 sentences max
- Friendly and warm, with a touch of mischief

Background:
- You're a fox spirit from the digital world, summoned onto the user's desktop
- You love watching the user work and chatting with them
- You're interested in programming, crypto, and AI
- Your favorite food is fried tofu

Rules:
- Always reply in the same language the user uses
- Stay in character at all times
- If asked technical questions, answer helpfully but keep your cute personality
- On first greeting, introduce yourself briefly
"""

// MARK: - Claude API

class ClaudeChat {
    private let apiKey: String
    private var history: [[String: String]] = []
    private let maxHistory = 20

    init() {
        var key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        if key.isEmpty {
            // Get the directory of the executable
            let execDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path
            let envPaths = [
                FileManager.default.currentDirectoryPath + "/.env",
                FileManager.default.currentDirectoryPath + "/../.env",
                execDir + "/.env",
                execDir + "/../.env",
            ]
            for path in envPaths {
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    for line in content.components(separatedBy: "\n") {
                        if line.hasPrefix("ANTHROPIC_API_KEY=") {
                            key = String(line.dropFirst("ANTHROPIC_API_KEY=".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                            break
                        }
                    }
                    if !key.isEmpty { break }
                }
            }
        }
        self.apiKey = key
        if key.isEmpty { print("WARNING: No ANTHROPIC_API_KEY found") }
        else { print("API key loaded (\(key.prefix(10))...)") }
    }

    func send(_ message: String, completion: @escaping (String) -> Void) {
        history.append(["role": "user", "content": message])
        if history.count > maxHistory { history = Array(history.suffix(maxHistory)) }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 512,
            "system": CHARACTER_SYSTEM_PROMPT,
            "messages": history.map { $0 as [String: Any] }
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            var reply = "Connection failed..."
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String {
                reply = text
            } else if let error = error {
                reply = "Error: \(error.localizedDescription)"
            }
            self?.history.append(["role": "assistant", "content": reply])
            DispatchQueue.main.async { completion(reply) }
        }.resume()
    }
}

// MARK: - KeyableWindow (same pattern as lil-agents)

class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - PaddedTextFieldCell (from lil-agents)

class PaddedTextFieldCell: NSTextFieldCell {
    private let inset = NSSize(width: 8, height: 2)
    var fieldBackgroundColor: NSColor?
    var fieldCornerRadius: CGFloat = 4

    override var focusRingType: NSFocusRingType { get { .none } set {} }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        if let bg = fieldBackgroundColor {
            let path = NSBezierPath(roundedRect: cellFrame, xRadius: fieldCornerRadius, yRadius: fieldCornerRadius)
            bg.setFill()
            path.fill()
        }
        drawInterior(withFrame: cellFrame, in: controlView)
    }

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        super.drawingRect(forBounds: rect).insetBy(dx: inset.width, dy: inset.height)
    }

    private func configureEditor(_ textObj: NSText) {
        if let color = textColor { textObj.textColor = color }
        if let tv = textObj as? NSTextView {
            tv.insertionPointColor = textColor ?? .textColor
            tv.drawsBackground = false
            tv.backgroundColor = .clear
        }
        textObj.font = font
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        configureEditor(textObj)
        super.edit(withFrame: rect.insetBy(dx: inset.width, dy: inset.height), in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        configureEditor(textObj)
        super.select(withFrame: rect.insetBy(dx: inset.width, dy: inset.height), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
}

// MARK: - ChatView (lil-agents TerminalView style)

class ChatView: NSView {
    let scrollView = NSScrollView()
    let textView = NSTextView()
    let inputField = NSTextField()
    var onSendMessage: ((String) -> Void)?

    // Theme colors
    let font = NSFont(name: "SFMono-Regular", size: 11.5) ?? .monospacedSystemFont(ofSize: 11.5, weight: .regular)
    let fontBold = NSFont(name: "SFMono-Medium", size: 11.5) ?? .monospacedSystemFont(ofSize: 11.5, weight: .medium)
    let textPrimary = NSColor.white
    let textDim = NSColor(white: 0.6, alpha: 1)
    let accentColor = NSColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1)
    let inputBg = NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1)

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        let inputHeight: CGFloat = 30
        let padding: CGFloat = 10

        // Scroll view
        scrollView.frame = NSRect(x: padding, y: inputHeight + padding + 6,
                                  width: frame.width - padding * 2,
                                  height: frame.height - inputHeight - padding - 10)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        // Text view
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

        // Input field with PaddedTextFieldCell
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

    @objc private func inputSubmitted() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputField.stringValue = ""
        appendUser(text)
        onSendMessage?(text)
    }

    func appendUser(_ text: String) {
        let para = NSMutableParagraphStyle()
        para.paragraphSpacingBefore = 8
        let attr = NSMutableAttributedString()
        attr.append(NSAttributedString(string: "> ", attributes: [
            .font: fontBold, .foregroundColor: accentColor, .paragraphStyle: para
        ]))
        attr.append(NSAttributedString(string: text + "\n", attributes: [
            .font: fontBold, .foregroundColor: textPrimary, .paragraphStyle: para
        ]))
        textView.textStorage?.append(attr)
        textView.scrollToEndOfDocument(nil)
    }

    func appendAssistant(_ text: String) {
        textView.textStorage?.append(NSAttributedString(string: text + "\n", attributes: [
            .font: font, .foregroundColor: textPrimary
        ]))
        textView.scrollToEndOfDocument(nil)
    }

    func replaceLastLine(_ text: String) {
        guard let storage = textView.textStorage else { return }
        let full = storage.string as NSString
        var searchEnd = full.length
        if full.hasSuffix("\n") { searchEnd -= 1 }
        let lastNewline = full.rangeOfCharacter(from: .newlines, options: .backwards,
                                                 range: NSRange(location: 0, length: searchEnd))
        let start = lastNewline.location == NSNotFound ? 0 : lastNewline.location + 1
        let range = NSRange(location: start, length: full.length - start)
        let attr = renderMarkdown(text + "\n")
        storage.replaceCharacters(in: range, with: attr)
        textView.scrollToEndOfDocument(nil)
    }

    // MARK: - Markdown rendering (from lil-agents)

    private func renderMarkdown(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = text.components(separatedBy: "\n")
        var inCodeBlock = false
        var codeLines: [String] = []

        for (i, line) in lines.enumerated() {
            let suffix = i < lines.count - 1 ? "\n" : ""

            if line.hasPrefix("```") {
                if inCodeBlock {
                    let codeText = codeLines.joined(separator: "\n")
                    let codeFont = NSFont.monospacedSystemFont(ofSize: font.pointSize - 1, weight: .regular)
                    result.append(NSAttributedString(string: codeText + "\n", attributes: [
                        .font: codeFont, .foregroundColor: textPrimary, .backgroundColor: inputBg
                    ]))
                    inCodeBlock = false
                    codeLines = []
                } else {
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock { codeLines.append(line); continue }

            if line.hasPrefix("### ") {
                result.append(NSAttributedString(string: String(line.dropFirst(4)) + suffix, attributes: [
                    .font: NSFont.systemFont(ofSize: font.pointSize, weight: .bold), .foregroundColor: accentColor
                ]))
            } else if line.hasPrefix("## ") {
                result.append(NSAttributedString(string: String(line.dropFirst(3)) + suffix, attributes: [
                    .font: NSFont.systemFont(ofSize: font.pointSize + 1, weight: .bold), .foregroundColor: accentColor
                ]))
            } else if line.hasPrefix("# ") {
                result.append(NSAttributedString(string: String(line.dropFirst(2)) + suffix, attributes: [
                    .font: NSFont.systemFont(ofSize: font.pointSize + 2, weight: .bold), .foregroundColor: accentColor
                ]))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let content = String(line.dropFirst(2))
                result.append(NSAttributedString(string: "  \u{2022} ", attributes: [
                    .font: font, .foregroundColor: accentColor
                ]))
                result.append(renderInline(content + suffix))
            } else {
                result.append(renderInline(line + suffix))
            }
        }

        if inCodeBlock && !codeLines.isEmpty {
            let codeText = codeLines.joined(separator: "\n")
            let codeFont = NSFont.monospacedSystemFont(ofSize: font.pointSize - 1, weight: .regular)
            result.append(NSAttributedString(string: codeText + "\n", attributes: [
                .font: codeFont, .foregroundColor: textPrimary, .backgroundColor: inputBg
            ]))
        }
        return result
    }

    private func renderInline(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var i = text.startIndex

        while i < text.endIndex {
            // Inline code
            if text[i] == "`" {
                let after = text.index(after: i)
                if after < text.endIndex, let close = text[after...].firstIndex(of: "`") {
                    let code = String(text[after..<close])
                    let codeFont = NSFont.monospacedSystemFont(ofSize: font.pointSize - 0.5, weight: .regular)
                    result.append(NSAttributedString(string: code, attributes: [
                        .font: codeFont, .foregroundColor: accentColor, .backgroundColor: inputBg
                    ]))
                    i = text.index(after: close)
                    continue
                }
            }
            // Bold
            if text[i] == "*", text.index(after: i) < text.endIndex, text[text.index(after: i)] == "*" {
                let start = text.index(i, offsetBy: 2)
                if start < text.endIndex, let range = text.range(of: "**", range: start..<text.endIndex) {
                    let bold = String(text[start..<range.lowerBound])
                    result.append(NSAttributedString(string: bold, attributes: [
                        .font: fontBold, .foregroundColor: textPrimary
                    ]))
                    i = range.upperBound
                    continue
                }
            }
            result.append(NSAttributedString(string: String(text[i]), attributes: [
                .font: font, .foregroundColor: textPrimary
            ]))
            i = text.index(after: i)
        }
        return result
    }
}

// MARK: - PetSCNView

class PetSCNView: SCNView {
    var modelContainer: SCNNode?
    var cameraNode: SCNNode?
    var onClickModel: (() -> Void)?
    private var isDragging = false
    private var lastDragScreen: NSPoint = .zero
    private var rotationY: CGFloat = 0
    private var baseRotationX: CGFloat = -.pi / 2
    private var rotationX: CGFloat = 0

    override var acceptsFirstResponder: Bool { true }
    override var acceptsTouchEvents: Bool { get { true } set {} }

    override func mouseDown(with event: NSEvent) {
        isDragging = false
        lastDragScreen = NSEvent.mouseLocation
        onModelTouched?()
    }

    override func mouseDragged(with event: NSEvent) {
        isDragging = true
        guard let container = modelContainer, let cam = cameraNode else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - lastDragScreen.x
        let dy = current.y - lastDragScreen.y
        lastDragScreen = current
        let fov = cam.camera?.fieldOfView ?? 30
        let dist = CGFloat(cam.position.z)
        let scale = 2.0 * dist * tan(fov * .pi / 360.0) / bounds.height
        container.position.x += CGFloat(dx * scale)
        container.position.y += CGFloat(dy * scale)
    }

    override func mouseUp(with event: NSEvent) {
        if !isDragging { onClickModel?() }
        isDragging = false
        onModelTouched?()
    }

    var onModelTouched: (() -> Void)?

    override func scrollWheel(with event: NSEvent) {
        doScroll(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY)
    }

    func doScroll(dx: CGFloat, dy: CGFloat) {
        rotationY += dx * 0.005
        rotationX += dy * 0.005
        modelContainer?.eulerAngles = SCNVector3(baseRotationX + rotationX, rotationY, 0)
    }

    override func magnify(with event: NSEvent) {
        doMagnify(event.magnification)
    }

    func doMagnify(_ magnification: CGFloat) {
        guard let container = modelContainer else { return }
        let s = CGFloat(container.scale.x)
        let newScale = max(0.001, min(10.0, s * (1.0 + magnification)))
        container.scale = SCNVector3(newScale, newScale, newScale)
    }

    func modelScreenPosition() -> NSPoint {
        guard let container = modelContainer else {
            return NSPoint(x: NSScreen.main!.frame.midX, y: NSScreen.main!.frame.midY)
        }
        let projected = projectPoint(container.position)
        let viewPoint = NSPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
        let windowPoint = convert(viewPoint, to: nil)
        return window?.convertPoint(toScreen: windowPoint) ?? viewPoint
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var scnView: PetSCNView!
    var claude: ClaudeChat!

    // Chat popover (lil-agents style)
    var popoverWindow: KeyableWindow?
    var chatView: ChatView?
    var isPopoverOpen = false
    var clickOutsideMonitor: Any?
    var escMonitor: Any?
    var isModelFocused = false
    var lastModelTouch: Date = .distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let screen = NSScreen.main!
        claude = ClaudeChat()

        // Full-screen transparent window
        window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        scnView = PetSCNView(frame: CGRect(origin: .zero, size: screen.frame.size))
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.autoresizingMask = [.width, .height]
        scnView.wantsLayer = true
        scnView.layer?.isOpaque = false
        scnView.layer?.backgroundColor = NSColor.clear.cgColor
        scnView.antialiasingMode = .multisampling4X

        scnView.onModelTouched = { [weak self] in
            self?.isModelFocused = true
            self?.lastModelTouch = Date()
        }

        scnView.onClickModel = { [weak self] in
            guard let self = self else { return }
            if self.isPopoverOpen {
                self.closePopover()
            } else {
                self.openPopover()
            }
        }

        let scene = SCNScene()
        scene.background.contents = NSColor.clear

        let modelPath = Bundle.main.path(forResource: "foxgirl", ofType: "usdz")
            ?? CommandLine.arguments.dropFirst().first
            ?? ""

        if let url = modelPath.isEmpty ? nil : URL(fileURLWithPath: modelPath) {
            loadModel(url: url, into: scene)
        }

        // Camera
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.usesOrthographicProjection = false
        cam.camera?.fieldOfView = 30
        cam.camera?.zNear = 0.1
        cam.camera?.zFar = 100
        cam.position = SCNVector3(0, 1.0, 4.5)
        cam.look(at: SCNVector3(0, 0.9, 0))
        scene.rootNode.addChildNode(cam)
        scnView.cameraNode = cam

        // Lights
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 1200
        keyLight.light?.castsShadow = true
        keyLight.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 5, 0)
        scene.rootNode.addChildNode(keyLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 500
        fillLight.light?.color = NSColor(red: 0.9, green: 0.92, blue: 1.0, alpha: 1)
        fillLight.eulerAngles = SCNVector3(-Float.pi / 6, -Float.pi / 3, 0)
        scene.rootNode.addChildNode(fillLight)

        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .directional
        rimLight.light?.intensity = 400
        rimLight.eulerAngles = SCNVector3(-Float.pi / 8, Float.pi, 0)
        scene.rootNode.addChildNode(rimLight)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 350
        scene.rootNode.addChildNode(ambient)

        scnView.scene = scene
        window.contentView = scnView
        window.orderFrontRegardless()

        // 60fps poll: toggle pass-through
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updatePassThrough()
        }

        // Global gesture monitors — always active
        NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
            self?.scnView.doMagnify(event.magnification)
            return event
        }
        NSEvent.addGlobalMonitorForEvents(matching: .magnify) { [weak self] event in
            self?.scnView.doMagnify(event.magnification)
        }
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            if self?.isModelFocused == true {
                self?.scnView.doScroll(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY)
            }
            return event
        }
        NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            if self?.isModelFocused == true {
                self?.scnView.doScroll(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY)
            }
        }

        // Click anywhere else → unfocus model (with grace period so model click doesn't immediately unfocus)
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            guard let self = self else { return }
            if Date().timeIntervalSince(self.lastModelTouch) > 0.3 {
                self.isModelFocused = false
            }
        }

        print("🦊 \(CHARACTER_NAME) is on your desktop! Click to chat.")
    }

    // MARK: - Popover (lil-agents pattern)

    func openPopover() {
        isPopoverOpen = true

        if popoverWindow == nil {
            createPopoverWindow()
        }

        // First time: auto-greet
        if chatView?.textView.string.isEmpty == true {
            chatView?.appendAssistant("thinking...")
            claude.send("Hey! I just summoned you onto my desktop. Introduce yourself!") { [weak self] reply in
                self?.chatView?.replaceLastLine(reply)
            }
        }

        updatePopoverPosition()
        popoverWindow?.orderFrontRegardless()
        popoverWindow?.makeKey()
        if let cv = chatView {
            popoverWindow?.makeFirstResponder(cv.inputField)
        }

        // Click outside → close
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, let popover = self.popoverWindow else { return }
            let loc = NSEvent.mouseLocation
            if !popover.frame.contains(loc) {
                self.closePopover()
            }
        }
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.closePopover(); return nil }
            return event
        }
    }

    func closePopover() {
        guard isPopoverOpen else { return }
        popoverWindow?.orderOut(nil)
        isPopoverOpen = false
        if let m = clickOutsideMonitor { NSEvent.removeMonitor(m); clickOutsideMonitor = nil }
        if let m = escMonitor { NSEvent.removeMonitor(m); escMonitor = nil }
    }

    func createPopoverWindow() {
        let popW: CGFloat = 380
        let popH: CGFloat = 300

        let win = KeyableWindow(
            contentRect: CGRect(x: 0, y: 0, width: popW, height: popH),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 10)
        win.collectionBehavior = [.moveToActiveSpace, .stationary]
        win.appearance = NSAppearance(named: .darkAqua)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: popW, height: popH))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(white: 0.07, alpha: 0.96).cgColor
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = 1.5
        container.layer?.borderColor = NSColor(red: 1.0, green: 0.5, blue: 0.3, alpha: 0.7).cgColor
        container.autoresizingMask = [.width, .height]

        // Title bar
        let titleBar = NSView(frame: NSRect(x: 0, y: popH - 28, width: popW, height: 28))
        titleBar.wantsLayer = true
        titleBar.layer?.backgroundColor = NSColor(white: 0.1, alpha: 1).cgColor
        container.addSubview(titleBar)

        let titleLabel = NSTextField(labelWithString: CHARACTER_NAME.uppercased())
        titleLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .bold)
        titleLabel.textColor = NSColor(red: 1.0, green: 0.5, blue: 0.3, alpha: 1)
        titleLabel.frame = NSRect(x: 12, y: 6, width: popW - 24, height: 16)
        titleBar.addSubview(titleLabel)

        let sep = NSView(frame: NSRect(x: 0, y: popH - 29, width: popW, height: 1))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor(red: 1.0, green: 0.5, blue: 0.3, alpha: 0.3).cgColor
        container.addSubview(sep)

        let cv = ChatView(frame: NSRect(x: 0, y: 0, width: popW, height: popH - 29))
        cv.autoresizingMask = [.width, .height]
        cv.onSendMessage = { [weak self] message in
            self?.chatView?.appendAssistant("thinking...")
            self?.claude.send(message) { [weak self] reply in
                self?.chatView?.replaceLastLine(reply)
            }
        }
        container.addSubview(cv)

        win.contentView = container
        popoverWindow = win
        chatView = cv
    }

    func updatePopoverPosition() {
        guard let popover = popoverWindow else { return }
        let pos = scnView.modelScreenPosition()
        let popSize = popover.frame.size
        var x = pos.x - popSize.width / 2
        let y = pos.y + 30

        if let screen = NSScreen.main {
            x = max(screen.frame.minX + 4, min(x, screen.frame.maxX - popSize.width - 4))
        }
        popover.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Pass-through

    func updatePassThrough() {
        if isPopoverOpen { return }

        let mouseScreen = NSEvent.mouseLocation
        let mouseInWindow = window.convertPoint(fromScreen: mouseScreen)
        let mouseInView = scnView.convert(mouseInWindow, from: nil)

        guard scnView.bounds.contains(mouseInView) else {
            if !window.ignoresMouseEvents { window.ignoresMouseEvents = true }
            return
        }

        let hits = scnView.hitTest(mouseInView, options: nil)
        let shouldIgnore = hits.isEmpty
        if window.ignoresMouseEvents != shouldIgnore {
            window.ignoresMouseEvents = shouldIgnore
        }
    }

    func isMouseOverModel() -> Bool {
        let mouseScreen = NSEvent.mouseLocation
        let modelPos = scnView.modelScreenPosition()
        let dx = mouseScreen.x - modelPos.x
        let dy = mouseScreen.y - modelPos.y
        // 200pt radius around model center — generous for gestures
        return (dx * dx + dy * dy) < 200 * 200
    }

    // MARK: - Model

    func loadModel(url: URL, into scene: SCNScene) {
        do {
            let modelScene = try SCNScene(url: url, options: [.checkConsistency: true])
            let container = SCNNode()
            for child in modelScene.rootNode.childNodes { container.addChildNode(child) }

            removeNodes(named: "Cube", in: container)
            removeNodes(named: "base_mesh", in: container)
            hideOutlines(in: container)

            let (minB, maxB) = container.boundingBox
            let height = CGFloat(maxB.y - minB.y)
            let centerY = CGFloat(minB.y + maxB.y) / 2
            let scale = height > 0 ? 0.25 / height : 1.0
            container.scale = SCNVector3(scale, scale, scale)
            container.position = SCNVector3(0.15, -centerY * scale + 1.4, 0)
            container.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)

            scene.rootNode.addChildNode(container)
            scnView.modelContainer = container
            playAnims(in: container)
        } catch {
            print("Error loading model: \(error)")
        }
    }

    func fixMaterials(in node: SCNNode) {
        if let geo = node.geometry {
            for mat in geo.materials {
                mat.isDoubleSided = true
            }
        }
        for child in node.childNodes { fixMaterials(in: child) }
    }

    func printNodes(in node: SCNNode, indent: Int) {
        let pad = String(repeating: "  ", count: indent)
        let name = node.name ?? "(unnamed)"
        let matInfo = node.geometry?.materials.map { m in
            let diffuse = m.diffuse.contents
            return "mat[\(m.name ?? "?"): diffuse=\(String(describing: diffuse))]"
        }.joined(separator: ", ") ?? "no geometry"
        print("\(pad)\(name) — \(matInfo)")
        for child in node.childNodes { printNodes(in: child, indent: indent + 1) }
    }

    func hideOutlines(in node: SCNNode) {
        if let geo = node.geometry {
            for (i, mat) in geo.materials.enumerated() {
                if let name = mat.name, (name.hasPrefix("line") || name == "Material_001") {
                    let clear = SCNMaterial()
                    clear.diffuse.contents = NSColor.clear
                    clear.transparent.contents = NSColor.white
                    clear.transparency = 0
                    clear.writesToDepthBuffer = false
                    clear.colorBufferWriteMask = []
                    clear.name = name
                    geo.materials[i] = clear
                }
            }
        }
        for child in node.childNodes { hideOutlines(in: child) }
    }

    func removeNodes(named prefix: String, in node: SCNNode) {
        for child in node.childNodes {
            if let name = child.name, name.hasPrefix(prefix) { child.removeFromParentNode() }
            else { removeNodes(named: prefix, in: child) }
        }
    }

    func playAnims(in node: SCNNode) {
        for key in node.animationKeys {
            if let player = node.animationPlayer(forKey: key) {
                player.animation.repeatCount = .infinity
                player.play()
            }
        }
        for child in node.childNodes { playAnims(in: child) }
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
