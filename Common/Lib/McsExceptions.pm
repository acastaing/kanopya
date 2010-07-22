
#TODO http://www.drdobbs.com/web-development/184416129

package McsExceptions;
use Data::Dumper;

use Exception::Class (
    Mcs::Exception => {
	description => "Mcs General Exception",
	fields => [ 'level', 'request' ],
    },
    Mcs::Exception::DB => {
	isa => 'Mcs::Exception',
	description => 'MicroCluster System Database exception',
    },
    Mcs::Exception::Internal => {
	isa => 'Mcs::Exception',
	description => 'MicroCluster System Internal exception',
    }
    );

$SIG{__DIE__} = \&handle_die;

sub handle_die {
	my $err = shift;
	print "In Handler de die\n";
	print Dumper $err;
}
1;
