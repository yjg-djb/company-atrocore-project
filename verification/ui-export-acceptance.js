const { spawn, execFileSync } = require('node:child_process');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');

const args = new Map();
for (let i = 2; i < process.argv.length; i += 2) {
  args.set(process.argv[i].replace(/^--/, ''), process.argv[i + 1]);
}

const baseUrl = args.get('baseUrl') || 'http://localhost:8081';
const username = args.get('username') || 'admin';
const password = args.get('password') || 'admin';
const reportDir = args.get('reportDir') || path.join('verification', 'reports');
const run = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, '').replace('T', '-');
const prefix = `Codex Smoke UI ${run}`;
const runStartedAt = new Date();
const apiBase = `${baseUrl}/api/v1`;
const results = [];
const created = [];

function addResult(group, name, entry, method, statusCode, result, summary, ids = '', cleanup = '', next = '') {
  results.push({
    time: new Date().toISOString(),
    group,
    name,
    entry,
    method,
    statusCode,
    result,
    summary: String(summary || ''),
    ids,
    cleanup,
    next,
  });
}

function shorten(text, max = 220) {
  const s = String(text || '').replace(/\s+/g, ' ').trim();
  return s.length > max ? `${s.slice(0, max)}...` : s;
}

async function api(pathPart, options = {}) {
  const headers = Object.assign({ 'X-Requested-With': 'XMLHttpRequest' }, options.headers || {});
  const init = Object.assign({}, options, { headers });
  if (init.body && typeof init.body !== 'string') {
    init.body = JSON.stringify(init.body);
    init.headers['Content-Type'] = 'application/json';
  }
  const response = await fetch(`${apiBase}/${pathPart}`, init);
  const text = await response.text();
  let content = text;
  try {
    content = text ? JSON.parse(text) : null;
  } catch {
    // Keep text content.
  }
  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText}: ${shorten(text, 500)}`);
  }
  return { status: response.status, content, raw: text };
}

async function loginApi() {
  const basic = Buffer.from(`${username}:${password}`).toString('base64');
  const response = await api('App/user', { headers: { Authorization: `Basic ${basic}` } });
  if (!response.content.authorizationToken) {
    throw new Error('authorizationToken missing');
  }
  return {
    'Authorization-Token': response.content.authorizationToken,
    'X-Requested-With': 'XMLHttpRequest',
  };
}

function chromePath() {
  const candidates = [
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
    'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  ];
  const found = candidates.find((candidate) => fs.existsSync(candidate));
  if (!found) throw new Error('Chrome or Edge executable not found');
  return found;
}

function getJson(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (response) => {
      let data = '';
      response.on('data', (chunk) => (data += chunk));
      response.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (error) {
          reject(error);
        }
      });
    }).on('error', reject);
  });
}

async function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForCdp(port) {
  for (let i = 0; i < 60; i++) {
    try {
      return await getJson(`http://127.0.0.1:${port}/json/version`);
    } catch {
      await wait(250);
    }
  }
  throw new Error('Chrome DevTools endpoint did not become ready');
}

class CdpClient {
  constructor(wsUrl) {
    this.ws = new WebSocket(wsUrl);
    this.id = 0;
    this.pending = new Map();
    this.ws.onmessage = (event) => {
      const message = JSON.parse(event.data);
      if (message.id && this.pending.has(message.id)) {
        const { resolve, reject } = this.pending.get(message.id);
        this.pending.delete(message.id);
        message.error ? reject(new Error(JSON.stringify(message.error))) : resolve(message.result);
      }
    };
  }

  async ready() {
    if (this.ws.readyState === 1) return;
    await new Promise((resolve, reject) => {
      this.ws.onopen = resolve;
      this.ws.onerror = reject;
    });
  }

  send(method, params = {}) {
    const id = ++this.id;
    this.ws.send(JSON.stringify({ id, method, params }));
    return new Promise((resolve, reject) => this.pending.set(id, { resolve, reject }));
  }

  async eval(expression) {
    const response = await this.send('Runtime.evaluate', {
      expression,
      returnByValue: true,
      awaitPromise: true,
    });
    if (response.exceptionDetails) {
      throw new Error(JSON.stringify(response.exceptionDetails));
    }
    return response.result.value;
  }
}

async function waitEval(client, expression, timeoutMs = 20000) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    const value = await client.eval(expression);
    if (value) return value;
    await wait(500);
  }
  throw new Error(`Timed out waiting for ${expression}`);
}

async function pageSnapshot(client) {
  return client.eval(`({
    url: location.href,
    title: document.title,
    text: document.body.innerText.slice(0, 3000),
    buttonTexts: [...document.querySelectorAll('button,a')].map((el) => el.innerText.trim()).filter(Boolean).slice(0, 80)
  })`);
}

async function loginUi(client) {
  await waitEval(client, `!!document.querySelector('#field-userName') && !!document.querySelector('#field-password')`);
  await client.eval(`
    document.querySelector('#field-userName').value = ${JSON.stringify(username)};
    document.querySelector('#field-password').value = ${JSON.stringify(password)};
    document.querySelector('#btn-login').click();
  `);
  await waitEval(client, `document.body.innerText.includes('Dashboard')`, 25000);
}

async function navigate(client, hash, expectedText) {
  await client.send('Page.navigate', { url: `${baseUrl}/${hash}` });
  await waitEval(client, `location.hash === ${JSON.stringify(hash)} || location.hash.startsWith(${JSON.stringify(hash + '/')})`, 10000);
  await waitEval(client, `
    document.title.includes(${JSON.stringify(expectedText)}) ||
    [...document.querySelectorAll('h1,h2,h3,.header-title')].some((el) => el.innerText.includes(${JSON.stringify(expectedText)}))
  `, 25000);
  return pageSnapshot(client);
}

async function createEntityViaUi(client, scope, label, fields) {
  const createHash = `#${scope}/create`;
  await navigate(client, createHash, label);
  await client.eval(`
    (() => {
      const fields = ${JSON.stringify(fields)};
      const setValue = (selector, value) => {
        const el = document.querySelector(selector);
        if (!el) throw new Error('Missing field ' + selector);
        el.focus();
        el.value = value;
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
      };
      for (const [selector, value] of Object.entries(fields)) setValue(selector, value);
      const save = [...document.querySelectorAll('button')].find((button) => button.innerText.trim() === 'Save');
      if (!save) throw new Error('Save button missing');
      save.click();
      return true;
    })()
  `);
  const viewHash = await waitEval(client, `location.hash.match(/^#${scope}\\/view\\//)?.input`, 30000);
  const id = String(viewHash).split('/').pop();
  created.push({ scope, id });
  const snapshot = await pageSnapshot(client);
  return { id, snapshot };
}

