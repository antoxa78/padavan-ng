<!DOCTYPE html>
<html>
<head>
<title><#Web_Title#> - WoL></title>
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
<script type="text/javascript" src="/client_function.js"></script>
<script>
var $j = jQuery.noConflict();

var ipmonitor = [<% get_static_client(); %>];
var m_dhcp = [<% get_nvram_list("LANHostConfig", "ManualDHCPList"); %>];

var staticClients = get_resolved_clients();

function initial(){
	var id_menu = 5;
	if(get_ap_mode()){
		id_menu = 4;
		if (lan_proto == '1')
			id_menu = 3;
	}

	show_banner(1);
	show_menu(5,3,id_menu);
	show_footer();
}

// Normalize "aabbccddeeff", "AA-BB-CC-DD-EE-FF" or "AA:BB:CC:DD:EE:FF"
// to "AA:BB:CC:DD:EE:FF". Returns an empty string for an invalid MAC.
function normalizeMac(mac)
{
	var raw = String(mac == null ? '' : mac).toUpperCase().replace(/[^0-9A-F]/g, '');
	if(raw.length != 12)
		return '';

	var parts = [];
	for(var i = 0; i < 12; i += 2)
		parts.push(raw.substr(i, 2));

	return parts.join(':');
}

function get_resolved_clients()
{
	var clients = new Array();
	for(var i = 0; i < ipmonitor.length; ++i) {
		clients[i] = new Array(3);
		clients[i][0] = ipmonitor[i][0];
		clients[i][1] = ipmonitor[i][1];
		clients[i][2] = ipmonitor[i][2];

		if(clients[i][2] == null || clients[i][2].length == 0)
			clients[i][2] = "*";
	}
	return clients;
}

function showWakeResult($button, ok, text)
{
	var $resp = $button.closest('td').find('div.wol_response');

	$button.hide();
	$resp.removeClass('alert-success alert-error')
	     .addClass(ok ? 'alert-success' : 'alert-error')
	     .html(text || (ok ? 'Success' : 'Error'))
	     .show();

	setTimeout(function(){
		$resp.hide();
		$button.show();
	}, 2000);
}

function sendWakeUp(mac, $button)
{
	mac = normalizeMac(mac);
	if(!mac) {
		showWakeResult($button, false, 'Invalid MAC');
		return;
	}

	$j.getJSON('/wol_action.asp', {dstmac: mac})
		.done(function(response){
			var respMac = (response != null && typeof response === 'object' && "wol_mac" in response)
			              ? normalizeMac(response.wol_mac)
			              : '';

			if(respMac == mac) {
				$j('#wol_mac').val(mac);
				showWakeResult($button, true, 'Success');
			} else {
				showWakeResult($button, false, 'Error');
			}
		})
		.fail(function(){
			showWakeResult($button, false, 'Request failed');
		});
}

function getDevices()
{
	var mergedDevices = {};
	var i, mac, name;

	for(i = 0; i < staticClients.length; i++)
	{
		mac = normalizeMac(staticClients[i][1]);
		if(!mac)
			continue;

		name = staticClients[i][2];
		mergedDevices[mac] = name ? name : '';
	}

	for(i = 0; i < m_dhcp.length; i++)
	{
		mac = normalizeMac(mac_add_delimiters(m_dhcp[i][0]));
		if(!mac)
			continue;

		name = m_dhcp[i][2];
		mergedDevices[mac] = name ? name : '';
	}

	return mergedDevices;
}

