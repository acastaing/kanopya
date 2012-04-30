USE `kanopya`;

SET foreign_key_checks=0;

--
-- Table structure for table `kanopyacollector1`
--

CREATE TABLE `kanopyacollector1` (
    `kanopya_collector1_id` int(8) unsigned NOT NULL,
    `collect_frequency` int unsigned NOT NULL DEFAULT 3600,
    `storage_time` int unsigned NOT NULL DEFAULT 86400,
    PRIMARY KEY (`kanopya_collector1_id`),
    CONSTRAINT FOREIGN KEY (`kanopya_collector1_id`) REFERENCES `component` (`component_id`) ON DELETE CASCADE ON UPDATE NO ACTION
)   ENGINE=InnoDB DEFAULT CHARSET=utf8;

SET foreign_key_checks=1;
