#!/usr/bin/perl
#
# show_ticket.pl -- retrieve an RT ticket.

use strict;
use warnings;

use RT::Client::REST;
use RT::Client::REST::Ticket;

unless (@ARGV >= 3) {
    die "Usage: $0 username password ticket_id\n";
}

my $rt = RT::Client::REST->new(
    server  => 'http://rt.cpan.org',
    username=> shift(@ARGV),
    password=> shift(@ARGV),
);

my $ticket = RT::Client::REST::Ticket->new(
    rt  => $rt,
    id  => shift(@ARGV),
)->retrieve;

use Data::Dumper;
print Dumper($ticket);
