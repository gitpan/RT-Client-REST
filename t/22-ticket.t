use strict;
use warnings;

use Test::More tests => 86;
use Test::Exception;

use constant METHODS => (
    'new', 'to_form', 'from_form', 'rt_type', 'comment', 'correspond',
    'attachments', 'transactions', 'take', 'untake', 'steal',
    
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
    # Need local copy.
    my $ticket = RT::Client::REST::Ticket->new;

    throws_ok {
        $ticket->$method(1);
    } 'RT::Client::REST::Object::OddNumberOfArgumentsException';

    throws_ok {
        $ticket->$method;
    } 'RT::Client::REST::Object::RequiredAttributeUnsetException',
        "won't go on without RT object";

    throws_ok {
        $ticket->rt('anc');
    } 'RT::Client::REST::Object::InvalidValueException',
        "'rt' expects an actual RT object";

    lives_ok {
        $ticket->rt(RT::Client::REST->new);
    } "RT object successfully set";

    throws_ok {
        $ticket->$method;
    } 'RT::Client::REST::Object::RequiredAttributeUnsetException',
        "won't go on without 'id' attribute";

    lives_ok {
        $ticket->id(1);
    } "'id' successfully set to a numeric value";

    throws_ok {
        $ticket->$method;
    } 'RT::Client::REST::Object::InvalidValueException';

    lives_ok {
        $ticket->id(1);
    } "'id' successfully set to a numeric value";

    throws_ok {
        $ticket->$method;
    } 'RT::Client::REST::Object::InvalidValueException',
        "Need 'message' to $method";

    throws_ok {
        $ticket->$method(message => 'abc');
    } 'RT::Client::REST::RequiredAttributeUnsetException';
}

for my $method (qw(attachments transactions)) {
    # Need local copy.
    my $ticket = RT::Client::REST::Ticket->new;

    throws_ok {
        $ticket->$method;
    } 'RT::Client::REST::Object::RequiredAttributeUnsetException',
        "won't go on without RT object";

    throws_ok {
        $ticket->rt('anc');
    } 'RT::Client::REST::Object::InvalidValueException',
        "'rt' expects an actual RT object";

    lives_ok {
        $ticket->rt(RT::Client::REST->new);
    } "RT object successfully set";

    throws_ok {
        $ticket->$method;
    } 'RT::Client::REST::Object::RequiredAttributeUnsetException',
        "won't go on without 'id' attribute";

    lives_ok {
        $ticket->id(1);
    } "'id' successfully set to a numeric value";

    throws_ok {
        $ticket->$method;
    } 'RT::Client::REST::RequiredAttributeUnsetException';
}

for my $method (qw(take untake steal)) {
    # Need local copy.
    my $ticket = RT::Client::REST::Ticket->new;

    throws_ok {
        $ticket->$method;
    } 'RT::Client::REST::Object::RequiredAttributeUnsetException',
        "won't go on without RT object";

    throws_ok {
        $ticket->rt('anc');
    } 'RT::Client::REST::Object::InvalidValueException',
        "'rt' expects an actual RT object";

    lives_ok {
        $ticket->rt(RT::Client::REST->new);
    } "RT object successfully set";

    throws_ok {
        $ticket->$method;
    } 'RT::Client::REST::Object::RequiredAttributeUnsetException',
        "won't go on without 'id' attribute";

    lives_ok {
        $ticket->id(1);
    } "'id' successfully set to a numeric value";

    throws_ok {
        $ticket->$method;
    } 'RT::Client::REST::RequiredAttributeUnsetException';
}

ok('ticket' eq $ticket->rt_type);

# vim:ft=perl:
