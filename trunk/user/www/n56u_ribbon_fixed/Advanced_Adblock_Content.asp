<!DOCTYPE html>
<html>
<head>
<title><#Web_Title#> - Adblock</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">

<link rel="shortcut icon" href="images/favicon.ico">
<link rel="icon" href="images/favicon.png">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/bootstrap.min.css">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/main.css">

<script type="text/javascript" src="/jquery.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script>
<% login_state_hook(); %>

var presetMask = parseInt('<% nvram_get("adblock_presets"); %>');
if (isNaN(presetMask)) presetMask = 127;

function initial() {
    show_banner(1);
    show_menu(5, 9, 4);
    show_footer();
    initPresets();
    if (!document.form.adblock_update_hour.value)
        document.form.adblock_update_hour.value = 4;
    if (!document.form.adblock_update_min.value)
        document.form.adblock_update_min.value = 15;
    fixStatusText();
    updateStatusBadge();
    updateScheduleHint();
}

function initPresets() {
    var boxes = document.getElementsByName('preset');
    for (var i = 0; i < boxes.length; i++) {
        boxes[i].checked = (presetMask & (1 << parseInt(boxes[i].value))) != 0;
    }
    updateMask();
}

function updateMask() {
    var mask = 0;
    var boxes = document.getElementsByName('preset');
    for (var i = 0; i < boxes.length; i++) {
        if (boxes[i].checked)
            mask |= (1 << parseInt(boxes[i].value));
    }
    document.form.adblock_presets.value = mask;
    updatePresetHint();
}

function setPresets(mask) {
    var boxes = document.getElementsByName('preset');
    for (var i = 0; i < boxes.length; i++)
        boxes[i].checked = (mask & (1 << parseInt(boxes[i].value))) != 0;
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
    if (!hint)
        return;
    var n = 0;
    var boxes = document.getElementsByName('preset');
    for (var i = 0; i < boxes.length; i++)
        if (boxes[i].checked) n++;
    if (n === 0)
        hint.innerHTML = 'No presets selected - extra sources and custom domains only.';
    else
        hint.innerHTML = n + ' preset source' + (n === 1 ? '' : 's') + ' selected.';
}

function fixStatusText() {
    var st = document.getElementById('statusText');
    if (st && !st.innerHTML.trim())
        st.innerHTML = 'not updated yet';
    var lu = document.getElementById('lastUpdate');
    if (lu && !lu.innerHTML.trim())
        lu.innerHTML = 'never';
}

function adblockPad2(n) {
    return (n < 10 ? '0' : '') + n;
}

function getScheduleValues() {
    var h = parseInt(document.form.adblock_update_hour.value, 10);
    var m = parseInt(document.form.adblock_update_min.value, 10);
    if (isNaN(h) || h < 0 || h > 23) h = 4;
    if (isNaN(m) || m < 0 || m > 59) m = 15;
    return { h: h, m: m };
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
    } else if (status.indexOf('fail') >= 0 || status.indexOf('error') >= 0) {
        cls = 'label-important';
        text = 'Error';
    } else if (status.indexOf('updating') >= 0) {
        cls = 'label-warning';
        text = 'Updating';
    }
    badge.className = 'label ' + cls;
    badge.innerHTML = text;
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
        longText = 'Automatic updates are disabled. Use Update now to refresh manually.';
    }

    var top = document.getElementById('scheduleHintTop');
    var inline = document.getElementById('scheduleHintInline');
    var short = document.getElementById('scheduleShort');
    if (short) short.innerHTML = shortText;
    if (top) top.innerHTML = longText;
    if (inline) inline.innerHTML = longText;
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

function submitAction(script) {
    if (!login_safe())
        return;
    updateMask();
    showLoading();
    document.form.action_mode.value = " Apply ";
    document.form.action_script.value = script;
    document.form.current_page.value = "/Advanced_Adblock_Content.asp";
    document.form.next_page.value = "";
    document.form.submit();
}

function applyRule() {
    if (!validateSchedule())
        return;
    submitAction('adblock_apply.sh');
}

function updateNow() {
    submitAction('adblock_update.sh');
}

