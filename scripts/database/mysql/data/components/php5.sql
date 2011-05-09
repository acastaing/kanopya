USE `administrator`;
SET foreign_key_checks=0;

# Component
SET @eid_new_component = (SELECT MAX(component_id) FROM component) + 1;
INSERT INTO `component` VALUES (@eid_new_component,'Php','5','Tool');

# Template
SET @eid_new_component_template = (SELECT MAX(component_template_id) FROM component_template) + 1;
INSERT INTO `component_template` VALUES (@eid_new_component_template,'php','/templates/components/php5', @eid_new_component);

SET foreign_key_checks=1;
