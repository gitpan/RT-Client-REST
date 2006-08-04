use strict;
use warnings;

use Test::More tests => 21;
use Test::Exception;

use constant METHODS => (
    'new', 'server', 'show', 'edit', 'login',
    'create', 'comment', 'correspond', 'merge_tickets', 'link_tickets',
    'unlink_tickets', 'search', 'get_attachment_ids', 'get_attachment',
    'get_transaction_ids', 'get_transaction', 'take', 'untake', 'steal',
);

use RT::Client::REST;

my $rt;

lives_ok {
    $rt = RT::Client::REST->new;
} 'RT::Client::REST instance created';

for my $method (METHODS) {
    can_ok($rt, $method);
}

throws_ok {
    $rt->login;
} 'RT::Client::REST::InvalidParameterValueException',
    "requires 'username' and 'password' parameters";

# vim:ft=perl:
