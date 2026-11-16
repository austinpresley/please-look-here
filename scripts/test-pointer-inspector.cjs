#!/usr/bin/env node
// Runs the actual inspector script with a tiny DOM/socket stub. No host or UI.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const html = fs.readFileSync(path.join(__dirname, '../streamdeck/inspectors/choose-pointer.html'), 'utf8');
const source = html.match(/<script>([\s\S]*?)<\/script>/)[1];

function inspector(saved) {
  const sent = [];
  const handlers = {};
  const select = {
    value: '', attributes: {}, invalid: null,
    querySelector() { return this.invalid; },
    prepend(option) { this.invalid = option; option.remove = () => { this.invalid = null; }; },
    setAttribute(key, value) { this.attributes[key] = value; },
    addEventListener(event, handler) { handlers[event] = handler; }
  };
  const error = { hidden: true };
  let socket;
  class Socket {
    static OPEN = 1;
    constructor() { this.readyState = 0; socket = this; }
    send(value) { sent.push(JSON.parse(value)); }
  }
  const sandbox = {
    document: { getElementById: id => id === 'direction' ? select : error },
    WebSocket: Socket,
    Option: function (text, value) { this.text = text; this.value = value; this.dataset = {}; }
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox);
  sandbox.connectElgatoStreamDeckSocket('1234', 'existing-context', 'registerPropertyInspector', '{}', JSON.stringify({ payload: { settings: saved } }));
  return {
    sent, select, error,
    open() { socket.readyState = 1; socket.onopen(); },
    choose(value) { select.value = value; handlers.change(); },
    received(settings) { socket.onmessage({ data: JSON.stringify({ event: 'didReceiveSettings', payload: { settings } }) }); }
  };
}

test('legacy settings open forward without rewriting any saved key', () => {
  const pi = inspector({ style: 'old-hand', activate: false, other: { keep: true } });
  assert.equal(pi.select.value, 'forward');
  pi.open();
  assert.deepEqual(pi.sent, [{ event: 'registerPropertyInspector', uuid: 'existing-context' }]);
  assert.equal(pi.error.hidden, true);
});

test('direction changes preserve all other saved settings and context', () => {
  const saved = { style: 'old-hand', activate: false, tool: 'arrow', other: { keep: true } };
  const pi = inspector(saved); pi.open(); pi.choose('backward');
  assert.deepEqual(pi.sent.at(-1), { event: 'setSettings', context: 'existing-context', payload: { ...saved, direction: 'backward' } });
  pi.choose('forward');
  assert.deepEqual(pi.sent.at(-1).payload, { ...saved, direction: 'forward' });
});

test('invalid saved directions are shown and never silently repaired', () => {
  for (const direction of [null, true, 1, '', 'previous', ['backward']]) {
    const pi = inspector({ direction, keep: 'saved' }); pi.open();
    assert.equal(pi.select.value, '');
    assert.equal(pi.error.hidden, false);
    assert.equal(pi.select.attributes['aria-invalid'], 'true');
    assert.equal(pi.sent.length, 1);
    pi.choose('backward');
    assert.deepEqual(pi.sent.at(-1).payload, { direction: 'backward', keep: 'saved' });
    assert.equal(pi.error.hidden, true);
    assert.equal(pi.select.invalid, null);
  }
});

test('host refreshes show direction without writes and preserve latest unknown fields', () => {
  const pi = inspector({}); pi.open();
  pi.received({ direction: 'backward', futureSetting: ['keep'] });
  assert.equal(pi.select.value, 'backward');
  assert.equal(pi.sent.length, 1);
  pi.choose('forward');
  assert.deepEqual(pi.sent.at(-1).payload, { direction: 'forward', futureSetting: ['keep'] });
});

test('closed sockets and invalid UI choices never write settings', () => {
  const pi = inspector({});
  pi.choose('backward'); assert.equal(pi.sent.length, 0);
  pi.open(); pi.choose('bad'); assert.equal(pi.sent.length, 1);
});
