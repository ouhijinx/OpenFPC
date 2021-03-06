#!/usr/bin/perl
#
#  Copyright (C) 2010, Edward Fjellskaal (edwardfjellskaal@gmail.com)
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#

# TODO:
#  * Read mysql settings from openfpc.conf (User/Pass ++)
#  * Implemet IPv4, IPv6, and "both" search.
#  * Implement negotiation (!) in searches.

use strict;
use warnings;
use Date::Simple ('date', 'today');
use Getopt::Long qw/:config auto_version auto_help/;
use DBI;

our $DEBUG         = 0;

# Hard-coded DB user,password and host to connect to...
my $db_host      = 'localhost';
my $db_user_name = 'openfpc';
my $db_password  = 'openfpc';
my $db_name      = 'openfpc';
my $db_table     = 'session';
my $DLIMIT       = 100;

# Read in the openfpc config file and override the default hard-coded values if specified.
# -Leon

my $CONFFILE = '/etc/openfpc/openfpc-default.conf';
my %CONFIG         = ();

if ($CONFFILE) {
   warn "[*] Reading config file: $CONFFILE\n" if ($DEBUG);
   open my $LINES, '<', $CONFFILE or die "Unable to open config file $CONFFILE $!";
   while(<$LINES>) {
       chomp;
       if ( $_ =~ m/^[a-zA-Z]/) {
           (my $key, my @value) = split /=/, $_;
           $CONFIG{$key} = join '=', @value;
       }
   }

   $db_name = $CONFIG{'SESSION_DB_NAME'} if (defined $CONFIG{'SESSION_DB_NAME'});
   $db_user_name = $CONFIG{'SESSION_DB_USER'} if (defined $CONFIG{'SESSION_DB_USER'});
   $db_password = $CONFIG{'SESSION_DB_PASS'} if (defined $CONFIG{'SESSION_DB_PASS'});

   close $LINES;

} else {
   warn "[-] No config file specified. Using defaults.\n" if ($DEBUG);
}

=head1 NAME

    ofpc-cxsearch.pl - Search cxtracker data for sessions

=head1 VERSION

    0.1

=head1 SYNOPSIS

$ ofpc-cxsearch.pl [options]

  OPTIONS:

    --ipv         : IP Version (4,6 or 10) # Only IPv4 implemented for now!
    --src_ip      : Source IP
    --src_port    : Source Port
    --dst_ip      : Destination IP
    --dst_port    : Destination Port
    --proto       : Protocol
    --from-date   : Date to search from in iso format (2010-01-01 etc.)
    --to-date     : Date to search to in iso format (2020-01-01 etc.)
    --limit       : Limit on search results

=cut

our $IPV;
our $SRC_IP;
our $SRC_PORT;
our $DST_IP;
our $DST_PORT;
our $PROTO;
our $FROM_DATE;
our $TO_DATE;
our $LIMIT;

GetOptions(
    'ipv=s'         => \$IPV,
    'src_ip|sip=s'      => \$SRC_IP,
    'src_port|spt=s'    => \$SRC_PORT,
    'dst_ip|dip=s'      => \$DST_IP,
    'dst_port|dpt=s'    => \$DST_PORT,
    'proto=s'       => \$PROTO,
    'from-date|stime=s'   => \$FROM_DATE,
    'to-date|etime=s'     => \$TO_DATE,
    'limit=s'       => \$LIMIT,
);


my $dsn = 'DBI:mysql:' . $db_name . ":" . $db_host;
my $dbh = DBI->connect($dsn, $db_user_name, $db_password);
my $today = today();
my $weekago = $today - 7;
my $yesterday = $today->prev;

=head1 FUNCTIONS

=head2 tftoa

    Takes decimal representation of TCP flags,
    and returns ascii defined values.

=cut

sub tftoa {
    my $Flags = shift;
    my $out = "";

    $out .= "S" if ( $Flags & 0x02 );
    $out .= "A" if ( $Flags & 0x10 );
    $out .= "P" if ( $Flags & 0x08 );
    $out .= "U" if ( $Flags & 0x20 );
    $out .= "E" if ( $Flags & 0x40 );
    $out .= "C" if ( $Flags & 0x80 );
    $out .= "F" if ( $Flags & 0x01 );
    $out .= "R" if ( $Flags & 0x04 );

    return "-" if $out eq "";
    return $out;
}

