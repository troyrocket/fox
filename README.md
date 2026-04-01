# DesktopFox

> A 3D AI companion that lives on your macOS desktop — and saves you money.

She floats transparently over your workspace, chats with you (powered by Claude), and manages your subscriptions. She watches your emails, finds subscriptions you forgot about, and helps you cancel them — all with your approval.

## What It Does

**Desktop Companion** — A 3D fox-girl rendered in SceneKit, always on top, click-through transparent. Drag her around, rotate, zoom, or click her head to chat.

**Subscription Agent** — Forward your subscription emails to the agent. It parses the service, price, and usage signals, then sends you a Telegram message: *"Loom $12.5/mo — 0 videos in 4 weeks. Cancel?"*. One tap to confirm, and the agent handles the rest via browser automation.

## Quick Start

### Desktop Companion

```bash
cd desktop-girl
export ANTHROPIC_API_KEY=sk-ant-...

# Compile
swiftc -framework AppKit -framework SceneKit -framework Foundation -o desktop-girl main.swift

# Run
./desktop-girl ./model/foxgirl_new.usdz
```

### Subscription Agent

```bash
pip install -r requirements.txt

# Set up .env:
# ANTHROPIC_API_KEY, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, AGENTMAIL_API_KEY

python main.py          # Watch mode (polls emails + Telegram bot)
python main.py --once   # Single check
```

## Controls

| Action | Input |
|--------|-------|
| **Move** | Drag the model |
| **Rotate** | Click model to focus, then two-finger scroll |
| **Zoom** | Click model to focus, then pinch |
| **Chat** | Click her head |
| **Close chat** | Esc or click outside |
| **Unfocus** | Click anywhere outside the model |

## How the Agent Works

```
You forward a subscription email
        ↓
Claude parses it (service, price, billing cycle, usage)
        ↓
Telegram sends you the analysis + action buttons
        ↓
You tap: Cancel / Keep / Review
        ↓
Browser agent navigates the cancellation flow
Screenshots at every step — you confirm before the final click
```

Every destructive action requires your explicit approval. The agent never cancels anything on its own.

## Tech Stack

| | |
|---|---|
| **3D Engine** | SceneKit (macOS native) |
| **AI** | Claude Sonnet 4 (agent) + Haiku (parsing) |
| **Desktop App** | Swift + AppKit |
| **Browser Automation** | Playwright |
| **Email** | AgentMail |
| **Notifications** | Telegram Bot |

## Requirements

- macOS 14.0+
- Anthropic API key
- For the subscription agent: Telegram Bot token, AgentMail API key

## License

MIT
