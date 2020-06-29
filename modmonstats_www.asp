<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="X-UA-Compatible" content="IE=Edge"/>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">
<link rel="shortcut icon" href="images/favicon.png">
<link rel="icon" href="images/favicon.png">
<title>Cable Modem Stats</title>
<link rel="stylesheet" type="text/css" href="index_style.css">
<link rel="stylesheet" type="text/css" href="form_style.css">
<style>
p {
  font-weight: bolder;
}

thead.collapsible {
  color: white;
  padding: 0px;
  width: 100%;
  border: none;
  text-align: left;
  outline: none;
  cursor: pointer;
}

thead.collapsibleparent {
  color: white;
  padding: 0px;
  width: 100%;
  border: none;
  text-align: left;
  outline: none;
  cursor: pointer;
}

th.keystatsnumber {
  font-size: 20px !important;
  font-weight: bolder !important;
}

td.keystatsnumber {
  font-size: 20px !important;
  font-weight: bolder !important;
}

td.nodata {
  font-size: 48px !important;
  font-weight: bolder !important;
  height: 65px !important;
  font-family: Arial !important;
}

td.channelcell {
  padding: 0px !important;
  border: 0px !important;
}

.StatsTable {
  table-layout: fixed !important;
  width: 747px !important;
  text-align: center !important;
}

.StatsTable th {
  background-color:#1F2D35 !important;
  background:#2F3A3E !important;
  border-bottom:none !important;
  border-top:none !important;
  font-size: 12px !important;
  color: white !important;
  padding: 4px !important;
  width: 740px !important;
}

.StatsTable td {
  padding: 2px !important;
  word-wrap: break-word !important;
  overflow-wrap: break-word !important;
}

.StatsTable a {
  font-weight: bolder !important;
  text-decoration: underline !important;
}

.StatsTable th:first-child,
.StatsTable td:first-child {
  border-left: none !important;
}

.StatsTable th:last-child ,
.StatsTable td:last-child {
  border-right: none !important;
}

.collapsiblecontent {
  padding: 0px;
  max-height: 0;
  overflow: hidden;
  border: none;
  transition: max-height 0.2s ease-out;
}
</style>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/jquery.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/moment.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/chart.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/hammerjs.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/chartjs-plugin-zoom.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/chartjs-plugin-annotation.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/d3.js"></script>
<script language="JavaScript" type="text/javascript" src="/state.js"></script>
<script language="JavaScript" type="text/javascript" src="/general.js"></script>
<script language="JavaScript" type="text/javascript" src="/popup.js"></script>
<script language="JavaScript" type="text/javascript" src="/help.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/detect.js"></script>
<script language="JavaScript" type="text/javascript" src="/tmhist.js"></script>
<script language="JavaScript" type="text/javascript" src="/tmmenu.js"></script>
<script language="JavaScript" type="text/javascript" src="/client_function.js"></script>
<script language="JavaScript" type="text/javascript" src="/validator.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/modmon/modstatstext.js"></script>
<script>
var $j = jQuery.noConflict(); //avoid conflicts on John's fork (state.js)
var maxNoCharts = 18;
var currentNoCharts = 0;

var ShowLines=GetCookie("ShowLines");

var metriclist = ["RxPwr","RxSnr","RxPstRs","TxPwr","TxT3Out","TxT4Out"];
var titlelist = ["Downstream Power","Downstream SNR","Post-RS Errors","Upstream Power","T3 Timeouts","T4 Timeouts"];
var measureunitlist = ["dBmV","dB","","dBmV","",""];
var chartlist = ["daily","weekly","monthly"];
var timeunitlist = ["hour","day","day"];
var intervallist = [24,7,30];