our $QUERY = q();
$QUERY = qq[SELECT start_time,INET_NTOA(src_ip),src_port,INET_NTOA(dst_ip),dst_port,ip_proto,src_flags,dst_flags FROM $db_table IGNORE INDEX (p_key) WHERE ];

if (defined $FROM_DATE && $FROM_DATE =~ /^\d\d\d\d\-\d\d\-\d\d$/) {
    print "Searching from date: $FROM_DATE 00:00:01\n" if $DEBUG;
    $QUERY = $QUERY . qq[$db_table.start_time > '$FROM_DATE 00:00:01' ];
} else {
    print "Searching from date: $yesterday\n" if $DEBUG;
    $QUERY = $QUERY . qq[$db_table.start_time > '$yesterday' ];
}

if (defined $TO_DATE && $TO_DATE =~ /^\d\d\d\d\-\d\d\-\d\d$/) {
    print "Searching to date: $TO_DATE 23:59:59\n" if $DEBUG;
    $QUERY = $QUERY . qq[AND $db_table.end_time < '$TO_DATE 23:59:59' ];
}

if (defined $SRC_IP && $SRC_IP =~ /^([\d]{1,3}\.){3}[\d]{1,3}$/) {
    print "Source IP is: $SRC_IP\n" if $DEBUG;
    $QUERY = $QUERY . qq[AND INET_NTOA($db_table.src_ip)='$SRC_IP' ];
}

if (defined $SRC_PORT && $SRC_PORT =~ /^([\d]){1,5}$/) {
    print "Source Port is: $SRC_PORT\n" if $DEBUG;
    $QUERY = $QUERY . qq[AND $db_table.src_port='$SRC_PORT' ];
}

if (defined $DST_IP && $DST_IP =~ /^([\d]{1,3}\.){3}[\d]{1,3}$/) {
    print "Destination IP is: $DST_IP\n" if $DEBUG;
    $QUERY = $QUERY . qq[AND INET_NTOA($db_table.dst_ip)='$DST_IP' ];
}

if (defined $DST_PORT && $DST_PORT =~ /^([\d]){1,5}$/) {
    print "Destination Port is: $DST_PORT\n" if $DEBUG;
    $QUERY = $QUERY . qq[AND $db_table.dst_port='$DST_PORT' ];
}

if (defined $PROTO && $PROTO =~ /^([\d]){1,3}$/) {
    print "Protocol is: $PROTO\n" if $DEBUG;
    $QUERY = $QUERY . qq[AND $db_table.ip_proto='$PROTO' ];
}

if (defined $LIMIT && $LIMIT =~ /^([\d])+$/) {
    print "Limit: $LIMIT\n" if $DEBUG;
    $QUERY = $QUERY . qq[ORDER BY $db_table.start_time LIMIT $LIMIT ];
} else {
    print "Limit: $DLIMIT\n" if $DEBUG;
    $QUERY = $QUERY . qq[ORDER BY $db_table.start_time LIMIT $DLIMIT ];
}

print "\n # Copyright (C) 2010, Edward Fjellskål (edwardfjellskaal\@gmail.com)\n\n";
print "\nmysql> $QUERY;\n\n" if $DEBUG;
print "  StartTime         src_ip    :s_port ->      dst_ip    :d_port (Proto) [Flags]\n";
print "--------------------------------------------------------------------------------\n";

my $pri = $dbh->prepare( qq{ $QUERY } ); 
$pri->execute();

while (my ($starttime,$src_ip,$src_port,$dst_ip,$dst_port,$proto,$src_flags,$dst_flags) = $pri->fetchrow_array()) {
    next if not defined $src_ip or not defined $dst_ip;
    my $SFlags = tftoa($src_flags);
    my $DFlags = tftoa($dst_flags);
    printf("%s % 15s:%-5s  -> % 15s:%-5s  (%3s)   [%s|%s]\n",$starttime,$src_ip,$src_port,$dst_ip,$dst_port,$proto,$SFlags,$DFlags);
}

print "\n";

$pri->finish();
$dbh->disconnect();

=head1 AUTHOR

    Edward Fjellskaal (edwardfjellskaal@gmail.com)

=head1 COPYRIGHT

    Copyright (C) 2010, Edward Fjellskaal (edwardfjellskaal@gmail.com)

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

=cut
