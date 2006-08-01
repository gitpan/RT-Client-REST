# $Id: Exception.pm 41 2006-08-01 14:59:39Z dtikhonov $
# RT::Client::REST::Object::Exception

package RT::Client::REST::Object::Exception;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = 0.03;

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

    'RT::Client::REST::Object::InvalidSearchParametersException' => {
        isa         => __PACKAGE__,
        description => "Invalid search parameters provided",
    },

    'RT::Clite::REST::Object::InvalidAttributeException' => {
        isa         => __PACKAGE__,
        description => "Invalid attribute name",
    },

    'RT::Client::REST::Object::IllegalMethodException' => {
        isa         => __PACKAGE__,
        description => "Illegal method is called on the object",
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