var RxCount,TxCount,RxColours,TxColours;
var chartColours = ['rgba(24,113,65, 1)','rgba(205,117,81, 1)','rgba(230,55,90, 1)','rgba(5,206,61, 1)','rgba(131,4,176, 1)','rgba(196,145,14, 1)','rgba(169,229,70, 1)','rgba(25,64,183, 1)','rgba(23,153,199, 1)','rgba(223,46,248, 1)','rgba(240,92,214, 1)','rgba(123,137,211, 1)','rgba(141,68,215, 1)','rgba(74,210,128, 1)','rgba(223,247,240, 1)','rgba(226,27,93, 1)','rgba(253,78,222, 1)','rgba(63,192,102, 1)','rgba(82,66,162, 1)','rgba(65,190,78, 1)','rgba(154,113,118, 1)','rgba(222,98,201, 1)','rgba(198,186,137, 1)','rgba(178,45,245, 1)','rgba(95,245,50, 1)','rgba(247,142,18, 1)','rgba(103,152,205, 1)','rgba(39,104,180, 1)','rgba(132,165,5, 1)','rgba(8,249,253, 1)','rgba(227,170,207, 1)','rgba(196,70,76, 1)','rgba(11,197,73, 1)','rgba(127,50,202, 1)','rgba(33,248,170, 1)','rgba(17,216,225, 1)','rgba(176,123,12, 1)','rgba(181,111,105, 1)','rgba(104,122,233, 1)','rgba(217,102,107, 1)','rgba(188,174,88, 1)','rgba(30,224,236, 1)','rgba(169,39,247, 1)','rgba(251,86,116, 1)','rgba(217,163,80, 1)','rgba(155,120,34, 1)','rgba(82,124,118, 1)','rgba(102,89,62, 1)','rgba(48,126,7, 1)','rgba(48,118,188, 1)','rgba(223,246,227, 1)','rgba(152,11,129, 1)','rgba(66,97,241, 1)','rgba(32,113,78, 1)','rgba(83,142,226, 1)','rgba(210,105,250, 1)','rgba(125,115,7, 1)','rgba(198,37,71, 1)','rgba(253,99,153, 1)','rgba(171,225,78, 1)','rgba(66,82,121, 1)','rgba(5,82,115, 1)','rgba(22,62,141, 1)','rgba(135,59,161, 1)','rgba(20,223,59, 1)','rgba(17,206,99, 1)','rgba(142,162,133, 1)','rgba(206,76,155, 1)','rgba(131,87,41, 1)','rgba(199,234,37, 1)','rgba(176,94,156, 1)','rgba(13,58,185, 1)','rgba(147,19,178, 1)','rgba(48,203,55, 1)','rgba(250,31,116, 1)','rgba(138,9,168, 1)','rgba(90,208,244, 1)','rgba(128,110,93, 1)','rgba(222,202,95, 1)','rgba(189,78,184, 1)','rgba(122,41,65, 1)','rgba(243,176,73, 1)','rgba(23,123,71, 1)','rgba(209,50,12, 1)','rgba(253,218,100, 1)','rgba(214,18,185, 1)','rgba(31,254,215, 1)','rgba(191,53,224, 1)','rgba(117,197,238, 1)','rgba(183,123,104, 1)','rgba(88,34,248, 1)','rgba(124,157,92, 1)','rgba(76,59,160, 1)','rgba(143,235,139, 1)','rgba(59,85,112, 1)','rgba(233,54,148, 1)','rgba(244,176,124, 1)','rgba(246,246,104, 1)','rgba(169,171,44, 1)','rgba(240,3,14, 1)'];

Chart.defaults.global.defaultFontColor = "#CCC";
Chart.Tooltip.positioners.cursor = function(chartElements, coordinates) {
	return coordinates;
};

function keyHandler(e) {
	if (e.keyCode == 27){
		$j(document).off("keydown");
		ResetZoom();
	}
}

$j(document).keydown(function(e){keyHandler(e);});
$j(document).keyup(function(e){
	$j(document).keydown(function(e){
		keyHandler(e);
	});
});

function Draw_Chart_NoData(txtchartname){
	document.getElementById("divLineChart"+txtchartname).width="730";
	document.getElementById("divLineChart"+txtchartname).height="300";
	document.getElementById("divLineChart"+txtchartname).style.width="730px";
	document.getElementById("divLineChart"+txtchartname).style.height="300px";
	var ctx = document.getElementById("divLineChart"+txtchartname).getContext("2d");
	ctx.save();
	ctx.textAlign = 'center';
	ctx.textBaseline = 'middle';
	ctx.font = "normal normal bolder 48px Arial";
	ctx.fillStyle = 'white';
	ctx.fillText('No data to display', 365, 150);
	ctx.restore();
}

