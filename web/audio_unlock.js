/*
 * Chain Escape - Web audio unlock (iOS Safari first, all browsers).
 *
 * Injected into the exported page's <head> BEFORE the Godot engine loads
 * (export_presets.cfg -> html/head_include; regenerate it with
 * tools/sync_web_head.py after editing this file).
 *
 * Why this exists: Godot creates its AudioContext at engine start, before
 * any tap, so browsers create it "suspended". iOS Safari only lets a page
 * start audio from inside an activation event (touchend / click / pointerup
 * / keydown), and plays Web Audio through the ringer/silent switch unless
 * the page asks for the "playback" audio session. The engine does not
 * expose its context, so we capture it here and unlock it ourselves.
 *
 * On EVERY activation event until audio runs (and again if iOS later
 * interrupts it):
 *   1. navigator.audioSession.type = "playback"   (iOS 17+: ignore mute switch)
 *   2. iOS without audioSession: play a 50 ms silent <audio> once
 *   3. ctx.resume() on every captured AudioContext that is not "running"
 *   4. start a 1-frame silent buffer on it (older iOS needs a real start)
 * Godot polls window.ceAudio.state() and starts music only once it reports
 * "running". Nothing audible is played here unless ?audiotest=1 asks for a
 * test tone.
 *
 * TEMPORARY DEBUG: logs go to the console ("[CE-Audio]"); add ?audiodebug=1
 * to the URL to also see them on screen (useful on an iPhone).
 */
(function () {
  'use strict';
  var params = location.search || '';
  var SHOW = /[?&]audiodebug/.test(params);
  var lines = [];
  var box = null;
  var ua = navigator.userAgent || '';
  var isIOS = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  var browser = /Edg\//.test(ua) ? 'Edge' : /CriOS|Chrome\//.test(ua) ? 'Chrome'
    : /FxiOS|Firefox\//.test(ua) ? 'Firefox' : /Safari\//.test(ua) ? 'Safari' : 'other';
  var platform = (isIOS ? 'iOS' : /Android/.test(ua) ? 'Android' : 'desktop') + ' ' + browser;

  function log(msg) {
    var line = '[CE-Audio] ' + msg;
    console.log(line);
    lines.push(line);
    if (lines.length > 40) lines.shift();
    if (SHOW) {
      if (!box && document.body) {
        box = document.createElement('div');
        box.style.cssText = 'position:fixed;left:0;right:0;bottom:0;max-height:38%;overflow:auto;z-index:99999;' +
          'background:rgba(0,0,0,.78);color:#9f9;font:11px/1.35 monospace;padding:6px;pointer-events:none;white-space:pre-wrap';
        document.body.appendChild(box);
      }
      if (box) { box.textContent = lines.join('\n'); box.scrollTop = box.scrollHeight; }
    }
  }

  // --- capture every AudioContext the engine creates -----------------------
  var contexts = [];
  var Orig = window.AudioContext || window.webkitAudioContext;
  if (Orig) {
    var Wrapped = function (opts) {
      var c = (opts === undefined) ? new Orig() : new Orig(opts);
      contexts.push(c);
      log('AudioContext created: state=' + c.state + ' sampleRate=' + c.sampleRate);
      c.addEventListener('statechange', function () { log('AudioContext state -> ' + c.state); });
      return c;
    };
    Wrapped.prototype = Orig.prototype;
    window.AudioContext = Wrapped;
    if (window.webkitAudioContext) window.webkitAudioContext = Wrapped;
  }
  log('platform: ' + platform + (Orig ? '' : ' (NO Web Audio support)'));

  var SILENT_WAV = 'data:audio/wav;base64,UklGRrQBAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YZABAACAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA';
  var gestures = 0;
  var mediaKicked = false;

  function allRunning() {
    if (!contexts.length) return false;
    for (var i = 0; i < contexts.length; i++) if (contexts[i].state !== 'running') return false;
    return true;
  }

  function states() {
    return contexts.map(function (c) { return c.state; }).join(',') || 'none';
  }

  function unlock(eventType) {
    // 1) iOS 17+: route Web Audio as media playback (not muted by the silent switch).
    if (navigator.audioSession && navigator.audioSession.type !== 'playback') {
      try { navigator.audioSession.type = 'playback'; log('audioSession.type = playback'); }
      catch (e) { log('audioSession not settable: ' + e); }
    }
    // 2) Older iOS: a short silent media element switches the audio route.
    if (isIOS && !navigator.audioSession && !mediaKicked) {
      mediaKicked = true;
      try {
        var a = document.createElement('audio');
        a.setAttribute('playsinline', '');
        a.src = SILENT_WAV;
        var p = a.play();
        if (p && p.then) p.then(function () { log('silent media kick: ok'); }, function (e) { log('silent media kick failed: ' + e); });
      } catch (e) { log('silent media kick error: ' + e); }
    }
    if (!contexts.length) { log('gesture (' + eventType + ') before the engine created audio - will retry'); return; }
    // 3) + 4) resume and start a silent buffer, synchronously inside the gesture.
    contexts.forEach(function (c, i) {
      var before = c.state;
      if (before !== 'running') {
        log('unlock attempt #' + gestures + ' (' + eventType + '): context ' + i + ' state before = ' + before);
        try {
          c.resume().then(function () { log('resume() resolved: context ' + i + ' state after = ' + c.state); },
            function (e) { log('resume() rejected: ' + e + ' (will retry on next tap)'); });
        } catch (e) { log('resume() threw: ' + e); }
      }
      try {
        var buf = c.createBuffer(1, 1, c.sampleRate);
        var src = c.createBufferSource();
        src.buffer = buf;
        src.connect(c.destination);
        src.start(0);
      } catch (e) { log('silent buffer failed: ' + e); }
    });
  }

  function onGesture(e) {
    gestures++;
    if (gestures === 1) log('first user gesture: ' + e.type + ' (contexts: ' + states() + ')');
    if (allRunning()) return; // already unlocked: nothing to do, never restarts anything
    unlock(e.type);
  }

  // Activation-triggering events only (touchstart is NOT one on iOS).
  ['touchend', 'pointerup', 'mouseup', 'click', 'keydown'].forEach(function (t) {
    window.addEventListener(t, onGesture, { capture: true, passive: true });
  });

  // --- API used by Godot (JavaScriptBridge) --------------------------------
  window.ceAudio = {
    platform: platform,
    isIOS: isIOS,
    /** "running" when every engine AudioContext runs; "none" before creation. */
    state: function () {
      if (!contexts.length) return 'none';
      return allRunning() ? 'running' : contexts[0].state;
    },
    gestures: function () { return gestures; },
    /** Audio clock advancing = the output really runs. */
    time: function () { return contexts.length ? contexts[0].currentTime : -1; },
    log: log,
    lines: function () { return lines.slice(); },
    /** Short, quiet, harmless beep straight through Web Audio (bypasses Godot). */
    testTone: function () {
      var c = contexts[0];
      if (!c || c.state !== 'running') { log('test tone skipped: context ' + (c ? c.state : 'missing')); return false; }
      var o = c.createOscillator();
      var g = c.createGain();
      o.frequency.value = 880;
      g.gain.setValueAtTime(0.0001, c.currentTime);
      g.gain.exponentialRampToValueAtTime(0.06, c.currentTime + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, c.currentTime + 0.18);
      o.connect(g); g.connect(c.destination);
      o.start(); o.stop(c.currentTime + 0.2);
      log('JS test tone played (880 Hz, 0.2 s)');
      return true;
    }
  };
})();
