
// mainmenu_def is set in product specific menu.conf.js
function add_menu(container, label, submenu_links, elem_id) {
    var id_suffix = elem_id ? elem_id : 'static';
    var view_id = 'view_' + label.replace(/ /g, '_') + '_' + id_suffix;
    var link_id = 'link_' + view_id;
    
    // If this link already exists for this menu then we don't repeat it
    var existing_link = container.find('#'+link_id);
    if (existing_link.length != 0) {
        existing_link.addClass('alive_link');
        return;
    };
    
    var link_li = $('<li id="' + link_id + '" class="view_link_cont alive_link"></li>');
    var link_a = $('<a class="view_link" style="white-space: nowrap" href="#' + view_id + '">' + label + '</a>');
    
    link_li.append(link_a);
    container.append(link_li);
    build_submenu($('#view-container'), view_id, submenu_links, elem_id);
    //link_li.find('a').click( function() {onViewLinkSelect($(this), elem_id)} );
    link_li.find('.view_link').click( {view_id: view_id, elem_id: elem_id}, onViewLinkSelect);
}

function add_menutree(container, label, menu_info, elem_id) {
    
    var link_li = $('<li>');
    var link_a = $('<a class="view_link" style="white-space: nowrap">' + label + '</a>');
    link_a.bind('click', function() {
        $(this).next().toggle();
    });
    var sublevel = $('<ul>');
    sublevel.hide();
    $.getJSON(menu_info.level2_url+'?service_template_id='+elem_id, function (data) {
        for(index in data) {
            add_menu(sublevel,data[index].cluster_name,menu_info.submenu,data[index].pk);
            //sublevel.append($('<li>'+data[index].cluster_name+'</li>'));
        }
    });
    
    link_li.append(link_a);
    link_li.append(sublevel);
    container.append(link_li);
}

// Create and link all generic menu elements based on mainmenu_def from conf
function build_mainmenu() {
    
    var container = $('#mainmenu-container');
    
    for (var label in mainmenu_def) {
        var menu_head = $('<h3 id="menuhead_' + label.replace(/ /g, '_') + '"><a href="#">' + label + '</a></h3>');
        var menu_def = mainmenu_def[label];
        container.append(menu_head);
        
        var content = $('<ul></ul>');
        container.append(content);
        
        if (menu_def['onLoad']) {
            // Custom menu
            menu_head.click(menu_def['onLoad']);
        } else if (menu_def['json']) {
            // Dynamic load from json
            menu_head.click(menu_def['json'], loadMenuFromJSON);
        } else if(menu_def['jsontree']) {
            menu_head.click(menu_def['jsontree'], loadTreeMenuFromJSON);
        } else {
            // Static menu
            for (var sublabel in menu_def) {
                var submenu_links = menu_def[sublabel];
                add_menu(content, sublabel, submenu_links);
            }
        }
        
        // Specific view when select menu head
        if (menu_def['masterView']) {
            var view_id = 'view_' + label.replace(/ /g, '_');
            build_submenu($('#view-container'), view_id, menu_def['masterView']);
            menu_head.click( {view_id: view_id}, onViewLinkSelect);
        }
    }
    
    container.accordion( {
        clearStyle  : true,     // size to content
        active      : false,    // all parts closed at start
    } );
}

function build_submenu(container, view_id, links, elem_id) {
    // Create the div container for this view
    var view = $('<div class="master_view" id="' + view_id + '"></div>').appendTo(container);
    // Tab container of the view
    var submenu_cont = $('<ul></ul>').appendTo(view);

    view.tabs({});

    for (var smenu in links) {
        var id_suffix = elem_id ? elem_id : 'static';

        var content_id = 'content_' + links[smenu]['id'] + '_' + id_suffix;
        var content = $('<div id="' + content_id + '"></div>');
        view.append(content);
        view.tabs('add', '#' + content_id , links[smenu]['label']);
        
        if (links[smenu]['onLoad']) {
            _content_handlers[content_id] = {
                    'onLoad' : links[smenu]['onLoad'],
                    'info' : links[smenu]['info']
            };
        }
    }

    // Load content on show event because we need the tab be visible to have a width and so scale content (grid autowidth)
    // Set here and not at tabs creation to avoid async problem (i.e trigger tabsshow before _content_handlers update)
    view.bind("tabsshow", function(event, ui) {
        var link = String(ui.tab);
        reload_content(link.split('#')[1], elem_id);
    });
    view.hide();
}

// Not used TO REMOVE
function build_detailmenu(container, view_id, links, elem_id) {
    // Create the div container for this view
    var view = $('<div class="master_view" id="' + view_id + '"></div>').appendTo(container);
    // Tab container of the view
    var submenu_cont = $('<ul></ul>').appendTo(view);
    
    view.tabs({
        select: function(event, ui) { 
            var link = String(ui.tab);
            //alert('Event select : ' + link.split('#')[1] + '  => ' + ui.panel);
            reload_content(link.split('#')[1], elem_id);
        }
    });
    
    for (var smenu in links) {
        var content_id = 'content_' + links[smenu]['id'];
        var content = $('<div id="' + content_id + '"></div>');
        view.append(content);
        view.tabs('add', '#' + content_id , links[smenu]['label'])
        
        if (links[smenu]['onLoad']) {
            _content_handlers[content_id] = {'onLoad' : links[smenu]['onLoad']};
        }
    }
}

function onViewLinkSelect(event) {
    var view_id = event.data.view_id;
    var elem_id = event.data.elem_id;
    
    // Hide all view div
    $('#view-container .master_view').hide();
    
    // Show div corresponding to this link 
    //$($(this).attr('href')).show(0, function(){alert('end show')});
    //var view = $(view_link.attr('href'));
    var view = $('#'+view_id);
    view.show();
    
    //var selected_tab_idx = view.tabs('option', 'selected');
    //view.tabs('select', selected_tab_idx);
    
    $('.selected_viewlink').removeClass('selected_viewlink')
    $(this).addClass('selected_viewlink');
    
    
    //reload content of the current selected sub menu of the selected view (menu)
    var content_ref =  view.find('.ui-tabs-selected a').attr('href');
    if (content_ref !== undefined) {
        var content_id  = content_ref.split('#')[1];
        reload_content(content_id, elem_id);
    }
    
}

function loadMenuFromJSON(event) {
    var menu_info = event.data;
    var container = $(this).next();

    $.getJSON(menu_info.url, function (data) {
        // Add menu entry and associated view
        for (var elem in data) {
            if (data[elem][menu_info.label_key] != null) {
                add_menu(   container,
                        data[elem][menu_info.label_key],
                        menu_info.submenu,
                        data[elem][menu_info.id_key]
                );
            }
        }
        
        // Remove old links and view
        var dead_links = container.find('.view_link_cont:not(.alive_link)').each(function () {
            var view = $($(this).find('.view_link').attr('href'));
            view.remove();
            $(this).remove();
        });
        container.find('.alive_link').removeClass('alive_link');
    });

}

function loadTreeMenuFromJSON(event) {
    var menu_info = event.data;
    var container = $(this).next();

    container.empty();

    $.getJSON(menu_info.level1_url, function (data) {
        // Add menu entry and associated view
        for (var elem in data) {
            if (data[elem][menu_info.level1_label_key] != null) {
                add_menutree(   container,
                        data[elem][menu_info.level1_label_key],
                        menu_info,
                        data[elem][menu_info.id_key]
                );
            }
        }
        
        // Remove old links and view
        //~ var dead_links = container.find('.view_link_cont:not(.alive_link)').each(function () {
            //~ var view = $($(this).find('.view_link').attr('href'));
            //~ view.remove();
            //~ $(this).remove();
        //~ });
        //~ container.find('.alive_link').removeClass('alive_link');
    }); 
    
}


$(document).ready(function () {
    build_mainmenu();
    
    function show_mainpage() {
        $('#view-container .master_view').hide();
        $('#view-dashboard').show();
    }

    // Display dashboard when click on product name or kanopya logo
    $('#product-name').click( show_mainpage );
    $('#menu_logo').click( show_mainpage );

    // Display welcome image only when everythings loaded
    $('#image-welcome').show();
});
