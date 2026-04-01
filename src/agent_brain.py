"""Agent 大脑：Claude tool_use 循环"""

import json
import anthropic
from src.state import AgentState
from src import tools

client = anthropic.Anthropic()

SYSTEM_PROMPT = """You are Undercurrent, a personal subscription management AI agent.

Your job:
1. Check the user's email inbox for subscription-related emails
2. Analyze each subscription (service, amount, usage, value)
3. Send the user a Telegram alert with your analysis and action buttons
4. Wait for the user's decision
5. If they want to cancel: open the cancellation page in a browser, navigate the flow step by step
6. At each step, describe what you see on the page and what you'll do next
7. Before any destructive action (final cancel click, payment submit), send a screenshot and wait for explicit confirmation
8. Report the result back to the user

CRITICAL RULES:
- NEVER execute a destructive action without user confirmation via send_screenshot_to_user + wait_for_user_response
- Always explain what you see on the page before clicking
- If a page needs login credentials, tell the user — never guess passwords
- Take screenshots at every major step so the user can follow along
- Communicate in Chinese (简体中文) when sending messages to the user
- Be concise and actionable in your analysis

WORKFLOW:
1. Call check_emails to see new subscription emails
2. For each subscription found, call send_telegram_alert, then wait_for_user_response
3. Based on user's choice:
   - "cancel": open_browser with the cancel_url, navigate the cancellation flow
   - "keep": acknowledge and move on
   - "review": provide more details, ask again
4. During browser automation, use click_element and fill_form_field as needed
5. Always send_screenshot_to_user before the final destructive step
6. After completion, close_browser
"""

TOOLS = [
    {
        "name": "check_emails",
        "description": "Check the AgentMail inbox for new subscription emails. Returns parsed subscription info for each new email.",
        "input_schema": {
            "type": "object",
            "properties": {},
            "required": [],
        },
    },
    {
        "name": "send_telegram_alert",
        "description": "Send a subscription analysis alert to the user via Telegram with action buttons (Cancel/Keep/Review). Returns an interaction_id for wait_for_user_response.",
        "input_schema": {
            "type": "object",
            "properties": {
                "service_name": {"type": "string", "description": "Name of the subscription service"},
                "amount": {"type": "string", "description": "Price amount, e.g. '$12.50'"},
                "billing_cycle": {"type": "string", "description": "monthly/yearly/one-time"},
                "status": {"type": "string", "enum": ["active", "expired", "trial", "cancelled"]},
                "recommendation": {"type": "string", "enum": ["cancel", "keep", "review"]},
                "reason": {"type": "string", "description": "Reason for the recommendation, in Chinese"},
                "cancel_url": {"type": "string", "description": "URL to cancel/manage the subscription"},
                "usage_signals": {"type": "string", "description": "Usage signals extracted from email"},
            },
            "required": ["service_name", "amount", "recommendation", "reason"],
        },
    },
    {
        "name": "wait_for_user_response",
        "description": "Wait for the user to click a button on a previous Telegram message. Blocks until response. Returns the user's choice string.",
        "input_schema": {
            "type": "object",
            "properties": {
                "interaction_id": {"type": "string"},
            },
            "required": ["interaction_id"],
        },
    },
    {
        "name": "open_browser",
        "description": "Open a URL in the browser. Returns page title, URL, screenshot path, and visible page text.",
        "input_schema": {
            "type": "object",
            "properties": {
                "url": {"type": "string"},
            },
            "required": ["url"],
        },
    },
    {
        "name": "take_screenshot",
        "description": "Take a screenshot of the current browser page.",
        "input_schema": {
            "type": "object",
            "properties": {},
            "required": [],
        },
    },
    {
        "name": "click_element",
        "description": "Click a page element by CSS selector. Returns success status, new screenshot, and page text.",
        "input_schema": {
            "type": "object",
            "properties": {
                "selector": {"type": "string", "description": "CSS selector of the element to click"},
            },
            "required": ["selector"],
        },
    },
    {
        "name": "fill_form_field",
        "description": "Fill a form field by CSS selector with a value.",
        "input_schema": {
            "type": "object",
            "properties": {
                "selector": {"type": "string"},
                "value": {"type": "string"},
            },
            "required": ["selector", "value"],
        },
    },
    {
        "name": "send_screenshot_to_user",
        "description": "Send a browser screenshot to the user via Telegram with Confirm/Abort buttons. Use before any destructive action. Returns an interaction_id.",
        "input_schema": {
            "type": "object",
            "properties": {
                "screenshot_path": {"type": "string"},
                "caption": {"type": "string", "description": "Caption explaining what's about to happen"},
            },
            "required": ["screenshot_path", "caption"],
        },
    },
    {
        "name": "close_browser",
        "description": "Close the browser session when done.",
        "input_schema": {
            "type": "object",
            "properties": {},
            "required": [],
        },
    },
]

# ── 工具分发 ──────────────────────────────────────

TOOL_MAP = {
    "check_emails": lambda state, params: tools.check_emails(state),
    "send_telegram_alert": lambda state, params: tools.send_telegram_alert(state, **params),
    "wait_for_user_response": lambda state, params: tools.wait_for_user_response(state, params["interaction_id"]),
    "open_browser": lambda state, params: tools.open_browser(state, params["url"]),
    "take_screenshot": lambda state, params: tools.take_screenshot(state),
    "click_element": lambda state, params: tools.click_element(state, params["selector"]),
    "fill_form_field": lambda state, params: tools.fill_form_field(state, params["selector"], params["value"]),
    "send_screenshot_to_user": lambda state, params: tools.send_screenshot_to_user(state, params["screenshot_path"], params["caption"]),
    "close_browser": lambda state, params: tools.close_browser(state),
}


async def run_agent_loop(state: AgentState, trigger: str = "Check for new subscription emails and process them."):
    """运行 Agent 循环：Claude 决策 → 调用工具 → 返回结果 → 继续"""
    messages = [{"role": "user", "content": trigger}]

    print(f"\n[Agent] 启动，触发消息: {trigger[:60]}...")

    while True:
        print("[Agent] 调用 Claude...")
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            system=SYSTEM_PROMPT,
            tools=TOOLS,
            messages=messages,
        )

        # 收集 assistant 回复
        assistant_content = response.content

        # 打印 text blocks
        for block in assistant_content:
            if hasattr(block, "text"):
                print(f"[Agent] 💬 {block.text}")

        # 如果没有工具调用，结束循环
        if response.stop_reason == "end_turn":
            print("[Agent] 循环结束")
            break

        # 处理工具调用
        tool_results = []
        for block in assistant_content:
            if block.type == "tool_use":
                tool_name = block.name
                tool_input = block.input
                print(f"[Agent] 🔧 调用工具: {tool_name}({json.dumps(tool_input, ensure_ascii=False)[:100]})")

                handler = TOOL_MAP.get(tool_name)
                if handler:
                    try:
                        result = await handler(state, tool_input)
                    except Exception as e:
                        result = {"error": str(e)}
                        print(f"[Agent] ❌ 工具错误: {e}")
                else:
                    result = {"error": f"Unknown tool: {tool_name}"}

                print(f"[Agent] 📦 结果: {json.dumps(result, ensure_ascii=False)[:200]}")
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": json.dumps(result, ensure_ascii=False),
                })

        # 追加到消息历史，继续循环
        messages.append({"role": "assistant", "content": assistant_content})
        messages.append({"role": "user", "content": tool_results})

    print("[Agent] ✅ 本轮处理完成\n")
