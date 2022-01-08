<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<!--
CakeQoS v2.1.0 released 2021-08-18
-->
<html xmlns="http://www.w3.org/1999/xhtml">
<html xmlns:v>
<head>
<meta http-equiv="X-UA-Compatible" content="IE=Edge"/>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta HTTP-EQUIV="Pragma" CONTENT="no-cache">
<meta HTTP-EQUIV="Expires" CONTENT="-1">
<link rel="shortcut icon" href="images/favicon.png">
<link rel="icon" href="images/favicon.png">
<title>ASUS Wireless Router - CakeQOS-Merlin</title>
<link rel="stylesheet" type="text/css" href="index_style.css">
<link rel="stylesheet" type="text/css" href="form_style.css">
<link rel="stylesheet" type="text/css" href="usp_style.css">
<link rel="stylesheet" type="text/css" href="device-map/device-map.css">
<link rel="stylesheet" type="text/css" href="/js/table/table.css">
<script type="text/javascript" src="/js/jquery.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/help.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script type="text/javascript" src="/validator.js"></script>
<script type="text/javascript" src="/js/table/table.js"></script>
<script language="JavaScript" type="text/javascript" src="/base64.js"></script>
<style>
thead.collapsible-jquery {
  color: white;
  padding: 0px;
  width: 100%;
  border: none;
  text-align: left;
  outline: none;
  cursor: pointer;
}
</style>
<script>
<% login_state_hook(); %>
var custom_settings = <% get_custom_settings(); %>;
const iptables_default_rules = "";
const iptables_default_rulenames = "";
var iptables_rulelist_array="";
var iptables_rulename_array="";
var iptables_temp_array=[];
var iptables_names_temp_array=[];
var qos_obw=<% nvram_get("qos_obw"); %>;
var qos_ibw=<% nvram_get("qos_ibw"); %>;
var qos_type = '<% nvram_get("qos_type"); %>';
if ('<% nvram_get("qos_enable"); %>' == 0) { // QoS disabled
	var qos_mode = 0;
} else if (qos_type == "9") { // Cake
	var qos_mode = 9;
} else if (bwdpi_support && (qos_type == "1")) { // aQoS
	var qos_mode = 2;
} else if (qos_type == "0") { // tQoS
	var qos_mode = 1;
} else if (qos_type == "2") { // BW limiter
	var qos_mode = 3;
} else { // invalid mode
	var qos_mode = 0;
}
var stat_retries = 0;

/* ATM, overhead, pmu, label */
var overhead_presets = [["1", "48", "0", "Conservative default"],
			["0", "42", "84", "Ethernet with VLAN"],
			["0", "18", "64", "Cable (DOCSIS)"],
			["0", "27", "0", "PPPoE VDSL"],
			["1", "32", "0", "RFC2684/RFC1483 Bridged LLC/Snap"],
			["1", "32", "0", "ADSL PPPoE VC/Mux"],
			["1", "40", "0", "ADSL PPPoE LLC/Snap"],
			["0", "19", "0", "VDSL Bridged/IPoE"],
			["2", "30", "0", "VDSL2 PPPoE PTM"],
			["2", "22", "0", "VDSL2 Bridged PTM"]
			];

var cake_stats_labels = {
	"threshold_rate": "Threshold Rate",
	"target_us": "Target",
	"interval_us": "Interval",
	"peak_delay_us": "Peak Delay",
	"avg_delay_us": "Average Delay",
	"base_delay_us": "Sparse Delay",
	"backlog_bytes": "Backlog",
	"sent_packets": "Packets Sent",
	"sent_bytes": "Sent",
	"way_indirect_hits": "Hash Indirect Hits",
	"way_misses": "Hash Misses",
	"way_collisions": "Hash Collisions",
	"drops": "Drops",
	"ecn_mark": "ECN Marked Packets",
	"ack_drops": "Dropped ACK Packets",
	"sparse_flows": "Sparse Flows",
	"bulk_flows": "Bulk Flows",
	"unresponsive_flows": "Unresponsive Flows",
	"max_pkt_len": "Max Packet Length",
	"flow_quantum": "Flow Quantum"
};

/* prototype function to respect user locale number formatting for fixed decimal point numbers */
Number.prototype.toLocaleFixed = function(min, max) {
	return this.toLocaleString(undefined, {
		minimumFractionDigits: min,
		maximumFractionDigits: max
	});
};

function YazHint(hintid) {
	var tag_name = document.getElementsByTagName('a');
	for (var i = 0; i < tag_name.length; i++) {
		tag_name[i].onmouseout = nd;
	}
	switch (hintid) {
		case 1:
			hinttext = "Select whether to shape traffic on the WAN or LAN interface. LAN interface allows for easier iptables manipulation.";
			break;
		case 2:
			hinttext = "CAKE can divide traffic into tins based on the Diffserv field.";
			break;
		case 3:
			hinttext = "Specify whether fairness is based on source address, destination address, individual flows, or any combination.";
			break;
		case 4:
			hinttext = "CAKE will use the conntrack NAT table to better determine real local addresses for fairness decisions.";
			break;
		case 5:
			hinttext = "Apply the wash option to clear all extra diffserv (but not ECN bits), after priority queuing has taken place.";
			break;
		case 6:
			hinttext = "Remove duplicate TCP ACKs from the flow queue since only the last ACK is needed.";
			break;
		case 7:
			hinttext = "Add any custom parameters separated by spaces. These will be appended to the end of the CAKE options and take priority over the options above. There is no validation done on these options. Use carefully!";
			break;
		default:
			hinttext = "Help text not yet defined";
	}
	return overlib(hinttext, HAUTO, VAUTO);
}

function build_overhead_presets(){
	var code = "";
	for(var i = 0; i < overhead_presets.length; i++) {
		code += '<a><div onclick="set_overhead(' + i +');">' + overhead_presets[i][3] + '</div></a>';
	}
	document.getElementById("overhead_presets_list").innerHTML += code;
	$(".ovh_pull_arrow").show();
}

function pullOverheadList(_this) {
	event.stopPropagation();
	var $element = $("#overhead_presets_list");
	var isMenuopen = $element[0].offsetWidth > 0 || $element[0].offsetHeight > 0;
	if(isMenuopen == 0) {
		$(_this).attr("src","/images/arrow-top.gif");
		$element.show();
	}
	else {
		$(_this).attr("src","/images/arrow-down.gif");
		$element.hide();
	}
}

function set_overhead(entry) {
	var framing = overhead_presets[entry][0];
	document.getElementById('qos_mpu').value = overhead_presets[entry][2];
	document.getElementById('qos_overhead').value = overhead_presets[entry][1];
	document.getElementById('qos_atm').value = framing;
	document.getElementById("ovh_pull_arrow").src = "/images/arrow-down.gif";
	document.getElementById('overhead_presets_list').style.display='none';
}

