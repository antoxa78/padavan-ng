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

function initial() {
    show_banner(1);
    show_menu(5, 9, 4);
    show_footer();
}

function applyRule() {
    if (!login_safe())
        return;
    showLoading();
    document.form.action_mode.value = " Apply ";
    document.form.action_script.value = "adblock_apply.sh";
    document.form.current_page.value = "/Advanced_Adblock_Content.asp";
    document.form.next_page.value = "";
    document.form.submit();
}

function updateNow() {
    if (!login_safe())
        return;
    showLoading();
    document.form.action_mode.value = " Apply ";
    document.form.action_script.value = "adblock_update.sh";
    document.form.current_page.value = "/Advanced_Adblock_Content.asp";
    document.form.next_page.value = "";
    document.form.submit();
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
                                                    <option value="daily" <% nvram_match("adblock_interval","daily","selected"); %>>Daily (04:15)</option>
                                                    <option value="weekly" <% nvram_match("adblock_interval","weekly","selected"); %>>Weekly (Sunday 04:15)</option>
                                                    <option value="off" <% nvram_match("adblock_interval","off","selected"); %>>Disabled</option>
                                                </select>
                                            </td>
                                        </tr>
                                        <tr>
                                            <th>Status</th>
                                            <td><% nvram_dump("adblock_status","not updated yet"); %></td>
                                        </tr>
                                    </table>

                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <tr>
                                            <th>Blocklist sources</th>
                                        </tr>
                                        <tr>
                                            <td>
                                                <textarea rows="10" wrap="off" spellcheck="false" maxlength="16384" class="span12" name="adblock_sources" style="resize:none; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_sources",""); %></textarea>
                                            </td>
                                        </tr>
                                        <tr>
                                            <th>Custom blocked domains</th>
                                        </tr>
                                        <tr>
                                            <td>
                                                <textarea rows="7" wrap="off" spellcheck="false" maxlength="16384" class="span12" name="adblock_custom" style="resize:none; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_custom",""); %></textarea>
                                            </td>
                                        </tr>
                                        <tr>
                                            <th>Allowed domains (never block)</th>
                                        </tr>
                                        <tr>
                                            <td>
                                                <textarea rows="6" wrap="off" spellcheck="false" maxlength="16384" class="span12" name="adblock_allow" style="resize:none; font-family:'Courier New'; font-size:12px;"><% nvram_dump("adblock_allow",""); %></textarea>
                                            </td>
                                        </tr>
                                    </table>

                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <tr>
                                            <td style="border: 0 none;">
                                                <center>
                                                    <input type="button" class="btn btn-primary" style="width: 180px" onclick="applyRule();" value="Apply"/>
                                                    <input type="button" class="btn" style="width: 180px" onclick="updateNow();" value="Update now"/>
                                                </center>
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
