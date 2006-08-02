# $Id: Object.pm 77 2006-08-02 17:31:16Z dtikhonov $

package RT::Client::REST::Object;

=head1 NAME

RT::Client::REST::Object -- base class for RT objects.

=head1 SYNOPSIS

  # Create a new type
  package RT::Client::REST::MyType;

  use base qw(RT::Client::REST::Object);

  sub _attributes {{
    myattribute => {
      validation => {
        type => SCALAR,
      },
    },
  }}

  sub rt_type { "mytype" }

  1;

=head1 DESCRIPTION

The RT::Client::REST::Object module is a superclass providing a whole
bunch of class and object methods in order to streamline the development
of RT's REST client interface.

=head1 METHODS

=over 2

=cut

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = 0.03;

use Error qw(:try);
use Params::Validate;
use RT::Client::REST::Object::Exception 0.04;
use RT::Client::REST::SearchResult 0.02;

=item new

Constructor

=cut

sub new {
    my $class = shift;

    if (@_ & 1) {
        RT::Client::REST::Object::OddNumberOfArgumentsException->throw;
    }

    my $self = bless {}, ref($class) || $class;
    my %opts = @_;

    while (my ($k, $v) = each(%opts)) {
        $self->$k($v);
    }

    return $self;
}

=item _generate_methods

This class method generates accessors and mutators based on
B<_attributes> method which your class should provide.  For items
that are lists, 'add_' and 'delete_' methods are created.  For instance,
the following two attributes specified in B<_attributes> will generate
methods 'creator', 'cc', 'add_cc', and 'delete_cc':

  creator => {
    validation => { type => SCALAR },
  },
  cc => {
    list => 1,
    validation => { type => ARRAYREF },
  },

Note that accessors/mutators working with 'list' attributes accept
and return array references, whereas convenience methods 'add_*' and
'delete_*' accept lists of items.

=cut

sub _generate_methods {
    my $class = shift;
    my $attributes = $class->_attributes;

    while (my ($method, $settings) = each(%$attributes)) {
        no strict 'refs';

        *{$class . '::' . $method} = sub {
            my $self = shift;

            if (@_) {
                if ($settings->{validation}) {
                    my @v = @_;
                    Params::Validate::validation_options(
                        on_fail => sub {
                            no warnings 'uninitialized';
                            RT::Client::REST::Object::InvalidValueException
                            ->throw(
                            "'@v' is not a valid value for attribute '$method'"
                            );
                        },
                    );
                    validate_pos(@_, $settings->{validation});
                }
                $self->{'_' . $method} = shift;
                $self->_mark_dirty($method);
            }

            return $self->{'_' . $method};
        };

        if ($settings->{list}) {
            # Generate convenience methods for list manipulation.
            my $add_method = $class . '::add_' . $method;
            my $delete_method = $class . '::delete_' . $method;

            *$add_method = sub {
                my $self = shift;

                unless (@_) {
                    RT::Client::REST::Object::NoValuesProvidedException
                        ->throw;
                }

                my $values = $self->$method || [];
                my %values = map { $_, 1 } @$values;

                # Now add new values
                for (@_) {
                    $values{$_} = 1;
                }

                $self->$method([keys %values]);
            };

            *$delete_method = sub {
                my $self = shift;

                unless (@_) {
                    RT::Client::REST::Object::NoValuesProvidedException
                        ->throw;
                }

                my $values = $self->$method || [];
                my %values = map { $_, 1 } @$values;

                # Now delete values
                for (@_) {
                    delete $values{$_};
                }

                $self->$method([keys %values]);
            };
        }
    }
}

=item _mark_dirty($attrname)

Mark an attribute as dirty.

=cut

sub _mark_dirty {
    my ($self, $attr) = @_;
    $self->{__dirty}{$attr} = 1;
}

=item _dirty

Return the list of dirty attributes.

=cut

sub _dirty {
    my $self = shift;

    if (exists($self->{__dirty})) {
        return keys %{$self->{__dirty}};
    }

    return;
}

=item to_form($all)

Convert the object to 'form' (used by REST protocol).  This is done based
on B<_attributes> method.  If C<$all> is true, create a form from all of
the object's attributes, otherwise use only dirty (see B<_dirty> method)
attributes.  Defaults to the latter.

=cut

sub to_form {
    my ($self, $all) = @_;
    my $attributes = $self->_attributes;

    my @attrs = ($all ? keys(%$attributes) : $self->_dirty);

    my %hash;

    for my $attr (@attrs) {
        my $rest_name = (exists($attributes->{$attr}{rest_name}) ?
                         $attributes->{$attr}{rest_name} : ucfirst($attr));
        my $value = $self->$attr;
        if (exists($attributes->{$attr}{value2form})) {
            $value = $attributes->{$attr}{value2form}($value);
        } elsif ($attributes->{$attr}{list}) {
            $value = join(',', @$value);
        }
        $hash{$rest_name} = $value;
    }

    for my $cf ($self->cf) {
        $hash{'CF-' . $cf} = $self->cf($cf);
    }

    return \%hash;
}

=item from_form

Set object's attributes from form received from RT server.

=cut

sub from_form {
    my $self = shift;
    
    unless (@_) {
        RT::Client::REST::Object::NoValuesProvidedException->throw;
    }

    my $hash = shift;

    unless ('HASH' eq ref($hash)) {
        RT::Client::REST::Object::InvalidValueException->throw(
            "Expecting a hash reference as argument to 'from_form'",
        );
    }

    # lowercase hash keys
    my $i = 0;
    $hash = { map { ($i++ & 1) ? $_ : lc } %$hash };

    my $attributes = $self->_attributes;
    my %rest2attr;  # Mapping of REST names to our attributes;
    while (my ($attr, $value) = each(%$attributes)) {
        my $rest_name = (exists($attributes->{$attr}{rest_name}) ?
                         lc($attributes->{$attr}{rest_name}) : $attr);
        $rest2attr{$rest_name} = $attr;
    }

    # Now set attbibutes:
    while (my ($key, $value) = each(%$hash)) {
        if ($key =~ s/^cf-//) { # Handle custom fields.
            if ($value =~ /,/) {    # OK, this is questionable.
                $value = [ split(/,/, $value) ];
            }

            $self->cf($key, $value);
            next;
        }

        unless (exists($rest2attr{$key})) {
            warn "Unknown key: $key\n";
            next;
        }

        if ($value =~ m/not set/i) {
            $value = undef;
        }

        my $method = $rest2attr{$key};
        if (exists($attributes->{$method}{form2value})) {
            $value = $attributes->{$method}{form2value}($value);
        } elsif ($attributes->{$method}{list}) {
            $value = [split(/,/, $value)],
        }
        $self->$method($value);
    }

    return;
}

sub retrieve {
    my $self = shift;

    $self->_assert_rt_and_id;

    my $rt = $self->rt;

    my ($hash) = $rt->show(type => $self->rt_type, id => $self->id);
    $self->from_form($hash);

    $self->{__dirty} = {};

    return $self;
}

sub store {
    my $self = shift;

    $self->_assert_rt;

    my $rt = $self->rt;

    if (defined($self->id)) {
        $rt->edit(
            type    => $self->rt_type,
            id      => $self->id,
            set     => $self->to_form,
        );
    } else {
        my $id = $rt->create(
            type    => $self->rt_type,
            set     => $self->to_form,
        );
        $self->id($id);
    }

    $self->{__dirty} = {};

    return $self;
}

sub search {
    my $self = shift;

    if (@_ & 1) {
        RT::Client::REST::Object::OddNumberOfArgumentsException->throw;
    }

    $self->_assert_rt;

    my %opts = @_;

    my $limits = delete($opts{limits}) || [];
    my $query = '';

    for my $limit (@$limits) {
        my $kw;
        try {
            $kw = $self->_attr2keyword($limit->{attribute});
        } catch RT::Clite::REST::Object::InvalidAttributeException with {
            RT::Client::REST::Object::InvalidSearchParametersException
                ->throw(shift->message);
        };
        my $op = $limit->{operator};
        my $val = $limit->{value};
        my $agg = $limit->{aggregator} || 'and';

        if (length($query)) {
            $query = "($query) $agg $kw $op '$val'";
        } else {
            $query = "$kw $op '$val'";
        }
    }

    my $orderby;
    try {
        # Defaults to 'id' at the moment.  Do not rely on this --
        # implementation may change!
        $orderby = (delete($opts{reverseorder}) ? '-' : '+') .
            ($self->_attr2keyword(delete($opts{orderby}) || 'id'));
    } catch RT::Clite::REST::Object::InvalidAttributeException with {
        RT::Client::REST::Object::InvalidSearchParametersException->throw(
            shift->message,
        );
    };

    my $rt = $self->rt;
    my @results;
    try {
        @results = $rt->search(
            type => $self->rt_type,
            query => $query,
            orderby => $orderby,
        );
    } catch RT::Client::REST::InvalidQueryException with {
        RT::Client::REST::Object::InvalidSearchParametersException->throw;
    };

    return RT::Client::REST::SearchResult->new(
        ids => \@results,
        retrieve => sub {
            return $self->new(
                id => shift,
                rt => $rt,
            )->retrieve,
        },
    );
}