function initial() {
	SetCurrentPage();
	show_menu();
	get_config();
	build_overhead_presets();
	showhide('well_known_rules_tr',(custom_settings.cakeqos_ulrules == 1 ? 1 : 0));
	showhide('iptables_rules_block',(custom_settings.cakeqos_ulrules == 1 ? 1 : 0));
	if (qos_mode != 9){		//if Cake is not enabled
		document.getElementById('no_aqos_notice').style.display = "";
		return;
	}
	show_iptables_rules();
	well_known_rules();
	submit_refresh_status();
}

tableValidator.qosPortRange = {
	keyPress : function($obj,event) {
		var objValue = $obj.val();
		var keyPressed = event.keyCode ? event.keyCode : event.which;
		if (tableValid_isFunctionButton(event)) {
			return true;
		}
		if ((keyPressed > 47 && keyPressed < 58)) {	//0~9
			return true;
		}
		else if (keyPressed == 58 && objValue.length > 0) { // colon :
			for(var i = 0; i < objValue.length; i++) {
				var c = objValue.charAt(i);
				if (c == ':' || c == ',')
					return false;
			}
			return true;
		}
		else if (keyPressed == 33) { // exclamation !
			if(objValue.length > 0 && objValue.length < $obj[0].attributes.maxlength.value && objValue.charAt(0) != '!') { // field already has value; only allow ! as first char
				$obj.val('!' + objValue);
			}
			else if (objValue.length == 0)
				return true;
			return false;
		}
		else if (keyPressed == 44 && objValue.length > 0){ // comma ,
			for(var i = 0; i < objValue.length; i++) {
				var c = objValue.charAt(i);
				if (c == ':')
					return false;
			}
			return true;
		}
		return false;
	},
	blur : function(_$obj) {
		var eachPort = function(num, min, max) {
			if(num < min || num > max) {
				return false;
			}
			return true;
		};
		var hintMsg = "";
		var _value = _$obj.val();
		_value = $.trim(_value);
		_$obj.val(_value);

		if(_value == "") {
			if(_$obj.hasClass("valueMust"))
				hintMsg = "Fields cannot be blank.";
			else
				hintMsg = HINTPASS;
		}
		else {
			var mini = 1;
			var maxi = 65535;
			var PortRange = _value.replace(/^\!/g, "");
			var singlerangere = new RegExp("^([0-9]{1,5})\:([0-9]{1,5})$", "gi");
			var multiportre = new RegExp("^([0-9]{1,5})(\,[0-9]{1,5})+$", "gi");
			if(singlerangere.test(PortRange)) {  // single port range
				if(parseInt(RegExp.$1) >= parseInt(RegExp.$2)) {
					hintMsg = _value + " is not a valid port range!";
				}
				else{
					if(!eachPort(RegExp.$1, mini, maxi) || !eachPort(RegExp.$2, mini, maxi)) {
						hintMsg = "Please enter a value between " + mini + " to " + maxi;
					}
					else
						hintMsg =  HINTPASS;
					}
			}
			else if (multiportre.test(PortRange)) {
				var split = PortRange.split(",");
				for (var i = 0; i < split.length; i++) {
					if(!eachPort(split[i], mini, maxi)){
						hintMsg = "Please enter a value between " + mini + " to " + maxi;
					}
					else
						hintMsg =  HINTPASS;
				}
			}
			else {
				if(!tableValid_range(PortRange, mini, maxi)) {
					hintMsg = "Please enter a value between " + mini + " to " + maxi;
				}
				else
					hintMsg =  HINTPASS;
			}
		}
		if(_$obj.next().closest(".hint").length) {
			_$obj.next().closest(".hint").remove();
		}
		if(hintMsg != HINTPASS) {
			var $hintHtml = $('<div>');
			$hintHtml.addClass("hint");
			$hintHtml.html(hintMsg);
			_$obj.after($hintHtml);
			_$obj.focus();
			return false;
		}
		return true;
	}
};

tableValidator.qosIPCIDR = { // only IP or IP plus netmask
	keyPress : function($obj,event) {
		var objValue = $obj.val();
		var keyPressed = event.keyCode ? event.keyCode : event.which;
		if (tableValid_isFunctionButton(event)) {
			return true;
		}
		var i,j;
		if((keyPressed > 47 && keyPressed < 58)){
			j = 0;
			for(i = 0; i < objValue.length; i++){
				if(objValue.charAt(i) == '.'){
					j++;
				}
			}
			if(j < 3 && i >= 3){
				if(objValue.charAt(i-3) != '!' && objValue.charAt(i-3) != '.' && objValue.charAt(i-2) != '.' && objValue.charAt(i-1) != '.'){
					$obj.val(objValue + '.');
				}
			}
			return true;
		}
		else if(keyPressed == 46){
			j = 0;
			for(i = 0; i < objValue.length; i++){
				if(objValue.charAt(i) == '.'){
					j++;
				}
			}
			if(objValue.charAt(i-1) == '.' || j == 3){
				return false;
			}
			return true;
		}
		else if(keyPressed == 47){
			j = 0;
			for(i = 0; i < objValue.length; i++){
				if(objValue.charAt(i) == '.'){
					j++;
				}
			}
			if( j < 3){
				return false;
			}
			return true;
		}
		else if (keyPressed == 33) { // exclamation !
			if(objValue.length > 0 && objValue.length < $obj[0].attributes.maxlength.value && objValue.charAt(0) != '!') { // field already has value; only allow ! as first char
				$obj.val('!' + objValue);
			}
			else if (objValue.length == 0)
				return true;
			return false;
		}
		return false;
	},
	blur : function(_$obj) {
		var hintMsg = "";
		var _value = _$obj.val();
		_value = $.trim(_value);
		_value = _value.toLowerCase();
		_$obj.val(_value);
		var _firstChar = _value.charAt(0);
		_value = _value.replace(/^\!/g, "");
		if(_value == "") {
			if(_$obj.hasClass("valueMust"))
				hintMsg = "Fields cannot be blank.";
			else
				hintMsg = HINTPASS;
		}
		else {
			var startIPAddr = tableValid_ipAddrToIPDecimal("0.0.0.0");
			var endIPAddr = tableValid_ipAddrToIPDecimal("255.255.255.255");
			var ipNum = 0;
			if(_value.search("/") == -1) {	// only IP
				ipNum = tableValid_ipAddrToIPDecimal(_value);
				if(ipNum > startIPAddr && ipNum < endIPAddr) {
					hintMsg = HINTPASS;
					//convert number to ip address
					if(_firstChar=="!")
						_$obj.val(_firstChar + tableValid_decimalToIPAddr(ipNum));
					else
						_$obj.val(tableValid_decimalToIPAddr(ipNum));
				}
				else {
					hintMsg = _value + " is not a valid IP address!";
				}
			}
			else{ // IP plus netmask
				if(_value.split("/").length > 2) {
					hintMsg = _value + " is not a valid IP address!";
				}
				else {
					var ip_tmp = _value.split("/")[0];
					var mask_tmp = parseInt(_value.split("/")[1]);
					ipNum = tableValid_ipAddrToIPDecimal(ip_tmp);
					if(ipNum > startIPAddr && ipNum < endIPAddr) {
						if(mask_tmp == "" || isNaN(mask_tmp))
							hintMsg = _value + " is not a valid IP address!";
						else if(mask_tmp == 0 || mask_tmp > 32)
							hintMsg = _value + " is not a valid IP address!";
						else {
							hintMsg = HINTPASS;
							//convert number to ip address
							if(_firstChar=="!")
								_$obj.val(_firstChar + tableValid_decimalToIPAddr(ipNum) + "/" + mask_tmp);
							else
								_$obj.val(tableValid_decimalToIPAddr(ipNum) + "/" + mask_tmp);
						}
					}
					else {
						hintMsg = _value + " is not a valid IP address!";
					}
				}
			}
		}
		if(_$obj.next().closest(".hint").length) {
			_$obj.next().closest(".hint").remove();
		}
		if(hintMsg != HINTPASS) {
			var $hintHtml = $('<div>');
			$hintHtml.addClass("hint");
			$hintHtml.html(hintMsg);
			_$obj.after($hintHtml);
			_$obj.focus();
			return false;
		}
		return true;
	}
};

