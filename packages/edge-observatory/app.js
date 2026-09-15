'use strict';

const clock = document.getElementById('clock');
const date = document.getElementById('date');
const timezone = document.getElementById('timezone');
const timeFormat = new Intl.DateTimeFormat(undefined, {hour: '2-digit', minute: '2-digit', hourCycle: 'h23'});
const dateFormat = new Intl.DateTimeFormat(undefined, {weekday: 'long', month: 'long', day: 'numeric'});
function updateClock() {
  const now = new Date();
  clock.textContent = timeFormat.format(now);
  clock.dateTime = now.toISOString();
  date.textContent = dateFormat.format(now);
  timezone.textContent = Intl.DateTimeFormat().resolvedOptions().timeZone.replaceAll('_', ' ');
}
updateClock();
setInterval(updateClock, 1000);

const themes = {
  observatory: 'Observatory',
  'piggy-pink': 'Piggy Pink',
  'sea-glass': 'Sea Glass',
  ember: 'Ember',
  paper: 'Paper',
};
const themePicker = document.querySelector('.theme-picker');
function applyTheme(theme) {
  document.documentElement.dataset.theme = theme;
  for (const button of themePicker.children) {
    const selected = button.dataset.theme === theme;
    button.setAttribute('aria-pressed', String(selected));
    button.title = `${themes[button.dataset.theme]}${selected ? ' (selected)' : ''}`;
  }
  try { localStorage.setItem('edge-observatory-theme', theme); } catch { /* The theme still works without storage. */ }
}
for (const [theme, name] of Object.entries(themes)) {
  const button = element('button', `theme-dot ${theme}`, '');
  button.type = 'button';
  button.dataset.theme = theme;
  button.setAttribute('aria-label', name);
  button.addEventListener('click', () => applyTheme(theme));
  themePicker.append(button);
}
try {
  const savedTheme = localStorage.getItem('edge-observatory-theme');
  applyTheme(Object.hasOwn(themes, savedTheme) ? savedTheme : 'observatory');
} catch { applyTheme('observatory'); }

const displayDialog = document.querySelector('.display-dialog');
const displayConfig = document.querySelector('.display-config');
displayConfig.addEventListener('click', () => displayDialog.showModal());
displayDialog.addEventListener('click', event => {
  const bounds = displayDialog.getBoundingClientRect();
  if (event.target === displayDialog && (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom)) displayDialog.close();
});

const weatherCurrent = document.querySelector('.weather-current');
const weatherForecast = document.querySelector('.weather-forecast');
function weatherDescription(code) {
  if (code === 0) return 'Clear';
  if ([1, 2, 3].includes(code)) return 'Cloudy';
  if ([45, 48].includes(code)) return 'Fog';
  if ([51, 53, 55, 56, 57].includes(code)) return 'Drizzle';
  if ([61, 63, 65, 66, 67, 80, 81, 82].includes(code)) return 'Rain';
  if ([71, 73, 75, 77, 85, 86].includes(code)) return 'Snow';
  if ([95, 96, 99].includes(code)) return 'Thunder';
  return 'Weather';
}
function weatherIcon(code) {
  if (code === 0) return '☀';
  if ([1, 2].includes(code)) return '⛅';
  if (code === 3) return '☁';
  if ([45, 48].includes(code)) return '≋';
  if ([51, 53, 55, 56, 57].includes(code)) return '☂';
  if ([61, 63, 65, 66, 67, 80, 81, 82].includes(code)) return '☔';
  if ([71, 73, 75, 77, 85, 86].includes(code)) return '❄';
  if ([95, 96, 99].includes(code)) return 'ϟ';
  return '·';
}
function renderWeather(data) {
  if (data.status !== 'connected') { weatherCurrent.textContent = data.message; weatherForecast.replaceChildren(); return; }
  weatherCurrent.textContent = `${Math.round(data.temperature)}° / ${weatherDescription(data.weatherCode)}`;
  weatherForecast.replaceChildren();
  for (const [index, day] of data.days.entries()) {
    const card = element('div', 'weather-day', '');
    const label = index === 0 ? 'TODAY' : index === 1 ? 'TOMORROW' : new Intl.DateTimeFormat(undefined, {weekday: 'short'}).format(new Date(`${day.date}T12:00:00`)).toUpperCase();
    const icon = element('span', 'weather-icon', weatherIcon(day.code));
    icon.setAttribute('aria-label', weatherDescription(day.code));
    card.append(element('span', '', label), icon, element('strong', '', `${Math.round(day.high)}°`), element('small', '', `${Math.round(day.low)}° · ${weatherDescription(day.code)}`));
    weatherForecast.append(card);
  }
}

