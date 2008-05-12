package FabForce::DBDesigner4::XML;

use 5.006001;
use strict;
use warnings;
use XML::Twig;
use XML::Writer;
use IO::File;
use FabForce::DBDesigner4::Table qw(:const);

our $VERSION     = '0.03';

sub new{
    my ($class) = @_;
    my $self = {};
    bless $self,$class;
    
    $self->_reset_tables;
    $self->_is_fabforce( 0 );
    $self->_id( 0 );
    $self->_reset_columns;
    $self->_reset_tableids;
    $self->_reset_relationsid;
    
    return $self;
}# new

sub writeXML{
    my ($self,$structref,$file) = @_;
    return unless(ref($structref) eq 'ARRAY');
    
    $self->_reset_tableids;
    $self->_id( 0 );
    $self->_reset_relationsid;
    
    my $fh = (defined $file) ? IO::File->new(">$file") : \*STDOUT;
    my $xml = XML::Writer->new(OUTPUT => $fh, UNSAFE => 1, NEWLINE => 1);
    $xml->xmlDecl('ISO-8859-1','yes');
    $xml->startTag("DBMODEL",version => "4.0");
    # general settings for DBDesigner
    $xml->startTag("SETTINGS");
    $xml->raw(_constants('DATATYPEGROUPS'));
    $xml->raw(_constants('DATATYPES'));
    $xml->raw(_constants('REGIONCOLORS'));
    $xml->endTag("SETTINGS");
    # metadata
    $xml->startTag("METADATA");
    $xml->startTag("TABLES");
    $xml->raw(_printTables($self,$structref));
    $xml->endTag("TABLES");
    $xml->startTag("RELATIONS");
    $xml->raw(_printRelations($self,$structref));
    $xml->endTag("RELATIONS");
    $xml->endTag("METADATA");
    # plugindata
    $xml->startTag("PLUGINDATA");
    $xml->endTag("PLUGINDATA");
    # querydata
    $xml->startTag("QUERYDATA");
    $xml->endTag("QUERYDATA");
    # linked models
    $xml->startTag("LINKEDMODELS");
    $xml->endTag("LINKEDMODELS");
    $xml->endTag("DBMODEL");
    $xml->end();
    $fh->close() if(ref($fh) ne 'GLOB');
}# writeXML

sub parsefile{
    my ($self,$filename) = @_;
    return unless $filename;
    $self->_reset_tables;
    $self->_is_fabforce( 0 );
    my $parser  = XML::Twig->new(twig_handlers => { 
        'TABLE'       => sub{_tables($self,@_)},
        'COLUMN'      => sub{_column($self,@_)},
        'RELATION'    => sub{_relation($self,@_)},
        'INDEXCOLUMN' => sub{_index($self,@_)},
        'DBMODEL'     => sub{$self->_is_fabforce(1)},
    });
    $parser->parsefile($filename);
    my $root = $parser->root;
    return unless($self->_is_fabforce);
    
    for my $table( $self->_all_tables ){
        $table->columns( $self->_table_columns( $table->name ) );
        $table->key( $self->_key( $table->name ) );
    }

    return [ $self->_all_tables ];
}# parsefile

sub _tables{
    my ($self,$t,$table) = @_;
    
    my $name = $table->{att}->{Tablename};
    my $xPos = $table->{att}->{XPos};
    my $yPos = $table->{att}->{YPos};
    
    my $tableobj = FabForce::DBDesigner4::Table->new();
    $tableobj->name($name);
    $tableobj->coords([$xPos,$yPos,0,0]);
    
    $self->_add_table( $tableobj );
    $self->_tableid( $table->{att}->{ID}, $name );
}# _tables

sub _column{
    my ($self,$t,$col) = @_;
    
    my $parent_table   = $col->{parent}->{parent}->{att}->{Tablename};
    my $name           = $col->{att}->{ColName};
    my $datatype       = _datatypes('id2name',$col->{att}->{idDatatype});
    my $notnull        = $col->{att}->{NotNull} ? 'NOT NULL' : '';
    my $default        = $col->{att}->{DefaultValue} || '';
    my $autoinc        = $col->{att}->{AutoInc} ? 'AUTOINCREMENT' : '';
    
    my $info           = '';
    $info .= $notnull.' '              if($notnull);
    $info .= "DEFAULT '".$default."' " if($default);
    $info .= $autoinc                  if($autoinc);
    
    $self->_add_columns( $parent_table, {$name => [$datatype,$info]} );
    $self->_key( $parent_table, $name ) if $col->{att}->{PrimaryKey};
}# _column