tableRuleDuplicateValidation = {
	iptables_rule : function(_newRuleArray, _currentRuleArray) {
		// Check that no 2 rules with the same values exist, ignoring the Description and Class
		if(_currentRuleArray.length == 0)
			return true;
		else {
			var newRuleArrayTemp = _newRuleArray.slice();
			newRuleArrayTemp.splice(0, 1); // Remove Description
			newRuleArrayTemp.splice(-1, 1); // Remove Class
			for(var i = 0; i < _currentRuleArray.length; i += 1) {
				var currentRuleArrayTemp = _currentRuleArray[i].slice();
				currentRuleArrayTemp.splice(0, 1); // Remove Description
				currentRuleArrayTemp.splice(-1, 1); // Remove Class
				if(newRuleArrayTemp.toString() == currentRuleArrayTemp.toString())
					return false;
			}
		}
		return true;
	}
} // tableRuleDuplicateValidation

tableRuleValidation = {
	iptables_rule : function(_newRuleArray) {
		if(_newRuleArray.length == 7) {
			if(_newRuleArray[1] == "" && _newRuleArray[2] == "" && _newRuleArray[4] == "" && _newRuleArray[5] == "" && _newRuleArray[6] == "") {
				return "Define at least one criterion for this rule!";
			}
			return HINTPASS;
		}
	}
} // tableRuleValidation

function show_iptables_rules(){
	var tableStruct = {
		data: iptables_temp_array,
		container: "iptables_rules_block",
		title: "iptables Rules",
		titieHint: "Edit existing rules by clicking in the table below.<small style='float:right; font-weight:normal; color:white; margin-right:10px; cursor:pointer;' onclick='CakeQoS_reset_iptables()'>Reset</small>",
		capability: {
			add: true,
			del: true,
			clickEdit: true
		},
		header: [
			{
				"title" : "Name",
				"width" : "15%"
			},
			{
				"title" : "Local IP",
				"width" : "15%"
			},
			{
				"title" : "Remote IP",
				"width" : "15%"
			},
			{
				"title" : "Proto",
				"width" : "10%"
			},
			{
				"title" : "Local Port",
				"width" : "15%"
			},
			{
				"title" : "Remote Port",
				"width" : "15%"
			},
			{
				"title" : "Category",
				"width" : "15%"
			}
		],
		createPanel: {
			inputs : [
				{
					"editMode" : "text",
					"title" : "Rule Description",
					"maxlength" : "27",
					"placeholder": "Rule Description",
					"validator" : "description"
				},
				{
					"editMode" : "text",
					"title" : "Local IP/CIDR",
					"maxlength" : "19",
					"valueMust" : false,
					"placeholder": "192.168.1.100 !192.168.1.100 192.168.1.100/31 !192.168.1.100/31",
					"validator" : "qosIPCIDR"
				},
				{
					"editMode" : "text",
					"title" : "Remote IP/CIDR",
					"maxlength" : "19",
					"valueMust" : false,
					"placeholder": "9.9.9.9 !9.9.9.9 9.9.9.0/24 !9.9.9.0/24",
					"validator" : "qosIPCIDR"
				},
				{
					"editMode" : "select",
					"title" : "Protocol",
					"option" : {"BOTH" : "both", "TCP" : "tcp", "UDP" : "udp"}
				},
				{
					"editMode" : "text",
					"title" : "Local Port",
					"maxlength" : "36",
					"valueMust" : false,
					"placeholder": "443 !443 1234:5678 !1234:5678 53,123,853 !53,123,853",
					"validator" : "qosPortRange"
				},
				{
					"editMode" : "text",
					"title" : "Remote Port",
					"maxlength" : "36",
					"valueMust" : false,
					"placeholder": "443 !443 1234:5678 !1234:5678 53,123,853 !53,123,853",
					"validator" : "qosPortRange"
				},
				{
					"editMode" : "select",
					"title" : "Category",
					"option" : { "Bulk" : "0", "Streaming" : "1", "Voice" : "2", "Conferencing" : "3", "Gaming" : "4" }
				}
			],
			maximum: 24
		},
		clickRawEditPanel: {
			inputs : [
				{
					"editMode" : "text",
					"maxlength" : "27",
					"styleList" : {"word-wrap":"break-word","overflow-wrap":"break-word"},
					"validator" : "description"
				},
				{
					"editMode" : "text",
					"maxlength" : "19",
					"valueMust" : false,
					"validator" : "qosIPCIDR"
				},
				{
					"editMode" : "text",
					"maxlength" : "19",
					"valueMust" : false,
					"validator" : "qosIPCIDR"
				},
				{
					"editMode" : "select",
					"option" : {"BOTH" : "both", "TCP" : "tcp", "UDP" : "udp"}
				},
				{
					"editMode" : "text",
					"maxlength" : "36",
					"valueMust" : false,
					"validator" : "qosPortRange"
				},
				{
					"editMode" : "text",
					"maxlength" : "36",
					"valueMust" : false,
					"validator" : "qosPortRange"
				},
				{
					"editMode" : "select",
					"option" : { "Bulk" : "0", "Streaming" : "1", "Voice" : "2", "Conferencing" : "3", "Gaming" : "4" }
				}
			]
		},
		ruleDuplicateValidation : "iptables_rule",
		ruleValidation : "iptables_rule"
	}
	tableApi.genTableAPI(tableStruct);
}

