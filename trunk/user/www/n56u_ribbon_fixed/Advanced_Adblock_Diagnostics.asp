<!DOCTYPE html>
<html>
<head>
<title>RM-AC2100 Wireless Router - Adblock Diagnostics</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">

<link rel="shortcut icon" href="images/favicon.ico">
<link rel="icon" href="images/favicon.png">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/bootstrap.min.css">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/main.css">
<style>
    .well { box-sizing: border-box; }
    .adblock-status-line { margin-top: 6px; }
    .recent-domain { font-family: 'Courier New', monospace; word-break: break-all; }
    #healthRows th { font-weight: 600; }
</style>

<script type="text/javascript" src="/jquery.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script>
<% login_state_hook(); %>

var currentPhase = '<% nvram_get_x("", "adblock_phase"); %>';
var adblockEnabled = '<% nvram_get_x("", "adblock_enable"); %>' === '1';
var pauseUntil = parseInt('<% nvram_get_x("", "adblock_pause_until"); %>', 10);
if (isNaN(pauseUntil)) pauseUntil = 0;
var actionPending = false;

function initial() {
    show_banner(1);
    show_menu(5, 9, 5);
    show_footer();
    fixStatusText();
    updateStatusBadge();
    updatePhaseText();
    renderHealth();
    renderRecent();
    maybeRefreshHealth();
    setInterval(updateStatusBadge, 30000);
}

function actionComplete() {
    if (!actionPending)
        return;
    actionPending = false;
    setTimeout(function() { location.reload(); }, 1200);
}

function refreshPage() {
    location.reload();
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

function isPaused() {
    return pauseUntil > Math.floor(Date.now() / 1000);
}

function updateStatusBadge() {
    var badge = document.getElementById('statusBadge');
    if (!badge)
        return;
    var st = document.getElementById('statusText');
    var status = st ? st.innerHTML.toLowerCase() : '';
    var cls = 'label-success';
    var text = 'Enabled';
    if (!adblockEnabled) {
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
    }
    badge.className = 'label ' + cls;
    badge.innerHTML = text;
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
                       (progress ? ' &mdash; ' + progress : '');
        el.style.display = '';
    } else if (progress) {
        el.innerHTML = progress;
        el.style.display = '';
    } else {
        el.innerHTML = '';
        el.style.display = 'none';
    }
}

function submitAction(script) {
    if (!login_safe())
        return;
    showLoading();
    actionPending = true;
    document.form.action_mode.value = " Apply ";
    document.form.action_script.value = script;
    document.form.current_page.value = "Advanced_Adblock_Diagnostics.asp";
    document.form.next_page.value = "";
    document.form.submit();
}

function testDomain() {
    submitAction('adblock_test.sh');
}

function viewLog() {
    submitAction('adblock_log.sh');
}

function refreshStats() {
    submitAction('adblock_stats.sh');
}

function escapeHtml(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function escapeAttr(s) {
    return escapeHtml(s).replace(/"/g, '&quot;');
}

function renderHealth() {
    var data = document.getElementById('healthData');
    var rows = document.getElementById('healthRows');
    var badge = document.getElementById('healthBadge');
    if (!rows)
        return;
    var lines = data ? data.value.split('\n') : [];
    var html = '';
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].replace(/\r$/, '');
        if (!line)
            continue;
        var p = line.split('|');
        if (p.length < 2)
            continue;
        html += '<tr><th width="35%">' + escapeHtml(p[0]) + '</th><td>' +
                escapeHtml(p.slice(1).join('|')) + '</td></tr>';
    }
    rows.innerHTML = html || '<tr><td class="muted">No health data yet. Press Refresh.</td></tr>';

    if (badge) {
        var state = '<% nvram_get_x("", "adblock_health_state"); %>';
        if (state === 'ok') {
            badge.className = 'label label-success';
            badge.innerHTML = 'Healthy';
        } else if (state === 'warn') {
            badge.className = 'label label-warning';
            badge.innerHTML = 'Warning';
        } else if (state === 'error') {
            badge.className = 'label label-important';
            badge.innerHTML = 'Error';
        } else {
            badge.className = 'label';
            badge.innerHTML = 'Unknown';
        }
    }
}

function ageText(sec) {
    sec = parseInt(sec, 10);
    if (isNaN(sec) || sec < 0) sec = 0;
    if (sec < 60) return sec + 's ago';
    if (sec < 3600) return Math.floor(sec / 60) + 'm ago';
    if (sec < 86400) return Math.floor(sec / 3600) + 'h ago';
    return Math.floor(sec / 86400) + 'd ago';
}

