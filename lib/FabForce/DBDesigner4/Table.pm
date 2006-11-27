package FabForce::DBDesigner4::Table;

use strict;
use warnings;

require Exporter;
our @ISA         = qw(Exporter);;
our @EXPORT      = ();
our @EXPORT_OK   = ();
our %EXPORT_TAGS = ();
our $VERSION     = '0.01';

sub new{
  my ($class,%args) = @_;
  my $self = {};
  
  bless $self,$class;
  
  $self->{COORDS}    = [];
  $self->{COLUMNS}   = [];
  $self->{NAME}      = '';
  $self->{RELATIONS} = [];
  $self->{KEY}       = [];
  $self->{ATTRIBUTE} = {};

  $self->{COORDS}    = $args{-coords}    if(_checkArg('coords'   , $args{-coords}   ));
  $self->{COLUMNS}   = $args{-columns}   if(_checkArg('columns'  , $args{-columns}  ));
  $self->{NAME}      = $args{-name}      if(_checkArg('name'     , $args{-name}     ));
  $self->{RELATIONS} = $args{-relations} if(_checkArg('relations', $args{-relations}));
  $self->{KEY}       = $args{-key}       if(_checkArg('key'      , $args{-key}      ));
  $self->{INDEX}     = $args{-index}     if(_checkArg('index'    , $args{-index}    ));
  $self->{ATTRIBUTE} = $args{-attr}      if(_checkArg('attribute', $args{-attr}     ));
  
  return $self;
}# new

sub columns{
  my ($self,$ar) = @_;
  unless($ar && _checkArg('columns',$ar)){
    my @columns;
    for my $col(@{$self->{COLUMNS}}){
      my $string = join('',keys(%$col));
      for my $val(values(%$col)){
        for my $elem(@$val){
          $string .= " ".$elem if(defined $elem);
        }
      }
      push(@columns,$string);
    }
    return @columns;
  }
  $self->{COLUMNS} = $ar;
  return 1;
}# columns

sub columnType{
  my ($self,$name) = @_;
  return undef unless($name);
  my $type = '';
  for(0..scalar(@{$self->{COLUMNS}})-1){
    my ($key) = keys(%{$self->{COLUMNS}->[$_]});
    if($key eq $name){
      $type = $self->{COLUMNS}->[$_]->{$key}->[0];
      last;
    }
  }
  return $type;
}# columnType

sub columnInfo{
  my ($self,$nr) = @_;
  return $self->{COLUMNS}->[$nr];
}# columnInfo

sub addColumn{
  my ($self,$ar) = @_;
  return undef unless($ar && ref($ar) eq 'ARRAY');
  push(@{$self->{COLUMNS}},{$ar->[0] => [@{$ar}[1,2]]});
  return 1;
}# addColumn

sub stringsToTableCols{
  my ($self,@array) = @_;
  
  my @returnArray;
  for my $col(@array){
    $col =~ s!,\s*?$!!;
    $col =~ s!^\s*!!;
    next if((not defined $col) or $col eq '');
    my ($name,$type,$info) = split(/\s+/,$col,3);
    push(@returnArray,{$name => [$type,$info]});
  }
  
  return @returnArray;
}# arrayToTableCols

sub coords{
  my ($self,$ar) = @_;
  return @{$self->{COORDS}} unless($ar && _checkArg('coords',$ar));
  $self->{COORDS} = $ar;
  return 1;
}# start

sub name{
  my ($self,$value) = @_;
  return $self->{NAME} unless($value && _checkArg('name',$value));
  $self->{NAME} = $value;
  return 1;
}# name

sub relations{
  my ($self,$value) = @_;
  return @{$self->{RELATIONS}} unless($value && _checkArg('relations',$value));
  $self->{RELATIONS} = $value;
  return 1;
}# relations

sub addRelation{
  my ($self,$value) = @_;
  return undef unless($value && ref($value) eq 'ARRAY' && scalar(@$value) == 3);
  push(@{$self->{RELATIONS}},$value);
  return 1;
}# addRelation