function get_config()
{
	if ( qos_ibw == 0 && qos_obw == 0 ) {
		document.getElementById('cakeqos_ibw').innerText = "Auto";
		document.getElementById('cakeqos_obw').innerText = "Auto";
	} else {
		document.getElementById('cakeqos_ibw').innerText = (qos_ibw/1024).toFixed(2) + ' Mb/s';
		document.getElementById('cakeqos_obw').innerText = (qos_obw/1024).toFixed(2) + ' Mb/s';
	}
	if ( custom_settings.cakeqos_ver != undefined )
		document.getElementById("cakeqos_version").innerText = "v" + custom_settings.cakeqos_ver;
	else
		document.getElementById("cakeqos_version").innerHTML = "<span>N/A</span>";
	
	if ( custom_settings.cakeqos_branch != undefined )
		document.getElementById("cakeqos_version").innerText += " Dev";

	if ( custom_settings.cakeqos_iptables == undefined )  // rules not yet converted to API format
		{
			iptables_rulelist_array = iptables_default_rules;
			iptables_rulename_array = decodeURIComponent(iptables_default_rulenames);
		}
	else { // rules are migrated to new API variables
		iptables_rulelist_array = custom_settings.cakeqos_iptables;
		if ( custom_settings.cakeqos_iptables_names == undefined ) {
			iptables_rulename_array = "";
			var iptables_rulecount = iptables_rulelist_array.split("<").length;
			for (var i=0;i<iptables_rulecount;i++) {
				iptables_rulename_array += "<Rule " + eval(" i + 1 ");
			}
		}
		else
			iptables_rulename_array = decodeURIComponent(custom_settings.cakeqos_iptables_names);
	}

	if ( custom_settings.cakeqos_dlprio == undefined )
		document.getElementById('cakeqos_dlprio').value = 3;
	else
		document.getElementById('cakeqos_dlprio').value = custom_settings.cakeqos_dlprio;

	if ( custom_settings.cakeqos_ulprio == undefined )
		document.getElementById('cakeqos_ulprio').value = 0;
	else
		document.getElementById('cakeqos_ulprio').value = custom_settings.cakeqos_ulprio;

	if ( custom_settings.cakeqos_dlflowiso == undefined )
		document.getElementById('cakeqos_dlflowiso').value = 6;
	else
		document.getElementById('cakeqos_dlflowiso').value = custom_settings.cakeqos_dlflowiso;

	if ( custom_settings.cakeqos_ulflowiso == undefined )
		document.getElementById('cakeqos_ulflowiso').value = 5;
	else
		document.getElementById('cakeqos_ulflowiso').value = custom_settings.cakeqos_ulflowiso;

	if ( custom_settings.cakeqos_dlnat == undefined )
		document.form.cakeqos_dlnat.value = <% nvram_match( "wan0_nat_x", "1", "1"); %>;
	else
		document.form.cakeqos_dlnat.value = custom_settings.cakeqos_dlnat;

	if ( custom_settings.cakeqos_ulnat == undefined )
		document.form.cakeqos_ulnat.value = <% nvram_match( "wan0_nat_x", "1", "1"); %>;
	else
		document.form.cakeqos_ulnat.value = custom_settings.cakeqos_ulnat;

	if ( custom_settings.cakeqos_dlwash == undefined )
		document.form.cakeqos_dlwash.value = 1;
	else
		document.form.cakeqos_dlwash.value = custom_settings.cakeqos_dlwash;

	if ( custom_settings.cakeqos_ulwash == undefined )
		document.form.cakeqos_ulwash.value = 0;
	else
		document.form.cakeqos_ulwash.value = custom_settings.cakeqos_ulwash;

	if ( custom_settings.cakeqos_dlack == undefined )
		document.form.cakeqos_dlack.value = 0;
	else
		document.form.cakeqos_dlack.value = custom_settings.cakeqos_dlack;

	if ( custom_settings.cakeqos_ulack == undefined )
		document.form.cakeqos_ulack.value = 0;
	else
		document.form.cakeqos_ulack.value = custom_settings.cakeqos_ulack;

	if ( custom_settings.cakeqos_dlcust == undefined )
		document.getElementById('cakeqos_dlcust').value = "";
	else
		document.getElementById('cakeqos_dlcust').value = Base64.decode(custom_settings.cakeqos_dlcust);

	if ( custom_settings.cakeqos_ulcust == undefined )
		document.getElementById('cakeqos_ulcust').value = "";
	else
		document.getElementById('cakeqos_ulcust').value = Base64.decode(custom_settings.cakeqos_ulcust);

	if ( custom_settings.cakeqos_ulrules == undefined )
		document.form.cakeqos_ulrules.value = 0;
	else
		document.form.cakeqos_ulrules.value = custom_settings.cakeqos_ulrules;

	var r=0;
	iptables_temp_array = iptables_rulelist_array.split("<");
	var iptables_names_temp_array = iptables_rulename_array.split("<");
	iptables_temp_array.shift();
	iptables_names_temp_array.shift();
	for (r=0;r<iptables_temp_array.length;r++){
		if (iptables_temp_array[r] != "") {
			iptables_temp_array[r]=iptables_temp_array[r].split(">");
			if (iptables_names_temp_array[r])
				iptables_temp_array[r].unshift(iptables_names_temp_array[r]);
		}
	}
}

function CakeQoS_reset_iptables() {
	iptables_rulelist_array = iptables_default_rules;
	iptables_rulename_array = decodeURIComponent(iptables_default_rulenames);
	iptables_temp_array = [];
	iptables_temp_array = iptables_rulelist_array.split("<");
	iptables_temp_array.shift();
	iptables_names_temp_array = [];
	iptables_names_temp_array = iptables_rulename_array.split("<");
	iptables_names_temp_array.shift();
	for (r=0;r<iptables_temp_array.length;r++){
		if (iptables_temp_array[r] != "") {
			iptables_temp_array[r]=iptables_temp_array[r].split(">");
			if (iptables_names_temp_array[r])
				iptables_temp_array[r].unshift(iptables_names_temp_array[r]);
		}
	}
	show_iptables_rules();
} // CakeQoS_reset_iptables()

