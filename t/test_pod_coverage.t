#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

SKIP:{
    eval "use Test::Pod::Coverage";
    skip "Test::Pod::Coverage required",1 if $@;

    my @mods = all_modules();
    all_pod_coverage_ok(@mods);
}
