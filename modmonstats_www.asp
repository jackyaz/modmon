<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="X-UA-Compatible" content="IE=Edge"/>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">
<link rel="shortcut icon" href="images/favicon.png">
<link rel="icon" href="images/favicon.png">
<title>Superhub Monitoring</title>
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
<script language="JavaScript" type="text/javascript" src="/js/jquery.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/moment.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/chart.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/hammerjs.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/chartjs-plugin-zoom.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/chartjs-plugin-annotation.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/chartjs-plugin-datasource.js"></script>
<script language="JavaScript" type="text/javascript" src="/state.js"></script>
<script language="JavaScript" type="text/javascript" src="/general.js"></script>
<script language="JavaScript" type="text/javascript" src="/popup.js"></script>
<script language="JavaScript" type="text/javascript" src="/help.js"></script>
<script language="JavaScript" type="text/javascript" src="/tmhist.js"></script>
<script language="JavaScript" type="text/javascript" src="/tmmenu.js"></script>
<script language="JavaScript" type="text/javascript" src="/client_function.js"></script>
<script language="JavaScript" type="text/javascript" src="/validator.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/modmon/modstatsdata.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/modmon/modstatstext.js"></script>
<script>
// Keep the real data in a seperate object called allData
// Put only that part of allData in the dataset to optimize zoom/pan performance
// Author: Evert van der Weit - 2018

function filterData(chartInstance) {
	var datasets = chartInstance.data.datasets;
	var originalDatasets = chartInstance.data.allData;
	var chartOptions = chartInstance.options.scales.xAxes[0];
	
	var startX = chartOptions.time.min
	var endX = chartOptions.time.max
	if(typeof originalDatasets === 'undefined' || originalDatasets === null) { return; }
	for(var i = 0; i < originalDatasets.length; i++) {
		var dataset = datasets[i];
		var originalData = originalDatasets[i];
		
		if (!originalData.length) break
		
		var s = startX;
		var e = endX;
		var sI = null;
		var eI = null;
		
		for (var j = 0; j < originalData.length; j++) {
			if ((sI==null) && originalData[j].x > s) {
				sI = j
			}
			if ((eI==null) && originalData[j].x > e) {
				eI = j
			}
		}
		if (sI==null) sI = 0
		if (originalData[originalData.length - 1].x < s) eI = 0
			else if (eI==null) eI = originalData.length
		
		dataset.data = originalData.slice(sI, eI)
	}
}

var datafilterPlugin = {
	beforeUpdate: function(chartInstance) {
		filterData(chartInstance)
	}
}
</script>
<script>
var ShowLines=GetCookie("ShowLines");

var metriclist = ["RxPwr","RxSnr","RxPstRs","TxPwr","TxT3Out","TxT4Out"];
var titlelist = ["Downstream Power","Downstream SNR","Post-RS Errors","Upstream Power","T3 Timeouts","T4 Timeouts"];
var measureunitlist = ["dBmV","dB","","dBmV","",""];
var chartlist = ["daily","weekly","monthly"];
var timeunitlist = ["hour","day","day"];
var intervallist = [24,7,30];

Chart.defaults.global.defaultFontColor = "#CCC";
Chart.Tooltip.positioners.cursor = function(chartElements, coordinates) {
	return coordinates;
};

Array.max = function( array ){
	return Math.max.apply( Math, array );
};

Array.min = function( array ){
	return Math.min.apply( Math, array );
};

var RxCount,TxCount,RxColours,TxColours;
RxColours = [];
TxColours = [];

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
	ctx.fillStyle = 'white'
	ctx.fillText('No data to display', 365, 150);
	ctx.restore();
}

