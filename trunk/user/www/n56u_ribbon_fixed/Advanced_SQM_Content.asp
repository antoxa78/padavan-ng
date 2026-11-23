<!DOCTYPE html>
<html>
<head>
<title>RM-AC2100 Wireless Router - SQM / QoS</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="0">

<link rel="shortcut icon" href="images/favicon.ico">
<link rel="icon" href="images/favicon.png">
<link rel="stylesheet" href="/bootstrap/css/bootstrap.min.css">
<link rel="stylesheet" href="/bootstrap/css/main.css">

<script type="text/javascript" src="/jquery.js"></script>
<script type="text/javascript" src="/bootstrap/js/bootstrap.min.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script type="text/javascript" src="/client_function.js"></script>
<script>
<% login_state_hook(); %>

var ipmonitor = [<% get_static_client(); %>];
var wireless = [<% wl_auth_list(); %>];
var clients_info = getclients(1, 0);
var actionPending = false;
var actionFinished = false;
var formDirty = false;

function initial() {
    show_banner(1);
    show_menu(5, 9, 6);
    show_footer();
    buildClientPicker();
    loadSavedClients();
    fixStatus();
    updateUi();
    bindDirtyTracking();
}

function bindDirtyTracking() {
    if (!document.form)
        return;
    document.form.addEventListener('input', function() { formDirty = true; });
    document.form.addEventListener('change', function() { formDirty = true; });
}

function escapeHtml(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function isValidIPv4(ip) {
    var p = ip.split('.');
    if (p.length !== 4)
        return false;
    for (var i = 0; i < 4; i++) {
        if (!/^(0|[1-9][0-9]{0,2})$/.test(p[i]))
            return false;
        var n = parseInt(p[i], 10);
        if (n < 0 || n > 255)
            return false;
    }
    return parseInt(p[0], 10) > 0;
}

function normMbps(v) {
    var n = parseFloat(v);
    if (!isFinite(n) || n < 0)
        n = 0;
    if (n > 10000)
        n = 10000;
    return String(Math.round(n * 1000) / 1000);
}

function createCell(input) {
    var td = document.createElement('td');
    td.appendChild(input);
    return td;
}

function addClientRow(ip, up) {
    var tbody = document.getElementById('clientRows');
    if (!tbody)
        return;
    if (tbody.rows.length >= 32) {
        alert('At most 32 per-client limits are supported.');
        return;
    }

    var tr = document.createElement('tr');

    var ipInput = document.createElement('input');
    ipInput.type = 'text';
    ipInput.className = 'input-medium sqm-client-ip';
    ipInput.placeholder = '192.168.1.10';
    ipInput.value = ip || '';
    tr.appendChild(createCell(ipInput));

    var upInput = document.createElement('input');
    upInput.type = 'text';
    upInput.className = 'input-mini sqm-client-up';
    upInput.placeholder = '0';
    upInput.value = up || '';
    tr.appendChild(createCell(upInput));

    var td = document.createElement('td');
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'btn btn-mini btn-danger';
    btn.innerHTML = '<i class="icon-remove icon-white"></i>';
    btn.onclick = function() {
        tbody.removeChild(tr);
        formDirty = true;
    };
    td.appendChild(btn);
    tr.appendChild(td);

    tbody.appendChild(tr);
    formDirty = true;
}

function loadSavedClients() {
    var raw = document.getElementById('sqmClientsValue');
    if (!raw || !raw.value)
        return;
    var lines = raw.value.split(/\r?\n/);
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].replace(/^\s+|\s+$/g, '');
        if (!line)
            continue;
        var p = line.split('|');
        addClientRow(p[0] || '', p[1] || '');
    }
    formDirty = false;
}

function buildClientPicker() {
    var sel = document.getElementById('clientPicker');
    if (!sel)
        return;
    sel.options.length = 0;
    var opt = document.createElement('option');
    opt.value = '';
    opt.text = clients_info.length ? 'Select a connected client...' : 'No connected clients found';
    sel.add(opt, null);
    for (var i = 0; i < clients_info.length; i++) {
        var ip = clients_info[i][1];
        if (!ip)
            continue;
        opt = document.createElement('option');
        opt.value = ip;
        opt.text = ip + '  ' + (clients_info[i][0] || '*') + '  [' + (clients_info[i][2] || '') + ']';
        sel.add(opt, null);
    }
}

function addSelectedClient() {
    var sel = document.getElementById('clientPicker');
    if (!sel || !sel.value) {
        alert('Select a connected client first.');
        return;
    }
    addClientRow(sel.value, '');
    sel.value = '';
}

