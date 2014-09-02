USE `kanopya`;

SET foreign_key_checks=0;

--
-- Table structure for table `linux`
--

CREATE TABLE `linux` (
  `linux_id` int(8) unsigned NOT NULL,
  `default_gateway_id` int(8) unsigned DEFAULT NULL,
  `domainname` char(64) NOT NULL,
  `nameserver1` char(15) NOT NULL,
  `nameserver2` char(15) NOT NULL,
  PRIMARY KEY (`linux_id`),
  FOREIGN KEY (`linux_id`) REFERENCES `component` (`component_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  FOREIGN KEY (`default_gateway_id`) REFERENCES `network` (`network_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `linux_mount` (
  `linux_mount_id` int(8) unsigned NOT NULL AUTO_INCREMENT,  
  `linux_id` int(8) unsigned NOT NULL,  
  `linux_mount_device` char(64) NOT NULL,
  `linux_mount_point` char(64) NOT NULL,
  `linux_mount_filesystem` char(32) NOT NULL,
  `linux_mount_options` char(128) NOT NULL DEFAULT 'defaults',
  `linux_mount_dumpfreq` int(1) NOT NULL DEFAULT 0,
  `linux_mount_passnum` enum('0','1','2') NOT NULL DEFAULT '0',
  PRIMARY KEY (`linux_mount_id`),
  UNIQUE KEY `linux_mount_unique1` (`linux_id`,`linux_mount_device`,`linux_mount_point`),
  FOREIGN KEY (`linux_id`) REFERENCES `linux` (`linux_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

SET foreign_key_checks=1;