sub count {
    my $self = shift;
    $self->_assert_rt;
    return $self->search(@_)->count;
}

sub _attr2keyword {
    my ($self, $attr) = @_;
    my $attributes = $self->_attributes;

    unless (exists($attributes->{$attr})) {
        no warnings 'uninitialized';
        RT::Clite::REST::Object::InvalidAttributeException->throw(
            "Attribute '$attr' does not exist in object type '" .
                ref($self) . "'"
        );
    }

    return (exists($attributes->{$attr}{rest_name}) ?
            $attributes->{$attr}{rest_name} :
            ucfirst($attr));
}

sub _assert_rt_and_id {
    my $self = shift;
    my $method = shift || (caller(1))[3];

    unless (defined($self->rt)) {
        RT::Client::REST::Object::RequiredAttributeUnsetException
            ->throw("Cannot '$method': 'rt' attribute of the object ".
                    "is not set");
    }

    unless (defined($self->id)) {
        RT::Client::REST::Object::RequiredAttributeUnsetException
            ->throw("Cannot '$method': 'id' attribute of the object ".
                    "is not set");
    }
}

sub _assert_rt {
    my $self = shift;
    my $method = shift || (caller(1))[3];

    unless (defined($self->rt)) {
        RT::Client::REST::Object::RequiredAttributeUnsetException
            ->throw("Cannot '$method': 'rt' attribute of the object ".
                    "is not set");
    }
}

=item param($name, $value)

Set an arbitrary parameter.

=cut

sub param {
    my $self = shift;

    unless (@_) {
        RT::Client::REST::Object::NoValuesProvidedException->throw;
    }

    my $name = shift;

    if (@_) {
        $self->{__param}{$name} = shift;
    }

    return $self->{__param}{$name};
}

=item cf([$name, [$value]])

Given no arguments, returns the list of custom field names.  With
one argument, returns the value of custom field C<$name>.  With two
arguments, sets custom field C<$name> to C<$value>.

=cut

sub cf {
    my $self = shift;

    unless (@_) {
        # Return a list of CFs.
        return keys %{$self->{__cf}};
    }

    my $name = lc shift;

    if (@_) {
        $self->{__cf}{$name} = shift;
    }

    return $self->{__cf}{$name};
}

=item rt

Get or set the 'rt' object, which should be of type L<RT::Client::REST>.

=cut

sub rt {
    my $self = shift;

    if (@_) {
        my $rt = shift;
        unless (UNIVERSAL::isa($rt, 'RT::Client::REST')) {
            RT::Client::REST::Object::InvalidValueException->throw;

        }
        $self->{__rt} = $rt;
    }

    return $self->{__rt};
}

=back

=head1 DB METHODS

The following are methods that have to do with reading, creating, updating,
and searching objects.

=over 2

=item count

Takes the same arguments as C<search()> but returns the actual count of
the found items.  Throws the same exceptions.

=item retrieve

Retrieve object's attributes.  Note that 'id' attribute must be set for this
to work.

=item search (%opts)

This method is used for searching objects.  It returns an object of type
L<RT::Client::REST::SearchResult>, which can then be used to process
results.  C<%opts> is a list of key-value pairs, which are as follows:

=over 2

=item limits

This is a reference to array containing hash references with limits to
apply to the search (think SQL limits).

=item orderby

Specifies attribute to sort the result by (in ascending order).

=item reverseorder

If set to a true value, sorts by attribute specified by B<orderby> in
descending order.

=back

If the client cannot construct the query from the specified arguments,
or if the server cannot make it out,
C<RT::Client::REST::Object::InvalidSearchParametersException> is thrown.

=item store

Store the object.  If 'id' is set, this is an update; otherwise, a new
object is created and the 'id' attribute is set.  Note that only changed
(dirty) attributes are sent to the server.

=cut

=back

=head1 SEE ALSO

L<RT::Client::REST::Ticket>,
L<RT::Client::REST::SearchResult>.

=head1 AUTHOR

Dmitri Tikhonov <dtikhonov@yahoo.com>

=cut

1;