function collectClients() {
    var tbody = document.getElementById('clientRows');
    var rows = tbody ? tbody.rows : [];
    var out = [];
    var seen = {};

    for (var i = 0; i < rows.length; i++) {
        var ipEl = rows[i].querySelector('.sqm-client-ip');
        var upEl = rows[i].querySelector('.sqm-client-up');
        if (!ipEl || !upEl)
            continue;

        var ip = ipEl.value.replace(/^\s+|\s+$/g, '');
        var up = upEl.value.replace(/^\s+|\s+$/g, '');

        if (!ip && !up)
            continue;
        if (!ip) {
            alert('A per-client row has a limit but no IP address.');
            ipEl.focus();
            return false;
        }
        if (!isValidIPv4(ip)) {
            alert('Invalid IPv4 address: ' + ip);
            ipEl.focus();
            return false;
        }
        if (seen[ip]) {
            alert('Duplicate client IP: ' + ip);
            ipEl.focus();
            return false;
        }
        if (up && !/^[0-9]+(\.[0-9]+)?$/.test(up)) {
            alert('The upload limit must be a number in Mbit/s: ' + ip);
            return false;
        }
        var u = parseFloat(up || '0');
        if (!isFinite(u) || u < 0 || u > 10000) {
            alert('The upload limit must be between 0 and 10000 Mbit/s: ' + ip);
            return false;
        }
        seen[ip] = true;
        out.push(ip + '|' + normMbps(up || '0'));
    }

    document.getElementById('sqmClientsValue').value = out.join('\n');
    return true;
}

function validateSettings() {
    var enable = document.form.sqm_enable.value;
    var upRaw = document.form.sqm_upload_mbps.value.replace(/^\s+|\s+$/g, '') || '0';
    var downRaw = document.form.sqm_download_mbps.value.replace(/^\s+|\s+$/g, '') || '0';
    var overheadRaw = document.form.sqm_overhead.value.replace(/^\s+|\s+$/g, '') || '95';
    var dlShape = document.form.sqm_download_shape.value;

    if (!/^[0-9]+(\.[0-9]+)?$/.test(upRaw) || !/^[0-9]+(\.[0-9]+)?$/.test(downRaw)) {
        alert('WAN speeds must be numbers in Mbit/s.');
        return false;
    }
    var up = parseFloat(upRaw);
    var down = parseFloat(downRaw);
    var overhead = parseInt(overheadRaw, 10);

    if (!isFinite(up) || !isFinite(down) || up < 0 || down < 0 || up > 10000 || down > 10000) {
        alert('WAN speeds must be between 0 and 10000 Mbit/s.');
        return false;
    }
    if (enable === '1' && up <= 0 && (dlShape !== '1' || down <= 0)) {
        alert('Set the measured WAN upload speed, or enable download shaping with a download speed.');
        return false;
    }
    if (!/^[0-9]+$/.test(overheadRaw) || !isFinite(overhead) || overhead < 50 || overhead > 100) {
        alert('The shaping percentage must be between 50 and 100.');
        return false;
    }
    document.form.sqm_upload_mbps.value = normMbps(upRaw);
    document.form.sqm_download_mbps.value = normMbps(downRaw);
    document.form.sqm_overhead.value = String(overhead);
    return true;
}

function submitRaw(script) {
    if (!login_safe())
        return;
    showLoading();
    document.form.action_mode.value = ' Apply ';
    document.form.action_script.value = script;
    document.form.current_page.value = 'Advanced_SQM_Content.asp';
    document.form.next_page.value = '';
    actionPending = true;
    actionFinished = false;
    document.form.submit();
}

function submitAction(script) {
    if (!collectClients() || !validateSettings())
        return;
    submitRaw(script);
}

function saveSettings() {
    submitAction('sqm_save.sh');
}

function stopSqm() {
    if (!confirm('Disable SQM and remove all shaping rules?'))
        return;
    document.form.sqm_enable.value = '0';
    // Keep the saved per-client list; do not require the edited rows to be valid.
    submitRaw('sqm_save.sh');
}

function refreshPage() {
    if (formDirty && !confirm('Discard unsaved changes?'))
        return;
    location.reload();
}

function actionComplete() {
    if (actionFinished || !actionPending)
        return;
    actionFinished = true;
    actionPending = false;
    formDirty = false;
    setTimeout(function() { location.reload(); }, 1500);
}

function updateUi() {
    var enable = document.form.sqm_enable.value === '1';
    var box = document.getElementById('sqmSettings');
    if (box) {
        box.style.opacity = enable ? '1' : '0.55';
    }
}

