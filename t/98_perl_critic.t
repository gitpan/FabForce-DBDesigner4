#!perl -T

use Test::More tests => 4;
use FabForce::DBDesigner4;

SKIP:{

    skip 'Set RELEASE_TESTING=1 to run this test' => 4 if not $ENV{RELEASE_TESTING};

    eval "use Perl::Critic";
    skip "Perl::Critic required", 4 if $@;

    my $pc = Perl::Critic->new();
    my @violations = $pc->critique($INC{'FabForce/DBDesigner4.pm'});
    is_deeply(\@violations,[],'Perl::Critic');
    my @violations2 = $pc->critique($INC{'FabForce/DBDesigner4/Table.pm'});
    is_deeply(\@violations2,[],'Perl::Critic');
    my @violations3 = $pc->critique($INC{'FabForce/DBDesigner4/SQL.pm'});
    is_deeply(\@violations3,[],'Perl::Critic');
    my @violations4 = $pc->critique($INC{'FabForce/DBDesigner4/XML.pm'});
    is_deeply(\@violations4,[],'Perl::Critic');
}