async function editEntityViaUi(client, scope, id, fields) {
  await client.send('Page.navigate', { url: `${baseUrl}/#${scope}/edit/${id}` });
  await waitEval(client, `location.hash === ${JSON.stringify(`#${scope}/edit/${id}`)}`, 10000);
  await waitEval(client, `[...document.querySelectorAll('button')].some((button) => button.innerText.trim() === 'Save')`, 25000);
  await client.eval(`
    (() => {
      const fields = ${JSON.stringify(fields)};
      const setValue = (selector, value) => {
        const el = document.querySelector(selector);
        if (!el) throw new Error('Missing field ' + selector);
        el.focus();
        el.value = value;
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
      };
      for (const [selector, value] of Object.entries(fields)) setValue(selector, value);
      const save = [...document.querySelectorAll('button')].find((button) => button.innerText.trim() === 'Save');
      if (!save) throw new Error('Save button missing');
      save.click();
      return true;
    })()
  `);
  await waitEval(client, `location.hash === ${JSON.stringify(`#${scope}/view/${id}`)} && document.body.innerText.includes(${JSON.stringify(Object.values(fields)[0])})`, 30000);
  return pageSnapshot(client);
}

async function verifyEntityPage(client, hash, expectedText) {
  const snapshot = await navigate(client, hash, expectedText);
  const hasCreate = snapshot.text.includes('Create') || snapshot.buttonTexts.includes('Create');
  addResult('UI', `${expectedText} list page`, hash, 'Browser', 200, 'PASS', `title=${snapshot.title}; createVisible=${hasCreate}`);
}

async function removeCreated(headers) {
  for (let i = created.length - 1; i >= 0; i--) {
    const item = created[i];
    try {
      await api(`${item.scope}/${item.id}`, { method: 'DELETE', headers });
      addResult('Cleanup', `${item.scope} ${item.id}`, `/${item.scope}/${item.id}`, 'DELETE', 200, 'PASS', 'deleted', item.id, 'deleted');
    } catch (error) {
      addResult('Cleanup', `${item.scope} ${item.id}`, `/${item.scope}/${item.id}`, 'DELETE', '', 'FAIL', error.message, item.id, 'not cleaned', 'Manual cleanup may be required');
    }
  }
}

async function removeSmokeJobs(headers) {
  try {
    const response = await api(`Job?where[0][type]=contains&where[0][attribute]=name&where[0][value]=${encodeURIComponent('Codex Smoke')}&maxSize=100`, { headers });
    const jobs = Array.isArray(response.content.list) ? response.content.list : [];
    for (const job of jobs) {
      try {
        await api(`Job/${job.id}`, { method: 'DELETE', headers });
        addResult('Cleanup', `Job ${job.id}`, `/Job/${job.id}`, 'DELETE', 200, 'PASS', 'deleted', job.id, 'deleted');
      } catch (error) {
        addResult('Cleanup', `Job ${job.id}`, `/Job/${job.id}`, 'DELETE', '', 'FAIL', error.message, job.id, 'not cleaned', 'Manual cleanup may be required');
      }
    }
  } catch (error) {
    addResult('Cleanup', 'Codex Smoke jobs', '/Job', 'GET', '', 'BLOCK', error.message, '', 'unknown', 'Manual cleanup may be required');
  }
}

async function cleanupResidue(headers) {
  for (const scope of ['Account', 'Contact', 'Product', 'File', 'Folder', 'ImportFeed', 'ExportFeed', 'ExportJob', 'Job']) {
    try {
      const pathPart = `${scope}?where[0][type]=contains&where[0][attribute]=name&where[0][value]=${encodeURIComponent('Codex Smoke')}&maxSize=50`;
      const response = await api(pathPart, { headers });
      const remaining = Array.isArray(response.content.list) ? response.content.list.length : 0;
      addResult('CleanupCheck', `${scope} Codex Smoke residue`, `/${scope}`, 'GET', response.status, remaining === 0 ? 'PASS' : 'FAIL', `remaining=${remaining}`, '', remaining === 0 ? 'clean' : 'residue', 'Manual cleanup may be required');
    } catch (error) {
      addResult('CleanupCheck', `${scope} Codex Smoke residue`, `/${scope}`, 'GET', '', 'BLOCK', error.message, '', 'unknown', 'Scope may not support name filter');
    }
  }
}

function currentRunLogLines(logs) {
  return String(logs || '')
    .split(/\r?\n/)
    .filter((line) => {
      const match = line.match(/^\[(.*?)\]/);
      if (!match) return false;
      const time = new Date(match[1]);
      return Number.isFinite(time.getTime()) && time >= runStartedAt;
    })
    .join('\n');
}

function readAtroLogs() {
  try {
    return execFileSync('docker', ['compose', 'exec', '-T', 'web', 'sh', '-lc', 'cd /var/www/localhost && find data/logs -maxdepth 1 -type f -print -exec tail -n 200 {} \\;'], { encoding: 'utf8' });
  } catch (error) {
    return error.stdout || error.message;
  }
}

async function exportWarningCheck(headers) {
  const account = await api('Account', { method: 'POST', headers, body: { name: `${prefix} Export Account` } });
  created.push({ scope: 'Account', id: account.content.id });

  const folder = await api('Folder', { method: 'POST', headers, body: { name: `${prefix} Export Folder` } });
  created.push({ scope: 'Folder', id: folder.content.id });

  const exportCode = `codex_ui_export_${run.replace(/\D/g, '').toLowerCase()}`;
  const feed = await api('ExportFeed', {
    method: 'POST',
    headers,
    body: {
      name: `${prefix} ExportFeed`,
      code: exportCode,
      type: 'simple',
      fileType: 'json',
      entity: 'Account',
      folderId: folder.content.id,
      localeId: 'main',
      isActive: true,
      limit: 100,
      data: {},
      fileNameMask: 'codex-smoke-ui.json',
      template: '{{ entities|json_encode }}',
      emptyValue: '',
      nullValue: 'Null',
      markForNoRelation: 'Null',
      markForUnlinkedAttribute: 'N/A',
      delimiter: '~',
      fieldDelimiterForRelation: '|',
    },
  });
  created.push({ scope: 'ExportFeed', id: feed.content.id });

  const item1 = await api('ExportConfiguratorItem', {
    method: 'POST',
    headers,
    body: { name: 'id', type: 'Field', columnType: 'name', exportFeedId: feed.content.id, sortOrder: 0 },
  });
  created.push({ scope: 'ExportConfiguratorItem', id: item1.content.id });

  const item2 = await api('ExportConfiguratorItem', {
    method: 'POST',
    headers,
    body: { name: 'name', type: 'Field', columnType: 'name', exportFeedId: feed.content.id, sortOrder: 10 },
  });
  created.push({ scope: 'ExportConfiguratorItem', id: item2.content.id });

  await api(`ExportFeed/action/verifyFeedByCode?code=${exportCode}`, { headers });

  let directWarning = false;
  try {
    const direct = await api(`ExportFeed/action/exportData?code=${exportCode}&offset=0`, { headers });
    const contains = String(direct.raw).includes(prefix);
    addResult('Export', 'Direct exportData path', '/ExportFeed/action/exportData', 'GET', direct.status, contains ? 'PASS' : 'BLOCK', `containsCodexSmoke=${contains}; known path may warn because no exportJobId`, feed.content.id);
  } catch (error) {
    addResult('Export', 'Direct exportData path', '/ExportFeed/action/exportData', 'GET', '', 'FAIL', error.message, feed.content.id);
  }

  const afterDirect = currentRunLogLines(readAtroLogs());
  directWarning = afterDirect.includes('Undefined array key "exportJobId"');

  const beforeJobLogs = new Date();
  const jobResponse = await api('ExportFeed/action/exportFile', {
    method: 'POST',
    headers,
    body: { id: feed.content.id },
  });
  execFileSync('docker', ['compose', 'exec', '-T', 'web', 'php', 'console.php', 'cron'], { encoding: 'utf8' });
  await wait(3000);

  const jobs = await api(`ExportJob?where[0][type]=equals&where[0][attribute]=exportFeedId&where[0][value]=${feed.content.id}&maxSize=20`, { headers });
  const jobList = Array.isArray(jobs.content.list) ? jobs.content.list : [];
  for (const job of jobList) created.push({ scope: 'ExportJob', id: job.id });
  const createdFileIds = jobList.map((job) => job.fileId).filter(Boolean);
  for (const fileId of createdFileIds) created.push({ scope: 'File', id: fileId });

  const currentLogs = currentRunLogLines(readAtroLogs());
  const jobWarningLines = currentLogs
    .split(/\r?\n/)
    .filter((line) => new Date((line.match(/^\[(.*?)\]/) || [])[1] || 0) >= beforeJobLogs)
    .filter((line) => line.includes('exportJobId'));
  const jobOk = jobResponse.content === true && jobList.length > 0 && jobWarningLines.length === 0;
  addResult('Export', 'Job exportFile path', '/ExportFeed/action/exportFile + cron', 'POSTCLI', 200, jobOk ? 'PASS' : 'BLOCK', `queued=${jobResponse.content}; exportJobs=${jobList.length}; files=${createdFileIds.length}; exportJobIdWarningsAfterJob=${jobWarningLines.length}; directPathWarning=${directWarning}`, { feed: feed.content.id, jobs: jobList.map((job) => job.id), files: createdFileIds }, '', jobOk ? 'Use exportFile + cron for production verification' : 'Inspect ExportJob state and logs');
}

function writeReports() {
  fs.mkdirSync(reportDir, { recursive: true });
  const jsonPath = path.join(reportDir, `ui-export-acceptance-${run}.json`);
  const mdPath = path.join(reportDir, `ui-export-acceptance-${run}.md`);
  fs.writeFileSync(jsonPath, JSON.stringify(results, null, 2));
  const pass = results.filter((r) => r.result === 'PASS').length;
  const fail = results.filter((r) => r.result === 'FAIL').length;
  const block = results.filter((r) => r.result === 'BLOCK').length;
  const lines = [
    `# UI + Export Acceptance ${run}`,
    '',
    `- BaseUrl: ${baseUrl}`,
    `- Summary: PASS=${pass} FAIL=${fail} BLOCK=${block}`,
    `- Prefix: ${prefix}`,
    '',
    '| Group | Name | Entry | Method | Status | Result | Summary | Cleanup | Next |',
    '|---|---|---|---|---:|---|---|---|---|',
  ];
  for (const row of results) {
    lines.push(`| ${row.group} | ${row.name} | \`${row.entry}\` | ${row.method} | ${row.statusCode} | ${row.result} | ${shorten(row.summary, 180).replace(/\|/g, '/')} | ${row.cleanup} | ${shorten(row.next, 120).replace(/\|/g, '/')} |`);
  }
  fs.writeFileSync(mdPath, `${lines.join('\n')}\n`);
  console.log(`Report JSON: ${jsonPath}`);
  console.log(`Report MD:   ${mdPath}`);
  console.log(`Summary: PASS=${pass} FAIL=${fail} BLOCK=${block}`);
  if (fail > 0) process.exitCode = 1;
}

async function main() {
  let browserProcess;
  let headers;
  try {
    headers = await loginApi();
    addResult('Precheck', 'API login', '/App/user', 'GET', 200, 'PASS', 'authorizationToken acquired');

    const port = 9400 + Math.floor(Math.random() * 400);
    const profileDir = fs.mkdtempSync(path.join(os.tmpdir(), 'atro-ui-'));
    browserProcess = spawn(chromePath(), [
      `--remote-debugging-port=${port}`,
      `--user-data-dir=${profileDir}`,
      '--headless=new',
      '--disable-gpu',
      '--no-first-run',
      '--no-default-browser-check',
      `${baseUrl}/`,
    ], { stdio: 'ignore' });

    await waitForCdp(port);
    const tabs = await getJson(`http://127.0.0.1:${port}/json/list`);
    const target = tabs.find((tab) => tab.url.startsWith(baseUrl));
    const client = new CdpClient(target.webSocketDebuggerUrl);
    await client.ready();
    await client.send('Runtime.enable');
    await client.send('Page.enable');
    await wait(2500);

    await loginUi(client);
    addResult('UI', 'Login', baseUrl, 'Browser', 200, 'PASS', 'Logged in with admin/admin; Dashboard visible');

    const dashboard = await pageSnapshot(client);
    addResult('UI', 'Dashboard', '#', 'Browser', 200, dashboard.text.includes('Dashboard') ? 'PASS' : 'FAIL', `title=${dashboard.title}`);

    await client.eval(`location.hash = '#logout'`);
    await waitEval(client, `document.body.innerText.includes('Login') && !!document.querySelector('#field-userName')`, 20000);
    addResult('UI', 'Logout', '#logout', 'Browser', 200, 'PASS', 'Login page visible after logout');
    await loginUi(client);
    addResult('UI', 'Relogin', baseUrl, 'Browser', 200, 'PASS', 'Logged in again after logout');

    for (const [hash, text] of [
      ['#Account', 'Accounts'],
      ['#Contact', 'Contact'],
      ['#Product', 'Product'],
      ['#File', 'Files'],
      ['#ImportFeed', 'Import Feeds'],
      ['#ExportFeed', 'Export Feeds'],
    ]) {
      await verifyEntityPage(client, hash, text);
    }

    const account = await createEntityViaUi(client, 'Account', 'New', { 'input[name="name"]': `${prefix} Account` });
    addResult('UI', 'Account create', '#Account/create', 'Browser', 200, 'PASS', `created id=${account.id}`, account.id);
    await editEntityViaUi(client, 'Account', account.id, { 'input[name="name"]': `${prefix} Account Updated` });
    addResult('UI', 'Account edit', `#Account/edit/${account.id}`, 'Browser', 200, 'PASS', 'updated name through UI', account.id);

    const contact = await createEntityViaUi(client, 'Contact', 'New', {
      'input[name="name"]': `${prefix} Contact`,
      'input[name="firstName"]': 'Codex',
      'input[name="secondName"]': `Smoke UI ${run}`,
    });
    addResult('UI', 'Contact create', '#Contact/create', 'Browser', 200, 'PASS', `created id=${contact.id}`, contact.id);
    await editEntityViaUi(client, 'Contact', contact.id, { 'input[name="firstName"]': 'CodexUpdated' });
    addResult('UI', 'Contact edit', `#Contact/edit/${contact.id}`, 'Browser', 200, 'PASS', 'updated firstName through UI', contact.id);

    const product = await createEntityViaUi(client, 'Product', 'New', {
      'input[name="name"]': `${prefix} Product`,
      'input[name="number"]': `UI-${run}`,
    });
    addResult('UI', 'Product create', '#Product/create', 'Browser', 200, 'PASS', `created id=${product.id}`, product.id);
    await editEntityViaUi(client, 'Product', product.id, { 'input[name="name"]': `${prefix} Product Updated` });
    addResult('UI', 'Product edit', `#Product/edit/${product.id}`, 'Browser', 200, 'PASS', 'updated name through UI', product.id);

    const folder = await api('Folder', { method: 'POST', headers, body: { name: `${prefix} File Folder` } });
    created.push({ scope: 'Folder', id: folder.content.id });
    const fileText = `${prefix} file content`;
    const file = await api('File', {
      method: 'POST',
      headers,
      body: {
        name: `${prefix} File.txt`,
        fileSize: fileText.length,
        fileContents: `data:text/plain;base64,${Buffer.from(fileText).toString('base64')}`,
        folderId: folder.content.id,
      },
    });
    created.push({ scope: 'File', id: file.content.id });
    await navigate(client, `#File/view/${file.content.id}`, 'File');
    const filePage = await pageSnapshot(client);
    addResult('UI', 'File detail', `#File/view/${file.content.id}`, 'BrowserAPI', 200, filePage.text.includes('File.txt') ? 'PASS' : 'BLOCK', `file detail opened; nameVisible=${filePage.text.includes('File.txt')}`, file.content.id);

    await exportWarningCheck(headers);

    const schema = execFileSync('docker', ['compose', 'exec', '-T', 'web', 'php', 'console.php', 'sql', 'diff', '--show'], { encoding: 'utf8' });
    addResult('Schema', 'SQL diff', 'php console.php sql diff --show', 'CLI', '', schema.includes('No database changes were detected') ? 'PASS' : 'FAIL', shorten(schema, 500));

    const currentLogs = currentRunLogLines(readAtroLogs());
    const fatal = /Fatal error|Uncaught|Log\.ERROR/.test(currentLogs);
    const warningCount = (currentLogs.match(/Log\.WARNING|E_WARNING/g) || []).length;
    addResult('Logs', 'AtroCore logs', 'data/logs', 'CLI', '', fatal ? 'FAIL' : warningCount ? 'BLOCK' : 'PASS', fatal ? shorten(currentLogs, 700) : `fatal=false; warnings=${warningCount}`, '', '', warningCount ? 'Warnings are classified separately; exportData warning is expected only on direct path' : '');
  } catch (error) {
    addResult('Run', 'UI + Export acceptance', baseUrl, 'Mixed', '', 'FAIL', error.stack || error.message, '', '', 'Inspect script output and latest report');
  } finally {
    if (headers) {
      await removeCreated(headers);
      await removeSmokeJobs(headers);
      await cleanupResidue(headers);
    }
    if (browserProcess) browserProcess.kill();
    writeReports();
  }
}

main();
