<h1 align="center">Fox</h1>

<p align="center">
  Your personal AI CFO — she lives on your desktop, watches your money, and fights for every dollar.
</p>

<p align="center">
  <a href="#what-is-fox">What is Fox</a> &nbsp;&bull;&nbsp;
  <a href="#features">Features</a> &nbsp;&bull;&nbsp;
  <a href="#how-it-works">How it Works</a> &nbsp;&bull;&nbsp;
  <a href="#getting-started">Getting Started</a> &nbsp;&bull;&nbsp;
  <a href="#architecture">Architecture</a> &nbsp;&bull;&nbsp;
  <a href="#roadmap">Roadmap</a>
</p>

---

## What is Fox

Fox is an AI financial assistant that sits on your macOS desktop as a 3D companion.

Most finance tools give you dashboards, charts, and spreadsheets. Fox gives you a character who actually manages your money — she talks to you, makes recommendations, and takes action on your behalf.

She does three things:
1. **Trades for you** — executes stocks and crypto trades on Polymarket and US brokerages, so you don't have to stare at charts all day
2. **Kills waste** — monitors your email for subscription charges, analyzes which ones you actually use, and cancels the rest through browser automation
3. **Talks to you** — not another app you forget to open. She's always on your desktop, ready to chat about your finances or anything else

Every action that touches your money requires your explicit approval. She'll show you exactly what she's about to do, take a screenshot, and wait for you to say "yes" before proceeding.

<p align="center">
  <img src="profile.png?v=2" alt="Fox" width="100%">
</p>

## Features

### 3D Desktop Companion

Fox lives on your macOS desktop as a 3D character rendered in SceneKit. She floats transparently over your workspace — only she intercepts clicks, everything else passes through to your apps.

- **Gesture Control** — drag to reposition, pinch to zoom, two-finger scroll to rotate her 360 degrees
- **AI Chat** ��� double-click to open a chat terminal powered by Claude Code. She has her own personality, memory, and opinions about your spending habits
- **Slap Reaction** — physically slap your MacBook and she reacts with anime voice effects and comic speech bubbles (uses Apple Silicon accelerometer via IOKit HID)
- **Persona System** — her identity, personality, and preferences are defined in editable markdown files. Customize who she is and how she talks

### Trader

Fox can trade on your behalf across prediction markets and stock brokerages. She uses Claude's Computer Use to navigate trading platforms in a real browser — the same way you would, but faster.

- **Polymarket** — browse prediction markets, analyze odds and volume, place bets on outcomes. She reads the market page, recommends a position, and sets up the trade for your confirmation
- **US Stocks** — search tickers, view stock details, place buy/sell orders through your brokerage account (Robinhood, Schwab, etc.)
- **Smart Execution** — she picks entries, sets stops, and manages positions based on the current market context
- **Daily Briefing** — a quick morning summary of what happened overnight, what your positions look like, and what she's planning next
- **Always Asks First** — no trade goes through without your explicit "yes". She shows a screenshot of the order before every execution

### Spending Manager

Fox monitors your email for subscription charges and helps you cancel the ones you don't need. She connects to your inbox via AgentMail and uses browser automation to handle cancellation flows end-to-end.

- **Email Monitoring** — forward subscription emails to `undercurrent-agent@agentmail.to` and Fox parses them automatically using Claude. She extracts service name, price, billing cycle, renewal date, and usage signals
- **Smart Analysis** — for each subscription, she gives you a recommendation (cancel / keep / review) with a one-line reason. She considers how often you use the service, what you're paying, and whether there's a cheaper alternative
- **Browser Automation** — when you decide to cancel, Fox opens the service's cancellation page and navigates the flow step by step. She fills forms, clicks through retention offers, and handles the multi-step flows that companies design to keep you subscribed
- **Payment Management** — need to update your card on file? Fox can fill in payment information on subscription pages via browser automation
- **Human in the Loop** — every destructive action (final cancel click, payment submission) requires your explicit approval. She takes a screenshot, describes what she's about to do, and waits for confirmation

## How it Works

Fox combines two systems:

**1. Desktop Companion (Swift / macOS native)**

A native macOS app that renders a 3D character on your desktop using SceneKit. The character has a built-in chat terminal that connects to Claude Code CLI. When you double-click her, you can ask her anything — check your subscriptions, place a trade, or just chat. Her personality is defined in editable markdown files under `persona/`.

**2. Financial Agent (Python / Claude API)**

A Python backend that handles the actual financial operations. It uses Claude's tool-use loop to decide what to do, then executes actions through:
- **AgentMail** — for reading and parsing subscription emails
- **Computer Use** — for controlling the browser to navigate trading platforms and subscription management pages
- **Claude** — for analyzing subscriptions, making trade recommendations, and deciding next steps

The two systems connect through Claude Code CLI — the desktop companion is the interface, the Python agent is the brain.

## Getting Started

### Requirements

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

**For spending management:**
```bash
pip install -r requirements.txt
playwright install chromium
```

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

The accelerometer requires root privileges. Run this once:

```bash
sudo chown root accel-helper && sudo chmod 4755 accel-helper
```

### 4. Run

```bash
./desktop-girl ./model/foxgirl_new.usdz
```

A 3D fox girl appears on your desktop. Double-click her to start chatting.

### What works today

| Feature | Status |
|:--------|:-------|
| 3D companion on desktop | ✅ |
| Drag, zoom, rotate gestures | ✅ |
| AI chat with personality & memory | ✅ |
| Slap → scream + speech bubble | ✅ |
| Subscription email parsing | ✅ |
| Cancel/Keep/Review recommendations | ✅ |
| Browser automation for cancellations | ✅ |
| Polymarket trading | ✅ |
| US stock trading | ✅ |
| Portfolio management | 🔜 |
| Daily market briefing | 🔜 |

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
desktop-girl/              — 3D companion app (Swift / macOS native)
├── main.swift                  Entry point
├── AppDelegate.swift           Window, scene, events, slap reaction
├── PetSCNView.swift            3D rendering, gestures, click detection
├── TerminalView.swift          Chat UI with markdown rendering
├── ClaudeSession.swift         Claude Code CLI process management
├── SlapDetector.swift          Accelerometer via IOKit HID
├── ComicBubbleView.swift       Comic-style speech bubbles
├── persona/                    Her personality (editable .md files)
│   ├── identity.md             Who she is
│   ├── personality.md          How she behaves
│   ├── preferences.md          What she likes and dislikes
│   └── memory.md               What she remembers
├── sounds/                     Voice effects (slap reactions, notifications)
└── model/                      3D model (.usdz)

src/                       — Financial agent backend (Python)
├── agent_brain.py              Claude Computer Use agent loop
├── computer_use.py             Screenshot + mouse/keyboard control (macOS)
├── trading/
│   ├── polymarket.py           Polymarket: browse, trade, portfolio
│   └── stocks.py               US stocks: search, order, portfolio
└── spending/
    ├── email_monitor.py        AgentMail inbox reader
    ├── email_parser.py         Claude-powered subscription parsing
    └── subscription_manager.py Browser automation for cancellations
```

| Layer | Technology |
|:------|:-----------|
| 3D Rendering | SceneKit (macOS native) |
| Desktop App | Swift + AppKit |
| AI Chat | Claude Code CLI (stream-json) |
| Financial Agent | Claude API + Computer Use |
| Email Parsing | AgentMail + Claude Haiku |
| Browser Control | screencapture + cliclick (macOS native) |
| Slap Detection | Apple Silicon accelerometer (IOKit HID) |

## Roadmap

- [x] 3D desktop companion with gesture controls
- [x] AI chat with personality and memory
- [x] Slap detection with anime voice reactions
- [x] Subscription email monitoring and parsing
- [x] Cancel/Keep/Review recommendation system
- [x] Browser automation for cancellation flows
- [x] Polymarket prediction market trading
- [x] US stock trading via brokerage
- [ ] Portfolio dashboard and tracking
- [ ] Daily market briefing
- [ ] Payment method auto-fill
- [ ] Custom character models
- [ ] iOS companion app

## License

MIT
