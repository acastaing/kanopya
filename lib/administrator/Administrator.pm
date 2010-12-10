# Administrator.pm - Object class of Administrator server

# Kanopya Copyright (C) 2009, 2010, 2011, 2012, 2013 Hedera Technology.

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.

# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; see the file COPYING.  If not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301 USA.

# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.
# Created 14 july 2010

=head1 NAME

Administrator - Administrator object

=head1 SYNOPSIS

    use Administrator;
    
    # Creates administrator
    my $adm = Administrator->new();
    
    # Get object
    $adm->getobject($type : String, %ObjectDefinition);


=head1 DESCRIPTION

Administrator is the main object use to create administrator objects

=head1 METHODS

=cut

package Administrator;


use strict;
use warnings;
use Log::Log4perl "get_logger";
use Data::Dumper;
use NetAddr::IP;
use lib qw(/workspace/mcs/Administrator/Lib /workspace/mcs/Common/Lib);
use AdministratorDB::Schema;
use EntityRights;
use McsExceptions;
use General;
use Entity;
use XML::Simple;
use DateTime;
use NetworkManager;
use NodeManager;

my $log = get_logger("administrator");
my $errmsg;

#$VERSION = do { my @r = (q$Revision: 0.1 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };


my $oneinstance;

=head2 Administrator::new (%args)
	
	Class : Public
	
	Desc : Instanciate Administrator object and check user authentication
	
	args: 
		login : String : user login to access to administrator
		password : String : user's password
	return: Administrator instance
	
=cut

sub new {
	my $class = shift;
	my %args = @_;
	
	# If Administrator exists return its already existing instance
	if(defined $oneinstance) { 
		$log->info("Administrator instance retrieved");	
		return $oneinstance;
	}
	
	# Check named arguments
	if ((! exists $args{login} or ! defined $args{login})||
		(! exists $args{password} or ! defined $args{password})) { 
		$errmsg = "Administrator->need a login and password named argument!";
		$log->error($errmsg);
		throw Mcs::Exception::Internal(error => $errmsg); 
	}
	
	my $login = $args{login};
	my $password = $args{password};
	
	my %opts = ();
	my ($schema, $rightschecker);
	my $self = {};
	
	bless $self, $class;
	# Load Administrator config
	# Add singleton
	# Catch exception from DB connection
	eval {
		my $dbi = $self->loadConf();
		$log->debug("dbi connection : $dbi, user : $self->{config}->{dbconf}->{user}, password : $self->{config}->{dbconf}->{password}");
		$schema = AdministratorDB::Schema->connect($dbi, $self->{config}->{dbconf}->{user}, $self->{config}->{dbconf}->{password}, \%opts);

		# When debug is set, all sql queries are printed
		#$schema->storage->debug(1); # or: $ENV{DBIC_TRACE} = 1 in any file
		
		$rightschecker = EntityRights->new( schema => $schema, login => $login, password => $password );
	};
	if ($@) {
		my $error = $@;
		if(ref($error) eq 'Mcs::Exception::LoginFailed') {
			$log->error("Administrator->new : $error");
			rethrow $error;
		} else {
			$log->error("Administrator->new : Error connecting Database $error");
			throw Mcs::Exception::DB(error => "$error");
		} 
	}
	
	$self->{db} = $schema;
	$self->{_rightschecker} = $rightschecker;		
	$oneinstance = $self;
	# Load Manager
	$self->{manager} = {};
	$self->{manager}->{network} = NetworkManager->new(schemas=>$self->{db},
													  internalnetwork => $self->{config}->{internalnetwork});
	
	$self->{manager}->{node} = NodeManager->new(node_rs => $self->{db}->resultset('Node'), adm => $self);
	$log->info("new Administrator instance");
	return $self;
}

=head Administrator::loadConf
	Class : Private
	
	Desc : This method allow to load configuration from xml file 
			/workspace/mcs/Administrator/Conf/administrator.conf
			File Administrator with config hash containing
	
	args: 
	return: Administrator instance
=cut

sub loadConf {
	my $self = shift;
	$self->{config} = XMLin("/opt/kanopya/conf/administrator.conf");
	if (! exists $self->{config}->{internalnetwork}->{ip} ||
		! defined $self->{config}->{internalnetwork}->{ip} ||
		! exists $self->{config}->{internalnetwork}->{mask} ||
		! defined $self->{config}->{internalnetwork}->{mask} ||
		! exists $self->{config}->{internalnetwork}->{gateway} ||
		! defined $self->{config}->{internalnetwork}->{gateway})
		{
			$errmsg = "Administrator->new need internalnetwork definition in config file!";
			$log->error($errmsg);
			throw Mcs::Exception::Internal::IncorrectParam(error => $errmsg);
		}
	
	if (! exists $self->{config}->{dbconf}->{name} ||
		! defined exists $self->{config}->{dbconf}->{name} ||
		! exists $self->{config}->{dbconf}->{password} ||
		! defined exists $self->{config}->{dbconf}->{password} ||
		! exists $self->{config}->{dbconf}->{type} ||
		! defined exists $self->{config}->{dbconf}->{type} ||
		! exists $self->{config}->{dbconf}->{host} ||
		! defined exists $self->{config}->{dbconf}->{host} ||
		! exists $self->{config}->{dbconf}->{user} ||
		! defined exists $self->{config}->{dbconf}->{user} ||
		! exists $self->{config}->{dbconf}->{port} ||
		! defined exists $self->{config}->{dbconf}->{port})
		{
			$errmsg = "Administrator->new need db definition in config file!";
			$log->error($errmsg);
			throw Mcs::Exception::Internal::IncorrectParam(error => $errmsg);
		}

	$log->info("Administrator configuration loaded");
	return "dbi:" . $self->{config}->{dbconf}->{type} .
			":" . $self->{config}->{dbconf}->{name} .
			":" . $self->{config}->{dbconf}->{host} .
			":" . $self->{config}->{dbconf}->{port};
}

=head2 getEntity
	
	Class : Public
	
	Desc : This method allows to get entity object. It
			get _data from table with _getData
			call _newObj on _data
	
	args: 
		type : String : Object Type
		id : int : Object id
		class_path : String : This is an optionnal parameter which allow to instanciate class_path with other DB tables
	Return : a new Entity::<type> with data corresponding to <id> (in <type> table)
	Comment : To modify data in DB call save() on returned obj (after modification)
	
=cut

sub getEntity {
	my $self = shift;
    my %args = @_;
    
    # entity_dbix will contain resultset row integrated into Entity
    # entity_class is Entity Class
    my ($entity_dbix, $entity_class);

	if ((! exists $args{type} or ! defined $args{type}) ||
		(! exists $args{id} or ! defined $args{id})) { 
		$errmsg = "Administrator->_getEntity need a type and an id named argument!";
		$log->error($errmsg);
		throw Mcs::Exception::Internal(error => $errmsg); 
	}
	
	$log->debug( "getEntity( ".join(', ', map( { "$_ => $args{$_}" } keys(%args) )). ");" );
	$log->debug( "_getDbix with table = $args{type} and id = $args{id}");
	$entity_dbix = $self->_getDbix( table => $args{type}, id => $args{id} );
	
	# Test if Dbix is get
	if ( defined $entity_dbix ) {
		$log->debug( "_getEntityClass with type = $args{type}");
		if (! exists $args{class_path} or ! defined $args{class_path}){
			 $entity_class = $self->_getEntityClass(type => $args{type});}
		else {
			$entity_class = $self->_getEntityClass(type => $args{type}, class_path => $args{class_path});}

		# Extension Entity Management
		my $extension = $entity_class->extension();
		if ($extension){
			$log->debug("GetEntity with extension");
			my %attrs;
			my $ext_attrs_rs = $entity_dbix->search_related( $extension );
			while ( my $param = $ext_attrs_rs->next ) {
				$attrs{ $param->name } = $param->value;
			}
			my $entity = $entity_class->new( rightschecker => $self->{_rightschecker}, data => $entity_dbix, ext_attrs => \%attrs); 
			$log->info(ref($entity)." retrieved from database");
			return $entity;
		} else {
			my $entity = $entity_class->new( rightschecker => $self->{_rightschecker}, data => $entity_dbix );
			$log->info(ref($entity)." retrieved from database");
			return $entity;
		}
	} else {
		$errmsg = "Administrator::getEntity(".join(', ', map( { "$_ => $args{$_}" } keys(%args) )). ") : Object not found!"; 
		$log->error($errmsg);
		throw Mcs::Exception::Internal(error => $errmsg);
	}
}

=head2 getEntities
	
	Class : Public
	
	Desc : This method allows to get many entity objects. It
			get allowed object corresponding to where clause in hash param
	
	args: 
		type : String : Objects type
		hash : hashref : this hash describe field and constraint for search
	Return Entities hash 
	
=cut

sub getEntities {
	my $self = shift;
    my %args = @_;
	my @objs = ();
    my ($rs, $entity_class);

	if ((! exists $args{type} or ! defined $args{type}) ||
		(! exists $args{hash} or ! defined $args{hash})) { 
		$errmsg = "Administrator->_getEntityFromHash need a type and a hash named argument!";
		$log->error($errmsg);
		throw Mcs::Exception::Internal(error => $errmsg);
	}
	
	$log->debug( "getEntityFromHash( ".join(', ', map( { "$_ => $args{$_}" } keys(%args) )). ");" );
	$log->debug( "_getDbix with table = $args{type} and hash = $args{hash}");
	$rs = $self->_getDbixFromHash( table => $args{type}, hash => $args{hash} );
	$log->debug('resultset count:'.$rs->count());
	$log->debug( "_getEntityClass with type = $args{type}");
	if (! exists $args{class_path} or ! defined $args{class_path}){
		 $entity_class = $self->_getEntityClass(type => $args{type});}
	else {
		$entity_class = $self->_getEntityClass(type => $args{type}, class_path => $args{class_path});}

	my $extension = $entity_class->extension();

	while ( my $raw = $rs->next ) {
		my $obj;
		if ($extension){
			my %attrs;
			my $ext_attrs_rs = $raw->search_related( $extension );
			while ( my $param = $ext_attrs_rs->next ) {
				$attrs{ $param->name } = $param->value;}
			$obj = $entity_class->new(rightschecker => $self->{_rightschecker}, data => $raw, ext_attrs => \%attrs);}
		else {
			$obj = $entity_class->new(rightschecker => $self->{_rightschecker}, data => $raw );}
		push @objs, $obj;
	}
	return  @objs;
}


#sub getEntities {
#	my $self = shift;
#    my %args = @_;
#	
#	if (! exists $args{type}) { 
#		throw Mcs::Exception::Internal(error => "Administrator->newOp need a type named argument!"); }
#	
#	my @objs = ();
#	my $rs = $self->_getAllDbix( table => $args{type} );
#	my $entity_class = $self->_getEntityClass(type => $args{type});
#	my $extension = $entity_class->extension();
#	while ( my $raw = $rs->next ) {
#		my $obj;
#		if ($extension){
#			my %attrs;
#			my $ext_attrs_rs = $raw->search_related( $extension );
#			while ( my $param = $ext_attrs_rs->next ) {
#				$attrs{ $param->name } = $param->value;}
#			$obj = $entity_class->new(rightschecker => $self->{_rightschecker}, data => $raw, ext_attrs => \%attrs);}
#		else {
#			$obj = $entity_class->new(rightschecker => $self->{_rightschecker}, data => $raw );}
#		push @objs, $obj;
#	}
#    return  @objs;
#}

=head2 countEntities 

	args:
		type : concrete Entity type
	
	Return an integer	

=cut

sub countEntities {
	my $self = shift;
	my %args = @_;
	if (! exists $args{type} or ! defined $args{type}) { 
		$errmsg = "Administrator->countEntities need a type named argument!";
		$log->error($errmsg);
		throw Mcs::Exception::Internal(error => $errmsg); 
	}
	my $count = $self->{db}->resultset($args{type})->count;
	$log->debug("Total number of entities $args{type} : $count");
	return $count;
}

=head2 newEntity
	
	Class : Public
	
	Desc : This method allows to instanciate entity object from hash table
			It Calls _newData and _newObj
	args: 
		type: concrete Entity type
		params: hash ref with key mapped on <type> table column
		
	Return a New Entity::<type> with params as data (not add in db)
	To add data in DB call save() on returned obj
	 
=cut

