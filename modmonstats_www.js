var $j = jQuery.noConflict(); //avoid conflicts on John's fork (state.js)
var maxNoCharts = 18;
var currentNoCharts = 0;

var ShowLines=GetCookie("ShowLines","string");

var DragZoom = true;
var ChartPan = false;

var metriclist = ["RxPwr","RxSnr","RxPstRs","TxPwr","TxT3Out","TxT4Out"];
var titlelist = ["Downstream Power","Downstream SNR","Post-RS Errors","Upstream Power","T3 Timeouts","T4 Timeouts"];
var measureunitlist = ["dBmV","dB","","dBmV","",""];
var chartlist = ["daily","weekly","monthly"];
var timeunitlist = ["hour","day","day"];
var intervallist = [24,7,30];

var RxCount,TxCount,RxColours,TxColours;
var chartColours = ['rgba(24,113,65, 1)','rgba(205,117,81, 1)','rgba(230,55,90, 1)','rgba(5,206,61, 1)','rgba(131,4,176, 1)','rgba(196,145,14, 1)','rgba(169,229,70, 1)','rgba(25,64,183, 1)','rgba(23,153,199, 1)','rgba(223,46,248, 1)','rgba(240,92,214, 1)','rgba(123,137,211, 1)','rgba(141,68,215, 1)','rgba(74,210,128, 1)','rgba(223,247,240, 1)','rgba(226,27,93, 1)','rgba(253,78,222, 1)','rgba(63,192,102, 1)','rgba(82,66,162, 1)','rgba(65,190,78, 1)','rgba(154,113,118, 1)','rgba(222,98,201, 1)','rgba(198,186,137, 1)','rgba(178,45,245, 1)','rgba(95,245,50, 1)','rgba(247,142,18, 1)','rgba(103,152,205, 1)','rgba(39,104,180, 1)','rgba(132,165,5, 1)','rgba(8,249,253, 1)','rgba(227,170,207, 1)','rgba(196,70,76, 1)','rgba(11,197,73, 1)','rgba(127,50,202, 1)','rgba(33,248,170, 1)','rgba(17,216,225, 1)','rgba(176,123,12, 1)','rgba(181,111,105, 1)','rgba(104,122,233, 1)','rgba(217,102,107, 1)','rgba(188,174,88, 1)','rgba(30,224,236, 1)','rgba(169,39,247, 1)','rgba(251,86,116, 1)','rgba(217,163,80, 1)','rgba(155,120,34, 1)','rgba(82,124,118, 1)','rgba(102,89,62, 1)','rgba(48,126,7, 1)','rgba(48,118,188, 1)','rgba(223,246,227, 1)','rgba(152,11,129, 1)','rgba(66,97,241, 1)','rgba(32,113,78, 1)','rgba(83,142,226, 1)','rgba(210,105,250, 1)','rgba(125,115,7, 1)','rgba(198,37,71, 1)','rgba(253,99,153, 1)','rgba(171,225,78, 1)','rgba(66,82,121, 1)','rgba(5,82,115, 1)','rgba(22,62,141, 1)','rgba(135,59,161, 1)','rgba(20,223,59, 1)','rgba(17,206,99, 1)','rgba(142,162,133, 1)','rgba(206,76,155, 1)','rgba(131,87,41, 1)','rgba(199,234,37, 1)','rgba(176,94,156, 1)','rgba(13,58,185, 1)','rgba(147,19,178, 1)','rgba(48,203,55, 1)','rgba(250,31,116, 1)','rgba(138,9,168, 1)','rgba(90,208,244, 1)','rgba(128,110,93, 1)','rgba(222,202,95, 1)','rgba(189,78,184, 1)','rgba(122,41,65, 1)','rgba(243,176,73, 1)','rgba(23,123,71, 1)','rgba(209,50,12, 1)','rgba(253,218,100, 1)','rgba(214,18,185, 1)','rgba(31,254,215, 1)','rgba(191,53,224, 1)','rgba(117,197,238, 1)','rgba(183,123,104, 1)','rgba(88,34,248, 1)','rgba(124,157,92, 1)','rgba(76,59,160, 1)','rgba(143,235,139, 1)','rgba(59,85,112, 1)','rgba(233,54,148, 1)','rgba(244,176,124, 1)','rgba(246,246,104, 1)','rgba(169,171,44, 1)','rgba(240,3,14, 1)'];

