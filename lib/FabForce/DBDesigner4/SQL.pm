package FabForce::DBDesigner4::SQL;

use 5.006001;
use strict;
use warnings;
use Carp;
use FabForce::DBDesigner4::Table qw(:const);

our $VERSION     = '0.04';
our $ERROR       = 0;

sub new{
  my ($class) = @_;
  my $self = {};
  bless $self,$class;
  return $self;
}# new

sub parsefile{
  my ($self,$filename) = @_;
  return unless($filename && -e $filename);
  my @creates;
  my $statement = '';
  open(my $fh,"<",$filename) or croak "Could not open $filename";
  while(<$fh>){
    if(/create/i../;/){
      $statement .= $_;
    }
    if($_ =~ /;/ && $statement ne ''){
      push(@creates,$statement);
      $statement = '';
    }
  }
  close $fh;
  my $array = createStructure(@creates);
  warn "Your SQL-Syntax has errors!\n" if($ERROR);
  return [] if($ERROR);
  return $array;
}# parsefile

sub writeSQL{
  my ($self,$structure,$file) = @_;
  return unless(ref($structure) eq 'ARRAY');
  my $fh = (defined $file) ? IO::File->new(">$file") : \*STDOUT;
  unless(ref($fh) =~ /IO::File/){
    $fh = \*STDOUT;
  }
  print $fh $self->getSQL($structure);

  $fh->close() if(ref($fh) ne 'GLOB');
}# writeSQL

sub getSQL{
    my ($self,$structure) = @_;
    return unless ref($structure) eq 'ARRAY';
    
    my @statements = ();
    
    for my $table(@$structure){
        my @columns   = $table->columns();
        my $tablename = $table->name();
        my @relations = grep{$_->[1] =~ /^$tablename\./}$table->relations();
           @relations = getForeignKeys(@relations);
        my $stmt = "CREATE TABLE ".$tablename."(\n  ".join(",\n  ",@columns).",\n  ";
        $stmt   .= "PRIMARY KEY(".join(",",$table->key())."),\n  " if(scalar($table->key()) > 0);
        $stmt   .= join(",\n  ",@relations).",\n  " if(scalar(@relations) > 0);
        $stmt   .= ");\n\n";
    
        push @statements,$stmt;
    }
    
    return @statements;
}

sub createStructure{
  my (@tables) = @_;
  my @tableArray;
  my $hashref;
  for my $table(@tables){
    $table =~ s/\r?\n/ /g;
    my ($primaryKey,$index,@foreignKeys);
    my $tableObject     = FabForce::DBDesigner4::Table->new();
    my ($tablename)     = $table =~ /create\s+table\s+([^\s(]*)/is;
    my ($columnsstring) = $table =~ /\((.*)\);/;
    if($columnsstring   =~ s/\s*?primary\s+key\s*?\(([^)]+)\)//i){
       $primaryKey      = $1 if($1);
    }
    if($columnsstring   =~ s/\sindex\s+(.*?)[,\n\)]//i){
      $index            = $1;
    }
    @foreignKeys = $columnsstring =~ m/\s*?(foreign\s+key\s*?\([^)]+\)\s+references\s*?[^\s\(]+\s*?\([^)]+\))/gi;
    $columnsstring =~ s/\s*?(foreign\s+key\s*?\([^)]+\)\s+references\s*?[^\s\(]+\s*?\([^)]+\))//gi;

    my @columns         = split(/,\s*/,$columnsstring);
       @columns         = grep{$_ !~ /^\s*?$/}@columns;
    $_ =~ s/^\s*// for(@columns);
    push(@foreignKeys,grep{/foreign\s+key/i || /references/i}@columns);
    my ($pK_candidate)  = grep{/primary\s+key/i}@columns;
    my $pK_cout         = grep{/primary\s+key/i}@columns;
    $ERROR++ if($pK_cout && $pK_cout > 1);
    unless($ERROR){
      @columns            = grep{$_ !~ /foreign\s+key/i 
                                 && $_ ne ''
                                 && $_ !~ /^primary/i
                                 && $_ !~ /^unique/i
                                 }@columns;
      my @primaryKeys = getTablePrimaryKeys($pK_candidate,$primaryKey);
      @foreignKeys    = getTableForeignKeys($tablename,\@tableArray,@foreignKeys);
      my @tmpArray    = $tableObject->stringsToTableCols(@columns);
      $tableObject->columns(\@tmpArray);
      $tableObject->name($tablename);
      $tableObject->key(\@primaryKeys);
      $tableObject->relations(\@foreignKeys);
      push(@tableArray,$tableObject);
    }
  }
  return \@tableArray;
}# createStructure

