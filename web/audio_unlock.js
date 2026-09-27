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
 * "running" after a real gesture. Nothing audible is ever played here.
 * Only failures are logged (console.warn).
 */
(function () {
  'use strict';
  var ua = navigator.userAgent || '';
  var isIOS = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

  function warn(msg) { console.warn('[CE-Audio] ' + msg); }

  // --- capture every AudioContext the engine creates -----------------------
  var contexts = [];
  var Orig = window.AudioContext || window.webkitAudioContext;
  if (Orig) {
    var Wrapped = function (opts) {
      var c = (opts === undefined) ? new Orig() : new Orig(opts);
      contexts.push(c);
      return c;
    };
    Wrapped.prototype = Orig.prototype;
    window.AudioContext = Wrapped;
    if (window.webkitAudioContext) window.webkitAudioContext = Wrapped;
  } else {
    warn('no Web Audio support in this browser');
  }

  var SILENT_WAV = 'data:audio/wav;base64,UklGRrQBAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YZABAACAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA';
  var gestures = 0;
  var unlockAttempts = 0;
  var mediaKicked = false;

  function allRunning() {
    if (!contexts.length) return false;
    for (var i = 0; i < contexts.length; i++) if (contexts[i].state !== 'running') return false;
    return true;
  }

  function unlock() {
    // 1) iOS 17+: route Web Audio as media playback (not muted by the silent switch).
    if (navigator.audioSession && navigator.audioSession.type !== 'playback') {
      try { navigator.audioSession.type = 'playback'; } catch (e) { warn('audioSession not settable: ' + e); }
    }
    // 2) Older iOS: a short silent media element switches the audio route.
    if (isIOS && !navigator.audioSession && !mediaKicked) {
      mediaKicked = true;
      try {
        var a = document.createElement('audio');
        a.setAttribute('playsinline', '');
        a.src = SILENT_WAV;
        var p = a.play();
        if (p && p.catch) p.catch(function (e) { warn('silent media kick failed: ' + e); });
      } catch (e) { warn('silent media kick error: ' + e); }
    }
    if (!contexts.length) return; // engine not started yet - the next tap retries
    unlockAttempts++;
    // 3) + 4) resume and start a silent buffer, synchronously inside the gesture.
    contexts.forEach(function (c) {
      if (c.state !== 'running') {
        try {
          c.resume().catch(function (e) { warn('resume() rejected: ' + e + ' (will retry on the next tap)'); });
        } catch (e) { warn('resume() threw: ' + e); }
      }
      try {
        var src = c.createBufferSource();
        src.buffer = c.createBuffer(1, 1, c.sampleRate);
        src.connect(c.destination);
        src.start(0);
      } catch (e) { warn('silent buffer failed: ' + e); }
    });
  }

  function onGesture() {
    gestures++;
    if (allRunning()) return; // already unlocked: nothing to do, never restarts anything
    unlock();
  }

  // Activation-triggering events only (touchstart is NOT one on iOS).
  ['touchend', 'pointerup', 'mouseup', 'click', 'keydown'].forEach(function (t) {
    window.addEventListener(t, onGesture, { capture: true, passive: true });
  });

  // --- API used by Godot (JavaScriptBridge) --------------------------------
  window.ceAudio = {
    isIOS: isIOS,
    /** "running" when every engine AudioContext runs; "none" before creation. */
    state: function () {
      if (!contexts.length) return 'none';
      return allRunning() ? 'running' : contexts[0].state;
    },
    gestures: function () { return gestures; },
    /** Counters for automated tests (no logging). */
    info: function () { return { gestures: gestures, unlockAttempts: unlockAttempts, contexts: contexts.length }; }
  };
})();