function renderRecent() {
    var data = document.getElementById('recentData');
    var rows = document.getElementById('recentRows');
    var empty = document.getElementById('recentEmpty');
    if (!rows)
        return;
    var lines = data ? data.value.split('\n') : [];
    var html = '';
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].replace(/\r$/, '');
        if (!line)
            continue;
        var p = line.split('|');
        if (p.length < 3)
            continue;
        var domain = p[1];
        html += '<tr><td>' + escapeHtml(p[0]) + '</td>' +
                '<td class="recent-domain">' + escapeHtml(domain) + '</td>' +
                '<td>' + escapeHtml(ageText(p[2])) + '</td>' +
                '<td><button type="button" class="btn btn-mini" data-domain="' +
                escapeAttr(domain) + '" onclick="allowDomain(this.getAttribute(\'data-domain\'));">' +
                '<i class="icon-ok"></i> Allow</button></td></tr>';
    }
    rows.innerHTML = html;
    if (empty)
        empty.style.display = html ? 'none' : '';
}

function postAction(script, fields, onSuccess) {
    if (typeof login_safe === 'function' && !login_safe())
        return false;
    if (!window.fetch || !window.URLSearchParams) {
        alert('This browser cannot run this action. Please use a current browser.');
        return false;
    }
    var body = new URLSearchParams();
    body.append('action_mode', ' Apply ');
    body.append('action_script', script);
    body.append('current_page', 'Advanced_Adblock_Diagnostics.asp');
    body.append('next_page', '');
    body.append('sid_list', 'General;');
    for (var k in fields) {
        if (Object.prototype.hasOwnProperty.call(fields, k))
            body.append(k, fields[k]);
    }
    showLoading();
    fetch('/start_apply.htm', {
        method: 'POST',
        body: body,
        credentials: 'same-origin'
    }).then(function(r) {
        if (!r.ok) throw new Error('HTTP ' + r.status);
        if (typeof onSuccess === 'function')
            onSuccess();
        else
            location.reload();
    }).catch(function() {
        hideLoading();
        alert('The action failed. Please retry.');
    });
    return true;
}

function refreshHealth() {
    postAction('adblock_health.sh', {});
}

function allowDomain(domain) {
    if (!confirm('Allow ' + domain + '?\n\n' +
                 'It will be added to the allowlist and removed from the live blocklist.'))
        return;
    postAction('adblock_allow.sh', { adblock_allow_add: domain }, function() {
        // Refresh the health snapshot so the allowed domain disappears.
        refreshHealth();
    });
}

function maybeRefreshHealth() {
    var data = document.getElementById('healthData');
    if (!data || data.value.trim())
        return;
    try {
        if (sessionStorage.getItem('adblockHealthTried') === '1')
            return;
        sessionStorage.setItem('adblockHealthTried', '1');
    } catch (e) {
        return;
    }
    refreshHealth();
}

function exportSettings() {
    submitAction('adblock_export.sh');
}

function importSettings() {
    if (!confirm('Import these settings?\n\n' +
                 'The blocklist is not downloaded until you press Update list on the Adblock page.'))
        return;
    submitAction('adblock_import.sh');
}

