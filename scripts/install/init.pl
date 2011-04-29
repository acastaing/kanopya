#!/usr/bin/perl -W
# init.pl -  

# Copyright (C) 2009, 2010, 2011, 2012, 2013
#   Free Software Foundation, Inc.

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.

# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; see the file COPYING.  If not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301 USA.

# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.
# Created 14 july 2010
#This scripts has to be executed as root or with sudo, after Kanopya's installation through a package manager.
#it's goal is to generate configuration files, to create kanopya system user and then to populate the database.
#@Date: 23/02/2011

use strict;
use Term::ReadKey;
use Template;
use NetAddr::IP;
use XML::Simple;
use Data::Dumper;

#Scripts variables, used to set stuff like path, users, etc
my $install_conf = XMLin("init_struct.xml");
my $questions = $install_conf->{questions};
my $conf_vars = $install_conf->{general_conf};
my $conf_files = $install_conf->{genfiles};
my $answers ={};

my %param_test = (dbuser        => \&matchRegexp,
                  dbpassword1   => sub {},
                  dbpassword2   => \&comparePassword,
                  dbip          => \&checkIpOrHostname,
                  dbport        => \&checkPort,
                  kanopya_server_domain_name=> \&matchRegexp,
                  internal_net_interface => \&matchRegexp,
                  internal_net_add => \&checkIp,
                  internal_net_mask => \&checkIp,
                  log_directory => \&matchRegexp,
                  vg    => \&matchRegexp);

printInitStruct();
#Welcome message - accepting Licence is mandatory
welcome();
#Ask questions to users 
getConf();
#Print user's answers, can be usefull for recap, etc
#printAnswers();
#Function used to generate conf files 
genConf();


###############
#Network setup#
###############
print "calculating the first host address available for this network...";
my $internal_ip_add = NetAddr::IP->new($answers->{internal_net_add}, $answers->{internal_net_mask});
my @c = split("/",$internal_ip_add->first);
$internal_ip_add = $c[0];
print "done (first host address is $internal_ip_add)\n";
print "setting up $answers->{internal_net_interface} ...";
system ("ifconfig $answers->{internal_net_interface} $internal_ip_add") == 0 or die "an error occured while trying to set up nic ($answers->{internal_net_interface}) address: $!";
print "done\n";
#We gather the NIC's MAC address
my $internal_net_interface_mac_add = `ip link list dev $answers->{internal_net_interface} | egrep "ether [0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}" | cut -d' ' -f6`;
chomp($internal_net_interface_mac_add);


#######################
# VG Analysis
#We gather the vg's size and free space:
my $kanopya_vg_sizes= `vgs --noheadings $answers->{vg} --units m -o vg_size,vg_free --nosuffix --separator '|'`;
chomp($kanopya_vg_sizes);
$kanopya_vg_sizes=~ s/^\s+//;
(my $kanopya_vg_size, my $kanopya_vg_free_space)=split(/\|/,$kanopya_vg_sizes);
#We gather pv's present in the vg
my @kanopya_pvs= `pvs --noheadings --separator '|' -o pv_name,vg_name  | grep $answers->{vg} | cut -d'|' -f1`;
chomp(@kanopya_pvs);


#########################
#Directory manipulations#
#########################
#We create the logging directory and give rights to apache user on it
print "creating the logging directory...";
if ($answers->{log_directory} !~ /\/$/){
	$answers->{log_directory} = $answers->{log_directory}.'/';
}
system ("mkdir -p $answers->{log_directory}") == 0 or die "error while creating the logging directory: $!";
system ("chown -R $conf_vars->{apache_user}.$conf_vars->{apache_user} $answers->{log_directory}") == 0 or die "error while granting rights on $answers->{log_directory} to $conf_vars->{apache_user}: $!";
print "done\n";