function Draw_Chart(txtchartname,txttitle,txtunity,txtunitx,numunitx,dataobject){
	if(typeof dataobject === 'undefined' || dataobject === null) { Draw_Chart_NoData(txtchartname); return; }
	if (dataobject.length == 0) { Draw_Chart_NoData(txtchartname); return; }
	
	var unique = [];
	var chartChannels = [];
	for( let i = 0; i < dataobject.length; i++ ){
		if( !unique[dataobject[i].Channel]){
			chartChannels.push(dataobject[i].Channel);
			unique[dataobject[i].Channel] = 1;
		}
	}
	
	var chartLabels = dataobject.map(function(d) {return d.Channel});
	var chartData = dataobject.map(function(d) {return {x: d.Time, y: d.Value}});
	var objchartname=window["LineChart"+txtchartname];
	
	factor=0;
	if (txtunitx=="hour"){
		factor=60*60*1000;
	}
	else if (txtunitx=="day"){
		factor=60*60*24*1000;
	}
	if (objchartname != undefined) objchartname.destroy();
	var ctx = document.getElementById("divLineChart"+txtchartname).getContext("2d");
	var lineOptions = {
		segmentShowStroke : false,
		segmentStrokeColor : "#000",
		//animationEasing : "easeOutQuart",
		//animationSteps : 100,
		animation: {
			duration: 0 // general animation time
		},
		responsiveAnimationDuration: 0, // animation duration after a resize
		maintainAspectRatio: false,
		animateScale : true,
		hover: { mode: "point" },
		legend: {
			display: true,
			position: "bottom",
			labels: {
				boxWidth: 10,
				fontSize: 10
			}
		},
		title: { display: true, text: txttitle },
		tooltips: {
			callbacks: {
					title: function (tooltipItem, data) { return (moment(tooltipItem[0].xLabel,"X").format('YYYY-MM-DD HH:mm:ss')); },
					label: function (tooltipItem, data) { return data.datasets[tooltipItem.datasetIndex].label + ": " + round(data.datasets[tooltipItem.datasetIndex].data[tooltipItem.index].y,3).toFixed(3) + ' ' + txtunity;}
				},
				mode: 'point',
				position: 'cursor',
				intersect: true
		},
		scales: {
			xAxes: [{
				type: "time",
				gridLines: { display: true, color: "#282828" },
				ticks: {
					display: true,
					min: moment().subtract(numunitx, txtunitx+"s")
				},
				time: { parser: "X", unit: txtunitx, stepSize: 1 }
			}],
			yAxes: [{
				gridLines: { display: false, color: "#282828" },
				scaleLabel: { display: false, labelString: txttitle },
				ticks: {
					display: true,
					beginAtZero: startAtZero(txtchartname),
					max: getLimit(chartData,"y","max",false) + getLimit(chartData,"y","max",false)*0.1,
					callback: function (value, index, values) {
						return round(value,3).toFixed(3) + ' ' + txtunity;
					}
				},
			}]
		},
		plugins: {
			zoom: {
				pan: {
					enabled: false,
					mode: 'xy',
					rangeMin: {
						x: new Date().getTime() - (factor * numunitx),
						y: getLimit(chartData,"y","min",false) - Math.sqrt(Math.pow(getLimit(chartData,"y","min",false),2))*0.1,
					},
					rangeMax: {
						x: new Date().getTime(),
						y: getLimit(chartData,"y","max",false) + getLimit(chartData,"y","max",false)*0.1,
					},
				},
				zoom: {
					enabled: true,
					drag: true,
					mode: 'xy',
					rangeMin: {
						x: new Date().getTime() - (factor * numunitx),
						y: getLimit(chartData,"y","min",false) - Math.sqrt(Math.pow(getLimit(chartData,"y","min",false),2))*0.1,
					},
					rangeMax: {
						x: new Date().getTime(),
						y: getLimit(chartData,"y","max",false) + getLimit(chartData,"y","max",false)*0.1,
					},
					speed: 0.1
				},
			},
		},
		annotation: {
			drawTime: 'afterDatasetsDraw',
			annotations: [{
				//id: 'avgline',
				type: ShowLines,
				mode: 'horizontal',
				scaleID: 'y-axis-0',
				value: getAverage(chartData),
				borderColor: "#fc8500",
				borderWidth: 1,
				borderDash: [5, 5],
				label: {
					backgroundColor: 'rgba(0,0,0,0.3)',
					fontFamily: "sans-serif",
					fontSize: 10,
					fontStyle: "bold",
					fontColor: "#fff",
					xPadding: 6,
					yPadding: 6,
					cornerRadius: 6,
					position: "center",
					enabled: true,
					xAdjust: 0,
					yAdjust: 0,
					content: "Avg=" + round(getAverage(chartData),3).toFixed(3)+txtunity,
				}
			},
			{
				//id: 'maxline',
				type: ShowLines,
				mode: 'horizontal',
				scaleID: 'y-axis-0',
				value: getLimit(chartData,"y","max",true),
				borderColor: "#fc8500",
				borderWidth: 1,
				borderDash: [5, 5],
				label: {
					backgroundColor: 'rgba(0,0,0,0.3)',
					fontFamily: "sans-serif",
					fontSize: 10,
					fontStyle: "bold",
					fontColor: "#fff",
					xPadding: 6,
					yPadding: 6,
					cornerRadius: 6,
					position: "center",
					enabled: true,
					xAdjust: 0,
					yAdjust: 0,
					content: "Max=" + round(getLimit(chartData,"y","max",true),3).toFixed(3)+txtunity,
				}
			},
			{
				//id: 'minline',
				type: ShowLines,
				mode: 'horizontal',
				scaleID: 'y-axis-0',
				value: getLimit(chartData,"y","min",true),
				borderColor: "#fc8500",
				borderWidth: 1,
				borderDash: [5, 5],
				label: {
					backgroundColor: 'rgba(0,0,0,0.3)',
					fontFamily: "sans-serif",
					fontSize: 10,
					fontStyle: "bold",
					fontColor: "#fff",
					xPadding: 6,
					yPadding: 6,
					cornerRadius: 6,
					position: "center",
					enabled: true,
					xAdjust: 0,
					yAdjust: 0,
					content: "Min=" + round(getLimit(chartData,"y","min",true),3).toFixed(3)+txtunity,
				}
			}]
		}
	};
	var lineDataset = {
		datasets: getDataSets(txtchartname, dataobject, chartChannels)
	};
	objchartname = new Chart(ctx, {
		type: 'line',
		data: lineDataset,
		options: lineOptions
	});
	window["LineChart"+txtchartname]=objchartname;
}

function getDataSets(txtchartname, objdata, objchannels) {
	var datasets = [];
	colourname="#fc8500";
	
	for(var i = 0; i < objchannels.length; i++) {
		var channeldata = objdata.filter(function(item) {
			return item.Channel == objchannels[i];
		}).map(function(d) {return {x: d.Time, y: d.Value}});
		
		datasets.push({ label: objchannels[i], data: channeldata, borderWidth: 1, pointRadius: 1, lineTension: 0, fill: false, backgroundColor: chartColours[i], borderColor: chartColours[i]});
	}
	return datasets;
}

function getLimit(datasetname,axis,maxmin,isannotation) {
	var limit=0;
	var values;
	if(axis == "x"){
		values = datasetname.map(function(o) { return o.x } );
	}
	else{
		values = datasetname.map(function(o) { return o.y } );
	}
	
	if(maxmin == "max"){
		limit=Math.max.apply(Math, values);
	}
	else{
		limit=Math.min.apply(Math, values);
	}
	if(maxmin == "max" && limit == 0 && isannotation == false){
		limit = 1;
	}
	return limit;
}

function getAverage(datasetname) {
	var total = 0;
	for(var i = 0; i < datasetname.length; i++) {
		total += (datasetname[i].y*1);
	}
	var avg = total / datasetname.length;
	return avg;
}

function startAtZero(datasetname) {
	var starty = false;
	if(datasetname.indexOf("PstRS") != -1 || datasetname.indexOf("T3Out") != -1 || datasetname.indexOf("T4Out") != -1){
		starty = true;
	}
	return starty;
}

function round(value, decimals) {
	return Number(Math.round(value+'e'+decimals)+'e-'+decimals);
}

function getRandomColor() {
	var r = Math.floor(Math.random() * 255);
	var g = Math.floor(Math.random() * 255);
	var b = Math.floor(Math.random() * 255);
	return "rgba(" + r + "," + g + "," + b + ", 1)";
}

function poolColors(a) {
	var pool = [];
	for(i = 0; i < a; i++) {
		pool.push(getRandomColor());
	}
	return pool;
}

function SetRxTxColours(){
	RxColours = poolColors(RxCount);
	TxColours = poolColors(TxCount);
}

function GetMaxChannels(){
	var RxCountArray = [];
	var TxCountArray = [];
	for(i = 0; i < metriclist.length; i++){
		for (i2 = 0; i2 < chartlist.length; i2++) {
			var varname="LineChart"+metriclist[i]+chartlist[i2];
			var channelcount=window[varname].data.datasets.length;
			if(varname.indexOf("Rx") != -1){
				RxCountArray.push(channelcount);
			}
			else {
				TxCountArray.push(channelcount);
			}
		}
	}
	RxCount = Math.max.apply(Math, RxCountArray);
	TxCount = Math.max.apply(Math, TxCountArray);
}

