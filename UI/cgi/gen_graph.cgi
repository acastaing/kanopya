#!/usr/bin/perl

use lib "/workspace/mcs/Monitor/Lib";

use strict;
use warnings;
use HTML::Template;
use CGI;

# open html template
my $template = HTML::Template->new(filename => 'templates/graph.tmpl');

# get url params (POST or GET)
my $cgi = new CGI;


$template->param(AUTO_REFRESH => 1);

my $dir = "/tmp/monitor/graph";
my $dir_alias = "/graph/";
my $graph_subdir = "monitor/graph/";

opendir DIR, $dir or die "$dir doesn't exist !";
my @files = readdir DIR;
my @graphs = ();
for my $file (@files) {
	if ( $file =~ "^graph_" ) {
		push @graphs, { dir_alias => $dir_alias, file => "$graph_subdir$file"};
	}
}

#my @graphs = ( 	{ file => '/graph/graph_cluster_1_nodecount.png'},
#				{ file => '/graph/graph_localhost_gen.png'});
$template->param(GRAPHS => \@graphs);



################################################################

# print html page using template
print "Content-Type: text/html\n\n", $template->output;