########################
#Services configuration#
########################
#We configure dhcp server with the gathered informations
#As conf file changes from lenny to squeeze, we need to handle both cases
open (my $FILE, "<","/etc/debian_version") or die "error while opening /etc/debian_version: $!";
my $line;
my $debian_version;
while ($line = <$FILE>){
        if ($line =~ m/^6\./ || $line =~ m/^squeeze/){
                print 'version stable: '.$line."\n";
                $debian_version = 'squeeze';
        }elsif ($line =~ m/^5\./ || $line =~ m/^lenny/){
                print 'ancienne stable: '.$line."\n";
                $debian_version = 'lenny';
        }
}
close ($FILE);
if ($debian_version eq 'squeeze'){
        open (my $FILE, ">","/etc/dhcp/dhcpd.conf") or die "an error occured while opening /etc/dhcp/dhcpd.conf: $!";
        print $FILE 'ddns-update-style none;'."\n".'default-lease-time 600;'."\n".'max-lease-time 7200;'."\n".'log-facility local7;'."\n".'subnet '.$answers->{internal_net_add}.' netmask '.$answers->{internal_net_mask}.'{}'."\n";
        system('invoke-rc.d isc-dhcp-server restart');
        close ($FILE);
}elsif ($debian_version eq 'lenny'){
        open (my $FILE, ">","/etc/dhcp3/dhcpd.conf") or die "an error occured while opening /etc/dhcp/dhcpd.conf: $!";
        print $FILE 'ddns-update-style none;'."\n".'default-lease-time 600;'."\n".'max-lease-time 7200;'."\n".'log-facility local7;'."\n".'subnet '.$answers->{internal_net_add}.' netmask '.$answers->{internal_net_mask}.'{}'."\n";
        system('invoke-rc.d dhcpd restart');
        close ($FILE);
}else{
        print 'we can\'t determine the Debian version you are running, please check /etc/debian_version';
}

#Atftpd configuration
open ($FILE, ">","/etc/default/atftpd") or die "an error occured while opening /etc/default/atftpd: $!";
print $FILE "USE_INETD=false\nOPTIONS=\"--daemon --tftpd-timeout 300 --retry-timeout 5 --no-multicast --bind-address $internal_ip_add --maxthread 100 --verbose=5 --logfile=/var/log/tftp.log /tftp\"";
close ($FILE);

########################
#Database configuration#
########################
#We generate the Data.sql file and setup database
my %datas = (kanopya_vg_name => $answers->{vg}, kanopya_vg_size => $kanopya_vg_size, kanopya_vg_free_space => $kanopya_vg_free_space, kanopya_pvs => \@kanopya_pvs, ipv4_internal_ip => $internal_ip_add, ipv4_internal_netmask => $answers->{internal_net_mask}, ipv4_internal_network_ip => $answers->{internal_net_add}, admin_domainname => $answers->{kanopya_server_domain_name}, mb_hw_address => $internal_net_interface_mac_add);
useTemplate(template => 'Data.sql.tt', datas => \%datas, conf => $conf_vars->{data_sql}, include => $conf_vars->{data_dir});
#Creation of database user
print "creating mysql user, please insert root password...\n";
system ("mysql -h $answers->{dbip}  -P $answers->{dbport} -u root -p -e \"CREATE USER '$answers->{dbuser}' IDENTIFIED BY '$answers->{dbpassword1}'\"") == 0 or die "error while creating mysql user: $!";
print "done\n";
#We grant all privileges to administrator database for $db_user
print "granting all privileges on administrator database to $answers->{dbuser}, please insert root password...\n";
system ("mysql -h $answers->{dbip} -P $answers->{dbport} -u root -p -e \"GRANT ALL PRIVILEGES ON administrator.* TO '$answers->{dbuser}' WITH GRANT OPTION\"") == 0 or die "error while granting privileges to $answers->{dbuser}: $!";
print "done\n";
#We now generate the database schemas
print "generating database schemas...";
system ("mysql -u $answers->{dbuser} -p$answers->{dbpassword1} < $conf_vars->{schema_sql}") == 0 or die "error while generating database schema: $!";
print "done\n";
#We now generate the components schemas 
print "loading component DB schemas...";
open ($FILE, "<","$conf_vars->{comp_conf}") or die "error while opening components.conf: $!";