sub removeRelation{
  my ($self,$index) = @_;
  return undef unless(defined $index or $index > (scalar(@{$self->{RELATIONS}})-1));
  splice(@{$self->{RELATIONS}},$index,1);
}# removeRelation

sub changeRelation{
  my ($self,$index,$value) = @_;
  return undef unless(defined $index and defined $value);
  $self->{RELATIONS}->[$index]->[0] = $value;
}# changeRelation

sub key{
  my ($self,$value) = @_;
  return @{$self->{KEY}} unless($value && _checkArg('key',$value));
  $self->{KEY} = $value;
  return 1;
}# key

sub tableIndex{
  my ($self,$value) = @_;
  return @{$self->{INDEX}} unless($value && _checkArg('index',$value));
  $self->{INDEX} = $value;
  return 1;
}# tableIndex

sub attribute{
  my ($self,$value) = @_;
  return @{$self->{ATTRIBUTE}} unless($value && _checkArg('attribute',$value));
  $self->{ATTRIBUTE} = $value;
  return 1;
}# attribute

sub _checkArg{
  my ($type,$value) = @_;
  my $return = 0;
  if($value){
    $return = 1 if($type eq 'coords' 
                   && ref($value) eq 'ARRAY' 
                   && scalar(@$value) == 4
                   && !grep{/\D/}@$value);
                   
    $return = 1 if($type eq 'columns'
                   && ref($value) eq 'ARRAY'
                   && !(!grep{ref($_) eq 'HASH'}@$value));
                   
    $return = 1 if($type eq 'name' 
                   && ref(\$value) eq 'SCALAR');
    
    $return = 1 if($type eq 'relations' 
                   && ref($value) eq 'ARRAY'
                   && !(!grep{ref($_) eq 'ARRAY'}@$value));
    
    $return = 1 if($type eq 'key'
                   && ref($value) eq 'ARRAY'
                   && !(!grep{ref(\$_) eq 'SCALAR'}@$value));
    
    $return = 1 if($type eq 'index'
                   && ref($value) eq 'ARRAY'
                   && !(!grep{ref(\$_) eq 'SCALAR'}@$value));
                   
    $return = 1 if($type eq 'attribute'
                   && ref($value) eq 'HASH');
  }
  
  return $return;
}# checkArg

1;
__END__

=head1 DBDesigner4::Table

Each table is an object which contains information about the columns,
the relations and the keys.

Methods of the table-objects

=head2 name

  # set the tablename
  $table->name('tablename');
  # get the tablename
  my $name = $table->name();
  
=head2 columns

  # set the tablecolumns
  my @array = ({'column1' => ['int','not null']});
  $table->columns(\@array);
  
  # get the columns
  print $_,"\n" for($table->columns());
  
=head2 columnType

  # get datatype of n-th column (i.e. 3rd column)
  my $datatype = $table->columnType(3);
  
=head2 columnInfo

  # get info about n-th column (i.e. 4th column)
  print Dumper($table->columnInfo(4));
  
=head2 stringsToTableCols

  # maps column information to hash (needed for columns())
  my @columns = ('col1 varchar(255) primary key', 'col2 int not null');
  my @array   = $table->stringsToTableCols(@columns);

=head2 addColumn

  # add the tablecolumn
  my $column = ['column1','int','not null'];
  $table->addColumn($column);

=head2 relations

  # set relations
  my @relations = ([1,'startTable.startCol','targetTable.targetCol']);
  $table->relations(\@relations);
  # get relations
  print $_,"\n" for($table->relations());

=head2 addRelation

  $table->addRelation([1,'startTable.startCol','targetTable.targetCol']);

=head2 removeRelation

  # removes a relation (i.e. 2nd relation)
  $table->removeRelation(2);

=head2 key

  # set the primary key
  $table->key(['prim1']);
  # get the primary key
  print "the primary key contains these columns:\n";
  print $_,"\n" for($table->key());

=head2 attribute

=head2 changeRelation

=head2 coords

=head2 new

=head2 tableIndex
