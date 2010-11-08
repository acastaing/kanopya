package Mcsui::Clusters;
use Data::Dumper;
use base 'CGI::Application';
use Log::Log4perl "get_logger";
use CGI::Application::Plugin::AutoRunmode;
use CGI::Application::Plugin::Redirect;

use lib "/workspace/mcs/Monitor/Lib";

my $log = get_logger("administrator");


sub setup {
	my $self = shift;
	$self->{'admin'} = Administrator->new(login => 'thom', password => 'pass');
}

sub view_clusters : StartRunmode {
    my $self = shift;
    my $output = '';
    my @eclusters = $self->{'admin'}->getEntities(type => 'Cluster', hash => {});
    my $clusters = [];
    my $details = [];
	
    foreach my $n (@eclusters){
    	my $tmp = {};
		$tmp->{ID} = $n->getAttr(name => 'cluster_id');
		$tmp->{NAME} = $n->getAttr(name => 'cluster_name');
		$tmp->{DESC} = $n->getAttr(name => 'cluster_desc');
		$tmp->{PRIORITY} = $n->getAttr(name => 'cluster_priority');
		$tmp->{STATE} = $n->getAttr(name => 'cluster_state');
		$tmp->{ACTIVE} = $n->getAttr('name' => 'active');
		$tmp->{MIN_NODE} = $n->getAttr(name => 'cluster_min_node');
		$tmp->{MAX_NODE} = $n->getAttr(name => 'cluster_max_node');
		if(not defined $n->getAttr(name =>'kernel_id')) {
			$tmp->{KERNEL} = 'default motherboards kernels';
		} else {
			my $ekernel = $self->{'admin'}->getEntity(type =>'Kernel', id => $n->getAttr(name =>'kernel_id'));
			$tmp->{KERNEL} = $ekernel->getAttr(name => 'kernel_version');
		}
		if ($n->getAttr(name => 'systemimage_id')){
			my $esystem = $self->{'admin'}->getEntity(type =>'Systemimage', id => $n->getAttr(name =>'systemimage_id'));
			$tmp->{SYSIMGNAME} =  $esystem->getAttr(name => 'systemimage_name');
		}else{
			$tmp->{SYSIMGNAME} = "";
		}
		$tmp->{PUBLICIPS} = $n->getPublicIps();
				
		if($tmp->{ACTIVE} and $tmp->{STATE} eq 'down') {$tmp->{CANSTART} = 1; }
		elsif($tmp->{ACTIVE} and $tmp->{STATE} eq 'up') {$tmp->{CANSTOP} = 1; }
		push (@$clusters, $tmp);	
    }	
   
    my $tmpl =  $self->load_tmpl('view_clusters.tmpl');
	$tmpl->param('CLUSTERS' => $clusters);
    $tmpl->param('TITLE_PAGE' => "Clusters View");
	$tmpl->param('MENU_CLUSTERSMANAGEMENT' => 1);
		
	$output .= $tmpl->output();       
    return $output;
}

sub view_clusterdetails : Runmode {
	my $self = shift;
	my $errors = shift;
	my $tmpl = $self->load_tmpl('view_clusterdetails.tmpl');
	my $output ='';
	my $query =$self->query();
	$clustId = $query->param('cluster_id');
	 
	my $ecluster = $self->{'admin'}->getEntity(type => 'Cluster', id => $query->param('cluster_id'));
	my $motherboards = $ecluster->getMotherboards(administrator => $self->{'admin'});
	my $components = $ecluster->getComponents(administrator => $self->{'admin'}, category => 'all');
	my $mothboards = [];
	my $comps = []; 
        
	foreach my $c (keys %$components){
		my $tmp = {};
		my $compAtt = $components->{$c}->getComponentAttr();
		$tmp->{NAME} = $compAtt->{component_name};
		$tmp->{VERSION} = $compAtt->{component_version};
		#$log->debug("component name : ".$tmp->{NAME});
		$tmp->{CATEGORY} = $compAtt->{component_category};
		#$log->debug("component category : ".$tmp->{CATEGORY});
		push (@$comps, $tmp);
	}

	# Retrieve from conf graph type we want display
	use XML::Simple;
	my $conf = XMLin("/workspace/mcs/UI/web/clusterdetails.conf");
	my $graph_dir = $conf->{graph_dir} || "/tmp";
	my $graph_dir_alias = $conf->{graph_dir_alias};
	my $graph_monitor_subdir = $conf->{graph_monitor_subdir};
	my $graph_orchestrator_subdir = $conf->{graph_orchestrator_subdir};
	my @node_indic_sets = split ",", $conf->{node_graph}{sets};
	my @cluster_indic_sets = split ",", $conf->{cluster_graph}{sets};
	
	foreach my $m (keys %$motherboards){
		my $tmp ={};
		my $ip = $motherboards->{$m}->getAttr(name=>'motherboard_internal_ip');
		$tmp->{CLUSTER_ID} = $clustId;
		$tmp->{MOTHERBOARD_ID} = $motherboards->{$m}->getAttr(name=>'motherboard_id');
		$tmp->{HOSTNAME} = $motherboards->{$m}->getAttr(name=>'motherboard_hostname');
		$tmp->{SLOTNUMBER} = $motherboards->{$m}->getAttr(name=>'motherboard_powersupply_id');
		$tmp->{INTERNALIP} = $ip;
		my @graphs = ();
		foreach my $indic_set ( @node_indic_sets ) {
			my $graph_name = "graph_" . "$ip" . "_$indic_set";
			push @graphs, { CUSTOM_GRAPH_FILE => "$graph_dir_alias/$graph_monitor_subdir/$graph_name.png",
							HOUR_GRAPH_FILE => "$graph_dir_alias/$graph_monitor_subdir/$graph_name" . "_hour.png",
							DAY_GRAPH_FILE => "$graph_dir_alias/$graph_monitor_subdir/$graph_name" . "_day.png",
							};
		}
		$tmp->{GRAPHS} = \@graphs;
		push (@$mothboards, $tmp);
	}
	

	$cluster_name = $ecluster->getAttr( name => 'cluster_name' );	
	my @monitoring_graphs = ( );
	foreach my $indic_set ( @cluster_indic_sets )  {
		my $graph_name = "graph_" . "$cluster_name" . "_$indic_set";
		if ( -e "$graph_dir/$graph_monitor_subdir/$graph_name" . "_avg" . ".png" ) {
			push( @monitoring_graphs, { GRAPH_INFO =>  $indic_set,
										HIDDEN => ($indic_set eq 'nodecount') ? 0 : 1,
										
										GRAPH_TYPE => [
											{
												CUSTOM_GRAPH_FILE => "$graph_dir_alias/$graph_monitor_subdir/$graph_name" . "_avg" . ".png",
												HOUR_GRAPH_FILE => "$graph_dir_alias/$graph_monitor_subdir/$graph_name" . "_avg" . "_hour.png",
												DAY_GRAPH_FILE => "$graph_dir_alias/$graph_monitor_subdir/$graph_name" . "_avg" . "_day.png",
											},
	#										{
	#											CUSTOM_GRAPH_FILE => "$graph_dir_alias/$graph_monitor_subdir/$graph_name" . "_total" . ".png",
	#											HOUR_GRAPH_FILE => "$graph_dir_alias/$graph_monitor_subdir/$graph_name" . "_total" . "_hour.png",
	#											DAY_GRAPH_FILE => "$graph_dir_alias/$graph_monitor_subdir/$graph_name" . "_total" . "_day.png",
	#										}
										],
										
									} );
		}
	}
	
	$graph_name = "graph_" . "$cluster_name" . "_nodecount";
	$tmpl->param('NODECOUNT_CUSTOM_GRAPH_FILE' => "$graph_dir_alias/$graph_monitor_subdir/$graph_name.png");
	$tmpl->param('NODECOUNT_HOUR_GRAPH_FILE' => "$graph_dir_alias/$graph_monitor_subdir/$graph_name" . "_hour.png");
	$tmpl->param('NODECOUNT_DAY_GRAPH_FILE' => "$graph_dir_alias/$graph_monitor_subdir/$graph_name" . "_day.png");
	
	# Custom graph options
	my $custom_file = "/tmp/gen_graph_custom.conf";
	my @dates;
	if ( -e $custom_file ) {
		open FILE, "<$custom_file";
		my @lines = <FILE>;
		my $line = shift @lines;
		@dates = split ",", $line;
	} else {
		use DateTime;
		my $date = DateTime->now()->ymd;
		@dates = ("$date 00:00", "$date 00:00");
	}
	my ($date, $time) = split " ", $dates[0];
	$tmpl->param('CUSTOM_GRAPH_DATE_START' => $date);
	$tmpl->param('CUSTOM_GRAPH_TIME_START' => $time);
	($date, $time) = split " ", $dates[1];
	$tmpl->param('CUSTOM_GRAPH_DATE_END' => $date);
	$tmpl->param('CUSTOM_GRAPH_TIME_END' => $time);
	
	if (defined $query->param('custom')) {
		$tmpl->param('SHOW_CUSTOM_GRAPH' => 1 );
	}
	
	
	$tmpl->param('CLUSTERID' => $query->param('cluster_id') );
	$tmpl->param('MONITORING_GRAPHS' => \@monitoring_graphs);
	$tmpl->param('ORCHESTRATOR_GRAPH_ADD' => "$graph_dir_alias/$graph_orchestrator_subdir/graph_orchestrator_$cluster_name" . "_add.png");
	$tmpl->param('ORCHESTRATOR_GRAPH_REMOVE' => "$graph_dir_alias/$graph_orchestrator_subdir/graph_orchestrator_$cluster_name" . "_remove.png");

	#$tmpl->param('AUTO_REFRESH' => 10);

	$tmpl->param('TITLE_PAGE' => "Cluster's details");
	$tmpl->param('MENU_CLUSTERSMANAGEMENT' => 1);
	$tmpl->param('COMPONENTS' => $comps);
	$tmpl->param('MOTHERBOARDS' => $mothboards);
	$tmpl->param($errors) if $errors;
	$output .= $tmpl->output();
	return $output;
	}

