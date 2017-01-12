#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Exception;
use Test::Pod;
use Data::Dumper;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({
    level  => 'DEBUG',
    file   => 'basedb_search.log',
    layout => '%d [ %H - %P ] %p -> %M - %m%n'
});

my $log = get_logger("");

my $testing = 1;

use Kanopya::Database;
use General;
use ClassType;
use Kanopya::Exceptions;
use BaseDB;

use TryCatch;
my $err;

Kanopya::Database::authenticate(login => 'admin', password => 'K4n0pY4');

main();

sub main {
    if ($testing == 1) {
        Kanopya::Database::beginTransaction;
    }

    # Get the JSON of all class types and ne instance of each if exists
    my @classes = ClassType->search();
    for my $class (map { $_->class_type } @classes) {
        try {
            General::requireClass($class);
        }
        catch (Kanopya::Exception::Internal::UnknownClass $err) {
            next;
        }

        lives_ok {
            for my $instance ($class->search()) {
                if (! $instance->isa($class)) {
                    die "Instance <$instance> should isa <$class>";
                }
                my $class_wanted = $instance->class_type->class_type;
                my $class_found  = ref($instance);
                if ($class_wanted ne $class_found) {
                    die "Instance <$instance> should have type <$class_wanted> instead of <$class_found>";
                }
            }
        } 'Search instancies of type ' . $class . ' and check type of each results';
    }

    if ($testing == 1) {
        Kanopya::Database::rollbackTransaction;
    }
}
