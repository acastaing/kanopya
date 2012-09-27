require('jquery/jquery.form.js');
require('jquery/jquery.validate.js');
require('jquery/jquery.form.wizard.js');
require('jquery/jquery.qtip.min.js');

$.validator.addMethod("regex", function(value, element, regexp) {
    var re = new RegExp(regexp);
    return this.optional(element) || re.test(value);
}, "Please check your input");

$.validator.addMethod("confirm_password", function(value, element, input) {
    return value === $(input).val();
}, "Password differs");

var FormWizardBuilder = (function() {
    function FormWizardBuilder(args) {
        this.handleArgs(args);

        this.content = $("<div>", { id : this.name });

        this.validateRules    = {};
        this.validateMessages = {};

        // Check if it is a creation or an update form
        var method = 'POST';
        var action = '/api/' + this.type;
        if (this.id != null) {
            method  = 'PUT';
            action += '/' + this.id;
        }

        if (args.prependElement !== undefined) {
            this.content.prepend($(args.prependElement));
        }

        // Initialize the from
        this.form   = $("<form>", { method : method, action : action });
        this.table  = $("<table>");
        this.tables = [];

        this.form.appendTo(this.content).append(this.table);

        this.attributedefs = {};

        // Retrieve data structure and values from api
        var response   = this.attrsCallback(this.type);
        var attributes = response.attributes;
        var relations  = response.relations;

        this.table.css('width', 500);

        // If it is an update form, retrieve old datas from api
        var values = {};
        if (this.id) {
            values = this.valuesCallback(this.type, this.id);
        }

        // Firstly merge the attrdef with possible raw attrdef given in params
        jQuery.extend(true, attributes, this.rawattrdef);

        // Build the form section corresponding to the object/class attributes
        this.buildFromAttrDef(attributes, this.displayed, values, relations);

        // For each relation 1-N, list all entries, add input to create an entry
        for (relation_name in this.relations) if (this.relations.hasOwnProperty(relation_name)) {
            var relationdef = relations[relation_name];

            // Get the relation type attrdef
            var response = this.attrsCallback(relationdef.resource);
            var rel_attributedefs = response.attributes;
            var rel_relationdefs  = response.relations;

            // Tag attr defs as belongs to a relation
            for (var name in rel_attributedefs) {
                rel_attributedefs[name].belongs_to = relation_name;
            }

            // If creation, find the foreign key name to remove the attr from relation attrs
            var foreign;
            for (var cond in relationdef.cond) if (cond.indexOf('foreign.') >= 0) {
                foreign = cond.substring(8);
            }
            if (!foreign) {
                throw new Error("FormWizardBuilder: Could not find the foreign key for relation " + relation_name);
            }
            if (!this.id) {
                delete rel_attributedefs[foreign];
            } else {
                rel_attributedefs[foreign].value = this.id;
            }

            // Build in one line the form inputs corresponding to the relation
            var add_button = $("<input>", { text : 'Add', class : 'wizard-ignore', type: 'button' });
            var add_button_line = $("<tr>").css('position', 'relative');
            $("<td>", { colspan : 2 }).append(add_button).appendTo(add_button_line);
            this.findTable(this.attributedefs[relation_name].label || relation_name, this.attributedefs[relation_name].step).append(add_button_line);

            var _this = this;
            add_button.bind('click', function() {
                _this.buildFromAttrDef(rel_attributedefs, _this.relations[relation_name], {},
                                       rel_relationdefs, _this.attributedefs[relation_name].label || relation_name);

            });
            add_button.button({ icons : { primary : 'ui-icon-plusthick' } });
            add_button.val('Add');

            // For each relation entries, add filled inputs in one line
            for (var entry in values[relation_name]) {
                this.buildFromAttrDef(rel_attributedefs, this.relations[relation_name],
                                      values[relation_name][entry], rel_relationdefs,
                                      this.attributedefs[relation_name].label || relation_name);
            }
        }
    }

    FormWizardBuilder.prototype.buildFromAttrDef = function(attributes, displayed, values, relations, listing) {
        var ordered_attributes = {};

        // Building a new hash according to the orderer list of displayed attrs
        for (name in displayed) {
            ordered_attributes[displayed[name]] = attributes[displayed[name]];
            delete attributes[displayed[name]];
        }
        for (hidden in attributes) {
            attributes[hidden].hidden = true;
            ordered_attributes[hidden] = attributes[hidden];
        }

        // Extends the global attribute def hash with the new one.
        jQuery.extend(true, this.attributedefs, ordered_attributes);

        // For each attributes, add an input to the form
        for (var name in ordered_attributes) if (ordered_attributes.hasOwnProperty(name)) {
            var value = this.attributedefs[name].value || values[name] || undefined;

            // Get options for select inputs
            if (this.attributedefs[name].type === 'relation' && this.attributedefs[name].options === undefined &&
                (this.attributedefs[name].relation === 'single' || this.attributedefs[name].relation === 'multi')) {
                this.attributedefs[name].options = this.buildSelectOptions(name, value, relations);
            }

            // Finally create the input field with label
            this.newFormInput(name, value, listing);
        }

        if ($(this.content).height() > $(window).innerHeight() - 200) {
            $(this.content).css('height', $(window).innerHeight() - 200);
            $(this.content).css('width', $(this.content).width() + 15);
        }
    }

    FormWizardBuilder.prototype.buildSelectOptions = function(name, value, relations) {
        var resource;
        if (relations[name]) {
            // Relation is multi to multi
            resource = this.attributedefs[name].expand;

        } else {
            // Relation is single to single
            for (relation in relations) {
                for (prop in relations[relation].cond) {
                    if (relations[relation].cond.hasOwnProperty(prop)) {
                        if (relations[relation].cond[prop] === 'self.' + name) {
                            resource = relations[relation].resource;
                            break;
                        }
                    }
                }
            }
        }
        var options = ajax('GET', '/api/' + resource);

        // If there is no options but a fixed value,
        // add the value to options.
        if (options === undefined && value !== undefined) {
            options = [ value ];
        }
        return options !== undefined ? options : [];
    }

    FormWizardBuilder.prototype.newFormInput = function(name, value, listing) {
        var attr = this.attributedefs[name];

        // Create input and label DOM elements
        var label = $("<label>", { for : 'input_' + name, text : name });

        // Use the label if defined
        if (attr.label !== undefined) {
            $(label).text(attr.label);
        }

        var input = undefined;

        // Handle text fields
        if (toInputType(attr.type) === 'textarea') {
            input = $("<textarea>");

        // Handle select fields
        } else if (toInputType(attr.type) === 'select') {
            input = $("<select>", { width: 200 });

            // If relation is multi, set the multiple select attribute
            if (attr.relation === 'multi') {
                input.attr('multiple', 'multiple');
            }

            // Inserting select options
            for (var i in attr.options) if (attr.options.hasOwnProperty(i)) {

                var optionvalue = attr.options[i].pk || attr.options[i];
                var optiontext  = attr.options[i].label || attr.options[i].pk || attr.options[i];
                var option = $("<option>", { value : optionvalue, text : optiontext }).appendTo(input);
                if (attr.formatter != null) {
                    $(option).text(attr.formatter($(option).text()));
                }

                // Set current option to value if defined
                if (optionvalue === value) {
                    $(option).attr('selected', 'selected');
                }
            }

        // Handle other field types
        } else {
            input = $("<input>", { type : attr.type ? toInputType(attr.type) : 'text', width: 196 });
        }

        // Set the field as hidden if defined
        if (attr.hidden) {
            input.attr('type', 'hidden');
        }

        // Set the input attributes
        $(input).attr({ name : name, id : 'input_' + name, rel : name });

        // Check if the attr is mandatory
        this.validateRules[name] = {};
        if (attr.is_mandatory == true) {
            $(label).append(' *');
            if ($(input).attr('type') !== 'checkbox') {
                this.validateRules[name].required = true;
            }

        } else if (toInputType(attr.type) === 'select' && attr.relation === 'single') {
            var option = $("<option>", { value : '', text : '-' }).prependTo(input);
            if (value === undefined) {
                $(option).attr('selected', 'selected');
            }
        }

        // Check if the attr must be validated by a regular expression
        if ($(input).attr('type') !== 'checkbox' && attr.pattern !== undefined) {
            if (attr.is_mandatory != true) {
                attr.pattern = '(^$|' + attr.pattern + ')';
            }
            this.validateRules[name].regex = attr.pattern;
        }

        // Insert value if any
        if (value !== undefined) {
            if (input.is('input')) {
                if (input.attr('type') == 'checkbox') {
                    if (value == true) {
                        $(input).attr('checked', 'checked');
                    }
                } else {
                    $(input).attr('value', value);
                }
            } else if (input.is('textarea')) {
                $(input).text(value);
            }
        }

        // Finally, insert DOM elements in the form
        this.insertInput(input, label, this.findTable(listing, attr.step), attr.help || attr.description, listing);

        // Disable the field if required
        if (this.mustDisableField(name) === true) {
            $(input).attr('disabled', 'disabled');
        }

        if ($(input).attr('type') === 'date') {
            $(input).datepicker({ dateFormat : 'yyyy-mm-dd', constrainInput : true });
        }

        /*
         * Unit management
         * - simple value to display beside attr
         * - unit selector when unit is 'byte' (MB, GB) and display current
         *   value with the more appropriate value
         *
         * See policiesform for management of unit depending on value of another attr
         */
        if (attr.unit) {
            var unit_cont = $('<span>');
            var unit_field_id = 'unit_' + $(input).attr('id');
            $(input).parent().append(unit_cont);

            var current_unit;
            addFieldUnit(attr, unit_cont, unit_field_id).addClass('wizard-ignore');
            current_unit = attr.unit;

            // Set the serialize attribute to manage convertion from (selected) unit to final value
            // Warning : this will override serialize attribute if defined
            this.attributedefs[name].serialize = function(val, input) {
                return val * getUnitMultiplicator('unit_' + $(input).attr('id'));
            }

            // If exist a value then convert it in human readable
            if (current_unit === 'byte' && $(input).val()) {
                var readable_value = getReadableSize($(input).val(), 1);
                $(input).val( readable_value.value );
                $(unit_cont).find('option:contains("' + readable_value.unit + '")').attr('selected', 'selected');
            }

            // TODO: Get the real lenght of the unit select box.
            $(input).width($(input).width() - 50);
        }
    }

    FormWizardBuilder.prototype.insertInput = function(input, label, table, help, listing) {
        var linecontainer;
        console.log($(input).attr('name') + ', ' + listing);
        if (listing) {
            // TOTO: Handle all special caracters as accent, etc
            listing = listing.replace(/ /g, '_');

            var listing_size;
            if (input.attr('type') === 'checkbox') {
                listing_size = 50;
            } else {
                listing_size = input.width() - 50;
            }
            input.width(listing_size);

            // Search for the line that contains labels for this listing
            var labelsline = $(table).find('tr.labels_' + listing).get(0);
            if (! labelsline) {
                // Add an empty line if not exists
                labelsline = $("<tr>").css('position', 'relative')
                labelsline.addClass('labels_' + listing);
                labelsline.appendTo(table);
                // Add a column for actions
                labeltd = $("<td>", { align : 'center' });
                labeltd.appendTo(labelsline);
            }

            var line = $(table).find('tr.' + listing).get(0);

            // Search for the label of the current field within the labels line
            var labeltd = $(labelsline).find('td.label_' + $(input).attr('name')).get(0);
            if (! labeltd) {
                // The label for this column does not exists yet,
                // we are building the first line of the listing.
                labeltd = $("<td>", { align : 'center' }).append(label);
                labeltd.addClass('label_' + $(input).attr('name'));
                labeltd.appendTo(labelsline);

            } else {
                // The labels line has been filled, so we can use
                // the number of columns to kown when swithing to next line.
                if ($(line).children('td').length >= $(labelsline).children('td').length) {
                    $(line).removeClass(listing);
                    line = undefined;
                };
            }

            // Build a new line if required
            if (! line) {
                line = $("<tr>").css('position', 'relative')
                line.addClass(listing);
                line.appendTo(table);

                // Add a button to remove the line
                var removeButton = $('<a>').button({ icons : { primary : 'ui-icon-closethick' }, text : false });
                removeButton.addClass('wizard-ignore');
                removeButton.bind('click', function () {
                    $(line).remove();
                    if ($(table).find('tr').length <= 2) {
                        $(labelsline).remove();
                    }
                });
                var td = $("<td>", { align : 'left' });
                td.append(removeButton);
                line.append(td);
            }

            var inputcontainer = $("<td>", { align : 'center' }).append(input);

            // Hide the line if required
            if ($(input).attr('type') === 'hidden') {
                $(inputcontainer).css('display', 'none');
                $(labeltd).css('display', 'none');
            }

            inputcontainer.appendTo(line);

            return;
        }

        $(label).text($(label).text() + " : ");

        // Add the line to the container
        if (input.is("textarea")) {
            var labelcontainer = $("<td>", { align : 'left', colspan : '2' }).append(label);
            var inputcontainer = $("<td>", { align : 'left', colspan : '2' }).append(input);
            var labelline = $("<tr>").append($(labelcontainer).append(this.createHelpElem(help))).appendTo(table);

            // Hide the label if required
            if ($(input).attr('type') === 'hidden') {
                $(labelline).css('display', 'none');
            }

            linecontainer = $("<tr>").append(inputcontainer);
            $(input).css('width', '100%');

        } else {
            linecontainer = $("<tr>").css('position', 'relative');
            $("<td>", { align : 'left' }).append(label).appendTo(linecontainer);
            $("<td>", { align : 'right' }).append(input).append(this.createHelpElem(help)).appendTo(linecontainer);
        }
        linecontainer.appendTo(table);

        // Hide the line if required
        if ($(input).attr('type') === 'hidden') {
            $(linecontainer).css('display', 'none');
        }

        // Add a confirm password line if required
        if ($(input).attr('type') === 'password') {
            var lineclone = $(linecontainer).clone();

            var _this = this;
            lineclone.find(':input').each(function() {
                // Update attrs
                $(this).attr('name', $(this).attr('name') + '_confirm');
                $(this).attr('id', $(this).attr('id') + '_confirm');
                $(this).attr('rel', $(this).attr('rel') + '_confirm');

                // Update label
                lineclone.find("label").each(function() {
                    $(this).text('Confirm ' + $(this).text());
                });
                $(this).addClass('wizard-ignore');

                // Set a validation rule to compare with password
                _this.validateRules[$(this).attr('name')] = {};
                _this.validateRules[$(this).attr('name')].confirm_password = $(input);
            });
            lineclone.appendTo(table);
        }
    }

    FormWizardBuilder.prototype.mustDisableField = function(name) {
        if (this.attributedefs[name].disabled == true) {
            return true;
        }
        if ($(this.form).attr('method').toUpperCase() === 'PUT' && this.attributedefs[name].is_editable != true &&
            !(this.attributedefs[name].is_primary == true && this.attributedefs[name].belongs_to != undefined)) {
            return true;
        }
        return false;
    }

    FormWizardBuilder.prototype.beforeSerialize = function(form, options) {
        var _this = this;
        $(form).find(':input').not('.wizard-ignore').each(function () {
            // Must transform all 'on' or 'off' values from checkboxes to '1' or '0'
            if (toInputType(_this.attributedefs[$(this).attr('name')].type) === 'checkbox') {

                if ($(this).attr('value') === 'on' && $(this).attr('checked')) {
                    $(this).attr('value', '1');
                } else {
                    $(this).attr('value', '0');
                    // Check the checkbox if we want the value submited
                    $(this).attr('checked', 'checked');
                }

            // Disable password confirmation inputs
            } else if ($(this).attr('type') === 'password') {
                $('#' + $(this).attr('id') + '_confirm').attr('disabled', 'disabled');
            }

            if (_this.attributedefs[$(this).attr('name')].serialize != null) {
                $(this).val(_this.attributedefs[$(this).attr('name')].serialize($(this).val(), $(this)));
            }

            // Disable empty non mandatory fields, only if there are select or not editable.
            if ($(this).val() === '' && ! _this.attributedefs[$(this).attr('name')].is_mandatory &&
                (toInputType(_this.attributedefs[$(this).attr('name')].type) === 'select' ||
                 ! _this.attributedefs[$(this).attr('name')].is_editable)) {

                $(this).attr('disabled', 'disabled');
            }
        });
    }

    FormWizardBuilder.prototype.handleBeforeSubmit = function(arr, $form, opts) {
        console.log(arr);
        // Building a hash representing the object with its relations
        var data = {};
        var rel_attr_names = [];
        for (var index in arr) {
            var attr = arr[index];

            // If the attr is an attr of a relation,
            // move value in the corresponding sub hash
            var hash_to_fill;
            if (this.attributedefs[attr.name].belongs_to) {
                var rel_list = data[this.attributedefs[attr.name].belongs_to];

                if (rel_list === undefined) {
                    data[this.attributedefs[attr.name].belongs_to] = [];
                    rel_list = data[this.attributedefs[attr.name].belongs_to];
                }

                // If attr not in the array, we are completing an entry
                if ($.inArray(attr.name, rel_attr_names) < 0 && rel_attr_names.length) {
                    rel_attr_names.push(attr.name);

                // If not, we are starting a new entry
                } else {
                    rel_attr_names = [attr.name]
                    rel_list.push({});
                }
                hash_to_fill = rel_list[rel_list.length - 1];

            } else {
                hash_to_fill = data;
            }
            if (this.attributedefs[attr.name].relation === 'multi') {
                console.log(attr.name + ' is multi');
                if (! hash_to_fill[attr.name]) {
                    hash_to_fill[attr.name] = [];
                }
                hash_to_fill[attr.name].push(attr.value);

            } else {
                hash_to_fill[attr.name] = attr.value;
            }
        }
        console.log(data);
        this.submitCallback(data, $form, opts, $.proxy(this.onSuccess, this), $.proxy(this.onError, this));

        return false;
    }

    FormWizardBuilder.prototype.submit = function(data, $form, opts) {
//      var buttonsdiv = $(this.content).parents('div.ui-dialog').children('div.ui-dialog-buttonpane');
//      buttonsdiv.find('button').each(function() {
//          $(this).attr('disabled', 'disabled');
//      });

        // We submit the from ourself because we want the data into json,
        // as we need to submit relations in a subhash.
        $.ajax({
            url         : $(this.form).attr('action'),
            type        : $(this.form).attr('method').toUpperCase(),
            contentType : 'application/json',
            data        : JSON.stringify(data),
            success     : $.proxy(this.onSuccess, this),
            error       : $.proxy(this.onError, this),
        });
    }

    FormWizardBuilder.prototype.getValues = function(type, id) {
        var url = '/api/' + type + '/' + id;

        // For each relation 1-N, use expand to get related entries with object values
        if (this.relations) {
            var expands = [];
            for (relation in this.relations) if (this.relations.hasOwnProperty(relation)) {
                expands.push(relation);
            }
            url += '?expand=' + expands.join(',');
        }
        return ajax('GET', url);
    }

    FormWizardBuilder.prototype.getAttributes = function(resource) {
        return ajax('GET', '/api/attributes/' + resource);
    }

    FormWizardBuilder.prototype.findTable = function(tag, step) {
        if (tag !== undefined) {
            tag.replace(/ /g, '_');

            var table = this.tables[tag];
            if (table === undefined) {
                var table = $("<table>", { id : this.name + '_tag_' + tag });

                var fieldset = $("<fieldset>").appendTo(this.form);
                var legend   = $("<legend>", { text : tag }).css('font-weight', 'bold');
                fieldset.css('border-color', '#ddd');
                fieldset.append(legend);
                fieldset.append(table);

                $(table).css('width', '100%');
                if (step !== undefined) {
                    table.attr('rel', step);
                    $(table).addClass('step');
                }
                this.tables[tag] = table;
            }
            return table;

        } else {
            return this.table;
        }
    }

    FormWizardBuilder.prototype.start = function() {
        $(document).append(this.content);
        // Open the modal and start the form wizard
        this.openDialog();
        this.startWizard();
    }

    FormWizardBuilder.prototype.handleArgs = function(args) {
        if ('type' in args) {
            this.type = args.type;
            this.name = 'form_' + args.type;
        } else {
            throw new Error("FormWizardBuilder : Must provide a type");
        }

        this.id             = args.id;
        this.displayed      = args.displayed      || [];
        this.relations      = args.relations      || {};
        this.rawattrdef     = args.rawattrdef     || {};
        this.callback       = args.callback       || $.noop;
        this.title          = args.title          || this.name;
        this.skippable      = args.skippable      || false;
        this.submitCallback = args.submitCallback || this.submit;
        this.valuesCallback = args.valuesCallback || this.getValues;
        this.attrsCallback  = args.attrsCallback  || this.getAttributes;
        this.cancelCallback = args.cancel         || $.noop;
        this.error          = args.error          || $.noop;
    }

    FormWizardBuilder.prototype.exportArgs = function() {
        return {
            type            : this.type,
            id              : this.id,
            displayed       : this.displayed,
            relations       : this.relations,
            rawattrdef      : this.rawattrdef,
            callback        : this.callback,
            title           : this.title,
            skippable       : this.skippable,
            submitCallback  : this.submitCallback,
            valuesCallback  : this.valuesCallback,
            attrsCallback   : this.attrsCallback,
            cancel          : this.cancelCallback
        };
    }

    FormWizardBuilder.prototype.createHelpElem = function(help) {
        if (help !== undefined) {
            var helpElem = $("<span>", { class : 'ui-icon ui-icon-info' });
            $(helpElem).css({ cursor : 'help', margin : '2px 0 0 2px', float : 'right' });
            $(helpElem).qtip({
                content  : help.replace("\n", "<br />", 'g'),
                position : {
                    corner : {
                        target  : 'rightMiddle',
                        tooltip : 'leftMiddle'
                    }
                },
                style : { tip : { corner  : 'leftMiddle' } }
            });
            return helpElem;

        } else {
            return $("<span>").css({ display : 'block', width : '16px', 'margin-left' : '2px',
                                     height : '1px', float : 'right' });
        }
    }

    FormWizardBuilder.prototype.changeStep = function(event, data) {
        var steps   = $(this.form).children("table.step");
        var text    = "";
        var i       = 1;
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
                text += " >> " + prepend + i + ". " + $(this).attr('rel') + append;
            }
            ++i;
        });
        $(this.content).children("div#" + this.name + "_steps").html(text);
    }

    FormWizardBuilder.prototype.startWizard = function() {
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
                success         : $.proxy(this.onSuccess, this),
                error           : $.proxy(this.onError, this),
            }
        });

        var steps = $(this.form).children("table.step")
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

    FormWizardBuilder.prototype.onSuccess = function(data) {
        // Ugly but must delete all DOM elements
        // but formwizard is using the element after this
        // callback, so we delay the deletion
        this.closeDialog();
        this.callback(data, this.form);

        return data;
    }

    FormWizardBuilder.prototype.onError = function(data) {
        var buttonsdiv = $(this.content).parents('div.ui-dialog').children('div.ui-dialog-buttonpane');
        buttonsdiv.find('button').each(function() {
            $(this).removeAttr('disabled', 'disabled');
        });
        $(this.content).find("div.ui-state-error").each(function() {
            $(this).remove();
        });
        var error = {};
        try {
            error = JSON.parse(data.responseText);
        }
        catch (err) {
            error.reason = 'An error occurs, but can not be parsed...'
        }
        $(this.content).prepend($("<div>", { text : error.reason, class : 'ui-state-error ui-corner-all' }));
        this.error(data);
    }

    FormWizardBuilder.prototype.openDialog = function() {
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
            position        : 'top',
            width           : 'auto',
            minWidth        : 550,
//            maxHeight       : 550,
            buttons         : buttons,
            closeOnEscape   : false
        });
        $('.ui-dialog-titlebar-close').remove();
    }

    FormWizardBuilder.prototype.cancel = function() {
        var state = $(this.form).formwizard("state");
        if (state.isFirstStep) {
            this.cancelCallback();
            this.closeDialog();
        }
        else {
            $(this.form).formwizard("back");
        }
    }

    FormWizardBuilder.prototype.closeDialog = function() {
        setTimeout($.proxy(function() {
            $(this).dialog("close");
            $(this).dialog("destroy");
            $(this.form).formwizard("destroy");
            $(this.content).remove();
        }, this), 10);
    }

    FormWizardBuilder.prototype.validateForm = function () {
        $(this.form).formwizard("next");
    }

    return FormWizardBuilder;
    
})();


