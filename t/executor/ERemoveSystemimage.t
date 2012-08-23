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
		
	BEGIN { $ENV{DBIC_TRACE} = 1 }
	
	note("Operation Addition test");
	$adm->newOp(type => "RemoveSystemimage", priority => '100', params => { systemimage_id => 1 });
	@args = ();
	note ("Execution begin");
	my $exec = new_ok("Executor", \@args, $exectest);
	$exec->execnround(run => 1);
	note("Operation Execution is finish");
	

};
if ($@){
	print "Exception catch, its type is : " . ref($@);
	print Dumper $@;
	if ($@->isa('Kanopya::Exception')) 
   	{
		print "Kanopya Exception\n";
   }
	
}


#pass($exectest);
#fail($admtest);