const brightnessValue = document.querySelector('.brightness-value');
const brightnessStatus = document.querySelector('.brightness-status');
const brightnessRestore = document.querySelector('.brightness-restore');
const brightnessSlider = document.querySelector('.brightness-slider');
let edgeBrightness = null;
let brightnessBusy = false;
let brightnessSliding = false;
function setBrightnessBusy(busy) {
  brightnessBusy = busy;
  brightnessSlider.disabled = busy || edgeBrightness == null;
  brightnessRestore.disabled = busy;
}
function renderBrightness(data) {
  brightnessBusy = false;
  edgeBrightness = data.status === 'connected' && Number.isInteger(data.current) ? data.current : null;
  brightnessValue.textContent = edgeBrightness == null ? 'UNAVAILABLE' : `${brightnessSliding ? brightnessSlider.value : edgeBrightness}%`;
  if (edgeBrightness != null && !brightnessSliding) brightnessSlider.value = String(edgeBrightness);
  brightnessStatus.textContent = data.message;
  brightnessRestore.hidden = data.original == null;
  setBrightnessBusy(false);
}
function requestBrightness(action, value) {
  if (brightnessBusy && action !== 'set') return;
  if (action !== 'set') setBrightnessBusy(true);
  request('brightness', value == null ? {action} : {action, value});
}
brightnessSlider.addEventListener('pointerdown', () => { brightnessSliding = true; });
brightnessSlider.addEventListener('input', () => {
  brightnessSliding = true;
  brightnessValue.textContent = `${brightnessSlider.value}%`;
  requestBrightness('set', Number(brightnessSlider.value));
});
brightnessSlider.addEventListener('change', () => { brightnessSliding = false; });
brightnessRestore.addEventListener('click', () => requestBrightness('restore'));

const temperatureButtons = document.querySelectorAll('[data-temperature]');
const temperatureStatus = document.querySelector('.temperature-status');
const temperatureRestore = document.querySelector('.temperature-restore');
let temperatureBusy = false;
function setTemperatureBusy(busy) {
  temperatureBusy = busy;
  temperatureButtons.forEach(button => { button.disabled = busy; });
  temperatureRestore.disabled = busy;
}
function renderTemperature(data) {
  temperatureBusy = false;
  temperatureStatus.textContent = data.message;
  temperatureButtons.forEach(button => button.setAttribute('aria-pressed', String(button.dataset.temperature === data.preset)));
  temperatureRestore.hidden = data.preset === 'neutral';
  setTemperatureBusy(false);
}
function requestTemperature(preset) {
  if (temperatureBusy) return;
  setTemperatureBusy(true);
  request('temperature', {preset});
}
temperatureButtons.forEach(button => button.addEventListener('click', () => requestTemperature(button.dataset.temperature)));
temperatureRestore.addEventListener('click', () => requestTemperature('restore'));

const costWindows = document.querySelector('.cost-windows');
function renderCostWindows(data) {
  if (data.status !== 'connected') { costWindows.textContent = 'Pi costs unavailable'; return; }
  costWindows.replaceChildren();
  for (const key of ['1d', '3d', '7d', '30d']) {
    const value = data.costs[key] ?? 0;
    const card = element('div', 'cost-window', '');
    card.append(element('span', '', key.toUpperCase()), element('strong', '', `$${value.toFixed(2)}`));
    costWindows.append(card);
  }
}

