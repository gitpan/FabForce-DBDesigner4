#!/usr/bin/perl

use strict;
use warnings;
use FindBin ();
use Test::More tests => 1;

SKIP:{
    eval "use Test::CheckManifest 0.4";
    skip "Test::CheckManifest 0.4 required",1 if $@;
    
    ok_manifest();
}