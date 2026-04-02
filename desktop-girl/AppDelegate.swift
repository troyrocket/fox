import AppKit
import SceneKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var scnView: PetSCNView!
    var session: ClaudeSession?
    var slapDetector: SlapDetector?
    var audioPlayer: AVAudioPlayer?

    // Popover
    var popoverWindow: KeyableWindow?
    var terminalView: TerminalView?
    var isPopoverOpen = false
    var clickOutsideMonitor: Any?
    var escMonitor: Any?

    // Model focus
    var isModelFocused = false
    var lastModelTouch: Date = .distantPast

    // Bubble
    var bubbleWindow: NSWindow?
    var bubbleTimer: Timer?

    // Thinking bubble (lil-agents style)
    var thinkingBubbleWindow: NSWindow?
    var thinkingPhrases = [
        "hmm...", "thinking...", "one sec...", "working on it",
        "let me check", "almost...", "on it!", "reading...",
        "cooking...", "vibing...", "hang tight", "processing..."
    ]
    var completionPhrases = [
        "done!", "all set!", "ready!", "here you go",
        "got it!", "ta-da!", "boom!", "there ya go!"
    ]
    var currentThinkingPhrase = ""
    var lastPhraseUpdate: CFTimeInterval = 0
    var isAgentBusy = false
    var thinkingTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let screen = NSScreen.main!

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

        scnView.onDoubleClickModel = { [weak self] in
            guard let self = self else { return }
            if self.isPopoverOpen { self.closePopover() } else { self.openPopover() }
        }

        scnView.onClickModel = { [weak self] in
            self?.isModelFocused = true
            self?.lastModelTouch = Date()
        }

        let scene = SCNScene()
        scene.background.contents = NSColor.clear

        let modelPath = Bundle.main.path(forResource: "foxgirl", ofType: "usdz")
            ?? CommandLine.arguments.dropFirst().first ?? ""
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

        // 60fps poll
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updatePassThrough()
        }

        // Gesture monitors
        NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
            if self?.isModelFocused == true { self?.scnView.doMagnify(event.magnification) }
            return event
        }
        NSEvent.addGlobalMonitorForEvents(matching: .magnify) { [weak self] event in
            if self?.isModelFocused == true { self?.scnView.doMagnify(event.magnification) }
        }
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            if self?.isModelFocused == true { self?.scnView.doScroll(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY) }
            return event
        }
        NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            if self?.isModelFocused == true { self?.scnView.doScroll(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY) }
        }

        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            guard let self = self else { return }
            if Date().timeIntervalSince(self.lastModelTouch) > 0.3 { self.isModelFocused = false }
        }

        // Slap detection
        slapDetector = SlapDetector()
        slapDetector?.onSlap = { [weak self] force in self?.onSlapDetected(force: force) }
        slapDetector?.start()

        print("🦊 \(CHARACTER_NAME) is on your desktop! Click to chat.")
    }

    // MARK: - Slap Reaction

    func onSlapDetected(force: Double) {
        guard let container = scnView.modelContainer else { return }

        let intensity = CGFloat(min(force / 2.0, 1.0))
        let shake = CAKeyframeAnimation(keyPath: "position.x")
        let base = CGFloat(container.position.x)
        shake.values = [base, base + 0.02 * intensity, base - 0.02 * intensity,
                        base + 0.01 * intensity, base - 0.01 * intensity, base]
        shake.keyTimes = [0, 0.15, 0.35, 0.55, 0.75, 1.0]
        shake.duration = 0.4
        container.addAnimation(shake, forKey: "slap_shake")

        // Play random slap sound
        let execDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        let slapDir = execDir.appendingPathComponent("sounds/slap")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: slapDir.path))?
            .filter { $0.hasSuffix(".mp3") } ?? []
        if let soundFile = files.randomElement() {
            let soundURL = slapDir.appendingPathComponent(soundFile)
            if let player = try? AVAudioPlayer(contentsOf: soundURL) {
                player.volume = 1.0
                player.play()
                self.audioPlayer = player
            }
        }

        // Show speech bubble
        let moans = ["Ahhhn~♡", "Mmm~♡", "Nyaaa~♡", "Haah..♡", "Kyaaa~!", "Iyaan~♡", "Nn..ahh~♡", "Yaa~♡"]
        showSlapBubble(text: moans.randomElement()!)

        print("🦊 Slap detected! Force: \(String(format: "%.2f", force))g")
    }

    // MARK: - Slap Bubble

    func showSlapBubble(text: String) {
        bubbleTimer?.invalidate()
        bubbleWindow?.orderOut(nil)

        let font = NSFont(name: "Futura-Bold", size: 15) ?? NSFont.systemFont(ofSize: 15, weight: .heavy)
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let padding: CGFloat = 20
        let tailH: CGFloat = 14
        let bubbleW = textSize.width + padding * 2
        let totalH: CGFloat = 40 + tailH

        let win = NSWindow(contentRect: CGRect(x: 0, y: 0, width: bubbleW, height: totalH),
                           styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 20)
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let bubbleView = ComicBubbleView(frame: NSRect(x: 0, y: 0, width: bubbleW, height: totalH))
        bubbleView.text = text
        bubbleView.font = font
        bubbleView.bubbleColor = NSColor(red: 0.85, green: 1.0, blue: 0.88, alpha: 0.95)
        bubbleView.borderColor = NSColor(red: 0.2, green: 0.65, blue: 0.35, alpha: 1.0)
        bubbleView.textColor = NSColor(red: 0.1, green: 0.35, blue: 0.15, alpha: 1.0)
        bubbleView.tailHeight = tailH
        bubbleView.bodyHeight = 40
        win.contentView = bubbleView

        let headPos = scnView.headScreenPosition()
        win.setFrameOrigin(NSPoint(x: headPos.x - 40, y: headPos.y - 20))
        win.orderFrontRegardless()
        bubbleWindow = win

        bubbleTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                self?.bubbleWindow?.animator().alphaValue = 0
            }, completionHandler: {
                self?.bubbleWindow?.orderOut(nil)
                self?.bubbleWindow?.alphaValue = 1
            })
        }
    }

    // MARK: - Thinking Bubble (lil-agents style)

    func showThinkingBubble(text: String, isCompletion: Bool) {
        if thinkingBubbleWindow == nil { createThinkingBubble() }

        let font = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let padding: CGFloat = 16
        let h: CGFloat = 26
        let w = max(ceil(textSize.width) + padding * 2, 48)

        let headPos = scnView.headScreenPosition()
        let x = headPos.x - w / 2
        let y = headPos.y + 5
        thinkingBubbleWindow?.setFrame(CGRect(x: x, y: y, width: w, height: h), display: false)

        let borderColor = isCompletion
            ? NSColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 0.7).cgColor
            : NSColor(red: 0.2, green: 0.65, blue: 0.35, alpha: 0.6).cgColor
        let textColor = isCompletion
            ? NSColor(red: 0.3, green: 0.85, blue: 0.3, alpha: 1.0)
            : NSColor(red: 0.5, green: 0.5, blue: 0.52, alpha: 1.0)

        if let container = thinkingBubbleWindow?.contentView {
            container.frame = NSRect(x: 0, y: 0, width: w, height: h)
            container.layer?.borderColor = borderColor
            if let label = container.viewWithTag(100) as? NSTextField {
                label.font = font
                label.frame = NSRect(x: 0, y: 4, width: w, height: 18)
                label.stringValue = text
                label.textColor = textColor
            }
        }

        if !(thinkingBubbleWindow?.isVisible ?? false) {
            thinkingBubbleWindow?.alphaValue = 1.0
            thinkingBubbleWindow?.orderFrontRegardless()
        }
    }

    func hideThinkingBubble() {
        thinkingBubbleWindow?.orderOut(nil)
    }

    private func createThinkingBubble() {
        let w: CGFloat = 80, h: CGFloat = 26
        let win = NSWindow(contentRect: CGRect(x: 0, y: 0, width: w, height: h),
                           styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 5)
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let container = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(white: 0.07, alpha: 0.92).cgColor
        container.layer?.cornerRadius = 12
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor(red: 0.2, green: 0.65, blue: 0.35, alpha: 0.6).cgColor

        let label = NSTextField(labelWithString: "")
        label.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        label.textColor = NSColor(white: 0.7, alpha: 1)
        label.alignment = .center
        label.drawsBackground = false
        label.isBordered = false
        label.isEditable = false
        label.frame = NSRect(x: 0, y: 4, width: w, height: 18)
        label.tag = 100
        container.addSubview(label)

        win.contentView = container
        thinkingBubbleWindow = win
    }

    func updateThinkingPhrase() {
        let now = CACurrentMediaTime()
        if currentThinkingPhrase.isEmpty || now - lastPhraseUpdate > Double.random(in: 3.0...5.0) {
            var next = thinkingPhrases.randomElement() ?? "..."
            while next == currentThinkingPhrase && thinkingPhrases.count > 1 {
                next = thinkingPhrases.randomElement() ?? "..."
            }
            currentThinkingPhrase = next
            lastPhraseUpdate = now
        }
    }

    // MARK: - Completion Sound

    func playCompletionSound() {
        let execDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        let pingDir = execDir.appendingPathComponent("sounds/ping")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: pingDir.path))?
            .filter { $0.hasSuffix(".mp3") || $0.hasSuffix(".m4a") } ?? []
        if let file = files.randomElement() {
            let url = pingDir.appendingPathComponent(file)
            if let sound = NSSound(contentsOf: url, byReference: true) {
                sound.play()
            }
        }
    }

    // MARK: - Popover

    func openPopover() {
        isPopoverOpen = true
        hideThinkingBubble()

        if popoverWindow == nil { createPopoverWindow() }
        if session == nil || session?.isRunning != true { startClaudeSession() }

        updatePopoverPosition()
        popoverWindow?.orderFrontRegardless()
        popoverWindow?.makeKey()
        if let tv = terminalView { popoverWindow?.makeFirstResponder(tv.inputField) }

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, let popover = self.popoverWindow else { return }
            if !popover.frame.contains(NSEvent.mouseLocation) { self.closePopover() }
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

        // Show thinking bubble if agent is still busy
        if isAgentBusy {
            updateThinkingPhrase()
            showThinkingBubble(text: currentThinkingPhrase, isCompletion: false)
        }
    }

    func createPopoverWindow() {
        let popW: CGFloat = 420, popH: CGFloat = 310

        let win = KeyableWindow(contentRect: CGRect(x: 0, y: 0, width: popW, height: popH),
                                styleMask: .borderless, backing: .buffered, defer: false)
        win.isMovableByWindowBackground = true
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
        container.layer?.borderColor = NSColor(red: 0.2, green: 0.65, blue: 0.35, alpha: 0.7).cgColor
        container.autoresizingMask = [.width, .height]

        // Title bar
        let titleBar = NSView(frame: NSRect(x: 0, y: popH - 28, width: popW, height: 28))
        titleBar.wantsLayer = true
        titleBar.layer?.backgroundColor = NSColor(white: 0.1, alpha: 1).cgColor
        container.addSubview(titleBar)

        let titleLabel = NSTextField(labelWithString: CHARACTER_NAME.uppercased())
        titleLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .bold)
        titleLabel.textColor = NSColor(red: 0.2, green: 0.65, blue: 0.35, alpha: 1)
        titleLabel.frame = NSRect(x: 12, y: 6, width: popW - 80, height: 16)
        titleBar.addSubview(titleLabel)

        // Copy button
        let copyBtn = NSButton(frame: NSRect(x: popW - 28, y: 5, width: 16, height: 16))
        copyBtn.image = NSImage(systemSymbolName: "square.on.square", accessibilityDescription: "Copy")
        copyBtn.imageScaling = .scaleProportionallyDown
        copyBtn.bezelStyle = .inline
        copyBtn.isBordered = false
        copyBtn.contentTintColor = NSColor(red: 0.2, green: 0.65, blue: 0.35, alpha: 0.75)
        copyBtn.target = self
        copyBtn.action = #selector(copyLastResponse)
        titleBar.addSubview(copyBtn)

        let sep = NSView(frame: NSRect(x: 0, y: popH - 29, width: popW, height: 1))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor(red: 0.2, green: 0.65, blue: 0.35, alpha: 0.3).cgColor
        container.addSubview(sep)

        let tv = TerminalView(frame: NSRect(x: 0, y: 0, width: popW, height: popH - 29))
        tv.autoresizingMask = [.width, .height]
        tv.onSendMessage = { [weak self] message in self?.session?.send(message: message) }
        tv.onClearRequested = { [weak self] in
            self?.session?.terminate(); self?.session = nil; self?.startClaudeSession()
        }
        container.addSubview(tv)

        win.contentView = container
        popoverWindow = win
        terminalView = tv
    }

    @objc func copyLastResponse() {
        terminalView?.handleSlashCommandPublic("/copy")
    }

    func startClaudeSession() {
        let s = ClaudeSession()
        session = s

        s.onText = { [weak self] text in
            self?.isAgentBusy = true
            self?.terminalView?.appendStreamingText(text)
            // Update thinking bubble if popover is closed
            if self?.isPopoverOpen == false {
                self?.updateThinkingPhrase()
                self?.showThinkingBubble(text: self?.currentThinkingPhrase ?? "thinking...", isCompletion: false)
            }
        }
        s.onError = { [weak self] text in
            self?.terminalView?.appendError(text)
        }
        s.onToolUse = { [weak self] name, summary in
            self?.terminalView?.appendToolUse(toolName: name, summary: summary)
        }
        s.onToolResult = { [weak self] summary, isError in
            self?.terminalView?.appendToolResult(summary: summary, isError: isError)
        }
        s.onTurnComplete = { [weak self] in
            self?.terminalView?.endStreaming()
            self?.isAgentBusy = false
            self?.playCompletionSound()

            // Show completion bubble
            let phrase = self?.completionPhrases.randomElement() ?? "done!"
            self?.showThinkingBubble(text: phrase, isCompletion: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.hideThinkingBubble()
            }
        }
        s.start()
    }

    func updatePopoverPosition() {
        guard let popover = popoverWindow, let screen = NSScreen.main else { return }
        let popSize = popover.frame.size
        let x = screen.frame.midX - popSize.width / 2
        let y = screen.frame.midY - popSize.height / 2
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
        if window.ignoresMouseEvents != shouldIgnore { window.ignoresMouseEvents = shouldIgnore }
    }

    // MARK: - Model Loading

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
            container.position = SCNVector3(0.15, -centerY * scale + 1.15, 0)
            container.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)

            scene.rootNode.addChildNode(container)
            scnView.modelContainer = container
            playAnims(in: container)
        } catch {
            print("Error loading model: \(error)")
        }
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