const agentList = document.querySelector('.agent-list');
const health = document.getElementById('agent-health');
const calendarContent = document.createElement('div');
const calendarHealth = document.createElement('p');
calendarContent.className = 'calendar-content';
calendarHealth.className = 'source-note';
calendarHealth.textContent = 'Connecting to Apple Calendar...';
const agenda = document.querySelector('.agenda');
agenda.querySelector('.next-event').replaceWith(calendarContent);
agenda.querySelector('.source-note').replaceWith(calendarHealth);

function element(tag, className, text) {
  const node = document.createElement(tag);
  node.className = className;
  node.textContent = text;
  return node;
}
function request(name, body = {}) {
  window.webkit.messageHandlers[name].postMessage(body);
}
function formatStatus(data) {
  return data.status === 'connected' ? 'Connected' : 'Disconnected';
}
function renderAgents(data) {
  if (data.status !== 'connected') {
    health.textContent = `${formatStatus(data)} / Retrying...`;
    return;
  }
  agentList.replaceChildren();
  document.querySelector('.count').textContent = String(data.agents.length).padStart(2, '0');
  for (const agent of data.agents.sort((a, b) => Number(b.unread) - Number(a.unread))) {
    const card = element('article', agent.unread ? 'agent-card unread' : 'agent-card', '');
    const body = element('div', 'agent-body', '');
    const heading = element('div', 'agent-heading', '');
    heading.append(element('h2', '', agent.workspace));
    const style = agent.status === 'working' ? 'running' : agent.status === 'blocked' ? 'waiting' : 'done';
    heading.append(element('span', `status ${style}`, agent.unread ? 'NEW RESPONSE' : agent.status.toUpperCase()));
    const cost = agent.cost == null ? 'Cost unavailable' : `$${agent.cost.toFixed(2)}`;
    const tokens = agent.tokens == null ? '' : ` / ${(agent.tokens / 1000).toFixed(1)}k tok`;
    body.append(heading, element('p', '', `${agent.agent} / ${agent.id}`), element('div', 'agent-cost', `${cost}${tokens}`));
    card.append(body);
    card.tabIndex = 0;
    card.setAttribute('role', 'button');
    card.setAttribute('aria-haspopup', 'dialog');
    card.setAttribute('aria-label', `View activity: ${agent.workspace}`);
    card.addEventListener('click', () => openAgent(agent));
    card.addEventListener('keydown', event => {
      if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); openAgent(agent); }
    });
    agentList.append(card);
  }
  if (!data.agents.length) agentList.append(element('p', 'source-note', 'No agents detected in this Herdr session.'));
  health.textContent = `${formatStatus(data)} / Updated ${timeFormat.format(new Date(data.updatedAt))}`;
}

