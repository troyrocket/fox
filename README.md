# DesktopFox

**Your desktop girlfriend that can save you money.**

DesktopFox is a 3D fox-girl AI companion that lives on your macOS desktop. She floats transparently over your workspace, responds to trackpad gestures, and chats with you powered by Claude AI. Beyond being cute, she's connected to an AI subscription management agent that helps you track, analyze, and cancel unused subscriptions — saving you money while you work.

## Features

- **3D Desktop Companion** — A fox-girl model rendered via SceneKit, floating transparently on your desktop
- **Natural Interaction** — Drag to move, trackpad scroll to rotate 360°, pinch to zoom
- **Click-Through Transparency** — Only the character intercepts clicks; everything else passes through to your desktop
- **AI Chat** — Click her to open a chat window powered by Claude. She has her own personality and remembers your conversation
- **Subscription Manager** — Forwards your subscription emails to an AI agent that analyzes usage, recommends cancellations, and automates the process via browser automation
- **Human in the Loop** — The agent never acts without your confirmation. Every cancellation requires explicit approval

## Quick Start

### Desktop Companion

```bash
cd desktop-pet
# Set your API key
export ANTHROPIC_API_KEY=sk-ant-...

# Compile and run
swiftc -framework AppKit -framework SceneKit -framework Foundation -o desktopfox main.swift
./desktopfox path/to/model.usdz
```

### Subscription Agent

```bash
pip install -r requirements.txt

# Configure .env with your keys:
# ANTHROPIC_API_KEY, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, AGENTMAIL_API_KEY

python main.py          # Watch mode: TG bot + email polling
python main.py --once   # Single run
```

## Controls

| Action | Input |
|--------|-------|
| Move | Left-click drag on model |
| Rotate 360° | Two-finger scroll (after clicking model) |
| Zoom | Pinch gesture (after clicking model) |
| Chat | Click model |
| Close chat | Esc or click outside |

## How the Subscription Agent Works

```
Forward subscription emails → AgentMail inbox
                                ↓
              Claude AI parses subscription info
              (name, amount, billing cycle, usage signals)
                                ↓
              Telegram Bot sends analysis + action buttons
              "Loom $12.5/mo — 0 videos in 4 weeks. Keep it?"
                                ↓
              You decide: Cancel / Keep / Review
                                ↓
              Browser agent automates cancellation flow
              Screenshots at every step for your confirmation
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| 3D Rendering | SceneKit (macOS native) |
| AI Chat | Claude API (Anthropic) |
| Email Ingestion | AgentMail |
| Subscription Parsing | Claude Haiku |
| Agent Framework | Claude Sonnet (tool-use loop) |
| Web Automation | Playwright |
| User Interaction | Telegram Bot |

## Requirements

- macOS Sonoma (14.0+)
- Anthropic API key
- For subscription agent: Telegram Bot token, AgentMail API key

## License

MIT