function save_config_apply() {
	iptables_rulelist_array = "";
	iptables_rulename_array = "";
	for(var i = 0; i < iptables_temp_array.length; i++) {
		if(iptables_temp_array[i].length != 0) {
			iptables_rulelist_array += "<";
			iptables_rulename_array += "<";
			for(var j = 0; j < iptables_temp_array[i].length; j++) {
				if ( j == 0 )
					iptables_rulename_array += encodeURIComponent(iptables_temp_array[i][j]);
				else {
					iptables_rulelist_array += iptables_temp_array[i][j];
					if( (j + 1) != iptables_temp_array[i].length)
						iptables_rulelist_array += ">";
				}
			}
		}
	}

	if (iptables_rulelist_array.length > 2999) {
		alert("Total iptables rules exceeds 2999 bytes! Please delete or consolidate!");
		return
	}
	if (iptables_rulename_array.length > 2999) {
		alert("Total iptables rule names exceed 2999 bytes! Please shorten or consolidate rules!");
		return
	}
	if (iptables_rulelist_array == iptables_default_rules && iptables_rulename_array == iptables_default_rulenames) {
		delete custom_settings.cakeqos_iptables;
		delete custom_settings.cakeqos_iptables_names;
	} else {
		custom_settings.cakeqos_iptables = iptables_rulelist_array;
		custom_settings.cakeqos_iptables_names = iptables_rulename_array;
	}

	if ( document.getElementById('cakeqos_dlprio').value == 3 )
		delete custom_settings.cakeqos_dlprio;
	else
		custom_settings.cakeqos_dlprio = document.getElementById('cakeqos_dlprio').value;

	if ( document.getElementById('cakeqos_ulprio').value == 0 )
		delete custom_settings.cakeqos_ulprio;
	else
		custom_settings.cakeqos_ulprio = document.getElementById('cakeqos_ulprio').value;

	if ( document.getElementById('cakeqos_dlflowiso').value == 6 )
		delete custom_settings.cakeqos_dlflowiso;
	else
		custom_settings.cakeqos_dlflowiso = document.getElementById('cakeqos_dlflowiso').value;

	if ( document.getElementById('cakeqos_ulflowiso').value == 5 )
		delete custom_settings.cakeqos_ulflowiso;
	else
		custom_settings.cakeqos_ulflowiso = document.getElementById('cakeqos_ulflowiso').value;

	if ( document.form.cakeqos_dlnat.value == <% nvram_match( "wan0_nat_x", "1", "1"); %> )
		delete custom_settings.cakeqos_dlnat;
	else
		custom_settings.cakeqos_dlnat = document.form.cakeqos_dlnat.value;

	if ( document.form.cakeqos_ulnat.value == <% nvram_match( "wan0_nat_x", "1", "1"); %> )
		delete custom_settings.cakeqos_ulnat;
	else
		custom_settings.cakeqos_ulnat = document.form.cakeqos_ulnat.value;

	if ( document.form.cakeqos_dlwash.value == 1 )
		delete custom_settings.cakeqos_dlwash;
	else
		custom_settings.cakeqos_dlwash = document.form.cakeqos_dlwash.value;

	if ( document.form.cakeqos_ulwash.value == 0 )
		delete custom_settings.cakeqos_ulwash;
	else
		custom_settings.cakeqos_ulwash = document.form.cakeqos_ulwash.value;

	if ( document.form.cakeqos_dlack.value == 0 )
		delete custom_settings.cakeqos_dlack;
	else
		custom_settings.cakeqos_dlack = document.form.cakeqos_dlack.value;

	if ( document.form.cakeqos_ulack.value == 0 )
		delete custom_settings.cakeqos_ulack;
	else
		custom_settings.cakeqos_ulack = document.form.cakeqos_ulack.value;

	if ( document.getElementById('cakeqos_dlcust').value == "" )
		delete custom_settings.cakeqos_dlcust;
	else
		custom_settings.cakeqos_dlcust = Base64.encode(document.getElementById('cakeqos_dlcust').value);

	if ( document.getElementById('cakeqos_ulcust').value == "" )
		delete custom_settings.cakeqos_ulcust;
	else
		custom_settings.cakeqos_ulcust = Base64.encode(document.getElementById('cakeqos_ulcust').value);

	if ( custom_settings.cakeqos_ulrules == 0 )
		delete custom_settings.cakeqos_ulrules;
	else
		custom_settings.cakeqos_ulrules = document.form.cakeqos_ulrules.value;

	/* Store object as a string in the amng_custom hidden input field */
	if (JSON.stringify(custom_settings).length < 8192) {
		document.getElementById('amng_custom').value = JSON.stringify(custom_settings);
		document.form.action_script.value = "restart_qos;restart_firewall";
		//document.form.action_script.value = "";
		document.form.submit();
	}
	else
		alert("Settings for all addons exceeds 8K limit! Cannot save!");
}

function SetCurrentPage() {
	var model = '<% nvram_get("odmpid"); %>';
	if ( model == "" ) model = '<% nvram_get("productid"); %>';
	document.title = "ASUS Wireless Router " + model + " - CakeQOS-Merlin";
	document.form.next_page.value = window.location.pathname.substring(1);
	document.form.current_page.value = window.location.pathname.substring(1);
}

function GetCookie(cookiename,returntype){
	var s;
	if((s = cookie.get("cakeqos_"+cookiename)) != null){
		return cookie.get("cakeqos_"+cookiename);
	}
	else{
		if(returntype == "string"){
			return "";
		}
		else if(returntype == "number"){
			return 0;
		}
	}
}

function SetCookie(cookiename,cookievalue){
	cookie.set("cakeqos_"+cookiename, cookievalue, 10 * 365);
}

function AddEventHandlers(){
	$(".collapsible-jquery").off('click').on('click', function(){
		$(this).siblings().toggle("fast",function(){
			if($(this).css("display") == "none"){
				SetCookie($(this).siblings()[0].id,"collapsed");
			}
			else{
				SetCookie($(this).siblings()[0].id,"expanded");
			}
		})
	});

	$(".collapsible-jquery").each(function(index,element){
		if(GetCookie($(this)[0].id,"string") == "collapsed"){
			$(this).siblings().toggle(false);
		}
		else{
			$(this).siblings().toggle(true);
		}
	});
}

function format_Cake_Stat(statname, statval) {
	var usec = new RegExp("^.*_us$", "gi");
	var bytes = new RegExp("^.*_bytes$", "gi");
	var unit = ' B';

	if (statname.match(usec)) {
		if (statval >= 1000)
			return ( statval / 1000 ).toLocaleFixed(0,2) + ' ms';
		else
			return statval.toLocaleString() + ' μs';
	}
	if (statname.match(bytes)) {
		if (statval > 1024) {
			statval = statval / 1024;
			unit = " KB";
		}
		if (statval > 1024) {
			statval = statval / 1024;
			unit = " MB";
		}
		if (statval > 1024) {
			statval = statval / 1024;
			unit = " GB";
		}
		return statval.toLocaleFixed(0,2) + unit;
	}
	if (statname == 'threshold_rate')
		return ( statval * 8 / 1000 ).toLocaleString() + ' Kbit';
	return statval.toLocaleString();
}

function generate_Cake_StatsTable(cake_stats_object, dir, id){
	var code = '';
	var lastUpdated = new Date(cake_statstime*1000);
	code +='<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable_table">';
	code += '<thead class="collapsible-jquery" id="' + id + '"><tr><td colspan="' + ( cake_stats_object.tins.length + 1 ) + '">Cake ' + dir + ' Statistics (click to expand/collapse)<small style="float:right;font-weight:normal;">Last Updated: ' + lastUpdated.toLocaleDateString() + ' ' + lastUpdated.toLocaleTimeString() + '</small></td></tr></thead>';
	code += '<tr><th></th>';
	switch (cake_stats_object.tins.length) {
		case 3:
			code += '<th width="26%">Bulk</th><th width="27%">Best Effort</th><th width="27%">Voice</th>';
			break;
		case 4:
			code += '<th width="20%">Bulk</th><th width="20%">Best Effort</th><th width="20%">Video</th><th width="20%">Voice</th>';
			break;
		default:
			for (var i=0;i<cake_stats_object.tins.length;i++)
				code += '<th width="' + ( 80 / cake_stats_object.tins.length ) +'%">Tin ' + i + '</th>';
			break;
	}
	code += '</tr>';
	for (const key in cake_stats_labels) {
		code += '<tr><th title="' + key + '">' + cake_stats_labels[key] + '</th>';
		for (var i=0;i<cake_stats_object.tins.length;i++) {
			code += '<td title="' + cake_stats_object.tins[i][key] + '">' + format_Cake_Stat(key, cake_stats_object.tins[i][key]) + '</td>';
		}
		code += '</tr>';
	}
	code += '</table>';
	return code;
}

