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
use File::Copy;

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
my $offsets = $CONFIG{offsets} || '10800 86400 604800 2419200 31536000';
my @offsets = split(/\s+/, $offsets); 

my $rrdlocation = $CONFIG{rrdlocation} || "rrd/";
my $graphlocation = $CONFIG{graphlocation} || "graphs/";


open INDEX, ">$graphlocation/index.html.tmp";
print INDEX htmlheader("StatGraph results");
print INDEX "<h1>StatGraph results</h1>";
print INDEX "<p>Last updated: " . nice_date;
print INDEX "<ul>";


## Main loop - run once for each host
foreach my $host (sort keys %HOSTS) {
    print "+ $HOSTS{$host}{displayname}\n"; 
    print INDEX "<li><a href='$host.html'>$host</a>";
    print INDEX " - $HOSTS{$host}{comment}</li>";
    
    my %ignore;
    
    foreach (split(/\s+/, $HOSTS{$host}{ignore})) {
        $ignore{$_} = 1;
    }
    
    open CACHE, "$rrdlocation$host.txt" || warn "$host has no cache\n";
    my @res = (<CACHE>);
    close CACHE;
    my %results = sgparse(\@res);
    
    
    ## Simple check that we've got reasonable statgrab data
    unless ($results{const}{0} eq '0') {
        warn "Bad statgrab results for $host";
        next;
    }
     
    open SUMM, ">$graphlocation$host.html";
    print SUMM htmlheader("$host summary");
    my %colours = %{$CONFIG{colour}};

    print SUMM "<h1>$host summary for last " . nice_time($offsets[0]). "</h1>";
    print SUMM "<p>$HOSTS{$host}{comment}</p>";
    print SUMM "<p>Last updated: " . nice_date;
    
    my %nicenames = (
            'cpu' => "CPU utilisation for $host",
            'load' => "Load averages for $host",
            'mem' => "Memory usage for $host",
            'page' => "Paging activity for $host",
            'proc' => "Processes for $host",
            'user' => "User activity for $host",
            'swap' => "Swap usage for $host");

    ## Generate graphs
    foreach ('cpu', 'load', 'mem', 'page', 'proc', 'user', 'swap') {
        if (-e "$rrdlocation$host.$_.rrd") {
            create_graph($rrdlocation, $graphlocation, $_, $host, '', \@offsets, '', \%colours);
            create_page($graphlocation, $_, $host, '', \@offsets);
            print SUMM "<h2>$nicenames{$_}</h2><a href='$host-$_.html'><img src='$host.$_.$offsets[0].png'></a><br />\n";
        }
    }

    ## net device RRDs
    foreach my $dev (sort keys %{ $results{net} }) {
        unless (defined $ignore{"net.$dev"}) {
            if (-e "$rrdlocation$host.net.$dev.rrd") {
                create_graph($rrdlocation, $graphlocation, 'net', $host, $dev, \@offsets, '', \%colours);
                create_page($graphlocation, 'net', $host, $dev, \@offsets);
                print SUMM "<h2>Network IO for $host on $dev</h2><a href='$host-net.$dev.html'><img src='$host.net.$dev.$offsets[0].png'></a><br />\n";
            }
        }
    }

    ## disk device RRDs
    foreach my $dev (sort keys %{ $results{disk} }) {
        unless (defined $ignore{"disk.$dev"}) {
            if (-e "$rrdlocation$host.disk.$dev.rrd") {
                create_graph($rrdlocation, $graphlocation, 'disk', $host, $dev, \@offsets, '', \%colours);
                create_page($graphlocation, 'disk', $host, $dev, \@offsets);
                print SUMM "<h2>Disk IO for $host on $dev</h2><a href='$host-disk.$dev.html'><img src='$host.disk.$dev.$offsets[0].png'></a><br />\n";
            }
        }
    }

    ## fs device RRDs
    foreach my $dev (sort keys %{ $results{fs} }) {
        unless (defined $ignore{"fs.$dev"}) {
            if (-e "$rrdlocation$host.fs.$dev.rrd") {
                create_graph($rrdlocation, $graphlocation, 'fs', $host, $dev, \@offsets, $results{fs}{$dev}{mnt_point}, \%colours); 
                create_page($graphlocation, 'fs', $host, $dev, \@offsets);
                print SUMM "<h2>Filesystem Utilisation for $host on $dev</h2><a href='$host-fs.$dev.html'><img src='$host.fs.$dev.$offsets[0].png'></a><br />\n";
            }
        }
    }
    print SUMM htmlfooter;
    close SUMM;
}
print INDEX "</ul>";
print INDEX htmlfooter;
close INDEX;

move("$graphlocation/index.html.tmp", "$graphlocation/index.html");