function ToggleLines() {
	if(ShowLines == ""){
		ShowLines = "line";
		SetCookie("ShowLines","line");
	}
	else {
		ShowLines = "";
		SetCookie("ShowLines","");
	}
	for(i = 0; i < metriclist.length; i++){
		for (i2 = 0; i2 < chartlist.length; i2++) {
			for (i3 = 0; i3 < 3; i3++) {
				window["LineChart"+metriclist[i]+chartlist[i2]].options.annotation.annotations[i3].type=ShowLines;
			}
			window["LineChart"+metriclist[i]+chartlist[i2]].update();
		}
	}
}

function RedrawAllCharts() {
	for(i = 0; i < metriclist.length; i++){
		for (i2 = 0; i2 < chartlist.length; i2++) {
			d3.csv("/ext/modmon/csv/"+metriclist[i]+chartlist[i2]+".htm").then(ProcessChart.bind(null,i,i2));
		}
	}
}

function ProcessChart(i1,i2,dataobject){
	Draw_Chart(metriclist[i1]+chartlist[i2],titlelist[i1],measureunitlist[i1],timeunitlist[i2],intervallist[i2],dataobject);
	currentNoCharts++;
	
	if(currentNoCharts == maxNoCharts) {
		GetMaxChannels();
		$j("#table_buttons2").after(BuildChannelFilterTable());
		AddEventHandlers();
	}
}

function GetCookie(cookiename) {
	var s;
	if ((s = cookie.get("mod_"+cookiename)) != null) {
		return cookie.get("mod_"+cookiename);
	}
	else {
		return "";
	}
}

function SetCookie(cookiename,cookievalue) {
	cookie.set("mod_"+cookiename, cookievalue, 31);
}

function SetCurrentPage(){
	document.form.next_page.value = window.location.pathname.substring(1);
	document.form.current_page.value = window.location.pathname.substring(1);
}

function initial(){
	SetCurrentPage();
	show_menu();
	metriclist.reverse();
	titlelist.reverse();
	
	for (i = 0; i < metriclist.length; i++) {
		$j("#table_buttons2").after(BuildMetricTable(metriclist[i],titlelist[i]));
	}
	
	metriclist.reverse();
	titlelist.reverse();
	
	RedrawAllCharts();
	SetModStatsTitle();
}

function reload() {
	location.reload(true);
}

function ResetZoom(){
	for(i = 0; i < metriclist.length; i++){
		for (i2 = 0; i2 < chartlist.length; i2++) {
			var chartobj = window["LineChart"+metriclist[i]+chartlist[i2]];
			if(typeof chartobj === 'undefined' || chartobj === null) { continue; }
			chartobj.resetZoom();
		}
	}
}

function DragZoom(button){
	var drag = true;
	var pan = false;
	var buttonvalue = "";
	if(button.value.indexOf("On") != -1){
		drag = false;
		pan = true;
		buttonvalue = "Drag Zoom Off";
	}
	else {
		drag = true;
		pan = false;
		buttonvalue = "Drag Zoom On";
	}
	
	for(i = 0; i < metriclist.length; i++){
		for (i2 = 0; i2 < chartlist.length; i2++) {
			var chartobj = window["LineChart"+metriclist[i]+chartlist[i2]];
			if(typeof chartobj === 'undefined' || chartobj === null) { continue; }
			chartobj.options.plugins.zoom.zoom.drag = drag;
			chartobj.options.plugins.zoom.pan.enabled = pan;
			button.value = buttonvalue;
			chartobj.update();
		}
	}
}

function ExportCSV() {
	location.href = "ext/modmon/csv/modmondata.zip";
	return 0;
}

function applyRule() {
	var action_script_tmp = "start_modmon";
	document.form.action_script.value = action_script_tmp;
	var restart_time = document.form.action_wait.value*1;
	showLoading();
	document.form.submit();
}

