# $Id: Ticket.pm 4 2006-07-22 21:02:27Z dmitri $
#
# RT::Client::REST::Ticket -- ticket object representation.

package RT::Client::REST::Ticket;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = 0.01;

use Params::Validate qw(:types);
use RT::Client::REST::Object 0.01;
use base 'RT::Client::REST::Object';

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
}}

sub rt_type { 'ticket' }

__PACKAGE__->_generate_methods;

1;