sub form_addcluster : Runmode {
	my $self = shift;
	my $errors = shift;
	my $tmpl =$self->load_tmpl('form_addcluster.tmpl');
	my $output = '';
	
	my @ekernels = $self->{'admin'}->getEntities(type => 'Kernel', hash => {});
	my @esystemimages = $self->{'admin'}->getEntities(type => 'Systemimage', hash => {});
	my @emotherboards = $self->{'admin'}->getEntities(type => 'Motherboard', hash => {});
	
	my $count = scalar @emotherboards;
	my $c =[];
	for (my $i=1; $i<=$count; $i++) {
		my $tmp->{CM}=$i;
		push(@$c, $tmp);
	}
	my $kmodels = [];
	foreach $k (@ekernels) {
		my $tmp = { ID => $k->getAttr( name => 'kernel_id'),
			NAME => $k->getAttr(name => 'kernel_version')
		};
		push (@$kmodels, $tmp);	
	} 
	my $smodels = [];
	foreach $s (@esystemimages){
		my $tmp = { ID => $s->getAttr (name => 'systemimage_id'),
			NAME => $s->getAttr(name => 'systemimage_name')
		};
		push (@$smodels, $tmp);
	}
	
	$tmpl->param('TITLE_PAGE' => "Adding a Cluster");
	$tmpl->param('MENU_CLUSTERSMANAGEMENT' => 1);
	$tmpl->param('COUNT' => $c);
	$tmpl->param('KERNELS' => $kmodels);
	$tmpl->param('SYSTEMIMAGES' => $smodels);
	$tmpl->param($errors) if $errors;
	$output .= $tmpl->output();
	return $output;
}

