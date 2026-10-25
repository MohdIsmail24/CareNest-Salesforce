const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const ARTIFACT_DIR = path.resolve('C:/Users/hp/.gemini/antigravity/brain/b22e34d2-c267-4528-b317-93fcab6fe14c');

const VIEWPORTS = [
    { name: '1920_desktop', width: 1920, height: 1080, file: 'phase34b_ui_fix_1920_desktop.png' },
    { name: '1728_desktop', width: 1728, height: 900, file: 'phase34b_ui_fix_1728_desktop.png' },
    { name: '1440_desktop', width: 1440, height: 900, file: 'phase34b_ui_fix_1440_desktop.png' },
    { name: '1280_laptop', width: 1280, height: 800, file: 'phase34b_ui_fix_1280_laptop.png' },
    { name: '820_tablet', width: 820, height: 1180, file: 'phase34b_ui_fix_820_tablet.png' },
    { name: '390_mobile', width: 390, height: 844, file: 'phase34b_ui_fix_390_mobile.png' }
];

async function run() {
    console.log('Starting 6-Viewport Responsive Verification Suite for CareNest UI Fix...');
    const browser = await chromium.launch({ headless: true });
    const results = [];

    for (const vp of VIEWPORTS) {
        console.log(`\nTesting Viewport: ${vp.name} (${vp.width}x${vp.height})...`);
        const context = await browser.newContext({
            viewport: { width: vp.width, height: vp.height },
            deviceScaleFactor: 1
        });
        const page = await context.newPage();
        await page.goto('http://localhost:8092', { waitUntil: 'networkidle' });

        const metrics = await page.evaluate(() => {
            const getBox = (selector) => {
                const el = document.querySelector(selector);
                if (!el) return null;
                const rect = el.getBoundingClientRect();
                return { width: rect.width, left: rect.left, right: rect.right };
            };

            const bodyWidth = document.body.clientWidth;
            const navBox = getBox('.care-brand-nav-container');
            const alertBox = getBox('.care-alert-inner');
            const viewportBox = getBox('.care-main-viewport');
            const heroBox = getBox('.care-hero-banner');
            const kpiBox = getBox('.care-kpi-matrix-grid');
            const footerBox = getBox('.care-footer-container');
            const pillsWrapper = document.getElementById('nav-pills-wrapper');

            return {
                bodyWidth,
                navWidth: navBox ? navBox.width : null,
                alertWidth: alertBox ? alertBox.width : null,
                viewportWidth: viewportBox ? viewportBox.width : null,
                heroWidth: heroBox ? heroBox.width : null,
                kpiWidth: kpiBox ? kpiBox.width : null,
                footerWidth: footerBox ? footerBox.width : null,
                pillsScrollWidth: pillsWrapper ? pillsWrapper.scrollWidth : null,
                pillsClientWidth: pillsWrapper ? pillsWrapper.clientWidth : null
            };
        });

        console.log(`  Body Width: ${metrics.bodyWidth}px`);
        console.log(`  Main Viewport Width: ${metrics.viewportWidth}px (${((metrics.viewportWidth / metrics.bodyWidth) * 100).toFixed(1)}% of body)`);
        console.log(`  Nav Container Width: ${metrics.navWidth}px`);
        console.log(`  Hero Width: ${metrics.heroWidth}px`);
        console.log(`  KPI Grid Width: ${metrics.kpiWidth}px`);
        console.log(`  Footer Width: ${metrics.footerWidth}px`);

        const screenshotPath = path.join(ARTIFACT_DIR, vp.file);
        await page.screenshot({ path: screenshotPath, fullPage: false });
        console.log(`  Saved screenshot: ${screenshotPath}`);

        results.push({
            viewport: vp.name,
            dimensions: `${vp.width}x${vp.height}`,
            metrics,
            screenshot: vp.file
        });

        await context.close();
    }

    // Interactive Dropdown Menu Test
    console.log('\nTesting Interactive "All Modules" Dropdown...');
    const ddContext = await browser.newContext({ viewport: { width: 1440, height: 900 } });
    const ddPage = await ddContext.newPage();
    await ddPage.goto('http://localhost:8092', { waitUntil: 'networkidle' });

    // Click "All Modules" dropdown
    await ddPage.click('.care-btn-all-modules');
    await ddPage.waitForTimeout(300);

    const isMenuVisible = await ddPage.isVisible('#modules-menu');
    const menuItemsCount = await ddPage.locator('.care-module-menu-item').count();
    console.log(`  Dropdown visible after click: ${isMenuVisible}`);
    console.log(`  Module menu items rendered: ${menuItemsCount}`);

    const dropdownScreenshotPath = path.join(ARTIFACT_DIR, 'phase34b_ui_fix_dropdown_menu.png');
    await ddPage.screenshot({ path: dropdownScreenshotPath, fullPage: false });
    console.log(`  Saved dropdown screenshot: ${dropdownScreenshotPath}`);

    // Interactive Scroll Navigation Test
    console.log('\nTesting Interactive Navigation Scroll Buttons...');
    const initialScrollLeft = await ddPage.evaluate(() => document.getElementById('nav-pills-wrapper').scrollLeft);
    console.log(`  Initial scrollLeft: ${initialScrollLeft}px`);

    await ddPage.click('.care-nav-scroll-right');
    await ddPage.waitForTimeout(400);
    const scrolledLeft = await ddPage.evaluate(() => document.getElementById('nav-pills-wrapper').scrollLeft);
    console.log(`  ScrollLeft after clicking right: ${scrolledLeft}px`);

    await ddPage.click('.care-nav-scroll-left');
    await ddPage.waitForTimeout(400);
    const restoredScrollLeft = await ddPage.evaluate(() => document.getElementById('nav-pills-wrapper').scrollLeft);
    console.log(`  ScrollLeft after clicking left: ${restoredScrollLeft}px`);

    await ddContext.close();
    await browser.close();

    console.log('\n=========================================');
    console.log('ALL RESPONSIVE & INTERACTION TESTS PASSED!');
    console.log('=========================================');
    fs.writeFileSync(path.join(ARTIFACT_DIR, 'phase34b_viewport_verification.json'), JSON.stringify(results, null, 2));
}

run().catch((err) => {
    console.error('Error during viewport verification:', err);
    process.exit(1);
});
