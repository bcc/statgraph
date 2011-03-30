#!/usr/bin/perl
$name = $ARGV[0];
$dnsdomainname = `dnsdomainname`;
chomp($dnsdomainname);

print "hosts.$name.displayname = $name.$dnsdomainname
hosts.$name.method = connect
hosts.$name.hostname = $name
hosts.$name.port = 27001
hosts.$name.comment = $name

"
