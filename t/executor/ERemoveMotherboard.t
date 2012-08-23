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

my $removemotherboard_op;

my $adm = Administrator->new( %args);
eval {
	$adm->{db}->txn_begin;
	
	note("Operation Addition test");
	$adm->newOp(type => "RemoveMotherboard", priority => '100', params => { node_id => 5 });
	$adm->newOp(type => "RemoveMotherboard", priority => '200', params => { node_id => 6 });
	@args = ();
	note ("Execution begin");
	my $exec = new_ok("Executor", \@args, $exectest);
	$exec->execnround(run => 2);
	note("Operation Execution is finish");
	eval {
		my $addmotherboard_op = $adm->getNextOp();
	};
	if ($@){
		is ($@->isa('Kanopya::Exception::Internal'), 1, "get Kanopya Exception No more operation in queue!");
		
		my $err = $@;
		
	}

	$adm->{db}->txn_rollback;
};
if ($@){
	print "Exception catch, its type is : " . ref($@);
	print Dumper $@;
	if ($@->isa('Kanopya::Exception')) 
   	{
		print "Kanopya Exception\n";
   }
	$adm->{db}->txn_rollback;
}


#pass($exectest);
#fail($admtest);

