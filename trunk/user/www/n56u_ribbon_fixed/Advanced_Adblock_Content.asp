<!DOCTYPE html>
<html>
<head>
<title>RM-AC2100 Wireless Router - Adblock</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">

<link rel="shortcut icon" href="images/favicon.ico">
<link rel="icon" href="images/favicon.png">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/bootstrap.min.css">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/main.css">
<style>
    .well { box-sizing: border-box; }
    .adblock-time input { box-sizing: border-box; }
    .adblock-sources td { vertical-align: middle; }
    .adblock-sources .src-url { font-size: 11px; word-break: break-all; }
    .adblock-extra-row { margin-bottom: 6px; }
    .adblock-extra-row input { width: 68%; }
    .adblock-extra-row .extra-status { margin-left: 8px; font-size: 12px; }
    .adblock-status-line { margin-top: 6px; }
    .adblock-pause-row { display: flex; align-items: center; flex-wrap: wrap; }
    .adblock-pause-row label { margin: 0 8px 0 0; font-weight: 600; }
    .adblock-pause-row select { width: auto; margin: 0 10px 0 0; }
    .adblock-pause-row .btn { margin: 0; }
    @media (max-width: 1000px) {
        .wrapper { width: auto; max-width: 100%; min-width: 0; }
    }
    .adblock-status-row { display: flex; flex-wrap: wrap; }
    .adblock-status-row > .span6 { display: flex; }
    .adblock-status-row .well { width: 100%; min-height: 132px; }
    @media (max-width: 760px) {
        .adblock-status-row { display: block; }
        .adblock-status-row > .span6 { display: block; width: auto; float: none; margin-left: 0; }
        .adblock-status-row > .span6 + .span6 { margin-top: 10px; }
    }
</style>

<script type="text/javascript" src="/jquery.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script>
<% login_state_hook(); %>

var presetMask = parseInt('<% nvram_get_x("", "adblock_presets"); %>');
if (isNaN(presetMask)) presetMask = 127;
var currentPhase = '<% nvram_get_x("", "adblock_phase"); %>';
var configDirty = '<% nvram_get_x("", "adblock_config_dirty"); %>' === '1';
var pauseUntil = parseInt('<% nvram_get_x("", "adblock_pause_until"); %>', 10);
if (isNaN(pauseUntil)) pauseUntil = 0;
var actionPending = false;
var actionFinished = false;
var formDirty = false;

var monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
var dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

function initial() {
    show_banner(1);
    show_menu(5, 9, 4);
    show_footer();
    renderPresets();
    setPresetPanel(presetPanelOpen());
    renderExtraSources();
    fixStatusText();
    updateStatusBadge();
    updateDirtyNotice();
    updatePhaseText();
    updatePauseState();
    updateSourceStatuses();
    updateScheduleHint();
    bindDirtyTracking();
    scheduleAutoRefresh();
    setInterval(function() { updatePauseState(); updateStatusBadge(); }, 30000);
}

function escapeHtml(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function escapeAttr(s) {
    return escapeHtml(s).replace(/"/g, '&quot;');
}

function markDirty() {
    formDirty = true;
}

function bindDirtyTracking() {
    if (!document.form)
        return;
    document.form.addEventListener('input', markDirty);
    document.form.addEventListener('change', markDirty);
}

function finishAction() {
    if (actionFinished || !actionPending)
        return;
    actionFinished = true;
    actionPending = false;
    formDirty = false;
    setTimeout(function() { location.reload(); }, 1200);
}

function finishSilentSave() {
    hideLoading();
    formDirty = false;
    showExtraSaveStatus('Removed and saved. Press Update list to rebuild the blocklist.');
}

function actionComplete() {
    finishAction();
}

function showExtraSaveStatus(msg) {
    var el = document.getElementById('extraSaveStatus');
    if (!el)
        return;
    el.innerHTML = escapeHtml(msg);
    el.style.display = '';
    if (showExtraSaveStatus.timer)
        clearTimeout(showExtraSaveStatus.timer);
    showExtraSaveStatus.timer = setTimeout(function() {
        el.style.display = 'none';
    }, 6000);
}

function refreshPage() {
    if (formDirty && !confirm('Discard unsaved changes?'))
        return;
    location.reload();
}

function adblockPad2(n) {
    return (n < 10 ? '0' : '') + n;
}

function fmtDate(d) {
    return dayNames[d.getDay()] + ' ' + d.getDate() + ' ' + monthNames[d.getMonth()] +
           ' ' + adblockPad2(d.getHours()) + ':' + adblockPad2(d.getMinutes());
}

function getScheduleValues() {
    var h = parseInt(document.form.adblock_update_hour.value, 10);
    var m = parseInt(document.form.adblock_update_min.value, 10);
    if (isNaN(h) || h < 0 || h > 23) h = 4;
    if (isNaN(m) || m < 0 || m > 59) m = 15;
    return { h: h, m: m };
}

function updateScheduleHint() {
    var interval = document.form.adblock_interval.value;
    var v = getScheduleValues();
    var hm = adblockPad2(v.h) + ':' + adblockPad2(v.m);
    var h12 = adblockPad2((v.h + 12) % 24) + ':' + adblockPad2(v.m);
    var h6 = [
        adblockPad2((v.h + 6) % 24) + ':' + adblockPad2(v.m),
        adblockPad2((v.h + 12) % 24) + ':' + adblockPad2(v.m),
        adblockPad2((v.h + 18) % 24) + ':' + adblockPad2(v.m)
    ];
    var shortText = '';
    var longText = '';

    if (interval === 'weekly') {
        shortText = 'Sunday ' + hm;
        longText = 'Runs every Sunday at ' + hm + '.';
    } else if (interval === 'daily') {
        shortText = 'Daily ' + hm;
        longText = 'Runs every day at ' + hm + '.';
    } else if (interval === '12h') {
        shortText = 'Every 12 hours';
        longText = 'Runs every 12 hours at ' + hm + ' and ' + h12 + '.';
    } else if (interval === '6h') {
        shortText = 'Every 6 hours';
        longText = 'Runs every 6 hours at ' + hm + ', ' + h6[0] + ', ' + h6[1] + ' and ' + h6[2] + '.';
    } else {
        shortText = 'Off';
        longText = 'Automatic updates are disabled. Use Update list to refresh manually.';
    }

    var top = document.getElementById('scheduleHintTop');
    var inline = document.getElementById('scheduleHintInline');
    var short = document.getElementById('scheduleShort');
    if (short) short.innerHTML = shortText;
    if (top) top.innerHTML = longText;
    if (inline) inline.innerHTML = longText;
    updateNextRun();
}

function updateNextRun() {
    var el = document.getElementById('nextRun');
    if (!el)
        return;
    var interval = document.form.adblock_interval.value;
    if (interval === 'off') {
        el.innerHTML = 'disabled';
        return;
    }
    var v = getScheduleValues();
    var now = new Date();
    var candidates = [];

    function at(dayOffset, hour) {
        var d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + dayOffset,
                         hour, v.m, 0, 0);
        if (d.getTime() > now.getTime())
            candidates.push(d);
    }

    if (interval === 'weekly') {
        for (var i = 0; i < 8; i++) {
            var d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + i,
                             v.h, v.m, 0, 0);
            if (d.getDay() === 0 && d.getTime() > now.getTime())
                candidates.push(d);
        }
    } else if (interval === 'daily') {
        at(0, v.h);
        at(1, v.h);
    } else if (interval === '12h') {
        at(0, v.h); at(0, (v.h + 12) % 24);
        at(1, v.h); at(1, (v.h + 12) % 24);
    } else if (interval === '6h') {
        for (var j = 0; j < 2; j++) {
            at(j, v.h); at(j, (v.h + 6) % 24);
            at(j, (v.h + 12) % 24); at(j, (v.h + 18) % 24);
        }
    }

    if (!candidates.length) {
        el.innerHTML = '&mdash;';
        return;
    }
    candidates.sort(function(a, b) { return a.getTime() - b.getTime(); });
    el.innerHTML = escapeHtml(fmtDate(candidates[0]));
}

function validateSchedule() {
    var h = parseInt(document.form.adblock_update_hour.value, 10);
    var m = parseInt(document.form.adblock_update_min.value, 10);
    if (isNaN(h) || h < 0 || h > 23) {
        alert('Update hour must be between 0 and 23.');
        document.form.adblock_update_hour.focus();
        return false;
    }
    if (isNaN(m) || m < 0 || m > 59) {
        alert('Update minute must be between 0 and 59.');
        document.form.adblock_update_min.focus();
        return false;
    }
    document.form.adblock_update_hour.value = h;
    document.form.adblock_update_min.value = m;
    return true;
}

function parsePresetConfig() {
    var el = document.getElementById('presetConfigData');
    if (!el)
        return [];
    var lines = el.value.split('\n');
    var out = [];
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].replace(/\r$/, '');
        if (!line || line.charAt(0) === '#')
            continue;
        var p = line.split('|');
        if (p.length < 3)
            continue;
        out.push({ idx: parseInt(p[0], 10), label: p[1], url: p[2] });
    }
    return out;
}

function renderPresets() {
    var rows = document.getElementById('presetRows');
    if (!rows)
        return;
    var presets = parsePresetConfig();
    var html = '';
    for (var i = 0; i < presets.length; i++) {
        var p = presets[i];
        var checked = (presetMask & (1 << p.idx)) ? ' checked' : '';
        html += '<tr>';
        html += '<td><input type="checkbox" name="preset" value="' + p.idx + '"' + checked +
                ' data-label="' + escapeAttr(p.label) + '" onchange="updateMask();"></td>';
        html += '<td><strong>' + escapeHtml(p.label) + '</strong>' +
                '<div class="src-url muted">' + escapeHtml(p.url) + '</div></td>';
        html += '<td><span class="src-status muted" data-url="' + escapeAttr(p.url) +
                '">awaiting update</span></td>';
        html += '</tr>';
    }
    rows.innerHTML = html;
    updateMask();
}

function updateMask() {
    var mask = 0;
    var boxes = document.getElementsByName('preset');
    for (var i = 0; i < boxes.length; i++) {
        if (boxes[i].checked)
            mask |= (1 << parseInt(boxes[i].value, 10));
    }
    document.form.adblock_presets.value = mask;
    updatePresetHint();
}

