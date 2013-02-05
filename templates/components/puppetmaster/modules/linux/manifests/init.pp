class linux ($sourcepath) {
	file { '/etc/hosts':
		path    => '/etc/hosts',
		ensure  => present,
		mode    => 0644,
		source  => "puppet:///kanopyafiles/${sourcepath}/etc/hosts",
	}
	service { 'resolvconf':
		name       => 'resolvconf',
		ensure     => stopped,
		hasstatus  => true,
		hasrestart => true,
		enable     => false,
	}
}  
