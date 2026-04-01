"""Agent 工具实现层：每个函数对应一个 Claude tool"""

import asyncio
import json
import os
import base64

from agentmail import AgentMail
from src.email_parser import parse_subscription_email
from src.browser_agent import BrowserSession
from src.state import AgentState
from src import telegram_bot

AGENTMAIL_API_KEY = os.getenv("AGENTMAIL_API_KEY")
INBOX = os.getenv("AGENTMAIL_INBOX", "undercurrent@agentmail.to")
PROCESSED_FILE = ".processed_messages.json"


def _load_processed() -> set:
    if os.path.exists(PROCESSED_FILE):
        with open(PROCESSED_FILE) as f:
            return set(json.load(f))
    return set()


def _save_processed(ids: set):
    with open(PROCESSED_FILE, "w") as f:
        json.dump(list(ids), f)


# ── Email 工具 ──────────────────────────────────────

async def check_emails(state: AgentState) -> dict:
    """拉取收件箱，解析新邮件，返回订阅信息列表"""
    def _sync_check():
        client = AgentMail(api_key=AGENTMAIL_API_KEY)
        processed = _load_processed()
        messages = client.inboxes.messages.list(INBOX)

        results = []
        for msg in messages.messages:
            msg_id = msg.message_id
            if msg_id in processed:
                continue

            thread = client.inboxes.threads.get(INBOX, msg.thread_id)
            full_msg = thread.messages[0]
            body = full_msg.text or ""

            info = parse_subscription_email(
                subject=msg.subject or "",
                body=body,
                sender=msg.from_ or "",
            )
            info["_msg_id"] = msg_id
            info["_subject"] = msg.subject or ""
            results.append(info)

            processed.add(msg_id)
            _save_processed(processed)

        return results

    results = await asyncio.to_thread(_sync_check)
    state.subscriptions.extend(results)

    if not results:
        return {"new_emails": 0, "message": "没有新邮件"}
    return {
        "new_emails": len(results),
        "subscriptions": results,
    }


# ── Telegram 工具 ────────────────────────────────────

async def send_telegram_alert(state: AgentState, **kwargs) -> dict:
    """发送订阅分析消息 + 行动按钮"""
    service = kwargs.get("service_name", "未知服务")
    amount = kwargs.get("amount", "N/A")
    cycle = kwargs.get("billing_cycle", "")
    status = kwargs.get("status", "")
    recommendation = kwargs.get("recommendation", "review")
    reason = kwargs.get("reason", "")
    cancel_url = kwargs.get("cancel_url", "")
    usage_signals = kwargs.get("usage_signals", "")

    status_emoji = {"active": "🟢", "expired": "🔴", "trial": "🟡", "cancelled": "⚫"}.get(status, "⚪")
    rec_emoji = {"cancel": "❌ 建议取消", "keep": "✅ 建议保留", "review": "🤔 需要确认"}.get(recommendation, "")

    text = (
        f"🌊 *Undercurrent 订阅分析*\n"
        f"━━━━━━━━━━━━━━━━\n"
        f"{status_emoji} *{service}*\n"
        f"💰 金额：{amount} / {cycle}\n"
    )
    if usage_signals:
        text += f"📊 使用信号：{usage_signals}\n"
    text += (
        f"━━━━━━━━━━━━━━━━\n"
        f"{rec_emoji}\n"
        f"💡 {reason}\n"
        f"━━━━━━━━━━━━━━━━\n"
        f"*请选择操作：*"
    )

    buttons = [
        {"text": "❌ 取消订阅", "value": "cancel"},
        {"text": "✅ 保留", "value": "keep"},
        {"text": "🔍 查看详情", "value": "review"},
    ]

    interaction = state.create_interaction(
        question=f"用户对 {service} 的决定",
        options=["cancel", "keep", "review"],
    )

    await telegram_bot.send_message_with_buttons(text, buttons, interaction.interaction_id)
    return {"interaction_id": interaction.interaction_id}


async def wait_for_user_response(state: AgentState, interaction_id: str) -> dict:
    """阻塞等待用户回应"""
    if interaction_id not in state.pending:
        return {"error": f"Unknown interaction: {interaction_id}"}

    interaction = state.pending[interaction_id]
    await interaction.event.wait()
    response = interaction.response

    # 清理
    del state.pending[interaction_id]
    return {"response": response}


async def send_screenshot_to_user(state: AgentState, screenshot_path: str, caption: str) -> dict:
    """发送截图 + Confirm/Abort 按钮"""
    buttons = [
        {"text": "✅ 确认执行", "value": "confirm"},
        {"text": "🚫 取消", "value": "abort"},
    ]
    interaction = state.create_interaction(
        question="用户确认操作",
        options=["confirm", "abort"],
    )
    await telegram_bot.send_photo_with_buttons(
        screenshot_path, caption, buttons, interaction.interaction_id
    )
    return {"interaction_id": interaction.interaction_id}


# ── Browser 工具 ─────────────────────────────────────

def _get_browser(state: AgentState) -> BrowserSession:
    if state.browser_session is None:
        state.browser_session = BrowserSession()
    return state.browser_session


async def open_browser(state: AgentState, url: str) -> dict:
    browser = _get_browser(state)
    result = await browser.goto(url)
    # 获取页面文本帮助 Agent 理解
    page_text = await browser.get_page_text()
    result["page_text"] = page_text[:2000]
    return result


async def take_screenshot(state: AgentState) -> dict:
    browser = _get_browser(state)
    path = await browser.screenshot()
    return {"screenshot_path": path}


async def click_element(state: AgentState, selector: str) -> dict:
    browser = _get_browser(state)
    result = await browser.click(selector)
    if result.get("success"):
        page_text = await browser.get_page_text()
        result["page_text"] = page_text[:2000]
    return result


async def fill_form_field(state: AgentState, selector: str, value: str) -> dict:
    browser = _get_browser(state)
    return await browser.fill(selector, value)


async def close_browser(state: AgentState) -> dict:
    browser = _get_browser(state)
    await browser.close()
    state.browser_session = None
    return {"success": True, "message": "浏览器已关闭"}
