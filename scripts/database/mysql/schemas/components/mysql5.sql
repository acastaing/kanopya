USE `kanopya`;

SET foreign_key_checks=0;

--
-- Table structure for mysql5
--

CREATE TABLE `mysql5` (
  `mysql5_id` int(8) unsigned NOT NULL,
  `mysql5_port` int(2) unsigned NOT NULL DEFAULT 3306,
  `mysql5_datadir` char(64) NOT NULL DEFAULT '/var/lib/mysql',
  `mysql5_bindaddress` char(17) NOT NULL DEFAULT '127.0.0.1', 
  PRIMARY KEY (`mysql5_id`),
  CONSTRAINT FOREIGN KEY (`mysql5_id`) REFERENCES `component` (`component_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

SET foreign_key_checks=1;