function refresh_Cake_StatsInfo(){
	var lastUpdated = new Date(cake_statstime*1000);
	var code='<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable_table">';
	code += '<thead class="collapsible-jquery" id="qdisc_status"><tr><td colspan="3">Cake Current Status (click to expand/collapse)<small style="float:right;font-weight:normal;">Last Updated: ' + lastUpdated.toLocaleDateString() + ' ' + lastUpdated.toLocaleTimeString() + '</small></td></tr></thead>';
	code += '<tr><th width="34%"></th>';
	code += '<th width="33%">Download</th>';
	code += '<th width="33%">Upload</th></tr>';
	code += '<tr><th>Bandwidth (Mb/s)</th><td>' + ( cake_download_stats.options.bandwidth * 8 / 1024000 ).toLocaleFixed(2,2) + '</td><td>' + ( cake_upload_stats.options.bandwidth * 8 / 1024000 ).toLocaleFixed(2,2) + '</td></tr>';
	code += '<tr><th>Priority Queue</th><td>' + cake_download_stats.options.diffserv + '</td><td>' + cake_upload_stats.options.diffserv + '</td></tr>';
	code += '<tr><th>Flow Isolation</th><td>' + cake_download_stats.options.flowmode + '</td><td>' + cake_upload_stats.options.flowmode + '</td></tr>';
	code += '<tr><th>NAT</th><td>' + ( cake_download_stats.options.nat ? 'Yes' : 'No' ) + '</td><td>' + ( cake_upload_stats.options.nat ? 'Yes' : 'No' ) + '</td></tr>';
	code += '<tr><th>Wash</th><td>' + ( cake_download_stats.options.wash ? 'Yes' : 'No' ) + '</td><td>' + ( cake_upload_stats.options.wash ? 'Yes' : 'No' ) + '</td></tr>';
	code += '<tr><th>Ingress</th><td>' + ( cake_download_stats.options.ingress ? 'ingress' : 'egress' ) + '</td><td>' + ( cake_upload_stats.options.ingress ? 'ingress' : 'egress' )  + '</td></tr>';
	code += '<tr><th>ACK Filter</th><td>' + cake_download_stats.options["ack-filter"] + '</td><td>' + cake_upload_stats.options["ack-filter"] + '</td></tr>';
	code += '<tr><th>Split GSO</th><td>' + ( cake_download_stats.options["split_gso"] ? 'Yes' : 'No' ) + '</td><td>' + ( cake_upload_stats.options["split_gso"] ? 'Yes' : 'No' ) + '</td></tr>';
	code += '<tr><th>Rount Trip Time (ms)</th><td>' + ( cake_download_stats.options.rtt / 1000 ) + '</td><td>' + ( cake_upload_stats.options.rtt / 1000 ) + '</td></tr>';
	code += '<tr><th>Overhead</th><td>' + cake_download_stats.options.overhead + '</td><td>' + cake_upload_stats.options.overhead + '</td></tr>';
	code += '<tr><th>ATM</th><td>' + cake_download_stats.options.atm + '</td><td>' + cake_upload_stats.options.atm + '</td></tr>';
	code += '<tr><th>MPU</th><td>' + cake_download_stats.options.mpu + '</td><td>' + cake_upload_stats.options.mpu + '</td></tr>';
	code += '</table>';

	code += generate_Cake_StatsTable(cake_download_stats, "Download", "dl_status");
	code += generate_Cake_StatsTable(cake_upload_stats, "Upload", "ul_status");

	return code;
}

function update_cake_status(){
	$.ajax({
		url: '/ext/cake-qos/cake_status.js',
		dataType: 'script',
		timeout: 3000,
		error:	function(xhr){
			if ( stat_retries < 5 ) {
				setTimeout('update_cake_status();', 3000);
				stat_retries++;
			} else {
				stat_retries = 0;
				document.getElementById("cake_status_check").disabled = false;
				document.getElementById('cakeqos_status').innerHTML='<div style="font-size: 125%; color: rgb(255, 204, 0);">Timeout retrieving Cake stats. Try again later.</div>';
			}
		},
		success: function(){
			stat_retries = 0;
			document.getElementById("cake_status_check").disabled = false;
			if ( cake_upload_stats.kind == 'cake' && cake_download_stats.kind == 'cake' ) {
				document.getElementById('cakeqos_status').innerHTML=refresh_Cake_StatsInfo();
				AddEventHandlers();
			}
			else
				document.getElementById('cakeqos_status').innerHTML='<div style="font-size: 125%; color: rgb(255, 204, 0);">Cake is not running. Try again later.</div>';
		}
	});
}

function update_status(){
	$.ajax({
		url: '/ext/cake-qos/detect_update.js',
		dataType: 'script',
		timeout: 3000,
		error:	function(xhr){
			setTimeout('update_status();', 3000);
		},
		success: function(){
			if ( verUpdateStatus == "InProgress" )
				setTimeout('update_status();', 3000);
			else {
				document.getElementById("ver_check").disabled = false;
				document.getElementById("ver_update_scan").style.display = "none";
				if ( verUpdateStatus == "NoUpdate" ) {
					document.getElementById("versionStatus").innerText = " You have the latest version.";
					document.getElementById("versionStatus").style.display = "";
					}
				else if ( verUpdateStatus == "Error" ) {
					document.getElementById("versionStatus").innerText = " Error getting remote version.";
					document.getElementById("versionStatus").style.display = "";
					}
				else {
					/* version update or hotfix available */
					/* toggle update button */
					document.getElementById("versionStatus").innerText = " " + verUpdateStatus + " available!";
					document.getElementById("versionStatus").style.display = "";
					document.getElementById("ver_check").style.display = "none";
					document.getElementById("ver_update").style.display = "";
				}
			}
		}
	});
}

function submit_refresh_status() {
	document.getElementById("cake_status_check").disabled = true;
	document.cake_status_check.submit();
	setTimeout("update_cake_status();", 2000);
}

function version_check() {
	document.getElementById("ver_check").disabled = true;
	document.ver_check.action_script.value="start_cake-qosupdatecheck"
	document.ver_check.submit();
	document.getElementById("versionStatus").style.display = "none";
	document.getElementById("ver_update_scan").style.display = "";
	setTimeout("update_status();", 2000);
}

function version_update() {
	document.form.action_script.value="start_cake-qosupdatesilent"
	document.form.submit();
}