sub _relation{
    my ($self,$t,$rel) = @_;
    
    my $src       = $self->_tableid( $rel->{att}->{SrcTable} );
    my @relations = split(/\\n/,$rel->{att}->{FKFields});
    my ($obj)     = grep{$_->name() eq $src}$self->_all_tables;
    my $f_id      = $self->_tableid( $rel->{att}->{DestTable} );
    my ($f_table) = grep{$_->name() eq $f_id}$self->_all_tables;
    my $type      = $rel->{att}->{Kind};
    
    for my $relation(@relations){
        my ($owncol,$foreign) = split(/=/,$relation,2);
        $obj->addRelation(    [ 1, $f_id.'.'.$foreign, $src.'.'.$owncol, $type ]);
        $f_table->addRelation([ 1, $f_id.'.'.$foreign, $src.'.'.$owncol, $type ]);
    }
}# _relation

sub _index{
    my ($self) = @_;
}# _index

sub _printTables{
    my ($self,$struct) = @_;
    my %optionselected = (0 => [1,5,6,6,19,20,33,34,35],
                          1 => [1,2,3,4,5],
                          );
    my $string      = '';
    # table attributes
    my @att_order = qw(ID Tablename PrevTableName XPos YPos TableType TablePrefix 
                       nmTable Temporary UseStandardInserts StandardInserts TableOptions 
                       Comments Collapsed IsLinkedObject IDLinkedModel Obj_id_Linked OrderPos);
                         
    # column attributes
    my @att_names = qw(ID ColName PrevColName Pos idDatatype DatatypeParams Width
                       Prec PrimaryKey NotNull AutoInc IsForeignKey DefaultValue Comments);
                       
    for my $table(@{$struct}){
        my $id = $self->_id;
        $self->_id( $id+1 );
        my $attributes = '';
        my $tablename  = $table->name();
        $self->_tableid( $self->_id, $tablename );
        for my $att(@att_order){
            my $value = '';
            if($att eq 'ID'){
              $value = $self->_id;
            }
            elsif($att eq 'Tablename'){
              $value = $table->name();
            }
            elsif($att eq 'XPos'){
              $value = ($table->coords())[0] || $self->_id * 20;
            }
            elsif($att eq 'YPos'){
              $value = ($table->coords())[1] || $self->_id * 30;
            }
            elsif($att eq 'TableType'){
              $value = 'MyISAM';
            }
            elsif($att eq 'PrevTableName'){
                $value = 'Table_'.sprintf("%02d",$self->_id);
            }
            $attributes .= ' '.$att.'="'.$value.'"';
        }
        $string .= '<TABLE'.$attributes.">\n";
        $string .= "<COLUMNS>\n";
        my $col_position = 0;
        for my $col($table->columns()){
            my $id = $self->_id;
            $self->_id( $id+1 );
            my $col_att     = '';
            my $columnname  = '';
            my $datatype_id = 0;
            for(@att_names){
                my $value = '1';
                if($_ eq 'IsForeignKey'){
                }
                elsif($_ eq 'ID'){
                    $value = $self->_id;
                }
                elsif($_ eq 'ColName'){
                    $value = (split(/\s/,$col,2))[0];
                    $columnname = $value;
                }
                elsif($_ eq 'idDatatype'){
                    my $dt = (split(/\s+/,$col,3))[1];
                    $datatype_id = _datatypes('name2id',uc($dt));
                }
                elsif($_ eq 'PrimaryKey'){
                    $value = grep{$_ eq $columnname}$table->key() ? 1 : 0;
                }
                elsif($_ eq 'NotNull'){
                    $value = $col =~ /not\s+null/i ? 1 : 0;
                }
                elsif($_ eq 'AutoInc'){
                    $value = $col =~ /autoincrement/i ? 1 : 0;
                }
                elsif($_ eq 'DefaultValue'){
                    ($value) = $col =~ /default\s+([^\s]+)/i;
                    $value ||= '';
                }
                $col_att .= " ".$_.'="'.$value.'"';
            }
            my $start = '<COLUMN'.$col_att.">\n";
            $start   .= "  <OPTIONSELECTED>\n";
            for my $val(0,1){
                $start   .= '    <OPTIONSELECT Value="'.$val.'" />'."\n" for(grep{$_ == $datatype_id}@{$optionselected{$val}});
            }
            $start   .= "  </OPTIONSELECTED>\n";
            $start   .= "</COLUMN>\n";
            $string  .= $start;
        
            ++$col_position;
        }
        $string .= "</COLUMNS>\n";
      
        my @relations_start  = grep{$_->[2] =~ /^$tablename\./}$table->relations();
        my @relations_end    = grep{$_->[1] =~ /^$tablename\./}$table->relations();
        my $relations_string = '';
      
        if(@relations_start){
            $relations_string = "<RELATIONS_START>\n";
            for my $rel_start(@relations_start){
                my $key = join('',@$rel_start);
                my $relationid = $self->_id;
                if( $self->_relationsid( $key ) ){
                    $relationid = $self->_relationsid( $key );
                }
                else{
                    my $id = $self->_id;
                    $self->_relationsid( $key, $id );
                    $self->_id( $id+1 );
                }
                $relations_string .= qq~  <RELATION_START ID="$relationid">\n~;
            }
            $relations_string .= "</RELATIONS_START>\n";
        }
      
        if(@relations_end){
            $relations_string .= "<RELATIONS_END>\n";
            for my $rel_end(@relations_end){
                my $key = join('',@$rel_end);
                my $relationid = $self->_id;
                if( $self->_relationsid( $key ) ){
                    $relationid = $self->_relationsid( $key );
                }
                else{
                    my $id = $self->_id;
                    $self->_relationsid( $key, $id );
                    $self->_id( $id+1 );
                }
                $relations_string .= qq~  <RELATION_END ID="$relationid">\n~;
            }
            $relations_string .= "</RELATIONS_END>\n";
            $string .= $relations_string;
        }
        $string .= "</TABLE>\n";
    }
    return $string
}# _printTable

sub _id{
    my ($self,$value) = @_;
    $self->{_ID_} = $value if defined $value;
    return $self->{_ID_};
}

sub _is_fabforce{
    my ($self,$value) = @_;
    $self->{_ISFABFORCE_} = $value if defined $value;
    return $self->{_ISFABFORCE_};
}

sub _add_table{
    my ($self,$table) = @_;
    push @{ $self->{_TABLES_} }, $table;
}

sub _reset_tables{
    my ($self) = @_;
    $self->{_TABLES_} = [];
}

sub _all_tables{
    my ($self) = @_;
    
    return @{ $self->{_TABLES_} };
}

sub _reset_columns{
    my ($self) = @_;
    $self->{_COLUMNS_} = {};
}

sub _table_columns{
    my ($self,$name) = @_;
    return $self->{_COLUMNS_}->{$name} if exists $self->{_COLUMNS_}->{$name};
    return;
}

sub _add_columns{
    my ($self,$table,$value) = @_;
    push @{ $self->{_COLUMNS_}->{$table} }, $value if defined $value;
}

sub _reset_relationsid{
    my ($self) = @_;
    $self->{_RELATIONSID_} = {};
}

sub _relationsid{
    my ($self,$key,$value) = @_;
    $self->{_RELATIONSID_}->{$key} = $value if defined $value;
    return $self->{_RELATIONSID_}->{$key} if exists $self->{_RELATIONSID_}->{$key};
    return;
}

sub _reset_tableids{
    my ($self) = @_;
    $self->{_TABLEIDS_} = {};
}

sub _tableid{
    my ($self,$id,$value) = @_;
    $self->{_TABLEIDS_}->{$id} = $value if defined $value;
    return $self->{_TABLEIDS_}->{$id} if exists $self->{_TABLEIDS_}->{$id};
    return;
}

sub _key{
    my ($self,$table,$value) = @_;
    push @{ $self->{_KEYS_}->{$table} }, $value if defined $value;
    return $self->{_KEYS_}->{$table} if exists $self->{_KEYS_}->{$table};
    return;
}

sub _printRelations{
    my ($self,$struct) = @_;
    return " ";
}# _printRelations

