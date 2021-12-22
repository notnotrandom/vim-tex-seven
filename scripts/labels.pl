#! /usr/bin/perl

use strict;
use warnings;

use Path::Tiny;
use JSON; # Requires perl-json.

use Data::Dumper;

my %res;

foreach (@ARGV) {
  my $fname = $_;
  my $content = path($fname)->slurp_utf8;
  my @labels = $content =~ m/\\label\{(\S+)\}/g;
  
  $res{$fname} = { "last_read_epoch" => time(), "labels" => \@labels } ;
}

my $json = to_json(\%res);
print $json;

# print Dumper from_json($json);

