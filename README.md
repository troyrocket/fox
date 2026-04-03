<h1 align="center">Fox</h1>

<p align="center">
  Your personal AI CFO — she lives on your desktop, watches your money, and fights for every dollar.
</p>

<p align="center">
  <a href="#what-is-fox">What is Fox</a> &nbsp;&bull;&nbsp;
  <a href="#features">Features</a> &nbsp;&bull;&nbsp;
  <a href="#getting-started">Getting Started</a> &nbsp;&bull;&nbsp;
  <a href="#architecture">Architecture</a> &nbsp;&bull;&nbsp;
  <a href="#roadmap">Roadmap</a> &nbsp;&bull;&nbsp;
  <a href="#license">License</a>
</p>

---

## What is Fox

Fox is an AI financial assistant that sits on your macOS desktop as a 3D companion.

She does three things:
1. **Trades for you** — executes stocks and crypto trades so you don't have to stare at charts
2. **Kills waste** — finds subscriptions you forgot about and cancels them for you
3. **Talks to you** — not a dashboard, not a spreadsheet. A character you actually want to interact with

Most finance tools give you data. Fox gives you someone who cares about your money.

## Features

### 3D Desktop Companion

- **Always There** — a fox-girl character floating on your desktop, rendered in SceneKit
- **Click-Through** — only she intercepts clicks; everything else passes through to your workspace
- **Gesture Control** — drag to move, pinch to zoom, two-finger scroll to rotate
- **AI Chat** — double-click to talk. She has her own personality, memory, and opinions
- **Slap Reaction** — slap your MacBook and she screams back (Apple Silicon accelerometer)

### Spending Manager

- **Email Monitoring** — forward subscription emails to Fox and she parses them automatically
- **Smart Analysis** — extracts service name, price, billing cycle, and usage signals
- **Alerts** — receive analysis with action buttons: Cancel / Keep / Review
- **Auto-Cancellation** — she navigates cancellation flows in the browser, with screenshots at every step
- **Human in the Loop** — every destructive action requires your explicit approval

### Trader `[Coming Soon]`

- **Stocks & Crypto** — connect your brokerage and crypto wallets, she trades on your behalf
- **Smart Execution** — she picks entries, sets stops, and manages positions so you don't have to
- **Daily Briefing** — a quick morning summary of what happened and what she's planning
- **Always Asks First** — no trade goes through without your approval

## Requirements

- **macOS 14.0+** (Sonoma or later)
- **Apple Silicon** (M1/M2/M3/M4) — required for slap detection
- **Xcode Command Line Tools**

```bash
xcode-select --install
```

**For AI chat:**
- [Claude Code CLI](https://claude.ai/download)
```bash
curl -fsSL https://claude.ai/install.sh | sh
claude /login
```

## Getting Started

### 1. Clone

```bash
git clone https://github.com/troyrocket/fox.git
cd fox/desktop-girl
```

### 2. Build

```bash
# Main app
swiftc -framework AppKit -framework SceneKit -framework Foundation \
  -framework IOKit -framework AVFoundation \
  -o desktop-girl main.swift Config.swift ShellEnvironment.swift \
  ClaudeSession.swift KeyableWindow.swift TerminalView.swift \
  PetSCNView.swift AppDelegate.swift SlapDetector.swift ComicBubbleView.swift

# Accelerometer helper (for slap detection)
swiftc -framework Foundation -framework IOKit -o accel-helper accel-helper.swift
```

### 3. Enable slap detection

```bash
sudo chown root accel-helper && sudo chmod 4755 accel-helper
```

### 4. Run

```bash
./desktop-girl ./model/foxgirl_new.usdz
```

A fox girl appears on your desktop. She's ready to talk.

### What works today

| Feature | Status |
|:--------|:-------|
| 3D companion on desktop | ✅ |
| Drag, zoom, rotate | ✅ |
| AI chat with personality | ✅ |
| Slap → scream + speech bubble | ✅ |
| Subscription email parsing | ✅ |
| Cancel/Keep/Review alerts | ✅ |
| Browser auto-cancellation | ✅ |
| Stock & crypto trading | 🔜 |
| Portfolio management | 🔜 |

## Controls

| Action | Input |
|:-------|:------|
| Move | Drag the model |
| Rotate | Click model, then two-finger scroll |
| Zoom | Click model, then pinch |
| Chat | Double-click the model |
| Close chat | `Esc` or click outside |
| Slap | Physically slap your MacBook |

## Architecture

```
desktop-girl/          — 3D companion app (Swift / macOS native)
├── main.swift
├── AppDelegate.swift       # Window, scene, events, slap reaction
├── PetSCNView.swift        # 3D rendering, gestures, click detection
├── TerminalView.swift      # Chat UI with markdown
├── ClaudeSession.swift     # Claude Code CLI integration
├── SlapDetector.swift      # Accelerometer via IOKit HID
├── ComicBubbleView.swift   # Speech bubbles
├── persona/                # Her personality (editable markdown)
├── sounds/                 # Voice effects
└── model/                  # 3D model (.usdz)

src/                   — Spending agent (Python)
├── agent_brain.py          # Claude tool-use loop
├── tools.py                # Email, browser, notification tools
├── email_parser.py         # Subscription email analysis
├── browser_agent.py        # Playwright automation
└── telegram_bot.py         # Alert delivery
```

| Layer | Technology |
|:------|:-----------|
| 3D Rendering | SceneKit |
| Desktop App | Swift + AppKit |
| AI Chat | Claude Code CLI |
| Spending Agent | Claude API + Playwright |
| Slap Detection | Apple Silicon accelerometer (IOKit HID) |
| Alerts | Telegram Bot API |

## Roadmap

- [x] 3D desktop companion with gesture controls
- [x] AI chat with personality and memory
- [x] Slap detection with voice reactions
- [x] Subscription email monitoring and parsing
- [x] Cancel/Keep/Review alert system
- [x] Browser automation for cancellation flows
- [ ] Stock & crypto trading with approval flow
- [ ] Brokerage and wallet integration
- [ ] Daily briefing and portfolio reports
- [ ] Custom character models
- [ ] iOS companion app

## License

MIT