while( defined( $line = <$FILE> ) )
{
        chomp ($line);
        print "installing $line component in database from $conf_vars->{comp_schemas_dir}$line.sql...\n ";
        system("mysql -u $answers->{dbuser} -p$answers->{dbpassword1} < $conf_vars->{comp_schemas_dir}$line.sql");
        print "done\n";
}
close($FILE);
print "components DB schemas loaded\n";
#And to conclude, we insert initial datas in the DB
print "inserting initial datas...";
system ("mysql -u $answers->{dbuser} -p$answers->{dbpassword1} < $conf_vars->{data_sql}") == 0 or die "error while inserting initial datas: $!";
print "done\n";
#######################
#Services manipulation#
#######################
# We remove the initial tftp line from inetd conf file and restart the service
system('sed -i s/^tftp.*// /etc/inetd.conf');
system('invoke-rc.d inetutils-inetd restart');
# We restart atftpd with the new configuration
system('invoke-rc.d atftpd restart');
# Launching Kanopya's init scripts
system('invoke-rc.d kanopya-executor start');
system('invoke-rc.d kanopya-collector start');
system('invoke-rc.d kanopya-grapher start');
system('invoke-rc.d kanopya-orchestrator start');
print "\ninitial configuration: done.\n";
print "You can now visit http://localhost/cgi/kanopya.cgi and start using Kanopya!\n";


##########################################################################################
##############################FUNCTIONS DECLARATION#######################################
##########################################################################################
sub welcome {
    my $validate_licence;

    print "Welcome on Kanopya\n";
    print "This script will configure your Kanopya instance\n";
    print "We advise to install Kanopya instance on a dedicated server\n";
    print "First please validate the user licence";
    `cat Licence`;
    print "Do you accept the licence ? (y/n)\n";
    chomp($validate_licence= <STDIN>);
    if ($validate_licence ne 'y'){
        exit;
    }
    print "Please answer to the following questions\n";
}
######################################### Methods to prompt user for informations
sub getConf{
    my $i = 0;
    foreach my $question (sort keys %$questions){
        print "question $i : ". $questions->{$question}->{question} . " (". $questions->{$question}->{default} .")\n";
        
        # Secret activation
        if(defined $questions->{$question}->{'is_secret'}){
            ReadMode('noecho');
        }
        my @searchable_answer;
        # if answer is searchable and has an answer detection, allow user to choose good answer
        if ($questions->{$question}->{is_searchable} eq "n"){
            my $tmp = `$questions->{$question}->{search_command}`;
            chomp($tmp);
            @searchable_answer = split(/ /, $tmp);
            my $cpt = 0;
            print "Choose a value between the following :\n";
            for my $possible_answer (@searchable_answer) {
                print "\n[$cpt] $possible_answer\n";
                $cpt++;
            }
        }
        chomp($answers->{$question} = <STDIN>);

        if ($answers->{$question} eq ''){
            if ($questions->{$question}->{is_searchable} eq "1"){
                print "Script will discover your configuration\n";
                $answers->{$question} = `$questions->{$question}->{search_command}`;
            } else {
                if ($questions->{$question}->{is_searchable} eq "n"){
                    $answers->{$question} = 0;
                }
                else {
                #print "Use default value\n";
                $answers->{$question} = $questions->{$question}->{default};}
            }
            chomp($answers->{$question});
        }
        else {
            my $method = $param_test{$question} || \&noMethodToTest;
            while ($method->(question => $question)){
                print "Wrong value, try again\n";
                chomp($answers->{$question} = <STDIN>);
            }
        }
        if ($questions->{$question}->{is_searchable} eq "n"){
            if ($answers->{$question} >= scalar @searchable_answer){
                print "Error you entered a value out of the answer scope.";
                default_error();}
            else {
                # On transforme la valeur de l'utilisateur par celle de la selection proposee
                $answers->{$question} = $searchable_answer[$answers->{$question}];
            }
        }
        # Secret deactivation
        if(defined $questions->{$question}->{'is_secret'}){
            ReadMode('original');
        }
        $i++;
        print "\n";
    }
}


