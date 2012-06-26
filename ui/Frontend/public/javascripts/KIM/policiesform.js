require('jquery/jquery.form.js');
require('jquery/jquery.validate.js');
require('jquery/jquery-ui-timepicker-addon.js');
// require('jquery/jquery.form.wizard.js');

$.validator.addMethod("regex", function(value, element, regexp) {
    var re = new RegExp(regexp);
    return this.optional(element) || re.test(value);
}, "Please check your input");

var PolicyForm = (function() {
    function PolicyForm(args) {
        this.handleArgs(args);

        this.content    = $("<div>", { id : this.name });

        this.validateRules      = {};
        this.validateMessages   = {};

        var method = 'POST';
        var action = '/api/' + this.baseName;
        // Check if it is a creation or an update form
        if (this.id !== undefined) {
            method  = 'PUT';
            action  += '/' + this.id;
        }
        if (args.prependElement !== undefined) {
            this.content.prepend($(args.prependElement));
        }
        this.form       = $("<form>", { method : method, action : action}).appendTo(this.content).append(this.table);
        this.table      = $("<table>").css('width', '100%').appendTo($(this.form));
        this.stepTables = [];

        // For each element in fields, add an input to the form
        for (var elem in this.fields) {
            // If this is a set, add a button to allow to add elements to the set

            if (this.fields[elem].set) {
                if (! this.fields[elem].policy) {
                    var add_button = $("<input type=\"button\"/>", { html : this.fields[elem].add_label, class : 'wizard-ignore' });
                    var element = elem;
                    var that = this;
                    add_button.bind('click', function() {
                        that.newElement(element);
                        $(that.content).dialog('option', 'position', $(that.content).dialog('option', 'position'));
                    });

                    this.findContainer(this.fields[elem].step).append(add_button);
                    add_button.val(this.fields[elem].add_label);
                }

                // If we have values for a set element, add the elements with
                // values.
                if (this.values[elem]) {
                    // this.newSeparator(this.fields[elem].step);
                    for (var set_element in this.values[elem]) {
                        this.newElement(elem, this.values[elem][set_element]);
                    }
                }
            } else if (! this.fields[elem].composite) {
                this.newElement(elem, this.values[elem] || this.fields[elem].value);
            }
        }
    }

    PolicyForm.prototype.newElement = function(elem, value) {
        if (this.fields[elem].triggered) {
            if (! this.triggeredFields[this.fields[elem].triggered]) {
                this.triggeredFields[this.fields[elem].triggered] = new Array();
            }
            this.triggeredFields[this.fields[elem].triggered].push(elem);
            return 0;
        }

        if (this.fields[elem].type === 'select' && !this.fields[elem].options) {
            this.newDropdownElement(elem, undefined, value);

        } else if (this.fields[elem].type === 'composite') {
            for (var composite_field in this.fields) {
                if (this.fields[composite_field].composite === elem) {
                    this.fields[composite_field].step = this.fields[elem].step;
                    this.fields[composite_field].set = this.fields[elem].set;

                    var composite_value;
                    if (value) {
                        composite_value = value[composite_field];
                    }
                    this.newElement(composite_field, composite_value);
                }
            }
        } else {
            this.newFormElement(elem, value);
        }
    }

    PolicyForm.prototype.start = function() {
        $(document).append(this.content);
        // Open the modal and start the form wizard
        this.openDialog();
        this.startWizard();
    }

    PolicyForm.prototype.handleArgs = function(args) {
        if ('name' in args) {
            this.baseName   = args.name;
            this.name       = 'form_' + args.name;
        }

        this.id             = args.id;
        this.callback       = args.callback     || $.noop;
        this.fields         = args.fields       || {};
        this.values         = args.values       || {};
        this.title          = args.title        || this.name;
        this.skippable      = args.skippable    || false;
        this.beforeSubmit   = args.beforeSubmit || $.noop;
        this.cancelCallback = args.cancel       || $.noop;
        this.error          = args.error        || $.noop;

        this.triggeredFields = {};
    }

    PolicyForm.prototype.mustDisableField = function(elementName, element) {
        if (this.fields[elementName].disabled == true) {
            return true;
        }
        if ($(this.form).attr('method').toUpperCase() === 'PUT' && element.is_editable == false) {
            return true;
        }
        return false;
    }

    PolicyForm.prototype.newFormElement = function(elementName, value, after) {
        var field = this.fields[elementName];
        var element = field;
        var input_name = elementName;

        /* Arg */
        if (! value) value = this.values[elementName];

        if (this.fields[elementName].hide_filled && value) {
            this.fields[elementName].type = 'hidden';
        }

        /* Use select for checkboxes because non checked checkboxes are handled as
         * non filled inputs. So fill the select with yes/no vlaues.
         */
        var type = field.type;
        var options = field.options;
        this.fields[elementName].value_shift = 0;
        if (field.type === 'checkbox') {
            type = 'select';
            options = [ 'no', 'yes' ];
            if (this.fields[elementName].is_mandatory == null ||
                this.fields[elementName].is_mandatory == false) {
                this.fields[elementName].value_shift = 1;
            }
            if (value) {
                value = parseInt(value) + this.fields[elementName].value_shift;
            }
        }

        // If type is 'set', post fix the element name with the current index
        var inputid = 'input_' + elementName;
        if (field.set) {
            input_name = elementName + '_' + this.form.find(".input_" + elementName).length;
            inputid += '_' + this.form.find(".input_" + elementName).length;
        }

        var set_element
        // Create input and label DOM elements
        var label = $("<label>", { for : 'input_' + elementName, text : elementName });
        if (field.label !== undefined) {
            $(label).text(field.label);
        }
        if (type === undefined ||
            (type !== 'textarea' && type !== 'select')) {
            var type    = type || 'text';
            var input   = $("<input>", { type : type });
        } else if (type === 'textarea') {
            var type    = 'textarea';
            var input   = $("<textarea>");
        }
        else if (type === 'select') {
            var input   = $("<select>");
            var isArray = options instanceof Array;
            if (! this.fields[elementName].is_mandatory) {
                var option  = $("<option>", { value : 0, text : '-' });
                this.fields[elementName].value_shift = 1;
                input.append(option);
            }
            for (var i in options) if (options.hasOwnProperty(i)) {
                var optionvalue = (isArray != true) ? options[i] : parseInt(i) + this.fields[elementName].value_shift;
                var optiontext  = (isArray != true) ? i : options[i];
                var option  = $("<option>", { value : optionvalue, text : optiontext }).appendTo(input);
                if (optionvalue == value) {
                    option.attr('selected', 'selected');
                    if (this.fields[elementName].disable_filled) {
                        input.attr('disabled', 'disabled');
                    }
                }
            }
        }
        $(input).attr({ name : input_name, id : inputid, class : 'input_' + elementName, rel : elementName });

        this.validateRules[elementName] = {};
        // Check if the field is mandatory
        if (element.is_mandatory == true) {
            $(label).append(' *');
            this.validateRules[elementName].required = true;
        }
        // Check if the field must be validated by a regular expression
        if ($(input).attr('type') !== 'checkbox' && element.pattern !== undefined && element.is_mandatory) {
            this.validateRules[elementName].regex = element.pattern;
        }

        // Insert value if any
        if (value !== undefined) {
            if (type === 'text' || type === 'textarea' || type === 'hidden') {
                $(input).attr('value', value);
                if (type !== 'hidden') {
                    if (this.fields[elementName].disable_filled) {
                        input.attr('disabled', 'disabled');
                    }
                }
            } else if (type === 'checkbox' && value == true) {
                //$(input).attr('checked', 'checked');
                $(input).attr('value', '1');
                if (this.fields[elementName].disable_filled) {
                    input.attr('disabled', 'disabled');
                }
            }
        }

        $(label).text($(label).text() + " : ");

        // Finally, insert DOM elements in the form
        var tr;
        var container = this.findContainer(field.step);
        if (input.is("textarea")) {
            tr = this.insertTextarea(input, label, container, field.help || element.description, after);
        } else {
            tr = this.insertTextInput(input, label, container, field.help || element.description, after);
        }

        if (this.mustDisableField(elementName, element) === true) {
            $(input).attr('disabled', 'disabled');
        }

        if ($(input).attr('type') === 'date') {
            $(input).datepicker({ dateFormat : 'yyyy-mm-dd', constrainInput : true });
        } else if ($(input).attr('type') === 'datetime') {
            $(input).datetimepicker({
                timeOnly    : false,
                hourGrid    : 4,
                minuteGrid  : 10,
                closeText   : 'Close'
            });
        } else if ($(input).attr('type') === 'time') {
            $(input).timepicker({
                hourGrid    : 4,
                minuteGrid  : 10,
                closeText   : 'Close'
            });
        }

        return tr;
    }

    PolicyForm.prototype.newDropdownElement = function(elementName, options, current, after) {
        var container = this.findContainer(this.fields[elementName].step);
        var input_name = elementName;

        /* Arg */
        if (! current) {
            current = this.values[elementName];
        }

        if (this.fields[elementName].hide_filled && current) {
            
            this.fields[elementName].type = 'hidden';
            if (this.fields[elementName].parent) {
                /* @ @ You never had seen the following line @ @ */
                this.form.find('#input_' + this.fields[elementName].parent).parent().parent().hide();

                this.fields[this.fields[elementName].parent].type = 'hidden';
            }
        }

        // If type is 'set', post fix the element name with the current index
        var inputid = 'input_' + elementName;
        if (this.fields[elementName].set) {
            input_name = elementName + '_' + this.form.find(".input_" + elementName).length;
            inputid     += '_' + this.form.find(".input_" + elementName).length;
            console.log(">> " + this.form.find(".input_" + elementName).length);
        }

        // Create input and label DOM elements
        var label   = $("<label>", { for : 'input_' + elementName, text : elementName });
        if (this.fields[elementName].label !== undefined) {
            $(label).text(this.fields[elementName].label);
        }

        var input = $("<select>", { name : input_name, id : inputid, class : 'input_' + elementName, rel : elementName });

        this.validateRules[elementName] = {};
        // Check if the field is mandatory
        if (this.fields[elementName].is_mandatory == true) {
            $(label).append(' *');
            this.validateRules[elementName].required = true;
        }
        // Check if the field must be validated by a regular expression
        if ($(input).attr('type') !== 'checkbox' && this.fields[elementName].pattern !== undefined && this.fields[elementName].is_mandatory) {
            this.validateRules[elementName].regex = this.fields[elementName].pattern;
        }

        /* Ugly hard coded hack to fill the service provider value, if the
         * depending fields are filled. If we are in policy edition context, we
         * have values for managers, but not for the corresponding service
         * provider that containt the manager. So if manager are defined, ask
         * for the service provider id to fill the select input.
         */
        if (current === undefined) {
            for (var depend_index in this.fields[elementName].depends) {
                var depend = this.fields[elementName].depends[depend_index];

                if (this.values[depend]) {
                    var depend_obj = this.ajaxCall('GET', '/api/' + this.fields[depend].entity + '/' + this.values[depend]);

                    /* Another hard coded name here (service_provider_id) */
                    if (depend_obj.service_provider_id) {
                        current = depend_obj.service_provider_id;
                        break;
                    }
                }
            }
        }

        var datavalues;
        if (options) {
            datavalues = options;

        } else if (this.fields[elementName].parent) {
            var parent = this.form.find("#input_" + this.fields[elementName].parent);
            this.updateFromParent(input, parent.val());

            var that = this;
            parent.change(function (event) {
                that.updateFromParent(input, event.target.value);
            });

        } else {
            var entity = this.fields[elementName].entity;

            var route = '/api/' + entity;
            var delimiter = '?';
            var method = 'GET';
            var args;

            if (this.fields[elementName].filters) {
                if (this.fields[elementName].filters.func) {
                    method = 'POST';
                    route += '/' + this.fields[elementName].filters.func;
                    args = this.fields[elementName].filters.args;
                } else {
                    for (var filter in this.fields[elementName].filters) {
                        route += delimiter + filter + '=' + this.fields[elementName].filters[filter];
                        if (delimiter === '?') {
                            delimiter = '&';
                        }
                    }
                }
            }

            datavalues = this.ajaxCall(method, route, args);

            /*
             * We do not have a master class for component and connector, so we
             * cannot search among both type in one query. Another workaround
             * here...
             */
            if (entity === 'componenttype') {
                var connector_values = this.ajaxCall('GET', '/api/connectortype');

                /*
                 * Add all connector types to the component types list, and
                 * change the name of the attr to display (component_name).
                 */
                for (var connector in connector_values) {
                    connector_values[connector][this.fields[elementName].display] = connector_values[connector].connector_name;
                    datavalues.push(connector_values[connector]);
                }
            }
        }

        if (! this.fields[elementName].is_mandatory) {
            var option = $("<option>", { value : 0, text : '-' });
            input.append(option);

        } else if (this.fields[elementName].welcome_value) {
            var option = $("<option>", { value : 0, text : this.fields[elementName].welcome_value, id : 'welcome_' + elementName});
            input.append(option);

            test = options;
            var that = this;
            function updateRemoveWelcomeValueOnChange (event) {
                $('#welcome_' + input.attr('name')).remove();
            }
            input.change(updateRemoveWelcomeValueOnChange);
        }

        /* Inject all values in the select */
        for (value in datavalues) {
            var key = undefined;
            var text = undefined;
            if (typeof datavalues[value] === "object") {
                key = datavalues[value].pk;
                var display = 'pk';

                if (this.fields[elementName].display_func && this.fields[elementName].entity) {
                    text = this.ajaxCall('POST', '/api/' +  this.fields[elementName].entity + '/' + key + '/' + this.fields[elementName].display_func);

                } else {

                    /*
                     * Ugly hack for getting the name of the service provider,
                     * whatever its type. Please do not (git) blame me...
                     */
                    if (this.fields[elementName].entity === 'serviceprovider') {
                        for (var attr in datavalues[value]) {
                            if (attr.indexOf("_name", attr.length - "_name".length) !== -1) {
                                display = attr;
                            }
                        }
                    } else {
                        display = this.fields[elementName].display || 'pk';
                    }
                    text = datavalues[value][display];
                }
            } else {
                key = datavalues[value];
                text = datavalues[value];
            }

            var option = $("<option>", { value : key , text : text });

            $(input).append(option);
            if (current !== undefined && current == key) {
                option.attr('selected', 'selected');

                if (this.fields[elementName].disable_filled) {
                    input.attr('disabled', 'disabled');
                    //input.addClass('wizard-ignore');
                }
            }
        }

        if (this.mustDisableField(elementName, this.fields[elementName]) === true) {
            $(input).attr('disabled', 'disabled');
        }

        /*
         * If 'params' defined in the field, this is a field that raise dynamic
         * insertion/removal of other fields
         */
        if (this.fields[elementName].params) {
            var that = this;
            function updatePolicyParamsOnChange (event) {
                that.updatePolicyParams(input, event.target.value);
            }
            input.change(updatePolicyParamsOnChange);
        }

        // Finally, insert DOM elements in the form
        var inserted = this.insertTextInput(input, label, container, this.fields[elementName].help || this.fields[elementName].description, after);

        // Raise the onChange event to update related objects
        input.change();

        /*
         * If 'values_func' defined in the field, this is a field that could
         * fill other fields with key/value hash returned by the given function
         * call.
         */
        if (this.fields[elementName].trigger) {
            var that = this;
            function triggerOnChange (event) {
                that.insertTriggeredElements(input, elementName);
            }
            input.change(triggerOnChange);

        } else if (this.fields[elementName].values_provider) {
            /*
             * If 'values_func' defined in the field, this is a field that could
             * fill other fields with key/value hash returned by the given
             * function call.
             */
            var that = this;
            function updateValuesOnChange (event) {
                that.updateValues(input, event.target.value);
            }
            input.change(updateValuesOnChange);
        }

        return inserted;
    }

    PolicyForm.prototype.updateValues = function (element, selected_id) {
        var datavalues = undefined;
        var name = element.attr('name');
        var step = this.fields[name].step;

        if (! (name && parseInt(selected_id))) { return; }

        element.removeClass('disabled_policy_id');

        /* Unset any callback on change event handle policies update */
        var that = this;
        this.findContainer(step).find(':input').each(function() {
            $(this).unbind('.resetPolicy');
        });

        if (this.fields[name].values_provider.func) {
            /* Call the given function on the entity to get a values hash */
            datavalues = this.ajaxCall('POST',
                                       '/api/' + this.fields[name].entity + '/' + selected_id + '/' + this.fields[name].values_provider.func,
                                       this.fields[name].values_provider.args);
        }
        
        /* Complete the values hash with the entity attributes */
        var datavalues = jQuery.extend(datavalues, this.ajaxCall('GET', '/api/' + this.fields[name].entity + '/' + selected_id));

        /* TODO: Do not hard code this :) */
        if (this.fields[name].entity === 'policy') {
            datavalues[datavalues['policy_type'] + '_policy_name'] = datavalues['policy_name'];
            datavalues[datavalues['policy_type'] + '_policy_desc'] = datavalues['policy_desc'];
        }

        this.values = datavalues;

        var that = this;
        var update_select = function() {
        //this.form.find('select').each(function() {
            var select_name = $(this).attr('name');
            if (that.fields[select_name] && select_name !== name) {
                var reset_value;

                if (that.fields[select_name].is_mandatory) {
                    var options = $(this).find('option');
                    if (options[0]) {
                        reset_value = options[0].value;
                    }
                } else {
                    reset_value = 0;
                }

                $(this).val(reset_value);
                if (that.fields[select_name].depends) {
                    $(this).change();
                }

                if (! (that.fields[select_name].disabled || that.fields[select_name].disable_filled)) {
                    $(this).removeAttr('disabled');    
                }
                if (datavalues[select_name]) {
                    /*
                     * Firstly set the value of the the parent field if exist,
                     * to raise the onChange event that fill the current select
                     * with possibles values corresponding to the current value
                     * to set.
                     */
                    if (that.fields[select_name].parent) {
                        /*
                         * Ugly hard coded hack to fill the service provider
                         * value, if the depending fields are filled.
                         */
                        var manager = that.ajaxCall('GET', '/api/' + that.fields[select_name].entity + '/' + datavalues[select_name]);

                        // Another hard coded name here (service_provider_id)
                        if (manager.service_provider_id) {
                            var parent = that.form.find('#input_' + that.fields[select_name].parent);
                            parent.val(manager.service_provider_id);
                            parent.change();
                            parent.attr('disabled', 'disabled');
                        }
                    }

                    if (that.fields[select_name].value_shift) {
                        datavalues[select_name] = parseInt(datavalues[select_name]) + parseInt(that.fields[select_name].value_shift);
                    }
                    $(this).val(datavalues[select_name]);

                    if (that.fields[select_name].values_provider) {
                        $(this).change();
                    }
                    if (that.fields[select_name].disable_filled) {
                        $(this).addClass('wizard-ignore');
                        $(this).attr('disabled', 'disabled');
                    }

                    if (that.fields[select_name].hide_filled) {
                        $(this).parent().parent().hide();
                        if (that.fields[select_name].parent) {
                            var parent = that.form.find('#input_' + that.fields[select_name].parent);
                            parent.parent().parent().hide();
                        }
                    }
                }
            }
        };
        
        if (this.fields[name].fields_provided) {
            for (var provided in this.fields[name].fields_provided) {
                this.form.find('#input_' + this.fields[name].fields_provided[provided]).each(update_select);
            }
        } else {
            this.findContainer(step).find('select').each(update_select);
            
            this.findContainer(step).find('input').each(function() {
                $(this).val('');
                if (! (that.fields[$(this).attr('name')].disabled || that.fields[$(this).attr('name')].disable_filled)) {
                    $(this).removeAttr('disabled');    
                }
                if (datavalues[$(this).attr('name')]) {
                    $(this).val(datavalues[$(this).attr('name')]);
                    if (that.fields[$(this).attr('name')].disable_filled) {
                        $(this).attr('disabled', 'disabled');
                    }
                    if (that.fields[$(this).attr('name')].hide_filled) {
                        $(this).parent().parent().hide();
                    }
                }
            });
            this.findContainer(step).find('textarea').each(function() {
                $(this).val('');
                if (! (that.fields[$(this).attr('name')].disabled || that.fields[$(this).attr('name')].disable_filled)) {
                    $(this).removeAttr('disabled');    
                }
                if (datavalues[$(this).attr('name')]) {
                    $(this).val(datavalues[$(this).attr('name')]);
                    if (that.fields[$(this).attr('name')].disable_filled) {
                        $(this).attr('disabled', 'disabled');
                    }
                    if (that.fields[$(this).attr('name')].hide_filled) {
                        $(this).parent().parent().hide();
                    }
                }
            });
        }

        /* Ugly third loop to set a callback on change, because
         * the first loop could raise this callback on some fileds.
         * We really need to review the mecanism that fill values in fields.
         *
         * Set a callback on change event handle policies update.
         */
        var that = this;
        this.findContainer(step).find(':input').each(function() {
            var elementName = $(this).attr('name')

            if (that.fields[elementName].policy) {
                function resetPolicyIdOnChange (event) {
                    that.resetPolicyId(elementName);
                }
                $(this).bind('change.resetPolicy', resetPolicyIdOnChange);
            }
        });
        
       //element.addClass('wizard-ignore');
       // element.attr('disabled', 'diabled');
    }

    PolicyForm.prototype.resetPolicyId = function (elementName) {
        this.form.find('#input_' + this.fields[elementName].policy + '_policy_id').addClass('disabled_policy_id');
    }

    PolicyForm.prototype.updateFromParent = function (element, selected_id) {
        var datavalues = undefined;
        var name = element.attr('name');

        if (! name) { return; }

        /* Arg... Can not call the route according to
         * this.fields[elementName].entity, as we do not have a common parent
         * class for component and connector. So use the findManager workaround
         * method for instance.
         */
        var entity = this.fields[name].parent;

        var route;
        var method = 'GET';
        var args;

        if (this.fields[name].filters) {
            method = 'POST';
            route = '/api/' + this.fields[this.fields[name].parent].entity + '/' + selected_id;
            route += '/' + this.fields[name].filters.func;
            args = this.fields[name].filters.args ? this.fields[name].filters.args : {};

            // Arrgg, the parent field name is not 'service_provider_id', but 'storage_provider_id'...
            //args[this.fields[name].parent] = selected_id;
            var reg = new RegExp("^.*_provider_id", "g");
            if (this.fields[name].parent.match(reg)) {
                args['service_provider_id'] = selected_id;
            }
            else {
                args[this.fields[name].parent] = selected_id;
            }

        } else {
            route = '/api/' + this.fields[name].entity + '/' + this.fields[name].parent + '?' + selected_id;
        }
        datavalues = this.ajaxCall('POST', route, args);

        // Inject all values in the select
        element.empty();
        for (var value in datavalues) {
            var display = datavalues[value].pk;

            if (this.fields[name].display_func && this.fields[name].entity) {
                var ressource_name = this.ajaxCall('POST', '/api/' +  this.fields[name].entity + '/' + datavalues[value].pk + '/' + this.fields[name].display_func);
                if (ressource_name) display = ressource_name;
            } else if (datavalues[value].name) {
                display = datavalues[value].name;
            }

            var option  = $("<option>", { value : datavalues[value].pk , text : display });

            element.append(option);
            if (datavalues[value].pk == this.values[name]) {
                option.attr('selected', 'selected');
                if (this.fields[name].disable_filled) {
                    element.attr('disabled', 'disabled');
                }
            }
        }
        element.change();
    }

    PolicyForm.prototype.updatePolicyParams = function (element, selected_id) {
        var name  = element.attr('name');
        this.removeDynamicFields(name);

        if (! selected_id) { return; }

        var datavalues = this.ajaxCall('POST',
                                       '/api/' + this.fields[name].entity + '/' + selected_id + '/' + this.fields[name].params.func,
                                       this.fields[name].params.args);

        for (var value in datavalues) {
            this.fields[datavalues[value].name] = {
                label   : datavalues[value].label,
                step    : this.fields[name].step,
                policy  : this.fields[name].policy,
                prefix  : this.fields[name].prefix,
                disable_filled : this.fields[name].disable_filled,
                hide_filled    : this.fields[name].hide_filled,
                is_mandatory   : this.fields[name].is_mandatory,
            }

            var tr = undefined;
            if (datavalues[value].values) {
                tr = this.newDropdownElement(datavalues[value].name,
                                             datavalues[value].values,
                                             this.values[datavalues[value].name],
                                             name);
            } else {
                tr = this.newFormElement(datavalues[value].name, this.values[datavalues[value].name], name);
            }

            tr.addClass(name + '_policy_params');
            tr.addClass('policy_params');
        }
    }

    PolicyForm.prototype.removeDynamicFields = function (name) {
        var classtoremove;
        if (name) {
            classtoremove = name + '_policy_params';
        } else {
            classtoremove = 'policy_params';
        }

        var that = this;
        this.form.find("." + classtoremove).each(function  () {
            $(this).remove();
            delete that.fields[$(this).find(':input').attr('name')];
        });
    }

    PolicyForm.prototype.insertTriggeredElements = function (input, name) {
        if (this.fields[name].trigger) {
            for (var field in this.triggeredFields[name]) {
                this.fields[this.triggeredFields[name][field]].triggered = undefined;

                this.newElement(this.triggeredFields[name][field]);

                this.triggeredFields[name][field] = undefined;
            }
            this.triggeredFields[name] = new Array();

            if (this.fields[name].values_provider) {
                var that = this;
                function updateValuesOnChange (event) {
                    that.updateValues(input, event.target.value);
                }
                input.change(updateValuesOnChange);
            }
            this.fields[name].trigger = undefined;

            input.change();
        }
    }

    PolicyForm.prototype.findContainer = function(step) {
        if (step !== undefined) {
            var table = this.stepTables[step];
            if (table === undefined) {
               var table = $("<table>", { id : this.name + '_step' + step }).appendTo(this.form);
               table.attr('rel', step);
               $(table).css('width', '100%').addClass('step');
               this.stepTables[step] = table;
            }
            return table;
        } else {
            return this.table;
        }
    }

    PolicyForm.prototype.createHelpElem = function(help) {
        if (help !== undefined) {
            var helpElem        = $("<span>", { class : 'ui-icon ui-icon-info' });
            $(helpElem).css({
                cursor  : 'pointer',
                margin  : '2px 0 0 2px',
                float   : 'right'
            });
            $(helpElem).qtip({
                content : help,
                position: {
                    corner  : {
                        target  : 'rightMiddle',
                        tooltip : 'leftMiddle'
                    }
                },
                style   : {
                    tip : { corner  : 'leftMiddle' }
                }
            });
            return helpElem;
        } else {
            return undefined;
        }
    }

    PolicyForm.prototype.insertTextInput = function(input, label, container, help, after) {
        var linecontainer = $("<tr>").css('position', 'relative');
        $("<td>", { align : 'left' }).append(label).appendTo(linecontainer);
        $("<td>", { align : 'right' }).append(input).append(this.createHelpElem(help)).appendTo(linecontainer);

        if (this.fields[$(input).attr('rel')].type === 'hidden') {
            $(linecontainer).css('display', 'none');
        }

        if (after) {
            this.form.find("#input_" + after).parent().parent().after(linecontainer);
        } else {
            linecontainer.appendTo(container);
        }

        return linecontainer;
    }

    PolicyForm.prototype.insertTextarea = function(input, label, container, help, after) {
        var labelcontainer = $("<td>", { align : 'left', colspan : '2' }).append(label);
        var inputcontainer = $("<td>", { align : 'left', colspan : '2' }).append(input);
        var labelline = $("<tr>").append($(labelcontainer).append(this.createHelpElem(help)));
        var arealine = $("<tr>").append(inputcontainer);
        $(input).css('width', '100%');

        if (after) {
            this.form.find("#input_" + after).after(arealine);
            this.form.find("#input_" + after).after(labelline);
        } else {
            labelline.appendTo(container);
            arealine.appendTo(container);
        }
        return labelcontainer;
    }

    PolicyForm.prototype.beforeSerialize = function(form, options) {
        var that = this;
        this.form.find(':input').each(function () {
            var id      = "";
            var classes = $(this).attr('class').split(' ');
            for (var i in classes) if (classes.hasOwnProperty(i)) {
                if ((new RegExp('^input_')).test(classes[i])) {
                    id  = (classes[i]).replace('input_', '');
                    break;
                }
            }
            if (that.fields[id]){
                if (that.fields[id].prefix) {
                    $(this).attr('name', that.fields[id].prefix + $(this).attr('name'));
                }
                if (that.fields[id].type === 'checkbox' && parseInt($(this).val())) {
                    $(this).val(parseInt($(this).val()) - that.fields[id].value_shift);
                }
                if (that.fields[id].serialize != null) {
                    $(this).val(that.fields[id].serialize($(this).val()));
                }
            }
            $(this).removeClass('wizard-ignore');
        });
        this.form.find(".disabled_policy_id").each(function  () {
            $(this).attr('value', '0');
        });
    }

    PolicyForm.prototype.changeStep = function(event, data) {
        var steps   = $(this.form).children("table.step");
        var text    = "";
        var i       = 1;

        var that = this;

        $(steps).each(function() {
            var prepend = "";
            var append  = "";
            if ($(this).attr("id") == data.currentStep) {
                prepend = "<b>";
                append  = "</b>";
            }
            if (text === "") {
                text += prepend + i + ". " + $(this).attr('rel') + append;
            } else {
                text += " > " + prepend + i + ". " + $(this).attr('rel') + append;
            }

            ++i;
        });
        $(this.content).children("div#" + this.name + "_steps").html(text);
    }

    PolicyForm.prototype.handleBeforeSubmit = function(arr, $form, opts) {
        var b   = this.beforeSubmit(arr, $form, opts, this) || true;

        if (b) {
            var buttonsdiv = $(this.content).parents('div.ui-dialog').children('div.ui-dialog-buttonpane');
            buttonsdiv.find('button').each(function() {
                $(this).attr('disabled', 'disabled');
            });
        }
        return b;
    }

    PolicyForm.prototype.startWizard = function() {
        $(this.form).formwizard({
            disableUIStyles     : true,
            validationEnabled   : true,
            validationOptions   : {
                rules           : this.validateRules,
                messages        : this.validateMessages,
                errorClass      : 'ui-state-error',
                errorPlacement  : function(error, element) {
                    error.insertBefore(element);
                }
            },
            formPluginEnabled   : true,
            formOptions         : {
                beforeSerialize : $.proxy(this.beforeSerialize, this),
                beforeSubmit    : $.proxy(this.handleBeforeSubmit, this),
                success         : $.proxy(function(data) {
                    // Ugly but must delete all DOM elements
                    // but formwizard is using the element after this
                    // callback, so we delay the deletion
                    setTimeout($.proxy(function() { this.closeDialog(); }, this), 10);
                    this.callback(data);
                }, this),
                error           : $.proxy(function(data) {
                    var buttonsdiv = $(this.content).parents('div.ui-dialog').children('div.ui-dialog-buttonpane');
                    buttonsdiv.find('button').each(function() {
                        $(this).removeAttr('disabled', 'disabled');
                    });
                    $(this.content).find("div.ui-state-error").each(function() {
                        $(this).remove();
                    });
                    var error = JSON.parse(data.responseText);
                    $(this.content).prepend($("<div>", { text : error.reason, class : 'ui-state-error ui-corner-all' }));
                    this.error(data);
                }, this)
            }
        });

        var steps = $(this.form).children("table");
        if (steps.length > 1) {
            $(steps).each(function() {
                if (!$(this).html()) {
                    $(this).remove();
                }
            });
            $(this.content).prepend($("<br />"));
            $(this.content).prepend($("<div>", { id : this.name + "_steps" }).css({
                width           : '100%',
                'border-bottom' : '1px solid #AAA',
                position        : 'relative'
            }));
            this.changeStep({}, $(this.form).formwizard("state"));
            $(this.form).bind('step_shown', $.proxy(this.changeStep, this));
        }
    }

    PolicyForm.prototype.openDialog = function() {
        var buttons = {
            'Cancel'    : $.proxy(this.cancel, this),
            'Ok'        : $.proxy(this.validateForm, this)
        };
        if (this.skippable) {
            buttons['Skip'] = $.proxy(function() {
                this.closeDialog();
                this.callback();
            }, this);
        }
        this.content.dialog({
            title           : this.title,
            modal           : true,
            resizable       : false,
            draggable       : false,
            width           : 500,
            buttons         : buttons,
            closeOnEscape   : false,
        });
        $('.ui-dialog-titlebar-close').remove();
    }

    PolicyForm.prototype.cancel = function() {
        this.cancelCallback();
        this.closeDialog();
    }

    PolicyForm.prototype.closeDialog = function() {
        this.removeDynamicFields();

        $(this).dialog("close");
        $(this).dialog("destroy");
        $(this.form).formwizard("destroy");
        $(this.content).remove();
    }

    PolicyForm.prototype.validateForm = function () {
        var remove_wizard_ignore = function() {
            $(this).removeClass('wizard-ignore');
        }
        if ($(this.form).formwizard("state").currentStep) {
            var step_preffix = this.name + '_step';
            var step = $(this.form).formwizard("state").currentStep.substring(step_preffix.length);
            this.findContainer(step).find('.wizard-ignore').each(remove_wizard_ignore);

        } else {
            $(this.form).find('.wizard-ignore').each(remove_wizard_ignore);
        }

        $(this.form).formwizard("next");
    }

    PolicyForm.prototype.ajaxCall = function (method, route, data) {
        var response;
        try {
            $.ajax({
                type        : method,
                async       : false,
                url         : route,
                data        : data,
                dataTYpe    : 'json',
                error       : function(xhr, status, error) {
                    console.log('Ajax call failled: ' + xhr.status);
                },
                success     : $.proxy(function(d) {
                    response = d;
                }, this)
            });
        }
        catch (error) {
            console.log('Ajax call failled: ' + error.message);
        }
        return response;
    }

    return PolicyForm;
})();