sub _datatypes{
    my ($type,$key) = @_;
    $key = uc($key);
    my %name2id = (
                   'TINYINT'            =>  1,
                   'SMALLINT'           =>  2,
                   'MEDIUMINT'          =>  3,
                   'INT'                =>  4,
                   'INTEGER'            =>  5,
                   'BIGINT'             =>  6,
                   'FLOAT'              =>  7,
                   'DOUBLE'             =>  9,
                   'DOUBLE PRECISION'   => 10,
                   'REAL'               => 11,
                   'DECIMAL'            => 12,
                   'NUMERIC'            => 13,
                   'DATE'               => 14,
                   'DATETIME'           => 15,
                   'TIMESTAMP'          => 16,
                   'TIME'               => 17,
                   'YEAR'               => 18,
                   'CHAR'               => 19,
                   'VARCHAR'            => 20,
                   'BIT'                => 21,
                   'BOOL'               => 22,
                   'TINYBLOB'           => 23,
                   'BLOB'               => 24,
                   'MEDIUMBLOB'         => 25,
                   'LONGBLOB'           => 26,
                   'TINYTEXT'           => 27,
                   'TEXT'               => 28,
                   'MEDIUMTEXT'         => 29,
                   'LONGTEXT'           => 30,
                   'ENUM'               => 31,
                   'SET'                => 32,
                   'Varchar(20)'        => 33,
                   'Varchar(45)'        => 34,
                   'Varchar(255)'       => 35,
                   'GEOMETRY'           => 36,
                   'LINESTRING'         => 38,
                   'POLYGON'            => 39,
                   'MULTIPOINT'         => 40,
                   'MULTILINESTRING'    => 41,
                   'MULTIPOLYGON'       => 42,
                   'GEOMETRYCOLLECTION' => 43,
                  );
    my %id2name;
    for( keys %name2id ){
        $id2name{$name2id{$_}} = uc($_);
        $name2id{uc($_)}       = $name2id{$_};
        $name2id{lc($_)}       = $name2id{$_};
    }
    
    my $value;
    if($type eq 'name2id' && exists($name2id{$key})){
      $value = $name2id{$key};
    }
    elsif($type eq 'id2name' && exists($id2name{$key})){
      $value = $id2name{$key};
    }
    else{
        #print ">>$key<<\n\n";
        #print Dumper(\%name2id);
        $value = 35;
    }
    
    return $value;
}# _datatypes

