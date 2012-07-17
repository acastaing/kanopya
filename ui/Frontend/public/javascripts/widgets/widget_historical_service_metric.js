require('widgets/widget_common.js');

$('.widget').live('widgetLoadContent',function(e, obj){
    // Check if loaded widget is for us
    if (obj.widget.element.find('.clusterCombinationView').length == 0) {return;}

    console.log('Load content of widget service metric historical ' + obj.widget.id);
    
     var sp_id = obj.widget.metadata.service_id;
     fillServiceMetricCombinationList(
             obj.widget,
             sp_id
     );

     setGraphDatePicker(obj.widget.element);
});

function fillServiceMetricCombinationList (widget, sp_id) {
    var indic_list = widget.element.find('.combination_list');

    indic_list.change(function () {
        var time_settings   = getPickedDate(widget.element);
        var metric_id       = this.options[this.selectedIndex].id;
        var metric_name     = this.options[this.selectedIndex].value

        setRefreshButton(widget.element, metric_id, metric_name, sp_id);

        showCombinationGraph(
                this,
                metric_id,
                metric_name,
                time_settings.start,
                time_settings.end,
                sp_id
        );
        widget.addMetadataValue('aggregate_combination_id', this.options[this.selectedIndex].id);
    });

    $.get('/api/serviceprovider/' + sp_id + '/aggregate_combinations', function (data) {
        $(data).each( function () {
            indic_list.append('<option id ="' + this.aggregate_combination_id + '" value="' + this.aggregate_combination_label + '">' + this.aggregate_combination_label + '</option>');
        });

        // Load widget content if configured
        if (widget.metadata.aggregate_combination_id) {
            indic_list.find('option#' + widget.metadata.aggregate_combination_id).attr('selected', 'selected');
            indic_list.change();
        }
    });
}

function setRefreshButton(widget_div, combi_id, combi_name, sp_id) {
    widget_div.find('.refresh_button').unbind('click');
    widget_div.find('.refresh_button').click(function () {
        var time_settings = getPickedDate(widget_div);
        showCombinationGraph(
                widget_div,
                combi_id,
                combi_name,
                time_settings.start,
                time_settings.end,
                sp_id
        );
    }).button({ icons : { primary : 'ui-icon-refresh' } }).show();
}

//function triggered on cluster_combination selection
function showCombinationGraph(curobj,combi_id,label,start,stop, sp_id) {
    if (combi_id == 'default'){return}
    var widget = $(curobj).closest('.widget');
    widget_loading_start( widget );
    
    var clustersview_url = '/monitoring/serviceprovider/' + sp_id +'/clustersview';
    var widget_id = $(curobj).closest('.widget').attr("id");
    var graph_container = widget.find('.clusterCombinationView');
    graph_container.children().remove();
    
    var params = {id:combi_id,start:start,stop:stop};
    $.getJSON(clustersview_url, params, function(data) {
        if (data.error) { alert (data.error); }
        else {
            var button = '<input type=\"button\" value=\"refresh\" id=\"cb_button\" onclick=\"c_replot()\"/>';
            var div_id = 'cluster_combination_graph_' + widget_id;
            var div = '<div id=\"'+div_id+'\"></div>';
            graph_container.css('display', 'block');
            graph_container.append(div);
            timedGraph(data.first_histovalues, data.min, data.max, label, data.unit, div_id);
            //graph_container.append(button);
        }
        widget_loading_stop( widget );
    });
}

function timedGraph(first_graph_line, min, max, label, unit, div_id) {
    $.jqplot.config.enablePlugins = true;
    // var first_graph_line=[['03-14-2012 16:23', 0], ['03-14-2012 16:17', 0], ['03-14-2012 16:12', 0],['03-14-2012 16:15',null], ['03-14-2012 16:19', 0], ['03-14-2012 16:26', null]];
    // alert ('min: '+min+' max: '+max);
    // alert ('data for selected combination: '+first_graph_line);
    var cluster_timed_graph = $.jqplot(div_id, [first_graph_line], {
        title:label,
        seriesDefaults: {
            breakOnNull:true,
            showMarker: false,
            trendline: {
                color : '#555555',
                show  : $('#trendlineinput').attr('checked') ? true : false, 
            }
        },
        axes:{
            xaxis:{
                renderer:$.jqplot.DateAxisRenderer,
                rendererOptions: {
                    tickInset: 0
                },
                tickRenderer: $.jqplot.CanvasAxisTickRenderer,
                tickOptions: {
                    mark: 'inside',
                    markSize: 10,
                    showGridline: false,
                    angle: -60,
                    formatString: '%m-%d-%Y %H:%M'
                },
                min:min,
                max:max,
            },
            yaxis:{
                label: unit,
                labelRenderer: $.jqplot.CanvasAxisLabelRenderer,
                tickOptions: {
                    showMark: false,
                },
            },
        },
        grid:{
            background: '#eeeeee',
        },
        highlighter: {
            show: true,
            // formatString: '<p class="cluster_combination_tooltip">Date: %s<br /> value: %f</p>',
        }
        
    });

    // Attach resize event handlers
    setGraphResizeHandlers(div_id, cluster_timed_graph);
}

function toggleTrendLine() {
    if (cluster_timed_graph) {
        cluster_timed_graph.series[0].trendline.show = ! cluster_timed_graph.series[0].trendline.show;
        cluster_timed_graph.replot();
    }
}
