package Frontend;

use Dancer ':syntax';
#use Dancer::Plugin::Preprocess::Sass;
use Dancer::Plugin::Ajax;

use Login;
use KIO::Services;
use Messager;
use Monitoring;
use REST::api;
use Kanopya::Config;
use KIM::Consommation;
use KIM::MasterImage;
use KIM::WorkflowLogs;

our $VERSION = '0.1';

prefix undef;

my $dir = Kanopya::Config::getKanopyaDir();

Log::Log4perl->init($dir.'/kanopya/conf/webui-log.conf');

hook 'before' => sub {
    $ENV{EID} = session('EID');
};

hook 'before_template' => sub {
    my $tokens = shift;

    $tokens->{username}  = session('username');
};

get '/' => sub {
    my $product = config->{kanopya_product};
    template $product . '/index';
};

get '/kim' => sub {
    my $product = 'KIM';
    template $product . '/index';
};

get '/kio' => sub {
    my $product = 'KIO';
    template $product . '/index';
};

get '/conf' => sub {
    content_type "application/json";
    return to_json {
        'messages_update'   => defined config->{'messages_update'}  ? int(config->{'messages_update'})  : 10,
        'show_gritters'     => defined config->{'show_gritters'}    ? int(config->{'show_gritters'})    : 1,
    };
};

get '/sandbox' => sub {
    template 'sandbox', {}, {layout => ''};
};

get '/dashboard' => sub {
    template 'dashboard', {}, {layout => ''};
};

sub exception_to_status {
    my $exception = shift;
    my $status;

    return "error" if not defined $exception;

    if ($exception->isa("Kanopya::Exception::Permission::Denied")) {
        $status = 'forbidden';
    }
    elsif ($exception->isa("Kanopya::Exception::Internal::NotFound")) {
        $status = 'not_found';
    }
    elsif ($exception->isa("Kanopya::Exception::NotImplemented")) {
        $status = "method_not_allowed";
    }
    else {
        $status = 'error';
    }

    # Really tricky : we store the status code in the request
    # as the exception is not available in the 'after_error_render' hook
    request->{status} = $status;

    return $status;
}

hook 'before_error_init' => sub {
    my $exception = shift;
    my $status = exception_to_status($exception->exception);

    if (defined $status && request->is_ajax) {
        content_type "application/json";
        set error_template => '/json_error.tt';
    }
    else {
        set error_template => '';
    }
};

hook 'after_error_render' => sub {
    status request->{status};
};

true;
