#!/usr/bin/perl -w

=head1 SCOPE

TODO

=head1 PRE-REQUISITE

TODO

=cut

use Test::More 'no_plan';
use Test::Exception;
use Test::Pod;
use Kanopya::Exceptions;
use ClassType::ComponentType;

use Log::Log4perl qw(:easy get_logger);
Log::Log4perl->easy_init({
    level=>'DEBUG',
    file=>'deploy_on_harddisk.t.log',
    layout=>'%F %L %p %m%n'
});

use Kanopya::Database;
use Entity::ServiceProvider::Cluster;
use Entity::User;
use Entity::Kernel;
use Entity::Processormodel;
use Entity::Hostmodel;
use Entity::Masterimage;
use Entity::Network;
use Entity::Netconf;
use Entity::Poolip;
use Entity::Operation;

use Kanopya::Test::Execution;
use Kanopya::Test::Register;
use Kanopya::Test::Retrieve;
use Kanopya::Test::Create;

main();

sub main {
    Kanopya::Database::authenticate( login =>'admin', password => 'K4n0pY4' );

    diag('Register master image');
    my $masterimage = Kanopya::Test::Register::registerMasterImage();

    my $cluster;
    lives_ok {
        diag('Create and configure cluster');
        $cluster = Kanopya::Test::Create->createCluster(
                       cluster_conf => {
                           masterimage_id => $masterimage->id,
                       },
                       managers => {
                           host_manager => {
                               manager_params => {
                                   deploy_on_disk => 1
                               }
                           }
                       }
                  );
    } 'create and configure cluster';

    diag('Start physical host');
    lives_ok {
        Kanopya::Test::Execution->startCluster(cluster => $cluster);
    } 'cluster started and image deployed on harddisk';
}

1;