function fixStatus() {
    var state = document.getElementById('sqmState');
    if (state && !state.innerHTML.trim())
        state.innerHTML = 'disabled';
    var summary = document.getElementById('sqmSummary');
    if (summary && !summary.innerHTML.trim())
        summary.innerHTML = 'SQM is disabled';
    var applied = document.getElementById('sqmApplied');
    if (applied && !applied.innerHTML.trim())
        applied.innerHTML = 'never';
    var speed = document.getElementById('sqmLinkSpeed');
    if (speed) {
        var s = speed.innerHTML.trim();
        if (!s || s === 'unknown' || s === '-1') {
            speed.innerHTML = 'unknown';
            var unit = document.getElementById('sqmLinkSpeedUnit');
            if (unit)
                unit.style.display = 'none';
        }
    }
    var rules = document.getElementById('sqmRules');
    if (rules && !rules.innerHTML.trim())
        rules.innerHTML = '0';
    var err = document.getElementById('sqmError');
    if (err && !err.innerHTML.trim()) {
        var row = document.getElementById('sqmErrorRow');
        if (row)
            row.style.display = 'none';
    }

    var hwNat = document.getElementById('sqmHwNat');
    if (hwNat) {
        var mode = '<% nvram_get_x("", "hw_nat_mode"); %>';
        if (mode === '2') {
            hwNat.innerHTML = 'Disabled (best for SQM)';
        } else {
            hwNat.innerHTML = 'Enabled &mdash; offloaded flows may bypass SQM. ' +
                'Set <strong>Advanced &rarr; WAN &rarr; Hardware NAT</strong> to ' +
                '<strong>Disable (Slow)</strong> for full shaping.';
        }
    }
}
</script>
</head>