const eventDialog = element('dialog', 'event-dialog', '');
eventDialog.setAttribute('aria-labelledby', 'event-detail-title');
const closeEvent = element('button', 'event-close', 'Close');
closeEvent.type = 'button';
closeEvent.addEventListener('click', () => eventDialog.close());
const eventDetail = element('div', 'event-detail-body', '');
eventDialog.append(closeEvent, eventDetail);
document.body.append(eventDialog);
eventDialog.addEventListener('click', event => {
  const bounds = eventDialog.getBoundingClientRect();
  if (event.target === eventDialog && (event.clientX < bounds.left || event.clientX > bounds.right ||
      event.clientY < bounds.top || event.clientY > bounds.bottom)) eventDialog.close();
});
function makeEventInteractive(card, event) {
  card.classList.add('calendar-event');
  card.tabIndex = 0;
  card.setAttribute('role', 'button');
  card.setAttribute('aria-label', `Event details: ${event.title}`);
  const open = () => {
    const title = element('h2', '', event.title);
    title.id = 'event-detail-title';
    const start = new Date(event.start), end = new Date(event.end);
    const format = new Intl.DateTimeFormat(undefined, {weekday: 'long', month: 'short', day: 'numeric', year: 'numeric', ...(event.allDay ? {} : {hour: '2-digit', minute: '2-digit', hourCycle: 'h23'})});
    eventDetail.replaceChildren(element('div', 'eyebrow', 'CALENDAR / READ ONLY'), title);
    eventDetail.append(element('p', '', `${event.allDay ? 'All day from' : 'Starts'}: ${format.format(start)}`));
    eventDetail.append(element('p', '', `${event.allDay ? 'Until (exclusive)' : 'Ends'}: ${format.format(end)}`));
    if (!event.allDay) eventDetail.append(element('p', '', `Duration: ${Math.max(0, Math.round((end - start) / 60000))} minutes`));
    eventDetail.append(element('p', 'source-note', `Times: ${Intl.DateTimeFormat().resolvedOptions().timeZone}`));
    eventDialog.showModal();
    closeEvent.focus();
  };
  card.addEventListener('click', open);
  card.addEventListener('keydown', key => { if (key.key === 'Enter' || key.key === ' ') { key.preventDefault(); open(); } });
}
function renderCalendar(data) {
  if (eventDialog.open || calendarContent.contains(document.activeElement)) return;
  calendarContent.replaceChildren();
  if (data.status !== 'connected') {
    const card = element('article', 'next-event', '');
    card.append(element('h2', '', data.status === 'permission_required' ? 'Calendar permission needed' : 'Calendar unavailable'), element('p', '', data.message));
    calendarContent.append(card);
    calendarHealth.textContent = data.status.toUpperCase().replaceAll('_', ' ');
    return;
  }
  const tomorrow = new Date();
  tomorrow.setHours(24, 0, 0, 0);
  const today = data.events.filter(event => new Date(event.start) < tomorrow);
  const later = data.events.filter(event => new Date(event.start) >= tomorrow);
  today.forEach((event, index) => {
    const card = element('article', index === 0 ? 'next-event' : 'agenda-row', '');
    const label = event.allDay ? 'All day' : `${timeFormat.format(new Date(event.start))} - ${timeFormat.format(new Date(event.end))}`;
    const body = element('div', '', '');
    body.append(element('h2', '', event.title));
    if (index === 0) card.append(element('div', 'eyebrow', 'REMAINING TODAY'), element('div', 'event-time', label));
    else card.append(element('time', '', label));
    card.append(body); makeEventInteractive(card, event); calendarContent.append(card);
  });
  if (!today.length) calendarContent.append(element('h2', '', 'No more events today'));
  if (later.length) {
    const preview = element('section', 'tomorrow-preview', ''); preview.append(element('h3', 'eyebrow', 'TOMORROW')); calendarContent.append(preview);
    for (const event of later) { const row = element('article', 'agenda-row', ''); row.append(element('time', '', event.allDay ? 'All day' : timeFormat.format(new Date(event.start))), element('h2', '', event.title)); makeEventInteractive(row, event); preview.append(row); if (calendarContent.scrollHeight > calendarContent.clientHeight) { row.remove(); break; } }
  }
  calendarHealth.textContent = `Apple Calendar / Updated ${timeFormat.format(new Date(data.updatedAt))}`;
}
const agentDialog = element('dialog', 'event-dialog agent-dialog', '');
agentDialog.setAttribute('aria-labelledby', 'agent-detail-title');
const agentTitle = element('h2', '', 'Agent activity');
agentTitle.id = 'agent-detail-title';
const agentStatus = element('span', 'agent-status-pill', 'CONNECTING');
const agentMeta = element('p', 'source-note', '');
const agentSummary = element('p', 'agent-summary', 'Waiting for activity...');
const messageList = element('div', 'message-list', '');
const agentActions = element('div', 'agent-actions', '');
const followButton = element('button', 'agent-action', 'Following');
const latestButton = element('button', 'agent-action', 'Jump to latest');
const agentClose = element('button', 'event-close', 'Close');
for (const button of [followButton, latestButton, agentClose]) button.type = 'button';
agentActions.append(followButton, latestButton, agentClose);
agentClose.addEventListener('click', () => agentDialog.close());
latestButton.addEventListener('click', () => { messageList.scrollTop = messageList.scrollHeight; });
followButton.addEventListener('click', () => {
  followButton.dataset.following = followButton.dataset.following === 'false' ? 'true' : 'false';
  followButton.textContent = followButton.dataset.following === 'false' ? 'Follow live' : 'Following';
});
agentDialog.append(agentActions, agentStatus, agentTitle, agentMeta, agentSummary, messageList);
document.body.append(agentDialog);
let selectedAgent = null;
let outputTimer;
function summaryFromOutput(text) {
  const lines = text.split('\n').map(line => line.trim()).filter(Boolean);
  const meaningful = lines.filter(line => !(
    line === 'yolo' ||
    /^[-─]{8,}$/.test(line) ||
    /^~\/git\//.test(line) ||
    /(?:%\/\d+k|openai\/gpt-|gpt-\d)/i.test(line)
  ));
  return meaningful.at(-1) || 'No readable recent response; Pi terminal status is hidden.';
}
function setAgentStatus(status) {
  agentStatus.textContent = status.toUpperCase();
  agentStatus.className = `agent-status-pill ${status.toLowerCase()}`;
}
agentDialog.addEventListener('close', () => {
  selectedAgent = null;
  clearTimeout(outputTimer);
  messageList.replaceChildren();
  agentTitle.textContent = 'Agent activity';
  agentMeta.textContent = '';
  agentSummary.textContent = 'Waiting for activity...';
});
function openAgent(agent) {
  selectedAgent = agent.id;
  agentTitle.textContent = agent.workspace;
  setAgentStatus(agent.unread ? 'new response' : agent.status);
  agentMeta.textContent = `${agent.agent} / ${agent.id} / Read only / Last 80 lines`;
  agentSummary.textContent = 'Loading the last 10 conversation messages...';
  messageList.replaceChildren(element('p', 'source-note', 'Loading local Pi session history...'));
  followButton.dataset.following = 'true';
  followButton.textContent = 'Following';
  agentDialog.showModal();
  agentClose.focus();
  pollOutput();
}
function pollOutput() {
  if (!agentDialog.open || !selectedAgent) return;
  request('agentMessages', {id: selectedAgent});
  outputTimer = setTimeout(pollOutput, 2000);
}
function renderMessages(data) {
  if (data.status !== 'connected') {
    messageList.replaceChildren(element('p', 'source-note', 'Conversation history is unavailable for this agent.'));
    agentSummary.textContent = 'No readable recent response.';
    return;
  }
  const atBottom = messageList.scrollHeight - messageList.scrollTop - messageList.clientHeight < 24;
  messageList.replaceChildren();
  for (const message of data.messages) {
    const card = element('article', `conversation-message ${message.role}`, '');
    const label = element('span', 'message-role', message.role === 'user' ? 'YOU' : 'AGENT');
    const text = element('p', 'message-text', message.text);
    card.append(label, text);
    messageList.append(card);
  }
  if (!data.messages.length) messageList.append(element('p', 'source-note', 'No text messages in the recent session history.'));
  const latest = data.messages.at(-1)?.text;
  agentSummary.textContent = latest ? summaryFromOutput(latest) : 'No readable recent response.';
  if (followButton.dataset.following !== 'false' || atBottom) messageList.scrollTop = messageList.scrollHeight;
}
window.edgeNativeReceive = (name, data) => {
  if (name === 'agents') renderAgents(data);
  else if (name === 'calendar') renderCalendar(data);
  else if (name === 'weather') renderWeather(data);
  else if (name === 'brightness') renderBrightness(data);
  else if (name === 'temperature') renderTemperature(data);
  else if (name === 'costWindows') renderCostWindows(data);
  else if (name === 'agentMessages' && agentDialog.open && data.id === selectedAgent) renderMessages(data);
};
function poll() {
  request('agents');
  request('calendar');
  setTimeout(poll, 1000);
}
function pollWeather() {
  request('weather');
  setTimeout(pollWeather, 15 * 60 * 1000);
}
function pollCosts() {
  request('costWindows');
  setTimeout(pollCosts, 5 * 60 * 1000);
}
poll();
pollWeather();
request('brightness', {action: 'read'});
request('temperature', {preset: 'read'});
pollCosts();
