use strict;
use warnings;

use Test::More tests => 2;
use Test::Exception;

use constant METHODS => (
    'new', 'username', 'password', 'server', 'cookie', 'show', 'edit',
    'create', 'comment', 'correspond', 'merge_tickets', 'link_tickets',
    'unlink_tickets',
);

use RT::Client::REST;

my $rt;

lives_ok {
    $rt = RT::Client::REST->new;
} 'RT::Client::REST instance created';

can_ok($rt, METHODS);

# vim:ft=perl:
