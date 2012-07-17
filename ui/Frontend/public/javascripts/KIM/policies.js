require('jquery/jquery.form.js');
require('jquery/jquery.validate.js');
require('jquery/jquery.form.wizard.js');
require('KIM/policiesdefs.js');
require('KIM/policiesform.js');
require('KIM/orchestration_policy.js');

function load_policy_content (container_id) {
    var policy_type = container_id.split('_')[1];

    function createAddPolicyButton(cid, grid) {
        var policy_opts = {
            title       : 'Add a ' + policy_type + ' policy',
            name        : 'policy',
            callback    : function () { grid.trigger("reloadGrid"); }
        };

        var button = $("<button>", {html : 'Add a ' + policy_type + ' policy'}).button({
            icons   : { primary : 'ui-icon-plusthick' }
        });

        button.bind('click', function() {
            policy_opts.fields  = jQuery.extend(true, {}, policies[policy_type]);
            if (policy_type != 'orchestration') {
                new PolicyForm(policy_opts).start();
            } else {
                addOrchestrationPolicy(policy_opts, grid);
            }
        });
        $('#' + cid).append(button);
    };

    var container = $('#' + container_id);
    var grid = create_grid( {
        url: '/api/policy?policy_type=' + policy_type,
        content_container_id: container_id,
        grid_id: policy_type + '_policy_list',
        colNames: [ 'ID', 'Name', 'Description' ],
        colModel: [ { name:'policy_id',   index:'policy_id',   width:60, sorttype:"int", hidden:true, key:true},
                    { name:'policy_name', index:'policy_name', width:300 },
                    { name:'policy_desc', index:'policy_desc', width:500 } ],
        details: { onSelectRow : load_policy_details }
    } );

    createAddPolicyButton(container_id, grid);
}

function load_policy_details (elem_id, row_data, grid_id) {
    var policy;
    $.ajax({
        type     : 'GET',
        async    : false,
        url      : '/api/policy/' + elem_id,
        dataTYpe : 'json',
        success  : $.proxy(function(d) {
            policy = d;
        }, this)
    });

    var flattened_policy;
    $.ajax({
        type     : 'POST',
        async    : false,
        url      : '/api/policy/' + elem_id + '/getFlattenedHash',
        dataTYpe : 'json',
        success  : $.proxy(function(d) {
            flattened_policy = d;
        }, this)
    });

    jQuery.extend(true, flattened_policy, policy);

    var fields = jQuery.extend(true, {}, policies[policy.policy_type]);
    fields['policy_id'] = {
        label        : 'Policy id',
        type         : 'hidden',
        value        : policy.policy_id,
    };

    var policy_opts = {
        title       : 'Edit the ' + policy.policy_type + ' policy: ' + policy.policy_name,
        name        : 'policy',
        fields      : fields,
        values      : flattened_policy,
        callback    : function () { $('#' + grid_id).trigger("reloadGrid"); }
    };

    // Special management for Orchestration policy
    if (policy.policy_type == 'orchestration') {
        load_orchestration_policy_details(policy_opts, flattened_policy, grid_id);
    } else {
        new PolicyForm(policy_opts).start();
    }
}