function BuildMetricTable(name,title){
	var charthtml = '<div style="line-height:10px;">&nbsp;</div>';
	charthtml+='<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" id="table_metric_'+name+'">';
	charthtml+='<thead class="collapsibleparent" id="'+name+'">';
	charthtml+='<tr>';
	charthtml+='<td colspan="2">'+title+' (click to expand/collapse)</td>';
	charthtml+='</tr>';
	charthtml+='</thead>';
	charthtml+='<tr>';
	charthtml+='<td colspan="2" align="center" style="padding: 0px;">';
	charthtml+='<div class="collapsiblecontent">';
	charthtml+='<div style="line-height:10px;">&nbsp;</div>';
	charthtml+='<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">';
	charthtml+='<tr>';
	charthtml+='<div style="line-height:10px;">&nbsp;</div>';
	charthtml+='</tr>';
	charthtml+='<thead class="collapsible" id="last24_'+name+'">';
	charthtml+='<tr>';
	charthtml+='<td colspan="2">Last 24 Hours (click to expand/collapse)</td>';
	charthtml+='</tr>';
	charthtml+='</thead>';
	charthtml+='<tr>';
	charthtml+='<td colspan="2" align="center" style="padding: 0px;">';
	charthtml+='<div class="collapsiblecontent">';
	charthtml+='<div style="background-color:#2f3e44;border-radius:10px;width:730px;padding-left:5px;"><canvas id="divLineChart'+name+'daily" height="300" /></div>';
	charthtml+='</div>';
	charthtml+='</td>';
	charthtml+='</tr>';
	charthtml+='</table>';
	charthtml+='<div style="line-height:10px;">&nbsp;</div>';
	charthtml+='<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">';
	charthtml+='<thead class="collapsible" id="last7_'+name+'">';
	charthtml+='<tr>';
	charthtml+='<td colspan="2">Last 7 days (click to expand/collapse)</td>';
	charthtml+='</tr>';
	charthtml+='</thead>';
	charthtml+='<tr>';
	charthtml+='<td colspan="2" align="center" style="padding: 0px;">';
	charthtml+='<div class="collapsiblecontent">';
	charthtml+='<div style="background-color:#2f3e44;border-radius:10px;width:730px;padding-left:5px;"><canvas id="divLineChart'+name+'weekly" height="300" /></div>';
	charthtml+='</div>';
	charthtml+='</td>';
	charthtml+='</tr>';
	charthtml+='</table>';
	charthtml+='<div style="line-height:10px;">&nbsp;</div>';
	charthtml+='<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">';
	charthtml+='<thead class="collapsible" id="last30_'+name+'">';
	charthtml+='<tr>';
	charthtml+='<td colspan="2">Last 30 days (click to expand/collapse)</td>';
	charthtml+='</tr>';
	charthtml+='</thead>';
	charthtml+='<tr>';
	charthtml+='<td colspan="2" align="center" style="padding: 0px;">';
	charthtml+='<div class="collapsiblecontent">';
	charthtml+='<div style="background-color:#2f3e44;border-radius:10px;width:730px;padding-left:5px;"><canvas id="divLineChart'+name+'monthly" height="300" /></div>';
	charthtml+='</div>';
	charthtml+='</td>';
	charthtml+='</tr>';
	charthtml+='</table>';
	charthtml+='</div>';
	charthtml+='</td>';
	charthtml+='</tr>';
	charthtml+='</table>';
	charthtml+='<div style="line-height:10px;">&nbsp;</div>';
	return charthtml;
}

function BuildChannelFilterTable(){
	var channelhtml = '<div style="line-height:10px;">&nbsp;</div>';
	channelhtml+='<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" id="table_filters">';
	channelhtml+='<thead class="collapsibleparent" id="mod_filters">';
	channelhtml+='<tr>';
	channelhtml+='<td colspan="2">Chart Filters (click to expand/collapse)</td>';
	channelhtml+='</tr>';
	channelhtml+='</thead>';
	channelhtml+='<tr>';
	channelhtml+='<td colspan="2" align="center" style="padding: 0px;">';
	channelhtml+='<div class="collapsiblecontent">';
	channelhtml+='<div style="line-height:10px;">&nbsp;</div>';
	channelhtml+=BuildChannelFilterRow("rx","Downstream Channels",RxCount);
	channelhtml+=BuildChannelFilterRow("tx","Upstream Channels",TxCount);
	channelhtml+='</div>';
	channelhtml+='</td>';
	channelhtml+='</tr>';
	channelhtml+='</table>';
	channelhtml+='<div style="line-height:10px;">&nbsp;</div>';
	return channelhtml;
}

function BuildChannelFilterRow(rxtx,title,channelcount){
	var channelhtml='';
	channelhtml+='<div style="line-height:10px;">&nbsp;</div>';
	channelhtml+='<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" id="table_'+rxtx+'">';
	channelhtml+='<thead id="channel_table_'+rxtx+'stream">';
	channelhtml+='<tr><td colspan="12">'+title+'</td></tr>';
	channelhtml+='</thead>';
	channelhtml+='<tr>';
	channelhtml+='<td colspan="12" align="center" style="padding: 0px;">';
	channelhtml+='<table width="100%" border="0" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" style="border: 0px;">';
	channelhtml+='<col style="width:60px;">';
	channelhtml+='<col style="width:60px;">';
	channelhtml+='<col style="width:60px;">';
	channelhtml+='<col style="width:60px;">';
	channelhtml+='<col style="width:60px;">';
	channelhtml+='<col style="width:60px;">';
	channelhtml+='<col style="width:60px;">';
	channelhtml+='<col style="width:60px;">';
	channelhtml+='<col style="width:60px;">';
	channelhtml+='<col style="width:60px;">';
	channelhtml+='<col style="width:60px;">';
	channelhtml+='<col style="width:60px;">';
	channelhtml+='<col style="width:60px;">';
	channelhtml+='<tr>';
	for (channelno = 1; channelno < channelcount+1; channelno++) {
		channelhtml+='<td class="channelcell"><label class="radio"><input type="checkbox" onchange="ToggleDataset(this);" name="'+rxtx+'opt'+channelno+'" id="'+rxtx+'opt'+channelno+'" checked/>Ch. '+channelno+'</label></td>';
		if(channelno % 12 == 0){
			channelhtml+='</tr><tr>';
		}
	}
	channelhtml+='</tr>';
	channelhtml+='</table>';
	channelhtml+='</div>';
	channelhtml+='</td>';
	channelhtml+='</tr>';
	channelhtml+='<tr class="apply_gen" valign="top" height="35px" id="row_'+rxtx+'_buttons">';
	channelhtml+='<td>';
	channelhtml+='<input type="button" onclick="SetAllChannels(this,true);" value="Select all" class="button_gen" name="'+rxtx+'_button_select" id="'+rxtx+'_button_select">';
	channelhtml+='&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
	channelhtml+='<input type="button" onclick="SetAllChannels(this,false);" value="Clear all" class="button_gen" name="'+rxtx+'_button_clear" id="'+rxtx+'_button_clear">';
	channelhtml+='</td></tr>';
	channelhtml+='</table>';
	return channelhtml;
}

function ToggleDataset(checkbox){
	for(i = 0; i < metriclist.length; i++){
		for (i2 = 0; i2 < chartlist.length; i2++) {
			if(metriclist[i].toLowerCase().indexOf(checkbox.id.substring(0,2)) != -1){
				window["LineChart"+metriclist[i]+chartlist[i2]].getDatasetMeta((checkbox.id.substring(5)*1)-1).hidden = ! checkbox.checked;
				window["LineChart"+metriclist[i]+chartlist[i2]].update();
			}
		}
	}
}

function SetAllChannels(button,setclear){
	var rxtx = "";
	var startindex = 0;
	if(setclear == false){startindex=1;}
	if(button.id.substring(0,2) == "rx"){rxtx="Rx";}
	else{rxtx="Tx";}
	if(startindex == 1){$j( "#"+rxtx.toLowerCase()+"opt1" ).prop("checked",true);}
	for(i = 1 + startindex; i < window[rxtx+"Count"]+1; i++){
		$j( "#"+rxtx.toLowerCase()+"opt"+i ).prop("checked",setclear);
	}
	for(i = 0; i < metriclist.length; i++){
		for (i2 = 0; i2 < chartlist.length; i2++) {
			if(metriclist[i].indexOf(rxtx) != -1){
				for(i3 = 0; i3 < window[rxtx+"Count"]; i3++){
					window["LineChart"+metriclist[i]+chartlist[i2]].getDatasetMeta(i3).hidden = ! $j( "#"+rxtx.toLowerCase()+"opt"+(i3+1) ).prop("checked");
				}
				window["LineChart"+metriclist[i]+chartlist[i2]].update();
			}
		}
	}
}

