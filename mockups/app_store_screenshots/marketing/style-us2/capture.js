const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

// App Store 6.7" iPhone dimensions
const WIDTH = 1284;
const HEIGHT = 2778;

const OUTPUT_DIR = path.join(__dirname, 'output');
const TEMPLATE_PATH = path.join(__dirname, 'template.html');

const frames = [
  { id: 'frame-1', name: '01-home-final' },
  { id: 'frame-2', name: '02-quiz-final' },
  { id: 'frame-3', name: '03-insights-final' },
  { id: 'frame-4', name: '04-word-search-final' },
  { id: 'frame-5', name: '05-alignment-final' },
  { id: 'frame-6', name: '06-steps-final' },
  { id: 'frame-7', name: '07-collection-final' },
  { id: 'frame-8', name: '08-cta-final' },
  { id: 'frame-9', name: '09-crossword-final' },
];

async function generateScreenshots() {
  console.log('Starting App Store screenshot generation...');
  console.log(`Output dimensions: ${WIDTH}x${HEIGHT}px`);

  // Ensure output directory exists
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  const browser = await puppeteer.launch({
    headless: true,
    executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();

  // Set viewport to exact App Store dimensions
  await page.setViewport({
    width: WIDTH,
    height: HEIGHT,
    deviceScaleFactor: 1
  });

  // Navigate to template
  console.log(`Loading template: ${TEMPLATE_PATH}`);
  await page.goto(`file://${TEMPLATE_PATH}`, { waitUntil: 'networkidle0' });

  // Wait for fonts to load
  await page.evaluateHandle('document.fonts.ready');
  await new Promise(r => setTimeout(r, 1000));

  // Capture each frame
  for (const frame of frames) {
    console.log(`Capturing ${frame.name}...`);

    // Get the element
    const element = await page.$(`#${frame.id}`);

    if (!element) {
      console.log(`Warning: Element #${frame.id} not found, skipping`);
      continue;
    }

    // Scroll to element
    await page.evaluate((id) => {
      const el = document.getElementById(id);
      if (el) el.scrollIntoView();
    }, frame.id);

    await new Promise(r => setTimeout(r, 200));

    // Capture screenshot
    const outputPath = path.join(OUTPUT_DIR, `${frame.name}.png`);
    await element.screenshot({
      path: outputPath,
      type: 'png'
    });

    console.log(`Saved: ${outputPath}`);

    // Verify dimensions
    const stats = fs.statSync(outputPath);
    console.log(`  File size: ${(stats.size / 1024).toFixed(1)} KB`);
  }

  await browser.close();

  console.log('\n=================================');
  console.log('App Store screenshots generated!');
  console.log(`Output folder: ${OUTPUT_DIR}`);
  console.log('=================================');

  // List generated files
  const files = fs.readdirSync(OUTPUT_DIR).filter(f => f.endsWith('.png'));
  console.log(`\nGenerated ${files.length} screenshots:`);
  files.forEach(f => console.log(`  - ${f}`));
}

generateScreenshots().catch(console.error);
