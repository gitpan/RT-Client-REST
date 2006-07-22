# $Id: Exception.pm 4 2006-07-22 21:02:27Z dmitri $
# RT::Client::REST::Object::Exception

package RT::Client::REST::Object::Exception;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = 0.01;

use Error;

use Exception::Class (
    'RT::Client::REST::Object::OddNumberOfArgumentsException'   => {
        isa         => __PACKAGE__,
        description => "This means that we wanted name/value pairs",
    },

    'RT::Client::REST::Object::InvalidValueException' => {
        isa         => __PACKAGE__,
        description => "Object attribute was passed an invalid value",
    },

    'RT::Client::REST::Object::NoValuesProvidedException' => {
        isa         => __PACKAGE__,
        description => "Method expected parameters, but none were provided",
    },
);

# Some mildly weird magic to fix up inheritance (see Exception::Class POD).
{
    no strict 'refs';
    push @{__PACKAGE__ . '::ISA'}, 'Exception::Class::Base';
    push @Exception::Class::Base::ISA, 'Error'
        unless Exception::Class::Base->isa('Error');
}

1;
