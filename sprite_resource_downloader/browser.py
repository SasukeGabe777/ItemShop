from __future__ import annotations

from contextlib import contextmanager
from typing import Iterator

from playwright.sync_api import Browser, BrowserContext, Page, sync_playwright


@contextmanager
def chromium_page(*, headed: bool) -> Iterator[tuple[Browser, BrowserContext, Page]]:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=not headed)
        context = browser.new_context(accept_downloads=True)
        page = context.new_page()
        try:
            yield browser, context, page
        finally:
            context.close()
            browser.close()
