"""双向 Telegram Bot：发送消息 + 接收用户回调"""

import os
from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update, Bot
from telegram.ext import Application, CallbackQueryHandler, CommandHandler, ContextTypes, MessageHandler, filters

BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
CHAT_ID = os.getenv("TELEGRAM_CHAT_ID")

_bot: Bot = None


def get_bot() -> Bot:
    global _bot
    if _bot is None:
        _bot = Bot(token=BOT_TOKEN)
    return _bot


async def send_message(text: str) -> dict:
    """发送纯文本消息"""
    bot = get_bot()
    msg = await bot.send_message(
        chat_id=CHAT_ID,
        text=text,
        parse_mode="Markdown",
    )
    return {"ok": True, "message_id": msg.message_id}


async def send_message_with_buttons(text: str, buttons: list[dict], interaction_id: str) -> dict:
    """
    发送带 InlineKeyboard 按钮的消息。
    buttons: [{"text": "Cancel", "value": "cancel"}, ...]
    callback_data 格式: "{interaction_id}:{value}"
    """
    bot = get_bot()
    keyboard = [
        [InlineKeyboardButton(
            text=btn["text"],
            callback_data=f"{interaction_id}:{btn['value']}"
        ) for btn in buttons]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    msg = await bot.send_message(
        chat_id=CHAT_ID,
        text=text,
        parse_mode="Markdown",
        reply_markup=reply_markup,
    )
    return {"ok": True, "message_id": msg.message_id}


async def send_photo(photo_path: str, caption: str = "") -> dict:
    """发送截图"""
    bot = get_bot()
    with open(photo_path, "rb") as f:
        msg = await bot.send_photo(
            chat_id=CHAT_ID,
            photo=f,
            caption=caption,
            parse_mode="Markdown",
        )
    return {"ok": True, "message_id": msg.message_id}


async def send_photo_with_buttons(photo_path: str, caption: str, buttons: list[dict], interaction_id: str) -> dict:
    """发送截图 + 按钮"""
    bot = get_bot()
    keyboard = [
        [InlineKeyboardButton(
            text=btn["text"],
            callback_data=f"{interaction_id}:{btn['value']}"
        ) for btn in buttons]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    with open(photo_path, "rb") as f:
        msg = await bot.send_photo(
            chat_id=CHAT_ID,
            photo=f,
            caption=caption,
            parse_mode="Markdown",
            reply_markup=reply_markup,
        )
    return {"ok": True, "message_id": msg.message_id}


def build_application(state) -> Application:
    """构建 Telegram Application，注册回调处理器"""
    app = Application.builder().token(BOT_TOKEN).build()

    async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
        await update.message.reply_text(
            "🌊 *Undercurrent Agent*\n"
            "正在监听您的订阅邮件，有发现会自动通知您。",
            parse_mode="Markdown",
        )

    async def callback_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
        query = update.callback_query
        await query.answer()

        data = query.data  # "int_xxx:cancel"
        if ":" not in data:
            return

        interaction_id, choice = data.split(":", 1)

        # 更新按钮文字，标记已选择
        await query.edit_message_reply_markup(reply_markup=None)
        await query.message.reply_text(f"✅ 已收到您的选择: *{choice}*", parse_mode="Markdown")

        # 解锁 Agent 等待
        state.resolve_interaction(interaction_id, choice)

    async def text_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
        """处理用户发送的文本消息，转发给 Agent"""
        # 简单回复，后续可以扩展为自由对话
        await update.message.reply_text(
            "🌊 收到！目前我通过按钮交互，请等待订阅分析结果后选择操作。"
        )

    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(CallbackQueryHandler(callback_handler))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, text_handler))

    return app
