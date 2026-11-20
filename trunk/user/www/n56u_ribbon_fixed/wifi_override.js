/* Temporary Wi-Fi schedule override, shared by the 2.4 GHz and 5 GHz pages. */
var wifiOverrideUntil = 0;
var wifiOverridePage = 'Advanced_Wireless_Content.asp';

function wifiOverrideTimeText() {
    var d = new Date(wifiOverrideUntil * 1000);
    var days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    function p2(n) { return (n < 10 ? '0' : '') + n; }
    return days[d.getDay()] + ' ' + d.getDate() + '/' + (d.getMonth() + 1) +
           ' ' + p2(d.getHours()) + ':' + p2(d.getMinutes());
}

function updateWifiOverrideStatus() {
    var el = document.getElementById('wifiOverrideStatus');
    if (!el)
        return;
    var now = Math.floor(Date.now() / 1000);
    if (wifiOverrideUntil > now) {
        el.innerHTML = '<span class="label label-warning">Override active</span> ' +
                       'Wi-Fi stays on until <strong>' + wifiOverrideTimeText() + '</strong>.';
    } else {
        el.innerHTML = 'No temporary override. Wi-Fi follows the schedule above.';
    }
}

function setWifiOverride(minutes) {
    if (typeof minutes === 'undefined') {
        var sel = document.getElementById('wifi_override_minutes');
        minutes = sel ? parseInt(sel.value, 10) : 60;
    }
    if (isNaN(minutes) || minutes < 0)
        minutes = 60;
    if (!login_safe())
        return;
    if (minutes === 0 && !confirm('Cancel the temporary Wi-Fi override?'))
        return;
    if (!window.fetch || !window.URLSearchParams) {
        alert('This browser cannot update the override. Please use a current browser.');
        return;
    }
    var body = new URLSearchParams();
    body.append('action_mode', ' Apply ');
    body.append('action_script', 'wifi_sched_override.sh');
    body.append('current_page', wifiOverridePage);
    body.append('next_page', '');
    body.append('sid_list', 'General;');
    body.append('wifi_sched_override_minutes', String(minutes));
    showLoading();
    fetch('/start_apply.htm', {
        method: 'POST',
        body: body,
        credentials: 'same-origin'
    }).then(function(r) {
        if (!r.ok)
            throw new Error('HTTP ' + r.status);
        location.reload();
    }).catch(function() {
        hideLoading();
        alert('Could not update the Wi-Fi override.');
    });
}
