#!/usr/bin/perl

use strict;
use warnings 'all';

use URI::Escape;
use LWP::UserAgent;
use HTTP::Request;
use JSON::Parse 'valid_json';
use JSON::XS 'decode_json';
use POSIX 'strftime';

my $baseurl = 'http://coursepickle.com/api/courses?max_results=10000&q=';
my $query = "@ARGV";
my $url = $baseurl . uri_escape $query;

die "Usage: $0 solr_query\n" if $query eq "";

my $ua = LWP::UserAgent->new;
$ua->agent('FindInterestingClass/0.1 ' . $ua->_agent);

my $req = HTTP::Request->new(GET => $url);
$req->header('Accept' => 'application/json');

# I used this back when coursepickle was really slow to tell people
# that this script didn't just hang or something. Checking termcap
# before using the ansi escape sequences wouldn't be a bad idea.
#$|++;
#print "Making request to coursepickle.com API...";
#my $res = $ua->request($req);
#print "\033[0G\033[K"; # move cursor to 1st column, clear to end of line
#$|--;

# But, coursepickle is fine now, so lets be quieter and nicer for
# piping to other programs.
my $res = $ua->request($req);

die 'HTTP reqest failed: ' . $res->status_line . "\n" unless $res->is_success;
die "Server returned invalid JSON\n" unless valid_json $res->content;

my @json = decode_json $res->content;

my $today = qw(Sun M T W R F Sat)[(localtime)[6]];
my $now = (localtime)[2] + (localtime)[2] * 60;

foreach (@{$json[0]}) {
	my $f = $_->{'fields'};

	my @days = split ' ', $f->{'days'};
	next unless grep($_ eq $today, @days);

	my @times = split ' ', $f->{'begin'};
	foreach (@times) {
		$_ =~ /([0-9]+):([0-9]+)([A|P])M/;
		$_ = ($1 eq "12" ? 0 : $1) * 60 + $2 + ($3 eq 'P') * 60 * 12;
	}
	next unless grep($_ - $now > 0, @times);

	printf "%-9s%-30s%4s %-16s%-20s\n",
	    $f->{'course'},
	    $f->{'title'},
	    join('', @days),
	    $f->{'begin'},
	    $f->{'location'};
}
