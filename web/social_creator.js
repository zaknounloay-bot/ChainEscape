/*
 * Chain Escape - Social creator page helpers (Social MVP 0.2A).
 *
 * Kept apart from web/audio_unlock.js (audio, saves, backup codes): this
 * script never touches localStorage, the save, audio or the network.
 *
 * 1. Photo picker. iPhone Safari opens a file picker only from inside a
 *    real tap (touchend / mouse up), and Godot handles taps a frame later.
 *    So Godot registers "pick zones" (normalized screen rectangles of its
 *    CHOOSE PHOTO buttons) and this script opens the native picker from
 *    the tap itself when a tap starts and ends inside a zone. The chosen
 *    image is decoded by the browser (so iPhone photos, EXIF rotation and
 *    HEIC-to-JPEG conversion are handled natively), scaled down to at most
 *    MAX_EDGE pixels and re-encoded as JPEG. Only that small copy goes to
 *    the game; the original file is never modified, stored or uploaded.
 * 2. Message dialog. A native textarea (the iPhone keyboard works with
 *    it), opened from the tap in the same way so the keyboard comes up at
 *    once, and pinned to the top of the visible area above the keyboard.
 *
 * 3. Share (0.2C). SEND ON WHATSAPP (a wa.me link to the main WhatsApp app),
 *    MORE WAYS TO SHARE and COPY LINK are tap zones too, so the
 *    native share sheet (navigator.share) and the clipboard - both need a
 *    real tap on iPhone - run inside the tap. Without navigator.share the
 *    link is copied instead. Only the link (challenge id) is shared: never
 *    the message or photo.
 * 4. Launch link (0.2C): the challenge id in this page's own address
 *    (?challenge=<id>, or #challenge=<id>), read once for the game, which
 *    validates it.
 *
 * Godot polls takePhoto() / takeMessage() / takeShareResult() (plain
 * function calls).
 */
