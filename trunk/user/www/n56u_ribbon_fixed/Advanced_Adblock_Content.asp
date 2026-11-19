<!DOCTYPE html>
<html>
<head>
<title>Adblock - Adblock</title>
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
                            <h2 class="box_head round_top">Adblock</h2>
                            <div class="round_bottom">
                                <div class="row-fluid">
                                    <div id="tabMenu" class="submenuBlock"></div>
                                    <div class="alert alert-info" style="margin: 10px;">
                                        DNS blocklist for clients connected through this router/AP.
                                        AP mode uses a separate resolver; router mode integrates with the system dnsmasq.
                                        The list is downloaded on first update; check <b>/tmp/adblock-update.log</b> for progress.
                                    </div>

                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <tr>
                                            <th width="35%">Adblock enabled</th>
                                            <td>
                                                <select name="adblock_enable" class="input">
                                                    <option value="1" <% nvram_match("adblock_enable","1","selected"); %>>Enabled</option>
                                                    <option value="0" <% nvram_match("adblock_enable","0","selected"); %>>Disabled</option>
                                                </select>
                                            </td>
                                        </tr>
                                        <tr>
                                            <th>Update interval</th>
                                            <td>
                                                <select name="adblock_interval" class="input">
                                                    <option value="weekly" <% nvram_match("adblock_interval","weekly","selected"); %>>Weekly (Sunday 04:15)</option>
                                                    <option value="daily" <% nvram_match("adblock_interval","daily","selected"); %>>Daily (04:15)</option>
                                                    <option value="off" <% nvram_match("adblock_interval","off","selected"); %>>Disabled</option>
                                                </select>
                                            </td>
                                        </tr>
                                        <tr>
                                            <th>Status</th>
                                            <td><% nvram_dump("adblock_status","not updated yet"); %></td>
                                        </tr>
                                        <tr>
                                            <th>Last successful update</th>
                                            <td><% nvram_dump("adblock_last_success","never"); %></td>
                                        </tr>
                                    </table>

                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <tr>
                                            <th>Preset sources</th>
                                        </tr>
                                        <tr>
                                            <td>
                                                <label class="checkbox inline"><input type="checkbox" name="preset" value="0" onchange="updateMask()"> AnudeepND</label>
                                                <label class="checkbox inline"><input type="checkbox" name="preset" value="1" onchange="updateMask()"> AdAway official</label>
                                                <label class="checkbox inline"><input type="checkbox" name="preset" value="2" onchange="updateMask()"> StevenBlack Unified</label>
                                                <label class="checkbox inline"><input type="checkbox" name="preset" value="3" onchange="updateMask()"> Pete Lowe</label>
                                                <label class="checkbox inline"><input type="checkbox" name="preset" value="4" onchange="updateMask()"> EasyList ad servers</label>
                                                <label class="checkbox inline"><input type="checkbox" name="preset" value="5" onchange="updateMask()"> EasyPrivacy</label>
                                                <label class="checkbox inline"><input type="checkbox" name="preset" value="6" onchange="updateMask()"> EasyList Hebrew</label>
                                                <br>
                                                <label class="checkbox inline"><input type="checkbox" name="preset" value="7" onchange="updateMask()"> EasyList Germany + EasyList</label>
                                                <label class="checkbox inline"><input type="checkbox" name="preset" value="8" onchange="updateMask()"> Liste FR + EasyList</label>
                                                <label class="checkbox inline"><input type="checkbox" name="preset" value="9" onchange="updateMask()"> EasyList Italy + EasyList</label>
                                                <label class="checkbox inline"><input type="checkbox" name="preset" value="10" onchange="updateMask()"> EasyList Dutch + EasyList</label>
                                                <label class="checkbox inline"><input type="checkbox" name="preset" value="11" onchange="updateMask()"> EasyList China + EasyList</label>
                                                <label class="checkbox inline"><input type="checkbox" name="preset" value="12" onchange="updateMask()"> EasyList Spanish + EasyList</label>
                                                <label class="checkbox inline"><input type="checkbox" name="preset" value="13" onchange="updateMask()"> EasyList Polish + EasyList</label>
                                                <label class="checkbox inline"><input type="checkbox" name="preset" value="14" onchange="updateMask()"> EasyList Portuguese + EasyList</label>
                                                <label class="checkbox inline"><input type="checkbox" name="preset" value="15" onchange="updateMask()"> RU AdList + EasyList</label>
                                                <label class="checkbox inline"><input type="checkbox" name="preset" value="16" onchange="updateMask()"> KoreanList + EasyList</label>
                                                <label class="checkbox inline"><input type="checkbox" name="preset" value="17" onchange="updateMask()"> IndianList + EasyList</label>
                                                <label class="checkbox inline"><input type="checkbox" name="preset" value="18" onchange="updateMask()"> Nordic Filters + EasyList</label>
                                            </td>
                                        </tr>
                                        <tr>
                                            <th>Extra source URLs (one per line)</th>
                                        </tr>
                                        <tr>
                                            <td>
                                                <textarea rows="4" wrap="off" spellcheck="false" maxlength="8192" class="span12" name="adblock_extra_sources" style="resize:none; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_extra_sources",""); %></textarea>
                                            </td>
                                        </tr>
                                        <tr>
                                            <th>Per-source status (last update)</th>
                                        </tr>
                                        <tr>
                                            <td>
                                                <textarea rows="8" wrap="off" readonly class="span12" style="resize:none; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_source_status",""); %></textarea>
                                            </td>
                                        </tr>
                                    </table>

                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <tr>
                                            <th>Custom blocked domains</th>
                                        </tr>
                                        <tr>
                                            <td>
                                                <textarea rows="6" wrap="off" spellcheck="false" maxlength="16384" class="span12" name="adblock_custom" style="resize:none; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_custom",""); %></textarea>
                                            </td>
                                        </tr>
                                        <tr>
                                            <th>Allowed domains (never block)</th>
                                        </tr>
                                        <tr>
                                            <td>
                                                <textarea rows="5" wrap="off" spellcheck="false" maxlength="16384" class="span12" name="adblock_allow" style="resize:none; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_allow",""); %></textarea>
                                            </td>
                                        </tr>
                                    </table>

                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <tr>
                                            <td style="border: 0 none;">
                                                <center>
                                                    <input type="button" class="btn btn-primary" style="width: 150px" onclick="applyRule();" value="Apply"/>
                                                    <input type="button" class="btn" style="width: 150px" onclick="updateNow();" value="Update now"/>
                                                    <input type="button" class="btn" style="width: 150px" onclick="resetDefaults();" value="Restore defaults"/>
                                                </center>
                                            </td>
                                        </tr>
                                    </table>

                                    <h3>Diagnostics</h3>
                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <tr>
                                            <th width="35%">Test domain</th>
                                            <td>
                                                <input type="text" class="input" name="adblock_test_domain" value="<% nvram_get("adblock_test_domain"); %>" size="32">
                                                <input type="button" class="btn" onclick="testDomain();" value="Test"/>
                                            </td>
                                        </tr>
                                        <tr>
                                            <th>Test result</th>
                                            <td><textarea rows="5" wrap="off" readonly class="span12" style="resize:none; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_test_result",""); %></textarea></td>
                                        </tr>
                                        <tr>
                                            <th>Update log</th>
                                            <td>
                                                <input type="button" class="btn" onclick="viewLog();" value="Show last 30 lines"/>
                                                <textarea rows="6" wrap="off" readonly class="span12" style="resize:none; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_update_log",""); %></textarea>
                                            </td>
                                        </tr>
                                        <tr>
                                            <th>Blocked queries</th>
                                            <td>
                                                <input type="button" class="btn" onclick="refreshStats();" value="Refresh stats"/>
                                                <textarea rows="8" wrap="off" readonly class="span12" style="resize:none; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_stats",""); %></textarea>
                                            </td>
                                        </tr>
                                        <tr>
                                            <th>Settings export</th>
                                            <td>
                                                <input type="button" class="btn" onclick="exportSettings();" value="Export"/>
                                                <textarea rows="8" wrap="off" readonly class="span12" style="resize:none; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_export",""); %></textarea>
                                            </td>
                                        </tr>
                                        <tr>
                                            <th>Settings import</th>
                                            <td>
                                                <textarea rows="8" wrap="off" spellcheck="false" class="span12" name="adblock_import" style="resize:none; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_import",""); %></textarea>
                                                <input type="button" class="btn" onclick="importSettings();" value="Import"/>
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
    </form>

    <div id="footer"></div>
</div>

</body>
</html>
