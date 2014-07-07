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

=head1 NAME

SCOM::Query - get performance counters values from a remote management server

=head1 SYNOPSIS

    my %counters = (
        'Memory'    => ['Available MBytes','PercentMemoryUsed'],
        'Processor' => ['% Processor Time'],
    );
    
    my $scom = SCOM::Query->new( server_name => $management_server_name );
    
    my $res = $scom->getPerformance(
        counters    => \%counters,
        monitoring_object => [],
        start_time  => '2/2/2012 11:00:00 AM',
        end_time    => '2/2/2012 12:00:00 AM',
    );

=head1 DESCRIPTION

Retrieve in one request all wanted counters (only one remote connection).
Output hash is fashionable.

Powershell script execution must be allowed (> set-executionPolicy unrestricted)

=head1 METHODS

=cut

package SCOM::Query;

use strict;
use warnings;

use IPC::Cmd;

sub new {
    my $class = shift;
    my %args = @_;

    # TODO check args
    
    my $self = {};
    bless $self, $class;
    
    $self->{_management_server_name} = $args{server_name};

    # Connection to scom shell using import module
#    $self->{_scom_modules} = [
#        'C:\Program Files\System Center Operations Manager 2007\Microsoft.EnterpriseManagement.OperationsManager.ClientShell.dll',
#        'C:\Program Files\System Center Operations Manager 2007\Microsoft.EnterpriseManagement.OperationsManager.ClientShell.Functions.ps1',
#    ];
#    $self->{_scom_shell_cmd} = 'Start-OperationsManagerClientShell -managementServerName: ' . $self->{_management_server_name} . ' -persistConnection: $false -interactive: $false';
    
    # Connection to scom shell using pssnapin
    $self->{_scom_shell_init} = [
        'Add-PSSnapin Microsoft.EnterpriseManagement.OperationsManager.Client',
        'New-ManagementGroupConnection -ConnectionString:localhost',
        'Set-Location \'OperationsManagerMonitoring::\'',
    ];
    
    $self->{_remote_invocation_options} = $args{use_ssl} ? "-UseSSL" : "";
    
    return $self;
}

sub getPerformance {
    my $self = shift;
    my %args = @_;
    
    my $wanted_attrs = defined $args{want_attrs} ? $args{want_attrs} 
                                                 : ['$pc.MonitoringObjectPath','$pc.ObjectName','$pc.CounterName','$pv.TimeSampled','$pv.SampleValue'];
    my ($line_sep, $item_sep) = ('DATARAW', '###');
    
    my @monit_object_slice = ($args{monitoring_object });
    my @res_slice;
    my %h_res;

    # We loop over slice to handle command is too long issue
    # If can't exec a slice we split it in sub-slice
    # Split only monitoring object list and not counters (TODO)
    OBJECT_SLICE:
    foreach my $monit_objects (@monit_object_slice) {
        if (@$monit_objects == 0) {
            die 'Can not split the command more, still too long or an unexpected error occured';
        }

        my $cmd = $self->_buildGetPerformanceCmd(
                    counters            => $args{counters},
                    monitoring_object   => $monit_objects,
                    start_time          => $args{start_time},
                    end_time            => $args{end_time},
                    want_attrs          => $wanted_attrs,
                    line_sep            => $line_sep,
                    item_sep            => $item_sep,
        );

        # Execute command
        my $cmd_res = $self->_execCmd(cmd => $cmd);

        # remove all \n (end of line and inserted \n due to console output)
        $cmd_res =~ s/(\r|\n)//g;

        # If can't execute command (too long) we split it
        if ($cmd_res eq '') {
            #$log->debug("command too long, we split it");
            my @objects = @{$monit_objects};
            my $last_idx = $#objects;
            my @left  = @objects[0..int($last_idx/2)];
            my @right = @objects[(int($last_idx/2)+1)..$last_idx];
            push @monit_object_slice, (\@left, \@right);
            next OBJECT_SLICE;
        }

        # Die if something wrong
        if ($cmd_res !~ '^PathName' || $cmd_res !~ 'DATASTART') {
            $cmd_res =~ s/DATASTART//g;
            die 'SCOM request fails : ' . $cmd_res;
        }

        # Build resulting data hash from cmd output
        my $h_res_slice    = $self->_formatToHash( 
                                    input           => $cmd_res,
                                    line_sep        => $line_sep,
                                    item_sep        => $item_sep,
                                    items_per_line  => scalar(@$wanted_attrs),
                                    #index_order    => [0,1,2,3,4],
        );
        
        %h_res = (%h_res, %$h_res_slice);
    }

    return \%h_res;
}