function Draw_Chart(txtchartname,txttitle,txtunity,txtunitx,numunitx){
	var objchartname=window["LineChart"+txtchartname];
	var objdataname=window[txtchartname+"size"];
	if(typeof objdataname === 'undefined' || objdataname === null) { Draw_Chart_NoData(txtchartname); return; }
	if (objdataname == 0) { Draw_Chart_NoData(txtchartname); return; }
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
					label: function (tooltipItem, data) { return data.datasets[tooltipItem.datasetIndex].label + ": " + data.datasets[tooltipItem.datasetIndex].data[tooltipItem.index].y.toString() + ' ' + txtunity;}
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
					max: getLimit(txtchartname,"y","max",false) + getLimit(txtchartname,"y","max",false)*0.1,
					callback: function (value, index, values) {
						return round(value,3).toFixed(3) + ' ' + txtunity;
					}
				},
			}]
		},
		plugins: {
			zoom: {
				pan: {
					enabled: true,
					mode: 'xy',
					rangeMin: {
						x: new Date().getTime() - (factor * numunitx),
						y: getLimit(txtchartname,"y","min",false) - Math.sqrt(Math.pow(getLimit(txtchartname,"y","min",false),2))*0.1,
					},
					rangeMax: {
						x: new Date().getTime(),
						y: getLimit(txtchartname,"y","max",false) + getLimit(txtchartname,"y","max",false)*0.1,
					},
				},
				zoom: {
					enabled: true,
					mode: 'xy',
					rangeMin: {
						x: new Date().getTime() - (factor * numunitx),
						y: getLimit(txtchartname,"y","min",false) - Math.sqrt(Math.pow(getLimit(txtchartname,"y","min",false),2))*0.1,
					},
					rangeMax: {
						x: new Date().getTime(),
						y: getLimit(txtchartname,"y","max",false) + getLimit(txtchartname,"y","max",false)*0.1,
					},
					speed: 0.1
				},
			},
			datasource: {
				type: 'csv',
				url: '/ext/modmon/csv/'+txtchartname+'.htm',
				delimiter: ',',
				rowMapping: 'datapoint',
				datapointLabelMapping: {
					_dataset: 'ChannelNum',
					x: 'Time',
					y: 'Value'
				}
			}
		},
		annotation: {
			drawTime: 'afterDatasetsDraw',
			annotations: [{
				//id: 'avgline',
				type: ShowLines,
				mode: 'horizontal',
				scaleID: 'y-axis-0',
				value: getAverage(txtchartname),
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
					content: "Avg=" + round(getAverage(txtchartname),3).toFixed(3)+txtunity,
				}
			},
			{
				//id: 'maxline',
				type: ShowLines,
				mode: 'horizontal',
				scaleID: 'y-axis-0',
				value: getLimit(txtchartname,"y","max",true),
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
					content: "Max=" + round(getLimit(txtchartname,"y","max",true),3).toFixed(3)+txtunity,
				}
			},
			{
				//id: 'minline',
				type: ShowLines,
				mode: 'horizontal',
				scaleID: 'y-axis-0',
				value: getLimit(txtchartname,"y","min",true),
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
					content: "Min=" + round(getLimit(txtchartname,"y","min",true),3).toFixed(3)+txtunity,
				}
			}]
		}
	};
	var lineDataset = {
		datasets: getDataSets(txtchartname, txttitle)
	};
	objchartname = new Chart(ctx, {
		type: 'line',
		plugins: [ChartDataSource,datafilterPlugin],
		data: lineDataset,
		options: lineOptions
	});
	window["LineChart"+txtchartname]=objchartname;
}

function getDataSets(txtchartname,txttitle) {
	var datasets = [];
	colourname="#fc8500";
	var objdataname=window[txtchartname+"size"];
	
	for(var i = 0; i < objdataname; i++) {
		if(txtchartname.indexOf("Rx") != -1){
			colourname=RxColours[i];
		}
		else {
			colourname=TxColours[i];
		}
		datasets.push({ label: "Ch. " + (i+1).toString(), borderWidth: 1, pointRadius: 1, lineTension: 0, fill: false, backgroundColor: colourname, borderColor: colourname});
	}
	return datasets;
}

function getLimit(datasetname,axis,maxmin,isannotation) {
	var limit = 0;
	var objdataname=window[datasetname+maxmin];
	if(typeof objdataname === 'undefined' || objdataname === null) { limit = 0; }
	else {limit = objdataname;}
	if(maxmin == "max" && limit == 0 && isannotation == false){
		limit = 1;
	}
	return limit;
}

