use Data::Dumper;
use Test::More 'no_plan';

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({level=>'DEBUG', file=>'STDOUT', layout=>'%F %L %p %m%n'});

my $admtest = "AdminTest";
my $exectest = "ExecTest";

note("Use Tests");
use_ok(Administrator);
use_ok(Executor);
use_ok(Kanopya::Exceptions);

note("Load Administrator tests");
my %args = (login =>'xebech', password => 'pass');

my $addmotherboard_op;

my $adm = Administrator->new( %args);
@args = ();
my $exec = new_ok("Executor", \@args, $exectest);
eval {
	#BEGIN { $ENV{DBIC_TRACE} = 1 }	
	note("Create Motherboard");
	$adm->newOp(type => "AddMotherboard", 
				priority => '100',
				params => { 
							motherboard_mac_address => '11:11:11:11:11:11', 
							kernel_id => 1, 
							motherboard_serial_number => "sn1",
							motherboard_model_id => 1,
							processor_model_id => 1});
	
	note("----------------------------------------------------------------------");
	note("Execute motherboard creation");
	note("----------------------------------------------------------------------");
	$exec->execnround(run => 1);
	
	
	note("Get the Cluster");
	my @entities = $adm->getEntities(type => 'Cluster', hash=> {cluster_name => 'WebBench'});
	my $cluster = $entities[0];
	
	note("Get the Motherboard");
	@entities = $adm->getEntities(type => 'Motherboard', hash=> {motherboard_mac_address => '11:11:11:11:11:11'});
	my $motherboard = $entities[0];
	
	note("Create operation to migrate the motherboard into the cluster");
	$adm->newOp(type		=> "AddMotherboardInCluster",
				priority	=> '100',
				params		=> {cluster_id => $cluster->getAttr(name => "cluster_id"), 
								motherboard_id => $motherboard->getAttr(name => "motherboard_id")});

	note("----------------------------------------------------------------------");
	note("Execute motherboard addition to the cluster");
	note("----------------------------------------------------------------------");
	$exec->execnround(run => 1);
	
	note("Create operation to remove the motherboard from the cluster");
	$adm->newOp(type		=> "RemoveMotherboardFromCluster",
				priority	=> '100',
				params		=> {cluster_id => $cluster->getAttr(name => "cluster_id"), 
								motherboard_id => $motherboard->getAttr(name => "motherboard_id")});
	
	note("----------------------------------------------------------------------");
	note("Execute remove motherboard from cluster");
	note("----------------------------------------------------------------------");
	$exec->execnround(run => 1);
	
	
	note("Remove Motherboard");
	$adm->newOp(type => "RemoveMotherboard", priority => '100', 
					params => { motherboard_id => $motherboard->getAttr(name=>'motherboard_id')});
	
	
	note("----------------------------------------------------------------------");
	note("Execute motherboard deletion");
	note("----------------------------------------------------------------------");
	$exec->execnround(run => 1);

};
if ($@){
	print "Exception catch, its type is : " . ref($@);
	print Dumper $@;
	if ($@->isa('Kanopya::Exception')) 
   	{
		print "Kanopya Exception\n";
   }
}
else {
	eval {
		my $addmotherboard_op = $adm->getNextOp();
	};
	if ($@){
		is ($@->isa('Kanopya::Exception::Internal'), 1, "get Kanopya Exception No more operation in queue!");
		
		my $err = $@;
	}
}


#pass($exectest);
#fail($admtest);