function resetDefaults() {
    submitAction('adblock_reset.sh');
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

function exportSettings() {
    submitAction('adblock_export.sh');
}

function importSettings() {
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

    <iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>
    <form method="post" name="form" id="ruleForm" action="/start_apply.htm" target="hidden_frame">

    <input type="hidden" name="current_page" value="Advanced_Adblock_Content.asp">
    <input type="hidden" name="next_page" value="">
    <input type="hidden" name="next_host" value="">
    <input type="hidden" name="sid_list" value="General;">
    <input type="hidden" name="group_id" value="">
    <input type="hidden" name="action_mode" value="">
    <input type="hidden" name="action_script" value="">
    <input type="hidden" name="adblock_presets" value="">

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
                                        AP mode uses a separate resolver; router mode integrates with the system dnsmasq.
                                        The list is downloaded on first update; progress is shown in the update log below.
                                    </div>

                                    <div class="row-fluid" style="margin: 0 10px 10px;">
                                        <div class="span6">
                                            <div class="well" style="margin-bottom: 0; padding: 12px;">
                                                <div class="clearfix">
                                                    <span class="pull-left"><strong>Status</strong></span>
                                                    <span class="pull-right">
                                                        <button type="button" class="btn btn-mini" style="margin-right: 6px;" onclick="location.reload();"><i class="icon-refresh"></i> Refresh</button>
                                                        <span id="statusBadge" class="label">Status</span>
                                                    </span>
                                                </div>
                                                <div class="muted" style="margin-top: 8px;">
                                                    Last successful update: <span id="lastUpdate"><% nvram_dump("adblock_last_success","never"); %></span>
                                                </div>
                                                <div class="muted" id="statusText"><% nvram_dump("adblock_status","not updated yet"); %></div>
                                            </div>
                                        </div>
                                        <div class="span6">
                                            <div class="well" style="margin-bottom: 0; padding: 12px;">
                                                <div class="clearfix">
                                                    <span class="pull-left"><strong>Schedule</strong></span>
                                                    <span class="pull-right muted" id="scheduleShort"></span>
                                                </div>
                                                <div class="muted" style="margin-top: 8px;" id="scheduleHintTop"></div>
                                            </div>
                                        </div>
                                    </div>

                                    <div class="well" style="margin: 0 10px 10px; padding: 12px;">
                                        <h4 style="margin-top: 0;">General</h4>
                                        <table class="table table-condensed" style="margin-bottom: 0;">
                                            <tr>
                                                <th width="35%">Adblock enabled</th>
                                                <td>
                                                    <select name="adblock_enable" class="input" onchange="updateStatusBadge();">
                                                        <option value="1" <% nvram_match("adblock_enable","1","selected"); %>>Enabled</option>
                                                        <option value="0" <% nvram_match("adblock_enable","0","selected"); %>>Disabled</option>
                                                    </select>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>Update interval</th>
                                                <td>
                                                    <select name="adblock_interval" class="input" onchange="updateScheduleHint();">
                                                        <option value="weekly" <% nvram_match("adblock_interval","weekly","selected"); %>>Weekly</option>
                                                        <option value="daily" <% nvram_match("adblock_interval","daily","selected"); %>>Daily</option>
                                                        <option value="12h" <% nvram_match("adblock_interval","12h","selected"); %>>Every 12 hours</option>
                                                        <option value="6h" <% nvram_match("adblock_interval","6h","selected"); %>>Every 6 hours</option>
                                                        <option value="off" <% nvram_match("adblock_interval","off","selected"); %>>Disabled</option>
                                                    </select>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>Update time</th>
                                                <td>
                                                    <input type="text" class="input-mini" name="adblock_update_hour" maxlength="2"
                                                           value="<% nvram_get("adblock_update_hour"); %>"
                                                           onchange="updateScheduleHint();" onkeyup="updateScheduleHint();"
                                                           onKeyPress="return is_number(this,event);" />
                                                    <span class="help-inline">:</span>
                                                    <input type="text" class="input-mini" name="adblock_update_min" maxlength="2"
                                                           value="<% nvram_get("adblock_update_min"); %>"
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
                                            <h4 class="pull-left" style="margin-top: 0;">Sources</h4>
                                            <div class="pull-right">
                                                <button type="button" class="btn btn-mini" onclick="defaultPresets();">Defaults</button>
                                                <button type="button" class="btn btn-mini" onclick="clearPresets();">Clear all</button>
                                            </div>
                                        </div>
                                        <p class="muted">Preset lists are downloaded during an update. Select the lists you want to use, or clear all to use only extra sources and custom domains.</p>
                                        <div class="help-block" id="presetHint" style="margin-bottom: 10px;"></div>
                                        <div class="row-fluid">
                                            <div class="span6">
                                                <label class="checkbox"><input type="checkbox" name="preset" value="0" onchange="updateMask()"> AnudeepND</label>
                                                <label class="checkbox"><input type="checkbox" name="preset" value="1" onchange="updateMask()"> AdAway official</label>
                                                <label class="checkbox"><input type="checkbox" name="preset" value="2" onchange="updateMask()"> StevenBlack Unified</label>
                                                <label class="checkbox"><input type="checkbox" name="preset" value="3" onchange="updateMask()"> Pete Lowe</label>
                                                <label class="checkbox"><input type="checkbox" name="preset" value="4" onchange="updateMask()"> EasyList ad servers</label>
                                                <label class="checkbox"><input type="checkbox" name="preset" value="5" onchange="updateMask()"> EasyPrivacy</label>
                                                <label class="checkbox"><input type="checkbox" name="preset" value="6" onchange="updateMask()"> EasyList Hebrew</label>
                                                <label class="checkbox"><input type="checkbox" name="preset" value="7" onchange="updateMask()"> EasyList Germany + EasyList</label>
                                                <label class="checkbox"><input type="checkbox" name="preset" value="8" onchange="updateMask()"> Liste FR + EasyList</label>
                                                <label class="checkbox"><input type="checkbox" name="preset" value="9" onchange="updateMask()"> EasyList Italy + EasyList</label>
                                            </div>
                                            <div class="span6">
                                                <label class="checkbox"><input type="checkbox" name="preset" value="10" onchange="updateMask()"> EasyList Dutch + EasyList</label>
                                                <label class="checkbox"><input type="checkbox" name="preset" value="11" onchange="updateMask()"> EasyList China + EasyList</label>
                                                <label class="checkbox"><input type="checkbox" name="preset" value="12" onchange="updateMask()"> EasyList Spanish + EasyList</label>
                                                <label class="checkbox"><input type="checkbox" name="preset" value="13" onchange="updateMask()"> EasyList Polish + EasyList</label>
                                                <label class="checkbox"><input type="checkbox" name="preset" value="14" onchange="updateMask()"> EasyList Portuguese + EasyList</label>
                                                <label class="checkbox"><input type="checkbox" name="preset" value="15" onchange="updateMask()"> RU AdList + EasyList</label>
                                                <label class="checkbox"><input type="checkbox" name="preset" value="16" onchange="updateMask()"> KoreanList + EasyList</label>
                                                <label class="checkbox"><input type="checkbox" name="preset" value="17" onchange="updateMask()"> IndianList + EasyList</label>
                                                <label class="checkbox"><input type="checkbox" name="preset" value="18" onchange="updateMask()"> Nordic Filters + EasyList</label>
                                            </div>
                                        </div>

                                        <table class="table table-condensed">
                                            <tr>
                                                <th>Extra source URLs <span class="muted">(one per line)</span></th>
                                            </tr>
                                            <tr>
                                                <td>
                                                    <textarea rows="4" wrap="off" spellcheck="false" maxlength="8192" class="span12"
                                                              name="adblock_extra_sources" placeholder="https://example.com/hosts.txt"
                                                              style="resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_extra_sources",""); %></textarea>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>Per-source status <span class="muted">(last update)</span></th>
                                            </tr>
                                            <tr>
                                                <td>
                                                    <textarea rows="7" wrap="off" readonly class="span12"
                                                              style="resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_source_status",""); %></textarea>
                                                </td>
                                            </tr>
                                        </table>
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
                                                              style="resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_custom",""); %></textarea>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>Allowed domains <span class="muted">(never block, one per line)</span></th>
                                            </tr>
                                            <tr>
                                                <td>
                                                    <textarea rows="5" wrap="off" spellcheck="false" maxlength="16384" class="span12"
                                                              name="adblock_allow" placeholder="example.com"
                                                              style="resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_allow",""); %></textarea>
                                                </td>
                                            </tr>
                                        </table>
                                    </div>

                                    <div class="row-fluid" style="margin: 0 10px 20px;">
                                        <div class="span12" style="text-align: center;">
                                            <button type="button" class="btn btn-primary" onclick="applyRule();"><i class="icon-ok icon-white"></i> Apply</button>
                                            <button type="button" class="btn" onclick="updateNow();"><i class="icon-refresh"></i> Update now</button>
                                            <button type="button" class="btn" onclick="resetDefaults();"><i class="icon-repeat"></i> Restore defaults</button>
                                        </div>
                                    </div>

                                    <h3 style="margin-left: 10px;">Diagnostics</h3>
                                    <div class="well" style="margin: 0 10px 10px; padding: 12px;">
                                        <table class="table table-condensed" style="margin-bottom: 0;">
                                            <tr>
                                                <th width="30%">Test domain</th>
                                                <td>
                                                    <input type="text" class="input" name="adblock_test_domain"
                                                           value="<% nvram_get("adblock_test_domain"); %>" size="32" placeholder="example.com">
                                                    <button type="button" class="btn" onclick="testDomain();"><i class="icon-search"></i> Test</button>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>Test result</th>
                                                <td>
                                                    <textarea rows="5" wrap="off" readonly class="span12"
                                                              style="resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_test_result",""); %></textarea>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>Update log</th>
                                                <td>
                                                    <button type="button" class="btn" onclick="viewLog();"><i class="icon-list-alt"></i> Show last 30 lines</button>
                                                    <textarea rows="6" wrap="off" readonly class="span12" style="margin-top: 6px; resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_update_log",""); %></textarea>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>Blocked queries</th>
                                                <td>
                                                    <button type="button" class="btn" onclick="refreshStats();"><i class="icon-refresh"></i> Refresh stats</button>
                                                    <textarea rows="7" wrap="off" readonly class="span12" style="margin-top: 6px; resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_stats",""); %></textarea>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>Settings export</th>
                                                <td>
                                                    <button type="button" class="btn" onclick="exportSettings();"><i class="icon-download-alt"></i> Export</button>
                                                    <textarea rows="7" wrap="off" readonly class="span12" style="margin-top: 6px; resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_export",""); %></textarea>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>Settings import</th>
                                                <td>
                                                    <textarea rows="7" wrap="off" spellcheck="false" class="span12"
                                                              name="adblock_import" placeholder="Paste an exported settings block here"
                                                              style="resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_import",""); %></textarea>
                                                    <button type="button" class="btn" style="margin-top: 6px;" onclick="importSettings();"><i class="icon-upload"></i> Import</button>
                                                </td>
                                            </tr>
                                        </table>
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
