#!/usr/bin/perl
#
# edit_ticket.pl -- edit an RT ticket.

use strict;
use warnings;

use RT::Client::REST;
use RT::Client::REST::Ticket;

unless (@ARGV >= 3) {
    die "Usage: $0 username password ticket_id attribute value1, value2..\n";
}

my $rt = RT::Client::REST->new(
    server  => ($ENV{RTSERVER} || 'http://rt.cpan.org'),
    username=> shift(@ARGV),
    password=> shift(@ARGV),
);

my ($id, $attr, @vals) = @ARGV;
my $ticket = RT::Client::REST::Ticket->new(
    rt  => $rt,
    id  => $id,
    $attr, 1 == @vals ? @vals : \@vals,
)->store;

use Data::Dumper;
print Dumper($ticket);
