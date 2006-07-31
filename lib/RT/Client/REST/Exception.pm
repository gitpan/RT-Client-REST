# $Id: Exception.pm 24 2006-07-28 20:39:27Z dtikhonov $
#
# We are going to throw exceptions, because we're cool like that.
package RT::Client::REST::Exception;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = 0.02;

use Error;

use Exception::Class (
    'RT::Client::REST::OddNumberOfArgumentsException'   => {
        isa         => __PACKAGE__,
        description => "This means that we wanted name/value pairs",
    },

    'RT::Client::REST::InvaildObjectTypeException'   => {
        isa         => __PACKAGE__,
        description => "Invalid object type was specified",
    },

    'RT::Client::REST::MalformedRTResponseException'    => {
        isa         => __PACKAGE__,
        description => "Malformed RT response received from server",
    },

    'RT::Client::REST::InvalidParameterValueException'  => {
        isa         => __PACKAGE__,
        description => "This happens when you feed me bad values",
    },

    'RT::Client::REST::RTException' => {
        isa         => __PACKAGE__,
        fields      => ['code'],
        description => "RT server returned an error code",
    },

    'RT::Client::REST::ObjectNotFoundException' => {
        isa         => 'RT::Client::REST::RTException',
        description => 'One or more of the specified objects was not found',
    },

    'RT::Client::REST::CouldNotCreateObjectException' => {
        isa         => 'RT::Client::REST::RTException',
        description => 'Object could not be created',
    },

    'RT::Client::REST::AuthenticationFailureException'  => {
        isa         => 'RT::Client::REST::RTException',
        description => "Incorrect username or password",
    },

    'RT::Client::REST::UnknownCustomFieldException' => {
        isa         => 'RT::Client::REST::RTException',
        description => 'Unknown custom field',
    },

    'RT::Client::REST::InvalidQueryException' => {
        isa         => 'RT::Client::REST::RTException',
        description => 'Invalid query (server could not parse it)',
    },

    'RT::Client::REST::UnknownRTException' => {
        isa         => 'RT::Client::REST::RTException',
        description => 'Some other RT error',
    },

    'RT::Client::REST::HTTPException'   => {
        isa         => __PACKAGE__,
        fields      => ['code'],
        description => "Error in the underlying protocol (HTTP)",
    },
);

sub _rt_content_to_exception {
    my ($self, $content) = @_;

    if ($content =~ /not found|does not exist/) {
        return 'RT::Client::REST::ObjectNotFoundException';
    } elsif ($content =~ /not create/) {
        return 'RT::Client::REST::CouldNotCreateObjectException';
    } elsif ($content =~ /[Uu]nknown custom field/) {
        return 'RT::Client::REST::UnknownCustomFieldException';
    } elsif ($content =~ /[Ii]nvalid query/) {
        return 'RT::Client::REST::InvalidQueryException';
    } else {
        return 'RT::Client::REST::UnknownRTException';
    }
}

# Some mildly weird magic to fix up inheritance (see Exception::Class POD).
{
    no strict 'refs';
    push @{__PACKAGE__ . '::ISA'}, 'Exception::Class::Base';
    push @Exception::Class::Base::ISA, 'Error'
        unless Exception::Class::Base->isa('Error');
}

1;
