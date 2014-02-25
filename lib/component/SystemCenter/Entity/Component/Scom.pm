# Scom.pm - SCOM connector
#    Copyright 2011 Hedera Technology SAS
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

# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.
# Created 3 july 2010


=pod
=begin classdoc

Link Kanopya to Microsoft SCOM

=end classdoc
=cut

package Entity::Component::Scom;
use base 'Entity::Component';
use base 'Manager::CollectorManager';

use strict;
use warnings;
use General;
use Kanopya::Exceptions;
use SCOM::Query;
use Entity::CollectorIndicator;
use DateTime::Format::Strptime;
use List::Util 'sum';

use constant ATTR_DEF => {
        scom_ms_name => {
                    pattern        => '.*',
                    is_mandatory   => 0,
                    is_extended    => 0,
                    is_editable    => 1
                 },
                 scom_usessl => {
                   pattern  => '^[01]$',
                   is_mandatory => 0,
                   is_extended => 0,
                   is_editable => 1
                 }
};

sub getAttrDef { return ATTR_DEF; }


sub new {
    my $class = shift;
    my %args  = @_;
    my $self  = $class->SUPER::new( %args );

    my @indicator_sets = (Indicatorset->search(hash =>{indicatorset_name => 'scom'}));
    $self->createCollectorIndicators(
        indicator_sets => \@indicator_sets,
    );

    return $self;
}

# Retriever interface method implementation
# args: nodes => [<node_id>], indicators => [<indicator_id>], time_span => <seconds>
# with:
#     <node_id> : scom MonitoringObjectPath
#     <indicator_id> : ObjectName/CounterName
# return: { <node_id> => { <counter_id> => <mean value for last <time_span> seconds> } }
sub retrieveData {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['nodelist', 'indicators', 'time_span']);

    my $management_server_name = $self->getAttr(name => 'scom_ms_name');
    my $use_ssl                = $self->getAttr(name => 'scom_usessl');
    my %counters;
    while (my($oid,$object) = each (%{$args{indicators}})) {
        # TODO check indic format
        my ($object_name, @counter_name_tab) = split '/', $oid;
        my $counter_name = join('/',@counter_name_tab);
        push @{$counters{$object_name}}, $counter_name;
    }

    my $global_time_laps = 7200;
    my $time_zone = 'UTC';
    my $end_dt   = DateTime->now->set_time_zone($time_zone);
    my $start_dt = DateTime->now->subtract( seconds => $global_time_laps )->set_time_zone($time_zone);

    my $scom = SCOM::Query->new(
        server_name => $management_server_name,
        use_ssl     => $use_ssl,
    );

    my $all_perfs = $scom->getPerformance(
        counters            => \%counters,
        monitoring_object   => $args{nodelist},
        start_time          => _format_dt(dt => $start_dt),
        end_time            => _format_dt(dt => $end_dt),
    );

    my $res = _format_data(
        data        => $all_perfs,
        end_dt      => $end_dt,
        time_span   => $args{time_span},
        time_zone   => $time_zone,
    );

    _consolidateName( data => $res, nodes => $args{nodelist});

    return $res;
}

# 1. Transform node name from SCOM format (COMPUTER.domain) to requested name (case sensitive)
# 2. Add a key for each nodes without data, with empty hash ref as value
#    So all nodes are listed even if no data are retrieved
sub _consolidateName {
    my %args = @_;

    foreach my $node (@{$args{nodes}}) {
        # Retrieve computer name (without domain)
        my $shortname = $node;
        $shortname =~ s/\..*//;
        # Retrieve domain name
        $node =~/[^.]+\.(.*)/;
        my $domain_name = $1;
        # Build SCOM format name (as in response)
        my $name_scom_format = (uc $shortname) . '.' . $domain_name;
        if (not exists $args{data}{$node}) {
            # Replace name from SCOM format to wanted name
            if (exists $args{data}{$name_scom_format}) {
                $args{data}{$node} = $args{data}{$name_scom_format};
                delete $args{data}{$name_scom_format};
            } else {
                # Add a key for node without data
                $args{data}{$node} = {};
            }
        }
    }
}

# Computes mean value for each metric from scom query res
# Mean on last <time_span> seconds, if no value during this laps then take the last value (handle scom db optimization)
# Builds retriever resulting hash
sub _format_data {
    my %args = @_;
    my $data = $args{data};
    my $end_dt = $args{end_dt};
    my $time_span = $args{time_span};
    my $time_zone = $args{time_zone};

    my $date_parser = DateTime::Format::Strptime->new( pattern => '%d/%m/%Y %H:%M:%S' );

    # Compute mean value for each metrics
    my %res;
    while (my ($monit_object_path, $metrics) = each %$data) {
        while (my ($object_name, $counters) = each %$metrics) {
            while (my ($counter_name, $values) = each %$counters) {
                my ($last_time, $last_value);
                my @values;
                while (my ($timestamp, $value) = each %$values) {
                    my $dt = $date_parser->parse_datetime( $timestamp )->set_time_zone( $time_zone );

                    # Change float format "1,0" to "1.0"
                    $value =~ s/,/./g;

                    # Keep values in time span
                    if ($end_dt->epoch - $dt->epoch <= $time_span) {
                        push @values, $value;
                    }

                    # Keep last value
                    if ((not defined $last_time) || ($last_time < $dt)) {($last_time, $last_value) = ($dt, $value)};
                }

                my $consolidate_value;
                if (0 != @values) {
                    # compute mean value
                    $consolidate_value = sum(@values) / @values;
                } else {
                    $consolidate_value = $last_value;
                    # TODO log!
                    #print "Info: take last counter value for $object_name/$counter_name\n";
                }

                $res{$monit_object_path}{"$object_name/$counter_name"} = $consolidate_value;
            }
        }
    }

    return \%res;
}

sub _format_dt {
    my %args = @_;
    my $dt = $args{dt};

    return $dt->dmy('/') . ' ' . $dt->hms(':');
}


=pod
=begin classdoc

Usefull to give information about this component
@return SCOM monitoring

=end classdoc
=cut

sub getCollectorType {
    return 'SCOM monitoring';
}


=pod
=begin classdoc

Override method in order to delete collector indicators properly.

=end classdoc
=cut

sub remove {
    my $self = shift;
    $self->removeCollectorIndicators();
    return $self->SUPER::remove();
}

1;
