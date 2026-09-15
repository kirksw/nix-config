'use strict';

const clock = document.getElementById('clock');
const date = document.getElementById('date');
const timezone = document.getElementById('timezone');
const timeFormat = new Intl.DateTimeFormat(undefined, {
  hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
});
const dateFormat = new Intl.DateTimeFormat(undefined, {
  weekday: 'long', month: 'long', day: 'numeric',
});

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
let lastUpdate = null;

function element(tag, className, text) {
  const node = document.createElement(tag);
  node.className = className;
  node.textContent = text;
  return node;
}

async function refreshAgents() {
  try {
    const response = await fetch('/api/agents', {signal: AbortSignal.timeout(6000)});
    if (!response.ok) throw new Error('Service unavailable');
    const data = await response.json();
    if (data.status !== 'connected') throw new Error('Herdr unavailable');
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
    lastUpdate = new Date(data.updatedAt);
    health.textContent = `Connected / Updated ${timeFormat.format(lastUpdate)}`;
  } catch {
    health.textContent = lastUpdate
      ? `STALE / Last successful update ${timeFormat.format(lastUpdate)}. Retrying...`
      : 'DISCONNECTED / Local service or Herdr unavailable. Retrying...';
  } finally {
    setTimeout(refreshAgents, 1000);
  }
}
refreshAgents();

const agenda = document.querySelector('.agenda');
const calendarContent = element('div', 'calendar-content', '');
const calendarHealth = element('p', 'source-note', 'Connecting to Apple Calendar...');
calendarContent.setAttribute('aria-live', 'polite');
agenda.querySelector('.next-event').remove();
agenda.querySelector('.source-note').remove();
agenda.append(calendarContent, calendarHealth);

async function refreshCalendar() {
  try {
    const response = await fetch('/api/calendar', {signal: AbortSignal.timeout(6000)});
    if (!response.ok) throw new Error('Calendar service unavailable');
    const data = await response.json();
    calendarContent.replaceChildren();
    if (data.status !== 'connected') {
      const card = element('article', 'next-event', '');
      card.append(element('h2', '', data.status === 'permission_required' ? 'Calendar permission needed' : 'Calendar unavailable'),
        element('p', '', data.message));
      calendarContent.append(card);
      calendarHealth.textContent = data.status.toUpperCase().replaceAll('_', ' ');
      return;
    }
    data.events.forEach((event, index) => {
      const card = element('article', index === 0 ? 'next-event' : 'agenda-row', '');
      const label = event.allDay ? 'All day' : `${timeFormat.format(new Date(event.start))} - ${timeFormat.format(new Date(event.end))}`;
      const body = element('div', '', '');
      body.append(element('h2', '', event.title));
      if (index === 0) card.append(element('div', 'eyebrow', 'REMAINING TODAY'), element('div', 'event-time', label));
      else card.append(element('time', '', label));
      card.append(body);
      calendarContent.append(card);
    });
    if (!data.events.length) calendarContent.append(element('h2', '', 'No more events today'));
    calendarHealth.textContent = `Apple Calendar / Updated ${timeFormat.format(new Date(data.updatedAt))}`;
  } catch {
    calendarContent.replaceChildren();
    calendarHealth.textContent = 'DISCONNECTED / Calendar service unavailable. Retrying...';
  } finally {
    setTimeout(refreshCalendar, 15000);
  }
}
refreshCalendar();
