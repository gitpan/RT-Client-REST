# $Id: Ticket.pm 12 2006-07-25 16:34:01Z dmitri $
#
# RT::Client::REST::Ticket -- ticket object representation.

package RT::Client::REST::Ticket;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = 0.02;

use Params::Validate qw(:types);
use RT::Client::REST::Object 0.01;
use RT::Client::REST::Object::Exception 0.01;
use base 'RT::Client::REST::Object';

=head1 NAME

RT::Client::REST::Ticket -- ticket object.

=head1 SYNOPSIS

  my $rt = RT::Client::REST->new(
    server  => $ENV{RTSERVER},
    username=> $username,
    password=> $password,
  );

  my $ticket = RT::Client::REST::Ticket->new(
    rt  => $rt,
    id  => $id,
    priority => 10,
  )->store;

=head1 DESCRIPTION

B<RT::Client::REST::Ticket> is based on L<RT::Client::REST::Object>.
The representation allows to retrieve, edit, comment on, and create
tickets in RT.

=cut

sub _attributes {{

    id  => {
        validation  => {
            type    => SCALAR,
            regex   => qr/^\d+$/,
        },
        form2value  => sub {
            shift =~ m~^ticket/(\d+)$~i;
            return $1;
        },
        value2form  => sub {
            return 'ticket/' . shift;
        },
    },

    queue   => {
        validation  => {
            type    => SCALAR,
        },
    },

    owner   => {
        validation  => {
            type    => SCALAR,
        },
    },

    creator   => {
        validation  => {
            type    => SCALAR,
        },
    },

    subject => {
        validation  => {
            type    => SCALAR,
        },
    },

    status  => {
        validation  => {
            # That's it for validation...  People can create their own
            # custom statuses.
            type    => SCALAR,
        },
    },

    priority => {
        validation  => {
            type    => SCALAR,
        },
    },

    initial_priority => {
        validation  => {
            type    => SCALAR,
        },
        rest_name   => 'InitialPriority',
    },

    final_priority  => {
        validation  => {
            type    => SCALAR,
        },
        rest_name   => 'FinalPriority',
    },

    requestors      => {
        validation  => {
            type    => ARRAYREF,
        },
        list        => 1,
    },

    cc              => {
        validation  => {
            type    => ARRAYREF,
        },
        list        => 1,
    },

    admin_cc        => {
        validation  => {
            type    => ARRAYREF,
        },
        list        => 1,
        rest_name   => 'AdminCc',
    },

    created         => {
        validation  => {
            type    => SCALAR,
        },
    },

    starts          => {
        validation  => {
            type    => SCALAR|UNDEF,
        },
    },

    started         => {
        validation  => {
            type    => SCALAR|UNDEF,
        },
    },

    due             => {
        validation  => {
            type    => SCALAR|UNDEF,
        },
    },

    resolved        => {
        validation  => {
            type    => SCALAR|UNDEF,
        },
    },

    told            => {
        validation  => {
            type    => SCALAR|UNDEF,
        },
    },

    time_estimated  => {
        validateion => {
            type    => SCALAR,
        },
        rest_name   => 'TimeEstimated',
    },

    time_worked     => {
        validateion => {
            type    => SCALAR,
        },
        rest_name   => 'TimeWorked',
    },

    time_left       => {
        validateion => {
            type    => SCALAR,
        },
        rest_name   => 'TimeLeft',
    },

    last_updated    => {
        validateion => {
            type    => SCALAR,
        },
        rest_name   => 'LastUpdated',
    },
}}

=head1 ATTRIBUTES

=over 2

=item B<id>

This is the numeric ID of the ticket.

=item B<queue>

This is the B<name> of the queue (not numeric id).

=item B<owner>

Username of the owner.

=item B<creator>

Username of RT user who created the ticket.

=item B<subject>

Subject of the ticket.

=item B<status>

The status is usually one of the following: "new", "open", "resolved",
"stalled", "rejected", and "deleted".  However, custom RT installations
sometimes add their own statuses.

=item B<priority>

Ticket priority.  Usually a numeric value.

=item B<initial_priority>

=item B<final_priority>

=item B<requestors>

This is a list attribute (for explanation of list attributes, see
B<LIST ATTRIBUTE PROPERTIES> in L<RT::Client::REST::Object>).  Contains
e-mail addresses of the requestors.

=item B<cc>

A list of e-mail addresses used to notify people of 'correspond'
actions.

=item B<admin_cc>

A list of e-mail addresses used to notify people of all actions performed
on a ticket.

=item B<created>

Time at which ticket was created.

=item B<starts>

=item B<started>

=item B<due>

=item B<resolved>

=item B<told>

=item B<time_estimated>

=item B<time_worked>

=item B<time_left>

=item B<last_updated>

=back

=head1 DB METHODS

For full explanation of these, please see B<"DB METHODS"> in
L<RT::Client::REST::Object> documentation.

=over 2

=item B<retrieve>

Retrieve RT ticket from database.

=item B<store>

Create or update the ticket.

=item B<search>

Search for tickets that meet specific conditions.

=back

=head1 TICKET-SPECIFIC METHODS

=over 2

=item B<comment(message => $message, %opts)>

Comment on this ticket with message $message.  C<%opts> is a list of
key-value pairs as follows:

=over 2

=item B<cc>

List of e-mail addresses to send carbon copies to (an array reference).

=item B<bcc>

List of e-mail addresses to send blind carbon copies to (an array
reference).

=back

=item B<correspond(message => $message, %opts)>

Add correspondence to the ticket.  Takes exactly the same arguments
as the B<comment> method above.

=back

=cut

# comment and correspond are really the same method, so we save ourselves
# some duplication here.
for my $method (qw(comment correspond)) {
    no strict 'refs';
    *$method = sub {
        my $self = shift;

        if (@_ & 1) {
            RT::Client::REST::Object::OddNumberOfArgumentsException->throw;
        }

        my %opts = @_;

        unless (defined($opts{message})) {
            RT::Client::REST::Object::InvalidValueException->throw(
                "No message was provided",
            );
        }

        $self->rt->$method(
            ticket_id => $self->id,
            %opts,
        );

        return;
    };
}

=head1 INTERNAL METHODS

=over 2

=item B<rt_type>

Returns 'ticket'.

=cut

sub rt_type { 'ticket' }

=back

=head1 SEE ALSO

L<RT::Client::REST>, L<RT::Client::REST::Object>.

=head1 AUTHOR

Dmitri Tikhonov <dtikhonov@yahoo.com>

=head1 LICENSE

Perl license with the exception of L<RT::Client::REST>, which is GPLed.

=cut

__PACKAGE__->_generate_methods;

1;
