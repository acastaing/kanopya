#    Copyright © 2011 Hedera Technology SAS
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as
#    published by the Free Software Foundation, either version 3 of the
#    License, or (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
package EEntity::EComponent::EKeepalived1;

use strict;
use Date::Simple (':all');
use Log::Log4perl "get_logger";
use Template;
use String::Random;
use General;

use base "EEntity::EComponent";

my $log = get_logger("executor");
my $errmsg;

# called when a node is added to a cluster
sub addNode {
    my $self = shift;
    my %args = @_;
    
    my $keepalived = $self->_getEntity();
    my $masternodeip = $args{cluster}->getMasterNodeIp();
        
    # recuperer les adresses ips publiques et les ports
    
    if(not defined $masternodeip) {

        # no masternode defined, this host becomes the masternode
        #  so it is the first initialization of keepalived
        
        my $publicips =  $args{cluster}->getPublicIps();
        my $components = $args{cluster}->getComponents(category => 'all');
        
        # retrieved loadbalanced components and there ports
        my $ports = [];
        foreach my $component(values %$components) {
            if($component->getClusterizationType() eq 'loadbalanced') {
                my $netconf = $component->getNetConf();
                foreach my $port (keys %$netconf) {
                    push(@$ports, $port); 
                }
            }
        }
        
        foreach my $vip (@$publicips) {
            foreach my $port (@$ports) {
                
                #$log->debug("adding virtualserver  definition in database");
                my $vsid = $keepalived->addVirtualserver(
                    virtualserver_ip => $vip->{address}.'/'.$vip->{netmask},
                    virtualserver_port => $port,
                    virtualserver_lbkind => 'NAT',
                    virtualserver_lbalgo => 'wlc');
                
                $log->debug("adding realserver definition in database");
                 my $rsid = $keepalived->addRealserver(
                    virtualserver_id => $vsid,
                    realserver_ip => $args{host}->getInternalIP()->{ipv4_internal_address},
                    realserver_port => $port,
                    realserver_checkport => $port,
                    realserver_checktimeout => 15,
                    realserver_weight => 1);
            }    
        }
    
        $log->debug("generate /etc/default/ipvsadm file");
        $self->generateIpvsadm(econtext => $args{econtext}, mount_point => $args{mount_point});
        $log->debug("generate /etc/keepalived/keepalived.conf file");
        $self->generateKeepalived(econtext => $args{econtext}, mount_point => $args{mount_point});
        
        $self->addInitScripts(    etc_mountpoint => $args{mount_point}, 
                                econtext => $args{econtext}, 
                                scriptname => 'ipvsadm', 
                                startvalue => 19, 
                                stopvalue => 21);
        
        $self->addInitScripts(    etc_mountpoint => $args{mount_point}, 
                                econtext => $args{econtext}, 
                                scriptname => 'keepalived', 
                                startvalue => 20, 
                                stopvalue => 20);
                                
        # activating ipv4 forwarding to sysctl
        $log->debug('activating ipv4 forwarding to sysctl.conf');
        my $command = "echo 'net.ipv4.ip_forward=1' >> $args{mount_point}/sysctl.conf";
        $log->debug($command);
        $args{econtext}->execute(command => $command);
    
    } else {
        # a masternode exists so we update his keepalived configuration
        $log->debug("Keepalived update");
        use EFactory;
        my $masternode_econtext = EFactory::newEContext(ip_source => '127.0.0.1', ip_destination => $masternodeip);
        
        # add this host as realserver for each virtualserver of this cluster
        my $virtualservers = $keepalived->getVirtualservers();
        
        foreach my $vs (@$virtualservers) {
            my $rsid = $keepalived->addRealserver(
                virtualserver_id => $vs->{virtualserver_id},
                realserver_ip => $args{host}->getInternalIP()->{ipv4_internal_address},
                realserver_port => $vs->{virtualserver_port},
                realserver_checkport => $vs->{virtualserver_port},
                realserver_checktimeout => 15,
                realserver_weight => 2);
        }
        
        $log->debug('Generation of network_routes script');
        $self->addnetwork_routes(mount_point => $args{mount_point},
                                econtext => $args{econtext},
                                loadbalancer_internal_ip => $masternodeip);
        
        $log->debug('init script generation for network_routes script');
        $self->addInitScripts(    etc_mountpoint => $args{mount_point}, 
                                econtext => $args{econtext}, 
                                scriptname => 'network_routes', 
                                startvalue => 17, 
                                stopvalue => 20);
        
#        $self->generateKeepalived(mount_point => '/etc', econtext => $masternode_econtext);
#        $self->reload(econtext => $masternode_econtext);
        
    }
}

# called when a node is removed from a cluster 
sub stopNode {
    my $self = shift;
    my %args = @_;
    
    my $keepalived = $self->_getEntity();
    my $masternodeip = $args{cluster}->getMasterNodeIp();
    if($masternodeip eq $args{host}->getInternalIP()->{ipv4_internal_address}) {
        # this host is the masternode so we remove virtualserver definitions
        $log->debug('No master node ip retreived, we are stopping the master node');
        my $virtualservers = $keepalived->getVirtualservers();
        foreach my $vs (@$virtualservers) {
            $keepalived->removeVirtualserver(virtualserver_id => $vs->{virtualserver_id});
        }
        
    } else {
        use EFactory;
        my $masternode_econtext = EFactory::newEContext(ip_source => '127.0.0.1', ip_destination => $masternodeip);
        
        # remove this host as realserver for each virtualserver of this cluster
        my $virtualservers = $keepalived->getVirtualservers();
        
        foreach my $vs (@$virtualservers) {
            my $realserver_id = $keepalived->getRealserverId(virtualserver_id => $vs->{virtualserver_id}, realserver_ip => $args{host}->getInternalIP()->{ipv4_internal_address});
            
            $keepalived->removeRealserver(
                virtualserver_id => $vs->{virtualserver_id},
                realserver_id => $realserver_id);
        }
        
        $self->generateKeepalived(mount_point => '/etc', econtext => $masternode_econtext);
        $self->reload(econtext => $masternode_econtext);    
    }
    
}

sub cleanNode {
    my $self = shift;
    my %args = @_;
    
    General::checkParams(args => \%args, required => ['econtext', 'host', 'cluster', 'mount_point']);
    
    my $keepalived = $self->_getEntity();
    
    # remove this host as realserver for each virtualserver of this cluster
    my $virtualservers = $keepalived->getVirtualservers();

    foreach my $vs (@$virtualservers) {
       my $realserver_id = $keepalived->getRealserverId(virtualserver_id => $vs->{virtualserver_id},
                                                        realserver_ip => $args{host}->getInternalIP()->{ipv4_internal_address});


       $keepalived->removeRealserver(
                virtualserver_id => $vs->{virtualserver_id},
                realserver_id => $realserver_id);
    }

    # If masternode then delete virtual server entry in db
    my $masternodeip = $args{cluster}->getMasterNodeIp();
    if($masternodeip eq $args{host}->getInternalIP()->{ipv4_internal_address}) {
        foreach my $vs (@$virtualservers) {
           $keepalived->removeVirtualserver(virtualserver_id => $vs->{virtualserver_id});
        }
    }
}

# Reload configuration of keepalived process
sub reload {
    my $self = shift;
    my %args = @_;
    
    General::checkParams(args => \%args, required => ['econtext']);

    my $command = "invoke-rc.d keepalived reload";
    my $result = $args{econtext}->execute(command => $command);
    return undef;
}

# generate /etc/keepalived/keepalived.conf configuration file
sub generateKeepalived {
    my $self = shift;
    my %args = @_;
    
    General::checkParams(args => \%args, required => ['econtext', 'mount_point']);
    
    my $data = $self->_getEntity()->getTemplateDataKeepalived();
    $self->generateFile( econtext => $args{econtext}, mount_point => $args{mount_point},
                         template_dir => "/templates/components/keepalived",
                         input_file => "keepalived.conf.tt", output => "/keepalived/keepalived.conf", data => $data);         
}

# generate /etc/default/ipvsadm configuration file for the master node
sub generateIpvsadm {
    my $self = shift;
    my %args = @_;
    
    General::checkParams(args => \%args, required => ['econtext', 'mount_point']);
    
    my $data = $self->_getEntity()->getTemplateDataIpvsadm();
    $self->generateFile( econtext => $args{econtext}, mount_point => $args{mount_point},
                         template_dir => "/templates/components/keepalived",
                         input_file => "default_ipvsadm.tt", output => "/default/ipvsadm", data => $data);
}

# add network_routes script to the node 
sub addnetwork_routes {
    my $self = shift;
    my %args = @_;
    
    General::checkParams(args => \%args, required => ['econtext', 'mount_point', 'loadbalancer_internal_ip']);
    
    

    my $config = {
        INCLUDE_PATH => '/templates/components/keepalived',
        INTERPOLATE  => 1,               # expand "$var" in plain text
        POST_CHOMP   => 0,               # cleanup whitespace 
        EVAL_PERL    => 1,               # evaluate Perl code blocks
        RELATIVE => 1,                   # desactive par defaut
    };
    
    my $rand = new String::Random;
    my $tmpfile = $rand->randpattern("cccccccc");
    # create Template object
    my $template = Template->new($config);
    my $input = "network_routes.tt";
    my $data = {};
    $data->{gateway} = $args{loadbalancer_internal_ip};
    
    $template->process($input, $data, "/tmp/".$tmpfile) || do {
        $errmsg = "EComponent::EKeepalived1->addnetwork_routes : error during template generation : $template->error;";
        $log->error($errmsg);
        throw Kanopya::Exception::Internal(error => $errmsg);    
    };
    $args{econtext}->send(src => "/tmp/$tmpfile", dest => $args{mount_point}."/init.d/network_routes");    
    my $command = '/bin/chmod +x '.$args{mount_point}.'/init.d/network_routes';
    $log->debug($command);
    my $result = $args{econtext}->execute(command => $command);
    unlink "/tmp/$tmpfile";        
}

sub postStartNode{
    my $self = shift;
    my %args = @_;
    
    my $keepalived = $self->_getEntity();
    my $masternodeip = $args{cluster}->getMasterNodeIp();
    if($masternodeip eq $args{host}->getInternalIP()->{ipv4_internal_address}) {
        # this host is the masternode so we remove virtualserver definitions
        $log->debug('First Node is started, nothing to do');
        return;        
    } else {
        use EFactory;
        my $masternode_econtext = EFactory::newEContext(ip_source => '127.0.0.1', ip_destination => $masternodeip);
        
        $self->generateKeepalived(mount_point => '/etc', econtext => $masternode_econtext);
        $self->reload(econtext => $masternode_econtext);    
    }
}
1;