function setPresets(mask) {
    var boxes = document.getElementsByName('preset');
    for (var i = 0; i < boxes.length; i++)
        boxes[i].checked = (mask & (1 << parseInt(boxes[i].value, 10))) != 0;
    updateMask();
}

function defaultPresets() {
    setPresets(127);
}

function clearPresets() {
    setPresets(0);
}

function updatePresetHint() {
    var hint = document.getElementById('presetHint');
    var summary = document.getElementById('presetSummary');
    var boxes = document.getElementsByName('preset');
    var n = 0;
    var names = [];
    for (var i = 0; i < boxes.length; i++) {
        if (boxes[i].checked) {
            n++;
            if (boxes[i].getAttribute('data-label'))
                names.push(boxes[i].getAttribute('data-label'));
        }
    }
    var shortText;
    if (n === 0)
        shortText = 'No preset sources selected.';
    else
        shortText = n + ' of ' + boxes.length + ' preset source' + (n === 1 ? '' : 's') + ' selected';
    if (n > 0 && n <= 4 && names.length)
        shortText += ': ' + names.join(', ');
    else if (n > 0)
        shortText += '.';
    if (summary)
        summary.innerHTML = escapeHtml(shortText);
    if (hint) {
        if (n === 0)
            hint.innerHTML = 'No preset sources selected &mdash; extra sources and custom domains only.';
        else
            hint.innerHTML = n + ' of ' + boxes.length + ' preset source' + (n === 1 ? '' : 's') + ' selected.';
    }
}

function presetPanelOpen() {
    try { return sessionStorage.getItem('adblockPresetOpen') === '1'; } catch (e) { return false; }
}

function setPresetPanel(open) {
    var body = document.getElementById('presetBody');
    var btn = document.getElementById('presetToggle');
    var text = document.getElementById('presetToggleText');
    var icon = document.getElementById('presetToggleIcon');
    if (!body || !btn)
        return;
    body.style.display = open ? '' : 'none';
    btn.setAttribute('aria-expanded', open ? 'true' : 'false');
    if (text) text.innerHTML = open ? 'Hide' : 'Show';
    if (icon) icon.className = open ? 'icon-chevron-up' : 'icon-chevron-down';
    try { sessionStorage.setItem('adblockPresetOpen', open ? '1' : '0'); } catch (e) {}
}

function togglePresets() {
    var body = document.getElementById('presetBody');
    setPresetPanel(!body || body.style.display === 'none');
}

function sourceStatusMap() {
    var map = {};
    var el = document.getElementById('sourceStatusData');
    if (!el)
        return map;
    var lines = el.value.split('\n');
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].replace(/\r$/, '');
        if (!line)
            continue;
        var p = line.split('|');
        if (p.length >= 3)
            map[p[0]] = { lines: p[1], state: p[2], time: p[3] || '', sourceTime: p[4] || '' };
    }
    return map;
}

function statusLabel(st) {
    var text;
    if (!st)
        text = 'awaiting update';
    else if (st.state === 'ok') {
        text = st.lines + ' lines';
        text += st.sourceTime ? ' · updated ' + st.sourceTime : ' · source time unknown';
    } else if (st.state === 'failed') {
        text = 'download failed';
        if (st.time)
            text += ' · ' + st.time;
    } else if (st.state === 'empty') {
        text = 'no usable domains';
        if (st.sourceTime)
            text += ' · updated ' + st.sourceTime;
    } else {
        text = st.state;
        if (st.time)
            text += ' · ' + st.time;
    }
    return text;
}

function statusClass(st) {
    if (!st)
        return 'muted';
    return st.state === 'ok' ? 'text-success' : 'text-error';
}

function updateSourceStatuses() {
    var map = sourceStatusMap();
    var els = document.querySelectorAll('.src-status');
    for (var i = 0; i < els.length; i++) {
        var st = map[els[i].getAttribute('data-url')];
        els[i].innerHTML = escapeHtml(statusLabel(st));
        els[i].className = 'src-status ' + statusClass(st);
        els[i].title = st && st.time ? 'Downloaded ' + st.time : '';
    }
    var extras = document.querySelectorAll('.extra-source');
    for (var j = 0; j < extras.length; j++) {
        var span = extras[j].parentNode.querySelector('.extra-status');
        if (!span)
            continue;
        var est = map[extras[j].value];
        span.innerHTML = escapeHtml(statusLabel(est));
        span.className = 'extra-status ' + statusClass(est);
    }
}

function renderExtraSources() {
    var list = document.getElementById('extraSourcesList');
    if (!list)
        return;
    list.innerHTML = '';
    var el = document.getElementById('extraSourcesData');
    var lines = el ? el.value.split('\n') : [];
    var count = 0;
    for (var i = 0; i < lines.length; i++) {
        var url = lines[i].replace(/^\s+|\s+$/g, '');
        if (!url)
            continue;
        addExtraSource(url);
        count++;
    }
    if (count === 0)
        list.innerHTML = '<div class="muted" id="noExtraSources">No extra sources.</div>';
}

