import asyncio, os, random, time
from playwright.async_api import async_playwright

POSTED_FILE = "data/posted.txt"
MAX_POSTS = int(os.getenv("MAX_POSTS_PER_RUN", 1))

async def main():
    posted = set()
    if os.path.exists(POSTED_FILE):
        posted = set(open(POSTED_FILE).read().splitlines())

    videos = [v for v in os.listdir("data/processed") if v not in posted][:MAX_POSTS]

    if not videos: return

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False,args=["--disable-blink-features=AutomationControlled","--no-sandbox"])
        context = await browser.new_context(storage_state="cookies.json")
        page = await context.new_page()

        for video in videos:
            await page.goto("https://www.tiktok.com/upload", timeout=60000)
            await page.wait_for_selector("input[type=file]")
            await page.set_input_files("input[type=file]", f"data/processed/{video}")
            await page.wait_for_timeout(random.randint(15000,25000))
            await page.keyboard.type(f"🔥 {video} #twitchclips #gaming #fyp")
            await page.wait_for_timeout(random.randint(5000,10000))
            await page.click("text=Post")
            time.sleep(random.randint(30,60))
            with open(POSTED_FILE,"a") as f:
                f.write(video+"\n")
        await browser.close()

asyncio.run(main())