function done_validating(action) {
    refreshpage();
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

    <input type="hidden" name="current_page" value="Advanced_Adblock_Diagnostics.asp">
    <input type="hidden" name="next_page" value="">
    <input type="hidden" name="next_host" value="">
    <input type="hidden" name="sid_list" value="General;">
    <input type="hidden" name="group_id" value="">
    <input type="hidden" name="action_mode" value="">
    <input type="hidden" name="action_script" value="">

    <textarea id="healthData" style="display:none;"><% nvram_get_x("", "adblock_health"); %></textarea>
    <textarea id="recentData" style="display:none;"><% nvram_get_x("", "adblock_recent"); %></textarea>

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
                            <h2 class="box_head round_top"><i class="icon-list-alt"></i> Adblock Diagnostics</h2>
                            <div class="round_bottom">
                                <div class="row-fluid">
                                    <div id="tabMenu" class="submenuBlock"></div>

                                    <div class="alert alert-info" style="margin: 10px;">
                                        Inspect resolver status, test domains, review the update log and blocked-query statistics,
                                        or export/import the Adblock configuration.
                                    </div>

                                    <div class="well" style="margin: 0 10px 10px; padding: 12px;">
                                        <div class="clearfix">
                                            <span class="pull-left"><strong>Status</strong></span>
                                            <span class="pull-right">
                                                <button type="button" class="btn btn-mini" style="margin-right: 6px;" onclick="refreshPage();"><i class="icon-refresh"></i> Refresh</button>
                                                <span id="statusBadge" class="label">Status</span>
                                            </span>
                                        </div>
                                        <div class="muted" style="margin-top: 8px;">
                                            Last successful list update: <span id="lastUpdate"><% nvram_get_x("", "adblock_last_success"); %></span><br>
                                            Last attempt: <span id="lastAttempt"><% nvram_get_x("", "adblock_last_attempt"); %></span>
                                        </div>
                                        <div class="muted adblock-status-line" id="blockedStats"><% nvram_get_x("", "adblock_stats_short"); %></div>
                                        <div class="muted adblock-status-line" id="statusText"><% nvram_get_x("", "adblock_status"); %></div>
                                        <div class="muted adblock-status-line" id="phaseText"><% nvram_get_x("", "adblock_progress"); %></div>
                                    </div>

                                    <div class="well" style="margin: 0 10px 10px; padding: 12px;">
                                        <div class="clearfix">
                                            <h4 class="pull-left" style="margin-top: 0;">Health</h4>
                                            <div class="pull-right">
                                                <button type="button" class="btn btn-mini" style="margin-right: 6px;" onclick="refreshHealth();"><i class="icon-refresh"></i> Refresh</button>
                                                <span id="healthBadge" class="label">Unknown</span>
                                            </div>
                                        </div>
                                        <table class="table table-condensed" style="margin-bottom: 0;">
                                            <tbody id="healthRows"></tbody>
                                        </table>
                                    </div>

                                    <div class="well" style="margin: 0 10px 10px; padding: 12px;">
                                        <div class="clearfix">
                                            <h4 class="pull-left" style="margin-top: 0;">Recent blocked queries</h4>
                                            <div class="pull-right">
                                                <button type="button" class="btn btn-mini" onclick="refreshHealth();"><i class="icon-refresh"></i> Refresh</button>
                                            </div>
                                        </div>
                                        <p class="muted">Allow adds the domain to the allowlist and removes it from the live blocklist. Wildcard- and DoH-blocked domains are not listed here; change those settings on the Adblock page instead.</p>
                                        <table class="table table-condensed" style="margin-bottom: 0;">
                                            <thead>
                                                <tr>
                                                    <th width="12%">Hits</th>
                                                    <th>Domain</th>
                                                    <th width="22%">Last seen</th>
                                                    <th width="16%"></th>
                                                </tr>
                                            </thead>
                                            <tbody id="recentRows"></tbody>
                                        </table>
                                        <div id="recentEmpty" class="muted" style="display:none;">No recent blocked queries yet. Browse for a minute, then press Refresh.</div>
                                    </div>

                                    <div class="well" style="margin: 0 10px 10px; padding: 12px;">
                                        <h4 style="margin-top: 0;">Domain test</h4>
                                        <table class="table table-condensed" style="margin-bottom: 0;">
                                            <tr>
                                                <th width="30%">Test domain</th>
                                                <td>
                                                    <input type="text" class="input" name="adblock_test_domain"
                                                           value="<% nvram_get_x("", "adblock_test_domain"); %>" size="32" placeholder="example.com">
                                                    <button type="button" class="btn" onclick="testDomain();"><i class="icon-search"></i> Test</button>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>Test result</th>
                                                <td>
                                                    <textarea rows="6" wrap="off" readonly class="span12"
                                                              style="resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_get_x("", "adblock_test_result"); %></textarea>
                                                </td>
                                            </tr>
                                        </table>
                                    </div>

                                    <div class="well" style="margin: 0 10px 10px; padding: 12px;">
                                        <div class="clearfix">
                                            <h4 class="pull-left" style="margin-top: 0;">Update log</h4>
                                            <div class="pull-right">
                                                <button type="button" class="btn btn-mini" onclick="viewLog();"><i class="icon-list-alt"></i> Show last 30 lines</button>
                                            </div>
                                        </div>
                                        <textarea rows="9" wrap="off" readonly class="span12"
                                                  style="resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_get_x("", "adblock_update_log"); %></textarea>
                                    </div>

                                    <div class="well" style="margin: 0 10px 10px; padding: 12px;">
                                        <div class="clearfix">
                                            <h4 class="pull-left" style="margin-top: 0;">Blocked queries</h4>
                                            <div class="pull-right">
                                                <button type="button" class="btn btn-mini" onclick="refreshStats();"><i class="icon-refresh"></i> Refresh stats</button>
                                            </div>
                                        </div>
                                        <p class="muted">Counts are collected every minute from the resolver log. The table is saved to storage every 15 minutes.</p>
                                        <textarea rows="12" wrap="off" readonly class="span12"
                                                  style="resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_get_x("", "adblock_stats"); %></textarea>
                                    </div>

                                    <div class="well" style="margin: 0 10px 10px; padding: 12px;">
                                        <h4 style="margin-top: 0;">Settings export</h4>
                                        <button type="button" class="btn" onclick="exportSettings();"><i class="icon-download-alt"></i> Export</button>
                                        <textarea rows="8" wrap="off" readonly class="span12"
                                                  style="margin-top: 6px; resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_get_x("", "adblock_export"); %></textarea>

                                        <h4 style="margin-top: 16px;">Settings import</h4>
                                        <textarea rows="8" wrap="off" spellcheck="false" class="span12"
                                                  name="adblock_import" placeholder="Paste an exported settings block here"
                                                  style="resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_get_x("", "adblock_import"); %></textarea>
                                        <button type="button" class="btn" style="margin-top: 6px;" onclick="importSettings();"><i class="icon-upload"></i> Import</button>
                                        <span class="help-inline">Import saves settings; press Update list on the Adblock page to apply.</span>
                                    </div>

                                    <div class="row-fluid" style="margin: 0 0 20px; padding: 0 10px; box-sizing: border-box;">
                                        <div class="span12" style="text-align: center;">
                                            <a class="btn" href="Advanced_Adblock_Content.asp"><i class="icon-arrow-left"></i> Back to Adblock settings</a>
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
