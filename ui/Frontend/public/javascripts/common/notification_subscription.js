require('common/formatters.js');

var addSubscriptionButtonInGrid = function(grid, rowid, rowdata, rowelem, colid, operationType, validation) {
    var cell            = $(grid).find('tr#' + rowid).find('td[aria-describedby="' + colid + '"]');
    var subscribeButton = $('<div>').button({ text : false, icons : { primary : 'ui-icon-mail-closed' } }).appendTo(cell);
    $(subscribeButton).attr('style', 'margin-top:5px;');
    $(subscribeButton).click(function() {
        var details = {
            tabs : [
                {
                    label  : 'Notification subscriptions',
                    id     : 'subscription',
                    onLoad : function(cid, eid) {
                        loadSubscriptionModal(cid, eid, operationType, validation);
                    }
                }
            ],
            title : 'Notification subscriptions'
        };
        show_detail('entity_subscription_list', 'entity_subscription_list', rowelem.pk, rowdata, details);
    });
}

function userOrGroupFormatter(cell, options, row) {
    var entity;
    $.ajax({
        async   : false,
        url     : '/api/entity/' + cell,
        success : function(data) {
            entity = data;
        }
    });
    return entity.user_firstname + ' ' + entity.user_lastname;
}

function loadSubscriptionModal (container_id, elem_id, operationtype, mustValidate) {
    if (mustValidate === undefined) {
        mustValidate = true;
    }
    var container = $('#'+container_id);

    var grid = create_grid( {
        url: '/api/notificationsubscription?entity_id=' + elem_id,
        content_container_id: container_id,
        grid_id: 'entity_subscription_list_' + elem_id,
        grid_class: 'entity_subscription_list',
        rowNum : 25,
        colNames: [ 'id', 'Subscriber', 'Validation' ],
        colModel: [
            { name: 'pk', index: 'pk', width: 60, sorttype: 'int', hidden: true, key: true },
            { name: 'subscriber_id', index: 'subscriber_id', formatter: userOrGroupFormatter },
            { name: 'validation', index: 'validation', width: 90, formatter: booleanFormatter },
        ],
        action_delete: {
            callback: function(subscrition_id) {
                // NOTE: The notifications at rule triggering have implemented differently
                // TODO: Use the common mechanism
                if (operationtype == "ProcessRule") {
                    $.post('/api/entity/' + elem_id + '/unsubscribe', { notification_subscription_id: subscrition_id } )
                } else {
                    $.post('/api/operationtype/unsubscribe', { notification_subscription_id: subscrition_id } )
                }
            }
        }
    } );

    grid.bind('reloadGrid', function () {
        buildUserSelectInput(subscriber, elem_id);
    });

    var content = $("<div>", { id : 'add_subscriber' }).appendTo(container);

    var form  = $("<form>", { method : 'POST', action : '/api/notificationsubscription' }).appendTo(content);
    var table = $("<table>").css('width', '60%').appendTo($(form));

    var tr_users = $("<tr>").appendTo(table);
    var tr_validation = $("<tr>").appendTo(table);
    var tr_button = $("<tr>").appendTo(table);

    var subscriber = $("<select>", { name : 'subscriber_id', id : 'input_subscriber',  width: 250});

    buildUserSelectInput(subscriber, elem_id);

    $("<td>", { align : 'left'}).append($("<label>", { for : 'input_subscriber', text : 'Select a user/group:'  })).appendTo(tr_users);
    $("<td>", { align : 'left' }).append(subscriber).appendTo(tr_users);

    if (mustValidate === true) {
        var validation = $("<input>", { type : 'checkbox', name : 'validation', id : 'input_validation' });
        $("<td>", { align : 'left' }).append($("<label>", { for : 'input_validation', text : 'Validation:' })).appendTo(tr_validation);
        $("<td>", { align : 'left' }).append(validation).appendTo(tr_validation);
    }

    $('<input>', { type : 'hidden', name : 'entity_id', id : 'input_entity_id', value: elem_id }).appendTo(form);

    var button = $("<button>", { html : 'Add a subscriber' } ).button({
        icons   : { primary : 'ui-icon-plusthick' }
    });

    $(form).submit(function() {
        if ($(validation).attr('checked')) {
            $(validation).attr('value', '1');
        } else {
            $(validation).attr('value', 0);
        }

        // NOTE: The notifications at rule triggering have implemented differently
        // TODO: Use the common mechanism
        var data = $(form).serialize();
        if (operationtype == "ProcessRule") {
            data += '&operationtype=' + operationtype;
            $.ajax({
                async : false,
                url   : '/api/rule/' + elem_id + '/subscribe',
                type  : 'POST',
                data  : data,
            });

        } else {
            $.ajax({
                type     : 'GET',
                async    : false,
                url     : '/api/operationtype?operationtype_name=' + operationtype,
                success : function(type) {
                    $.ajax({
                        async : false,
                        url   : '/api/operationtype/' + type[0].pk + '/subscribe',
                        type  : 'POST',
                        data  : data,
                    });
                }
            });
        }

        grid.trigger("reloadGrid");
        return false;
    })

    $("<td>", { align : 'left', colspan : '2' }).append(button).appendTo(tr_button);
}

function buildUserSelectInput(input, elem_id) {
    $(input).find('option').remove();

    var users;
    $.ajax({
        type     : 'GET',
        async    : false,
        url      : '/api/user',
        dataTYpe : 'json',
        success  : $.proxy(function(d) {
            users = d;
        }, this)
    });
    
    // TODO: Use the grid content to known users that already subscribe.
    var subscribtions = new Array();
    $.ajax({
        type     : 'GET',
        async    : false,
        url     : '/api/notificationsubscription?entity_id=' + elem_id,
        success : function(data) {
            for (var subscription in data) {
                subscribtions.push(data[subscription].subscriber_id);
            }
        }
    });

    for (var user in users) {
        if (subscribtions.indexOf(users[user].pk) === -1) {
            $("<option>", { value : users[user].pk, text : users[user].user_firstname + ' ' + users[user].user_lastname }).appendTo(input);
        }
    }
}
