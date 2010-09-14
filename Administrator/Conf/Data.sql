USE `administrator`;
SET foreign_key_checks=0;
SET @eid := 1;

--
-- permanents data
--

-- user and groups
INSERT INTO `groups` VALUES 
(1,'User','User master group',1),
(2,'Processortemplate','Processortemplate master group',1),
(3,'Motherboardtemplate','Motherboardtemplate master group',1),
(4,'Motherboard','Motherboard master group',1),
(5,'Cluster','Cluster master group',1),
(6,'Distribution','Distribution master group',1),
(7,'Kernel','Kernel master group',1),
(8,'Systemimage','Systemimage master group',1),
(9,'Operationtype','Operationtype master group',1),
(10,'admin','for administration tasks',1);
INSERT INTO `entity` VALUES (@eid); INSERT INTO `groups_entity` VALUES (@eid,1); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `groups_entity` VALUES (@eid,2); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `groups_entity` VALUES (@eid,3); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `groups_entity` VALUES (@eid,4); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `groups_entity` VALUES (@eid,5); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `groups_entity` VALUES (@eid,6); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `groups_entity` VALUES (@eid,7); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `groups_entity` VALUES (@eid,8); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `groups_entity` VALUES (@eid,9); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `groups_entity` VALUES (@eid,10); SET @eid := @eid +1;


INSERT INTO `user` VALUES (1,'executer','executer','executer','executer',NULL,'2010-07-22',NULL,'executer');
INSERT INTO `entity` VALUES (@eid); INSERT INTO `user_entity` VALUES (@eid,1); SET @eid := @eid +1;

-- motherboard and processor models
INSERT INTO `processormodel` VALUES (1,'Intel','Atom 330',2,2,0,2,17,0,0,NULL);
INSERT INTO `entity` VALUES (@eid); INSERT INTO `processormodel_entity` VALUES (@eid,1); SET @eid := @eid +1;

INSERT INTO `motherboardmodel` VALUES (1,'Intel','DG945GCLF2','945GC',2,42,1,1,2,1);
INSERT INTO `entity` VALUES (@eid); INSERT INTO `motherboardmodel_entity` VALUES (@eid,1); SET @eid := @eid +1;

-- operation types list
INSERT INTO `operationtype` VALUES 
(1,'AddMotherboard'),
(2,'ModifyMotherboard'),
(3,'RemoveMotherboard'),
(4,'ActivateMotherboard'),
(5,'DeactivateMotherboard'),
(6,'AddCluster'),
(7,'ModifyCluster'),
(8,'RemoveCluster'),
(9,'ActivateCluster'),
(10,'DeactivateCluster'),
(11,'StartCluster'),
(12,'StopCluster'),
(13,'AddSystemimage'),
(14,'CloneSystemimage'),
(15,'ModifySystemimage'),
(16,'RemoveSystemimage'),
(17,'ActivateSystemimage'),
(18,'DeactivateSystemimage'),
(19,'AddMotherboardInCluster'),
(20,'RemoveMotherboardFromCluster'),
(21,'AddComponentToCluster'),
(22,'RemoveComponentFromCluster');

INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,1); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,2); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,3); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,4); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,5); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,6); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,7); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,8); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,9); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,10); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,11); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,12); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,13); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,14); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,15); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,16); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,17); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,18); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,19); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,20); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,21); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `operationtype_entity` VALUES (@eid,22); SET @eid := @eid +1;


-- components list
INSERT INTO `component` VALUES 
(1,'Lvm','2','Storage'),
(2,'Apache','2','Webserver'),
(3,'Iscsitarget','1','Export'),
(4,'Openiscsi','2','Exportclient'),
(5,'Dhcpd','3','Dhcpserver'),
(6,'Atftpd','0','Tftpserver'),
(7,'Snmpd','5','Snmpagent');

