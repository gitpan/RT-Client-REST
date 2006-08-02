# $Id: REST.pm 86 2006-08-02 18:04:19Z dtikhonov $
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


package RT::Client::REST;

use strict;
use warnings;

use vars qw/$VERSION/;
$VERSION = '0.19';

use LWP;
use HTTP::Cookies;
use HTTP::Request::Common;
use RT::Client::REST::Exception 0.06;
use RT::Client::REST::Forms;

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
    my $id;

    if ('user' eq $type) {
        # User ID may be his username, not just a number.
        $id = delete($opts{id});
    } else {
        $id = $self->_valid_numeric_object_id(delete($opts{id}));
    }

    my $form = form_parse($self->_submit("$type/$id")->content);
    my ($c, $o, $k, $e) = @{$$form[0]};

    if (!@$o && $c) {
        RT::Client::REST::Exception->_rt_content_to_exception($c)->throw;
    }

    return $k;
}

sub get_attachment_ids {
    my $self = shift;

    $self->_assert_even(@_);

    my %opts = @_;

    my $type = $self->_valid_type(delete($opts{type}) || 'ticket');
    my $id = $self->_valid_numeric_object_id(delete($opts{id}));

    my $form = form_parse(
        $self->_submit("$type/$id/attachments/")->content
    );
    my ($c, $o, $k, $e) = @{$$form[0]};

    if (!@$o && $c) {
        RT::Client::REST::Exception->_rt_content_to_exception($c)->throw;
    }

    return $k->{Attachments} =~ m/(\d+):/mg;
}

sub get_attachment {
    my $self = shift;

    $self->_assert_even(@_);

    my %opts = @_;

    my $type = $self->_valid_type(delete($opts{type}) || 'ticket');
    my $parent_id = $self->_valid_numeric_object_id(delete($opts{parent_id}));
    my $id = $self->_valid_numeric_object_id(delete($opts{id}));

    my $form = form_parse(
        $self->_submit("$type/$parent_id/attachments/$id")->content
    );
    my ($c, $o, $k, $e) = @{$$form[0]};

    if (!@$o && $c) {
        RT::Client::REST::Exception->_rt_content_to_exception($c)->throw;
    }

    return $k;
}

sub get_transaction_ids {
    my $self = shift;

    $self->_assert_even(@_);

    my %opts = @_;

    my $parent_id = $self->_valid_numeric_object_id(delete($opts{parent_id}));
    my $type = $self->_valid_type(delete($opts{type}) || 'ticket');

    my $path;
    my $tr_type = delete($opts{transaction_type});
    if (!defined($tr_type)) {
        # Gotta catch 'em all!
        $path = "$type/$parent_id/history";
    } elsif ('ARRAY' eq ref($tr_type)) {
        # OK, more than one type.  Call ourselves for each.
        # NOTE: this may be very expensive.
        return sort map {
            $self->get_transaction_ids(
                parent_id => $parent_id,
                transaction_type => $_,
            )
        } map {
            # Check all the types before recursing, cheaper to catch an
            # error this way.
            $self->_valid_transaction_type($_)
        } @$type;
    } else {
        $tr_type = $self->_valid_transaction_type($tr_type);
        $path = "$type/$parent_id/history/type/$tr_type"
    }

    my $form = form_parse( $self->_submit($path)->content );
    my ($c, $o, $k, $e) = @{$$form[0]};

    if (!length($e)) {
        my $ex = RT::Client::REST::Exception->_rt_content_to_exception($c);
        unless ($ex->message =~ m~^0/~) {
            # We do not throw exception if the error is that no values
            # were found.
            $ex->throw;
        }
    }

    return $e =~ m/^(?:>> )?(\d+):/mg;
}

sub get_transaction {
    my $self = shift;

    $self->_assert_even(@_);

    my %opts = @_;

    my $type = $self->_valid_type(delete($opts{type}) || 'ticket');
    my $parent_id = $self->_valid_numeric_object_id(delete($opts{parent_id}));
    my $id = $self->_valid_numeric_object_id(delete($opts{id}));

    my $form = form_parse(
        $self->_submit("$type/$parent_id/history/id/$id")->content
    );
    my ($c, $o, $k, $e) = @{$$form[0]};

    if (!@$o && $c) {
        RT::Client::REST::Exception->_rt_content_to_exception($c)->throw;
    }

    return $k;
}

sub search {
    my $self = shift;

    $self->_assert_even(@_);

    my %opts = @_;

    my $type = $self->_valid_type(delete($opts{type}));
    my $query = delete($opts{query});
    my $orderby = delete($opts{orderby});

    my $r = $self->_submit("search/$type", {
        query => $query,
        (defined($orderby) ? (orderby => $orderby) : ()),
    });

    return $r->content =~ m/^(\d+):/gm;
}

sub edit {
    my $self = shift;
    $self->_assert_even(@_);
    my %opts = @_;

    my $type = $self->_valid_type(delete($opts{type}));

    my $id = delete($opts{id});
    unless ('new' eq $id) {
        $id = $self->_valid_numeric_object_id($id);
    }

    my %set;
    if (defined(my $set = delete($opts{set}))) {
        while (my ($k, $v) = each(%$set)) {
            vpush(\%set, lc($k), $v);
        }
    }
    $set{id} = "$type/$id";

    my $r = $self->_submit('edit', {
        content => form_compose([['', [keys %set], \%set]])
    });

    # This seems to be a bug on the server side: returning 200 Ok when
    # ticket creation (for instance) fails.  We check it here:
    if ($r->content =~ /not/) {
        RT::Client::REST::Exception->_rt_content_to_exception($r->content)
        ->throw(
            code    => $r->code,
            message => "RT server returned this error: " .  $r->content,
        );
    }

    if ($r->content =~ /^#[^\d]+(\d+) (?:created|updated)/) {
        return $1;
    } else {
        RT::Client::REST::MalformedRTResponseException->throw(
            message => "Cound not read ID of the modified object",
        );
    }
}

sub create { shift->edit(@_, id => 'new') }

sub comment {
    my $self = shift;
    $self->_assert_even(@_);
    my %opts = @_;
    my $action = $self->_valid_comment_action(
        delete($opts{comment_action}) || 'comment');
    my $ticket_id = $self->_valid_numeric_object_id(delete($opts{ticket_id}));
    my $msg = $self->_valid_comment_message(delete($opts{message}));

    my @objects = ("Ticket", "Action", "Text");
    my %values  = (
        Ticket      => $ticket_id,
        Action      => $action,
        Text        => $msg,
    );

    if (exists($opts{cc})) {
        push @objects, "Cc";
        $values{Cc} = delete($opts{cc});
    }

    if (exists($opts{bcc})) {
        push @objects, "Bcc";
        $values{Bcc} = delete($opts{bcc});
    }

    my $text = form_compose([[ '', \@objects, \%values, ]]);

    $self->_submit("ticket/$ticket_id/comment", {
        content => $text,
    });

    return;
}

sub correspond { shift->comment(@_, comment_action => 'correspond') }

sub merge_tickets {
    my $self = shift;
    $self->_assert_even(@_);
    my %opts = @_;
    my ($src, $dst) = map { $self->_valid_numeric_object_id($_) }
        @opts{qw(src dst)};
    $self->_submit("ticket/merge/$src", { into => $dst});
    return;
}

sub link_tickets {
    my $self = shift;
    $self->_assert_even(@_);
    my %opts = @_;
    my ($src, $dst) = map { $self->_valid_numeric_object_id($_) }
        @opts{qw(src dst)};
    my $ltype = $self->_valid_link_type(delete($opts{link_type}));
    my $del = (exists($opts{'unlink'}) ? 1 : '');

    $self->_submit("ticket/link", {
        id  => $src,
        rel => $ltype,
        to  => $dst,
        del => $del,
    });

    return;
}

sub unlink_tickets { shift->link_tickets(@_, unlink => 1) }

sub _ticket_action {
    my $self = shift;

    $self->_assert_even(@_);

    my %opts = @_;

    my $id = delete $opts{id};
    my $action = delete $opts{action};

    my $text = form_compose([[ '', ['Action'], { Action => $action }, ]]);

    my $form = form_parse(
        $self->_submit("/ticket/$id/take", { content => $text })->content
    );
    my ($c, $o, $k, $e) = @{$$form[0]};

    if ($e) {
        RT::Client::REST::Exception->_rt_content_to_exception($c)->throw;
    }
}

sub take { shift->_ticket_action(@_, action => 'take') }
sub untake { shift->_ticket_action(@_, action => 'untake') }
sub steal { shift->_ticket_action(@_, action => 'steal') }

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
            } else {
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

# Not a constant so that it can be overridden.
sub _list_of_valid_transaction_types {
    sort +(qw(
        Create Set Status Correspond Comment Give Steal Take Told
        CustomField AddLink DeleteLink AddWatcher DelWatcher EmailRecord
    ));
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

sub _valid_numeric_object_id {
    my ($self, $id) = @_;

    unless ($id =~ m/^\d+$/) {
        RT::Client::REST::InvalidParameterValueException->throw(
            "'$id' is not a valid numeric object ID",
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

sub _valid_transaction_type {
    my ($self, $type) = @_;

    unless (grep { $type eq $_ } $self->_list_of_valid_transaction_types) {
        RT::Client::REST::InvalidParameterValueException->throw(
            "'$type' is not a valid transaction type.  Allowed types: " .
            join(", ", $self->_list_of_valid_transaction_types)
        );
    }

    return $type;
}

sub _assert_even {
    shift;
    RT::Client::REST::OddNumberOfArgumentsException->throw(
        "odd number of arguments passed") if @_ & 1;
}

sub _rest {
    my $self = shift;
    my $server = $self->server;

    unless (defined($server)) {
        RT::Client::REST::RequiredAttributeUnsetException->throw(
            "'server' attribute is not set",
        );
    }

    return $server . '/REST/1.0';
}

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
    # Get ticket #10
    $ticket = $rt->show(type => 'ticket', id => 10);
  } catch RT::Client::REST::Exception with {
    # something went wrong.
  };

=head1 DESCRIPTION

B<RT::Client::REST> is B</usr/bin/rt> converted to a Perl module.  I needed
to implement some RT interactions from my application, but did not feel that
invoking a shell command is appropriate.  Thus, I took B<rt> tool, written
by Abhijit Menon-Sen, and converted it to an object-oriented Perl module.

B<RT::Client::REST> does not (at the moment, see TODO file) retrieve forms from
RT server, which is either good or bad, depending how you look at it.  More
work on this module will be performed in the future as I get a better grip
of this whole REST business.

=head1 USAGE NOTES

This API mimics that of 'rt'.  For a more OO-style APIs, please use
L<RT::Client::REST::Object>-derived classes:
L<RT::Client::REST::Ticket> and L<RT::Client::REST::User> (the latter is
not implemented yet).

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

=item show (type => $type, id => $id)

Return a reference to a hash with key-value pair specifying object C<$id>
of type C<$type>.

=item edit (type => $type, id => $id, set => { status => 1 })

Set fields specified in parameter B<set> in object C<$id> of type
C<$type>.

=item create (type => $type, set => \%params)

Create a new object of type B<$type> and set initial parameters to B<%params>.
Returns numeric ID of the new object.  If numeric ID cannot be parsed from
the response, B<RT::Client::REST::MalformedRTResponseException> is thrown.

=item search (type => $type, query => $query, %opts)

Search for object of type C<$type> by using query C<$query>.  For
example:

  # Find all stalled tickets
  my @ids = $rt->search(
    type => 'ticket',
    query => "Status = 'stalled'",
  );

C<%opts> is a list of key-value pairs:

=over 4

=item B<orderby>

The value is the name of the field you want to sort by.  Plus or minus
sign in front of it signifies ascending order (plus) or descending
order (minus).  For example:

  # Get all stalled tickets in reverse order:
  my @ids = $rt->search(
    type => 'ticket',
    query => "Status = 'stalled'",
    orderby => '-id',
  );

=back

C<search> returns the list of numeric IDs of objects that matched
your query.  You can then use these to retrieve object information
using C<show()> method:

  my @ids = $rt->search(
    type => 'ticket',
    query => "Status = 'stalled'",
  );
  for my $id (@ids) {
    my ($ticket) = $rt->show(type => 'ticket', ids => [$id]);
    print "Subject: ", $t->{Subject}, "\n";
  }

=item comment (ticket_id => $id, message => $message, %opts)

Comment on a ticket with ID B<$id>.
Optionally takes arguments B<cc> and B<bcc> which are references to lists
of e-mail addresses:

  $rt->comment(
    ticket_id   => 5,
    message     => "Wild thing, you make my heart sing",
    cc          => [qw(dmitri@localhost some@otherdude.com)],
  );

=item correspond (ticket_id => $id, message => $message, %opts)

Add correspondence to ticket ID B<$id>.  Takes optional B<cc> and
B<bcc> parameters (see C<comment> above).

=item get_attachment_ids (id => $id)

Get a list of numeric attachment IDs associated with ticket C<$id>.

=item get_attachment (parent_id => $parent_id, id => $id)

Returns reference to a hash with key-value pair describing attachment
C<$id> of ticket C<$parent_id>.  (parent_id because -- who knows? --
maybe attachments won't be just for tickets anymore in the future).

=item get_transaction_ids (parent_id => $id, %opts)

Get a list of numeric IDs associated with parent ID C<$id>.  C<%opts>
have the following options:

=over 2

=item B<type>

Type of the object transactions are associated wtih.  Defaults to "ticket"
(I do not think server-side supports anything else).  This is designed with
the eye on the future, as transactions are not just for tickets, but for
other objects as well.

=item B<transaction_type>

If not specified, IDs of all transactions are returned.  If set to a
scalar, only transactions of that type are returned.  If you want to specify
more than one type, pass an array reference.

Transactions may be of the following types (case-sensitive):

=over 2

=item AddLink

=item AddWatcher

=item Comment

=item Correspond

=item Create

=item CustomField

=item DeleteLink

=item DelWatcher

=item EmailRecord

=item Give

=item Set

=item Status

=item Steal

=item Take

=item Told

=back

=back

=item get_transaction (parent_id => $id, id => $id, %opts)

Get a hashref representation of transaction C<$id> associated with
parent object C<$id>.  You can optionally specify parent object type in
C<%opts> (defaults to 'ticket').

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

=item take (id => $id)

Take ticket C<$id>.
This will throw C<RT::Client::REST::AlreadyTicketOwnerException> if you are
already the ticket owner.

=item untake (id => $id)

Untake ticket C<$id>.
This will throw C<RT::Client::REST::AlreadyTicketOwnerException> if Nobody
is already the ticket owner.

=item steal (id => $id)

Steal ticket C<$id>.
This will throw C<RT::Client::REST::AlreadyTicketOwnerException> if you are
already the ticket owner.

=back

=head1 EXCEPTIONS

When an error occurs, this module will throw exceptions.  I recommend
using Error.pm's B<try{}> mechanism to catch them, but you may also use
simple B<eval{}>.  The former will give you flexibility to catch just the
exceptions you want.

Please see L<RT::Client::REST::Exception> for the full listing and
description of all the exceptions.

=head1 LIMITATIONS

Beginning with version 0.14, methods C<edit()> and C<show()> only support
operating on a single object.  This is a conscious departure from semantics
offered by the original tool, as I would like to have a precise behavior
for exceptions.  If you want to operate on a whole bunch of objects, please
use a loop.

=head1 DEPENDENCIES

The following modules are required:

=over 2

=item

Error

=item

Exception::Class

=item

LWP

=item

HTTP::Cookies

=item

HTTP::Request::Common

=back

=head1 SEE ALSO

L<RT::Client::REST::Exception>

=head1 BUGS

Most likely.  Please report.

=head1 VERSION

This is version 0.18 of B<RT::Client::REST>.

=head1 AUTHORS

Original /usr/bin/rt was written by Abhijit Menon-Sen <ams@wiw.org>.  rt
was later converted to this module by Dmitri Tikhonov <dtikhonov@vonage.com>

=head1 LICENSE

Since original rt is licensed under GPL, so is this module.

=cut