function addExtraSource(url) {
    var list = document.getElementById('extraSourcesList');
    if (!list)
        return;
    var hint = document.getElementById('noExtraSources');
    if (hint)
        hint.parentNode.removeChild(hint);
    var row = document.createElement('div');
    row.className = 'adblock-extra-row';
    row.innerHTML = '<input type="text" class="input-xxlarge extra-source" value="' +
        escapeAttr(url || '') + '" placeholder="https://example.com/hosts.txt"> ' +
        '<button type="button" class="btn btn-mini" onclick="removeExtraSource(this);">' +
        '<i class="icon-remove"></i> Remove</button> ' +
        '<button type="button" class="btn btn-mini btn-primary" onclick="saveSettings();">' +
        '<i class="icon-ok icon-white"></i> Apply</button> ' +
        '<span class="extra-status muted">awaiting update</span>';
    list.appendChild(row);
    var input = row.querySelector('.extra-source');
    if (input)
        input.addEventListener('input', markDirty);
}

function removeExtraSource(btn) {
    var row = btn.parentNode;
    var parent = row.parentNode;
    var next = row.nextSibling;
    parent.removeChild(row);
    markDirty();
    syncExtraSources();
    var list = document.getElementById('extraSourcesList');
    if (list && list.children.length === 0)
        list.innerHTML = '<div class="muted" id="noExtraSources">No extra sources.</div>';
    if (!validateSchedule() || !validateSources()) {
        // The rest of the form is invalid; put the row back and let the user fix it.
        var hint = document.getElementById('noExtraSources');
        if (hint)
            hint.parentNode.removeChild(hint);
        parent.insertBefore(row, next);
        syncExtraSources();
        return;
    }
    // Persist the removal now without reloading the page.
    submitAction('adblock_save.sh', true);
}

function syncExtraSources() {
    var inputs = document.querySelectorAll('.extra-source');
    var vals = [];
    for (var i = 0; i < inputs.length; i++) {
        var v = inputs[i].value.replace(/^\s+|\s+$/g, '');
        if (v)
            vals.push(v);
    }
    document.getElementById('extraSourcesValue').value = vals.join('\n');
}

function validateSources() {
    var inputs = document.querySelectorAll('.extra-source');
    for (var i = 0; i < inputs.length; i++) {
        var v = inputs[i].value.replace(/^\s+|\s+$/g, '');
        if (!v)
            continue;
        if (!/^https?:\/\/.+/.test(v)) {
            alert('Extra source must start with http:// or https://:\n' + v);
            inputs[i].focus();
            return false;
        }
    }
    return true;
}

function fixStatusText() {
    var st = document.getElementById('statusText');
    if (st && !st.innerHTML.trim())
        st.innerHTML = 'not updated yet';
    var lu = document.getElementById('lastUpdate');
    if (lu && !lu.innerHTML.trim())
        lu.innerHTML = 'never';
    var la = document.getElementById('lastAttempt');
    if (la && !la.innerHTML.trim())
        la.innerHTML = 'never';
    var bs = document.getElementById('blockedStats');
    if (bs && !bs.innerHTML.trim())
        bs.innerHTML = 'Blocked today: 0 &middot; this month: 0';
}

function isActivePhase() {
    return currentPhase === 'downloading' || currentPhase === 'merging' ||
           currentPhase === 'applying';
}

function updateStatusBadge() {
    var badge = document.getElementById('statusBadge');
    if (!badge)
        return;
    var enabled = document.form.adblock_enable.value === '1';
    var st = document.getElementById('statusText');
    var status = st ? st.innerHTML.toLowerCase() : '';
    var cls = 'label-success';
    var text = 'Enabled';
    if (!enabled) {
        cls = 'label-important';
        text = 'Disabled';
    } else if (isPaused()) {
        cls = 'label-warning';
        text = 'Paused';
    } else if (isActivePhase()) {
        cls = 'label-warning';
        text = 'Updating';
    } else if (currentPhase === 'error' ||
               /fail|error|reject|missing|invalid/.test(status)) {
        cls = 'label-important';
        text = 'Error';
    } else if (configDirty) {
        cls = 'label-info';
        text = 'Saved';
    }
    badge.className = 'label ' + cls;
    badge.innerHTML = text;
}

function updateDirtyNotice() {
    var el = document.getElementById('dirtyNotice');
    if (!el)
        return;
    var enabled = document.form.adblock_enable.value === '1';
    el.style.display = (configDirty && enabled) ? '' : 'none';
}

function isPaused() {
    return pauseUntil > Math.floor(Date.now() / 1000);
}

function pauseTimeText() {
    var d = new Date(pauseUntil * 1000);
    return dayNames[d.getDay()] + ' ' + d.getDate() + ' ' + monthNames[d.getMonth()] +
           ' ' + adblockPad2(d.getHours()) + ':' + adblockPad2(d.getMinutes());
}

