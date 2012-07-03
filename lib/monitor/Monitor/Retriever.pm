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
package Monitor::Retriever;

use strict;
use warnings;
use List::Util qw(sum);
use XML::Simple;
#use General;

use Data::Dumper;

use base "Monitor";

# logger
use Log::Log4perl "get_logger";
my $log = get_logger("monitor");


# Constructor

sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new( %args );

    return $self;
}


=head2 getData

    Class : Public

    Desc :     Retrieve from storage (rrd) values for required var (ds).
            For each ds can compute mean value on a time laps or percent value, using all values for the ds collected during the time laps.

    Args :
        rrd_name: string: the name of the rrd where data are stored.
        time_laps: int: time laps to consider.
        (optionnal) required_ds: array ref: list of ds name to retrieve. If not defined, get all ds. WARNING: don't use it if 'percent'.
        (optionnal) percent: if defined compute percent else compute mean for each ds. See 'max_def'.
        (optionnal) max_def: array: list of ds name to add to obtain max value (used to compute percent). If not defined, use all ds.

    Return : A hash ( ds_name => computed_value )

=cut

#TODO gérer le cas où les ds dans max_def ne sont pas toutes dans les required_ds
sub getData {
    my $self = shift;
    my %args = @_;

    my $rrd_name = $args{rrd_name};

    $log->info('REQUESTED RRD: '.Dumper $rrd_name);
    # rrd constructor
    my $rrd = $self->getRRD(file => "$rrd_name.rrd" );

    # Start fetching values
    my $start = defined $args{start} ? $args{start} : time() - $args{time_laps};
    my $end;

    if ((not defined $args{end}) && $args{time_laps}) {
        $end = $start + $args{time_laps};
    }

    $rrd->fetch_start(start => $start,
                      end   => $end || $args{end});
    $rrd->fetch_skip_undef();

    # retrieve array of ds name ordered like in rrd (db column)
    # WARN we directly access class hash, breaking encapsulation
    my $ds_names = $rrd->{fetch_ds_names};

    $log->info('DS NAMES FOR REQUESTED RRD : '.Dumper $ds_names);
    my @max_def = $args{max_def} ? @{ $args{max_def} } : @$ds_names;
    my %res_data = ( "_MAX_" => [] );

    #############################################
    # Build ds index map : (ds_name => rrd_idx) #
    #############################################

    my $required_ds = $args{required_ds} || $ds_names;
    my %required_ds_idx = ();
    my @max_idx = ();
    foreach my $ds_name (@$required_ds) {
        # find the index of required ds
        my $ds_idx = 0;
        ++$ds_idx until ( ($ds_idx == scalar @$ds_names) or ($ds_names->[$ds_idx] eq $ds_name) );
        if ($ds_idx == scalar @$ds_names) {
            die "Invalid ds_name for this RRD : '$args{ds_name}'";
        }
        $required_ds_idx{ $ds_name } = $ds_idx;
        $res_data{ $ds_name } = [];

        if ( 0 < grep { $_ eq $ds_name } @max_def ) {
            push @max_idx, $ds_idx;
        }
    }

    # Check error in max definition
    if ( scalar @max_idx != scalar @max_def) {
        $log->warn("bad ds name in max definition: [ ", join(", ", @max_def), " ]");
    }

    ################################################
    # Build res data : ( ds_name => [v1, v2, ..] ) #
    ################################################
    while(my($time, @values) = $rrd->fetch_next()) {
        # compute max value for this row
        if (defined $values[0]) {
            my $max = 0;
            foreach my $idx (@max_idx) { $max += $values[$idx] };
            push @{ $res_data{ "_MAX_"} }, $max;
        }
        # add values in res_data
        while ( my ($ds_name, $ds_idx) = each %required_ds_idx ) {
            if (defined $values[$ds_idx]) {
                push @{ $res_data{ $ds_name } }, $values[$ds_idx];
            }
        }
    }

    ######################################################
    # Build resulting hash : ( ds_name => f(v1,v2,...) ) #
    ######################################################

    my %res = ();
    my $max = sum @{ $res_data{"_MAX_"} };
    delete $res_data{"_MAX_"};
    while ( my ($ds_name, $values) = each %res_data ) {
        my $sum = sum( @$values ) || 0;
        eval {
            if (defined $args{percent}) {
                $res{ $ds_name } = defined $max ? $sum * 100 / $max : undef;
            }
            elsif (defined $args{raw}) {
                $res{ $ds_name } = $values;
            }
            else { # mean
                $res{ $ds_name } = $sum / scalar @$values;
            }
        };
        if ($@) {
            $res{ $ds_name } = undef;
        }
    }

    return %res;
}


sub getHostData {
    my $self = shift;
    my %args = @_;

    my $rrd_name = $self->rrdName( set_name => $args{set}, host_name => $args{host} );

    my $set_def = $self->getSetDesc(set_label => $args{set});
    my @max_def;
    if ( $set_def->{max} ) { @max_def = split( /\+/, $set_def->{max} ) };
    if (defined $args{percent} && 0 == scalar @max_def ) {
        $log->warn("No max definition to compute percent for '$args{set}'");
    }

    my %host_data = $self->getData(rrd_name => $rrd_name,
                                   time_laps => $args{time_laps},
                                   max_def => (scalar @max_def) ? \@max_def : undef,
                                   percent => $args{percent} );

    return \%host_data;
}

sub getClusterData {
    my $self = shift;
    my %args = @_;

    my $rrd_name = $self->rrdName( set_name => $args{set}, host_name => $args{cluster} );

    # Unable the monitoring of _total based and stay compatible with existant code
    if(exists $args{aggregation} and defined $args{aggregation}){
        if($args{aggregation} eq 'total'){
            $rrd_name .= "_total";
        }
        elsif($args{aggregation} eq 'average'){
            $rrd_name .= "_avg";
        }
        else{
            $rrd_name .= "_" . $args{aggregation};
        }
    }
    else{
        $rrd_name .= "_raw";
    }

    my $set_def = $self->getSetDesc(set_label => $args{set});
    my @max_def;
    if ( $set_def->{max} ) { @max_def = split( /\+/, $set_def->{max} ) };
    if (defined $args{percent} && 0 == scalar @max_def ) {
        $log->warn("No max definition to compute percent for '$args{set}'");
    }

    my %cluster_data = $self->getData(rrd_name  => $rrd_name,
                                      start     => $args{start},
                                      end       => $args{end},
                                      time_laps => $args{time_laps},
                                      raw       => $args{raw},
                                      max_def   => (scalar @max_def) ? \@max_def : undef,
                                      percent   => $args{percent} );

    return \%cluster_data;
}

sub getClustersData {
    my $self = shift;
    my %args = @_;

    my %clusters_data = ();
    my @clusters = $self->getClustersName();

    for my $cluster (@clusters) {
        $clusters_data{ $cluster } = $self->getClusterData(cluster   => $cluster,
                                                           set       => $args{set},
                                                           time_laps => $args{time_laps},
                                                           percent   => $args{percent},
                                                           aggregate => $args{aggregate});
    }

    return \%clusters_data;
}

1;

__END__

=head1 AUTHOR

Copyright (c) 2010 by Hedera Technology Dev Team (dev@hederatech.com). All rights reserved.
This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
