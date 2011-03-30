# Statgraph #

## Introduction ##

Statgraph is a simple tool for graphing usage statistic from a number of
unix hosts. 

Statgraph makes use of the statgrab tool from
http://www.i-scream.org/libstatgrab/ and has been tested on Linux,
Solaris and FreeBSD. In theory, any platform supported by libstatgrab
should work.


## Usage ##

To make use of statgraph, you'll need perl and RRDtool, along with the
perl bindings for RRDtool. On debian, these are included in the
'librrds-perl' package. 

To collect statistics from a host, it will need the statgrab tool
installed from libstatgrab. On a debian/ubuntu system, you can simply
'apt-get install statgrab'. 

You'll need to decide how to collect statistics - either via a direct
TCP connection to the target host, or by executing a command of your
choice. This does mean you can make use of ssh with an ssh key if you
want to keep open ports to a minimum. 

### Direct TCP ###

If you're collecting via TCP, the easiest way to set things up is to run
statgrab from inetd. 

In /etc/services, add:

    statgrab        27001/tcp

and in /etc/inetd.conf:
 
    statgrab stream tcp nowait root /usr/sbin/tcpd /usr/bin/statgrab

You don't have to run it as root, but there are some statistics that it
doesn't collect as an unprivileged user. The risk is relatively low as
statgrab doesn't accept any input, and will simply print the statistics
and exit, but there is always a risk with exposing a service. As always,
you should seriously consider firewalling access to this port to trusted
hosts only. 

### Running a command ###

This has a bit more overhead, but does mean minimal changes to the
server you're connecting to. Any command that generates statgrab output
is fine. The simplest option is something like: 

    ssh -i ssh_key user@hostname /usr/bin/statgrab

### Configuration File ###

The configuration for statgraph is statgraph.conf - this should be
fairly self-explanatory, and a few examples are provided in
statgraph.conf.example

## Running ##

To check it's all working, run ./statgraph.pl manually. If that looks
good, add to cron and run once per minute. It will email you if a
connection to a host fails though, so you might want to redirect output
to a log file. I don't, since it's useful to know if a host is broken :)

To generate graphs, run the ./mkgraph.pl script. I run this every 10
minutes from cron, and it generates static html and .png images in
whatever you've configured the graphs to live. By default this is the
'graphs' directory inside the statgraph directory. 

This directory can be shared by a webserver and contains no dynamic code
whatsoever. 

## Known Issues ##

 * Statgraph is insanely spammy if a host is down, unless you redirect
   output

 * Mounts with : in the name (remote NFS mounts for example) don't show
   up correctly.

 * There's no sanity checking for return values, since they could
   massively vary. When I wrote statgraph the idea of 128 core machines
   was unimaginable, but we're there now, so I'm reluctant to hard code
   any values in. Occasionally a wonky value will make the graph scale a
   bit silly. There's a tool called 'rrdtrim' that can fix these. On an
   installation monitoring about 40 hosts, I probably have to fix 2 a
   year.

 * Running it from cron can be a bit braindead sometime, and the
   timeouts could be more effective - occasionally processes do get
   wedged if the child does, but it's rare. 

## License ##

Statgraph is released under the GPLv2 license. See the COPYING file for
details.
