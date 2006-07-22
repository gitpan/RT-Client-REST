use strict;
use warnings;

use Test::More tests => 27;
use Test::Exception;

use constant METHODS => (
    'new', 'to_form', 'from_form', 'rt_type',
    
    # attrubutes:
    'id', 'queue', 'owner', 'creator', 'subject', 'status', 'priority',
    'initial_priority', 'final_priority', 'requestors', 'cc', 'admin_cc',
    'created', 'starts', 'started', 'due', 'resolved', 'told',
    'time_estimated', 'time_worked', 'time_left',
);

BEGIN {
    use_ok('RT::Client::REST::Ticket');
}

my $ticket;

lives_ok {
    $ticket = RT::Client::REST::Ticket->new;
} 'Ticket can get successfully created';

for my $method (METHODS) {
    can_ok($ticket, $method);
}

# vim:ft=perl:
