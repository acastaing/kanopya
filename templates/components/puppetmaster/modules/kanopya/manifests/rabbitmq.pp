class kanopya::rabbitmq ($disk_nodes, $cookie) {
    $rabbitmq_repo = $operatingsystem ? {
        /(?i)(debian|ubuntu)/ => 'rabbitmq::repo::apt',
        default               => 'rabbitmq::repo::rhel'
    }
    class { "$rabbitmq_repo": }
    class { 'rabbitmq::server':
        wipe_db_on_cookie_change => true,
        config_cluster           => true,
        cluster_disk_nodes       => $disk_nodes,
        erlang_cookie            => $cookie,
        require                  => Class["$rabbitmq_repo"],
        package_name             => $operatingsystem ? {
            /(?i)(centos|redhat|fedora)/ => 'rabbitmq-server.noarch',
            default                      => 'rabbitmq-server'
        }
    }
    Rabbitmq_user <<| tag == "${fqdn}" |>>
    Rabbitmq_user_permissions <<| tag == "${fqdn}" |>>
}