sub getTablePrimaryKeys{
  my ($candConstraint,$candTblConstraint) = @_;
  my @names;
  if($candTblConstraint){
    @names = split(/,/,$candTblConstraint);
    $_ =~ s!^\s!! for(@names);
  }
  elsif($candConstraint){
    @names = (split(/\s/,$candConstraint,2))[0];
  }
  return @names;
}# getTablePrimaryKeys

sub getTableForeignKeys{
  my ($name,$arref,@array) = @_;
  my %seen;
  my @keys = grep{/foreign\s+key/i}@array;
  @seen{@keys} = 1;
  my @references = grep{!$seen{$_}++}@array;
  my @fkeys;
  for my $key(@keys){
    my ($localcols) = $key =~ /foreign\s+key\s*\(([^\)]+)/i;
    my ($refTbl,$refColst) = $key =~ /references\s*?([^\s\(]+)\s*?\(([^\)]+)/i;
    my @locCols = split(/,/,$localcols);
    $_ =~ s/\s//g for(@locCols);
    my @refCols = split(/,/,$refColst);
    $_ =~ s/\s//g for(@refCols);
    $ERROR++ unless(scalar(@locCols) == scalar(@refCols));
    unless($ERROR){
      for my $i(0..$#locCols){
        push(@fkeys,[1,$name.'.'.$locCols[$i],$refTbl.'.'.$refCols[$i]]);
      }
    }
  }

  for my $reference(@references){
    my ($colname) = split(/\s/,$reference,2);
    my ($refTbl)  = $reference =~ /references\s*?([^\s\(]+)/i;
    my ($table)   = grep{$_->name() eq $refTbl}@$arref;
    $ERROR++ unless($table);
    unless($ERROR){
      my (@primaryKeys) = $table->key();
      $ERROR++ unless(scalar(@primaryKeys) == 1);
      unless($ERROR){
        push(@fkeys,[1,$name.'.'.$colname,$refTbl.'.'.$primaryKeys[0]]);
        $table->addRelation([1,$name.'.'.$colname,$refTbl.'.'.$primaryKeys[0]]);
      }
    }
  }
  return @fkeys;
}# getTableForeignKeys

sub getForeignKeys{
  my @rels = @_;
  my %relations;
  my @foreignKeys;
  for my $rel(@rels){
    next unless $rel;
    my $start           = (split(/\./,$rel->[1]))[1];
    my ($table,$target) =  split(/\./,$rel->[2]);
    push(@{$relations{$table}},[$start,$target]);
  }
  for my $key(keys(%relations)){
    my $string  = 'FOREIGN KEY ('.join(',',map{$_->[0]}@{$relations{$key}}).')';
       $string .= " REFERENCES $key(".join(',',map{$_->[1]}@{$relations{$key}}).')';
    push(@foreignKeys,$string)
  }
  return @foreignKeys;
}# getForeignKeys

1;

__END__

=head1 METHODS

=head2 new

=head2 parsefile

=head2 getForeignKeys

=head2 getTableForeignKeys

=head2 getTablePrimaryKeys

=head2 getSQL

=head2 writeSQL

=head2 createStructure
