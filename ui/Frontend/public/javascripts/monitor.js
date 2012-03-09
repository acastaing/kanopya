 $(document).ready(function(){
 
  	var url_params = window.location.href.split('?')[1];
  	var url = window.location.href;
	var path = url.replace(/^[^\/]+\/\/[^\/]+/g,'');	
	var content_link = path + '/graphs'; // remove the beginning of the url to keep only path
 	var save_clustermonitoring_settings_link = path + '/save';
 	var save_monitoring_settings_link = "/cgi/kanopya.cgi/monitoring/save_monitoring_settings";
    var current_path = path;


 	commonInit();
 	
 // ------------------------------------------------------------------------------------
 	
 	$('.expand_ul ul').hide();
 	$('.expand_ul').click( function() {
 		$(this).find('ul').toggle();
 	} ).addClass('clickable');

	$('[id^=X] .expandable').hide();  // hide all elems of class 'expandable' under elem with id starting with 'X'
 	$(".expander", this).click(function() {
 		
 		var elem_to_expand = $('#X'+this.id).find('.expandable');
 		
 		if ( ! $('#X'+this.id).hasClass('expand_on')) {
 			
 			$('.expanded').hide('blind', {}, 300).removeClass('expanded');
 			$('.expand_on').removeClass('expand_on');
 		}
     	elem_to_expand.toggle('blind', {}, 300);
     	elem_to_expand.toggleClass('expanded');
     	$('#X'+this.id).toggleClass('expand_on');
     	
   }).addClass('clickable');
 	
 	
 	
 	$('.select_collect').click( function () {
 				$(this).toggleClass('collected'); 
 				$(this).siblings('.select_graph').removeClass('graphed');
 	} ).addClass('clickable');
 	
 	$('.select_graph').click( function () {
 				$(this).toggleClass('graphed');
 				var id = $(this).siblings('.expander').attr('id');
 				$(this).hasClass('graphed') ? $('#X'+id+' .select_ds').addClass('on_graph') : $('#X'+id+' .select_ds').removeClass('on_graph');
 				$(this).siblings('.select_collect').addClass('collected');
 	} ).addClass('clickable');
 	
 	$('.select_ds').click( function () { $(this).toggleClass('on_graph'); } ).addClass('clickable');
 	
 	$('#save_clustermonitoring_settings').click( function () {
 			loading_start(); 
 			var set_array = $('.select_collect.collected').map( function () { return $(this).siblings('.expander').attr('id');} ).get();

 			var settings = $('.select_graph.graphed').map( function() {
 				var set_label = $(this).siblings('.expander').attr('id');
 				var graph_settings = { 'set_label': set_label };
 				$('.graph_settings_' + set_label + ' .graph_option').each( function() { 												
	 															graph_settings[$(this).attr('opt_name')] = $(this).text(); 
	 														} )
	 			graph_settings['ds_label'] = $('.graph_settings_' + set_label + ' .select_ds.on_graph').map( function() { 												
	 															return $(this).attr('id'); 
	 														} ).get().join(",");
	 														
	 			return graph_settings;
 			}).get();
 			

 			//var params = { 'collect_sets[]': set_array, 'graphs_settings': JSON.stringify(settings) };
			var params = { 'collect_sets': JSON.stringify(set_array), 'graphs_settings': JSON.stringify(settings) };
 			
 			$.get(save_clustermonitoring_settings_link, params, function(resp) {
				loading_stop();
				alert(resp);				
				
			});
 	} ).addClass('clickable');
 
 
 	$('#save_monitoring_settings').click( function () {
 		loading_start(); 
 		
 		var settings = $('pouet');
 		
 		var params = {  };
 			
		$.get(save_monitoring_settings_link, params, function(resp) {
			loading_stop();
			alert(resp);
		});
 	}).addClass('clickable');
 
 	$('.set_def_show').click( function () { $('.set_def').show(); } );
 	$('.set_def_hide').click( function () { $('.set_def').hide(); } );
 	
 	
 	$('.yes_no_choice').click( function () { $(this).text($(this).text() == 'no' ? 'yes' : 'no') } ).addClass('clickable');
 	
 	

 // ------------------------------------------------------------------------------------
 
 	$('.simpleexpand').click( function () {
 		$('#X'+this.id).toggle();
 	}).addClass('clickable');
 
 // ------------------------------------------------------------------------------------
 
 	function refreshGraph () {
 		var timestamp = new Date().getTime();
		//$(this).fadeOut('fast').attr('src',$(this).attr('src').split('?')[0] + '?' +timestamp ).fadeIn('fast');		
		$(this).attr('src',$(this).attr('src').split('?')[0] + '?' +timestamp );
 	}
 
 	setInterval( 
 		function() {
	 		$("img.autorefresh").each( refreshGraph )
 	 	} , 5000);
 
 	//$("#ivy1").show('bounce', {}, 500);
 	//$("#logo").show('slide', {}, 500);
 	//$("#logo").mouseover(function() { $(this).show('shake', {}, 500); });
 	
 	function toggleNodeSet() {
 /*
 		loading_start();
 		alert("marche pas encore... " + $(this).attr('id'));
		var anim = 'blind';//'blind/slide';
   		var anim_duration = 500;
   		$(".selected_node").removeClass('selected_node');
   		$(this).parents().find(".node_selector").addClass('selected_node');

		var set_name = $(this).attr('id');

		$(".selected_node table img").hide(anim, {}, anim_duration);

   		setTimeout( function() {
	   		var node_name = $('.selected_node').attr('id');
	   		
	   		var params;
		   	if ($('.selected_node').hasClass('expanded')) {
		   		$(".selected_node").removeClass('expanded'); 
		   		//var set_name = $('.selected_set').attr('id').split('_')[1];;
		   		params = {node: node_name, set: set_name};
		   	} else {
		   		$(".selected_node").addClass('expanded');
		   		params = {node: node_name};
		   	}
		   	
	   		// send request
	    	$.get(content_link, params, function(xml) {
				
				fill_content_container(xml);
		
				$(".selected_node img").addClass('autorefresh').show(anim, {}, anim_duration);
				loading_stop();
			});
		}, anim_duration);
*/   	 		
 	}
 
	function toggleNode() {

		loading_start();
		var anim = 'fold';//'blind/slide';
   		var anim_duration = 500;
   		$(".selected_node").removeClass('selected_node');
   		$(".activated_content_container").removeClass('activated_content_container');
   		$(this).addClass('selected_node');
   		var content_node = $("#" + $('.selected_node').attr('id') + "_content").addClass('selected_node');
   		content_node.addClass('activated_content_container');
   		
   		var delay = anim_duration;
   		//var imgs = $(".selected_node img");
   		var imgs = content_node.find("img");
   		if (imgs.size() == 0) {
   			delay = 0;
   		} else {
   			imgs.hide(anim, {}, anim_duration);
   		}

   		setTimeout( function() {
	   		var node_name = $('.selected_node').attr('id');
	   		var period = $('.selected_period').attr('id');
	   		var params;
		   	if ($('.selected_node').hasClass('expanded')) {
		   		$(".selected_node").removeClass('expanded');
		   		if ($('.selected_set').size() == 0) {
		   			$('.activated_content_container').html("");
		   			loading_stop();
		   			return;
		   		}
		   		var set_name = $('.selected_set').attr('id');
		   		params = {node: node_name, set: set_name, period: period};
		   	} else {
		   		$(".selected_node").addClass('expanded');
		   		params = {node: node_name, period: period};
		   	}
	   		// send request
	    	$.get(content_link, params, function(xml) {

				fill_content_container(xml);

				if ($('.selected_node').hasClass('expanded')) {
					$('.activated_content_container').find(".set_selector").click( toggleNodeSet ).addClass('clickable');
				}
				
				$('.activated_content_container').find("img").addClass('autorefresh').show(anim, {}, anim_duration);
				loading_stop();
			});
		}, delay);
		
	}
   
   function fill_content_container(xml) {
		$(xml).find('node').each(function(){
			var id = $(this).attr('id');
			$("#" + id + "_content").html('<table class="simplelisting"><tr><td><img src="' + $(this).attr('img_src') + '" /></td></tr></table>')
			//$("#" + id + "_content").html($(this).children());
		});
		$("#nodecount_graph img").attr('src', $(xml).find('nodecount_graph').attr('src'));
   }
   
   function loading_start() {
   		$('body').css('cursor','wait');
   		$('.set_selector').addClass('unactive_set_selector').removeClass('set_selector');
   		$('.clickable').addClass('unactive_clickable').removeClass('clickable');		
   }
   
   function loading_stop() {
   		$('body').css('cursor','auto');
   		$('.unactive_set_selector').addClass('set_selector').removeClass('unactive_set_selector');	
   		$('.unactive_clickable').addClass('clickable').removeClass('unactive_clickable');
   }
   

   $(".set_selectors .set_selector").click(function() {
   		loading_start();
   		var anim = 'fold';//'blind/slide';
   		var anim_duration = 0;
   		
   		$(".selected_set").removeClass('selected_set');
   		$(".expanded").removeClass('expanded');
   		$(this).addClass('selected_set');
   		//$("#graph_table img").hide(anim, {}, anim_duration);
   		setTimeout( function() {
   			
	   		var set_name = $('.selected_set').attr('id');
	   		var period = $('.selected_period').attr('id');
	   		// send request
	    	$.get(content_link, {set: set_name, period: period}, function(xml) {

				fill_content_container(xml);
				 
				$("#graph_table img").addClass('autorefresh');
				//$("#graph_table img").show(anim, {}, anim_duration);
				loading_stop();
			});
		}, anim_duration); 
   });


   $("#graph_table .node_selector").click( toggleNode ).addClass('clickable');
   
   //$(".period_selectors .period_selector").click(function() {
   $(".period_selector").click(function() {
   		$('.selected_period').removeClass('selected_period');
   		$(this).addClass('selected_period');
   		$('#period_label').html($(this).text());
   		var period = $(this).attr('id');
   		$('.content_container img').each( function() {
   			$(this).attr('src',$(this).attr('src').replace(/(day|hour|custom)/, period) );
   		});
   		$('#nodecount_graph img').attr('src', $('#nodecount_graph img').attr('src').replace(/(day|hour|custom)/, period) );
   		
   }).addClass('clickable');
   
   
   $('#fold_all').click( function() {
   		$('.selected_set').removeClass('selected_set');
   		$('.content_container img').hide('fold', {}, 500);
   		setTimeout( function() {$('.content_container').html('');}, 500);
   });
   
   
   //$("a").toggle(function(){ $("b").fadeOut('slow'); },function(){$("b").fadeIn('slow');});
   
   
   //$( ".draggable" ).draggable();
    // function test_ui(){
        // 0();
        // alert (current_path);
        // var s1 = 34;
        // $.getJSON(current_path, {v1: s1}, function(data) {
			// alert ('alert xml une fois pouet');
            // alert(data.values);
            // loading_stop();
        // });     
   // } 
   // $('#testcall').click (test_ui);
 });


$(function() {
	$( "#combination_start_time" ).datetimepicker({
		dateFormat: 'mm-dd-yy'
	});
});
 $(function() {
	$( "#combination_end_time" ).datetimepicker({
		dateFormat: 'mm-dd-yy'
	});
});
 
var url = window.location.href;
var path = url.replace(/^[^\/]+\/\/[^\/]+/g,'');
var nodes_view = path + '/nodesview';
var clusters_view = path  + '/clustersview';

function showCombinationGraph(curobj,combi_id,start,stop){
	if(combi_id == 'default'){return}
	loading_start();
	var params = {id:combi_id,start:start,stop:stop};
	document.getElementById('timedCombinationView').innerHTML='';
	 $.getJSON(clusters_view, params, function(data) {
		if (data.error){ alert (data.error); }
		else{
			document.getElementById('timedCombinationView').style.display='block';
			timedGraph(data.first_histovalues, data.min, data.max);
		}
        loading_stop();
    });
}

function showMetricGraph(curobj,metric_oid,metric_unit){
	if(metric_oid == 'default'){return}
	loading_start();
	var params = {oid:metric_oid,unit:metric_unit};
	document.getElementById('nodes_charts').innerHTML='';
	$.getJSON(nodes_view, params, function(data) {
		alert('toto');
		if (data.error){ alert (data.error); }
		else{
			document.getElementById('nodes_charts').style.display='block';
			var max_nodes_per_graph = 100;
			var graph_number = Math.round((data.nodelist.length/max_nodes_per_graph)+0.5);
			var nodes_per_graph = data.nodelist.length/graph_number;
			for (var i = 0; i<graph_number; i++){
				var div_id = 'nodechart_'+i;
				var div = '<div id=\"'+div_id+'\"></div>';
				//create the graph div container
				$("#nodes_charts").append(div);
				//slice the array
				var indexOffset = nodes_per_graph*i;
				var toElementNumber = nodes_per_graph*(i+1);
				var sliced_values = data.values.slice(indexOffset,toElementNumber);
				var sliced_nodelist = data.nodelist.slice(indexOffset,toElementNumber);
				//we generate the graph
				barGraph(sliced_values, sliced_nodelist, data.unit, div_id);
			}
		}
        loading_stop();
    });
}

function barGraph(values, nodelist, unit, div_id){
	$.jqplot.config.enablePlugins = true;
    plot1 = $.jqplot(div_id, [values], {
	title:'Indicator Distributed Graph (in '+unit+' )',
        animate: !$.jqplot.use_excanvas,
        seriesDefaults:{
            renderer:$.jqplot.BarRenderer,
            rendererOptions:{ varyBarColor : true, shadowOffset: 0, barWidth: 5 },
            pointLabels: { show: true }
        },
        axes: {
            xaxis: {
                renderer: $.jqplot.CategoryAxisRenderer,
                showGridline: false,
                ticks: nodelist,
                tickRenderer: $.jqplot.CanvasAxisTickRenderer,
                tickOptions: {
                    angle: -60,
                }
            }
        },
        seriesColors: ["#D4D4D4" ,"#999999"],
        highlighter: { show: false }
    });
 
    // $('#nodechart').bind('jqplotDataClick',
        // function (ev, seriesIndex, pointIndex, data) {
            // $('#info1').html('series: '+seriesIndex+', point: '+pointIndex+', data: '+data);
        // }
    // );
}
 
 function timedGraph(first_graph_line, min, max){
	$.jqplot.config.enablePlugins = true;
    alert ('data for selected combination: '+first_graph_line);
	// var line1=[['03-30-2012 16:10',1], ['03-30-2012 16:13',3], ['03-30-2012 16:22',5], ['03-30-2012 16:23',7], ['03-30-2012 16:27',8]];
	var plot1 = $.jqplot('timedCombinationView', [first_graph_line], {
        title:'Combination Historical Graph',
        axes:{
            xaxis:{
                renderer:$.jqplot.DateAxisRenderer,
                rendererOptions: {
                    tickInset: 0
                },
                tickRenderer: $.jqplot.CanvasAxisTickRenderer,
                tickOptions: {
                  angle: -60,
                  formatString: '%y-%m-%d %H:%M'
                },
        min:min,
        max:max,
		// min: '03-30-2012 16:00',
		// max: '03-30-2012 16:30'
            }      
        },
        series:[{lineWidth:4, markerOptions:{style:'square'}}]
    });
}

