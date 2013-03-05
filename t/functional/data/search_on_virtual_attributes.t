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
    file   => 'search_on_virtual_attributes.log',
    layout => '%F %L %p %m%n'
});
my $log = get_logger("");

my $testing = 1;

use BaseDB;
use Entity::Host;
use Entity::Component::Physicalhoster0;

BaseDB->authenticate(login => 'admin', password => 'K4n0pY4');

main();

sub main {
    if ($testing == 1) {
        BaseDB->beginTransaction;
    }

    # Test comparison operators for strings
    my $ip = Entity::Host->find()->admin_ip;
    throws_ok {
        Entity::Host->find(hash => { admin_ip => '0.0.0.0' });
    } 'Kanopya::Exception::Internal::NotFound', 'Search return no hosts for virtual attribute admin_ip = 0.0.0.0';

    lives_ok {
        Entity::Host->find(hash => { admin_ip => $ip });
    } 'Search return one host for virtual attribute admin_ip => ' . $ip;

    throws_ok {
        Entity::Host->find(hash => { admin_ip => { '<>' => $ip } });
    } 'Kanopya::Exception::Internal::NotFound', 'Search return no hosts for virtual attribute admin_ip <> ' . $ip;

    lives_ok {
        Entity::Host->find(hash => { admin_ip => { '<>' => '0.0.0.0' } });
    } 'Search return one host for virtual attribute admin_ip <> 0.0.0.0';

    lives_ok {
        Entity::Host->find(hash => { admin_ip => { '>' => '0.0.0.0' } });
    } 'Search return one host for virtual attribute admin_ip > 0.0.0.0';

    lives_ok {
        Entity::Host->find(hash => { admin_ip => { '>=' => '0.0.0.0' } });
    } 'Search return one host for virtual attribute admin_ip >= 0.0.0.0';

    throws_ok {
        Entity::Host->find(hash => { admin_ip => { '<' => 10 } });
    } 'Kanopya::Exception::Internal::NotFound', 'Search return no hosts for virtual attribute admin_ip < 0.0.0.0';

    throws_ok {
        Entity::Host->find(hash => { admin_ip => { '<=' => 10 } });
    } 'Kanopya::Exception::Internal::NotFound', 'Search return no hosts for virtual attribute admin_ip <= 0.0.0.0';

    lives_ok {
        Entity::Host->find(hash => { admin_ip => { '>=' => $ip } });
    } 'Search return one host for virtual attribute admin_ip >= ' . $ip;

    lives_ok {
        Entity::Host->find(hash => { admin_ip => { '<=' => $ip } });
    } 'Search return one host for virtual attribute admin_ip <= ' . $ip;

    my @splited = split (/\./, $ip);
    my $begin = $splited[0];
    my $end = $splited[3];

    lives_ok {
        Entity::Host->find(hash => { admin_ip => { 'LIKE' => $begin . '%' } });
    } 'Search return one host for virtual attribute admin_ip LIKE ' . $begin . '%';

    throws_ok {
        Entity::Host->find(hash => { admin_ip => { 'LIKE' => '9999999999%' } });
    } 'Kanopya::Exception::Internal::NotFound', 'Search return no hosts for virtual attribute LIKE 9999999999%';

    lives_ok {
        Entity::Host->find(hash => { admin_ip => { 'LIKE' =>  '%' . $end } });
    } 'Search return one host for virtual attribute admin_ip LIKE %' . $end;

    throws_ok {
        Entity::Host->find(hash => { admin_ip => { 'LIKE' => '%9999999999' } });
    } 'Kanopya::Exception::Internal::NotFound', 'Search return no hosts for virtual attribute LIKE %9999999999';

    throws_ok {
        Entity::Host->find(hash => { admin_ip => { 'NOT LIKE' => $begin . '%' } });
    } 'Kanopya::Exception::Internal::NotFound', 'Search return no hosts for virtual attribute NOT LIKE ' . $begin . '%';

    throws_ok {
        Entity::Host->find(hash => { admin_ip => { 'NOT LIKE' => '%' . $end } });
    } 'Kanopya::Exception::Internal::NotFound', 'Search return no hosts for virtual attribute NOT LIKE %' . $end;

    lives_ok {
        Entity::Host->find(hash => { admin_ip => { 'NOT LIKE' =>  '%999999999' } });
    } 'Search return one host for virtual attribute admin_ip NOT LIKE %99999999';

    lives_ok {
        Entity::Host->find(hash => { admin_ip => { 'NOT LIKE' =>  '999999999%' } });
    } 'Search return one host for virtual attribute admin_ip NOT LIKE 99999999%';

    # Test comparison operators for int
    my $component = Entity::Component::Physicalhoster0->find();
    my $priority  = $component->priority;
    my $higherpriority = $priority + 100;
    my $lowerpriority  = $priority - 1;

    throws_ok {
        Entity::Component->find(hash => { priority => $higherpriority });
    } 'Kanopya::Exception::Internal::NotFound', 'Search return no component for virtual attribute priority = ' . $higherpriority;

    lives_ok {
        Entity::Component->find(hash => { priority => $priority });
    } 'Search return one component for virtual attribute priority = ' . $priority;

    lives_ok {
        Entity::Component->find(hash => { priority => { '<>' => $higherpriority } });
    } 'Search return one component for virtual attribute priority = ' . $priority;

    lives_ok {
        Entity::Component->find(hash => { priority => { '<' => $higherpriority } });
    } 'Search return one component for virtual attribute priority < ' . $higherpriority;

    lives_ok {
        Entity::Component->find(hash => { priority => { '<=' => $higherpriority } });
    } 'Search return one component for virtual attribute priority <= ' . $higherpriority;

    throws_ok {
        Entity::Component->find(hash => { priority => { '>' => $higherpriority } });
    } 'Kanopya::Exception::Internal::NotFound', 'Search return no component for virtual attribute priority > ' . $higherpriority;

    throws_ok {
        Entity::Component->find(hash => { priority => { '>=' => $higherpriority } });
    } 'Kanopya::Exception::Internal::NotFound', 'Search return no component for virtual attribute priority >= ' . $higherpriority;

    if ($testing == 1) {
        BaseDB->rollbackTransaction;
    }
}