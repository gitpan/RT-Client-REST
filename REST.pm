# $Id$
# RT::Client::REST
#
# Dmitri Tikhonov <dtikhonov@vonage.com>
# April 18, 2006
#
# This code is adapted (stolen) from /usr/bin/rt that came with RT.  I just
# wanted to make an actual module out of it.  Therefore, this code is GPLed.
#
# Original notice:
#------------------------
# COPYRIGHT:
# This software is Copyright (c) 1996-2005 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
# Designed and implemented for Best Practical Solutions, LLC by
# Abhijit Menon-Sen <ams@wiw.org>
#------------------------


# We are going to throw exceptions, because we're cool like that.
package RT::Client::REST::Exception;

use strict;
use warnings;

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

    'RT::Client::REST::AuthenticationFailureException'  => {
        isa         => 'RT::Client::REST::RTException',
        description => "Incorrect username or password",
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

    if ($content =~ /not found/) {
        return 'RT::Client::REST::ObjectNotFoundException';
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


# Now for the actual package.
package RT::Client::REST;
use vars qw/$VERSION/;

$VERSION = 0.03;

use strict;
use warnings;

    # This exports the following methods:
    # expand_list form_parse form_compose vpush vsplit
use RT::Interface::REST;

use LWP;
use HTTP::Cookies;
use HTTP::Request::Common;

# Generate accessors/mutators
for my $method (qw(username password server cookie)) {
    no strict 'refs';
    *{__PACKAGE__ . '::' . $method} = sub {
        my $self = shift;
        $self->{'_' . $method} = shift if @_;
        return $self->{'_' . $method};
    };
}

sub new {
    my $class = shift;

    $class->_assert_even(@_);

    my $self = bless {}, ref($class) || $class;
    my %opts = @_;

    while (my ($k, $v) = each(%opts)) {
        $self->$k($v);
    }

    return $self;
}

sub show {
    my $self = shift;

    $self->_assert_even(@_);

    my %opts = @_;

    my $type = $self->_valid_type(delete($opts{type}));
    my $objects = $self->_valid_objects(delete($opts{objects}));

    my $r = $self->_submit('show', {
        id => [ map { $type . '/' . $_ } @$objects ],
    });

    return map { $$_[2] } @{form_parse($r->content)};
}

sub edit {
    my $self = shift;
    $self->_assert_even(@_);
    my %opts = @_;

    my $type = $self->_valid_type(delete($opts{type}));
    my $objects = $self->_valid_objects(delete($opts{objects}));

    my (%set);
    if (defined(my $set = delete($opts{set}))) {
        while (my ($k, $v) = each(%$set)) {
            vpush(\%set, lc($k), $v);
        }
    }

    my @forms;
    for my $obj (@$objects) {
        my %set = (%set, id => "$type/$obj");
        push @forms, ['', [keys %set], \%set]
    }

    my $r = $self->_submit('edit', {
        content => form_compose(\@forms),
    });

    print $r->content;
}

sub create { shift->edit(@_, objects => ['new']) }

sub comment {
    my $self = shift;
    $self->_assert_even(@_);
    my %opts = @_;
    my $action = $self->_valid_comment_action(
        delete($opts{comment_action}) || 'comment');
    my $ticket_id = $self->_valid_numeric_ticket_id(delete($opts{ticket_id}));
    my $msg = $self->_valid_comment_message(delete($opts{message}));

    my $text = form_compose([[
        '',
        [ "Ticket", "Action", "Cc", "Bcc", "Attachment", "TimeWorked", "Text" ],
        {
            Ticket      => $ticket_id,
            Action      => $action,
            Cc          => [],
            Bcc         => [],
            Attachment  => [],
            TimeWorked  => '',
            Text        => $msg,
            Status      => '',
        },
    ]]);

    my $r = $self->_submit("ticket/comment/$ticket_id", {
        content => $text,
    });

    return $r->content;
}

sub correspond { shift->comment(@_, comment_action => 'correspond') }

sub merge_tickets {
    my $self = shift;
    $self->_assert_even(@_);
    my %opts = @_;
    my ($src, $dst) = map { $self->_valid_numeric_ticket_id($_) }
        @opts{qw(src dst)};
    my $r = $self->_submit("ticket/merge/$src", { into => $dst});
    print $r->content;
}

sub link_tickets {
    my $self = shift;
    $self->_assert_even(@_);
    my %opts = @_;
    my ($src, $dst) = map { $self->_valid_numeric_ticket_id($_) }
        @opts{qw(src dst)};
    my $ltype = $self->_valid_link_type(delete($opts{link_type}));
    my $del = (exists($opts{'unlink'}) ? 1 : '');

    my $r = $self->_submit("ticket/link", {
        id  => $src,
        rel => $ltype,
        to  => $dst,
        del => $del,
    });

    print $r->content;
}

sub unlink_tickets { shift->link_tickets(@_, unlink => 1) }

sub _submit {
    my ($self, $uri, $content) = @_;
    my ($req, $data);
    my $ua = new LWP::UserAgent(
        agent => $self->_ua_string,
        env_proxy => 1,
    );

    # Did the caller specify any data to send with the request?
    $data = [];
    if (defined $content) {
        unless (ref $content) {
            # If it's just a string, make sure LWP handles it properly.
            # (By pretending that it's a file!)
            $content = [ content => [undef, "", Content => $content] ];
        }
        elsif (ref $content eq 'HASH') {
            my @data;
            foreach my $k (keys %$content) {
                if (ref $content->{$k} eq 'ARRAY') {
                    foreach my $v (@{ $content->{$k} }) {
                        push @data, $k, $v;
                    }
                }
                else { push @data, $k, $content->{$k} }
            }
            $content = \@data;
        }
        $data = $content;
    }

    # Should we send authentication information to start a new session?
    unless ($self->cookie) {
        push @$data, (user => $self->username, pass => $self->password);
    }

    # Now, we construct the request.
    if (@$data) {
        $req = POST($self->_uri($uri), $data, Content_Type => 'form-data');
    }
    else {
        $req = GET($self->_uri($uri));
    }
    #$session->add_cookie_header($req);
    if ($self->cookie) {
        $self->cookie->add_cookie_header($req);
    }

    # Then we send the request and parse the response.
    #DEBUG(3, $req->as_string);
    my $res = $ua->request($req);
    #DEBUG(3, $res->as_string);

    if ($res->is_success) {
        # The content of the response we get from the RT server consists
        # of an HTTP-like status line followed by optional header lines,
        # a blank line, and arbitrary text.

        my ($head, $text) = split /\n\n/, $res->content, 2;
        my ($status, @headers) = split /\n/, $head;
        $text =~ s/\n*$/\n/ if ($text);

        # "RT/3.0.1 401 Credentials required"
	if ($status !~ m#^RT/\d+(?:\S+) (\d+) ([\w\s]+)$#) {
            RT::Client::REST::MalformedRTResponseException->throw(
                "Malformed RT response received from " . $self->server,
            );
        }

        # Our caller can pretend that the server returned a custom HTTP
        # response code and message. (Doing that directly is apparently
        # not sufficiently portable and uncomplicated.)
        $res->code($1);
        $res->message($2);
        $res->content($text);
        #$session->update($res) if ($res->is_success || $res->code != 401);
        if ($res->header('set-cookie')) {
            my $jar = HTTP::Cookies->new;
            $jar->extract_cookies($res);
            $self->cookie($jar);
        }

        if (!$res->is_success) {
            # We can deal with authentication failures ourselves. Either
            # we sent invalid credentials, or our session has expired.
            if ($res->code == 401) {
                my %d = @$data;
                if (exists $d{user}) {
                    RT::Client::REST::AuthenticationFailureException->throw(
                        code    => $res->code,
                        message => "Incorrect username or password",
                    );
                }
                elsif ($req->header("Cookie")) {
                    # We'll retry the request with credentials, unless
                    # we only wanted to logout in the first place.
                    #$session->delete;
                    #return submit(@_) unless $uri eq "$REST/logout";
                }
            }
            # Conflicts should be dealt with by the handler and user.
            # For anything else, we just die.
            elsif ($res->code != 409) {
                RT::Client::REST::Exception->_rt_content_to_exception(
                    $res->content)
                ->throw(
                    code    => $res->code,
                    message => "RT server returned this error: " .
                               $res->content,
                );
            }
        }
    }
    else {
        RT::Client::REST::HTTPException->throw(
            code    => $res->code,
            message => $res->message,
        );
    }

    return $res;
}

sub _valid_type {
    my ($self, $type) = @_;

    unless ($type =~ /^[A-Za-z0-9_.-]+$/) {
        RT::Client::REST::InvaildObjectTypeException->throw(
            "'$type' is not a valid object type",
        );
    }

    return $type;
}

sub _valid_objects {
    my ($self, $objects) = @_;

    unless ('ARRAY' eq ref($objects)) {
        RT::Client::REST::InvalidParameterValueException->throw(
            "'objects' must be an array reference",
        );
    }

    return $objects;
}

sub _valid_numeric_ticket_id {
    my ($self, $id) = @_;

    unless ($id =~ m/^\d+$/) {
        RT::Client::REST::InvalidParameterValueException->throw(
            "'$id' is not a valid numeric ticket ID",
        );
    }

    return $id;
}

sub _valid_comment_action {
    my ($self, $action) = @_;

    unless (grep { $_ eq lc($action) } (qw(comment correspond))) {
        RT::Client::REST::InvalidParameterValueException->throw(
            "'$action' is not a valid comment action",
        );
    }

    return lc($action);
}

sub _valid_comment_message {
    my ($self, $message) = @_;

    unless (defined($message) and length($message)) {
        RT::Client::REST::InvalidParameterValueException->throw(
            "Comment cannot be empty (specify 'message' parameter)",
        );
    }

    return $message;
}

sub _valid_link_type {
    my ($self, $type) = @_;
    my @types = qw(DependsOn DependedOnBy RefersTo ReferredToBy HasMember
                   MemberOf);

    unless (grep { lc($type) eq lc($_) } @types) {
        RT::Client::REST::InvalidParameterValueException->throw(
            "'$type' is not a valid link type",
        );
    }

    return lc($type);
}

sub _assert_even {
    shift;
    RT::Client::REST::OddNumberOfArgumentsException->throw(
        "odd number of arguments passed") if @_ & 1;
}

sub _rest { shift->server . '/REST/1.0' }

sub _uri { shift->_rest . '/' . shift }

sub _ua_string {
    my $self = shift;
    return ref($self) . '/' . $self->_version;
}

sub _version { $VERSION }

1;

__END__

=pod

=head1 NAME

RT::Client::REST -- talk to RT installation using REST protocol.

=head1 SYNOPSIS

  my $rt = RT::Client::REST->new(
    username => $user,
    password => $pass,
    server => 'http://example.com/rt',
  );

  try {
    # Get tickets 10 through 20
    @tx = $rt->show(type => 'ticket', objects => [10 .. 20]);
  } catch RT::Client::REST::Exception with {
    # something went wrong.
  };

=head1 DESCRIPTION

B<RT::Client::REST> is B</usr/bin/rt> converted to a Perl module.  I needed
to implement some RT interactions from my application, but did not feel that
invoking a shell command is appropriate.  Thus, I took B<rt> tool, written
by Abhijit Menon-Sen, and converted it to an object-oriented Perl module.

As of this writing (version 0.03), B<RT::Client::REST> is missing a lot of
things that B<rt> has.  It does not support attachments, CCs, BCCs, and
probably other things.  B<RT::Client::REST> does not retrieve forms from
RT server, which is either good or bad, depending how you look at it.  More
work on this module will be performed in the future as I get a better grip
of this whole REST business.  It also does not have 'list' (or 'search')
operation; this will be added in a later version.

=head1 METHODS

=over

=item new ()

The constructor can take these options:

=over 2

=item *

B<server> is a URI pointing to your RT installation.

=item *

B<username> and B<password> are used to authenticate your request.  After
an instance of B<RT::Client::REST> is used to issue a successful request,
subsequent requests will use a cookie, so the first request is an effect
a log in.

=item *

Alternatively, if you have already authenticated against RT in some other
part of your program, you can use B<cookie> parameter to supply an object
of type B<HTTP::Cookies> to use for credentials information.

=item *

All of the above, B<server>, B<username>, B<password>, and B<cookie> can also
be used as regular methods after your object is instantiated.

=back

=item show (type => $type, objects => \@ids)

Get a list of objects of type B<4type>.  One or more IDs should be specified.
This returns an array of hashrefs (I don't get "forms", so I just take the
third element and return it).

=item edit (type => $type, objects => \@ids, set => { status => 1 })

For all objects of type B<$type> whose ID is in B<@ids>, set fields as
prescribed by the B<set> parameter.

=item create (type => $type, set => \%params)

Create a new object of type B<$type> and set initial parameters to B<%params>.

=item comment (ticket_id => $id, message => "This is a comment")

Comment on a ticket with ID B<$id>.

=item correspond (ticket_id => $id, message => "This is a comment")

Add correspondence to ticket ID B<$id>.

=item merge_tickets (src => $id1, dst => $id2)

Merge ticket B<$id1> into ticket B<$id2>.

=item link_tickets (src => $id1, dst => $id2, link_type => $type)

Create a link between two tickets.  A link type can be one of the following:

=over 2

=item

DependsOn

=item

DependedOnBy

=item

RefersTo

=item

ReferredToBy

=item

HasMember

=item

MemberOf

=back

=item unlink_tickets (src => $id1, dst => $id2, link_type => $type)

Remove a link between two tickets (see B<link_tickets()>)

=back

=head1 EXCEPTIONS

When an error occurs, this module will throw exceptions.  I recommend
using Error.pm's B<try{}> mechanism to catch them, but you may also use
simple B<eval{}>.  The former will give you flexibility to catch just the
exceptions you want.  Here is the hierarchy:

=over 2

=item

RT::Client::REST::Exception

=over 2

=item

RT::Client::REST::OddNumberOfArgumentsException

=item

RT::Client::REST::InvaildObjectTypeException

=item

RT::Client::REST::MalformedRTResponseException

=item

RT::Client::REST::InvalidParameterValueException

=item

B<RT::Client::REST::RTException>.  This exception is virtual; only its
subclasses are thrown.  This group is used when RT REST interface returns
an error message.  Exceptions derived from it all have a custom field
B<code> which can be used to get RT's numeric error code.

=over 2

=item

RT::Client::REST::ObjectNotFoundException

=item

RT::Client::REST::AuthenticationFailureException

=item

RT::Client::REST::UnknownRTException

=back

=item

B<RT::Client::REST::HTTPException>.  This is thrown if anything besides
B<200 OK> code is returned by the underlying HTTP protocol.  Custom field
B<code> can be used to access the actual HTTP status code.

=back

=back

=head1 DEPENDENCIES

The following modules are required:

=over 2

=item

Error

=item

Exception::Class

=item

RT::Interface::REST

=item

LWP

=item

HTTP::Cookies

=item

HTTP::Request::Common

=back

=head1 BUGS

Most likely.  Please report.

=head1 TODO

=over 2

=item

Add the rest of the features available in /usr/bin/rt.

=item

Implement /usr/bin/rt using this RT::Client::REST.

=back

=head1 VERSION

This is version 0.03 of B<RT::Client::REST>.  B</usr/bin/rt> shipped with
RT 3.4.5 is version 0.02, so the logical version continuation is to have
one higher.

=head1 AUTHORS

Original /usr/bin/rt was written by Abhijit Menon-Sen <ams@wiw.org>.  rt
was later converted to this module by Dmitri Tikhonov <dtikhonov@vonage.com>

=head1 LICENSE

Since original rt is licensed under GPL, so is this module.

=end