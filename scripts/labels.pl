#! /usr/bin/perl

# LaTeX filetype plugin
# Languages:    LaTeX
# Maintainer:   Óscar Pereira
# License:      GPL
#
#************************************************************************
#
#                     TeX-7 library: Vim script
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program. If not, see <http://www.gnu.org/licenses/>.
#
#    Copyright Óscar Pereira, 2022
#
#************************************************************************

use strict;
use warnings;

use Path::Tiny;
use JSON; # Requires perl-json.

use Data::Dumper;

my %res;

foreach (@ARGV) {
  my $fname = $_;
  unless (-e $fname && -r $fname) {
    next;
  }
  my $content = path($fname)->slurp_utf8;
  my @labels = $content =~ m/\\label\{(\S+)\}/g;
  
  $res{$fname} = { "last_read_epoch" => time(), "labels" => \@labels } ;
}

my $json = to_json(\%res);
print $json;

# print Dumper from_json($json);
