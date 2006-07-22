#!/usr/bin/perl
#
# edit_ticket.pl -- edit an RT ticket.

use strict;
use warnings;

use RT::Client::REST;
use RT::Client::REST::Ticket;

unless (@ARGV >= 3) {
    die "Usage: $0 username password ticket_id [key-value pairs]\n";
}

my $rt = RT::Client::REST->new(
    server  => 'http://rt.cpan.org',
    username=> shift(@ARGV),
    password=> shift(@ARGV),
);

my $ticket = RT::Client::REST::Ticket->new(
    rt  => $rt,
    id  => shift(@ARGV),
    @ARGV,
)->store;

use Data::Dumper;
print Dumper($ticket);
