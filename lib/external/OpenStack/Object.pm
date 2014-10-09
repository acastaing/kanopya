#    Copyright © 2013 Hedera Technology SAS
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

package OpenStack::Object;

use Kanopya::Exceptions;

use HTTP::Request::Common;
use LWP;
use JSON qw(from_json to_json);

use Data::Dumper;

use Log::Log4perl "get_logger";
my $log = get_logger("");

sub new {
    my ($self, %args) = @_;

    return bless \%args;
}

sub AUTOLOAD {
    my ($self, %args) = @_;
    General::checkParams(args => \%args,
                         optional => { 'id' => undef, 'filter' => undef });

    my @autoload = split(/::/, $AUTOLOAD);
    my $method = $autoload[-1];

    my $path = (defined $self->{path}) ? $self->{path} . '/' : '';

    # $args{id} is used to avoid methods starting with digit
    # abc->images(id => '022efa')->members <---> abc/images/022efa/members
    if ( defined $args{id} || defined $args{varchar} ) {
        $path .= $method . '/' . $args{id};
    }
    else {
        $path .= $method;
    }

    $path .= '?' . $args{filter} if ( defined $args{filter} );

    return OpenStack::Object->new(path    => $path,
                                  service => $self->{service});
}

sub get {
    my ($self, %args) = @_;

    my $response = $self->request(method_type => 'GET', parameters => \%args);

    return $response;
}

sub post {
    my ($self, %args) = @_;

    my $response = $self->request(method_type => 'POST', parameters => \%args);

    return $response;
}

sub put {
    my ($self, %args) = @_;

    my $response = $self->request(method_type => 'PUT', parameters => \%args);

    return $response;
}

sub delete {
    my ($self, %args) = @_;

    my $response = $self->request(method_type => 'DELETE', parameters => \%args);

    return $response;
}

sub request {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'method_type', 'parameters' ]);
    my $parameters = $args{parameters};
    General::checkParams(
        args        => $parameters,
        optional    => {
            'content'       => undef,
            'content_type'  => 'application/json',
            'headers'        => undef,
        }
    );

    $log->debug('Request : Service endpoint : ' . $self->{service}->getEndpoint);

    my $token = $self->{service}->{api}->{token};
    my $method_type = $args{method_type};
    my $content = $parameters->{content};
    my $content_type = $parameters->{content_type};
    my $headers = $parameters->{headers};

    my $url = '';
    if (defined $parameters->{admin} && $parameters->{admin} eq 1) {
        $url = $self->{service}->adminURL;
    }
    else {
        $url = $self->{service}->getEndpoint;
    }
    $url .= '/' . $self->{path};

    my $request = '-H "Accept: application/json" -H "Expect: "';
    if (defined $content) {
        $request = ' -H "Content-Type:' . $content_type . '"';
        if ($content_type eq 'application/json') {
            $request .= " -d  '" . to_json($content) . "'";
        }
        else { # Content-Type = 'application/octet-stream' => Content = FilePath in our case
            $request .= ' -T ' . $content;
        }
    }

    # TODO if ( $self->{token_expiration} <= date('UTC') ) then $self->login();
    # Token is undefined for the first request (to obtain a token)
    $request .= ' -H "X-Auth-Token:' . $token . '"' if (defined $token);

    # Each header is jsonified and preceded by "-H" option of curl
    if (defined $headers) {
        foreach my $header (keys(%$headers)) {
            $request .= ' -H "' . $header . ':' . $headers->{$header} . '"';
        }
    }

    $log->debug("curl -X $method_type $request $url");
    my $response = `curl -X $method_type $request $url`;
    my $returncode = $?;
    if($returncode != 0) {
        throw Kanopya::Exception::Execution::Command(
              error       => 'Openstack API call with curl failed',
              command     => "curl -X $method_type $request $url",
              return_code => $returncode,
	)
    }

    my $json;
    eval {
        $json = from_json($response);
    };
    if ($@) {
        if ($response) {
            $log->debug("Invalid response from API : $response");
        }
        else {
            $log->debug("API returned no response");
        }
    }

    return $json;
}

sub DESTROY {
}

1;
