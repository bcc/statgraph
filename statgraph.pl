#!/usr/bin/perl

# statgraph: A simple host resource graphing tool
# Copyright (C) 2004-2011  Ben Charlton <ben@spod.cx>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; see the file COPYING. If not, write to the Free 
# Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, 
# MA 02110-1301 USA, or see http://www.gnu.org

use strict;
use StatGraph;

## TODO: configure with getopt
my $config = "statgraph.conf";

## Get configuration
open CONFIG, $config || die "Cannot open $config: $!";
my @CONFIG = (<CONFIG>);
close CONFIG;

my %CONFIG = confparse(\@CONFIG);
my %HOSTS = %{$CONFIG{hosts}};
%CONFIG = %{$CONFIG{config}};

## Set default configuration options if they've not been specified
my $defaultport = $CONFIG{defaultport} || 27001;
my $rrdlocation = $CONFIG{rrdlocation} || "rrd/";


my $pid = $$;
my $parent = 0;
my @kids = ();
my $host;

## Main loop - run once for each host
FORK: foreach my $currhost (keys %HOSTS) {

    my $newpid = fork();
    if ( not defined $newpid ) {
        # if return value of fork() is undef, something went wrong
        die "fork didn't work: $!\n";
    }
    elsif ( $newpid == 0 ) {
        # if return value is 0, this is the child process
        $parent = $pid; # which has a parent called $pid
        $pid = $$;      # and which will have a process ID of its very own
        @kids = ();     # the child doesn't want this baggage from the parent
        $host = $currhost;
        last FORK;    # and we don't want the child making babies either
    }
    else {
        # the parent process is returned the PID of the newborn by fork()
        push @kids, $newpid;
    }

}

if ( $parent ) {
    # if I have a parent, i.e. if I'm the child process
    my %results;
    my %ignore;
    
    foreach (split(/\s+/, $HOSTS{$host}{ignore})) {
        $ignore{$_} = 1;
    }
    
    ## exec method
    if ($HOSTS{$host}{method} eq 'exec') {
        unless (defined $HOSTS{$host}{execcommand}) {
            die "execcommand not specified for $host, skipping...";
        }
        %results = get_exec_results($HOSTS{$host}{execcommand}, "$rrdlocation$host.txt");
        
    ## Network socket connection method  
    } elsif ($HOSTS{$host}{method} eq 'connect') {
        unless (defined $HOSTS{$host}{hostname}) {
            die "hostname not specified for $host, skipping...";
        }
        my $port = $HOSTS{$host}{port} || $defaultport;
        %results = get_net_results($HOSTS{$host}{hostname}, $port, "$rrdlocation$host.txt");
        
    ## Unknown method  
    } else {
        die "Unknown method specified for $host, skipping...";
    }
    
    ## Simple check that we've got reasonable statgrab data
    unless ($results{const}{0} eq '0') {
        die "Bad statgrab results";
    } else {
	print "got result for $host\n";
    }

    ## Update RRDs
    foreach ('cpu', 'load', 'mem', 'page', 'proc', 'user', 'swap') {
        unless (-e "$rrdlocation$host.$_.rrd") {
            create_rrd($rrdlocation, $_, $host, '');
        }
    }
    update_rrd("$rrdlocation$host.cpu.rrd", sprintf("N:%s:%s:%s:%s:%s:%s:%s", 
        $results{cpu}{idle},
        $results{cpu}{iowait},
        $results{cpu}{kernel},
        $results{cpu}{nice},
        $results{cpu}{swap},
        $results{cpu}{total},
        $results{cpu}{user}));

    update_rrd("$rrdlocation$host.load.rrd", sprintf("N:%s:%s:%s",
        $results{load}{min1},
        $results{load}{min5},
        $results{load}{min15}));

    update_rrd("$rrdlocation$host.mem.rrd", sprintf("N:%s:%s:%s:%s",
        $results{mem}{cache},
        $results{mem}{free},
        $results{mem}{total},
        $results{mem}{used}));

    update_rrd("$rrdlocation$host.page.rrd", sprintf("N:%s:%s",
        $results{page}{in},
        $results{page}{out}));

    update_rrd("$rrdlocation$host.proc.rrd", sprintf("N:%s:%s:%s:%s:%s",
        $results{proc}{running},
        $results{proc}{sleeping},
        $results{proc}{stopped},
        $results{proc}{total},
        $results{proc}{zombie}));

    update_rrd("$rrdlocation$host.user.rrd", sprintf("N:%s",
        $results{user}{num}));

    update_rrd("$rrdlocation$host.swap.rrd", sprintf("N:%s:%s:%s",
        $results{swap}{free},
        $results{swap}{total},
        $results{swap}{used}));

    ## net device RRDs
    foreach my $dev (keys %{ $results{net} }) {
        unless (defined $ignore{"net.$dev"}) {
            unless (-e "$rrdlocation$host.net.$dev.rrd") {
                create_rrd($rrdlocation, 'net', $host, $dev);
            }
            update_rrd("$rrdlocation$host.net.$dev.rrd", sprintf("N:%s:%s:%s:%s:%s:%s",
                $results{net}{$dev}{rx} || 0,
                $results{net}{$dev}{tx} || 0,
                $results{net}{$dev}{ipackets} || 0,
                $results{net}{$dev}{opackets} || 0,
                $results{net}{$dev}{ierrors} || 0,
                $results{net}{$dev}{oerrors} || 0));
        }
    }

    ## disk device RRDs
    foreach my $dev (keys %{ $results{disk} }) {
        unless (defined $ignore{"disk.$dev"}) {
            unless (-e "$rrdlocation$host.disk.$dev.rrd") {
                create_rrd($rrdlocation, 'disk', $host, $dev);
            }
            update_rrd("$rrdlocation$host.disk.$dev.rrd", sprintf("N:%s:%s",
                $results{disk}{$dev}{read_bytes},
                $results{disk}{$dev}{write_bytes}));
        }
    }

    ## fs device RRDs
    foreach my $dev (keys %{ $results{fs} }) {
        unless (defined $ignore{"fs.$dev"}) {
            unless (-e "$rrdlocation$host.fs.$dev.rrd") {
                create_rrd($rrdlocation, 'fs', $host, $dev); 
            }
            update_rrd("$rrdlocation$host.fs.$dev.rrd", sprintf("N:%s:%s:%s:%s",
                $results{fs}{$dev}{used},
                $results{fs}{$dev}{size},
                $results{fs}{$dev}{used_inodes},
                $results{fs}{$dev}{total_inodes}));
        }
    }
}

else {
    # parent process needs to preside over the death of its kids
    while ( my $kid = shift @kids ) {
        my $reaped = waitpid( $kid, 0 );
        unless ( $reaped == $kid ) {
            warn "Something's up: $?\n";
        }
    }
}