var ModalForm = (function() {
    function ModalForm(args) {
        this.handleArgs(args);
        
        this.content = $("<div>", { id : this.name });
        
        this.validateRules    = {};
        this.validateMessages = {};
        
        var method      = 'POST';
        var action      = '/api/' + this.baseName;
        // Check if it is a creation or an update form
        if (this.id != null) {
            method  = 'PUT';
            action  += '/' + this.id;
        }
        if (args.prependElement !== undefined) {
            this.content.prepend($(args.prependElement));
        }
        this.form       = $("<form>", { method : method, action : action}).appendTo(this.content).append(this.table);
        this.table      = $("<table>").css('width', '100%').appendTo($(this.form));
        this.stepTables = [];
        
        // Retrieve data structure from REST
        $.ajax({
            type        : 'GET',
            // no_relations option allow to keep old field management (see below)
            // TODO : review fields management and use generic FormWizardBuilder instead of this class (ModalForm)
            url         : '/api/attributes/' + this.baseName + '?no_relations=1',
            dataType    : 'json',
            async       : false,
            success     : $.proxy(function(data) {
                    var values = {};
                    // If it is an update form, retrieve old datas from REST

                    if (this.id != null) {
                        $.ajax({
                            type        : 'GET',
                            async       : false,
                            url         : '/api/' + this.baseName + '/' + this.id,
                            dataType    : 'json',
                            success     : function(data) {
                                values = data;
                            }
                        });
                    }
                    
                    // For each element in the data structure, add an input
                    // to the form
                    for (elem in this.fields) if (this.fields.hasOwnProperty(elem)) {
                        var val = values[elem] || this.fields[elem].value;
                        if (elem in data.attributes) { // Whether just an input
                            this.newFormElement(elem, data.attributes[elem], val);
                        } else if (this.fields[elem].skip == true) {
                            this.newFormElement(elem, {}, val);
                        } else { // Or retrieve all possibles values and create a select element
                            var datavalues = this.getForeignValues(data, elem);
                            this.newDropdownElement(elem, data.attributes[elem], val, datavalues);
                        }
                    }
            }, this)
        });
    }
    
    ModalForm.prototype.start = function() {
        $(document).append(this.content);
        // Open the modal and start the form wizard
        this.openDialog();
        this.startWizard();
    }
    
    ModalForm.prototype.getForeignValues = function(data, elem) {
        var datavalues = undefined;
        for (relation in data.relations) {
            for (prop in data.relations[relation].cond)
            if (data.relations[relation].cond.hasOwnProperty(prop)) {
                if (data.relations[relation].cond[prop] === 'self.' + elem) {
                    var cond = this.fields[elem].cond || "";
                    relation    = data.relations[relation].resource;
                    $.ajax({
                        type        : 'GET',
                        async       : false,
                        url         : '/api/' + relation + cond,
                        dataType    : 'json',
                        success     : $.proxy(function(d) {
                            datavalues = d;
                        }, this)
                    });
                    break;
                }
                break;
            }
        }
        return datavalues;
    }
    
    ModalForm.prototype.handleArgs = function(args) {
        
        if ('name' in args) {
            this.baseName   = args.name;
            this.name       = 'form_' + args.name;
        } else {
            throw new Error("ModalForm : Must provide a name");
        }
        
        this.id             = args.id;
        this.callback       = args.callback     || $.noop;
        if (args.fields) {
            this.fields         = args.fields;
        } else {
            throw new Error("ModalForm : Must provide at least one field");
        }
        this.title          = args.title        || this.name;
        this.skippable      = args.skippable    || false;
        this.beforeSubmit   = args.beforeSubmit || $.noop;
        this.cancelCallback = args.cancel       || $.noop;
        this.error          = args.error        || $.noop;
    }
 
    ModalForm.prototype.exportArgs = function() {
        return {
            name            : this.name,
            id              : this.id,
            callback        : this.callback,
            fields          : this.fields,
            title           : this.title,
            skippable       : this.skippable,
            beforeSubmit    : this.beforeSubmit,
            cancel          : this.cancelCallback
        };
    }
    
    ModalForm.prototype.mustDisableField = function(elementName, element) {
        if (this.fields[elementName].disabled == true) {
            return true;
        }
        if ($(this.form).attr('method').toUpperCase() === 'PUT' && element.is_editable == false) {
            return true;
        }
        return false;
    }

    ModalForm.prototype.newFormElement = function(elementName, element, value) {
        var field = this.fields[elementName];
        // Create input and label DOM elements
        var label = $("<label>", { for : 'input_' + elementName, text : elementName });
        if (field.label !== undefined) {
            $(label).text(field.label);
        }
        if (field.type === undefined ||
            (field.type !== 'textarea' && field.type !== 'select')) {
            var type    = field.type || 'text';
            var input   = $("<input>", { type : type });
        } else if (field.type === 'textarea') {
            var type    = 'textarea';
            var input   = $("<textarea>");
        } else if (field.type === 'select') {
            var input   = $("<select>");
            var isArray = field.options instanceof Array;
            for (var i in field.options) if (field.options.hasOwnProperty(i)) {
                var optionvalue = field.options[i];
                var optiontext  = (isArray != true) ? i : field.options[i];
                var option  = $("<option>", { value : optionvalue, text : optiontext }).appendTo(input);
                if (optionvalue === value) {
                    $(option).attr('selected', 'selected');
                }
            }
        }
        $(input).attr({ name : elementName, id : 'input_' + elementName, rel : elementName });
        if (this.fields[elem].skip == true) {
            $(input).addClass('wizard-ignore');
            $(input).attr('name', '');
        }
        
        this.validateRules[elementName] = {};
        // Check if the field is mandatory
        if (element.is_mandatory == true) {
            $(label).append(' *');
            this.validateRules[elementName].required = true;
        }
        // Check if the field must be validated by a regular expression
        if ($(input).attr('type') !== 'checkbox' && element.pattern !== undefined) {
            this.validateRules[elementName].regex = element.pattern;
        }
        
        // Insert value if any
        if (value !== undefined) {
            if (type === 'text' || type === 'hidden') {//patched for hidden fields
                $(input).attr('value', value);
            } else if (type === 'checkbox' && value == true) {
                $(input).attr('checked', 'checked');
            } else if (type === 'textarea') {
                $(input).text(value);
            }
        }
        
        $(label).text($(label).text() + " : ");
        
        // Finally, insert DOM elements in the form
        var container = this.findContainer(field.step);
        if (input.is("textarea")) {
            this.insertTextarea(input, label, container, field.help || element.description);
        } else {
            this.insertTextInput(input, label, container, field.help || element.description);
        }

        if (this.mustDisableField(elementName, element) === true) {
            $(input).attr('disabled', 'disabled');
        }

        if ($(input).attr('type') === 'date') {
            $(input).datepicker({ dateFormat : 'yyyy-mm-dd', constrainInput : true });
        }

        // manage unit
        // - simple value to display beside field
        // - unit selector when unit is 'byte' (MB, GB) and display current value with the more appropriate value
        // See policiesform for management of unit depending on value of another field
        if (field.unit) {
            var unit_cont = $('<span>');
            var unit_field_id ='unit_' + $(input).attr('id');
            $(input).parent().append(unit_cont);

            var current_unit;
            addFieldUnit(field, unit_cont, unit_field_id);
            current_unit = field.unit;

            // Set the serialize attribute to manage convertion from (selected) unit to final value
            // Warning : this will override serialize attribute if defined
            this.fields[elementName].serialize = function(val, elem) {
                return val * getUnitMultiplicator('unit_' + $(elem).attr('id'));
            }

            // If exist a value then convert it in human readable
            if (current_unit === 'byte' && $(input).val()) {
                var readable_value = getReadableSize($(input).val(), 1);
                $(input).val( readable_value.value );
                $(unit_cont).find('option:contains("' + readable_value.unit + '")').attr('selected', 'selected');
            }
        }
    }
    
    ModalForm.prototype.newDropdownElement = function(elementName, element, current, values) {
        // Create input and label DOM elements
        var label   = $("<label>", { for : 'input_' + elementName, text : elementName });
        if (this.fields[elementName].label !== undefined) {
            $(label).text(this.fields[elementName].label);
        }
        $(label).text($(label).text() + ' * :');
        var input   = $("<select>", { name : elementName, id : 'input_' + elementName, rel : elementName });

        // Inject all values in the select
        for (value in values) {
            var display = this.fields[elementName].display || 'pk';
            var option  = $("<option>", { value : values[value].pk , text : values[value][display] });
            if (this.fields[elementName].formatter != null) {
                $(option).text(this.fields[elementName].formatter($(option).text()));
            }
            $(input).append(option);
            if (current !== undefined && current == values[value].pk) {
                $(option).attr('selected', 'selected');
            }
        }
        
        // Finally, insert DOM elements in the form
        var container = this.findContainer(this.fields[elementName].step);
        this.insertTextInput(input, label, container);
    }
    
    ModalForm.prototype.findContainer = function(step) {
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

    ModalForm.prototype.createHelpElem = function(help) {
        if (help !== undefined) {
            var helpElem        = $("<span>", { class : 'ui-icon ui-icon-info' });
            $(helpElem).css({
                cursor  : 'help',
                margin  : '2px 0 0 2px',
                float   : 'right'
            });
            $(helpElem).qtip({
                content : help.replace("\n", "<br />", 'g'),
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
            return $("<span>").css({ display : 'block', width : '16px', 'margin-left' : '2px', height : '1px', float : 'right' });
        }
    }

    ModalForm.prototype.insertTextInput = function(input, label, container, help) {
        var linecontainer   = $("<tr>").css('position', 'relative').appendTo(container);
        $("<td>", { align : 'left' }).append(label).appendTo(linecontainer);
        $("<td>", { align : 'right' }).append(input).append(this.createHelpElem(help)).appendTo(linecontainer);
        if (this.fields[$(input).attr('rel')].type === 'hidden') {
            $(linecontainer).css('display', 'none');
        }
    }
    
    ModalForm.prototype.insertTextarea = function(input, label, container, help) {
        var labelcontainer = $("<td>", { align : 'left', colspan : '2' }).append(label);
        var inputcontainer = $("<td>", { align : 'left', colspan : '2' }).append(input);
        $("<tr>").append($(labelcontainer).append(this.createHelpElem(help))).appendTo(container);
        $("<tr>").append(inputcontainer).appendTo(container);
        $(input).css('width', '100%');
    }
    
    ModalForm.prototype.beforeSerialize = function(form, options) {
        // Must transform all 'on' or 'off' values from checkboxes to '1' or '0'
        for (field in this.fields) {
            if (this.fields[field].type === 'checkbox') {
                var checkbox = $(form).find('input[name="' + field + '"]');
                if (checkbox.attr('value') === 'on') {
                    if (checkbox.attr('checked')) {
                        checkbox.attr('value', '1');
                    } else {
                        checkbox.attr('value', '0');
                    }
                } else if (checkbox.attr('value') === 'off') {
                    checkbox.attr('value', '0');
                }
            }
            if (this.fields[field].serialize != null) {
                var input = $(form).find('input[name="' + field + '"]');
                $(input).val(this.fields[field].serialize($(input).val(), input));
            }
        }
    }
    
    ModalForm.prototype.changeStep = function(event, data) {
        var steps   = $(this.form).children("table.step");
        var text    = "";
        var i       = 1;
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
                text += " >> " + prepend + i + ". " + $(this).attr('rel') + append;
            }
            ++i;
        });
        $(this.content).children("div#" + this.name + "_steps").html(text);
    }
    
    ModalForm.prototype.handleBeforeSubmit = function(arr, $form, opts) {
        // Add data to submit for each unchecked checkbox
        // Because by default no data are posted for unchecked box
        $form.find(':checkbox').each(function() {
            if ($(this).val() == 0) {
                arr.push({name: $(this).attr('name'), value: 0});
            }
        });

        var b   = this.beforeSubmit(arr, $form, opts, this);
        if (b) {
            var buttonsdiv = $(this.content).parents('div.ui-dialog').children('div.ui-dialog-buttonpane');
            buttonsdiv.find('button').each(function() {
                $(this).attr('disabled', 'disabled');
            });
        }
        return b;
    }
    
    ModalForm.prototype.startWizard = function() {
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
                success         : $.proxy(this.onSuccess, this),
                error           : $.proxy(this.onError, this),
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
    
    ModalForm.prototype.openDialog = function() {
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
            width           : 500,
            buttons         : buttons,
            closeOnEscape   : false
        });
        $('.ui-dialog-titlebar-close').remove();
    }

    ModalForm.prototype.cancel = function() {
        var state = $(this.form).formwizard("state");
        if (state.isFirstStep) {
            this.cancelCallback();
            this.closeDialog();
        }
        else {
            $(this.form).formwizard("back");
        }
        
    }
 
    ModalForm.prototype.closeDialog = function() {
        setTimeout($.proxy(function() {
            $(this).dialog("close");
            $(this).dialog("destroy");
            $(this.form).formwizard("destroy");
            $(this.content).remove();
        }, this), 10);
    }
 
    ModalForm.prototype.validateForm = function () {
        $(this.form).formwizard("next");
    }
    
    return ModalForm;
    
})();
