require('widgets/widget_common.js');

$('.widget').live('widgetLoadContent',function(e, obj){
    // Check if loaded widget is for us
    if (obj.widget.element.find('.nmHistogram').length == 0) {return;}

     var sp_id = obj.widget.metadata.service_id;
     fillNodeMetricList2(
             obj.widget,
             sp_id
     );
});

// Can be factorized with the equivalent for nmBarGraph but will be removed soon (with widget advanced config)
function fillNodeMetricList2 (widget, sp_id) {
    var indic_list = widget.element.find('.nmHistogram_list');
    var part_number = 10;
    
    indic_list.change(function () {
        showNodemetricCombinationHistogram(this, this.options[this.selectedIndex].id, this.options[this.selectedIndex].value, part_number, sp_id);
        widget.addMetadataValue('nodemetric_id', this.options[this.selectedIndex].id);
        widgetUpdateTitle(widget, this.options[this.selectedIndex].value);
    });

    $.get('/api/nodemetriccombination?service_provider_id=' + sp_id, function (data) {
        $(data).each( function () {
            indic_list.append('<option id ="' + this.nodemetric_combination_id + '" value="' + this.nodemetric_combination_label 
            + '">' + this.nodemetric_combination_label + '</option>');
        });

        // Load widget content if configured
        if (widget.metadata.nodemetric_id) {
            indic_list.find('option#' + widget.metadata.nodemetric_id).attr('selected', 'selected');
            indic_list.change();
        }
    });
}

function showNodemetricCombinationHistogram(curobj,nodemetric_combination_id,nodemetric_combination_label,part_number, sp_id) {
    var nodes_view_histogram = '/monitoring/serviceprovider/' + sp_id +'/nodesview/histogram';

    var widget_id = $(curobj).closest('.widget').attr("id");

    var graph_container_div = $(curobj).closest('.widget').find('.nodes_histogram');
    var graph_div_id = 'nodes_histogram' + widget_id;
    var graph_div = $('<div>', { id : graph_div_id });
    
    graph_container_div.children().remove();
    graph_container_div.append(graph_div);
    
    if (nodemetric_combination_id == 'default') { return }
    if (!isInt(part_number)) {
        alert(part_number+' is not an integer');
        return
    } else if (!part_number) {
        part_number = 10;
    }
    widget_loading_start( $(curobj).closest('.widget') );
    var params = {id:nodemetric_combination_id,pn:part_number};
    //graph_div.html('');
    $.getJSON(nodes_view_histogram, params, function(data) {
        if (data.error){
            graph_container_div.append($('<div>', {'class' : 'ui-state-highlight ui-corner-all', html: data.error}));
        } else {
            // Transform series values to add node percentage information (displayed in tooltips, see highlighter conf)
            // e.g. :   nbof_nodes_in_partition = [20,10,40] (interpreted by jqplot as [[1,20],[2,10],[3,40]]
            //          After transformation nodes_count_and_percent_in_partition = [[1,20,28.57],[2,10,14.28],[3,40,57.14]]
            var total = data.nbof_nodes_in_partition.reduce(function(a, b){return a+b});
            var nodes_count_and_percent_in_partition = [];
            $.each(data.nbof_nodes_in_partition, function (i,j) {
                nodes_count_and_percent_in_partition.push([i+1, j, j*100/total]);
            });

            graph_div.css('display', 'block');
            nodemetricCombinationHistogram(nodes_count_and_percent_in_partition, data.partitions, graph_div_id, data.nodesquantity, nodemetric_combination_label);
        }
//        var button = '<input type=\"button\" value=\"refresh\" id=\"nch_button\" onclick=\"nch_replot()\"/>';
//        $("#"+div_id).append(button);
        widget_loading_stop( $(curobj).closest('.widget') );
    });
}

function nodemetricCombinationHistogram(nbof_nodes_in_partition, partitions, div_id, nodesquantity, title) {
    $.jqplot.config.enablePlugins = true;
    var nodes_bar_graph = $.jqplot(div_id, [nbof_nodes_in_partition], {
    title: title,
        animate: !$.jqplot.use_excanvas,
        seriesDefaults:{
            renderer:$.jqplot.BarRenderer,
            rendererOptions:{ varyBarColor : true, barWidth: 30 },
            pointLabels: { show: true, formatString: '%.1f\%' },
            trendline: {
                show: false, 
            },
        },
        axes: {
            xaxis: {
                renderer: $.jqplot.CategoryAxisRenderer,
                ticks: partitions,
                tickRenderer: $.jqplot.CanvasAxisTickRenderer,
                tickOptions: {
                    showMark: false,
                    showGridline: false,
                    angle: -40,
                }
            },
            yaxis:{
                label:'# nodes',
                labelRenderer: $.jqplot.CanvasAxisLabelRenderer,
//              min:0,
//              max:nodesquantity,
            },
        },
        grid:{
            background: '#eeeeee',
        },
        //seriesColors: ["#D4D4D4" ,"#999999"],
        seriesColors: ["#4BB2C5" ,"#6DD4E7"],
        highlighter: { 
            show: true,
            showMarker:false,
            tooltipAxes: 'y',
            yvalues : 2,
            formatString: '%i nodes (%s\%)',
        },
        cursor : {
            show : false
        }
    });

    // Attach resize event handlers
    setGraphResizeHandlers(div_id, nodes_bar_graph);

}

//simple function to check if a variable is an integer
function isInt(n) {
   return n % 1 == 0;
}
