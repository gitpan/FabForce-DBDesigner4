#!/usr/bin/perl

use strict;
use warnings;
use FindBin ();
use Test::More;

SKIP:{
    eval "use Test::Pod 1.00";
    skip "Test::Pod 1.00 required",1 if $@;
    
    my $pod_dir = $FindBin::Bin . "/../lib";
    my @poddirs = ($pod_dir);
    all_pod_files_ok(all_pod_files(@poddirs));
}