sub matchRegexp{
    my %args = @_;
    if ((!defined $args{question} or !exists $args{question})){
        print "Error, did you modify init script ?\n";
        exit;
    }
    if (!defined $questions->{$args{question}}->{pattern}){
        default_error();
    }
    if($answers->{$args{question}} !~ m/($questions->{$args{question}}->{pattern})/){
        print "answer <".$answers->{$args{question}}."> does not fit regexp <". $questions->{$args{question}}->{pattern}.">\n";
        return 1;
	}
	return 0;
}

######################################### Methods to check user's parameter

sub checkPort{
    my %args = @_;
    if ((!defined $args{question} or !exists $args{question})){
        print "Error, Do you modify init script ?\n";
        exit;
    }
    if ($answers->{$args{question}} !~ m/\d+/) {
        print "port has to be a numerical value\n";
        return 1;
    }
    if (!($answers->{$args{question}} >0 and $answers->{$args{question}} < 65535)) {
        print "port has to have value between 0 and 65535\n";
        return 1;
    }
    return 0;
}

# Check ip or hostname
# Hostname could only be localhost for the moment
sub checkIpOrHostname{
    my %args = @_;
    if ((!defined $args{question} or !exists $args{question})){
        default_error();
    }
    if ($answers->{$args{question}} =~ m/localhost/) {
        $answers->{$args{question}} = "127.0.0.1";
    }
    else{
        return checkIp(%args);
    }
    return 0;
}

sub checkIp{
    my %args = @_;
    if ((!defined $args{question} or !exists $args{question})){
        default_error();
    }
	my $ip = new NetAddr::IP($answers->{$args{question}});
	if(not defined $ip) {
	    print "IP <".$answers->{$args{question}}."> seems to be not good";
	    return 1;
	}
	return 0;
}

# Check that password is confirmed
sub comparePassword{
    my %args = @_;
    if ((!defined $args{question} or !exists $args{question})){
        default_error();
    }
    if ($answers->{$args{question}} ne $answers->{'dbpassword1'}){
        print "Passwords are differents\n";
        return 1;
    }
    exit 0;
}

# When no check method are defined in param_test structure.
sub noMethodToTest {
    print "Error, param get not found in test table.\n";
    print "If you modified your init script or its xml, you may have broken your install";
    exit;
}

# Print xml struct
sub printInitStruct{
    my $i = 0;
    foreach my $question (keys %$questions){
        print "question $i : ". $questions->{$question}->{question} ."\n";
        print "default value : ". $questions->{$question}->{default} ."\n";
        print "question is_searchable : ". $questions->{$question}->{is_searchable} ."\n";
        print "command to search default : ". $questions->{$question}->{search_command} ."\n";
        $i++;
    }
}
sub printAnswers {
    my $i = 0;
    foreach my $answer (keys %$answers){
        print "answer $i : ". $answers->{$answer} ."\n";
        $i++;
    }
}
# Default error message and exit
sub default_error{
        print "Error, did you modify init script ?\n";
        exit;
}


###################################################### Following functions generates conf files for Kanopya

sub genConf {
	unless ( -d $conf_vars->{conf_dir} ){mkdir $conf_vars->{conf_dir};
	my %datas;
	print $conf_vars->{apache_user}."\n";
	foreach my $files (keys %$conf_files){
		foreach my $d (keys %{$conf_files->{$files}->{datas}}){
			%datas->{$d} = $answers->{$conf_files->{$files}->{datas}->{$d}};
		}
		useTemplate(template => $conf_files->{$files}->{template}, datas => \%datas, conf => $conf_vars->{conf_dir}.$files, include => $conf_vars->{install_template_dir});
	}
}
sub useTemplate{
        my %args=@_;
        my $input=$args{template};
	my $include=$args{include};
        my $dat=$args{datas};
        my $output=$args{conf};
        my $config = {
                INCLUDE_PATH => $include,
                INTERPOLATE  => 1,
                POST_CHOMP   => 1,
                EVAL_PERL    => 1,
        };
        my $template = Template->new($config);
        $template->process($input, $dat, $output) || do {
                print "error while generating $output: $!";
        };
}
