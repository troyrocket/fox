<p align="center">
  <h1 align="center">Desktop Fox</h1>
  <p align="center">
    A 3D AI companion on your macOS desktop that chats with you and saves you money.
  </p>
</p>

<p align="center">
  <a href="#features">Features</a> &nbsp;&bull;&nbsp;
  <a href="#getting-started">Getting Started</a> &nbsp;&bull;&nbsp;
  <a href="#controls">Controls</a> &nbsp;&bull;&nbsp;
  <a href="#architecture">Architecture</a> &nbsp;&bull;&nbsp;
  <a href="#license">License</a>
</p>

---

## Features

### Desktop Companion

- **3D Character** — A fox-girl model rendered via SceneKit, floating transparently on your desktop
- **Click-Through** — Only the character intercepts clicks; everything else passes through to your workspace
- **Gesture Control** — Drag to move, pinch to zoom, two-finger scroll to rotate 360 degrees
- **AI Chat** — Click her head to open a Claude-powered chat window with its own personality and memory

### Subscription Agent

- **Email Monitoring** — Forward subscription emails to an AgentMail inbox for automatic parsing
- **Smart Analysis** — Claude extracts service name, price, billing cycle, and usage signals
- **Telegram Alerts** — Receive formatted analysis with action buttons: Cancel / Keep / Review
- **Browser Automation** — Playwright navigates cancellation flows with screenshots at every step
- **Human in the Loop** — Every destructive action requires your explicit approval

## Getting Started

### Desktop Companion

```bash
cd desktop-girl

export ANTHROPIC_API_KEY=sk-ant-...

swiftc -framework AppKit -framework SceneKit -framework Foundation \
  -o desktop-girl main.swift

./desktop-girl ./model/foxgirl_new.usdz
```

### Subscription Agent

```bash
pip install -r requirements.txt
```

Create a `.env` file with the following keys:

```
ANTHROPIC_API_KEY=sk-ant-...
TELEGRAM_BOT_TOKEN=...
TELEGRAM_CHAT_ID=...
AGENTMAIL_API_KEY=...
```

```bash
python main.py            # Watch mode — polls emails + Telegram bot
python main.py --once     # Single check
```

## Controls

| Action | Input |
|:-------|:------|
| Move | Drag the model |
| Rotate | Click model to focus, then two-finger scroll |
| Zoom | Click model to focus, then pinch |
| Chat | Click her head |
| Close chat | `Esc` or click outside the chat window |
| Unfocus | Click anywhere outside the model |

## How the Agent Works

1. **Detect** — You forward a subscription email to the AgentMail inbox
2. **Parse** — Claude extracts service name, price, billing cycle, and usage signals
3. **Alert** — Telegram sends you the analysis: *"Loom $12.5/mo — 0 videos in 4 weeks. Cancel?"*
4. **Decide** — You tap Cancel, Keep, or Review
5. **Execute** — Browser agent navigates the cancellation flow with screenshots at every step
6. **Confirm** — You approve the final action before anything is cancelled

## Architecture

| Component | Technology |
|:----------|:-----------|
| 3D Rendering | SceneKit (macOS native) |
| Desktop App | Swift + AppKit |
| AI Chat | Claude Sonnet 4 |
| Email Parsing | Claude Haiku |
| Agent Framework | Claude tool-use loop |
| Browser Automation | Playwright |
| Email Ingestion | AgentMail |
| User Notifications | Telegram Bot |

## Requirements

- macOS 14.0+
- [Anthropic API key](https://console.anthropic.com/)
- For the subscription agent:
  - Telegram Bot token
  - AgentMail API key

## License

MIT