sub process_customgraph : Runmode {
	my $self = shift;
	
	 my $query = $self->query();
	 
	 my ($date_start, $time_start, $date_end, $time_end) = ( $query->param('date_start'), $query->param('time_start'),
	 														 $query->param('date_end'), $query->param('time_end') );
	 
	 # we write custom range in a specific file which will be read by Monitor::Retriever at the next graph generation iteration
	 `echo "$date_start $time_start,$date_end $time_end" > /tmp/gen_graph_custom.conf`;
	 
#	 use Monitor::Retriever;
#	 my $monitor = Monitor::Retriever->new();
#	 my %graph_infos = $monitor->graphFromConf();
	
	 $self->redirect('/cgi/mcsui.cgi/clusters/view_clusterdetails?cluster_id='.$query->param('cluster_id') . "&custom" . "#monitoring");
}

sub process_addcluster : Runmode {
        my $self = shift;
        use CGI::Application::Plugin::ValidateRM (qw/check_rm/);
        my ($results, $err_page) = $self->check_rm('form_addcluster', '_addcluster_profile');
        return $err_page if $err_page;

        my $query = $self->query();
        eval {
            my $params = {
				cluster_name => $query->param('name'),
				cluster_desc => $query->param('desc'),
				cluster_min_node => $query->param('min_node'),
				cluster_max_node => $query->param('max_node'),
				cluster_priority => $query->param('priority'),
				systemimage_id => $query->param('systemimage_id')
			};
			if($query->param('kernel_id') ne '0') { $params->{kernel_id} = $query->param('kernel_id'); }
			$self->{'admin'}->newOp(type =>"AddCluster", priority => '100', params => $params);
		};
        if($@) {
                my $error = $@;
                $self->{'admin'}->addMessage(type => 'error', content => $error);
	} else { 
		$self->{'admin'}->addMessage(type => 'newop', content => 'new cluster operation adding to execution queue'); 
	}
    	$self->redirect('/cgi/mcsui.cgi/clusters/view_clusters');
}

sub _addcluster_profile {
        return {
                required => ['name', 'systemimage_id', 'kernel_id', 'min_node', 'max_node'],
                msgs => {
                                any_errors => 'some_errors',
                                prefix => 'err_'
                },
        };
}

sub process_activatecluster : Runmode {
    my $self = shift;
        
    my $query = $self->query();
    eval {
    $self->{'admin'}->newOp(type => "ActivateCluster", priority => '100', params => { 
		cluster_id => $query->param('cluster_id'), 
		});
    };
    if($@) { 
		my $error = $@;
		$self->{'admin'}->addMessage(type => 'error', content => $error); 
	} else { $self->{'admin'}->addMessage(type => 'newop', content => 'activate cluster operation adding to execution queue'); }
    $self->redirect('/cgi/mcsui.cgi/clusters/view_clusters');
}

sub process_deactivatecluster : Runmode {
    my $self = shift;
        
    my $query = $self->query();
    eval {
    $self->{'admin'}->newOp(type => "DeactivateCluster", priority => '100', params => { 
		cluster_id => $query->param('cluster_id'), 
		});
    };
    if($@) { 
		my $error = $@;
		$self->{'admin'}->addMessage(type => 'error', content => $error); 
	} else { $self->{'admin'}->addMessage(type => 'newop', content => 'deactivate cluster operation adding to execution queue'); }
    $self->redirect('/cgi/mcsui.cgi/clusters/view_clusters');
}

sub process_removecluster : Runmode {
    my $self = shift;
    my $query = $self->query();
    eval {
    $self->{'admin'}->newOp(type => "RemoveCluster", priority => '100', params => { 
		cluster_id => $query->param('cluster_id'), 
		});
    };
    if($@) { 
		my $error = $@;
		$self->{'admin'}->addMessage(type => 'error', content => $error); 
	} else { $self->{'admin'}->addMessage(type => 'newop', content => 'remove cluster operation adding to execution queue'); }
    $self->redirect('/cgi/mcsui.cgi/cluster/view_clusters');
}

sub form_setpubliciptocluster : Runmode {
	my $self = shift;
	my $errors = shift;
	my $tmpl =$self->load_tmpl('form_setpubliciptocluster.tmpl');
	my $output = '';
	my $query = $self->query();	
	my $freepublicips = $self->{admin}->getFreePublicIPs();
	
	$tmpl->param('TITLE_PAGE' => "Adding a public ip to a Cluster");
	$tmpl->param('MENU_CLUSTERSMANAGEMENT' => 1);
	$tmpl->param('CLUSTER_ID' => $query->param('cluster_id'));
	$tmpl->param('FREEPUBLICIPS' => $freepublicips);
	
	$output .= $tmpl->output();
	return $output;
}

sub process_setpubliciptocluster : Runmode {
	my $self = shift;
    my $query = $self->query();
    eval {
    	$self->{admin}->setClusterPublicIP(
    		publicip_id => $query->param('publicip_id'),
    		cluster_id => $query->param('cluster_id'),
    	);
    };
    if($@) { 
		my $error = $@;
		$self->{'admin'}->addMessage(type => 'error', content => $error); 
	} else { $self->{'admin'}->addMessage(type => 'success', content => 'new public ip added to cluster.'); }
    $self->redirect('/cgi/mcsui.cgi/clusters');
}

sub process_startcluster : Runmode {
	my $self = shift;
	my $query = $self->query();
    eval {
	    $self->{'admin'}->newOp(type => "StartCluster", priority => '100', 
	    	params => { cluster_id => $query->param('cluster_id') } 
		);
    };
    if($@) { 
		my $error = $@;
		$self->{'admin'}->addMessage(type => 'error', content => $error); 
	} else { $self->{'admin'}->addMessage(type => 'newop', content => 'start cluster operation adding to execution queue'); }
    $self->redirect('/cgi/mcsui.cgi/clusters/view_clusters');
}

sub process_stopcluster : Runmode {
	my $self = shift;
	my $query = $self->query();
    eval {
	    $self->{'admin'}->newOp(type => "StopCluster", priority => '100', 
	    	params => { cluster_id => $query->param('cluster_id') } 
		);
    };
    if($@) { 
		my $error = $@;
		$self->{'admin'}->addMessage(type => 'error', content => $error); 
	} else { $self->{'admin'}->addMessage(type => 'newop', content => 'stop cluster operation adding to execution queue'); }
    $self->redirect('/cgi/mcsui.cgi/clusters/view_clusters');
}

sub process_removenode : Runmode {
	my $self = shift;
	my $query = $self->query();
    eval {
	    $self->{'admin'}->newOp(type => "StopNode", priority => '100', 
	    	params => { cluster_id => $query->param('cluster_id'), motherboard_id => $query->param('motherboard_id') } 
		);
    };
    if($@) { 
		my $error = $@;
		$self->{'admin'}->addMessage(type => 'error', content => $error); 
	} else { $self->{'admin'}->addMessage(type => 'newop', content => 'stop cluster operation adding to execution queue'); }
    $self->redirect('/cgi/mcsui.cgi/clusters/view_clusterdetails?cluster_id='.$query->param('cluster_id'));
}

sub process_addnode : Runmode {
	my $self = shift;
	my $query = $self->query();
	        
    eval {
	    my @free_motherboards = $self->{admin}->getEntities(type => 'Motherboard', hash => { active => 1, motherboard_state => 'down'});
	    if(not scalar @free_motherboards) {
	    	my $errmsg = 'no motherboard is available ; can\'t add a new node to this cluster';
	    	throw Mcs::Exception::Internal(error => $errmsg);
	    }
	    my $motherboard = pop @free_motherboards;
	    $self->{'admin'}->newOp(type => "AddMotherboardInCluster", priority => '100', 
	    	params => { cluster_id => $query->param('cluster_id'), motherboard_id => $motherboard->getAttr(name => 'motherboard_id') } 
		);
    };
    if($@) { 
		my $error = $@;
		$self->{'admin'}->addMessage(type => 'error', content => $error); 
	} else { $self->{'admin'}->addMessage(type => 'newop', content => 'AddMotherboardInCluster operation adding to execution queue'); }
    $self->redirect('/cgi/mcsui.cgi/clusters/view_clusterdetails?cluster_id='.$query->param('cluster_id'));
}

1;