(function () {
  var MAX_EDGE = 1080;          // longest edge of the working copy
  var JPEG_QUALITY = 0.85;
  var MAX_FILE_BYTES = 40 * 1024 * 1024;
  var MESSAGE_MAX = 200;

  var zones = [];               // [{id, x, y, w, h}] normalized to the canvas
  var photoResult = '';         // JSON waiting for Godot
  var photoBusy = false;
  var messageResult = '';
  var draft = '';
  var dialogOpen = false;
  var lastFire = 0;
  var start = null;             // where the current touch / press began
  var input = null;
  var share = { url: '', text: '', title: '' };
  var shareResult = '';

  // Launch address parameters, read once. Values end at &, # or a second
  // ?, so a parameter appended to a full link (".../index.html?challenge=
  // <id>?friendbench=1") is still read as two parameters.
  //   challenge    the shared challenge id, as given (the game validates it:
  //                a malformed one gets a friendly "not available" screen
  //                instead of the normal start). null = no parameter at all.
  //   friendbench  1 = the developer generation benchmark page.
  var launchRaw = null;
  var devBench = false;
  try {
    var parts = String(location.search + location.hash).split(/[?&#]/);
    for (var pi = 0; pi < parts.length; pi++) {
      var eq = parts[pi].indexOf('=');
      var key = (eq < 0 ? parts[pi] : parts[pi].slice(0, eq)).trim();
      var val = eq < 0 ? '' : parts[pi].slice(eq + 1);
      try { val = decodeURIComponent(val); } catch (e2) { /* keep as given */ }
      if (key === 'challenge' && eq >= 0 && launchRaw === null) {
        launchRaw = String(val).trim().slice(0, 64);
      } else if (key === 'friendbench' && /^(1|true)?$/i.test(String(val).trim())) {
        devBench = true;
      }
    }
  } catch (e) { launchRaw = null; devBench = false; }
  var ui = 'font-family:-apple-system,system-ui,sans-serif;';

  function canvasRect() {
    var c = document.getElementById('canvas') || document.querySelector('canvas');
    return c ? c.getBoundingClientRect() : null;
  }

  function zoneAt(x, y) {
    var r = canvasRect();
    if (!r || r.width <= 0 || r.height <= 0) return null;
    var nx = (x - r.left) / r.width, ny = (y - r.top) / r.height;
    for (var i = 0; i < zones.length; i++) {
      var z = zones[i];
      if (nx >= z.x && nx <= z.x + z.w && ny >= z.y && ny <= z.y + z.h) return z;
    }
    return null;
  }

  function point(e) {
    var t = e.changedTouches && e.changedTouches[0];
    return t ? { x: t.clientX, y: t.clientY } : { x: e.clientX, y: e.clientY };
  }

  function otherDialogOpen() {
    return dialogOpen || !!document.getElementById('ce-backup') || !!document.getElementById('ce-gate') &&
      document.getElementById('ce-gate').style.display !== 'none';
  }

  function onStart(e) {
    if (!zones.length || otherDialogOpen()) { start = null; return; }
    var p = point(e);
    var z = zoneAt(p.x, p.y);
    start = z ? z.id : null;
  }

  // Runs inside the tap (an activation-triggering event), so the native
  // picker / keyboard is allowed to open.
  function onEnd(e) {
    var began = start;
    start = null;
    if (!began || !zones.length || otherDialogOpen()) return;
    var p = point(e);
    var z = zoneAt(p.x, p.y);
    if (!z || z.id !== began) return;
    var now = Date.now();
    if (now - lastFire < 800) return;  // touchend + compatibility mouseup
    lastFire = now;
    if (z.id === 'message') openMessage();
    else if (z.id === 'whatsapp') doWhatsApp();
    else if (z.id === 'share') doShare();
    else if (z.id === 'copy') doCopy();
    else openPicker();
  }

  window.addEventListener('touchstart', onStart, { capture: true, passive: true });
  window.addEventListener('touchend', onEnd, { capture: true, passive: true });
  window.addEventListener('mousedown', onStart, { capture: true, passive: true });
  window.addEventListener('mouseup', onEnd, { capture: true, passive: true });

  // --- Photo ---------------------------------------------------------------
  function openPicker() {
    if (photoBusy) return;
    if (!input) {
      input = document.createElement('input');
      input.type = 'file';
      input.accept = 'image/*';
      input.id = 'ce-photo-input';
      input.style.cssText = 'position:fixed;left:-1000px;top:0;width:1px;height:1px;opacity:0';
      input.addEventListener('change', function () {
        var f = input.files && input.files[0];
        input.value = '';  // choosing the same photo again still fires change
        if (f) decode(f);
      });
      document.body.appendChild(input);
    }
    input.click();
  }

  function fail(code) {
    photoBusy = false;
    photoResult = JSON.stringify({ ok: false, error: code });
  }

  function decode(file) {
    if (file.type && file.type.indexOf('image/') !== 0) { fail('type'); return; }
    if (file.size > MAX_FILE_BYTES) { fail('too_large'); return; }
    photoBusy = true;
    photoResult = '';
    var url = URL.createObjectURL(file);
    var img = new Image();
    img.onload = function () {
      var w = img.naturalWidth, h = img.naturalHeight;
      if (!w || !h) { URL.revokeObjectURL(url); fail('decode'); return; }
      var s = Math.min(1, MAX_EDGE / Math.max(w, h));
      var cw = Math.max(1, Math.round(w * s)), ch = Math.max(1, Math.round(h * s));
      var cv = document.createElement('canvas');
      cv.width = cw; cv.height = ch;
      var ctx = cv.getContext('2d');
      ctx.fillStyle = '#fff';  // transparent PNGs get a white background
      ctx.fillRect(0, 0, cw, ch);
      ctx.imageSmoothingQuality = 'high';
      ctx.drawImage(img, 0, 0, cw, ch);
      URL.revokeObjectURL(url);
      img.onload = img.onerror = null;  // clearing src must not report an error
      img.src = '';
      cv.toBlob(function (blob) {
        cv.width = 0; cv.height = 0;  // free the canvas memory at once (iOS)
        if (!blob) { fail('encode'); return; }
        var fr = new FileReader();
        fr.onload = function () {
          var s64 = String(fr.result);
          photoBusy = false;
          photoResult = JSON.stringify({ ok: true, w: cw, h: ch, source_w: w, source_h: h,
            b64: s64.slice(s64.indexOf(',') + 1) });
        };
        fr.onerror = function () { fail('encode'); };
        fr.readAsDataURL(blob);
      }, 'image/jpeg', JPEG_QUALITY);
    };
    img.onerror = function () { URL.revokeObjectURL(url); fail('decode'); };
    img.src = url;
  }

  // --- Message ---------------------------------------------------------------
  function openMessage() {
    var old = document.getElementById('ce-message');
    if (old) old.remove();
    dialogOpen = true;
    var opened = Date.now();
    var d = document.createElement('div');
    d.id = 'ce-message';
    // Top-aligned and sized to the visible area, so the keyboard never
    // covers the text field.
    d.style.cssText = 'position:fixed;left:0;right:0;top:0;height:100%;z-index:10003;display:flex;align-items:flex-start;justify-content:center;' +
      'background:rgba(18,16,30,.88);' + ui + 'padding:max(14px,env(safe-area-inset-top)) 14px 14px;box-sizing:border-box;overflow:auto';
    var c = document.createElement('div');
    c.style.cssText = 'background:#fff;color:#2B2440;border-radius:22px;padding:18px;max-width:440px;width:100%;box-sizing:border-box;border:3px solid #EBCBF7';
    var title = document.createElement('div');
    title.style.cssText = 'font-size:20px;font-weight:900;margin-bottom:6px';
    title.textContent = 'ADD A MESSAGE';
    var help = document.createElement('div');
    help.style.cssText = 'font-size:14px;line-height:1.4;margin-bottom:10px;color:#5C5475';
    help.textContent = "Add something they'll see when they escape.";
    var ta = document.createElement('textarea');
    ta.id = 'ce-message-text';
    ta.maxLength = MESSAGE_MAX;
    ta.rows = 4;
    ta.placeholder = 'Write your message';
    ta.value = draft.slice(0, MESSAGE_MAX);
    // 16px+ so iPhone Safari does not zoom the page when the field is focused.
    ta.style.cssText = 'width:100%;box-sizing:border-box;height:118px;border:2px solid #E4DEF2;border-radius:12px;padding:10px;font:16px/1.35 -apple-system,system-ui,sans-serif;resize:none';
    var count = document.createElement('div');
    count.id = 'ce-message-count';
    count.style.cssText = 'text-align:right;font-size:13px;font-weight:700;color:#7A7596;margin-top:4px';
    function recount() { count.textContent = ta.value.length + ' / ' + MESSAGE_MAX; }
    ta.addEventListener('input', recount);
    recount();
    var row = document.createElement('div');
    row.style.cssText = 'display:flex;gap:10px;margin-top:8px';
    function btn(id, text, bg, fg) {
      var b = document.createElement('button');
      b.id = id;
      b.textContent = text;
      b.style.cssText = 'flex:1;border:0;border-radius:16px;padding:15px 10px;background:' + bg + ';color:' + fg + ';' + ui + 'font-weight:800;font-size:17px';
      return b;
    }
    var cancel = btn('ce-message-cancel', 'CANCEL', '#F1EDF9', '#2B2440');
    var done = btn('ce-message-done', 'DONE', '#C645E6', '#fff');
    function close(result) {
      if (Date.now() - opened < 400) return;  // the opening tap's own click
      messageResult = JSON.stringify(result);
      dialogOpen = false;
      if (vv) vv.removeEventListener('resize', fit);
      ta.blur();
      d.remove();
    }
    cancel.addEventListener('click', function () { close({ done: false }); });
    done.addEventListener('click', function () { close({ done: true, text: ta.value.slice(0, MESSAGE_MAX) }); });
    row.appendChild(cancel); row.appendChild(done);
    c.appendChild(title); c.appendChild(help); c.appendChild(ta); c.appendChild(count); c.appendChild(row);
    d.appendChild(c);
    document.body.appendChild(d);
    var vv = window.visualViewport;
    function fit() { d.style.height = vv.height + 'px'; d.style.top = vv.offsetTop + 'px'; }
    if (vv) { vv.addEventListener('resize', fit); fit(); }
    // Inside the tap: iPhone Safari brings the keyboard up.
    try { ta.focus(); ta.setSelectionRange(ta.value.length, ta.value.length); } catch (e) { /* tap the field */ }
  }

  // --- Share (0.2C) -----------------------------------------------------------
  // SEND ON WHATSAPP: the challenge text + link prefilled in the MAIN
  // WhatsApp app via its official https://wa.me/?text= link. (Through the
  // share sheet, WhatsApp's share extension only queues the message until
  // WhatsApp is next opened.) Opened as a real link in a NEW TAB, inside the
  // tap, exactly as the ?sharetest=1 real-iPhone check did: the game page
  // never navigates, so it is kept even without WhatsApp installed (then
  // the wa.me page opens in that tab). Same-page only if no tab can open.
  // The page cannot know whether a message was sent: result 'whatsapp' just
  // means "handed to WhatsApp".
  function whatsAppUrl() {
    return 'https://wa.me/?text=' + encodeURIComponent((share.text ? share.text + '\n' : '') + share.url);
  }

  function doWhatsApp() {
    if (!share.url) return;
    var url = whatsAppUrl();
    var opened = false;
    try {
      var a = document.createElement('a');
      a.href = url;
      a.target = '_blank';
      a.rel = 'noopener';
      a.style.display = 'none';
      document.body.appendChild(a);
      a.click();
      a.remove();
      opened = true;
    } catch (e) { opened = false; }
    if (!opened) {
      try { location.href = url; opened = true; } catch (e2) { opened = false; }
    }
    shareResult = opened ? 'whatsapp' : 'failed';
  }

  function doShare() {
    if (!share.url) return;
    if (navigator.share) {
      try {
        navigator.share({ title: share.title, text: share.text, url: share.url }).then(
          function () { shareResult = 'shared'; },
          function (e) { shareResult = (e && e.name === 'AbortError') ? 'cancelled' : 'failed'; });
        return;
      } catch (e) { /* fall through to copy */ }
    }
    doCopy();
  }

  function copyFallback() {
    var ta = document.createElement('textarea');
    ta.value = share.url;
    ta.setAttribute('readonly', '');
    ta.style.cssText = 'position:fixed;left:-1000px;top:0;opacity:0';
    document.body.appendChild(ta);
    ta.select(); ta.setSelectionRange(0, ta.value.length);
    var ok = false;
    try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
    ta.remove();
    shareResult = ok ? 'copied' : 'failed';
  }

  function doCopy() {
    if (!share.url) return;
    if (navigator.clipboard && navigator.clipboard.writeText) {
      try {
        navigator.clipboard.writeText(share.url).then(function () { shareResult = 'copied'; }, copyFallback);
        return;
      } catch (e) { /* older browsers */ }
    }
    copyFallback();
  }

  // --- API used by Godot ----------------------------------------------------
  window.ceSocial = {
    /** zones: JSON [{id, x, y, w, h}] normalized to the canvas; '[]' clears. */
    setZones: function (json) { try { zones = JSON.parse(json) || []; } catch (e) { zones = []; } },
    /** '' while nothing is ready; else JSON {ok, w, h, source_w, source_h, b64} or {ok:false, error}. */
    takePhoto: function () { var r = photoResult; photoResult = ''; return r; },
    photoBusy: function () { return photoBusy; },
    setDraft: function (text) { draft = String(text || ''); },
    /** '' while the dialog is open / unused; else JSON {done, text}. */
    takeMessage: function () { var r = messageResult; messageResult = ''; return r; },
    dialogOpen: function () { return dialogOpen; },
    /** The link SHARE / COPY LINK will hand over (set before showing them). */
    setShare: function (url, text, title) { share = { url: String(url || ''), text: String(text || ''), title: String(title || '') }; },
    /** '' until a share / copy finished: 'whatsapp' (handed to WhatsApp) |
     *  'shared' (handed to the app picked in the share sheet) | 'copied' |
     *  'cancelled' | 'failed'. Never means "delivered". */
    takeShareResult: function () { var r = shareResult; shareResult = ''; return r; },
    canShare: function () { return !!navigator.share; },
    /** The wa.me link SEND ON WHATSAPP opens (tests / diagnostics). */
    whatsAppUrl: function () { return share.url ? whatsAppUrl() : ''; },
    /** This page's address without query / fragment (base for share links). */
    pageBase: function () { return location.origin + location.pathname; },
    /** Challenge parameter this page was opened with: '' = none, else
     *  '=' + the raw value (possibly malformed - the game validates it). */
    launchChallenge: function () { return launchRaw === null ? '' : '=' + launchRaw; },
    /** True when the address asks for the developer generation benchmark. */
    devBench: function () { return devBench; },
    /** Leaving the flow: forget zones, pending results and any open dialog. */
    reset: function () {
      zones = []; photoResult = ''; messageResult = ''; draft = '';
      share = { url: '', text: '', title: '' }; shareResult = '';
      var m = document.getElementById('ce-message');
      if (m) m.remove();
      dialogOpen = false;
    }
  };
})();