function well_known_rules(){
	var code = "";
	var wellKnownRule = new Array();
//		[ "Rule Name", "Local IP", "Remote IP", "Proto", "Local Port", "Remote Port", "DSCP/Tin"],
//      Tin: { "Bulk" : "0", "Streaming" : "1", "Voice" : "2", "Conferencing" : "3", "Gaming" : "4" }
	wItem = [
		[ "Facetime", "", "", "udp", "16384:16415", "", "3"],
		[ "Google Meet", "", "", "udp", "", "19302:19309", "3"],
		[ "Skype/Teams", "", "", "udp", "", "3478:3481", "3"],
		[ "Usenet", "", "", "tcp", "", "119,563", "0"],
		[ "WiFi Calling", "", "", "udp", "", "500,4500", "2"],
		[ "Zoom", "", "", "udp", "", "8801:8810", "3"]
	];

	code += '<option value="User Defined">Please select</option>';
	code += '<optgroup label="Pre-defined rules">';
	for (var i = 0; i < wItem.length; i++){
		code += '<option value="' + i + '">' + wItem[i][0] + '</option>';
	}
	var tmpCount=wItem.length;
	for (i=0;i<iptables_temp_array.length; i++) {
		if (i==0)
			code += '<optgroup label="User-defined rules">';
		code += '<option value="' + ( tmpCount + i ) + '">' + iptables_temp_array[i][0] + '</option>';
		wItem.push(iptables_temp_array[i]);
	}
	document.form.WellKnownRules.innerHTML = code;
} // well_known_rules

function change_wizard(o){
	var i = o.value;
	var wellKnownRule = new Array();
	wellKnownRule.push(wItem[i][0]);
	if (wItem[i][1] == "login_ip_str")
		wellKnownRule.push(login_ip_str());
	else
		wellKnownRule.push(wItem[i][1]);
	wellKnownRule.push(wItem[i][2]);
	wellKnownRule.push(wItem[i][3]);
	wellKnownRule.push(wItem[i][4]);
	wellKnownRule.push(wItem[i][5]);
	wellKnownRule.push(wItem[i][6]);

	var validDuplicateFlag = true;
	if(tableApi._attr.hasOwnProperty("ruleDuplicateValidation")) {
		var currentEditRuleArray = wellKnownRule;
		var filterCurrentEditRuleArray = iptables_temp_array;
		validDuplicateFlag = tableRuleDuplicateValidation[tableApi._attr.ruleDuplicateValidation](currentEditRuleArray, filterCurrentEditRuleArray);
		if(!validDuplicateFlag) {
			document.form.WellKnownRules.selectedIndex = 0;
			alert("This rule already exists.");
			return false;
		}
		iptables_temp_array.push(currentEditRuleArray);
		show_iptables_rules();
		}
	document.form.WellKnownRules.selectedIndex = 0;
} // change_wizard

</script>
</head>
<body onload="initial();" class="bg">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>
<iframe name="hidden_frame" id="hidden_frame" width="0" height="0" frameborder="0"></iframe>
<form method="post" name="form" action="/start_apply.htm" target="hidden_frame">
<input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get(" preferred_lang "); %>">
<input type="hidden" name="firmver" value="<% nvram_get(" firmver "); %>">
<input type="hidden" name="current_page" value="">
<input type="hidden" name="next_page" value="">
<input type="hidden" name="action_mode" value="apply">
<input type="hidden" name="action_script" value="">
<input type="hidden" name="action_wait" value="15">
<input type="hidden" name="flag" value="">
<input type="hidden" name="amng_custom" id="amng_custom" value="">
<table class="content" align="center" cellpadding="0" cellspacing="0">
<tr>
<td width="17">&nbsp;</td>
<td valign="top" width="202">
<div id="mainMenu"></div>
<div id="subMenu"></div>
</td>
<td valign="top">
<div id="tabMenu" class="submenuBlock"></div>
<table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
<tr>
<td valign="top">
<table width="760px" border="0" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTitle" id="FormTitle">
<tbody bgcolor="#4D595D">
<tr>
<td valign="top">
<div class="formfonttitle" style="margin:10px 0px 10px 5px; display:inline-block;">CakeQOS-Merlin</div>
<div id="no_aqos_notice" style="display:none;margin:10px 0px 10px 5px;font-size:125%;color:#FFCC00;float:right;">Note: Cake QoS is not enabled.</div>
<div style="margin-bottom:10px" class="splitLine"></div>

<!-- CakeQoS UI Start-->
<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" class="FormTable">
	<thead class="collapsible-jquery" id="options">
		<tr>
			<td colspan="3">Options (click to expand/collapse)</td>
		</tr>
	</thead>
	<tr>
		<th>Version</th>
		<td colspan="2">
			<span id="cakeqos_version" style="margin-left:4px; color:#FFFFFF;"></span>
			&nbsp;&nbsp;&nbsp;
			<input type="button" id="ver_check" class="button_gen" style="width:135px;height:24px;" onclick="version_check();" value="Check for Update">
			<input type="button" id="ver_update" class="button_gen" style="display:none;width:135px;height:24px;" onclick="version_update();" value="Update">
			&nbsp;&nbsp;&nbsp;
			<img id="ver_update_scan" style="display:none;vertical-align:middle;" src="images/InternetScan.gif">
			<span id="versionStatus" style="color:#FC0;display:none;"></span>
		</td>
	</tr>
	<tr id="qos_overhead_tr">
		<th><a class="hintstyle" href="javascript:void(0);" onClick="openHint(50, 28);">WAN packet overhead</a></th>
		<td colspan="2">
			<input type="text" maxlength="4" class="input_6_table" name="qos_overhead" id="qos_overhead" onKeyPress="return validator.isNumber(this,event);" onblur="validator.numberRange(this, -64, 256);" value="<% nvram_get("qos_overhead"); %>" style="float:left;">
			<img id="ovh_pull_arrow" class="pull_arrow" height="14px;" src="/images/arrow-down.gif" onclick="pullOverheadList(this);">
			<div id="overhead_presets_list" style="margin-top:25px;height:auto;" class="dns_server_list_dropdown"></div>
			<label for="qos_mpu" style="float:left;margin-left:25px;margin-right:5px;margin-top:4px;">MPU:</label>
			<input type="text" maxlength="4" class="input_6_table" name="qos_mpu" id="qos_mpu" onKeyPress="return validator.isNumber(this,event);" onblur="validator.numberRange(this, 0, 256);" value="<% nvram_get("qos_mpu"); %>" style="float:left;">
			<label for="qos_atm" style="float:left;margin-left:25px;margin-right:5px;margin-top:4px;">Mode:</label>
			<select name="qos_atm" id="qos_atm" class="input_option">
				<option <% nvram_match("qos_atm","0","selected"); %> value="0">Normal</option>
				<option <% nvram_match("qos_atm","1","selected"); %> value="1">ATM</option>
				<option <% nvram_match("qos_atm","2","selected"); %> value="2">PTM</option>
			</select>
		</td>
	</tr>
	<tr>
		<th>Bandwidth (read-only)&nbsp;&nbsp;&nbsp;<span><a style="color:#FC0;text-decoration: underline;" href="QoS_EZQoS.asp">Manage</a></span></th>
		<td>
			Download:&nbsp;<div id="cakeqos_ibw" style="display:inline;"></div>
		</td>
		<td>
			Upload:&nbsp;<div id="cakeqos_obw" style="display:inline;"></div>
		</td>
	</tr>
	<tr>
		<th><a class="hintstyle" href="javascript:void(0);" onclick="YazHint(2);">Priority Queue (Tins)</a></th>
		<td>
			<label for="cakeqos_dlprio">Download:</label>
			<select name="cakeqos_dlprio" id="cakeqos_dlprio" class="input_option">
				<option value="0">diffserv3</option>
				<option value="1">diffserv4</option>
				<option value="2">diffserv8</option>
				<option value="3">besteffort</option>
			</select>
			</td>
			<td>
			<label for="cakeqos_ulprio">Upload:</label>
			<select name="cakeqos_ulprio" id="cakeqos_ulprio" class="input_option">
				<option value="0">diffserv3</option>
				<option value="1">diffserv4</option>
				<option value="2">diffserv8</option>
				<option value="3">besteffort</option>
			</select>
		</td>
	</tr>
	<tr>
		<th><a class="hintstyle" href="javascript:void(0);" onclick="YazHint(3);">Flow Isolation (Fairness)</a></th>
		<td>
			<label for="cakeqos_dlflowiso">Download:</label>
			<select name="cakeqos_dlflowiso" id="cakeqos_dlflowiso" class="input_option">
				<option value="0">flowblind</option>
				<option value="1">srchost</option>
				<option value="2">dsthost</option>
				<option value="3">hosts</option>
				<option value="4">flows</option>
				<option value="5">dual-srchost</option>
				<option value="6">dual-dsthost</option>
				<option value="7">triple-isolate</option>
			</select>
			</td>
			<td>
			<label for="cakeqos_ulflowiso">Upload:</label>
			<select name="cakeqos_ulflowiso" id="cakeqos_ulflowiso" class="input_option">
				<option value="0">flowblind</option>
				<option value="1">srchost</option>
				<option value="2">dsthost</option>
				<option value="3">hosts</option>
				<option value="4">flows</option>
				<option value="5">dual-srchost</option>
				<option value="6">dual-dsthost</option>
				<option value="7">triple-isolate</option>
			</select>
		</td>
	</tr>
	<tr>
		<th><a class="hintstyle" href="javascript:void(0);" onclick="YazHint(4);">NAT Lookup</a></th>
		<td>
			<label for="cakeqos_dlnat">Download:</label>
			<input type="radio" name="cakeqos_dlnat" class="input" value="1">Yes
			<input type="radio" name="cakeqos_dlnat" class="input" value="0">No
			</td>
			<td>
			<label for="cakeqos_ulnat">Upload:</label>
			<input type="radio" name="cakeqos_ulnat" class="input" value="1">Yes
			<input type="radio" name="cakeqos_ulnat" class="input" value="0">No
		</td>
	</tr>
	<tr>
		<th><a class="hintstyle" href="javascript:void(0);" onclick="YazHint(5);">Wash DSCP Markings</a></th>
		<td>
			<label for="cakeqos_dlwash">Download:</label>
			<input type="radio" name="cakeqos_dlwash" class="input" value="1">Yes
			<input type="radio" name="cakeqos_dlwash" class="input" value="0">No
			</td>
			<td>
			<label for="cakeqos_ulwash">Upload:</label>
			<input type="radio" name="cakeqos_ulwash" class="input" value="1">Yes
			<input type="radio" name="cakeqos_ulwash" class="input" value="0">No
		</td>
	</tr>
	<tr>
		<th><a class="hintstyle" href="javascript:void(0);" onclick="YazHint(6);">Filter Duplicate TCP ACKs</a></th>
		<td>
			<label for="cakeqos_dlack">Download:</label>
			<input type="radio" name="cakeqos_dlack" class="input" value="1">Yes
			<input type="radio" name="cakeqos_dlack" class="input" value="0">No
			</td>
			<td>
			<label for="cakeqos_ulack">Upload:</label>
			<input type="radio" name="cakeqos_ulack" class="input" value="1">Yes
			<input type="radio" name="cakeqos_ulack" class="input" value="0">No
		</td>
	</tr>
	<tr>
		<th><a class="hintstyle" href="javascript:void(0);" onclick="YazHint(7);">Custom Download Parameters</a></th>
		<td colspan="2">
			<input id="cakeqos_dlcust" type="text" maxlength="48" class="input_32_table" name="cakeqos_dlcust" autocomplete="off" autocorrect="off" autocapitalize="off" placeholder="Optional custom parameters">
		</td>
	</tr>
	<tr>
		<th><a class="hintstyle" href="javascript:void(0);" onclick="YazHint(7);">Custom Upload Parameters</a></th>
		<td colspan="2">
			<input id="cakeqos_ulcust" type="text" maxlength="48" class="input_32_table" name="cakeqos_ulcust" autocomplete="off" autocorrect="off" autocapitalize="off" placeholder="Optional custom parameters">
		</td>
	</tr>
	<tr>
		<th><a class="hintstyle" href="javascript:void(0);" onclick="YazHint(1);">Enable Upload Classification</a></th>
		<td colspan="2">
			<input type="radio" name="cakeqos_ulrules" class="input" value="1" onclick="showhide('well_known_rules_tr',1);showhide('iptables_rules_block',1);">Yes
			<input type="radio" name="cakeqos_ulrules" class="input" value="0" onclick="showhide('well_known_rules_tr',0);showhide('iptables_rules_block',0);">No
		</td>
	</tr>
	<tr id="well_known_rules_tr">
		<th>Add Well-Known iptables Rule</th>
		<td colspan="2">
			<select name="WellKnownRules" class="input_option" onChange="change_wizard(this);">
				<option value="User Defined">Please select</option>
			</select>
		</td>
	</tr>
</table>
<div id="iptables_rules_block"></div>
<div class="apply_gen">
	<input name="button" type="button" class="button_gen" onclick="save_config_apply();" value="Apply" />
</div>
<div id="cakeqos_status"></div>
<div class="apply_gen">
	<input type="button" id="cake_status_check" class="button_gen" onclick="submit_refresh_status();" value="Refresh Status">
</div>

<!-- CakeQoS UI END-->
<br>
</td>
</tr>
</tbody>
</table>
</td>
</tr>
</table>
</td>
<td width="10" align="center" valign="top">&nbsp;</td>
</tr>
</table>
</form>
<form method="post" name="ver_check" action="/start_apply.htm" target="hidden_frame">
	<input type="hidden" name="productid" value="<% nvram_get("productid"); %>">
	<input type="hidden" name="current_page" value="">
	<input type="hidden" name="next_page" value="">
	<input type="hidden" name="action_mode" value="apply">
	<input type="hidden" name="action_script" value="">
	<input type="hidden" name="action_wait" value="">
</form>
<form method="post" name="cake_status_check" action="/start_apply.htm" target="hidden_frame">
	<input type="hidden" name="productid" value="<% nvram_get("productid"); %>">
	<input type="hidden" name="current_page" value="">
	<input type="hidden" name="next_page" value="">
	<input type="hidden" name="action_mode" value="apply">
	<input type="hidden" name="action_script" value="start_cake-qosstatsupdate">
	<input type="hidden" name="action_wait" value="">
</form>
<div id="footer"></div>
</body>
