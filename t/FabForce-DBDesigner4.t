# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl FabForce-DBDesigner4.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 6;
use FindBin qw();
use FabForce::DBDesigner4;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

  my $designer = FabForce::DBDesigner4->new();
  ok(ref $designer eq 'FabForce::DBDesigner4');
  
  my $file = $FindBin::Bin .'/test.xml';
  $designer->parsefile(xml => $file);
  
  my @tables = $designer->getTables();
  ok(scalar(@tables) == 1);
  ok($tables[0]->name() eq 'Testtable');
  
  my $col = ($tables[0]->columns())[0];
  ok($col eq 'column1 INTEGER NOT NULL AUTOINCREMENT');
  
  my @creates = (qq~CREATE TABLE Testtable(
  column1 INTEGER NOT NULL AUTOINCREMENT,
  col2 VARCHAR(255) ,
  PRIMARY KEY(column1),
  );

~);
  
  is_deeply(\@creates,[$designer->getSQL()],'check getSQL()');