sub _constants{
    my ($name) = @_;
    my %constants = (
    DATATYPEGROUPS => qq~<DATATYPEGROUPS>
<DATATYPEGROUP Name="Numeric Types" Icon="1" />
<DATATYPEGROUP Name="Date and Time Types" Icon="2" />
<DATATYPEGROUP Name="String Types" Icon="3" />
<DATATYPEGROUP Name="Blob and Text Types" Icon="4" />
<DATATYPEGROUP Name="User defined Types" Icon="5" />
<DATATYPEGROUP Name="Geographic Types" Icon="6" />
</DATATYPEGROUPS>~,
    DATATYPES => qq~<DATATYPES>
<DATATYPE ID="1" IDGroup="0" TypeName="TINYINT" Description="A very small integer. The signed range is -128 to 127. The unsigned range is 0 to 255." ParamCount="1" OptionCount="2" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
<PARAMS>
<PARAM Name="length" />
</PARAMS>
<OPTIONS>
<OPTION Name="UNSIGNED" Default="1" />
<OPTION Name="ZEROFILL" Default="0" />
</OPTIONS>
</DATATYPE>
<DATATYPE ID="2" IDGroup="0" TypeName="SMALLINT" Description="A small integer. The signed range is -32768 to 32767. The unsigned range is 0 to 65535." ParamCount="1" OptionCount="2" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
<PARAMS>
<PARAM Name="length" />
</PARAMS>
<OPTIONS>
<OPTION Name="UNSIGNED" Default="1" />
<OPTION Name="ZEROFILL" Default="0" />
</OPTIONS>
</DATATYPE>
<DATATYPE ID="3" IDGroup="0" TypeName="MEDIUMINT" Description="A medium-size integer. The signed range is -8388608 to 8388607. The unsigned range is 0 to 16777215." ParamCount="1" OptionCount="2" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
<PARAMS>
<PARAM Name="length" />
</PARAMS>
<OPTIONS>
<OPTION Name="UNSIGNED" Default="1" />
<OPTION Name="ZEROFILL" Default="0" />
</OPTIONS>
</DATATYPE>
<DATATYPE ID="4" IDGroup="0" TypeName="INT" Description="A normal-size integer. The signed range is -2147483648 to 2147483647. The unsigned range is 0 to 4294967295." ParamCount="1" OptionCount="2" ParamRequired="0" EditParamsAsString="0" SynonymGroup="1" PhysicalMapping="0" PhysicalTypeName="" >
<PARAMS>
<PARAM Name="length" />
</PARAMS>
<OPTIONS>
<OPTION Name="UNSIGNED" Default="0" />
<OPTION Name="ZEROFILL" Default="0" />
</OPTIONS>
</DATATYPE>
<DATATYPE ID="5" IDGroup="0" TypeName="INTEGER" Description="A normal-size integer. The signed range is -2147483648 to 2147483647. The unsigned range is 0 to 4294967295." ParamCount="1" OptionCount="2" ParamRequired="0" EditParamsAsString="0" SynonymGroup="1" PhysicalMapping="0" PhysicalTypeName="" >
<PARAMS>
<PARAM Name="length" />
</PARAMS>
<OPTIONS>
<OPTION Name="UNSIGNED" Default="1" />
<OPTION Name="ZEROFILL" Default="0" />
</OPTIONS>
</DATATYPE>
<DATATYPE ID="6" IDGroup="0" TypeName="BIGINT" Description="A large integer. The signed range is -9223372036854775808 to 9223372036854775807. The unsigned range is 0 to 18446744073709551615." ParamCount="1" OptionCount="2" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
<PARAMS>
<PARAM Name="length" />
</PARAMS>
<OPTIONS>
<OPTION Name="UNSIGNED" Default="0" />
<OPTION Name="ZEROFILL" Default="0" />
</OPTIONS>
</DATATYPE>
<DATATYPE ID="7" IDGroup="0" TypeName="FLOAT" Description="A small (single-precision) floating-point number. Cannot be unsigned. Allowable values are -3.402823466E+38 to -1.175494351E-38, 0, and 1.175494351E-38 to 3.402823466E+38." ParamCount="1" OptionCount="1" ParamRequired="1" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
<PARAMS>
<PARAM Name="precision" />
</PARAMS>
<OPTIONS>
<OPTION Name="ZEROFILL" Default="0" />
</OPTIONS>
</DATATYPE>
<DATATYPE ID="8" IDGroup="0" TypeName="FLOAT" Description="A small (single-precision) floating-point number. Cannot be unsigned. Allowable values are -3.402823466E+38 to -1.175494351E-38, 0, and 1.175494351E-38 to 3.402823466E+38." ParamCount="2" OptionCount="1" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
<PARAMS>
<PARAM Name="length" />
<PARAM Name="decimals" />
</PARAMS>
<OPTIONS>
<OPTION Name="ZEROFILL" Default="0" />
</OPTIONS>
</DATATYPE>
<DATATYPE ID="9" IDGroup="0" TypeName="DOUBLE" Description="A normal-size (double-precision) floating-point number. Cannot be unsigned. Allowable values are -1.7976931348623157E+308 to -2.2250738585072014E-308, 0, and 2.2250738585072014E-308 to 1.7976931348623157E+308." ParamCount="2" OptionCount="1" ParamRequired="0" EditParamsAsString="0" SynonymGroup="2" PhysicalMapping="0" PhysicalTypeName="" >
<PARAMS>
<PARAM Name="length" />
<PARAM Name="decimals" />
</PARAMS>
<OPTIONS>
<OPTION Name="ZEROFILL" Default="0" />
</OPTIONS>
</DATATYPE>
<DATATYPE ID="10" IDGroup="0" TypeName="DOUBLE PRECISION" Description="This is a synonym for DOUBLE." ParamCount="2" OptionCount="1" ParamRequired="0" EditParamsAsString="0" SynonymGroup="2" PhysicalMapping="0" PhysicalTypeName="" >
<PARAMS>
<PARAM Name="length" />
<PARAM Name="decimals" />
</PARAMS>
<OPTIONS>
<OPTION Name="ZEROFILL" Default="0" />
</OPTIONS>
</DATATYPE>
<DATATYPE ID="11" IDGroup="0" TypeName="REAL" Description="This is a synonym for DOUBLE." ParamCount="2" OptionCount="1" ParamRequired="0" EditParamsAsString="0" SynonymGroup="2" PhysicalMapping="0" PhysicalTypeName="" >
<PARAMS>
<PARAM Name="length" />
<PARAM Name="decimals" />
</PARAMS>
<OPTIONS>
<OPTION Name="ZEROFILL" Default="0" />
</OPTIONS>
</DATATYPE>
<DATATYPE ID="12" IDGroup="0" TypeName="DECIMAL" Description="An unpacked floating-point number. Cannot be unsigned. Behaves like a CHAR column." ParamCount="2" OptionCount="1" ParamRequired="0" EditParamsAsString="0" SynonymGroup="3" PhysicalMapping="0" PhysicalTypeName="" >
<PARAMS>
<PARAM Name="length" />
<PARAM Name="decimals" />
</PARAMS>
<OPTIONS>
<OPTION Name="ZEROFILL" Default="0" />
</OPTIONS>
</DATATYPE>
<DATATYPE ID="13" IDGroup="0" TypeName="NUMERIC" Description="This is a synonym for DECIMAL." ParamCount="2" OptionCount="1" ParamRequired="1" EditParamsAsString="0" SynonymGroup="3" PhysicalMapping="0" PhysicalTypeName="" >
<PARAMS>
<PARAM Name="length" />
<PARAM Name="decimals" />
</PARAMS>
<OPTIONS>
<OPTION Name="ZEROFILL" Default="0" />
</OPTIONS>
</DATATYPE>
<DATATYPE ID="14" IDGroup="1" TypeName="DATE" Description="A date. The supported range is \\a1000-01-01\\a to \\a9999-12-31\\a." ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
<DATATYPE ID="15" IDGroup="1" TypeName="DATETIME" Description="A date and time combination. The supported range is \\a1000-01-01 00:00:00\\a to \\a9999-12-31 23:59:59\\a." ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
<DATATYPE ID="16" IDGroup="1" TypeName="TIMESTAMP" Description="A timestamp. The range is \\a1970-01-01 00:00:00\\a to sometime in the year 2037. The length can be 14 (or missing), 12, 10, 8, 6, 4, or 2 representing YYYYMMDDHHMMSS, ... , YYYYMMDD, ... , YY formats." ParamCount="1" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
<PARAMS>
<PARAM Name="length" />
</PARAMS>
</DATATYPE>
<DATATYPE ID="17" IDGroup="1" TypeName="TIME" Description="A time. The range is \\a-838:59:59\\a to \\a838:59:59\\a." ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
<DATATYPE ID="18" IDGroup="1" TypeName="YEAR" Description="A year in 2- or 4-digit format (default is 4-digit)." ParamCount="1" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
<PARAMS>
<PARAM Name="length" />
</PARAMS>
</DATATYPE>
<DATATYPE ID="19" IDGroup="2" TypeName="CHAR" Description="A fixed-length string (1 to 255 characters) that is always right-padded with spaces to the specified length when stored. values are sorted and compared in case-insensitive fashion according to the default character set unless the BINARY keyword is given." ParamCount="1" OptionCount="1" ParamRequired="1" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
<PARAMS>
<PARAM Name="length" />
</PARAMS>
<OPTIONS>
<OPTION Name="BINARY" Default="0" />
</OPTIONS>
</DATATYPE>
<DATATYPE ID="20" IDGroup="2" TypeName="VARCHAR" Description="A variable-length string (1 to 255 characters). Values are sorted and compared in case-sensitive fashion unless the BINARY keyword is given." ParamCount="1" OptionCount="1" ParamRequired="1" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
<PARAMS>
<PARAM Name="length" />
</PARAMS>
<OPTIONS>
<OPTION Name="BINARY" Default="0" />
</OPTIONS>
</DATATYPE>
<DATATYPE ID="21" IDGroup="2" TypeName="BIT" Description="This is a synonym for CHAR(1)." ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
<DATATYPE ID="22" IDGroup="2" TypeName="BOOL" Description="This is a synonym for CHAR(1)." ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
<DATATYPE ID="23" IDGroup="3" TypeName="TINYBLOB" Description="A column maximum length of 255 (2^8 - 1) characters. Values are sorted and compared in case-sensitive fashion." ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
<DATATYPE ID="24" IDGroup="3" TypeName="BLOB" Description="A column maximum length of 65535 (2^16 - 1) characters. Values are sorted and compared in case-sensitive fashion." ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
<DATATYPE ID="25" IDGroup="3" TypeName="MEDIUMBLOB" Description="A column maximum length of 16777215 (2^24 - 1) characters. Values are sorted and compared in case-sensitive fashion." ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
<DATATYPE ID="26" IDGroup="3" TypeName="LONGBLOB" Description="A column maximum length of 4294967295 (2^32 - 1) characters. Values are sorted and compared in case-sensitive fashion." ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
<DATATYPE ID="27" IDGroup="3" TypeName="TINYTEXT" Description="A column maximum length of 255 (2^8 - 1) characters." ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
<DATATYPE ID="28" IDGroup="3" TypeName="TEXT" Description="A column maximum length of 65535 (2^16 - 1) characters." ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
<DATATYPE ID="29" IDGroup="3" TypeName="MEDIUMTEXT" Description="A column maximum length of 16777215 (2^24 - 1) characters." ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
<DATATYPE ID="30" IDGroup="3" TypeName="LONGTEXT" Description="A column maximum length of 4294967295 (2^32 - 1) characters." ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
<DATATYPE ID="31" IDGroup="3" TypeName="ENUM" Description="An enumeration. A string object that can have only one value, chosen from the list of values." ParamCount="1" OptionCount="0" ParamRequired="1" EditParamsAsString="1" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
<PARAMS>
<PARAM Name="values" />
</PARAMS>
</DATATYPE>
<DATATYPE ID="32" IDGroup="3" TypeName="SET" Description="A set. A string object that can have zero or more values, each of which must be chosen from the list of values." ParamCount="1" OptionCount="0" ParamRequired="1" EditParamsAsString="1" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
<PARAMS>
<PARAM Name="values" />
</PARAMS>
</DATATYPE>
<DATATYPE ID="33" IDGroup="4" TypeName="Varchar(20)" Description="" ParamCount="0" OptionCount="1" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
<OPTIONS>
<OPTION Name="BINARY" Default="0" />
</OPTIONS>
</DATATYPE>
<DATATYPE ID="34" IDGroup="4" TypeName="Varchar(45)" Description="" ParamCount="0" OptionCount="1" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
<OPTIONS>
<OPTION Name="BINARY" Default="0" />
</OPTIONS>
</DATATYPE>
<DATATYPE ID="35" IDGroup="4" TypeName="Varchar(255)" Description="" ParamCount="0" OptionCount="1" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
<OPTIONS>
<OPTION Name="BINARY" Default="0" />
</OPTIONS>
</DATATYPE>
<DATATYPE ID="36" IDGroup="5" TypeName="GEOMETRY" Description="Geographic Datatype" ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
<DATATYPE ID="38" IDGroup="5" TypeName="LINESTRING" Description="Geographic Datatype" ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
<DATATYPE ID="39" IDGroup="5" TypeName="POLYGON" Description="Geographic Datatype" ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
<DATATYPE ID="40" IDGroup="5" TypeName="MULTIPOINT" Description="Geographic Datatype" ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
<DATATYPE ID="41" IDGroup="5" TypeName="MULTILINESTRING" Description="Geographic Datatype" ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
<DATATYPE ID="42" IDGroup="5" TypeName="MULTIPOLYGON" Description="Geographic Datatype" ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
<DATATYPE ID="43" IDGroup="5" TypeName="GEOMETRYCOLLECTION" Description="Geographic Datatype" ParamCount="0" OptionCount="0" ParamRequired="0" EditParamsAsString="0" SynonymGroup="0" PhysicalMapping="0" PhysicalTypeName="" >
</DATATYPE>
</DATATYPES>~, 
                  REGIONCOLORS => qq~<REGIONCOLORS>
<REGIONCOLOR Color="Red=#FFEEEC" />
<REGIONCOLOR Color="Yellow=#FEFDED" />
<REGIONCOLOR Color="Green=#EAFFE5" />
<REGIONCOLOR Color="Cyan=#ECFDFF" />
<REGIONCOLOR Color="Blue=#F0F1FE" />
<REGIONCOLOR Color="Magenta=#FFEBFA" />
</REGIONCOLORS>~,

                  );
  return $constants{$name};
}# _constants

1;
__END__
=pod

=head1 METHODS

=head2 new

=head2 writeXML

=head2 parsefile
