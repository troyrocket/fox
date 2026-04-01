import anthropic
import json
import os

client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

PARSE_PROMPT = """你是一个订阅管理 AI。分析这封邮件，提取订阅信息。

返回 JSON 格式：
{
  "service_name": "服务名称",
  "amount": "金额（如 $30.00）",
  "billing_cycle": "billing cycle（monthly/yearly/expired）",
  "status": "active/expired/trial/cancelled",
  "expiry_date": "到期日（如果有）",
  "account_email": "账号邮箱",
  "action_url": "续费或取消链接（如果有）",
  "cancel_url": "取消链接（如果有）",
  "usage_signals": "使用信号描述（从邮件内容推断用量）",
  "recommendation": "keep/cancel/review",
  "recommendation_reason": "推荐原因（中文，一句话）"
}

如果某字段无法提取，填 null。
"""

def parse_subscription_email(subject: str, body: str, sender: str) -> dict:
    """用 Claude 解析订阅邮件，返回结构化信息"""
    
    content = f"发件人: {sender}\n主题: {subject}\n\n邮件内容:\n{body[:3000]}"
    
    response = client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=1024,
        messages=[{
            "role": "user",
            "content": f"{PARSE_PROMPT}\n\n邮件:\n{content}"
        }]
    )
    
    text = response.content[0].text
    # 提取 JSON
    start = text.find("{")
    end = text.rfind("}") + 1
    if start >= 0 and end > start:
        return json.loads(text[start:end])
    return {}
