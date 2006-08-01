use strict;
use warnings;

use Test::More tests => 36;
use Test::Exception;

use constant METHODS => (
    'new', 'to_form', 'from_form', 'rt_type', 'comment', 'correspond',
    'attachments',
    
    # attrubutes:
    'id', 'queue', 'owner', 'creator', 'subject', 'status', 'priority',
    'initial_priority', 'final_priority', 'requestors', 'cc', 'admin_cc',
    'created', 'starts', 'started', 'due', 'resolved', 'told',
    'time_estimated', 'time_worked', 'time_left', 'last_updated',
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

for my $method (qw(comment correspond)) {
    throws_ok {
        $ticket->$method(1);
    } 'RT::Client::REST::Object::OddNumberOfArgumentsException';

    throws_ok {
        $ticket->$method;
    } 'RT::Client::REST::Object::InvalidValueException';
}

ok('ticket' eq $ticket->rt_type);

# vim:ft=perl:
