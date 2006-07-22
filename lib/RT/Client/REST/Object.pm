# $Id: Object.pm 4 2006-07-22 21:02:27Z dmitri $

package RT::Client::REST::Object;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = 0.01;

use Params::Validate;
use RT::Client::REST::Object::Exception 0.01;

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
                            RT::Client::REST::Object::InvalidValueException
                            ->throw(
                            "@v is not a valid value for attribute '$method'"
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

# Mark an attribute as dirty.
sub _mark_dirty {
    my ($self, $attr) = @_;
    $self->{__dirty}{$attr} = 1;
}

# Return the list of dirty attributes.
sub _dirty {
    my $self = shift;

    if (exists($self->{__dirty})) {
        return keys %{$self->{__dirty}};
    }

    return;
}

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

    return \%hash;
}

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
        next if $key =~ /^cf-/; # Custom fields are not yet supported.
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
    my $rt = $self->rt;

    unless (defined($self->id)) {
        RT::Client::REST::Object::InvalidValueException->throw(
            "'" . ref($self) . "' must have 'id' in order to retrieve it",
        );
    }

    my ($hash) = $rt->show(type => $self->rt_type, objects => [$self->id]);
    $self->from_form($hash);

    $self->{__dirty} = {};

    return $self;
}

sub store {
    my $self = shift;

    my $rt = $self->rt;

    if (defined($self->id)) {
        $rt->edit(
            type    => $self->rt_type,
            objects => [ $self->id ],
            set     => $self->to_form,
        );
    } else {
        $rt->create(
            type    => $self->rt_type,
            set     => $self->to_form,
        );
    }

    $self->{__dirty} = {};

    return $self;
}

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

1;