sub newEntity {
	my $self = shift;
    my %args = @_;

	if ((! exists $args{type} or ! defined $args{type}) ||
		(! exists $args{params} or ! defined $args{params})) { 
		$errmsg = "Administrator->newEntity need params and type named argument!";
		$log->error($errmsg);
		throw Mcs::Exception::Internal(error => $errmsg); 
	}

	$log->debug("newEntity(".join(', ', map( { "$_ => $args{$_}" } keys(%args) )).")");

	# We get class and require Entity::$entity_class
	my $entity_class;
	if (! exists $args{class_path} or ! defined $args{class_path}){
		$entity_class = $self->_getEntityClass(type => $args{type});
	} else {
		$entity_class = $self->_getEntityClass(type => $args{type}, class_path => $args{class_path});}
	
	# We check entity attributes and separate them in two categories :
	#	- ext_attrs
	#	- global_attrs
	my $attrs = $entity_class->checkAttrs(attrs => $args{params});
	
	# We create a new DBIx containing new entity (only global attrs)
	my $entity_data = $self->_newDbix( table =>  $args{type}, row => $attrs->{global} );
	
	# We instanciate entity with DBIx data and rightchecker
	my $new_entity;
	if ($entity_class->extension()) {
		$new_entity = $entity_class->new( data => $entity_data, rightschecker => $self->{_rightschecker}, ext_attrs => $attrs->{extended});
	}
	else {
		$new_entity = $entity_class->new( data => $entity_data, rightschecker => $self->{_rightschecker});
	}
	$log->info(ref($new_entity)." instanciated");
    return $new_entity;
}

=head2 new Op
	
	Class : Public
	
	Desc : This method allows to instanciate entity object from hash table
			It Calls _newData and _newObj
	args : 
		type : concrete Entity::Operation type (Real Operation type (AddMotherboard, MigrateNode, ...))
		params : hash ref with key mapped on <type> table column
		priority : Operation priority (<1000)
		
	Return a New Entity::Operation::type with data from hash (params)
	This Operation is immediatly saved
	
=cut

sub newOp {
	my $self = shift;
	my %args = @_;
	
	if ((! exists $args{priority} or ! defined $args{priority}) ||
		(! exists $args{type} or ! defined $args{type}) ||
		(! exists $args{params} or ! defined $args{params})) {
			$errmsg = "Administrator->newOp need a priority, params and type named argument!";
			$log->error($errmsg); 
			throw Mcs::Exception::Internal(error => $errmsg); 
	}
	#TODO Check if operation is allowed
	my $rank = $self->_get_lastRank() + 1;
	my $user_id = $self->{_rightschecker}->{_user};
	$log->debug("User id in _rightschecker is $user_id");
	my $hoped_execution_time = defined $args{hoped_execution_time} ? time + $args{hoped_execution_time} : undef; 
	my $op_data = $self->_newDbix( table => 'Operation', row => { 	type => $args{type},
																	execution_rank => $rank,
																	user_id => $user_id,
																	priority => $args{priority},
																	creation_date => \"CURRENT_DATE()",
																	creation_time => \"CURRENT_TIME()",
																	hoped_execution_time => $hoped_execution_time
																	});

	my $subclass = $args{type};
	eval {
		require "Operation/$subclass.pm";
	};
	if ($@) {
		$errmsg = "Administrator->newOp : Operation type ($args{type}) does not exist when require Operation::$subclass.pm";
		$log->error($errmsg);
		throw Mcs::Exception::Internal(error => $errmsg);
	}

	my $op = "Operation::$subclass"->new(data => $op_data, administrator => $self, params => $args{params});
	$op->save();
	# We do not return the operation to user.
}

=head2 _getLastRank

	Class : Private
	
	Desc : This method return last operation number

=cut

sub _get_lastRank{
	my $self = shift;
	my $row = $self->{db}->resultset('Operation')->search(undef, {column => 'execution_rank', order_by=> ['execution_rank desc']})->first;
	if (! $row) {
		$log->debug("No previous operation in queue");
		return 0;
	}
	else {
		my $last_in_db = $row->get_column('execution_rank');
		$log->debug("Previous operation in queue is $last_in_db");
		return $last_in_db;	
	}
}

=head2 getNextOp
	
	Class : Public
	
	Desc : This method return next operation to execute

	Returns the concrete Operation with the execution_rank min 
	
=cut

sub getNextOp {
	my $self = shift;
	
	# Get all operation
	my $all_ops = $self->_getDbixFromHash( table => 'Operation', hash => {});
	$log->debug("Get Operation $all_ops");
	
	# Choose the next operation to be treated :
	# if hoped_execution_time is definied, value returned by time function must be superior to hoped_execution_time
	# unless operation is not execute at this moment
	$log->error("Time is : ", time);
	my $op_data = $all_ops->search( 
		{ -or => [ hoped_execution_time => undef, hoped_execution_time => {'<',time}] }, 
		{ order_by => { -asc => 'execution_rank' }}   
	)->next();
	
	# if no other operation to Operation::$subclassbe treated, return undef
	if(! defined $op_data) { 
		$log->info("No operation left in the queue");
		return undef;
	}
	# Get the operation type
	my $op_type = $op_data->get_column('type');
	
	my $op_hoped_exec_time = $op_data->get_column('type');
	
	# Get Operation parameters
	my $params_rs = $op_data->operation_parameters;
	my %params;
	while ( my $param = $params_rs->next ) {
		$params{ $param->name } = $param->value;
	}
	$log->debug("Parameters get <" . %params . ">");
	# Try to load Operation::$op_type
	eval {
		$log->debug("op_type: ".$op_type);
		require "Operation/$op_type.pm";
	};
	if ($@) {
		$errmsg = "Administrator->newOp : Operation type <$op_type> does not exist!";
		$log->error($errmsg);
		throw Mcs::Exception::Internal(error => $errmsg);
	}

	# Operation instanciation
	my $op = "Operation::$op_type"->new(data => $op_data, administrator => $self, params => \%params);
	$log->info(ref($op) . " retrieved from database (next operation from execution list)");
	return $op;
}

=head2 getNextOp
	
	Class : Public
	
	Desc : This method change user in context administrator.
	
	Args :
		user_id : Int : User Id which will be the new user
	
=cut

sub changeUser {
	my $self = shift;
	my %args = @_;
	if (! exists $args{user_id} or ! defined $args{user_id}) { 
		$errmsg = "Administrator->changeUser need a user_id named argument!";
		$log->error($errmsg);
		throw Mcs::Exception::Internal(error => $errmsg); 
	}
	my $nextuser = $self->getEntity(type => "User",id => $args{user_id});
	$self->{_rightschecker}->{_userbackup} = $self->{_rightschecker}->{_user};
	$self->{_rightschecker}->{_user} = $nextuser;
} 

=head2 Administrator::_getDbix(%args)
	
	Class : Private
	
	Desc : Instanciate dbix class mapped to corresponding raw in DB
	
	args: 
		table : String : DB table name
		id: Int : id of required entity in table
	return: db schema (dbix)
	
=cut

sub _getDbix {
	my $self = shift;
	my %args = @_;
	
	if ((! exists $args{table} or ! defined $args{table}) ||
		(! exists $args{id} or ! defined $args{id})) { 
			$errmsg = "Administrator->_getDbix need a table and id named argument!";
			$log->error($errmsg);
			throw Mcs::Exception::Internal(error => $errmsg);
	}

	my $dbix;
#	my $entitylink = lc($args{table})."_entities";
	eval {
		$dbix = $self->{db}->resultset( $args{table} )->find(  $args{id}, 
										{ 	'+columns' => [ {entity_id => "entitylink.entity_id"} ], 
										join => ["entitylink"] });};
	if ($@) {
		$errmsg = "Administrator->_getDbix error ".$@;
		$log->error($errmsg);
		throw Mcs::Exception::Internal(error => $errmsg);
	}
	return $dbix;
}

=head2 Administrator::_getDbixFromHash(%args)
	
	Class : Private
	
	Desc : Instanciate dbix class mapped to corresponding raw in DB
	
	args: 
		table : String : DB table name
		hash: Hash ref : hash of constraints to find entity
	return: db schema (dbix)
	
=cut

sub _getDbixFromHash {
	my $self = shift;
	my %args = @_;
	
	if ((! exists $args{table} or ! defined $args{table}) ||
		(! exists $args{hash} or ! defined $args{hash})) {
			$errmsg = "Administrator->_getDbixFromHash need a table and hash named argument!";
			$log->error($errmsg); 
			throw Mcs::Exception::Internal(error => $errmsg);
	}

	my $dbix;
	my $entitylink = lc($args{table})."_entities";
#	my $entitylink = lc($args{table})."_entities";
	eval {
#		$log->debug("Search obj with the following hash $args{hash} in the following table : $args{table}");
#		$log->debug(Dumper $args{hash});
		my $hash = $args{hash};
		if (keys(%$hash)){
#			$log->debug("Hash has keys and value : %$hash when search in $args{table}");
			$dbix = $self->{db}->resultset( $args{table} )->search( $args{hash},
										{ 	'+columns' => [ "$entitylink.entity_id" ], 
										join => ["$entitylink"] });
		}
		else {
#			$log->debug("hash is empty : %$hash when search in $args{table}");
			$dbix = $self->{db}->resultset( $args{table} )->search( undef,
										{ 	'+columns' => [ "$entitylink.entity_id" ], 
										join => ["$entitylink"] });
		}
	};
	if ($@) {
		$errmsg = "Administrator->_getDbix error ".$@;
		$log->error($errmsg);
		throw Mcs::Exception::Internal(error =>  $errmsg);
	}
	return $dbix;
}

=head2 _getAllDbix

	Class : Private

	Desc : Get all dbix class of table
	
	args:
		table : String : Table name
	return: resultset (dbix)
	
=cut

sub _getAllDbix {
	my $self = shift;
	my %args = @_;

	if (! exists $args{table} or ! defined $args{table}) { 
		$errmsg = "Administrator->_getAllData need a table named argument!";	
		$log->error($errmsg);
		throw Mcs::Exception::Internal(error => $errmsg);
	}

	my $entitylink = lc($args{table})."_entities";
	return $self->{db}->resultset( $args{table} )->search(undef, {'+columns' => [ "$entitylink.entity_id" ], 
		join => ["$entitylink"]});
}

=head2 _newDbix
	
	Class : Private
	
	Desc : Instanciate dbix class filled with <params>, doesn't add in DB
	
	args: 
		table : String : DB table name
		row: hash ref : representing the new row (key mapped on <table> columns)
	return: db schema (dbix)

=cut

sub _newDbix {
	my $self = shift;
	my %args  = @_;	
	#$args{params} = {} if !$args{params};	

	if ((! exists $args{table} or ! defined $args{table}) ||
		(! exists $args{row} or ! defined $args{row})) {
		$errmsg = "Administrator->_newData need a table and row named argument!";
		$log->error($errmsg);		 
		throw Mcs::Exception::Internal(error => $errmsg);
	}

	my $new_obj = $self->{db}->resultset($args{table} )->new( $args{row});
	return $new_obj;
}

=head2 _getEntityClass
	
	Class : Private
	
	Desc : Make good require during an Entity Instanciation
	
	args: 
		type : concrete entity type	
	return: Entity class
=cut

sub _getEntityClass{
	my $self = shift;
    my %args = @_;
	my $entity_class;

	if (! exists $args{type} or ! defined $args{type}) {
		$errmsg = "Administrator->_getEntityClass a type named argument!"; 
		$log->error($errmsg);
		throw Mcs::Exception::Internal(error => $errmsg);
	}

	if (defined $args{class_path} && exists $args{class_path}){
		$entity_class = $args{class_path}}
	else {
		$entity_class = General::getClassEntityFromType(%args);}
    my $location = General::getLocFromClass(entityclass => $entity_class);
	eval { require $location; };
    if ($@){
    	$errmsg = "Administrator->_getEntityClass type or class_path invalid! (location is $location)";
    	$log->error($errmsg);
    	throw Mcs::Exception::Internal(error => $errmsg);
    }
	return $entity_class;
}

sub getNodes {
	my $self = shift;
	my %args = @_;
	if (! exists $args{cluster_id} or ! defined $args{cluster_id}) {
		$errmsg = "Administrator->getNodes need a cluster_id named argument!";
		$log->error($errmsg);
		throw Mcs::Exception::Internal(error => $errmsg);
	}
	my $nodes = $self->{db}->resultset('Node')->search({ cluster_id => $args{cluster_id}});
	my $motherboards = [];
	while (my $n = $nodes->next) {
		push @$motherboards, $self->getEntity(type => 'Motherboard', id => $n->get_column('motherboard_id'));
	}
	return $motherboards;
}


