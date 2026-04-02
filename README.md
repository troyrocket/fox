<p align="center">
  <h1 align="center">Desktop Fox</h1>
  <p align="center">
    A 3D AI companion on your macOS desktop. She chats, she reacts, she screams when you slap your MacBook.
  </p>
</p>

<p align="center">
  <a href="#features">Features</a> &nbsp;&bull;&nbsp;
  <a href="#getting-started">Getting Started</a> &nbsp;&bull;&nbsp;
  <a href="#controls">Controls</a> &nbsp;&bull;&nbsp;
  <a href="#architecture">Architecture</a> &nbsp;&bull;&nbsp;
  <a href="#roadmap">Roadmap</a> &nbsp;&bull;&nbsp;
  <a href="#license">License</a>
</p>

---

## Features

### Desktop Companion

- **3D Character** — A fox-girl model rendered via SceneKit, floating transparently on your desktop
- **Click-Through** — Only the character intercepts clicks; everything else passes through to your workspace
- **Gesture Control** — Drag to move, pinch to zoom, two-finger scroll to rotate 360 degrees
- **AI Chat** — Double-click to open a Claude Code terminal with her own personality and memory
- **Slap Reaction** — Slap your MacBook and she screams back with anime voice effects and comic speech bubbles (uses Apple Silicon accelerometer via IOKit HID)

### Subscription Agent `[Coming Soon]`

- **Email Monitoring** — Forward subscription emails to an AgentMail inbox for automatic parsing
- **Smart Analysis** — Claude extracts service name, price, billing cycle, and usage signals
- **Telegram Alerts** — Receive formatted analysis with action buttons: Cancel / Keep / Review
- **Browser Automation** — Playwright navigates cancellation flows with screenshots at every step
- **Human in the Loop** — Every destructive action requires your explicit approval

## Getting Started

### Desktop Companion

```bash
cd desktop-girl

# Compile
swiftc -framework AppKit -framework SceneKit -framework Foundation \
  -framework IOKit -framework AVFoundation \
  -o desktop-girl main.swift Config.swift ShellEnvironment.swift \
  ClaudeSession.swift KeyableWindow.swift TerminalView.swift \
  PetSCNView.swift AppDelegate.swift SlapDetector.swift ComicBubbleView.swift

# Compile the accelerometer helper (for slap detection)
swiftc -framework Foundation -framework IOKit -o accel-helper accel-helper.swift

# Run
./desktop-girl ./model/foxgirl_new.usdz
```

> **Note:** Slap detection requires the accelerometer helper to run with root privileges. Set it up with:
> ```bash
> sudo chown root accel-helper && sudo chmod 4755 accel-helper
> ```

### Requirements

- macOS 14.0+ with Apple Silicon
- [Claude Code CLI](https://claude.ai/download) installed and logged in

## Controls

| Action | Input |
|:-------|:------|
| Move | Drag the model |
| Rotate | Click model to focus, then two-finger scroll |
| Zoom | Click model to focus, then pinch |
| Chat | Double-click the model |
| Close chat | `Esc` or click outside the chat window |
| Unfocus | Click anywhere outside the model |
| Slap | Physically slap your MacBook |

## Architecture

```
desktop-girl/
├── main.swift              # App entry point
├── Config.swift            # Character name and persona loader
├── AppDelegate.swift       # Window, scene, events, popover, slap reaction
├── PetSCNView.swift        # 3D view, drag/zoom/rotate, click detection
├── TerminalView.swift      # Chat UI, markdown rendering, slash commands
├── ClaudeSession.swift     # Claude Code CLI process management
├── ShellEnvironment.swift  # Shell PATH resolution
├── SlapDetector.swift      # Accelerometer helper launcher
├── ComicBubbleView.swift   # Comic-style speech bubble
├── accel-helper.swift      # Standalone accelerometer reader (runs as root)
├── persona/                # Character personality files (editable .md)
│   ├── identity.md
│   ├── personality.md
│   ├── preferences.md
│   └── memory.md
├── sounds/
│   ├── slap/               # Slap reaction sound effects
│   └── ping/               # Completion notification sounds
└── model/
    └── foxgirl_new.usdz    # 3D model
```

| Component | Technology |
|:----------|:-----------|
| 3D Rendering | SceneKit (macOS native) |
| Desktop App | Swift + AppKit |
| AI Terminal | Claude Code CLI (stream-json) |
| Slap Detection | Apple Silicon accelerometer via IOKit HID |
| Sound Effects | AVFoundation |
| Character Persona | Editable markdown files |

## Roadmap

- [x] 3D desktop companion with gesture controls
- [x] Claude Code terminal integration
- [x] Slap detection with anime voice reactions
- [x] Comic speech bubbles
- [x] Thinking/completion bubbles
- [ ] Subscription email monitoring (AgentMail)
- [ ] Telegram notification with action buttons
- [ ] Browser automation for cancellation flows
- [ ] Custom sound pack support
- [ ] Multiple character models

## License

MIT
