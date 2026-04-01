"""持久化浏览器会话，支持多步操作"""

from playwright.async_api import async_playwright


class BrowserSession:
    def __init__(self):
        self.playwright = None
        self.browser = None
        self.page = None
        self.screenshot_counter = 0

    async def ensure_browser(self):
        if not self.browser:
            self.playwright = await async_playwright().start()
            self.browser = await self.playwright.chromium.launch(headless=False)
            self.page = await self.browser.new_page()
            await self.page.set_viewport_size({"width": 1280, "height": 900})

    async def goto(self, url: str) -> dict:
        await self.ensure_browser()
        await self.page.goto(url, wait_until="networkidle", timeout=30000)
        screenshot_path = await self.screenshot()
        return {
            "title": await self.page.title(),
            "url": self.page.url,
            "screenshot_path": screenshot_path,
        }

    async def screenshot(self) -> str:
        self.screenshot_counter += 1
        path = f"/tmp/uc_screenshot_{self.screenshot_counter}.png"
        await self.page.screenshot(path=path, full_page=True)
        return path

    async def click(self, selector: str) -> dict:
        try:
            await self.page.click(selector, timeout=10000)
            await self.page.wait_for_load_state("networkidle", timeout=15000)
            screenshot_path = await self.screenshot()
            return {"success": True, "screenshot_path": screenshot_path}
        except Exception as e:
            screenshot_path = await self.screenshot()
            return {"success": False, "error": str(e), "screenshot_path": screenshot_path}

    async def fill(self, selector: str, value: str) -> dict:
        try:
            await self.page.fill(selector, value)
            return {"success": True}
        except Exception as e:
            return {"success": False, "error": str(e)}

    async def get_page_text(self) -> str:
        """获取页面可见文本，帮助 Agent 理解页面内容"""
        if not self.page:
            return ""
        return await self.page.inner_text("body")

    async def close(self):
        if self.browser:
            await self.browser.close()
            self.browser = None
            self.page = None
        if self.playwright:
            await self.playwright.stop()
            self.playwright = None