$j(document).ready(function() {
	// Format MAC entry as the user types (no external mask plugin needed).
	$j('#wol_mac').on('input change', function(){
		var raw = this.value.toUpperCase().replace(/[^0-9A-F]/g, '').substr(0, 12);
		var out = '';

		for(var i = 0; i < raw.length; i++) {
			if(i && (i % 2) == 0)
				out += ':';
			out += raw.charAt(i);
		}

		if(this.value != out)
			this.value = out;
	});

	$j('#wol_mac').keydown(function(e){
		if(e.which == 13) {
			e.preventDefault();
			$j('#wol_btn').click();
		}
	});

	var devices = getDevices();
	var countDevices = Object.keys(devices).length;
	if(countDevices > 0)
	{
		var t_body = '';

		$j.each(devices, function(mac, name){
			var btn = '<button type="button" class="btn btn-info btn_wakeup">Wake up</button><div class="wol_response alert"></div>';

			t_body += '<tr>\n';
			t_body += '  <td class="mac">'+mac+'</td>\n';
			t_body += '  <td>'+name+'</td>\n';
			t_body += '  <td>'+btn+'</td>\n';
			t_body += '</tr>\n';
		});
		$j('#wol_table').append(t_body);
	}

	// event click "Wake up"
	$j('#wol_btn, .btn_wakeup').click(function(){
		var $button = $j(this);
		var mac = $button.hasClass('btn_wakeup')
		          ? $button.closest('tr').find('.mac').text()
		          : $j('#wol_mac').val();

		sendWakeUp(mac, $button);

		return false;
	});
});
</script>
<style>
    #wol_table{
        margin-top: 20px;
    }

    #wol_table td:first-child {
        font-family: monospace;
        font-weight: bold;
    }

    .wol_response
    {
        display: none;
        float: left;
        padding: 5px 11px;
        min-width: 52px;
        height: 18px;
        text-align: center;
        border-radius: 5px;
        white-space: nowrap;
    }
</style>
</head>

<body onload="initial();">

<div class="wrapper">
    <div class="container-fluid" style="padding-right: 0px">
        <div class="row-fluid">
            <div class="span3"><center><div id="logo"></div></center></div>
            <div class="span9" >
                <div id="TopBanner"></div>
            </div>
        </div>
    </div>

    <div id="Loading" class="popup_bg"></div>

    <iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>

    <form method="post" name="form" id="ruleForm" action="/start_apply.htm" target="hidden_frame">

    <input type="hidden" name="current_page" value="Advanced_WOL_Content.asp">
    <input type="hidden" name="next_page" value="">
    <input type="hidden" name="next_host" value="">
    <input type="hidden" name="sid_list" value="LANHostConfig;">
    <input type="hidden" name="group_id" value="">
    <input type="hidden" name="action_mode" value="">
    <input type="hidden" name="action_script" value="">

    <div class="container-fluid">
        <div class="row-fluid">
            <div class="span3">
                <!--Sidebar content-->
                <!--=====Beginning of Main Menu=====-->
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
                <!--Body content-->
                <div class="row-fluid">
                    <div class="span12">
                        <div class="box well grad_colour_dark_blue">
                            <h2 class="box_head round_top"><#menu5_2#> - Wake-on-LAN</h2>
                            <div class="round_bottom">
                                <div class="row-fluid">
                                    <div id="tabMenu" class="submenuBlock"></div>

                                    <table width="100%" cellpadding="4" cellspacing="0" class="table" style="margin-top: 10px;">
                                        <tr>
                                            <th width="25%" style="border-top: 0 none; "><#MAC_Address#></th>
                                            <td width="395px" style="border-top: 0 none; ">
                                                <input style="float: left; margin-right: 5px; font-family: monospace" id="wol_mac" type="text" maxlength="17" class="span12 mac" size="15" name="wol_mac" autocomplete="off" placeholder="AA:BB:CC:DD:EE:FF" value="<% nvram_get_x("","wol_mac_last"); %>"/>
                                            </td>
                                            <td style="border-top: 0 none; ">
                                                <input type="button" id="wol_btn" class="btn btn-primary" value="Wake-up" />
                                                <div class="wol_response alert"></div>
                                            </td>
                                        </tr>
                                    </table>

                                    <table width="100%" cellpadding="4" cellspacing="0" class="table" id="wol_table">
                                        <tr>
                                            <th width="40%"><#MAC_Address#></th>
                                            <th width="40%"><#Computer_Name#></th>
                                            <th width="20%">&nbsp;</th>
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
