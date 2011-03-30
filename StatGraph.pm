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

use RRDs;
use strict;

# Takes array ref of statgrab output.
# Returns hash structure
sub sgparse ($) {
    my $text = shift;
    my %tree;
    foreach (@$text) {
        chomp;
        m/^([^=]*) = (.*)$/ or die "bad line in statgrab output";
        my @parts = split /\./, $1;
        if ($#parts == 2) {
            $tree{$parts[0]}{$parts[1]}{$parts[2]} = $2;
        } else {
            $tree{$parts[0]}{$parts[1]} = $2;
        }        
    }
    return %tree;
}

sub confparse ($) {
    my $text = shift;
    my %tree;
    foreach (@$text) {
        chomp;
        next if (m/^#/);
        next if (m/^$/);
        m/^([^=]*) = (.*)$/ or die "bad line in config $_";
        my @parts = split /\./, $1;
        if ($#parts == 2) {
            $tree{$parts[0]}{$parts[1]}{$parts[2]} = $2;
        } else {
            $tree{$parts[0]}{$parts[1]} = $2;
        }
    }
    return %tree;
}

## Connect to remote host and retrieve statgrab results
sub get_net_results ($$$) {
    use IO::Socket;
    my ($remote_host, $remote_port, $cache) = @_;
    my ($line, $response, $socket, $flag, @res);

    $socket = IO::Socket::INET->new(PeerAddr => $remote_host,
                                    PeerPort => $remote_port,
                                    Proto    => "tcp",
                                    Type     => SOCK_STREAM)
        or die "Couldn't connect to $remote_host:$remote_port\n";

    #while($line = <$socket>){
    #        push @res, $line;
    #}
    @res = (<$socket>);    

    my $results = join('', @res);
    if ($results ne "") {
        open CACHE, ">$cache";
        print CACHE $results;
        close CACHE;
    } else {
        die "No result from $remote_host";
    }
    return sgparse(\@res);
}

## Run command on local host to retrieve statgrab results
## Can be used to get local stats, or call ssh, or similar...
sub get_exec_results ($$) {
    my $command = shift;
    my $cache = shift;
    open STATGRAB, "$command|" or warn "$command failed: $!";
    my @res = (<STATGRAB>);
    
    my $results = join('', @res);
    if ($results ne "") {
        open CACHE, ">$cache";
        print CACHE $results;
        close CACHE;
    } else {
        die "No result from $command";
    }
    
    return sgparse(\@res);
    
}

## Create RRDs where relevant
sub create_rrd ($$$$) {
    my $rrdlocation = shift;
    my $type = shift;
    my $host = shift;
    my $devname = shift;
    
    use RRDs;
    
    print "  Creating RRD: $host $type $devname\n";
    
    if ($type eq 'cpu') {
        RRDs::create ("$rrdlocation$host.cpu.rrd",
                            "--step", "60",
                            "DS:idle:COUNTER:120:U:U",
                            "DS:iowait:COUNTER:120:U:U",
                            "DS:kernel:COUNTER:120:U:U",
                            "DS:nice:COUNTER:120:U:U",
                            "DS:swap:COUNTER:120:U:U",
                            "DS:total:COUNTER:120:U:U",
                            "DS:user:COUNTER:120:U:U",
                            "RRA:AVERAGE:0.5:1:2160", # 1.5 days
                            "RRA:AVERAGE:0.5:15:1008", # 1.5 weeks
                            "RRA:AVERAGE:0.5:60:1008", # 6 weeks
                            "RRA:AVERAGE:0.5:720:1460", # 2 years
                            "RRA:MAX:0.5:1:2160", # 1.5 days
                            "RRA:MAX:0.5:15:1008", # 1.5 weeks
                            "RRA:MAX:0.5:60:1008", # 6 weeks
                            "RRA:MAX:0.5:720:1460"); # 2 years

    } elsif ($type eq 'load') {
        RRDs::create ("$rrdlocation$host.load.rrd",
                            "--step", "60",
                            "DS:min1:GAUGE:120:U:U",
                            "DS:min5:GAUGE:120:U:U",
                            "DS:min15:GAUGE:120:U:U",
                            "RRA:AVERAGE:0.5:1:2160", # 1.5 days
                            "RRA:AVERAGE:0.5:15:1008", # 1.5 weeks
                            "RRA:AVERAGE:0.5:60:1008", # 6 weeks
                            "RRA:AVERAGE:0.5:720:1460", # 2 years
                            "RRA:MAX:0.5:1:2160", # 1.5 days
                            "RRA:MAX:0.5:15:1008", # 1.5 weeks
                            "RRA:MAX:0.5:60:1008", # 6 weeks
                            "RRA:MAX:0.5:720:1460"); # 2 years
                            
    } elsif ($type eq 'mem') {
        RRDs::create ("$rrdlocation$host.mem.rrd",
                            "--step", "60",
                            "DS:cache:GAUGE:120:U:U",
                            "DS:free:GAUGE:120:U:U",
                            "DS:total:GAUGE:120:U:U",
                            "DS:used:GAUGE:120:U:U",
                            "RRA:AVERAGE:0.5:1:2160", # 1.5 days
                            "RRA:AVERAGE:0.5:15:1008", # 1.5 weeks
                            "RRA:AVERAGE:0.5:60:1008", # 6 weeks
                            "RRA:AVERAGE:0.5:720:1460", # 2 years
                            "RRA:MAX:0.5:1:2160", # 1.5 days
                            "RRA:MAX:0.5:15:1008", # 1.5 weeks
                            "RRA:MAX:0.5:60:1008", # 6 weeks
                            "RRA:MAX:0.5:720:1460"); # 2 years
    
    } elsif ($type eq 'page') {
        RRDs::create ("$rrdlocation$host.page.rrd",
                            "--step", "60",
                            "DS:in:COUNTER:120:U:U",
                            "DS:out:COUNTER:120:U:U",
                            "RRA:AVERAGE:0.5:1:2160", # 1.5 days
                            "RRA:AVERAGE:0.5:15:1008", # 1.5 weeks
                            "RRA:AVERAGE:0.5:60:1008", # 6 weeks
                            "RRA:AVERAGE:0.5:720:1460", # 2 years
                            "RRA:MAX:0.5:1:2160", # 1.5 days
                            "RRA:MAX:0.5:15:1008", # 1.5 weeks
                            "RRA:MAX:0.5:60:1008", # 6 weeks
                            "RRA:MAX:0.5:720:1460"); # 2 years
                            
    } elsif ($type eq 'proc') {
        RRDs::create ("$rrdlocation$host.proc.rrd",
                            "--step", "60",
                            "DS:running:GAUGE:120:U:U",
                            "DS:sleeping:GAUGE:120:U:U",
                            "DS:stopped:GAUGE:120:U:U",
                            "DS:total:GAUGE:120:U:U",
                            "DS:zombie:GAUGE:120:U:U",
                            "RRA:AVERAGE:0.5:1:2160", # 1.5 days
                            "RRA:AVERAGE:0.5:15:1008", # 1.5 weeks
                            "RRA:AVERAGE:0.5:60:1008", # 6 weeks
                            "RRA:AVERAGE:0.5:720:1460", # 2 years
                            "RRA:MAX:0.5:1:2160", # 1.5 days
                            "RRA:MAX:0.5:15:1008", # 1.5 weeks
                            "RRA:MAX:0.5:60:1008", # 6 weeks
                            "RRA:MAX:0.5:720:1460"); # 2 years
    
    } elsif ($type eq 'user') {
        RRDs::create ("$rrdlocation$host.user.rrd",
                            "--step", "60",
                            "DS:num:GAUGE:120:U:U",
                            "RRA:AVERAGE:0.5:1:2160", # 1.5 days
                            "RRA:AVERAGE:0.5:15:1008", # 1.5 weeks
                            "RRA:AVERAGE:0.5:60:1008", # 6 weeks
                            "RRA:AVERAGE:0.5:720:1460", # 2 years
                            "RRA:MAX:0.5:1:2160", # 1.5 days
                            "RRA:MAX:0.5:15:1008", # 1.5 weeks
                            "RRA:MAX:0.5:60:1008", # 6 weeks
                            "RRA:MAX:0.5:720:1460"); # 2 years
    
    } elsif ($type eq 'swap') {
        RRDs::create ("$rrdlocation$host.swap.rrd",
                            "--step", "60",
                            "DS:free:GAUGE:120:U:U",
                            "DS:total:GAUGE:120:U:U",
                            "DS:used:GAUGE:120:U:U",
                            "RRA:AVERAGE:0.5:1:2160", # 1.5 days
                            "RRA:AVERAGE:0.5:15:1008", # 1.5 weeks
                            "RRA:AVERAGE:0.5:60:1008", # 6 weeks
                            "RRA:AVERAGE:0.5:720:1460", # 2 years
                            "RRA:MAX:0.5:1:2160", # 1.5 days
                            "RRA:MAX:0.5:15:1008", # 1.5 weeks
                            "RRA:MAX:0.5:60:1008", # 6 weeks
                            "RRA:MAX:0.5:720:1460"); # 2 years
     

    } elsif ($type eq 'disk') {
        RRDs::create ("$rrdlocation$host.disk.$devname.rrd",
                            "--step", "60",
                            "DS:read_bytes:COUNTER:120:U:U",
                            "DS:write_bytes:COUNTER:120:U:U",
                            "RRA:AVERAGE:0.5:1:2160", # 1.5 days
                            "RRA:AVERAGE:0.5:15:1008", # 1.5 weeks
                            "RRA:AVERAGE:0.5:60:1008", # 6 weeks
                            "RRA:AVERAGE:0.5:720:1460", # 2 years
                            "RRA:MAX:0.5:1:2160", # 1.5 days
                            "RRA:MAX:0.5:15:1008", # 1.5 weeks
                            "RRA:MAX:0.5:60:1008", # 6 weeks
                            "RRA:MAX:0.5:720:1460"); # 2 years
                            
    } elsif ($type eq 'net') {
        RRDs::create ("$rrdlocation$host.net.$devname.rrd",
                            "--step", "60",
                            "DS:rx:COUNTER:120:U:U",
                            "DS:tx:COUNTER:120:U:U",
                            "DS:ipackets:COUNTER:120:U:U",
                            "DS:opackets:COUNTER:120:U:U",
                            "DS:ierrors:COUNTER:120:U:U",
                            "DS:oerrors:COUNTER:120:U:U",
                            "RRA:AVERAGE:0.5:1:2160", # 1.5 days
                            "RRA:AVERAGE:0.5:15:1008", # 1.5 weeks
                            "RRA:AVERAGE:0.5:60:1008", # 6 weeks
                            "RRA:AVERAGE:0.5:720:1460", # 2 years
                            "RRA:MAX:0.5:1:2160", # 1.5 days
                            "RRA:MAX:0.5:15:1008", # 1.5 weeks
                            "RRA:MAX:0.5:60:1008", # 6 weeks
                            "RRA:MAX:0.5:720:1460"); # 2 years
    } elsif ($type eq 'fs') {
        RRDs::create ("$rrdlocation$host.fs.$devname.rrd",
                            "--step", "60",
                            "DS:used:GAUGE:120:U:U",
                            "DS:size:GAUGE:120:U:U",
                            "DS:used_inodes:GAUGE:120:U:U",
                            "DS:total_inodes:GAUGE:120:U:U",
                            "RRA:AVERAGE:0.5:1:2160", # 1.5 days
                            "RRA:AVERAGE:0.5:15:1008", # 1.5 weeks
                            "RRA:AVERAGE:0.5:60:1008", # 6 weeks
                            "RRA:AVERAGE:0.5:720:1460", # 2 years
                            "RRA:MAX:0.5:1:2160", # 1.5 days
                            "RRA:MAX:0.5:15:1008", # 1.5 weeks
                            "RRA:MAX:0.5:60:1008", # 6 weeks
                            "RRA:MAX:0.5:720:1460"); # 2 years
    }
}

sub update_rrd ($$) {
    my $rrd = shift;
    my $data = shift;
    #print "$rrd, $data\n";
    RRDs::update($rrd, $data);
    my $ERR=RRDs::error;
    print "ERROR while updating $rrd: $ERR\n" if $ERR;
}

sub create_graph ($$$$$$$$) {
    my $rrdlocation = shift;
    my $location = shift;
    my $type = shift;
    my $host = shift;
    my $devname = shift;
    my $offsets = shift;
    my $friendly = shift;
    my $colours = shift;
    my %colours = %$colours;
   
    # Check colours
    $colours{stack1} = '#FF0000' unless $colours{stack1};
    $colours{stack2} = '#FFFF00' unless $colours{stack2};
    $colours{stack3} = '#00FFFF' unless $colours{stack3};
    $colours{stack4} = '#00FF00' unless $colours{stack4};
    $colours{stack5} = '#0000FF' unless $colours{stack5};
    
    $colours{load1} = '#CECFFF' unless $colours{load1};
    $colours{load5} = '#7375FF' unless $colours{load5};
    $colours{load15} = '#0000FF' unless $colours{load15}; 

    $colours{area} = '#CECFFF' unless $colours{area};
    $colours{line} = '#0000FF' unless $colours{line};    
    
    $colours{in} = '#00FF00' unless $colours{in};
    $colours{out} = '#0000FF' unless $colours{out}; 
    
    foreach my $offset (@$offsets) {
    
        if ($type eq 'cpu') {
            create_graph_cpu($rrdlocation, $location, $host, $offset, \%colours);
        } elsif ($type eq 'load') {
            create_graph_load($rrdlocation, $location, $host, $offset, \%colours);
        } elsif ($type eq 'mem') {
            create_graph_mem($rrdlocation, $location, $host, $offset, \%colours);    
        } elsif ($type eq 'page') {
            create_graph_page($rrdlocation, $location, $host, $offset, \%colours);
        } elsif ($type eq 'proc') {
            create_graph_proc($rrdlocation, $location, $host, $offset, \%colours);
        } elsif ($type eq 'user') {
            create_graph_user($rrdlocation, $location, $host, $offset, \%colours);
        } elsif ($type eq 'swap') {
            create_graph_swap($rrdlocation, $location, $host, $offset, \%colours);
        } elsif ($type eq 'disk') {
            create_graph_disk($rrdlocation, $location, $host, $devname, $offset, \%colours);
        } elsif ($type eq 'net') {
            create_graph_net($rrdlocation, $location, $host, $devname, $offset, \%colours);
        } elsif ($type eq 'fs') {
            create_graph_fs($rrdlocation, $location, $host, $devname, $offset, $friendly, \%colours);
        }
    
    }
}

sub create_graph_cpu ($$$$$) {
    my $rrdlocation = shift;
    my $location = shift;
    my $host = shift;
    my $offset = shift;
    my $colours = shift;
    my %colours = %{$colours};
    my $type = "cpu";
    
    RRDs::graph ("$location$host.$type.$offset.png",
                        "--start", "-$offset",
                        "-l", "0",
                        "-a", "PNG",
                        "-t", "CPU usage for $host",
                        "--vertical-label", "% cpu used",
                        "DEF:idle=$rrdlocation$host.$type.rrd:idle:AVERAGE",
                        "DEF:iowait=$rrdlocation$host.$type.rrd:iowait:AVERAGE",
                        "DEF:kernel=$rrdlocation$host.$type.rrd:kernel:AVERAGE",
                        "DEF:nice=$rrdlocation$host.$type.rrd:nice:AVERAGE",
                        "DEF:swap=$rrdlocation$host.$type.rrd:swap:AVERAGE",
                        "DEF:user=$rrdlocation$host.$type.rrd:user:AVERAGE",
                        "AREA:kernel$colours{stack1}:kernel cpu",
                        "GPRINT:kernel:LAST:Current\\: \%8.2lf %s",
                        "GPRINT:kernel:AVERAGE:Average\\: \%8.2lf %s",
                        "GPRINT:kernel:MAX:Max\\: \%8.2lf %s\\n",
                        "STACK:swap$colours{stack2}:swap cpu  ",
                        "GPRINT:swap:LAST:Current\\: \%8.2lf %s",
                        "GPRINT:swap:AVERAGE:Average\\: \%8.2lf %s",
                        "GPRINT:swap:MAX:Max\\: \%8.2lf %s\\n",
                        "STACK:iowait$colours{stack3}:iowait cpu",
                        "GPRINT:iowait:LAST:Current\\: \%8.2lf %s",
                        "GPRINT:iowait:AVERAGE:Average\\: \%8.2lf %s",
                        "GPRINT:iowait:MAX:Max\\: \%8.2lf %s\\n",
                        "STACK:nice$colours{stack4}:nice cpu  ",
                        "GPRINT:nice:LAST:Current\\: \%8.2lf %s",
                        "GPRINT:nice:AVERAGE:Average\\: \%8.2lf %s",
                        "GPRINT:nice:MAX:Max\\: \%8.2lf %s\\n",
                        "STACK:user$colours{stack5}:user cpu  ",
                        "GPRINT:user:LAST:Current\\: \%8.2lf %s",
                        "GPRINT:user:AVERAGE:Average\\: \%8.2lf %s",
                        "GPRINT:user:MAX:Max\\: \%8.2lf %s\\n");
    my $ERR=RRDs::error;
    die "ERROR : $ERR\n" if $ERR;
}

sub create_graph_load ($$$$$) {
    my $rrdlocation = shift;
    my $location = shift;
    my $host = shift;
    my $offset = shift;
    my $colours = shift;
    my %colours = %{$colours};
    my $type = "load";
    
    RRDs::graph ("$location$host.$type.$offset.png",
                            "--start", "-$offset",
                            "-l", "0",
                            "-u", "1",
                            "-a", "PNG",
                            "-t", "load averages for $host",
                            "--units-exponent", "1",
                            "--vertical-label", "processes in run queue",
                            "DEF:load1=$rrdlocation$host.$type.rrd:min1:AVERAGE",
                            "DEF:load5=$rrdlocation$host.$type.rrd:min5:AVERAGE",
                            "DEF:load15=$rrdlocation$host.$type.rrd:min15:AVERAGE",
                            "LINE2:load1$colours{load1}:1 minute load ",
                            "GPRINT:load1:LAST:Current\\: \%8.2lf %s",
                            "GPRINT:load1:AVERAGE:Average\\: \%8.2lf %s",
                            "GPRINT:load1:MAX:Max\\: \%8.2lf %s\\n",
                            "LINE2:load5$colours{load5}:5 minute load ",
                            "GPRINT:load5:LAST:Current\\: \%8.2lf %s",
                            "GPRINT:load5:AVERAGE:Average\\: \%8.2lf %s",
                            "GPRINT:load5:MAX:Max\\: \%8.2lf %s\\n",
                            "LINE2:load15$colours{load15}:15 minute load",
                            "GPRINT:load15:LAST:Current\\: \%8.2lf %s",
                            "GPRINT:load15:AVERAGE:Average\\: \%8.2lf %s",
                            "GPRINT:load15:MAX:Max\\: \%8.2lf %s\\n");
    my $ERR=RRDs::error;
    die "ERROR : $ERR\n" if $ERR;
}

sub create_graph_mem ($$$$$) {
    my $rrdlocation = shift;
    my $location = shift;
    my $host = shift;
    my $offset = shift;
    my $colours = shift;
    my %colours = %{$colours};
    my $type = "mem";
    
    RRDs::graph ("$location$host.$type.$offset.png",
                                    "--start", "-$offset",
                                    "-l", "0",
                                    "-a", "PNG",
                                    "-u", "100",
                                    "-t", "memory usage for $host",
                                    "--base", "1024",
                                    "--vertical-label", "% memory used",
                                    "DEF:free=$rrdlocation$host.$type.rrd:free:AVERAGE",
                                    "DEF:cache=$rrdlocation$host.$type.rrd:cache:AVERAGE",
                                    "DEF:used=$rrdlocation$host.$type.rrd:used:AVERAGE",
                                    "DEF:total=$rrdlocation$host.$type.rrd:total:AVERAGE",
                                    "CDEF:peruse=total,free,total,LT,free,0,IF,-,total,/,100,*",
                                    "CDEF:percacuse=cache,total,LT,cache,0,IF,total,/,100,*",
                                    "AREA:peruse$colours{area}:Used ",
                                    "GPRINT:peruse:LAST:Current\\: \%8.2lf %s",
                                    "GPRINT:peruse:AVERAGE:Average\\: \%8.2lf %s",
                                    "GPRINT:peruse:MAX:Max\\: \%8.2lf %s\\n",
                                    "LINE2:percacuse$colours{line}:Cache",
                                    "GPRINT:percacuse:LAST:Current\\: \%8.2lf %s",
                                    "GPRINT:percacuse:AVERAGE:Average\\: \%8.2lf %s",
                                    "GPRINT:percacuse:MAX:Max\\: \%8.2lf %s\\n",
                                    "GPRINT:total:LAST:Current total memory\\: \%.2lf %sb\\c");

    my $ERR=RRDs::error;
    die "ERROR : $ERR\n" if $ERR;
}

sub create_graph_proc ($$$$$) {
    my $rrdlocation = shift;
    my $location = shift;
    my $host = shift;
    my $offset = shift;
    my $colours = shift;
    my %colours = %{$colours};
    my $type = "proc";
    
    RRDs::graph ("$location$host.$type.$offset.png",
                            "--start", "-$offset",
                            "-l", "0",,
                            "-a", "PNG",
                            "-t", "processes on $host",
                            "--units-exponent", "1",
                            "--vertical-label", "num of processes",
                            "DEF:running=$rrdlocation$host.$type.rrd:running:AVERAGE",
                            "DEF:sleeping=$rrdlocation$host.$type.rrd:sleeping:AVERAGE",
                            "DEF:stopped=$rrdlocation$host.$type.rrd:stopped:AVERAGE",
                            "DEF:zombie=$rrdlocation$host.$type.rrd:zombie:AVERAGE",
                            "AREA:stopped$colours{stack1}:stopped processes ",
                            "GPRINT:stopped:LAST:Current\\: \%8.2lf %s",
                            "GPRINT:stopped:AVERAGE:Average\\: \%8.2lf %s",
                            "GPRINT:stopped:MAX:Max\\: \%8.2lf %s\\n",
                            "STACK:zombie$colours{stack2}:zombie processes  ",
                            "GPRINT:zombie:LAST:Current\\: \%8.2lf %s",
                            "GPRINT:zombie:AVERAGE:Average\\: \%8.2lf %s",
                            "GPRINT:zombie:MAX:Max\\: \%8.2lf %s\\n",
                            "STACK:sleeping$colours{stack3}:sleeping processes",
                            "GPRINT:sleeping:LAST:Current\\: \%8.2lf %s",
                            "GPRINT:sleeping:AVERAGE:Average\\: \%8.2lf %s",
                            "GPRINT:sleeping:MAX:Max\\: \%8.2lf %s\\n",
                            "STACK:running$colours{stack4}:running processes ",
                            "GPRINT:running:LAST:Current\\: \%8.2lf %s",
                            "GPRINT:running:AVERAGE:Average\\: \%8.2lf %s",
                            "GPRINT:running:MAX:Max\\: \%8.2lf %s\\n");
                            
    my $ERR=RRDs::error;
    die "ERROR : $ERR\n" if $ERR;
}

sub create_graph_page ($$$$$) {
    my $rrdlocation = shift;
    my $location = shift;
    my $host = shift;
    my $offset = shift;
    my $colours = shift;
    my %colours = %{$colours};
    my $type = "page";
    
    RRDs::graph ("$location$host.$type.$offset.png",
                            "--start", "-$offset",
                            "-l", "0",,
                            "-a", "PNG",
                            "-t", "paging activity on $host",
                            "--units-exponent", "1",
                            "--vertical-label", "pages/second",
                            "DEF:in=$rrdlocation$host.$type.rrd:in:AVERAGE",
                            "DEF:out=$rrdlocation$host.$type.rrd:out:AVERAGE",
                            "AREA:in$colours{in}:pages in ",
                            "GPRINT:in:LAST:Current\\: \%8.2lf %s",
                            "GPRINT:in:AVERAGE:Average\\: \%8.2lf %s",
                            "GPRINT:in:MAX:Max\\: \%8.2lf %s\\n",
                            "LINE2:out$colours{out}:pages out",
                            "GPRINT:out:LAST:Current\\: \%8.2lf %s",
                            "GPRINT:out:AVERAGE:Average\\: \%8.2lf %s",
                            "GPRINT:out:MAX:Max\\: \%8.2lf %s\\n");
                            
    my $ERR=RRDs::error;
    die "ERROR : $ERR\n" if $ERR;
}

sub create_graph_user ($$$$$) {
    my $rrdlocation = shift;
    my $location = shift;
    my $host = shift;
    my $offset = shift;
    my $colours = shift;
    my %colours = %{$colours};
    my $type = "user";
    
    RRDs::graph ("$location$host.$type.$offset.png",
                            "--start", "-$offset",
                            "-l", "0",
                            "-u", "1",
                            "-a", "PNG",
                            "-t", "users on $host",
                            "--units-exponent", "1",
                            "--vertical-label", "users logged in",
                            "DEF:num=$rrdlocation$host.$type.rrd:num:AVERAGE",
                            "LINE2:num$colours{line}:Logged in users",
                            "GPRINT:num:LAST:Current\\: \%8.2lf %s",
                            "GPRINT:num:AVERAGE:Average\\: \%8.2lf %s",
                            "GPRINT:num:MAX:Max\\: \%8.2lf %s\\n");
                            
    my $ERR=RRDs::error;
    die "ERROR : $ERR\n" if $ERR;
}

sub create_graph_swap ($$$$$) {
    my $rrdlocation = shift;
    my $location = shift;
    my $host = shift;
    my $offset = shift;
    my $colours = shift;
    my %colours = %{$colours};
    my $type = "swap";
    
    RRDs::graph ("$location$host.$type.$offset.png",
                                    "--start", "-$offset",
                                    "-l", "0",
                                    "-a", "PNG",
                                    "-u", "100",
                                    "-t", "swap use on $host",
                                    "--base", "1024",
                                    "--vertical-label", "% swap used",
                                    "DEF:free=$rrdlocation$host.$type.rrd:free:AVERAGE",
                                    "DEF:used=$rrdlocation$host.$type.rrd:used:AVERAGE",
                                    "DEF:total=$rrdlocation$host.$type.rrd:total:AVERAGE",
                                    "CDEF:peruse=total,free,total,LT,free,0,IF,-,total,/,100,*",
                                    "AREA:peruse$colours{area}:Used",
                                    "GPRINT:peruse:LAST:Current\\: \%8.2lf %s",
                                    "GPRINT:peruse:AVERAGE:Average\\: \%8.2lf %s",
                                    "GPRINT:peruse:MAX:Max\\: \%8.2lf %s\\n",
                                    "GPRINT:total:LAST:Current total swap\\: \%.2lf %sb\\c");
                            
    my $ERR=RRDs::error;
    die "ERROR : $ERR\n" if $ERR;
}

sub create_graph_disk ($$$$$$) {
    my $rrdlocation = shift;
    my $location = shift;
    my $host = shift;
    my $dev = shift;
    my $offset = shift;
    my $colours = shift;
    my %colours = %{$colours};
    my $type = "disk";
    
    RRDs::graph ("$location$host.$type.$dev.$offset.png",
                                    "--start", "-$offset",
                                    "-l", "0",
                                    "-a", "PNG",
                                    "-t", "disk io on $host for $dev",
                                    "--base", "1024",
                                    "--vertical-label", "bytes per second",
                                    "DEF:read_bytes=$rrdlocation$host.$type.$dev.rrd:read_bytes:AVERAGE",
                                    "DEF:write_bytes=$rrdlocation$host.$type.$dev.rrd:write_bytes:AVERAGE",
                                    "AREA:read_bytes$colours{in}:read bytes ",
                                    "GPRINT:read_bytes:LAST:Current\\: \%8.2lf %s",
                                    "GPRINT:read_bytes:AVERAGE:Average\\: \%8.2lf %s",
                                    "GPRINT:read_bytes:MAX:Max\\: \%8.2lf %s\\n",
                                    "LINE2:write_bytes$colours{out}:write bytes",
                                    "GPRINT:write_bytes:LAST:Current\\: \%8.2lf %s",
                                    "GPRINT:write_bytes:AVERAGE:Average\\: \%8.2lf %s",
                                    "GPRINT:write_bytes:MAX:Max\\: \%8.2lf %s\\n");
                            
    my $ERR=RRDs::error;
    die "ERROR : $ERR\n" if $ERR;
}

sub create_graph_net ($$$$$$) {
    my $rrdlocation = shift;
    my $location = shift;
    my $host = shift;
    my $dev = shift;
    my $offset = shift;
    my $colours = shift;
    my %colours = %{$colours};
    my $type = "net";
    
    RRDs::graph ("$location$host.$type.$dev.$offset.png",
                                    "--start", "-$offset",
                                    "-l", "0",
                                    "-a", "PNG",
                                    "-t", "network io on $host for $dev",
                                    "--base", "1024",
                                    "--vertical-label", "bytes per second",
                                    "DEF:rx=$rrdlocation$host.$type.$dev.rrd:rx:AVERAGE",
                                    "DEF:tx=$rrdlocation$host.$type.$dev.rrd:tx:AVERAGE",
                                    "AREA:rx$colours{in}:recieved bytes   ",
                                    "GPRINT:rx:LAST:Current\\: \%8.2lf %s",
                                    "GPRINT:rx:AVERAGE:Average\\: \%8.2lf %s",
                                    "GPRINT:rx:MAX:Max\\: \%8.2lf %s\\n",
                                    "LINE2:tx$colours{out}:transmitted bytes",
                                    "GPRINT:tx:LAST:Current\\: \%8.2lf %s",
                                    "GPRINT:tx:AVERAGE:Average\\: \%8.2lf %s",
                                    "GPRINT:tx:MAX:Max\\: \%8.2lf %s\\n");
                            
    my $ERR=RRDs::error;
    die "ERROR : $ERR\n" if $ERR;
}

sub create_graph_fs ($$$$$$$) {
    my $rrdlocation = shift;
    my $location = shift;
    my $host = shift;
    my $dev = shift;
    my $offset = shift;
    my $mountpoint = shift || $dev;
    my $colours = shift;
    my %colours = %{$colours};
    my $type = "fs";
    $dev =~ s/:/\\:/g;
    RRDs::graph ("$location$host.$type.$dev.$offset.png",
                                    "--start", "-$offset",
                                    "-l", "0",
                                    "-a", "PNG",
                                    "-u", "100",
                                    "-t", "disk usage on $host for $mountpoint",
                                    "--base", "1024",
                                    "--vertical-label", "% used",
                                    "DEF:used=$rrdlocation$host.$type.$dev.rrd:used:AVERAGE",
                                    "DEF:size=$rrdlocation$host.$type.$dev.rrd:size:AVERAGE",
                                    "DEF:used_inodes=$rrdlocation$host.$type.$dev.rrd:used_inodes:AVERAGE",
                                    "DEF:total_inodes=$rrdlocation$host.$type.$dev.rrd:total_inodes:AVERAGE",
                                    "CDEF:peruse=used,size,/,100,*",
                                    "CDEF:perinode=used_inodes,total_inodes,/,100,*",
                                    "AREA:peruse$colours{area}:space used ",
                                    "GPRINT:peruse:LAST:Current\\: \%8.2lf %s",
                                    "GPRINT:peruse:AVERAGE:Average\\: \%8.2lf %s",
                                    "GPRINT:peruse:MAX:Max\\: \%8.2lf %s\\n",
                                    "GPRINT:size:LAST:Current total space\\: \%.2lf %sb\\c",
                                    "LINE2:perinode$colours{line}:inodes used",
                                    "GPRINT:perinode:LAST:Current\\: \%8.2lf %s",
                                    "GPRINT:perinode:AVERAGE:Average\\: \%8.2lf %s",
                                    "GPRINT:perinode:MAX:Max\\: \%8.2lf %s\\n",
                                    "GPRINT:total_inodes:LAST:Current total inodes\\: \%.2lf %s\\c");

    my $ERR=RRDs::error;
    die "ERROR : $ERR\n" if $ERR;
}

sub htmlheader ($) {
    my $title = shift;
    return "<html><head><meta http-equiv='refresh' content='60'>
	<title>$title</title></head>
    <body>";
}

sub htmlfooter () {
    return "<p><img src='sg-p-small.png' alt='Powered by StatGraph' /></p>
    </body></html>";
}


sub create_page ($$$$$) {
    my $location = shift;
    my $type = shift;
    my $host = shift;
    my $devname = shift;
    my $offsets = shift;
   
   # print "  Creating graphs: $host $type $devname\n";
    
    my %nicenames = (
            'cpu' => "CPU utilisation for $host",
            'load' => "Load averages for $host",
            'mem' => "Memory usage for $host",
            'page' => "Paging activity for $host",
            'proc' => "Processes for $host",
            'user' => "User activity for $host",
            'swap' => "Swap usage for $host",
            'disk' => "Disk IO for $host on $devname",
            'net' => "Network IO for $host on $devname",
        'fs' => "Filsystem Utilisation for $host on $devname");
        
    
    my $dev = "";
    $dev = ".$devname" if ($devname ne "");
    
    open OUT, ">$location$host-$type$dev.html";
    print OUT htmlheader("$nicenames{$type}");
    print OUT "<h1>$nicenames{$type}</h1>\n";
    print OUT "<p>Last updated: " . nice_date();    

    foreach my $offset (@$offsets) {
        print OUT "<h2>" . nice_time($offset). "</h2><img src='$host.$type$dev.$offset.png'><br />\n";
    }
    close OUT;
} 

sub nice_time ($) {
    my $seconds = shift;
    my $minute = '60';
    my $hour = '3600';
    my $day = 24 * $hour;
    my $week = 7 * $day;
    my $month = 4 * $week;
    my $year = 365 * $day;
    
    my @stack;
    
    my $tmp = int($seconds / $year);
    if ($tmp > 0) {
        push @stack, "$tmp years";
        $seconds = $seconds % $year;
    }
    
    $tmp = int($seconds / $month);
    if ($tmp > 0) {
        push @stack, "$tmp months";
        $seconds = $seconds % $month;
    }

    $tmp = int($seconds / $week);
    if ($tmp > 0) {
        push @stack, "$tmp weeks";
        $seconds = $seconds % $week;
    }
    
    $tmp = int($seconds / $day);
    if ($tmp > 0) {
        push @stack, "$tmp days";
        $seconds = $seconds % $day;
    }
    
    $tmp = int($seconds / $hour);
    if ($tmp > 0) {
        push @stack, "$tmp hours";
        $seconds = $seconds % $hour;
    }

    $tmp = int($seconds / $minute);
    if ($tmp > 0) {
        push @stack, "$tmp minutes";
        $seconds = $seconds % $minute;
    } 
    
    push (@stack, "$seconds seconds") if ($seconds > 0);
    
    return join (", ", @stack);
}

sub nice_date () {
    my ($seconds, $minutes, $hours, $day_of_month, $month, $year, $wday, $yday, $isdst) = localtime(time);
    return sprintf("%02d:%02d:%02d-%04d/%02d/%02d\n", $hours, $minutes, $seconds, $year+1900, $month+1, $day_of_month);
}

1;