// function testBar(){
//var ticks = ['plusdetroiscaractere', 'plusdetroiscaractere', 'plusdetroiscaractere', 'plusdetroiscaractere', 'plusdetroiscaractere','n24', 'n25', 'n17', 'n18', 'n19', 'n20', 'n21', 'n22', 'n23', 'n24', 'n25', 'n17', 'n18', 'n19', 'pouet','plusdetroiscaractere', 'plusdetroiscaractere', 'plusdetroiscaractere', 'plusdetroiscaractere', 'plusdetroiscaractere','n24', 'n25', 'n17', 'n18', 'n19', 'n20', 'n21', 'n22', 'n23', 'n24', 'n25', 'n17', 'n18', 'n19', 'pouet', 'plusdetroiscaractere', 'plusdetroiscaractere', 'plusdetroiscaractere', 'plusdetroiscaractere', 'plusdetroiscaractere','n24', 'n25', 'n17', 'n18', 'n19', 'n20', 'n21', 'n22', 'n23', 'n24', 'n25', 'n17', 'n18', 'n19', 'pouet', 'tortue', 'tortue', 'tortue', 'tortue', 'tortue', 'tortue', 'tortue', 'tortue', 'tortue', 'tortue', 'DOC', 'DOC', 'DOC', 'DOC', 'DOC', 'DOC', 'DOC', 'DOC', 'DOC', 'DOC', 'GOD', 'GOD', 'GOD', 'GOD', 'GOD', 'GOD', 'GOD', 'GOD', 'GOD', 'GOD', 'POMME', 'POMME', 'POMME', 'POMME', 'POMME', 'POMME', 'POMME', 'POMME', 'POMME', 'POMME', 'TOMATE', 'TOMATE', 'TOMATE', 'TOMATE', 'TOMATE', 'TOMATE', 'TOMATE', 'TOMATE', 'TOMATE', 'TOMATE', 'DOUDOU', 'DOUDOU', 'DOUDOU', 'DOUDOU', 'DOUDOU', 'DOUDOU', 'DOUDOU', 'DOUDOU', 'DOUDOU', 'DOUDOU' ];
	//var s1 = [ 3600, 1800, 1900, 2000, 2100, 2200, 2300, 2400, 2500,2300, 2400, 2500, 2600, 2700, 2800, 2900, 3000, 3500, 3600, 1800, 3600, 1800, 1900, 2000, 2100, 2200, 2300, 2400, 2500,2300, 2400, 2500, 2600, 2700, 2800, 2900, 3000, 3500, 3600, 1800, 3600, 1800, 1900, 2000, 2100, 2200, 2300, 2400, 2500,2300, 2400, 2500, 2600, 2700, 2800, 2900, 3000, 3500, 3600, 5000, 5000, 5000, 5000, 5000, 5000, 5000, 5000, 5000, 5000, 5000, 6000,6000, 6000, 6000, 6000, 6000, 6000, 6000, 6000, 6000, 8000, 8000, 8000, 8000, 8000, 8000, 8000, 8000, 8000, 8000, 9000, 9000, 9000, 9000, 9000, 9000, 9000, 9000, 9000, 9000, 10000, 10000, 10000, 10000, 10000, 10000, 10000, 10000, 10000, 10000, 12000, 12000, 12000, 12000, 12000, 12000, 12000, 12000, 12000, 12000];	
	// $.jqplot.config.enablePlugins = true;
	// plot1 = $.jqplot('testchart', [s1], {
	// title:'Indicator Distributed Graph',
        // animate: !$.jqplot.use_excanvas,
        // seriesDefaults:{
            // renderer:$.jqplot.BarRenderer,
            // rendererOptions:{ varyBarColor : true },
            // pointLabels: { show: true }
        // },
        // axes: {
            // xaxis: {
                // renderer: $.jqplot.CategoryAxisRenderer,
                // ticks: ticks,
                // tickRenderer: $.jqplot.CanvasAxisTickRenderer,
                // tickOptions: {
                    // angle: -80,
                // }
            // }
        // },
        // seriesColors: ["#D4D4D4" ,"#999999"],
        // highlighter: { show: false }
    // });
    
    // $('#testchart').bind('jqplotDataClick', 
    // function (ev, seriesIndex, pointIndex, data) {
        // $('#info1').html('series: '+seriesIndex+', point: '+pointIndex+', data: '+data);
    // }
    // );
// }
