# Copyright © 2011-2012 Hedera Technology SAS
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.

=pod

=begin classdoc

The orchestration policy defines the parameters describing how a service
manage the monitoring and automation rules and conditions.

@since    2012-Aug-16
@instance hash
@self     $self

=end classdoc

=cut

package Entity::Policy::OrchestrationPolicy;
use base 'Entity::Policy';

use strict;
use warnings;

use Data::Dumper;
use Log::Log4perl 'get_logger';
use Entity::ServiceProvider;
use TryCatch;

my $log = get_logger("");

use constant ATTR_DEF => {};

sub getAttrDef { return ATTR_DEF; }

use constant POLICY_ATTR_DEF => {
    collector_manager_id => {
        label        => "Collector Manager",
        type         => 'relation',
        relation     => 'single',
        pattern      => '^\d*$',
        reload       => 1,
        is_mandatory => 1,
    },
};

use constant POLICY_SELECTOR_ATTR_DEF => {};
use constant POLICY_SELECTOR_MAP => {};

sub getPolicyAttrDef { return POLICY_ATTR_DEF; }
sub getPolicySelectorAttrDef { return POLICY_SELECTOR_ATTR_DEF; }
sub getPolicySelectorMap { return POLICY_SELECTOR_MAP; }

sub remove {
    my $self = shift;
    my $params = $self->getParams;
    if (defined $params->{orchestration}->{service_provider_id}) {
        try {
            Entity::ServiceProvider->get(id => $params->{orchestration}->{service_provider_id})->remove;
        }
        catch(Kanopya::Exception $err) {
            $log->warn('Error during service provider deletion : ' . $err->user_message);
        }
        catch($err) {
            $log->warn($err);
        }
    }
    return $self->SUPER::remove();
}

=pod

=begin classdoc

Handle orchestration policy specific parameters to build
the policy pattern. Here, handle the service provider id
that containers rules and condition to clone.

@return a policy pattern fragment

=end classdoc

=cut

sub getPatternFromParams {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, optional => { 'params' => {} });

    my $pattern = $self->SUPER::getPatternFromParams(params => $args{params});

    if (defined $args{params}->{orchestration}{service_provider_id}) {
        $pattern->{orchestration}{service_provider_id} = delete $args{params}->{orchestration}{service_provider_id};
    }
    return $pattern;
}

1;