-- kernels
INSERT INTO `kernel` VALUES (1,'admin','2.6.32','Admin Kernel');
--INSERT INTO `kernel` VALUES (2,'2.6.26-2-486','2.6.26-2-486','');
--INSERT INTO `kernel` VALUES (3,'2.6.26-2-xen-686','2.6.26-2-xen-686','');
--INSERT INTO `kernel` VALUES (4,'2.6.26-hedera','2.6.26-hedera','');
INSERT INTO `kernel` VALUES (5,'2.6.30.1-hedera','2.6.30.1-hedera','');
--INSERT INTO `kernel` VALUES (6,'2.6.31-hederatech-minix','2.6.31-hederatech-minix','');
--INSERT INTO `kernel` VALUES (7,'2.6.31-hederatech-via-vb8001','2.6.31-hederatech-via-vb8001','');
--INSERT INTO `kernel` VALUES (8,'2.6.31-hederatech-zotac-ion','2.6.31-hederatech-zotac-ion','');
INSERT INTO `entity` VALUES (@eid); INSERT INTO `kernel_entity` VALUES (@eid,1); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `kernel_entity` VALUES (@eid,2); SET @eid := @eid +1;
--INSERT INTO `entity` VALUES (@eid); INSERT INTO `kernel_entity` VALUES (@eid,3); SET @eid := @eid +1;
--INSERT INTO `entity` VALUES (@eid); INSERT INTO `kernel_entity` VALUES (@eid,4); SET @eid := @eid +1;
--INSERT INTO `entity` VALUES (@eid); INSERT INTO `kernel_entity` VALUES (@eid,5); SET @eid := @eid +1;
--INSERT INTO `entity` VALUES (@eid); INSERT INTO `kernel_entity` VALUES (@eid,6); SET @eid := @eid +1;
--INSERT INTO `entity` VALUES (@eid); INSERT INTO `kernel_entity` VALUES (@eid,7); SET @eid := @eid +1;
--INSERT INTO `entity` VALUES (@eid); INSERT INTO `kernel_entity` VALUES (@eid,8); SET @eid := @eid +1;

-- default distribution
INSERT INTO `distribution` VALUES (1,'Debian','5.0','Debian Lenny',1,2);
INSERT INTO `entity` VALUES (@eid); INSERT INTO `distribution_entity` VALUES (@eid,1); SET @eid := @eid +1;

-- components provided by default distribution
INSERT INTO `component_provided` VALUES (2,1),(4,1),(7,1);

-- default systemimage based on default distribution
INSERT INTO `systemimage` VALUES (1,'DebianSystemImage','default system image based on Debian 5.0 distribution', 1, 3, 4, 0);
INSERT INTO `entity` VALUES (@eid); INSERT INTO `systemimage_entity` VALUES (@eid,1); SET @eid := @eid +1;

-- components installed on systemimage DebianSystemImage
INSERT INTO `component_installed` VALUES (2,1),(4,1),(7,1);

-- admin cluster
INSERT INTO `cluster` VALUES (1,'adm','Main Cluster hosting Administrator, Executor, Boot server and NAS',0,1,1,500,1,NULL,1, 'up');
INSERT INTO `entity` VALUES (@eid); INSERT INTO `cluster_entity` VALUES (@eid,1); SET @eid := @eid +1;

-- public ip for admin cluster
INSERT INTO `publicip` VALUES (1,'192.168.0.1','255.255.255.0',NULL,1); 

-- admin motherboard
INSERT INTO `motherboard` VALUES (1,1,1,1,'Admin SN',1,'Admin motherboard',1,'00:1c:c0:c0:a9:1b','adm.hederatech.com','10.0.0.1','node001',NULL, 'up');
INSERT INTO `entity` VALUES (@eid); INSERT INTO `motherboard_entity` VALUES (@eid,1); SET @eid := @eid +1;

-- admin node
INSERT INTO `node` VALUES (1,1,1,1);

