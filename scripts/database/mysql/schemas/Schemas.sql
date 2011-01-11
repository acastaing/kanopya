DROP DATABASE IF EXISTS `administrator`;

CREATE DATABASE `administrator`;
USE `administrator`;

SET foreign_key_checks=0;

--
-- Table structure for table `kernel`
--

CREATE TABLE `kernel` (
  `kernel_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `kernel_name` char(64) NOT NULL,
  `kernel_version` char(32) NOT NULL,
  `kernel_desc` char(255) DEFAULT NULL,
  PRIMARY KEY (`kernel_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `processormodel`
--

CREATE TABLE `processormodel` (
  `processormodel_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `processormodel_brand` char(64) NOT NULL,
  `processormodel_name` char(32) NOT NULL,
  `processormodel_core_num` int(2) unsigned NOT NULL,
  `processormodel_clock_speed` float unsigned NOT NULL,
  `processormodel_l2_cache` int(2) unsigned NOT NULL,
  `processormodel_max_tdp` int(2) unsigned NOT NULL,
  `processormodel_64bits` int(1) unsigned NOT NULL,
  PRIMARY KEY (`processormodel_id`),
  UNIQUE KEY `processormodel_UNIQUE` (`processormodel_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `motherboardmodel`
--

CREATE TABLE `motherboardmodel` (
  `motherboardmodel_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `motherboardmodel_brand` char(64) NOT NULL,
  `motherboardmodel_name` char(32) NOT NULL,
  `motherboardmodel_chipset` char(64) NOT NULL,
  `motherboardmodel_processor_num` int(1) unsigned NOT NULL,
  `motherboardmodel_consumption` int(2) unsigned NOT NULL,
  `motherboardmodel_iface_num` int(1) unsigned NOT NULL,
  `motherboardmodel_ram_slot_num` int(1) unsigned NOT NULL,
  `motherboardmodel_ram_max` int(1) unsigned NOT NULL,
  `processormodel_id` int(8) unsigned DEFAULT NULL,
  PRIMARY KEY (`motherboardmodel_id`),
  UNIQUE KEY `motherboardmodel_name_UNIQUE` (`motherboardmodel_name`),
  KEY `fk_motherboardmodel_1` (`processormodel_id`),
  CONSTRAINT `fk_motherboardmodel_1` FOREIGN KEY (`processormodel_id`) REFERENCES `processormodel` (`processormodel_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `motherboard`
--

CREATE TABLE `motherboard` (
  `motherboard_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `motherboardmodel_id` int(8) unsigned NOT NULL,
  `processormodel_id` int(8) unsigned NOT NULL,
  `kernel_id` int(8) unsigned NOT NULL,
  `motherboard_serial_number` char(64) NOT NULL,
  `motherboard_powersupply_id` int(8) unsigned,
  `motherboard_desc` char(255) DEFAULT NULL,
  `active` int(1) unsigned NOT NULL,
  `motherboard_mac_address` char(18) NOT NULL,
  `motherboard_initiatorname` char(64) DEFAULT NULL,
  `motherboard_internal_ip` char(15) DEFAULT NULL,
  `motherboard_hostname` char(32) DEFAULT NULL,
  `etc_device_id` int(8) unsigned DEFAULT NULL,
  `motherboard_state` char(32) NOT NULL DEFAULT 'down', 
  PRIMARY KEY (`motherboard_id`),
  UNIQUE KEY `motherboard_internal_ip_UNIQUE` (`motherboard_internal_ip`),
  UNIQUE KEY `motherboard_mac_address_UNIQUE` (`motherboard_mac_address`),
  KEY `fk_motherboard_1` (`motherboardmodel_id`),
  KEY `fk_motherboard_2` (`processormodel_id`),
  KEY `fk_motherboard_3` (`kernel_id`),
  KEY `fk_motherboard_4` (`etc_device_id`),
  KEY `fk_motherboard_5` (`motherboard_powersupply_id`),
  CONSTRAINT `fk_motherboard_1` FOREIGN KEY (`motherboardmodel_id`) REFERENCES `motherboardmodel` (`motherboardmodel_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_motherboard_2` FOREIGN KEY (`processormodel_id`) REFERENCES `processormodel` (`processormodel_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_motherboard_3` FOREIGN KEY (`kernel_id`) REFERENCES `kernel` (`kernel_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_motherboard_4` FOREIGN KEY (`etc_device_id`) REFERENCES `lvm2_lv` (`lvm2_lv_id`) ON DELETE SET NULL ON UPDATE NO ACTION,
  CONSTRAINT `fk_motherboard_5` FOREIGN KEY (`motherboard_powersupply_id`) REFERENCES `powersupply` (`powersupply_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `motherboarddetails`
--

CREATE TABLE `motherboarddetails` (
  `motherboard_id` int(8) unsigned NOT NULL,
  `name` char(32) NOT NULL,
  `value` char(255) DEFAULT NULL,
  PRIMARY KEY (`motherboard_id`,`name`),
  KEY `fk_motherboarddetails_1` (`motherboard_id`),
  CONSTRAINT `fk_motherboarddetails_1` FOREIGN KEY (`motherboard_id`) REFERENCES `motherboard` (`motherboard_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


--
-- Table structure for table `powersupply`
--
CREATE TABLE `powersupply` (
  `powersupply_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `powersupplycard_id` int(8) unsigned NOT NULL,
  `powersupplyport_number` int(8) unsigned NOT NULL,
  PRIMARY KEY (`powersupply_id`),
  KEY `fk_powersupplycard_1` (`powersupplycard_id`),
  CONSTRAINT `fk_powersupplycard_1` FOREIGN KEY (`powersupplycard_id`) REFERENCES `powersupplycard` (`powersupplycard_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `powersupplycard`
--
CREATE TABLE `powersupplycard` (
  `powersupplycard_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `powersupplycard_name` char(64) NOT NULL,
  `powersupplycard_ip` char(15) DEFAULT NULL,
  `powersupplycard_model_id` int(8),
  `powersupplycard_mac_address` char(32) NOT NULL,
  `active` int(1),
  PRIMARY KEY (`powersupplycard_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


--
-- Table structure for table `distribution`
--

CREATE TABLE `distribution` (
  `distribution_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `distribution_name` char(64) NOT NULL,
  `distribution_version` char(32) NOT NULL,
  `distribution_desc` char(255) DEFAULT NULL,
  `etc_device_id` int(8) unsigned DEFAULT NULL,
  `root_device_id` int(8) unsigned DEFAULT NULL,
  PRIMARY KEY (`distribution_id`),
  KEY `fk_distribution_1` (`etc_device_id`),
  KEY `fk_distribution_2` (`root_device_id`),
  CONSTRAINT `fk_distribution_1` FOREIGN KEY (`etc_device_id`) REFERENCES `lvm2_lv` (`lvm2_lv_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_distribution_2` FOREIGN KEY (`root_device_id`) REFERENCES `lvm2_lv` (`lvm2_lv_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `cluster`
--

CREATE TABLE `cluster` (
  `cluster_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `cluster_name` char(32) NOT NULL,
  `cluster_desc` char(255) DEFAULT NULL,
  `cluster_type` int(1) unsigned DEFAULT NULL,
  `cluster_min_node` int(2) unsigned NOT NULL,
  `cluster_max_node` int(2) unsigned NOT NULL,
  `cluster_priority` int(1) unsigned NOT NULL,
  `active` int(1) unsigned NOT NULL,
  `systemimage_id` int(8) unsigned DEFAULT NULL,
  `kernel_id` int(8) unsigned DEFAULT NULL,
  `cluster_state` char(32) NOT NULL DEFAULT 'down', 
  PRIMARY KEY (`cluster_id`),
  UNIQUE KEY `cluster_name_UNIQUE` (`cluster_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `clusterdetails`
--

CREATE TABLE `clusterdetails` (
  `cluster_id` int(8) unsigned NOT NULL,
  `name` char(32) NOT NULL,
  `value` char(255) NOT NULL,
  PRIMARY KEY (`cluster_id`,`name`),
  KEY `fk_clusterdetails_1` (`cluster_id`),
  CONSTRAINT `fk_clusterdetails_1` FOREIGN KEY (`cluster_id`) REFERENCES `cluster` (`cluster_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `node`
--

CREATE TABLE `node` (
  `node_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `cluster_id` int(8) unsigned NOT NULL,
  `motherboard_id` int(8) unsigned NOT NULL,
  `master_node` int(1) unsigned DEFAULT NULL,
  PRIMARY KEY (`node_id`),
  KEY `cluster_id` (`cluster_id`,`motherboard_id`),
  KEY `fk_node_1` (`cluster_id`),
  KEY `fk_node_2` (`motherboard_id`),
  CONSTRAINT `fk_node_1` FOREIGN KEY (`cluster_id`) REFERENCES `cluster` (`cluster_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_node_2` FOREIGN KEY (`motherboard_id`) REFERENCES `motherboard` (`motherboard_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `operationtype`
--

CREATE TABLE `operationtype` (
  `operationtype_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `operationtype_name` char(64) DEFAULT NULL,
  PRIMARY KEY (`operationtype_id`),
  UNIQUE KEY `operationtype_name_UNIQUE` (`operationtype_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `operation`
--

CREATE TABLE `operation` (
  `operation_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `type` char(64) NOT NULL,
  `user_id` int(8) unsigned NOT NULL,
  `priority` int(2) unsigned NOT NULL,
  `creation_date` date NOT NULL,
  `creation_time` time NOT NULL,
  `hoped_execution_time` int(4) unsigned DEFAULT NULL,
  `execution_rank` int(8) unsigned NOT NULL,
  PRIMARY KEY (`operation_id`),
  UNIQUE KEY `execution_rank_UNIQUE` (`execution_rank`),
  KEY `fk_operation_queue_1` (`user_id`),
  KEY `fk_operation_queue_2` (`type`),
  CONSTRAINT `fk_operation_queue_1` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_operation_queue_2` FOREIGN KEY (`type`) REFERENCES `operationtype` (`operationtype_name`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `operation_parameter`
--

CREATE TABLE `operation_parameter` (
  `operation_param_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `name` char(64) NOT NULL,
  `value` char(255) NOT NULL,
  `operation_id` int(8) unsigned NOT NULL,
  PRIMARY KEY (`operation_param_id`),
  KEY `fk_operation_parameter_1` (`operation_id`),
  CONSTRAINT `fk_operation_parameter_1` FOREIGN KEY (`operation_id`) REFERENCES `operation` (`operation_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `systemimage`
--

CREATE TABLE `systemimage` (
  `systemimage_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `systemimage_name` char(32) NOT NULL,
  `systemimage_desc` char(255) DEFAULT NULL,
  `distribution_id` int(8) unsigned NOT NULL,
  `etc_device_id` int(8) unsigned DEFAULT NULL,
  `root_device_id` int(8) unsigned DEFAULT NULL,
  `active` int(1) unsigned NOT NULL,
  PRIMARY KEY (`systemimage_id`),
  UNIQUE KEY `systemimage_name_UNIQUE` (`systemimage_name`),
  KEY `fk_systemimage_1` (`distribution_id`),
  KEY `fk_systemimage_2` (`etc_device_id`),
  KEY `fk_systemimage_3` (`root_device_id`),
  CONSTRAINT `fk_systemimage_1` FOREIGN KEY (`distribution_id`) REFERENCES `distribution` (`distribution_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_systemimage_2` FOREIGN KEY (`etc_device_id`) REFERENCES `lvm2_lv` (`lvm2_lv_id`) ON DELETE SET NULL ON UPDATE NO ACTION,
  CONSTRAINT `fk_systemimage_3` FOREIGN KEY (`root_device_id`) REFERENCES `lvm2_lv` (`lvm2_lv_id`) ON DELETE SET NULL ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `publicip`
--

CREATE TABLE `publicip` (
  `publicip_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `ip_address` char(39) NOT NULL,
  `ip_mask` char(39) NOT NULL,
  `gateway` char(39) DEFAULT NULL,
  `cluster_id` int(8) unsigned DEFAULT NULL,
  PRIMARY KEY (`publicip_id`),
  KEY `fk_publicip_1` (`cluster_id`),
  CONSTRAINT `fk_publicip_1` FOREIGN KEY (`cluster_id`) REFERENCES `cluster` (`cluster_id`) ON DELETE SET NULL ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `route`
--

CREATE TABLE `route` (
  `route_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `publicip_id` int(8) unsigned NOT NULL,
  `ip_destination` char(39) NOT NULL,
  `gateway` char(39) DEFAULT NULL,
  PRIMARY KEY (`route_id`),
  KEY `fk_route_1` (`publicip_id`),
  CONSTRAINT `fk_route_1` FOREIGN KEY (`publicip_id`) REFERENCES `publicip` (`publicip_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `user`
--

CREATE TABLE `user` (
  `user_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `user_system` int(1) unsigned NOT NULL DEFAULT 0,
  `user_login` char(32) NOT NULL,
  `user_password` char(32) NOT NULL,
  `user_firstname` char(64) DEFAULT NULL,
  `user_lastname` char(64) DEFAULT NULL,
  `user_email` char(255) DEFAULT NULL,
  `user_creationdate` date DEFAULT NULL,
  `user_lastaccess` datetime DEFAULT NULL,
  `user_desc` char(255) DEFAULT 'Note concerning this user',
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `user_login` (`user_login`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `groups`
--

CREATE TABLE `groups` (
  `groups_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `groups_name` char(32) NOT NULL,
  `groups_type` char(32) NOT NULL,
  `groups_desc` char(255) DEFAULT NULL,
  `groups_system` int(1) unsigned NOT NULL,
  PRIMARY KEY (`groups_id`),
  UNIQUE KEY `groups_name` (`groups_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `message`
--

CREATE TABLE `message` (
  `message_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(8) unsigned DEFAULT NULL,
  `message_from` char(32) NOT NULL,
  `message_creationdate` date NOT NULL,
  `message_creationtime` time NOT NULL,
  `message_level` char(32) NOT NULL,
  `message_content` text(512) NOT NULL,
  PRIMARY KEY (`message_id`),
  KEY `fk_message_1` (`user_id`),
  CONSTRAINT `fk_message_1` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Component management tables
--

--
-- Table structure for table `component`
--

CREATE TABLE `component` (
  `component_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `component_name` varchar(32) NOT NULL,
  `component_version` varchar(32) NOT NULL,
  `component_category` varchar(32) NOT NULL,
  PRIMARY KEY (`component_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `component_provided`
--

CREATE TABLE `component_provided` (
  `component_id` int(8) unsigned NOT NULL,
  `distribution_id` int(8) unsigned NOT NULL,
  PRIMARY KEY (`component_id`,`distribution_id`),
  KEY `fk_component_provided_1` (`component_id`),
  KEY `fk_component_provided_2` (`distribution_id`),
  CONSTRAINT `fk_component_provided_1` FOREIGN KEY (`component_id`) REFERENCES `component` (`component_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_component_provided_2` FOREIGN KEY (`distribution_id`) REFERENCES `distribution` (`distribution_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `component_installed`
--

CREATE TABLE `component_installed` (
  `component_id` int(8) unsigned NOT NULL,
  `systemimage_id` int(8) unsigned NOT NULL,
  PRIMARY KEY (`component_id`,`systemimage_id`),
  KEY `fk_component_installed_1` (`component_id`),
  KEY `fk_component_installed_2` (`systemimage_id`),
  CONSTRAINT `fk_component_installed_1` FOREIGN KEY (`component_id`) REFERENCES `component` (`component_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_component_installed_2` FOREIGN KEY (`systemimage_id`) REFERENCES `systemimage` (`systemimage_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `component_instance`
--

CREATE TABLE `component_instance` (
  `component_instance_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `cluster_id` int(8) unsigned NOT NULL,
  `component_id` int(8) unsigned NOT NULL,
  `component_template_id` int(8) unsigned DEFAULT NULL,
  PRIMARY KEY (`component_instance_id`),
  KEY `fk_component_instance_1` (`cluster_id`),
  KEY `fk_component_instance_2` (`component_template_id`),
  KEY `fk_component_instance_3` (`component_id`),
  CONSTRAINT `fk_component_instance_1` FOREIGN KEY (`cluster_id`) REFERENCES `cluster` (`cluster_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `fk_component_instance_2` FOREIGN KEY (`component_template_id`) REFERENCES `component_template` (`component_template_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_component_instance_3` FOREIGN KEY (`component_id`) REFERENCES `component` (`component_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `component_template`
--

CREATE TABLE `component_template` (
  `component_template_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `component_template_name` varchar(45) NOT NULL,
  `component_template_directory` varchar(45) NOT NULL,
  `component_id` int(8) unsigned NOT NULL,
  PRIMARY KEY (`component_template_id`),
  UNIQUE KEY `component_template_UNIQUE` (`component_template_name`),
  KEY `fk_component_template_1` (`component_id`),
  CONSTRAINT `fk_component_template_1` FOREIGN KEY (`component_id`) REFERENCES `component` (`component_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `component_template_attr`
--

CREATE TABLE `component_template_attr` (
  `template_component_id` int(8) unsigned NOT NULL,
  `template_component_attr_file` varchar(45) NOT NULL,
  `component_template_attr_field` varchar(45) NOT NULL,
  `component_template_attr_type` varchar(45) NOT NULL,
  PRIMARY KEY (`template_component_id`),
  KEY `fk_component_template_attr_1` (`template_component_id`),
  CONSTRAINT `fk_component_template_attr_1` FOREIGN KEY (`template_component_id`) REFERENCES `component_template` (`component_template_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for orchestrator table `condition`
--

CREATE TABLE `rulecondition` (
  `rulecondition_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `rulecondition_var` varchar(32) NOT NULL,
  `rulecondition_time_laps` varchar(32) NOT NULL,
  `rulecondition_consolidation_func` varchar(32) NOT NULL,
  `rulecondition_transformation_func` varchar(32) NOT NULL,
  `rulecondition_operator` varchar(32) NOT NULL,
  `rulecondition_value` int(8) unsigned NOT NULL,
  `rule_id` int(8) unsigned DEFAULT NULL,
  PRIMARY KEY (`rulecondition_id`),
  KEY `fk_rulecondition_1` (`rule_id`),
  CONSTRAINT `fk_rulecondition_1` FOREIGN KEY (`rule_id`) REFERENCES `rule` (`rule_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for orchestrator table `rule`
--

CREATE TABLE `rule` (
  `rule_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `rule_condition` varchar(32) NOT NULL,
  `rule_action` varchar(32) NOT NULL,
  `cluster_id` int(8) unsigned DEFAULT NULL,
  PRIMARY KEY (`rule_id`),
  KEY `fk_rule_1` (`cluster_id`),
  CONSTRAINT `fk_rule_1` FOREIGN KEY (`cluster_id`) REFERENCES `cluster` (`cluster_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Entity tables
--

--
-- Table structure for table `entity`
--

CREATE TABLE `entity` (
  `entity_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`entity_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `ingroups`
--

CREATE TABLE `ingroups` (
  `groups_id` int(8) unsigned NOT NULL,
  `entity_id` int(8) unsigned NOT NULL,
  PRIMARY KEY (`groups_id`,`entity_id`),
  KEY `fk_grouping_1` (`entity_id`),
  KEY `fk_grouping_2` (`groups_id`),
  CONSTRAINT `fk_grouping_1` FOREIGN KEY (`entity_id`) REFERENCES `entity` (`entity_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `fk_grouping_2` FOREIGN KEY (`groups_id`) REFERENCES `groups` (`groups_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `entityright`
--

CREATE TABLE `entityright` (
  `entityright_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `entityright_consumed_id` int(8) unsigned NOT NULL,
  `entityright_consumer_id` int(8) unsigned NOT NULL,
  `entityright_method` char(64) NOT NULL,
  PRIMARY KEY (`entityright_id`),
  UNIQUE KEY `entityright_right` (`entityright_consumed_id`,`entityright_consumer_id`,`entityright_method`),
  KEY `fk_entityright_1` (`entityright_consumed_id`),
  KEY `fk_entityright_2` (`entityright_consumer_id`),
  CONSTRAINT `fk_entityright_1` FOREIGN KEY (`entityright_consumed_id`) REFERENCES `entity` (`entity_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `fk_entityright_2` FOREIGN KEY (`entityright_consumer_id`) REFERENCES `entity` (`entity_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `user_entity`
--

CREATE TABLE `user_entity` (
  `entity_id` int(8) unsigned NOT NULL,
  `user_id` int(8) unsigned NOT NULL,
  PRIMARY KEY (`entity_id`,`user_id`),
  UNIQUE KEY `fk_user_entity_1` (`entity_id`),
  UNIQUE KEY `fk_user_entity_2` (`user_id`),
  CONSTRAINT `fk_user_entity_1` FOREIGN KEY (`entity_id`) REFERENCES `entity` (`entity_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `fk_user_entity_2` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `distribution_entity`
--

CREATE TABLE `distribution_entity` (
  `entity_id` int(8) unsigned NOT NULL,
  `distribution_id` int(8) unsigned NOT NULL,
  PRIMARY KEY (`entity_id`,`distribution_id`),
  UNIQUE KEY `fk_distribution_entity_1` (`entity_id`),
  UNIQUE KEY `fk_distribution_entity_2` (`distribution_id`),
  CONSTRAINT `fk_distribution_entity_1` FOREIGN KEY (`entity_id`) REFERENCES `entity` (`entity_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `fk_distribution_entity_2` FOREIGN KEY (`distribution_id`) REFERENCES `distribution` (`distribution_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `motherboard_entity`
--

CREATE TABLE `motherboard_entity` (
  `entity_id` int(8) unsigned NOT NULL,
  `motherboard_id` int(8) unsigned NOT NULL,
  PRIMARY KEY (`entity_id`,`motherboard_id`),
  UNIQUE KEY `fk_motherboard_entity_1` (`entity_id`),
  UNIQUE KEY `fk_motherboard_entity_2` (`motherboard_id`),
  CONSTRAINT `fk_motherboard_entity_1` FOREIGN KEY (`entity_id`) REFERENCES `entity` (`entity_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `fk_motherboard_entity_2` FOREIGN KEY (`motherboard_id`) REFERENCES `motherboard` (`motherboard_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


--
-- Table structure for table `powersupplycard_entity`
--

CREATE TABLE `powersupplycard_entity` (
  `entity_id` int(8) unsigned NOT NULL,
  `powersupplycard_id` int(8) unsigned NOT NULL,
  PRIMARY KEY (`entity_id`,`powersupplycard_id`),
  UNIQUE KEY `fk_powersupplycard_entity_1` (`entity_id`),
  UNIQUE KEY `fk_powersupplycard_entity_2` (`powersupplycard_id`),
  CONSTRAINT `fk_powersupplycard_entity_1` FOREIGN KEY (`entity_id`) REFERENCES `entity` (`entity_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `fk_powersupplycard_entity_2` FOREIGN KEY (`powersupplycard_id`) REFERENCES `powersupplycard` (`powersupplycard_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `operation_entity`
--

CREATE TABLE `operation_entity` (
  `entity_id` int(8) unsigned NOT NULL,
  `operation_id` int(8) unsigned NOT NULL,
  PRIMARY KEY (`entity_id`,`operation_id`),
  UNIQUE KEY `fk_operation_entity_1` (`entity_id`),
  UNIQUE KEY `fk_operation_entity_2` (`operation_id`),
  CONSTRAINT `fk_operation_entity_1` FOREIGN KEY (`entity_id`) REFERENCES `entity` (`entity_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `fk_operation_entity_2` FOREIGN KEY (`operation_id`) REFERENCES `operation` (`operation_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `systemimage_entity`
--

CREATE TABLE `systemimage_entity` (
  `entity_id` int(8) unsigned NOT NULL,
  `systemimage_id` int(8) unsigned NOT NULL,
  PRIMARY KEY (`entity_id`,`systemimage_id`),
  UNIQUE KEY `fk_systemimage_entity_1` (`entity_id`),
  UNIQUE KEY `fk_systemimage_entity_2` (`systemimage_id`),
  CONSTRAINT `fk_systemimage_entity_1` FOREIGN KEY (`entity_id`) REFERENCES `entity` (`entity_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `fk_systemimage_entity_2` FOREIGN KEY (`systemimage_id`) REFERENCES `systemimage` (`systemimage_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `component_instance_entity`
--

CREATE TABLE `component_instance_entity` (
  `entity_id` int(8) unsigned NOT NULL,
  `component_instance_id` int(8) unsigned NOT NULL,
  PRIMARY KEY (`entity_id`,`component_instance_id`),
  UNIQUE KEY `fk_component_instance_entity_1` (`entity_id`),
  UNIQUE KEY `fk_component_instance_entity_2` (`component_instance_id`),
  CONSTRAINT `fk_component_instance_entity_1` FOREIGN KEY (`entity_id`) REFERENCES `entity` (`entity_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `fk_component_instance_entity_2` FOREIGN KEY (`component_instance_id`) REFERENCES `component_instance` (`component_instance_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `message_entity`
--

CREATE TABLE `message_entity` (
  `entity_id` int(8) unsigned NOT NULL,
  `message_id` int(8) unsigned NOT NULL,
  PRIMARY KEY (`entity_id`,`message_id`),
  UNIQUE KEY `fk_message_entity_1` (`entity_id`),
  UNIQUE KEY `fk_message_entity_2` (`message_id`),
  CONSTRAINT `fk_message_entity_1` FOREIGN KEY (`entity_id`) REFERENCES `entity` (`entity_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `fk_message_entity_2` FOREIGN KEY (`message_id`) REFERENCES `message` (`message_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `kernel_entity`
--

CREATE TABLE `kernel_entity` (
  `entity_id` int(8) unsigned NOT NULL,
  `kernel_id` int(8) unsigned NOT NULL,
  PRIMARY KEY (`entity_id`,`kernel_id`),
  UNIQUE KEY `fk_kernel_entity_1` (`entity_id`),
  UNIQUE KEY `fk_kernel_entity_2` (`kernel_id`),
  CONSTRAINT `fk_kernel_entity_1` FOREIGN KEY (`entity_id`) REFERENCES `entity` (`entity_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `fk_kernel_entity_2` FOREIGN KEY (`kernel_id`) REFERENCES `kernel` (`kernel_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `operationtype_entity`
--

CREATE TABLE `operationtype_entity` (
  `entity_id` int(8) unsigned NOT NULL,
  `operationtype_id` int(8) unsigned NOT NULL,
  PRIMARY KEY (`entity_id`,`operationtype_id`),
  UNIQUE KEY `fk_operationtype_entity_1` (`entity_id`),
  UNIQUE KEY `fk_operationtype_entity_2` (`operationtype_id`),
  CONSTRAINT `fk_operationtype_entity_1` FOREIGN KEY (`entity_id`) REFERENCES `entity` (`entity_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `fk_operationtype_entity_2` FOREIGN KEY (`operationtype_id`) REFERENCES `operationtype` (`operationtype_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `groups_entity`
--

CREATE TABLE `groups_entity` (
  `entity_id` int(8) unsigned NOT NULL,
  `groups_id` int(8) unsigned NOT NULL,
  PRIMARY KEY (`entity_id`,`groups_id`),
  UNIQUE KEY `fk_groups_entity_1` (`entity_id`),
  UNIQUE KEY `fk_groups_entity_2` (`groups_id`),
  CONSTRAINT `fk_groups_entity_1` FOREIGN KEY (`entity_id`) REFERENCES `entity` (`entity_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `fk_groups_entity_2` FOREIGN KEY (`groups_id`) REFERENCES `groups` (`groups_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `motherboardmodel_entity`
--

CREATE TABLE `motherboardmodel_entity` (
  `entity_id` int(8) unsigned NOT NULL,
  `motherboardmodel_id` int(8) unsigned NOT NULL,
  PRIMARY KEY (`entity_id`,`motherboardmodel_id`),
  UNIQUE KEY `fk_motherboardmodel_entity_1` (`entity_id`),
  UNIQUE KEY `fk_motherboardmodel_entity_2` (`motherboardmodel_id`),
  CONSTRAINT `fk_motherboardmodel_entity_1` FOREIGN KEY (`entity_id`) REFERENCES `entity` (`entity_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_motherboardmodel_entity_2` FOREIGN KEY (`motherboardmodel_id`) REFERENCES `motherboardmodel` (`motherboardmodel_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `processormodel_entity`
--

CREATE TABLE `processormodel_entity` (
  `entity_id` int(8) unsigned NOT NULL,
  `processormodel_id` int(8) unsigned NOT NULL,
  PRIMARY KEY (`entity_id`,`processormodel_id`),
  UNIQUE KEY `fk_processormodel_entity_1` (`entity_id`),
  UNIQUE KEY `fk_processormodel_entity_2` (`processormodel_id`),
  CONSTRAINT `fk_processormodel_entity_1` FOREIGN KEY (`entity_id`) REFERENCES `entity` (`entity_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `fk_processormodel_entity_2` FOREIGN KEY (`processormodel_id`) REFERENCES `processormodel` (`processormodel_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


--
-- Table structure for table `cluster_entity`
--

CREATE TABLE `cluster_entity` (
  `entity_id` int(8) unsigned NOT NULL,
  `cluster_id` int(8) unsigned NOT NULL,
  PRIMARY KEY (`entity_id`,`cluster_id`),
  UNIQUE KEY `fk_cluster_entity_1` (`entity_id`),
  UNIQUE KEY `fk_cluster_entity_2` (`cluster_id`),
  CONSTRAINT `fk_cluster_entity_1` FOREIGN KEY (`entity_id`) REFERENCES `entity` (`entity_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `fk_cluster_entity_2` FOREIGN KEY (`cluster_id`) REFERENCES `cluster` (`cluster_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

SET foreign_key_checks=1;

