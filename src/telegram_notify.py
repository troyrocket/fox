import requests
import os

BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
CHAT_ID = os.getenv("TELEGRAM_CHAT_ID")

def send_message(text: str) -> dict:
    """发送 Telegram 消息"""
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    resp = requests.post(url, json={
        "chat_id": CHAT_ID,
        "text": text,
        "parse_mode": "Markdown"
    })
    return resp.json()

def format_subscription_alert(info: dict, raw_subject: str) -> str:
    """格式化订阅摘要消息"""
    status_emoji = {
        "active": "🟢", 
        "expired": "🔴", 
        "trial": "🟡", 
        "cancelled": "⚫"
    }.get(info.get("status", ""), "⚪")
    
    rec_emoji = {
        "cancel": "❌ 建议取消",
        "keep": "✅ 建议保留",
        "review": "🤔 需要确认"
    }.get(info.get("recommendation", ""), "")

    lines = [
        f"🌊 *Undercurrent 订阅分析*",
        f"━━━━━━━━━━━━━━━━",
        f"{status_emoji} *{info.get('service_name', '未知服务')}*",
        f"💰 金额：{info.get('amount', 'N/A')} / {info.get('billing_cycle', 'N/A')}",
    ]
    
    if info.get("status") == "expired" and info.get("expiry_date"):
        lines.append(f"📅 已于 {info.get('expiry_date')} 过期")
    
    if info.get("account_email"):
        lines.append(f"📧 账号：{info.get('account_email')}")
    
    if info.get("usage_signals"):
        lines.append(f"📊 使用信号：{info.get('usage_signals')}")
    
    lines += [
        f"━━━━━━━━━━━━━━━━",
        f"{rec_emoji}",
        f"💡 {info.get('recommendation_reason', '')}",
        f"━━━━━━━━━━━━━━━━",
        f"*请回复指令：*",
        f"1️⃣ 取消订阅",
        f"2️⃣ 保留订阅",
        f"3️⃣ 查看续费选项",
    ]
    
    if info.get("action_url"):
        lines.append(f"\n🔗 续费链接：{info.get('action_url')}")

    return "\n".join(lines)
