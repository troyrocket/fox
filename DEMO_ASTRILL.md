# Demo with Astrill VPN

## Setup Steps

### 1. AgentMail Setup
- Create inbox: `undercurrent@agentmail.to`
- Get API key from AgentMail dashboard

### 2. Telegram Bot
- Create bot via @BotFather
- Get bot token
- Get your chat ID (send message to bot, check via API)

### 3. Environment Variables
```
ANTHROPIC_API_KEY=sk-ant-...
AGENTMAIL_API_KEY=...
TELEGRAM_BOT_TOKEN=...
TELEGRAM_CHAT_ID=...
```

### 4. Astrill VPN
- Connect to US server for Telegram API access
- Ensure stable connection before demo

### 5. Demo Flow
1. Forward real subscription emails to `undercurrent@agentmail.to`
2. Run `python main.py`
3. Wait for TG notification with subscription analysis
4. Click "Cancel" on a subscription
5. Agent opens browser, navigates cancellation flow
6. Screenshot sent to TG for final confirmation
7. Confirm → Agent executes

### 6. Backup Plan
- If VPN drops: show pre-recorded demo video
- If AgentMail slow: have pre-parsed emails ready
- If browser automation fails: show the analysis + TG interaction part

### Tips
- Keep Astrill connected throughout
- Test TG bot connection before demo
- Have 2-3 real subscription emails ready (Loom, Notion, etc.)
- Browser should be visible (headless=False) for audience
