var chart;

    	// Function for loading a highchart pie
			function loadPie(title, data, obj) {
				var pieId = 'pie' + obj.closest('.widget').attr("id");
				chart = new Highcharts.Chart({
					chart: {
						renderTo: pieId,
						plotBackgroundColor: null,
						plotBorderWidth: null,
						plotShadow: false,
						width:650
					},
					title: {
						text: title
					},
					tooltip: {
						formatter: function() {
							return '<b>'+ this.point.name +'</b>: '+ this.y + ' (' + ((this.y/this.total)*100).toFixed(0) + '%)';
						}
					},
					plotOptions: {
						pie: {
							allowPointSelect: true,
							cursor: 'pointer',
							dataLabels: {
								enabled: true,
								color: '#000000',
								connectorColor: '#000000',
								formatter: function() {
									return '<b>'+ this.point.name +'</b>: '+ ' ' + ((this.y/this.total)*100).toFixed(0) + '%';
								}
							}
						}
					},
						series: [{
						type: 'pie',
						name: title,
						data: data
					}]
				});

			}


      // This is the code for definining the dashboard
      $(document).ready(function() {
        // load the templates
        $('#view-dashboard').append('<div id="templates"></div>');
        $("#templates").hide();
        $("#templates").load("templates.html", initDashboard);

        function initDashboard() {

          // to make it possible to add widgets more than once, we create clientside unique id's
          // this is for demo purposes: normally this would be an id generated serverside
          var startId = 100;

          var dashboard = $('#dashboard').dashboard({
            // layout class is used to make it possible to switch layouts
            layoutClass:'layout',
            // feed for the widgets which are on the dashboard when opened
            json_data : {
              url: "jsonfeed/mywidgets_charts.json"
            },
            // json feed; the widgets whcih you can add to your dashboard
            addWidgetSettings: {
              widgetDirectoryUrl:"jsonfeed/widgetcategories.json"
            },

            // Definition of the layout
            // When using the layoutClass, it is possible to change layout using only another class. In this case
            // you don't need the html property in the layout

            layouts :
              [
                { title: "Layout1",
                  id: "layout1",
                  image: "layouts/layout1.png",
                  classname: 'layout-a'
                },
                { title: "Layout2",
                  id: "layout2",
                  image: "layouts/layout2.png",
                  classname: 'layout-aa'
                },
                { title: "Layout3",
                  id: "layout3",
                  image: "layouts/layout3.png",
                  classname: 'layout-ba'
                },
                { title: "Layout4",
                  id: "layout4",
                  image: "layouts/layout4.png",
                  classname: 'layout-ab'
                },
                { title: "Layout5",
                  id: "layout5",
                  image: "layouts/layout5.png",
                  classname: 'layout-aaa'
                }
              ]

          }); // end dashboard call

          // binding for a widgets is added to the dashboard
          dashboard.element.live('dashboardAddWidget',function(e, obj){
            var widget = obj.widget;

            dashboard.addWidget({
              "id":startId++,
              "title":widget.title,
              "url":widget.url,
              "metadata":widget.metadata
              }, dashboard.element.find('.column:first'));
          });

					// Make sure the pie is loaded when the widget is loaded. This makes it possible to add the pie more than once
					dashboard.element.live('widgetLoaded',function(e, obj){

						var widgetEl = obj.widget.element;
						if (widgetEl.find('.piecontainer').length > 0) {
							// The pie needs a dic with a unique id, so create one with the widget ID (which is unique)
							widgetEl.find('.pielocation').append('<div id="pie' + obj.widget.id + '"></div>');

							// Some data for my pie
							var data = [
								['Firefox',   45.0],
								['IE',       26.8],
								{
									name: 'Chrome',
									y: 12.8,
									sliced: true,
									selected: true
								},
								['Safari',    8.5],
								['Opera',     6.2],
								['Others',   0.7]
							];

							loadPie('My Pie',data,widgetEl);

						}
					});


          // the init builds the dashboard. This makes it possible to first unbind events before the dashboars is built.
          dashboard.init();
        }
      });


