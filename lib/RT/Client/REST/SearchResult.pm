# $Id$
#
# RT::Client::REST::SearchResult -- search results object.

package RT::Client::REST::SearchResult;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = 0.01;

sub new {
    my $class = shift;

    my %opts = @_;

    my $self = bless {}, ref($class) || $class;

    # FIXME: add validation.
    $self->{_rt} = $opts{rt};
    $self->{_type} = $opts{type};
    $self->{_ids} = $opts{ids} || [];

    return $self;
}

sub count { scalar(@{shift->{_ids}}) }

sub get_iterator {
    my $self = shift;
    my @ids = @{$self->{_ids}};
    my $type = $self->{_type};
    my $rt = $self->{_rt};

    return sub {
        if (wantarray) {
            my @tomap = @ids;
            @ids = ();

            return map {
                $type->new(
                    id => $_,
                    rt => $rt,
                )->retrieve
            } @tomap;
        } elsif (@ids) {
            my $object = $type->new(
                id => shift(@ids),
                rt => $rt,
            )->retrieve;
            return $object;
        } else {
            return;     # This signifies the end of the iterations
        }
    };
}

1;

__END__

=head1 NAME

RT::Client::REST::SearchResult -- Search results representation.

=head1 SYNOPSIS

  my $iterator = $search->get_iterator;
  my $count = $iterator->count;

  while (defined(my $obj = &$iterator)) {
    # do something with the $obj
  }

=head1 DESCRIPTION

This class is a representation of a search result.  This is the type
of the object you get back when you call method C<search()> on
L<RT::Client::REST::Object>-derived objects.  It makes it easy to
iterate over results and find out just how many there are.

=head1 METHODS

=over 4

=item B<count>

Returns the number of search results.  This number will always be the
same unless you stick your fat dirty fingers into the object and abuse
it.  This number is not affected by calls to C<get_iterator()>.

=item B<get_iterator>

Returns a reference to a subroutine which is used to iterate over the
results.

Evaluating it in scalar context, returns the next object
or C<undef> if all the results have already been iterated over.  Note
that for each object to be instantiated with correct values,
B<retrieve()> method is called on the object before returning it
to the caller.

Evaluating the subroutine reference in list context returns a list
of all results fully instantiated.  WARNING: this may be expensive,
as each object is issued B<retrieve()> method.  Subsequent calls to
the iterator result in empty list.

You may safely mix calling the iterator in scalar and list context.  For
example:

  $iterator = $search->get_iterator;

  $first = &$iterator;
  $second = &$iterator;
  @the_rest = &$iterator;

You can get as many iterators as you want -- they will not step on
each other's toes.

=item B<new>

You should not have to call it yourself, but just for the sake of
completeness, here are the arguments:

  my $search = RT::Client::REST::SearchResult->new(
    ids => [1 .. 10],
    type => 'RT::Client::REST::Ticket,
    rt => RT::Client::REST->new(%opts),
  );

=back

=head1 SEE ALSO

L<RT::Client::REST::Object>, L<RT::Client::REST>.

=head1 AUTHOR

Dmitri Tikhonov <dtikhonov@yahoo.com>

=cut