function AddEventHandlers(){
	var coll = document.getElementsByClassName("collapsible");
	var i;
	var height = 0;

	for (i = 0; i < coll.length; i++) {
		coll[i].addEventListener("click", function() {
			this.classList.toggle("active");
			var content = this.nextElementSibling.firstElementChild.firstElementChild.firstElementChild;
			if (content.style.maxHeight){
					content.style.maxHeight = null;
					SetCookie(this.id,"collapsed");
			} else {
					content.style.maxHeight = content.scrollHeight + "px";
					this.parentElement.parentElement.style.maxHeight = (this.parentElement.parentElement.style.maxHeight.substring(0,this.parentElement.parentElement.style.maxHeight.length-2)*1) + content.scrollHeight + "px";
					SetCookie(this.id,"expanded");
				}
		});
		
		if(GetCookie(coll[i].id) == "expanded" || GetCookie(coll[i].id) == ""){
			coll[i].click();
		}
		height=(coll[i].nextElementSibling.firstElementChild.firstElementChild.firstElementChild.style.maxHeight.substring(0,coll[i].nextElementSibling.firstElementChild.firstElementChild.firstElementChild.style.maxHeight.length-2)*1) + height + 21 + 10 + 10 + 10 + 10 + 10;
	}
	
	var coll = document.getElementsByClassName("collapsibleparent");
	var i;
	
	for (i = 0; i < coll.length; i++) {
		coll[i].addEventListener("click", function() {
			this.classList.toggle("active");
			var content = this.nextElementSibling.firstElementChild.firstElementChild.firstElementChild;
			if (content.style.maxHeight){
				content.style.maxHeight = null;
				SetCookie(this.id,"collapsed");
			} else {
				content.style.maxHeight = content.scrollHeight + "px";
				SetCookie(this.id,"expanded");
			}
		});
		if(GetCookie(coll[i].id) == "expanded" || GetCookie(coll[i].id) == ""){
			coll[i].nextElementSibling.firstElementChild.firstElementChild.firstElementChild.style.maxHeight = height + "px";
		} else {
			coll[i].nextElementSibling.firstElementChild.firstElementChild.firstElementChild.style.maxHeight = null;
		}
	}
}

</script>
</head>
<body onload="initial();" onunload="return unload_body();">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>
<iframe name="hidden_frame" id="hidden_frame" src="about:blank" width="0" height="0" frameborder="0"></iframe>
<form method="post" name="form" id="ruleForm" action="/start_apply.htm" target="hidden_frame">
<input type="hidden" name="action_script" value="start_modmon">
<input type="hidden" name="current_page" value="">
<input type="hidden" name="next_page" value="">
<input type="hidden" name="modified" value="0">
<input type="hidden" name="action_mode" value="apply">
<input type="hidden" name="action_wait" value="30">
<input type="hidden" name="first_time" value="">
<input type="hidden" name="SystemCmd" value="">
<input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get("preferred_lang"); %>">
<input type="hidden" name="firmver" value="<% nvram_get("firmver"); %>">
<input type="hidden" name="amng_custom" id="amng_custom" value="">
<table class="content" align="center" cellpadding="0" cellspacing="0">
<tr>
<td width="17">&nbsp;</td>
<td valign="top" width="202">
<div id="mainMenu"></div>
<div id="subMenu"></div></td>
<td valign="top">
<div id="tabMenu" class="submenuBlock"></div>
<table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
<tr>
<td valign="top">
<table width="760px" border="0" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTitle" id="FormTitle">
<tbody>
<tr bgcolor="#4D595D">
<td valign="top">
<div>&nbsp;</div>
<div class="formfonttitle" id="statstitle">Cable Modem Stats</div>
<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" style="border:0px;" id="table_buttons">
<tr class="apply_gen" valign="top" height="35px" id="row_buttons">
<td style="background-color:rgb(77, 89, 93);border:0px;">
<input type="button" onclick="DragZoom(this);" value="Drag Zoom On" class="button_gen" name="button">
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<input type="button" onclick="ResetZoom();" value="Reset Zoom" class="button_gen" name="button">
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<input type="button" onclick="ToggleLines();" value="Toggle Lines" class="button_gen" name="button">
</td>
</tr>
</table>
<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" style="border:0px;" id="table_buttons2">
<tr class="apply_gen" valign="top" height="35px">
<td style="background-color:rgb(77, 89, 93);border:0px;">
<input type="button" onclick="applyRule();" value="Update stats now" class="button_gen" name="button">
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<input type="button" onclick="ExportCSV();" value="Export to CSV" class="button_gen" name="button">
</td>
</tr>
<!-- Chart legend filters inserted here -->
</table>
<!-- Charts inserted here -->
</td>
</tr>
</tbody>
</table>
</td>
</tr>
</table>
</td>
</tr>
</table>
</form>
<div id="footer">
</div>
</body>
</html>