Chart.defaults.global.defaultFontColor = "#CCC";
Chart.Tooltip.positioners.cursor = function(chartElements, coordinates){
	return coordinates;
};

function keyHandler(e){
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
	document.getElementById("divLineChart_"+txtchartname).width="730";
	document.getElementById("divLineChart_"+txtchartname).height="500";
	document.getElementById("divLineChart_"+txtchartname).style.width="730px";
	document.getElementById("divLineChart_"+txtchartname).style.height="500px";
	var ctx = document.getElementById("divLineChart_"+txtchartname).getContext("2d");
	ctx.save();
	ctx.textAlign = 'center';
	ctx.textBaseline = 'middle';
	ctx.font = "normal normal bolder 48px Arial";
	ctx.fillStyle = 'white';
	ctx.fillText('No data to display', 365, 250);
	ctx.restore();
}

function Draw_Chart(txtchartname,txttitle,txtunity){
	var chartperiod = getChartPeriod($j("#" + txtchartname + "_Period option:selected").val());
	var txtunitx = timeunitlist[$j("#" + txtchartname + "_Period option:selected").val()];
	var numunitx = intervallist[$j("#" + txtchartname + "_Period option:selected").val()];
	var dataobject = window[txtchartname+chartperiod];
	
	if(typeof dataobject === 'undefined' || dataobject === null){ Draw_Chart_NoData(txtchartname); return; }
	if (dataobject.length == 0){ Draw_Chart_NoData(txtchartname); return; }
	
	var unique = [];
	var chartChannels = [];
	for( let i = 0; i < dataobject.length; i++ ){
		if( !unique[dataobject[i].Channel]){
			chartChannels.push(dataobject[i].Channel);
			unique[dataobject[i].Channel] = 1;
		}
	}
	
	var chartLabels = dataobject.map(function(d){return d.Channel});
	var chartData = dataobject.map(function(d){return {x: d.Time, y: d.Value}});
	var objchartname=window["LineChart_"+txtchartname];
	
	var timeaxisformat = getTimeFormat($j("#Time_Format option:selected").val(),"axis");
	var timetooltipformat = getTimeFormat($j("#Time_Format option:selected").val(),"tooltip");
	
	factor=0;
	if (txtunitx=="hour"){
		factor=60*60*1000;
	}
	else if (txtunitx=="day"){
		factor=60*60*24*1000;
	}
	if (objchartname != undefined) objchartname.destroy();
	var ctx = document.getElementById("divLineChart_"+txtchartname).getContext("2d");
	var lineOptions = {
		segmentShowStroke : false,
		segmentStrokeColor : "#000",
		animationEasing : "easeOutQuart",
		animationSteps : 100,
		//animation: {
		//	duration: 0 // general animation time
		//},
		//responsiveAnimationDuration: 0, // animation duration after a resize
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
					title: function (tooltipItem, data){ return (moment(tooltipItem[0].xLabel,"X").format(timetooltipformat)); },
					label: function (tooltipItem, data){ return data.datasets[tooltipItem.datasetIndex].label + ": " + round(data.datasets[tooltipItem.datasetIndex].data[tooltipItem.index].y,3).toFixed(3) + ' ' + txtunity;}
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
				time: {
					parser: "X",
					unit: txtunitx,
					stepSize: 1,
					displayFormats: timeaxisformat
				}
			}],
			yAxes: [{
				gridLines: { display: false, color: "#282828" },
				scaleLabel: { display: false, labelString: txttitle },
				ticks: {
					display: true,
					beginAtZero: startAtZero(txtchartname),
					callback: function (value, index, values){
						return round(value,3).toFixed(3) + ' ' + txtunity;
					}
				},
			}]
		},
		plugins: {
			zoom: {
				pan: {
					enabled: ChartPan,
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
					drag: DragZoom,
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
					position: "right",
					enabled: true,
					xAdjust: 15,
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
					position: "left",
					enabled: true,
					xAdjust: 15,
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
	window["LineChart_"+txtchartname]=objchartname;
}

function getDataSets(txtchartname, objdata, objchannels){
	var datasets = [];
	colourname="#fc8500";
	
	for(var i = 0; i < objchannels.length; i++){
		var channeldata = objdata.filter(function(item){
			return item.Channel == objchannels[i];
		}).map(function(d){return {x: d.Time, y: d.Value}});
		
		datasets.push({ label: objchannels[i], data: channeldata, borderWidth: 1, pointRadius: 1, lineTension: 0, fill: false, backgroundColor: chartColours[i], borderColor: chartColours[i]});
	}
	return datasets;
}

function getLimit(datasetname,axis,maxmin,isannotation){
	var limit=0;
	var values;
	if(axis == "x"){
		values = datasetname.map(function(o){ return o.x } );
	}
	else{
		values = datasetname.map(function(o){ return o.y } );
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

function getAverage(datasetname){
	var total = 0;
	for(var i = 0; i < datasetname.length; i++){
		total += (datasetname[i].y*1);
	}
	var avg = total / datasetname.length;
	return avg;
}

function startAtZero(datasetname){
	var starty = false;
	if(datasetname.indexOf("PstRS") != -1 || datasetname.indexOf("T3Out") != -1 || datasetname.indexOf("T4Out") != -1){
		starty = true;
	}
	return starty;
}

function round(value, decimals){
	return Number(Math.round(value+'e'+decimals)+'e-'+decimals);
}

function getRandomColor(){
	var r = Math.floor(Math.random() * 255);
	var g = Math.floor(Math.random() * 255);
	var b = Math.floor(Math.random() * 255);
	return "rgba(" + r + "," + g + "," + b + ", 1)";
}

function poolColors(a){
	var pool = [];
	for(i = 0; i < a; i++){
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
		var varname="LineChart_"+metriclist[i];
		var channelcount=window[varname].data.datasets.length;
		if(varname.indexOf("Rx") != -1){
			RxCountArray.push(channelcount);
		}
		else{
			TxCountArray.push(channelcount);
		}
	}
	RxCount = Math.max.apply(Math, RxCountArray);
	TxCount = Math.max.apply(Math, TxCountArray);
}

function ToggleLines(){
	if(ShowLines == ""){
		ShowLines = "line";
		SetCookie("ShowLines","line");
	}
	else{
		ShowLines = "";
		SetCookie("ShowLines","");
	}
	for(i = 0; i < metriclist.length; i++){
		for (i3 = 0; i3 < 3; i3++){
			window["LineChart_"+metriclist[i]].options.annotation.annotations[i3].type=ShowLines;
		}
		window["LineChart_"+metriclist[i]].update();
	}
}

function changeChart(e) {
	value = e.value * 1;
	name = e.id.substring(0, e.id.indexOf("_"));
	SetCookie(e.id,value);
	
	if(name == "RxPwr"){
		Draw_Chart("RxPwr",titlelist[0],measureunitlist[0]);
	}
	else if(name == "RxSnr"){
		Draw_Chart("RxSnr",titlelist[1],measureunitlist[1]);
	}
	else if(name == "RxPstRs"){
		Draw_Chart("RxPstRs",titlelist[2],measureunitlist[2]);
	}
	else if(name == "TxPwr"){
		Draw_Chart("TxPwr",titlelist[2],measureunitlist[3]);
	}
	else if(name == "TxT3Out"){
		Draw_Chart("TxT3Out",titlelist[4],measureunitlist[4]);
	}
	else if(name == "TxT4Out"){
		Draw_Chart("TxT4Out",titlelist[5],measureunitlist[5]);
	}
}

function RedrawAllCharts(){
	for(i = 0; i < metriclist.length; i++){
		for (i2 = 0; i2 < chartlist.length; i2++){
			d3.csv("/ext/modmon/csv/"+metriclist[i]+chartlist[i2]+".htm").then(ProcessChart.bind(null,i,i2));
		}
	}
}

function changeAllCharts(e){
	value = e.value * 1;
	name = e.id.substring(0, e.id.indexOf("_"));
	SetCookie(e.id,value);
	for (i = 0; i < metriclist.length; i++){
		Draw_Chart(metriclist[i],titlelist[i],measureunitlist[i]);
	}
}

function getTimeFormat(value,format){
	var timeformat;
	
	if(format == "axis"){
		if (value == 0){
			timeformat = {
				millisecond: 'HH:mm:ss.SSS',
				second: 'HH:mm:ss',
				minute: 'HH:mm',
				hour: 'HH:mm'
			}
		}
		else if (value == 1){
			timeformat = {
				millisecond: 'h:mm:ss.SSS A',
				second: 'h:mm:ss A',
				minute: 'h:mm A',
				hour: 'h A'
			}
		}
	}
	else if(format == "tooltip"){
		if (value == 0){
			timeformat = "YYYY-MM-DD HH:mm:ss";
		}
		else if (value == 1){
			timeformat = "YYYY-MM-DD h:mm:ss A";
		}
	}
	
	return timeformat;
}

function ProcessChart(i1,i2,dataobject){
	window[metriclist[i1]+chartlist[i2]] = dataobject;
	currentNoCharts++;
	
	if(currentNoCharts == maxNoCharts){
		for(i = 0; i < metriclist.length; i++){
			$j("#"+metriclist[i]+"_Period").val(GetCookie(metriclist[i]+"_Period","number"));
			Draw_Chart(metriclist[i],titlelist[i],measureunitlist[i]);
		}
		GetMaxChannels();
		$j("#table_buttons2").after(BuildChannelFilterTable());
		AddEventHandlers();
	}
}

function GetCookie(cookiename,returntype){
	var s;
	if ((s = cookie.get("mod_"+cookiename)) != null){
		return cookie.get("mod_"+cookiename);
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
	cookie.set("mod_"+cookiename, cookievalue, 31);
}

$j.fn.serializeObject = function(){
	var o = custom_settings;
	var a = this.serializeArray();
	$j.each(a, function(){
		if (o[this.name] !== undefined && this.name.indexOf("modmon") != -1 && this.name.indexOf("version") == -1){
			if (!o[this.name].push){
				o[this.name] = [o[this.name]];
			}
			o[this.name].push(this.value || '');
		} else if (this.name.indexOf("modmon") != -1 && this.name.indexOf("version") == -1){
			o[this.name] = this.value || '';
		}
	});
	return o;
};

function SetCurrentPage(){
	document.form.next_page.value = window.location.pathname.substring(1);
	document.form.current_page.value = window.location.pathname.substring(1);
}

function initial(){
	SetCurrentPage();
	LoadCustomSettings();
	show_menu();
	get_conf_file();
	$j("#Time_Format").val(GetCookie("Time_Format","number"));
	ScriptUpdateLayout();
	SetModStatsTitle();
	
	var metrictablehtml="";
	
	for (i = 0; i < metriclist.length; i++){
		metrictablehtml += BuildMetricTable(metriclist[i],titlelist[i],i);
	}
	
	$j("#table_buttons2").after(metrictablehtml);
	
	RedrawAllCharts();
}

function ScriptUpdateLayout(){
	var localver = GetVersionNumber("local");
	var serverver = GetVersionNumber("server");
	$j("#scripttitle").text($j("#scripttitle").text()+" - "+localver);
	$j("#modmon_version_local").text(localver);
	
	if (localver != serverver && serverver != "N/A"){
		$j("#modmon_version_server").text("Updated version available: "+serverver);
		showhide("btnChkUpdate", false);
		showhide("modmon_version_server", true);
		showhide("btnDoUpdate", true);
	}
}

function reload(){
	location.reload(true);
}

function getChartPeriod(period){
	var chartperiod = "daily";
	if (period == 0) chartperiod = "daily";
	else if (period == 1) chartperiod = "weekly";
	else if (period == 2) chartperiod = "monthly";
	return chartperiod;
}

function ResetZoom(){
	for(i = 0; i < metriclist.length; i++){
		var chartobj = window["LineChart_"+metriclist[i]];
		if(typeof chartobj === 'undefined' || chartobj === null){ continue; }
		chartobj.resetZoom();
	}
}

function ToggleDragZoom(button){
	var drag = true;
	var pan = false;
	var buttonvalue = "";
	if(button.value.indexOf("On") != -1){
		drag = false;
		pan = true;
		DragZoom = false;
		ChartPan = true;
		buttonvalue = "Drag Zoom Off";
	}
	else{
		drag = true;
		pan = false;
		DragZoom = true;
		ChartPan = false;
		buttonvalue = "Drag Zoom On";
	}
	
	for(i = 0; i < metriclist.length; i++){
		var chartobj = window["LineChart_"+metriclist[i]];
		if(typeof chartobj === 'undefined' || chartobj === null){ continue; }
		chartobj.options.plugins.zoom.zoom.drag = drag;
		chartobj.options.plugins.zoom.pan.enabled = pan;
		button.value = buttonvalue;
		chartobj.update();
	}
}

function ExportCSV(){
	location.href = "ext/modmon/csv/modmondata.zip";
	return 0;
}

function update_status(){
	$j.ajax({
		url: '/ext/modmon/detect_update.js',
		dataType: 'script',
		timeout: 3000,
		error:	function(xhr){
			setTimeout('update_status();', 1000);
		},
		success: function(){
			if (updatestatus == "InProgress"){
				setTimeout('update_status();', 1000);
			}
			else{
				document.getElementById("imgChkUpdate").style.display = "none";
				showhide("modmon_version_server", true);
				if(updatestatus != "None"){
					$j("#modmon_version_server").text("Updated version available: "+updatestatus);
					showhide("btnChkUpdate", false);
					showhide("btnDoUpdate", true);
				}
				else{
					$j("#modmon_version_server").text("No update available");
					showhide("btnChkUpdate", true);
					showhide("btnDoUpdate", false);
				}
			}
		}
	});
}

function CheckUpdate(){
	showhide("btnChkUpdate", false);
	document.formChkVer.action_script.value="start_modmoncheckupdate"
	document.formChkVer.submit();
	document.getElementById("imgChkUpdate").style.display = "";
	setTimeout("update_status();", 2000);
}

function DoUpdate(){
	var action_script_tmp = "start_modmondoupdate";
	document.form.action_script.value = action_script_tmp;
	var restart_time = 10;
	document.form.action_wait.value = restart_time;
	showLoading();
	document.form.submit();
}

function applyRule(){
	document.getElementById('amng_custom').value = JSON.stringify($j('form').serializeObject())
	var action_script_tmp = "start_modmonconfig";
	document.form.action_script.value = action_script_tmp;
	var restart_time = 5;
	document.form.action_wait.value = restart_time;
	showLoading();
	document.form.submit();
}

function UpdateStats(){
	var action_script_tmp = "start_modmon";
	var restart_time = 10;
	document.form.action_wait.value = restart_time;
	showLoading();
	document.form.submit();
}

function GetVersionNumber(versiontype){
	var versionprop;
	if(versiontype == "local"){
		versionprop = custom_settings.modmon_version_local;
	}
	else if(versiontype == "server"){
		versionprop = custom_settings.modmon_version_server;
	}
	
	if(typeof versionprop == 'undefined' || versionprop == null){
		return "N/A";
	}
	else{
		return versionprop;
	}
}

function get_conf_file(){
	$j.ajax({
		url: '/ext/modmon/config.htm',
		dataType: 'text',
		error: function(xhr){
			setTimeout("get_conf_file();", 1000);
		},
		success: function(data){
			var configdata=data.split("\n");
			configdata = configdata.filter(Boolean);
			
			for (var i = 0; i < configdata.length; i++){
				if (configdata[i].indexOf("OUTPUTDATAMODE") != -1){
					document.form.modmon_outputdatamode.value=configdata[i].split("=")[1].replace(/(\r\n|\n|\r)/gm,"");
				}
				else if (configdata[i].indexOf("OUTPUTTIMEMODE") != -1){
					document.form.modmon_outputtimemode.value=configdata[i].split("=")[1].replace(/(\r\n|\n|\r)/gm,"");
				}
				else if (configdata[i].indexOf("STORAGELOCATION") != -1){
					document.form.modmon_storagelocation.value=configdata[i].split("=")[1].replace(/(\r\n|\n|\r)/gm,"");
				}
				else if (configdata[i].indexOf("FIXTXPWR") != -1){
					document.form.modmon_fixtxpwr.value=configdata[i].split("=")[1].replace(/(\r\n|\n|\r)/gm,"");
				}
			}
		}
	});
}

function BuildMetricTable(name,title,loopindex){
	var charthtml = '<div style="line-height:10px;">&nbsp;</div>';
	
	if(loopindex == 0){
		charthtml+='<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">';
		charthtml+='<thead class="collapsible-jquery" id="table_charts">';
		charthtml+='<tr>';
		charthtml+='<td>Charts (click to expand/collapse)</td>';
		charthtml+='</tr>';
		charthtml+='</thead>';
		charthtml+='<tr><td align="center" style="padding: 0px;">';
	}
	
	charthtml+='<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" id="table_metric_'+name+'">';
	charthtml+='<thead class="collapsible-jquery" id="'+name+'">';
	charthtml+='<tr>';
	charthtml+='<td colspan="2">'+title+' (click to expand/collapse)</td>';
	charthtml+='</tr>';
	charthtml+='</thead>';
	charthtml+='<tr class="even">';
	charthtml+='<th width="40%">Period to display</th>';
	charthtml+='<td>';
	charthtml+='<select style="width:125px" class="input_option" onchange="changeChart(this)" id="'+name+'_Period">';
	charthtml+='<option value="0">Last 24 hours</option>';
	charthtml+='<option value="1">Last 7 days</option>';
	charthtml+='<option value="2">Last 30 days</option>';
	charthtml+='</select>';
	charthtml+='</td>';
	charthtml+='</tr>';
	charthtml+='<tr>';
	charthtml+='<td colspan="2" align="center" style="padding: 0px;">';
	charthtml+='<div style="background-color:#2f3e44;border-radius:10px;width:730px;padding-left:5px;"><canvas id="divLineChart_'+name+'" height="500" /></div>';
	charthtml+='</td>';
	charthtml+='</tr>';
	charthtml+='</table>';
	
	if(loopindex == metriclist.length-1){
		charthtml+='</td>';
		charthtml+='</tr>';
		charthtml+='</table>';
	}
	
	return charthtml;
}

function BuildChannelFilterTable(){
	var channelhtml = '<div style="line-height:10px;">&nbsp;</div>';
	channelhtml+='<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" id="table_filters">';
	channelhtml+='<thead class="collapsible-jquery" id="mod_filters">';
	channelhtml+='<tr>';
	channelhtml+='<td colspan="2">Chart Filters (click to expand/collapse)</td>';
	channelhtml+='</tr>';
	channelhtml+='</thead>';
	channelhtml+='<tr>';
	channelhtml+='<td colspan="2" align="center" style="padding: 0px;">';
	channelhtml+=BuildChannelFilterRow("rx","Downstream Channels",RxCount);
	channelhtml+=BuildChannelFilterRow("tx","Upstream Channels",TxCount);
	channelhtml+='</td>';
	channelhtml+='</tr>';
	channelhtml+='</table>';
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
	for (channelno = 1; channelno < channelcount+1; channelno++){
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
		if(metriclist[i].toLowerCase().indexOf(checkbox.id.substring(0,2)) != -1){
			window["LineChart_"+metriclist[i]].getDatasetMeta((checkbox.id.substring(5)*1)-1).hidden = ! checkbox.checked;
			window["LineChart_"+metriclist[i]].update();
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
		if(metriclist[i].indexOf(rxtx) != -1){
			for(i3 = 0; i3 < window[rxtx+"Count"]; i3++){
				window["LineChart_"+metriclist[i]].getDatasetMeta(i3).hidden = ! $j( "#"+rxtx.toLowerCase()+"opt"+(i3+1) ).prop("checked");
			}
			window["LineChart_"+metriclist[i]].update();
		}
	}
}

function AddEventHandlers(){
	$j(".collapsible-jquery").click(function(){
		$j(this).siblings().toggle("fast",function(){
			if($j(this).css("display") == "none"){
				SetCookie($j(this).siblings()[0].id,"collapsed");
			}
			else{
				SetCookie($j(this).siblings()[0].id,"expanded");
			}
		})
	});

	$j(".collapsible-jquery").each(function(index,element){
		if(GetCookie($j(this)[0].id,"string") == "collapsed"){
			$j(this).siblings().toggle(false);
		}
		else{
			$j(this).siblings().toggle(true);
		}
	});
}
