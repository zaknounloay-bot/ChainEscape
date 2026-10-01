/*
 * Chain Escape - developer share test page (?sharetest=1 or &sharetest=1).
 *
 * Real-device check only: which way of handing a message to WhatsApp opens
 * the MAIN WhatsApp app (so a sent message leaves at once) while keeping the
 * game page alive. Three plain links, so each gets a genuine iPhone tap:
 *   1  https://wa.me/?text=...   same page
 *   2  https://wa.me/?text=...   new tab (target=_blank)
 *   3  whatsapp://send?text=...
 * The message is a dummy test text with a timestamp (no challenge, no
 * private data). "Loads in this tab" counts page loads in this tab
 * (sessionStorage): if it went up after coming back, the page reloaded.
 * Does nothing at all without the parameter; never touches the game, the
 * save, the network or the production SHARE.
 */
(function () {
  'use strict';
  var on = false;
  try {
    var parts = String(location.search + location.hash).split(/[?&#]/);
    for (var i = 0; i < parts.length; i++) {
      if (/^sharetest=(1|true)$/i.test(parts[i])) on = true;
    }
  } catch (e) { on = false; }
  if (!on) return;

  var loads = 1;
  try {
    loads = (parseInt(sessionStorage.getItem('ce_sharetest_loads') || '0', 10) || 0) + 1;
    sessionStorage.setItem('ce_sharetest_loads', String(loads));
  } catch (e) { /* private mode: counter unavailable */ }
  var loadedAt = new Date().toTimeString().slice(0, 8);

  function build() {
    if (document.getElementById('ce-sharetest')) return;
    var stamp = new Date().toTimeString().slice(0, 8);
    var text = 'Chain Escape share test ' + stamp + ' ' + location.origin + location.pathname;
    var enc = encodeURIComponent(text);
    var ui = 'font-family:-apple-system,system-ui,sans-serif;';
    var d = document.createElement('div');
    d.id = 'ce-sharetest';
    d.style.cssText = 'position:fixed;left:0;right:0;bottom:0;z-index:2147483646;background:#fff;color:#2B2440;' +
      'padding:16px 16px calc(16px + env(safe-area-inset-bottom));border-radius:20px 20px 0 0;' +
      'box-shadow:0 -6px 24px rgba(0,0,0,.25);' + ui + 'font-size:15px;line-height:1.35';
    var html = '<div style="font-weight:800;font-size:17px;margin-bottom:4px">SHARE TEST (DEV)</div>' +
      '<div id="ce-sharetest-info" style="font-size:13px;color:#6B6480;margin-bottom:10px">' +
      'Page loaded ' + loadedAt + ' · loads in this tab: <b id="ce-sharetest-loads">' + loads + '</b><br>' +
      'Message: “' + text.replace(/</g, '&lt;') + '”</div>';
    var links = [
      ['ce-st-1', '1 · wa.me — same page', 'https://wa.me/?text=' + enc, ''],
      ['ce-st-2', '2 · wa.me — new tab', 'https://wa.me/?text=' + enc, '_blank'],
      ['ce-st-3', '3 · whatsapp://', 'whatsapp://send?text=' + enc, ''],
    ];
    for (var i = 0; i < links.length; i++) {
      var l = links[i];
      html += '<a id="' + l[0] + '" href="' + l[2] + '"' + (l[3] ? ' target="_blank" rel="noopener"' : '') +
        ' style="display:block;text-align:center;text-decoration:none;border-radius:14px;padding:14px 10px;margin-top:8px;' +
        'background:#C645E6;color:#fff;font-weight:800;font-size:17px">' + l[1] + '</a>';
    }
    html += '<button id="ce-st-close" style="display:block;width:100%;border:0;border-radius:14px;padding:12px;margin-top:8px;' +
      'background:#F1EDF9;color:#2B2440;' + ui + 'font-weight:800;font-size:16px">HIDE</button>';
    d.innerHTML = html;
    // Taps here belong to this panel only (not the game underneath).
    ['touchstart', 'touchend', 'mousedown', 'mouseup', 'click'].forEach(function (t) {
      d.addEventListener(t, function (e) { e.stopPropagation(); }, false);
    });
    document.body.appendChild(d);
    document.getElementById('ce-st-close').addEventListener('click', function () { d.remove(); });
  }
  if (document.body) build(); else document.addEventListener('DOMContentLoaded', build);
  window.ceShareTest = { loads: function () { return loads; } };
})();