function updatePauseState() {
    var active = isPaused();
    var idle = document.getElementById('pauseIdle');
    var paused = document.getElementById('pauseActive');
    var badge = document.getElementById('pauseBadge');
    if (idle) idle.style.display = active ? 'none' : '';
    if (paused) paused.style.display = active ? '' : 'none';
    if (badge) {
        badge.className = 'label ' + (active ? 'label-warning' : 'label-success');
        badge.innerHTML = active ? 'Paused' : 'Filtering on';
    }
    var idleText = document.getElementById('pauseIdleText');
    if (idleText && !active)
        idleText.innerHTML = 'Filtering is active. No pause scheduled.';
    var until = document.getElementById('pauseUntilText');
    if (until && active)
        until.innerHTML = 'Paused until <strong>' + pauseTimeText() + '</strong>. DNS filtering is off until then.';
}

function pauseAdblock() {
    var sel = document.getElementById('adblock_pause_minutes');
    var min = sel ? parseInt(sel.value, 10) : 60;
    if (isNaN(min) || min < 1)
        min = 60;
    if (!confirm('Pause DNS filtering for ' + min + ' minutes?\n\n' +
                 'Ads will not be blocked until the pause ends or you resume manually.'))
        return;
    if (!window.fetch || !window.URLSearchParams) {
        alert('This browser cannot pause Adblock. Please use a current browser.');
        return;
    }
    var body = new URLSearchParams();
    body.append('action_mode', ' Apply ');
    body.append('action_script', 'adblock_pause.sh');
    body.append('current_page', 'Advanced_Adblock_Content.asp');
    body.append('next_page', '');
    body.append('sid_list', 'General;');
    body.append('adblock_pause_minutes', String(min));
    showLoading();
    fetch('/start_apply.htm', {
        method: 'POST',
        body: body,
        credentials: 'same-origin'
    }).then(function(r) {
        if (!r.ok) throw new Error('HTTP ' + r.status);
        location.reload();
    }).catch(function() {
        hideLoading();
        alert('Could not pause Adblock.');
    });
}

function resumeAdblock() {
    if (!window.fetch || !window.URLSearchParams) {
        alert('This browser cannot resume Adblock. Please use a current browser.');
        return;
    }
    var body = new URLSearchParams();
    body.append('action_mode', ' Apply ');
    body.append('action_script', 'adblock_resume.sh');
    body.append('current_page', 'Advanced_Adblock_Content.asp');
    body.append('next_page', '');
    body.append('sid_list', 'General;');
    showLoading();
    fetch('/start_apply.htm', {
        method: 'POST',
        body: body,
        credentials: 'same-origin'
    }).then(function(r) {
        if (!r.ok) throw new Error('HTTP ' + r.status);
        location.reload();
    }).catch(function() {
        hideLoading();
        alert('Could not resume Adblock.');
    });
}

