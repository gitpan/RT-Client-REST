use strict;
use warnings;

use Test::More tests => 11;
use Test::Exception;

use constant METHODS => (
    'new', 'to_form', 'from_form', '_generate_methods', 'store', 'retrieve',
    'param', 'rt', 'cf',
);

BEGIN {
    use_ok('RT::Client::REST::Object');
}

my $obj;

lives_ok {
    $obj = RT::Client::REST::Object->new;
} 'Object can get successfully created';

for my $method (METHODS) {
    can_ok($obj, $method);
}

# vim:ft=perl:
