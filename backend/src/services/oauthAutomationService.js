function parseAuthorizationCode(raw) {
  if (!raw) {
    return null;
  }

  try {
    const url = new URL(raw);
    return url.searchParams.get('code');
  } catch (_error) {
    const queryIndex = raw.indexOf('?');
    if (queryIndex === -1) {
      return null;
    }
    const params = new URLSearchParams(raw.slice(queryIndex + 1));
    return params.get('code');
  }
}

function getSelectorConfig() {
  return {
    emailXPath:
      process.env.PSA_AUTOAUTH_EMAIL_XPATH ||
      '/html/body/div[2]/div/div[2]/div/form/div[2]/div[1]/div[2]/input',
    passwordXPath:
      process.env.PSA_AUTOAUTH_PASSWORD_XPATH ||
      '/html/body/div[2]/div/div[2]/div/form/div[2]/div[1]/div[3]/input',
    submitXPath:
      process.env.PSA_AUTOAUTH_SUBMIT_XPATH ||
      '/html/body/div[2]/div/div[2]/div/form/div[2]/div[2]/div[2]/input',
  };
}

async function typeIntoXPath(page, xpath, value) {
  const handle = await page.waitForSelector(`xpath/${xpath}`, {
    timeout: 15000,
  });
  if (!handle) {
    throw new Error(`Auto-auth selector not found: ${xpath}`);
  }
  await handle.click({ clickCount: 3 });
  await handle.type(value, { delay: 20 });
}

async function clickXPath(page, xpath) {
  const handle = await page.waitForSelector(`xpath/${xpath}`, {
    timeout: 15000,
  });
  if (!handle) {
    throw new Error(`Auto-auth submit selector not found: ${xpath}`);
  }
  await handle.click();
}

async function automateAuthorization({ redirectUrl, email, password }) {
  let puppeteer;
  try {
    puppeteer = require('puppeteer-core');
  } catch (_error) {
    throw new Error(
      'Automatic browser login is not available on this backend. Install puppeteer-core or use manual code paste.',
    );
  }

  if (!redirectUrl || !email || !password) {
    throw new Error('redirectUrl, email and password are required for automatic login.');
  }

  const timeoutMs = Number(process.env.PSA_AUTOAUTH_TIMEOUT_MS || 90000);
  const selectorConfig = getSelectorConfig();

  const launchOptions = {
    headless: process.env.PSA_AUTOAUTH_HEADLESS !== 'false',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
    ],
  };
  const executablePath =
    process.env.PSA_AUTOAUTH_EXECUTABLE_PATH || process.env.PUPPETEER_EXECUTABLE_PATH;
  if (executablePath) {
    launchOptions.executablePath = executablePath;
  }

  const browser = await puppeteer.launch(launchOptions);
  try {
    const page = await browser.newPage();
    page.setDefaultTimeout(timeoutMs);

    await page.goto(redirectUrl, { waitUntil: 'domcontentloaded', timeout: timeoutMs });
    await typeIntoXPath(page, selectorConfig.emailXPath, email);
    await typeIntoXPath(page, selectorConfig.passwordXPath, password);
    await clickXPath(page, selectorConfig.submitXPath);

    await page.waitForFunction(
      () => window.location.href.includes('code='),
      { timeout: timeoutMs },
    );

    const finalUrl = page.url();
    const code = parseAuthorizationCode(finalUrl);
    if (!code) {
      throw new Error('Automatic login completed but no authorization code was found.');
    }

    return {
      code,
      finalUrl,
    };
  } finally {
    await browser.close();
  }
}

module.exports = {
  automateAuthorization,
};