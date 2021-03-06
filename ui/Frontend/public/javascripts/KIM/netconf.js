//require('kanopyaformwizard.js');
require('common/general.js');

function netconf_addbutton_action(e, grid) {
    (new KanopyaFormWizard({
        title      : 'Create a Network Configuration',
        type       : 'netconf',
        id         : (!(e instanceof Object)) ? e : undefined,
        displayed  : [ 'netconf_name', 'netconf_vlans', 'netconf_poolips', 'netconf_role_id' ],
        callback   : function () { handleCreate(grid); }
    })).start();
}

function netconfs_list(cid) {
    var grid = create_grid({
        url                     : '/api/netconf',
        content_container_id    : cid,
        grid_id                 : 'netconfs_list',
        colNames                : [ 'Id', 'Name' ],
        colModel                : [
            { name : 'pk', index : 'pk', hidden : true, key : true, sorttype : 'int' },
            { name : 'netconf_name', index : 'netconf_name' }
        ],
        details                 : {
            onSelectRow : netconf_addbutton_action
        }
    });
    var action_div=$('#' + cid).prevAll('.action_buttons'); 
    var addButton   = $('<a>', { text : 'Add a Network Configuration' }).appendTo(action_div)
                        .button({ icons : { primary : 'ui-icon-plusthick' } });
    $(addButton).bind('click', function (e) {
        netconf_addbutton_action(e, grid);
    });
}
