#!/usr/bin/env python3
"""
Undercurrent Agent — AI 订阅管理 Agent
用法: python main.py [--once]
默认启动监听模式（TG Bot + 邮件轮询 + Agent 循环）
"""

import os
import sys
import asyncio
import argparse
import signal
from dotenv import load_dotenv

load_dotenv()

from src.state import AgentState
from src.telegram_bot import build_application, send_message
from src.agent_brain import run_agent_loop


async def email_watcher(state: AgentState, interval: int = 60):
    """定期检查邮件并触发 Agent 循环"""
    while True:
        try:
            await run_agent_loop(state)
        except Exception as e:
            print(f"[Watcher] ❌ 错误: {e}")
            import traceback
            traceback.print_exc()
        print(f"[Watcher] 等待 {interval}s...\n")
        await asyncio.sleep(interval)


async def run_once(state: AgentState):
    """单次运行：检查邮件 → 处理 → 退出"""
    print("[Undercurrent] 单次运行模式")
    await run_agent_loop(state)
    print("[Undercurrent] 完成")


async def run_watch(state: AgentState, interval: int = 60):
    """监听模式：TG Bot + 邮件定时轮询"""
    print("[Undercurrent] 🌊 启动监听模式...")

    # 构建 Telegram Bot
    app = build_application(state)

    async with app:
        await app.start()
        await app.updater.start_polling(drop_pending_updates=True)
        print("[Undercurrent] ✅ Telegram Bot 已启动")

        # 发送启动消息
        try:
            await send_message(
                "🌊 *Undercurrent Agent 已启动*\n"
                "正在监听 `undercurrent@agentmail.to`\n"
                "转发订阅邮件到这个地址，我来帮你分析！"
            )
        except Exception as e:
            print(f"[TG] 启动消息发送失败: {e}")

        # 启动邮件轮询
        watcher = asyncio.create_task(email_watcher(state, interval))

        # 等待中断信号
        stop = asyncio.Event()
        loop = asyncio.get_event_loop()
        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(sig, stop.set)

        print("[Undercurrent] 🎯 运行中，按 Ctrl+C 退出\n")
        await stop.wait()

        # 清理
        print("\n[Undercurrent] 正在关闭...")
        watcher.cancel()
        try:
            await watcher
        except asyncio.CancelledError:
            pass

        # 关闭浏览器
        if state.browser_session:
            await state.browser_session.close()

        await app.updater.stop()
        await app.stop()
        print("[Undercurrent] 👋 已退出")


def main():
    parser = argparse.ArgumentParser(description="Undercurrent Subscription Agent")
    parser.add_argument("--once", action="store_true", help="单次运行模式")
    parser.add_argument("--interval", type=int, default=60, help="检查间隔（秒）")
    args = parser.parse_args()

    state = AgentState()

    if args.once:
        asyncio.run(run_once(state))
    else:
        asyncio.run(run_watch(state, args.interval))


if __name__ == "__main__":
    main()