sub getcounters {
    
}

# Build a power shell command to execute a SCOM command on management server
sub _execCmd {
    my $self = shift;
    my %args = @_;
    
    my @cmd_list = (
        #map({ "import-module '$_' -DisableNameChecking" } @{$self->{_scom_modules}}),   # import modules without verb warning
        #$self->{_scom_shell_cmd},                                                       # connect to scom shell on management server
        @{ $self->{_scom_shell_init} },                                                 # connect to scom shell
        $args{cmd},                                                                     # SCOM cmd to execute (double quote must be escaped)
    );

    my $full_cmd = join(';', @cmd_list) . ";";

    my $remote_cmd = ['remote_powershell_cmd.py', '-t', $self->{_management_server_name}, '-c', $full_cmd];
    my ($success, $error_message, $full_buf, $stdout_buf, $stderr_buf) = IPC::Cmd::run(command => $remote_cmd, verbose => 0);

    if (!$success) {
        my $error = join "", @$stderr_buf;
        if (!$error || $error eq '') { $error = $error_message };
        die "Something went wrong when trying to call powershell remote script : '$error'";
    }

    my $cmd_res = join "", @$stdout_buf;

    return $cmd_res;
}

sub _buildGetPerformanceCmd {
    my $self = shift;
    my %args = @_;
    my @want_attrs  = @{$args{want_attrs}};
    my %counters    = %{$args{counters}};
    my $start_time  = $args{start_time};
    my $end_time    = $args{end_time};
    
    my @obj_criteria;
    while (my ($object_name, $counters_name) = each %counters) {
        push @obj_criteria,
            "(ObjectName='$object_name' and (" . join( ' or ', map { "CounterName='$_'" } @$counters_name) . "))";
    }
    my $criteria = join ' or ', @obj_criteria;
    
    if (defined $args{monitoring_object}) {
        my $target_criteria = join ' or ', map { "MonitoringObjectPath='$_'" } @{$args{monitoring_object}};
        $criteria = "($criteria) and ($target_criteria)";
    }
    
    my $want_attrs_str = join ',', @want_attrs;
    my $format_str = join $args{item_sep}, map { "{$_}" } (0..$#want_attrs);

    # TODO study better way: ps script template...
    my $cmd   = 'echo DATASTART;';
    $cmd     .= 'foreach ($pc in Get-PerformanceCounter -Criteria \"' . $criteria . '\")';
    #my $cmd  = 'foreach ($pc in Get-PerformanceCounter )';
    $cmd     .= '{ foreach ($pv in Get-PerformanceCounterValue -startTime \''. $start_time .'\' -endTime \''. $end_time .'\' $pc)';
    $cmd     .= '{ \"' . $args{line_sep} . $format_str . '\" -f ' . $want_attrs_str . '; } }';

    return $cmd;
}

# Parse string and build correponding hash
# String has multi lines separated by line_sep
# each line has data separated by item_sep
# resulting hash is build in this way: $h{item_0}{item_1}{item_2}{...} = value
# with item_x = item at pos $key_idx_order[x] 
# and value = item at pos $value_idx 
sub _formatToHash {
    my $self = shift;
    my %args = @_;
    my $input = $args{input};

    my $value_idx = defined $args{value_index} ? $args{value_index} : $args{items_per_line} - 1; # last item by default
    my @key_idx_order = defined $args{index_order} ? @{$args{index_order}} : (0..$args{items_per_line}-2);
    
    my %h_res;
    LINE:
    foreach my $line (split $args{line_sep}, $input) {
        my @items = split $args{item_sep}, $line;
        if ($args{items_per_line} != @items) {
            # TODO LOG WARNING !!
            next LINE;
        }
        my $h_update_str =     '$h_res' .
                            (join '', map { "{'$items[$_]'}" } @key_idx_order) .
                            "= '$items[$value_idx]';";
        eval($h_update_str);
    }
    
    return \%h_res;
}

1;
