package Frontend;
use Dancer ':syntax';

our $VERSION = '0.1';

get '/' => sub {
    template 'index';
};

get '/login' => sub {
    template 'login', {},{ layout=>'login' };
};

true;