sub getComponent {
	my $self = shift;
    my %args = @_;

	if ((! exists $args{component_instance_id} or ! defined $args{component_instance_id})) { 
		$errmsg = "Administrator->getComponent needs a component_instance_id named argument!";
		$log->error($errmsg);
		throw Mcs::Exception::Internal::IncorrectParam(error => $errmsg);
	}
	
	my $comp_instance_row = $self->{db}->resultset("ComponentInstance")->find(
		{ component_instance_id => $args{component_instance_id} }, 
		{ '+columns' => [ "component_id.component_name",
						  "component_id.component_version",
						  "component_id.component_category"], 
		join => ["component_id"]});	
	
	return $self->getEntity (
				class_path => "Entity::Component::".$comp_instance_row->get_column('component_category')."::" .
					$comp_instance_row->get_column('component_name') . 
					$comp_instance_row->get_column('component_version'),
				id => $comp_instance_row->get_column('component_instance_id'),
				type => "ComponentInstance");
}

########################################
## methodes for fast usage in web ui ##
########################################

# add a new message
sub addMessage {
	my $self = shift;
	my %args = @_;
	if ((! exists $args{level} or ! defined $args{level}) ||
		(! exists $args{from} or ! defined $args{from}) ||
		(! exists $args{content} or ! defined $args{content})){
		$errmsg = "Administrator->addMessage need a level, from and content named argument!";
		$log->error($errmsg);
		throw Mcs::Exception::Internal(error => $errmsg);
	}
	$self->{db}->resultset('Message')->create({
		user_id => $self->{_rightschecker}->{_user},
		message_from => $args{from},
		message_creationdate => \"CURRENT_DATE()",
		message_creationtime => \"CURRENT_TIME()",
		message_level => $args{level},
		message_content => $args{content}
	});
	return;
}

sub getMessages {
	my $self = shift;

	my $r = $self->{db}->resultset('Message')->search(undef, { 
		order_by => { -desc => [qw/message_id/], },
		rows => 50 
	});
	my @arr = ();
	while (my $row = $r->next) {
		push @arr, { 
			'from' => $row->get_column('message_from'),
			'level' => $row->get_column('message_level'),,
			'date' => $row->get_column('message_creationdate'), 
			'time' => $row->get_column('message_creationtime'), 
			'content' => $row->get_column('message_content'),
			  
		};
	}
	return @arr;
}

sub getOperations {
	my $self = shift;
	my $Operations = $self->{db}->resultset('Operation')->search(undef, { 
		order_by => { -desc => [qw/execution_rank creation_date creation_time/] },
		'+columns' => [ 'user_id.user_login' ],
		join => [ 'user_id' ]
	});
	
	my $arr = [];
	while (my $op = $Operations->next) {
		
		my $opparams = [];
		my $execution_time;
		my $Parameters = $self->{db}->resultset('OperationParameter')->search({operation_id=>$op->get_column('operation_id')});
		
		while (my $param = $Parameters->next) {
			push @$opparams, { 
				'PARAMNAME' => $param->get_column('name'), 
				'VAL' => $param->get_column('value')
			};
		}
		if( defined $op->get_column('hoped_execution_time') ) {
			my $dt = DateTime->from_epoch(epoch => $op->get_column('hoped_execution_time'), time_zone => 'Europe/Paris');
			$execution_time = $dt->ymd()." ".$dt->hms();
			
		} else {
			$execution_time = 'no'; 
		}  
		push @$arr, { 
			'ID' => $op->get_column('operation_id'),
			'TYPE' => $op->get_column('type'), 
			'FROM' => $op->get_column('user_login'), 
			'CREATION' => $op->get_column('creation_date')." ".$op->get_column('creation_time'), 
			'PLANNED' => $execution_time, 
			'RANK' => $op->get_column('execution_rank'), 
			'PRIORITY' => $op->get_column('priority'),
			'PARAMETERS' => $opparams,
		};
	}
	return $arr;

}

sub getComponentsListByCategory {
	my $self = shift;
	my $components = $self->{db}->resultset('Component')->search({}, 
	{ order_by => { -asc => [qw/component_category component_name component_version/]}}
	);
	my $list = [];
	my $currentindex = -1;
	my $currentcategory = '';
	while(my $c = $components->next) {
		my $category = $c->get_column('component_category');
		my $tmp = { name => $c->get_column('component_name'), version => $c->get_column('component_version')};
		if($currentcategory ne $category) { 
			$currentcategory = $category; 
			$currentindex++; 
			$list->[$currentindex] = {category => "$category", components => []};
		} 
		push @{$list->[$currentindex]->{components}}, $tmp;
	}
	return $list;
}






1;

__END__

=head1 AUTHOR

Copyright (c) 2010 by Hedera Technology Dev Team (dev@hederatech.com). All rights reserved.
This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