-- components templates
INSERT INTO `component_template` VALUES (1,'defaultapache','/templates/defaultapache', 2);
INSERT INTO `component_template` VALUES (2,'mcsdhcpd','/templates/mcsdhcpd', 5);

-- initial components instance for admin cluster: 
INSERT INTO `component_instance` VALUES (1,1,1,NULL),(2,1,2,1),(3,1,3,NULL),(4,1,5,2),(5,1,6,NULL);
INSERT INTO `entity` VALUES (@eid); INSERT INTO `component_instance_entity` VALUES (@eid,1); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `component_instance_entity` VALUES (@eid,2); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `component_instance_entity` VALUES (@eid,3); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `component_instance_entity` VALUES (@eid,4); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `component_instance_entity` VALUES (@eid,5); SET @eid := @eid +1;

-- main vg storage from only one pv
INSERT INTO `lvm2_vg` VALUES (1,1,'vg1',65610,134190);
INSERT INTO `lvm2_pv` VALUES (1,1,'/dev/sda4');

-- distribution device for Debian 5.0
INSERT INTO `lvm2_lv` VALUES (1,1,'etc_Debian_5.0',52,0,'ext3');
INSERT INTO `lvm2_lv` VALUES (2,1,'root_Debian_5.0',6144,0,'ext3');
-- systemimage device for DebianSystemImage
INSERT INTO `lvm2_lv` VALUES (3,1,'etc_DebianSystemImage',52,0,'ext3');
INSERT INTO `lvm2_lv` VALUES (4,1,'root_DebianSystemImage',6144,0,'ext3');

-- atftp configuration
INSERT INTO `atftpd0` VALUES (1,5,'--daemon --tftpd-timeout 300 --retry-timeout 5 --no-multicast --maxthread 100 --verbose=5', 'FALSE', '/var/log/atftpd.log','/tftp');

-- dhcpd configuration
INSERT INTO `dhcpd3` VALUES (1,4,'hedera-technology.com', '137.194.2.16','node001');
INSERT INTO `dhcpd3_subnet` VALUES (1,1,'10.0.0.0','255.255.255.0');


--
-- data for development tests
-- 

INSERT INTO `user` VALUES 
(2,'thom','pass','Thomas','MANNI','thomas.manni@hederatech.com',CURRENT_DATE(),NULL,''),(3,'xebech','pass','Antoine','CASTAING','antoine.castaing@hederatech.com',CURRENT_DATE(),NULL,''),
(4,'tortue','pass','Sylvain','YVON-PALIOT','sylvain.yvon-paliot@hederatech.com',CURRENT_DATE(),NULL,'');
INSERT INTO `entity` VALUES (@eid); INSERT INTO `user_entity` VALUES (@eid,2); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `user_entity` VALUES (@eid,3); SET @eid := @eid +1;
INSERT INTO `entity` VALUES (@eid); INSERT INTO `user_entity` VALUES (@eid,4); SET @eid := @eid +1;

INSERT INTO `cluster` VALUES (2,'WebBench','Benchmark cluster',0,1,4,500,1,1,5, 'down');
INSERT INTO `entity` VALUES (@eid); INSERT INTO `cluster_entity` VALUES (@eid,2); SET @eid := @eid +1;

INSERT INTO `component_instance` VALUES (6,2,4,NULL);
INSERT INTO `entity` VALUES (@eid); INSERT INTO `component_instance_entity` VALUES (@eid,6); SET @eid := @eid +1;

INSERT INTO `iscsitarget1_target` VALUES (2,3,'iqn.2010-08.com.hedera-technology.nas:srv_WebBench', '/srv', '');

INSERT INTO `openiscsi2` VALUES (1,6,'iqn.2010-08.com.hedera-technology.nas:srv_WebBench', '127.0.0.1', '3260', '/srv', '', 'ext3');

INSERT INTO `lvm2_lv` VALUES (5,1,'srv_WebBench',100,0,'ext3');

SET foreign_key_checks=1;





