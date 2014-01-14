class kanopya::openstack::quantum::server(
  $email              = 'nothing@nothing.com',
  $bridge_flat        = 'br-flat',
  $bridge_vlan        = 'br-vlan',
  $database_name      = 'quantum',
  $database_user      = 'quantum',
  $database_password  = 'quantum',
  $keystone_user      = 'quantum',
  $keystone_password  = 'quantum',
  $rabbit_user        = 'quantum',
  $rabbit_password    = 'quantum',
  $rabbit_virtualhost = '/'
) {
  tag("kanopya::quantum")

  $dbserver = $components[quantum][mysql][mysqld][tag]
  $dbip = $components[quantum][mysql][mysqld][ip]
  $keystone = $components[quantum][keystone][keystone_admin][tag]
  $amqpserver = $components[quantum][amqp][amqp][tag]
  $rabbits = $components[quantum][amqp][nodes]

  if ! defined(Class['kanopya::openstack::repository']) {
    class { 'kanopya::openstack::repository':
      stage => 'system',
    }
  }

  if ! defined(Class['kanopya::openstack::quantum::common']) {
    class { 'kanopya::openstack::quantum::common':
      rabbit_password    => "${rabbit_password}",
      rabbit_hosts       => $rabbits,
      rabbit_user    => "${rabbit_user}",
      rabbit_virtualhost => "${rabbit_virtualhost}"
    }
  }

  class { '::quantum::server':
    auth_password => "${keystone_password}",
    auth_host     => "${keystone}",
    require       => Class['kanopya::openstack::repository']
  }

  if ($components[quantum][master] == 1) {
    @@mysql::db { "${database_name}":
      user     => "${database_user}",
      password => "${database_password}",
      host     => "${ipaddress}",
      tag      => "${dbserver}"
    }

    @@rabbitmq_user { "${rabbit_user}":
      admin    => true,
      password => "${rabbit_password}",
      provider => 'rabbitmqctl',
      tag      => "${amqpserver}"
    }

    @@rabbitmq_user_permissions { "${rabbit_user}@${rabbit_virtualhost}":
      configure_permission => '.*',
      write_permission     => '.*',
      read_permission      => '.*',
      provider             => 'rabbitmqctl',
      tag                  => "${amqpserver}"
    }

    @@keystone_user { "${keystone_user}":
      ensure   => present,
      password => "${keystone_password}",
      email    => "${email}",
      tenant   => "services",
      tag      => "${keystone}"
    }

    @@keystone_user_role { "${keystone_user}@services":
      ensure  => present,
      roles   => 'admin',
      tag     => "${keystone}"
    }

    @@keystone_service { 'quantum':
      ensure      => present,
      type        => "network",
      description => "Quantum Networking Service",
      tag         => "${keystone}"
    }

    $quantum_access_ip = $components[quantum][access][quantum][ip]
    @@keystone_endpoint { "RegionOne/quantum":
      ensure       => present,
      public_url   => "http://${quantum_access_ip}:9696",
      admin_url    => "http://${fqdn}:9696",
      internal_url => "http://${fqdn}:9696",
      tag          => "${keystone}"
    }
  }
  else {
    @@database_user { "${database_user}@${ipaddress}":
      password_hash => mysql_password("${database_password}"),
      tag           => "${dbserver}",
    }

    @@database_grant { "${database_user}@${ipaddress}/${database_name}":
      privileges => ['all'] ,
      tag        => "${dbserver}"
    }
  }

  class { 'quantum::plugins::ovs':
    sql_connection      => "mysql://${database_user}:${database_password}@${dbip}/${database_name}",
    tenant_network_type => 'vlan',
    network_vlan_ranges => 'physnetflat,physnetvlan:1:4094',
    require             => Class['kanopya::openstack::repository']
  }

  class { 'quantum::quota':
    default_quota             => -1,
    quota_network             => -1,
    quota_subnet              => -1,
    quota_port                => -1,
    quota_router              => -1,
    quota_floatingip          => -1,
    quota_security_group      => -1,
    quota_security_group_rule => -1
  }

  if ! has_key($components, "novacompute") {
    quantum_plugin_ovs {
      'SECURITYGROUP/firewall_driver': value => "quantum.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver";
    }
  }

  Class['kanopya::openstack::repository'] -> Class['kanopya::openstack::quantum::server']
}