<body onload="initial();" onUnLoad="return unload_body();">

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
    <input type="hidden" name="current_page" value="Advanced_SQM_Content.asp">
    <input type="hidden" name="next_page" value="">
    <input type="hidden" name="next_host" value="">
    <input type="hidden" name="sid_list" value="General;">
    <input type="hidden" name="group_id" value="">
    <input type="hidden" name="action_mode" value="">
    <input type="hidden" name="action_script" value="">

    <div class="container-fluid">
        <div class="row-fluid">
            <div class="span3">
                <div class="well sidebar-nav side_nav" style="padding: 0px;">
                    <ul id="mainMenu" class="clearfix"></ul>
                    <ul class="clearfix">
                        <li><div id="subMenu" class="accordion"></div></li>
                    </ul>
                </div>
            </div>

            <div class="span9">
                <div class="row-fluid">
                    <div class="span12">
                        <div class="box well grad_colour_dark_blue">
                            <h2 class="box_head round_top"><i class="icon-tasks"></i> SQM / QoS</h2>
                            <div class="round_bottom">
                                <div class="row-fluid">
                                    <div id="tabMenu" class="submenuBlock"></div>
                                    <div class="span12">
                                        <div class="alert alert-info">
                                            <strong>SQM keeps latency low when the connection is busy.</strong>
                                            It does not increase download speed or audio bitrate. Pick the highest
                                            quality in your music app; SQM prevents stutter when downloads, updates or
                                            other devices compete for the line.
                                        </div>
                                        <div class="alert">
                                            Set the speeds to about <strong>90&ndash;95%</strong> of a speed test result.
                                            Download shaping uses the IFB device and needs more CPU. On the MT7621,
                                            a few hundred Mbit/s is a realistic shaping ceiling. If shaping has no
                                            effect, disable <strong>Hardware NAT</strong> under <strong>Advanced &rarr; WAN</strong>.
                                        </div>

                                        <table class="table table-bordered table-striped">
                                            <tr>
                                                <th width="35%">Enable SQM / QoS</th>
                                                <td>
                                                    <select name="sqm_enable" id="sqmEnable" class="input-small" onchange="updateUi();">
                                                        <option value="0" <% nvram_match_x("", "sqm_enable", "0", "selected"); %>>Disabled</option>
                                                        <option value="1" <% nvram_match_x("", "sqm_enable", "1", "selected"); %>>Enabled</option>
                                                    </select>
                                                </td>
                                            </tr>
                                        </table>

                                        <div id="sqmSettings">
                                            <table class="table table-bordered table-striped">
                                                <tr>
                                                    <th width="35%">WAN upload speed (Mbit/s)</th>
                                                    <td>
                                                        <input type="text" name="sqm_upload_mbps" class="input-small" value="<% nvram_get_x("", "sqm_upload_mbps"); %>" placeholder="e.g. 100">
                                                        <span class="help-inline">Measured upload speed of your internet connection.</span>
                                                    </td>
                                                </tr>
                                                <tr>
                                                    <th>WAN download speed (Mbit/s)</th>
                                                    <td>
                                                        <input type="text" name="sqm_download_mbps" class="input-small" value="<% nvram_get_x("", "sqm_download_mbps"); %>" placeholder="e.g. 500">
                                                        <span class="help-inline">Leave 0 to shape upload only.</span>
                                                    </td>
                                                </tr>
                                                <tr>
                                                    <th>Shaping percentage</th>
                                                    <td>
                                                        <input type="text" name="sqm_overhead" class="input-mini" value="<% nvram_get_x("", "sqm_overhead"); %>" placeholder="95">
                                                        <span class="help-inline">% of the measured speed. 90&ndash;95 is recommended.</span>
                                                    </td>
                                                </tr>
                                                <tr>
                                                    <th>Download shaping</th>
                                                    <td>
                                                        <select name="sqm_download_shape" class="input-small">
                                                            <option value="1" <% nvram_match_x("", "sqm_download_shape", "1", "selected"); %>>Enabled (recommended)</option>
                                                            <option value="0" <% nvram_match_x("", "sqm_download_shape", "0", "selected"); %>>Disabled</option>
                                                        </select>
                                                        <span class="help-inline">Upload shaping has the biggest effect on latency and uses little CPU.</span>
                                                    </td>
                                                </tr>
                                            </table>

                                            <h3>Per-client upload limits</h3>
                                            <p class="help-block">
                                                Optional upload caps in Mbit/s. 0 means no limit. The WAN upload
                                                speed must be set for these to take effect. Use Static DHCP so a
                                                client keeps the same address. Download traffic is shared and kept
                                                fair by <code>fq_codel</code>; per-client download caps are not
                                                available in this version.
                                            </p>
                                            <div class="form-inline" style="margin-bottom: 8px;">
                                                <select id="clientPicker" class="input-xlarge"></select>
                                                <button type="button" class="btn" onclick="addSelectedClient();"><i class="icon-plus"></i> Add connected client</button>
                                                <button type="button" class="btn" onclick="addClientRow('', '');"><i class="icon-plus"></i> Add empty row</button>
                                            </div>
                                            <table class="table table-bordered table-striped">
                                                <thead>
                                                    <tr>
                                                        <th>Client IP</th>
                                                        <th>Upload limit (Mbit/s)</th>
                                                        <th width="40"></th>
                                                    </tr>
                                                </thead>
                                                <tbody id="clientRows"></tbody>
                                            </table>
                                            <textarea name="sqm_clients" id="sqmClientsValue" style="display:none;"><% nvram_get_x("", "sqm_clients"); %></textarea>
                                        </div>

                                        <div class="form-actions">
                                            <button type="button" class="btn btn-primary" onclick="saveSettings();"><i class="icon-ok icon-white"></i> Save &amp; apply</button>
                                            <button type="button" class="btn" onclick="refreshPage();"><i class="icon-refresh"></i> Refresh</button>
                                            <button type="button" class="btn btn-danger" onclick="stopSqm();"><i class="icon-stop icon-white"></i> Disable</button>
                                        </div>

                                        <h3>Status</h3>
                                        <table class="table table-bordered">
                                            <tr><th width="35%">State</th><td><span id="sqmState"><% nvram_get_x("", "sqm_status"); %></span></td></tr>
                                            <tr><th>Summary</th><td><span id="sqmSummary"><% nvram_get_x("", "sqm_summary"); %></span></td></tr>
                                            <tr><th>Last applied</th><td><span id="sqmApplied"><% nvram_get_x("", "sqm_applied"); %></span></td></tr>
                                            <tr><th>WAN link speed</th><td><span id="sqmLinkSpeed"><% nvram_get_x("", "sqm_link_speed"); %></span><span id="sqmLinkSpeedUnit"> Mbit/s</span></td></tr>
                                            <tr><th>Hardware NAT offload</th><td><span id="sqmHwNat">checking...</span></td></tr>
                                            <tr><th>Active rules</th><td><span id="sqmRules"><% nvram_get_x("", "sqm_rule_count"); %></span></td></tr>
                                            <tr id="sqmErrorRow"><th>Last error</th><td><span id="sqmError"><% nvram_get_x("", "sqm_last_error"); %></span></td></tr>
                                        </table>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <div id="footer"></div>
    </div>
    </form>
</div>
</body>
</html>