function getAverage(datasetname) {
	var avg = 0;
	var objdataname=window[datasetname+"avg"];
	if(typeof objdataname === 'undefined' || objdataname === null) { avg = 0; }
	else {avg = objdataname;}
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

function ToggleLines() {
	if(ShowLines == ""){
		ShowLines = "line";
		SetCookie("ShowLines","line")
	}
	else {
		ShowLines = "";
		SetCookie("ShowLines","")
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

function SetRxTxColours(){
	RxColours = poolColors(RxCount);
	TxColours = poolColors(TxCount);
}

function GetMaxChannels(){
	var RxCountArray = [];
	var TxCountArray = [];
	for(i = 0; i < metriclist.length; i++){
		for (i2 = 0; i2 < chartlist.length; i2++) {
			varname=metriclist[i]+chartlist[i2]+"size";
			var objdataname=window[varname];
			if(varname.indexOf("Rx") != -1){
				RxCountArray.push(objdataname);
			}
			else {
				TxCountArray.push(objdataname);
			}
		}
	}
	RxCount = Array.max(RxCountArray);
	TxCount = Array.max(TxCountArray);
}

function RedrawAllCharts() {
	for(i = 0; i < metriclist.length; i++){
		for (i2 = 0; i2 < chartlist.length; i2++) {
			Draw_Chart(metriclist[i]+chartlist[i2],titlelist[i],measureunitlist[i],timeunitlist[i2],intervallist[i2]);
		}
	}
}

function GetCookie(cookiename) {
	var s;
	if ((s = cookie.get("mod_"+cookiename)) != null) {
		return cookie.get("mod_"+cookiename);
	}
	else {
		return ""
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
		$("#table_buttons").after(BuildMetricTable(metriclist[i],titlelist[i]));
	}
	
	metriclist.reverse();
	titlelist.reverse();
	
	GetMaxChannels();
	
	$("#table_buttons").after(BuildChannelFilterTable());
	
	AddEventHandlers();
	SetRxTxColours();
	RedrawAllCharts();
	SetModStatsTitle();
}

function reload() {
	location.reload(true);
}

function ResetZoom(){
	for(i = 0; i < metriclist.length; i++){
		for (i2 = 0; i2 < chartlist.length; i2++) {
			window["LineChart"+metriclist[i]+chartlist[i2]].resetZoom();
		}
	}
}

function applyRule() {
	var action_script_tmp = "start_modmon";
	document.form.action_script.value = action_script_tmp;
	var restart_time = document.form.action_wait.value*1;
	parent.showLoading(restart_time, "waiting");
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
	channelhtml+='<thead id="channel_table_downstream">';
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
	for(i = 1 + startindex; i < window[rxtx+"Count"]+1; i++){
		$( "#"+rxtx.toLowerCase()+"opt"+i ).prop("checked",setclear);
	}
	for(i = 0; i < metriclist.length; i++){
		for (i2 = 0; i2 < chartlist.length; i2++) {
			if(metriclist[i].indexOf(rxtx) != -1){
				for(i3 = 0 + startindex; i3 < window[rxtx+"Count"]; i3++){
					window["LineChart"+metriclist[i]+chartlist[i2]].getDatasetMeta(i3).hidden = ! setclear;
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
					SetCookie(this.id,"collapsed")
			} else {
					content.style.maxHeight = content.scrollHeight + "px";
					this.parentElement.parentElement.style.maxHeight = (this.parentElement.parentElement.style.maxHeight.substring(0,this.parentElement.parentElement.style.maxHeight.length-2)*1) + content.scrollHeight + "px";
					SetCookie(this.id,"expanded")
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
				SetCookie(this.id,"collapsed")
			} else {
				content.style.maxHeight = content.scrollHeight + "px";
				SetCookie(this.id,"expanded")
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
<div class="formfonttitle" id="statstitle">Superhub 3 Stats</div>
<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" style="border:0px;" id="table_buttons">
<tr class="apply_gen" valign="top" height="35px" id="row_buttons">
<td style="background-color:rgb(77, 89, 93);border:0px;">
<input type="button" onclick="applyRule();" value="Update stats now" class="button_gen" name="button">
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<input type="button" onclick="ResetZoom();" value="Reset Zoom" class="button_gen" name="button">
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<input type="button" onclick="ToggleLines();" value="Toggle Lines" class="button_gen" name="button">
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
