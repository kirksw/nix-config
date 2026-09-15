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
    body.append(heading, element('p', '', `${agent.agent} / ${agent.id}`));
    card.append(body);
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
window.edgeNativeReceive = (name, data) => name === 'agents' ? renderAgents(data) : renderCalendar(data);
function poll() {
  request('agents');
  request('calendar');
  setTimeout(poll, 1000);
}
poll();