function validateWildcard() {
    var ta = document.form.adblock_wildcard;
    if (!ta)
        return true;
    var lines = ta.value.split('\n');
    for (var i = 0; i < lines.length; i++) {
        var v = lines[i].replace(/^\s+|\s+$/g, '');
        if (!v || v.charAt(0) === '#')
            continue;
        if (v.indexOf('://') !== -1 || v.indexOf('/') !== -1 ||
            !/^(\*\.)?[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$/.test(v)) {
            alert('Wildcard line ' + (i + 1) + ' is not a valid domain:\n' + v +
                  '\n\nEnter only a domain such as doubleclick.net.');
            ta.focus();
            return false;
        }
    }
    return true;
}

function updatePhaseText() {
    var el = document.getElementById('phaseText');
    if (!el)
        return;
    var progress = el.innerHTML.trim();
    var labels = {
        downloading: 'Downloading',
        merging: 'Merging sources',
        applying: 'Applying blocklist',
        error: 'Error'
    };
    if (labels[currentPhase]) {
        el.innerHTML = '<strong>' + labels[currentPhase] + '</strong>' +
                       (progress ? ' &mdash; ' + escapeHtml(progress) : '');
        el.style.display = '';
    } else if (progress) {
        el.innerHTML = escapeHtml(progress);
        el.style.display = '';
    } else {
        el.innerHTML = '';
        el.style.display = 'none';
    }
}

function scheduleAutoRefresh() {
    if (!formDirty && isActivePhase())
        setTimeout(function() { location.reload(); }, 8000);
}

function submitAction(script, silent) {
    if (!login_safe())
        return;
    updateMask();
    syncExtraSources();
    showLoading();
    document.form.action_mode.value = " Apply ";
    document.form.action_script.value = script;
    document.form.current_page.value = "Advanced_Adblock_Content.asp";
    document.form.next_page.value = "";
    if (silent && window.fetch && window.FormData && window.URLSearchParams) {
        // Save without navigating the page.  The response HTML is ignored.
        var fd = new FormData(document.form);
        fetch('/start_apply.htm', {
            method: 'POST',
            body: new URLSearchParams(fd),
            credentials: 'same-origin'
        }).then(function(r) {
            if (!r.ok)
                throw new Error('HTTP ' + r.status);
            finishSilentSave();
        }).catch(function() {
            hideLoading();
            showExtraSaveStatus('Save failed; please retry.');
        });
        return;
    }
    actionPending = true;
    actionFinished = false;
    document.form.submit();
}

function saveSettings() {
    if (!validateSchedule() || !validateSources() || !validateWildcard())
        return;
    submitAction('adblock_save.sh');
}

function updateNow() {
    if (isPaused()) {
        alert('Adblock is paused. Resume filtering before updating the list.');
        return;
    }
    if (!validateSchedule() || !validateSources() || !validateWildcard())
        return;
    submitAction('adblock_update.sh');
}

function resetDefaults() {
    if (!confirm('Restore the default sources and schedule?\n\n' +
                 'The blocklist is not downloaded until you press Update list.'))
        return;
    submitAction('adblock_reset.sh');
}

function done_validating(action) {
    finishAction();
}
</script>
</head>

<body onload="initial();" onunLoad="return unload_body();">

<div class="wrapper">
    <div class="container-fluid" style="padding-right: 0px">
        <div class="row-fluid">
            <div class="span3"><center><div id="logo"></div></center></div>
            <div class="span9">
                <div id="TopBanner"></div>
            </div>
        </div>
    </div>

    <div id="Loading" class="popup_bg"></div>

    <iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0" onload="actionComplete();"></iframe>
    <form method="post" name="form" id="ruleForm" action="/start_apply.htm" target="hidden_frame">

    <input type="hidden" name="current_page" value="Advanced_Adblock_Content.asp">
    <input type="hidden" name="next_page" value="">
    <input type="hidden" name="next_host" value="">
    <input type="hidden" name="sid_list" value="General;">
    <input type="hidden" name="group_id" value="">
    <input type="hidden" name="action_mode" value="">
    <input type="hidden" name="action_script" value="">
    <input type="hidden" name="adblock_presets" value="">
    <input type="hidden" name="adblock_extra_sources" id="extraSourcesValue" value="">

    <textarea id="presetConfigData" style="display:none;"><% nvram_get_x("", "adblock_presets_config"); %></textarea>
    <textarea id="sourceStatusData" style="display:none;"><% nvram_get_x("", "adblock_source_status"); %></textarea>
    <textarea id="extraSourcesData" style="display:none;"><% nvram_get_x("", "adblock_extra_sources"); %></textarea>

    <div class="container-fluid">
        <div class="row-fluid">
            <div class="span3">
                <div class="well sidebar-nav side_nav" style="padding: 0px;">
                    <ul id="mainMenu" class="clearfix"></ul>
                    <ul class="clearfix">
                        <li>
                            <div id="subMenu" class="accordion"></div>
                        </li>
                    </ul>
                </div>
            </div>

            <div class="span9">
                <div class="row-fluid">
                    <div class="span12">
                        <div class="box well grad_colour_dark_blue">
                            <h2 class="box_head round_top"><i class="icon-filter"></i> Adblock</h2>
                            <div class="round_bottom">
                                <div class="row-fluid">
                                    <div id="tabMenu" class="submenuBlock"></div>

                                    <div class="alert alert-info" style="margin: 10px;">
                                        DNS blocklist for clients connected through this router or AP.
                                        Both IPv4 and IPv6 DNS are filtered.
                                        AP mode uses a separate resolver; router mode integrates with the system dnsmasq.
                                        Save settings first, then press <strong>Update list</strong> to rebuild the blocklist.
                                    </div>

                                    <div class="row-fluid adblock-status-row" style="margin: 0 0 10px; padding: 0 10px; box-sizing: border-box;">
                                        <div class="span6">
                                            <div class="well" style="margin-bottom: 0; padding: 12px;">
                                                <div class="clearfix">
                                                    <span class="pull-left"><strong>Status</strong></span>
                                                    <span class="pull-right">
                                                        <button type="button" class="btn btn-mini" style="margin-right: 6px;" onclick="refreshPage();"><i class="icon-refresh"></i> Refresh</button>
                                                        <span id="statusBadge" class="label">Status</span>
                                                    </span>
                                                </div>
                                                <div class="muted" style="margin-top: 8px;">
                                                    Last successful blocklist build: <span id="lastUpdate"><% nvram_get_x("", "adblock_last_success"); %></span><br>
                                                    Last attempt: <span id="lastAttempt"><% nvram_get_x("", "adblock_last_attempt"); %></span>
                                                </div>
                                                <div class="muted adblock-status-line" id="blockedStats"><% nvram_get_x("", "adblock_stats_short"); %></div>
                                                <div class="muted adblock-status-line" id="statusText"><% nvram_get_x("", "adblock_status"); %></div>
                                                <div class="muted adblock-status-line" id="phaseText"><% nvram_get_x("", "adblock_progress"); %></div>
                                                <div class="alert alert-warning" id="dirtyNotice" style="display:none; margin:8px 0 0; padding:6px 10px;">
                                                    Settings saved. Press <strong>Update list</strong> to rebuild the blocklist.
                                                </div>
                                            </div>
                                        </div>
                                        <div class="span6">
                                            <div class="well" style="margin-bottom: 0; padding: 12px;">
                                                <div class="clearfix">
                                                    <span class="pull-left"><strong>Schedule</strong></span>
                                                    <span class="pull-right muted" id="scheduleShort"></span>
                                                </div>
                                                <div class="muted" style="margin-top: 8px;" id="scheduleHintTop"></div>
                                                <div class="muted" style="margin-top: 6px;">Next run: <span id="nextRun"></span></div>
                                            </div>
                                        </div>
                                    </div>

                                    <div class="well" style="margin: 0 10px 10px; padding: 12px;">
                                        <div class="clearfix">
                                            <h4 class="pull-left" style="margin-top: 0;">Pause filtering</h4>
                                            <span id="pauseBadge" class="label pull-right">Filtering on</span>
                                        </div>
                                        <div id="pauseIdle">
                                            <p class="muted" id="pauseIdleText" style="margin-bottom: 8px;">Filtering is active. No pause scheduled.</p>
                                            <div class="adblock-pause-row">
                                                <label for="adblock_pause_minutes">Pause for</label>
                                                <select id="adblock_pause_minutes" name="adblock_pause_minutes" class="input">
                                                    <option value="15">15 minutes</option>
                                                    <option value="30">30 minutes</option>
                                                    <option value="60" selected>1 hour</option>
                                                    <option value="120">2 hours</option>
                                                    <option value="240">4 hours</option>
                                                    <option value="480">8 hours</option>
                                                    <option value="1440">24 hours</option>
                                                </select>
                                                <button type="button" class="btn btn-warning" onclick="pauseAdblock();"><i class="icon-pause"></i> Pause filtering</button>
                                            </div>
                                            <div class="help-block" style="margin-bottom: 0;">Temporarily stop blocking ads without disabling the resolver. Filtering resumes automatically when the pause expires.</div>
                                        </div>
                                        <div id="pauseActive" style="display:none;">
                                            <p id="pauseUntilText" class="muted"></p>
                                            <button type="button" class="btn btn-primary" onclick="resumeAdblock();"><i class="icon-play icon-white"></i> Resume filtering now</button>
                                        </div>
                                    </div>

                                    <div class="well" style="margin: 0 10px 10px; padding: 12px;">
                                        <h4 style="margin-top: 0;">General</h4>
                                        <table class="table table-condensed" style="margin-bottom: 0;">
                                            <tr>
                                                <th width="35%">Adblock enabled</th>
                                                <td>
                                                    <select name="adblock_enable" class="input" onchange="updateStatusBadge(); updateDirtyNotice();">
                                                        <option value="1" <% nvram_match_x("", "adblock_enable", "1", "selected"); %>>Enabled</option>
                                                        <option value="0" <% nvram_match_x("", "adblock_enable", "0", "selected"); %>>Disabled</option>
                                                    </select>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>Update interval</th>
                                                <td>
                                                    <select name="adblock_interval" class="input" onchange="updateScheduleHint();">
                                                        <option value="weekly" <% nvram_match_x("", "adblock_interval", "weekly", "selected"); %>>Weekly</option>
                                                        <option value="daily" <% nvram_match_x("", "adblock_interval", "daily", "selected"); %>>Daily</option>
                                                        <option value="12h" <% nvram_match_x("", "adblock_interval", "12h", "selected"); %>>Every 12 hours</option>
                                                        <option value="6h" <% nvram_match_x("", "adblock_interval", "6h", "selected"); %>>Every 6 hours</option>
                                                        <option value="off" <% nvram_match_x("", "adblock_interval", "off", "selected"); %>>Disabled</option>
                                                    </select>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>Update time</th>
                                                <td>
                                                    <input type="text" class="input-mini" name="adblock_update_hour" maxlength="2"
                                                           value="<% nvram_get_x("", "adblock_update_hour"); %>"
                                                           onchange="updateScheduleHint();" onkeyup="updateScheduleHint();"
                                                           onKeyPress="return is_number(this,event);" />
                                                    <span class="help-inline">:</span>
                                                    <input type="text" class="input-mini" name="adblock_update_min" maxlength="2"
                                                           value="<% nvram_get_x("", "adblock_update_min"); %>"
                                                           onchange="updateScheduleHint();" onkeyup="updateScheduleHint();"
                                                           onKeyPress="return is_number(this,event);" />
                                                    <span class="help-inline">24-hour clock</span>
                                                    <div class="help-block" id="scheduleHintInline" style="margin-bottom: 0;"></div>
                                                </td>
                                            </tr>
                                        </table>
                                    </div>

                                    <div class="well" style="margin: 0 10px 10px; padding: 12px;">
                                        <div class="clearfix">
                                            <h4 class="pull-left" style="margin-top: 0;">Preset sources</h4>
                                            <div class="pull-right">
                                                <button type="button" class="btn btn-mini btn-primary" onclick="saveSettings();"><i class="icon-ok icon-white"></i> Apply</button>
                                                <button type="button" class="btn btn-mini" onclick="defaultPresets();">Defaults</button>
                                                <button type="button" class="btn btn-mini" onclick="clearPresets();">Clear all</button>
                                                <button type="button" class="btn btn-mini" id="presetToggle" onclick="togglePresets();" aria-expanded="false" aria-controls="presetBody">
                                                    <i class="icon-chevron-down" id="presetToggleIcon"></i> <span id="presetToggleText">Show</span>
                                                </button>
                                            </div>
                                        </div>
                                        <p class="muted" id="presetSummary" style="margin-bottom: 0;">Loading preset sources...</p>
                                        <div id="presetBody" style="display:none; margin-top: 10px;">
                                            <p class="muted">Preset lists are downloaded during an update. Uncheck a source to remove it from the next build.</p>
                                            <div class="help-block" id="presetHint" style="margin-bottom: 10px;"></div>
                                            <table class="table table-condensed adblock-sources">
                                                <thead>
                                                    <tr>
                                                        <th width="40">Use</th>
                                                        <th>Source</th>
                                                        <th width="34%">Source updated <span class="muted">(server time)</span></th>
                                                    </tr>
                                                </thead>
                                                <tbody id="presetRows"></tbody>
                                            </table>
                                        </div>
                                    </div>

                                    <div class="well" style="margin: 0 10px 10px; padding: 12px;">
                                        <div class="clearfix">
                                            <h4 class="pull-left" style="margin-top: 0;">Extra source URLs</h4>
                                            <div class="pull-right">
                                                <button type="button" class="btn btn-mini" onclick="addExtraSource('');"><i class="icon-plus"></i> Add source</button>
                                            </div>
                                        </div>
                                        <p class="muted">These rows are for links to <strong>hosts/blocklist files</strong>, not websites you want to block. Add a row, paste the list URL, then press <strong>Apply</strong>. To block a site, add its domain under <strong>Custom blocked domains</strong> below. <strong>Remove</strong> deletes the row and saves immediately.</p>
                                        <div id="extraSourcesList"></div>
                                        <div id="extraSaveStatus" class="muted" style="display:none; margin-top:6px;"></div>
                                    </div>

                                    <div class="well" style="margin: 0 10px 10px; padding: 12px;">
                                        <h4 style="margin-top: 0;">Custom rules</h4>
                                        <table class="table table-condensed" style="margin-bottom: 0;">
                                            <tr>
                                                <th>Custom blocked domains <span class="muted">(one per line)</span></th>
                                            </tr>
                                            <tr>
                                                <td>
                                                    <textarea rows="5" wrap="off" spellcheck="false" maxlength="16384" class="span12"
                                                              name="adblock_custom" placeholder="example.com"
                                                              style="resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_get_x("", "adblock_custom"); %></textarea>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>Allowed domains <span class="muted">(never block, one per line)</span></th>
                                            </tr>
                                            <tr>
                                                <td>
                                                    <textarea rows="5" wrap="off" spellcheck="false" maxlength="16384" class="span12"
                                                              name="adblock_allow" placeholder="example.com"
                                                              style="resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_get_x("", "adblock_allow"); %></textarea>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>Wildcard blocked domains <span class="muted">(domain and all subdomains, one per line)</span></th>
                                            </tr>
                                            <tr>
                                                <td>
                                                    <textarea rows="5" wrap="off" spellcheck="false" maxlength="16384" class="span12"
                                                              name="adblock_wildcard" placeholder="doubleclick.net"
                                                              style="resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_get_x("", "adblock_wildcard"); %></textarea>
                                                    <div class="help-block">Wildcard entries block the domain and every subdomain. They are applied when you press <strong>Update list</strong>.</div>
                                                </td>
                                            </tr>
                                        </table>
                                    </div>

                                    <div class="well" style="margin: 0 10px 10px; padding: 12px;">
                                        <h4 style="margin-top: 0;">DNS protection</h4>
                                        <table class="table table-condensed" style="margin-bottom: 0;">
                                            <tr>
                                                <th width="45%">Block DNS-over-HTTPS providers</th>
                                                <td>
                                                    <select name="adblock_doh_block" class="input">
                                                        <option value="1" <% nvram_match_x("", "adblock_doh_block", "1", "selected"); %>>Enabled</option>
                                                        <option value="0" <% nvram_match_x("", "adblock_doh_block", "0", "selected"); %>>Disabled</option>
                                                    </select>
                                                    <div class="help-block">Blocks known DoH endpoints and the Firefox canary domain so clients use this resolver.</div>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>Reject DNS rebinding</th>
                                                <td>
                                                    <select name="adblock_rebind" class="input">
                                                        <option value="0" <% nvram_match_x("", "adblock_rebind", "0", "selected"); %>>Disabled</option>
                                                        <option value="1" <% nvram_match_x("", "adblock_rebind", "1", "selected"); %>>Enabled</option>
                                                    </select>
                                                    <div class="help-block">Rejects upstream answers that point to private IP addresses. May break local hostnames in AP mode; leave off if unsure.</div>
                                                </td>
                                            </tr>
                                        </table>
                                        <p class="muted" style="margin-bottom: 0;">These options are applied when you press <strong>Update list</strong>.</p>
                                    </div>

                                    <div class="row-fluid" style="margin: 0 10px 20px;">
                                        <div class="span12" style="text-align: center;">
                                            <button type="button" class="btn btn-primary" onclick="saveSettings();"><i class="icon-ok icon-white"></i> Save settings</button>
                                            <button type="button" class="btn" onclick="updateNow();"><i class="icon-refresh"></i> Update list</button>
                                            <button type="button" class="btn" onclick="resetDefaults();"><i class="icon-repeat"></i> Restore defaults</button>
                                            <a class="btn" href="Advanced_Adblock_Diagnostics.asp"><i class="icon-list-alt"></i> Diagnostics</a>
                                        </div>
                                    </div>


                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    </form>

    <div id="footer"></div>
</div>

</body>
</html>
