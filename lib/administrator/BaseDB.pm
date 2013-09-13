#    Copyright © 2012-2013 Hedera Technology SAS
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as
#    published by the Free Software Foundation, either version 3 of the
#    License, or (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

=pod
=begin classdoc

Base class to manage inheritance throw relational database.

@since    2012-Jun-10
@instance hash
@self     $self

=end classdoc
=cut

package BaseDB;

use strict;
use warnings;

use General;
use Kanopya::Exceptions;
use Kanopya::Config;

use AdministratorDB::Schema;

use Class::ISA;
use Hash::Merge;
use POSIX qw(ceil);
use vars qw($AUTOLOAD);
use Clone qw(clone);

use Data::Dumper;
use Log::Log4perl "get_logger";

use TryCatch;
my $err;

my $log = get_logger("basedb");
my $errmsg;


# In-memory cache for class types
my %class_type_cache;

# In-memory cache for atrributes definitions
my %attr_defs_cache;

use constant ATTR_DEF => {
    label => {
        is_virtual  => 1,
    }
};

sub getAttrDef { return ATTR_DEF; }

sub methods {
    return {
        get => {
            description => 'get <object>',
        },
        create => {
            description => 'create a new <object>',
        },
        remove => {
            description => 'remove <object>',
        },
        update => {
            description => 'update <object>',
        },
    };
}

my $adm = {
    # DBix database schema
    schema => undef,
    # Libkanopya configuration
    config => undef,
    # Current logged in user
    user   => undef,
};


=pod
=begin classdoc

@constructor

Create a new instance of the class. It inserts a entry for every class
of the hierarchy, every entry having a foreign key to its parent entry

@return a class instance

=end classdoc
=cut

sub new {
    my ($class, %args) = @_;
    my $hash = \%args;
    my $virtuals = { };
    my $attrdef = $class->getAttrDefs();

    # Extract relation for futher handling
    my $relations = $class->_extractRelations(hash => $hash);

    my @attrs = keys %args;
    foreach my $attr (@attrs) {
        my $relation = $class->getAttrDefs->{$attr . "_id"};

        if ($relation && defined($relation->{relation}) && $args{$attr}->isa("BaseDB")) {
            $args{$attr . "_id"} = $args{$attr}->id;
            delete $args{$attr};
        }
        # If an attr is 'user_id' and is null, automatically set it
        # to the current user id.
        elsif ($attr eq 'user_id' and not defined $args{$attr}) {
            $args{$attr} = BaseDB->_adm->{user}->{user_id};
        }
        else {
            if ($attrdef->{$attr}->{is_virtual}) {
                # If the attribute is virtual and editable, call the setter method
                if ($attrdef->{$attr}->{is_editable}) {
                    $virtuals->{$attr} = delete $hash->{$attr};
                }
                else {
                    delete $hash->{$attr};
                }
            }
        }
    }

    $class->_populateRelations(relations => $relations,
                               foreign   => 0,
                               attrs     => $hash);

    my $attrs = $class->checkAttrs(attrs => $hash);
    my $self = $class->newDBix(attrs => $attrs);
    bless $self, $class;

    for my $attr (keys %$virtuals) {
        $self->$attr($virtuals->{$attr});
    }

    # Populate relations
    $self->_populateRelations(relations => $relations);

#    $self->{_altered} = 0;

    return $self;
}


=pod
=begin classdoc

Update an instance by setting values for attribute taht differs,
also handle the update of relations.

@return the updated object

=end classdoc
=cut

sub update {
    my ($self, %args) = @_;
    my $class = ref($self) || $self;

    General::checkParams(args => \%args, optional => { 'override_relations' => 1 });

    my $override = delete $args{override_relations};
    my $hash = \%args;

    # Extract relation for futher handling
    my $relations = $class->_extractRelations(hash => $hash);
    delete $hash->{id};

    my $updated = 0;
    my $attrdef = $class->getAttrDefs();
    for my $attr (keys %$hash) {
        if (not $attrdef->{$attr}->{is_virtual}) {
            my $currentvalue = $self->getAttr(name => $attr);
            if ((defined $currentvalue && "$hash->{$attr}" ne "$currentvalue") ||
                (not defined $currentvalue && defined $hash->{$attr})) {
                $self->setAttr(name => $attr, value => $hash->{$attr});

                if (not $updated) { $updated = 1; }
            }
        } else {
            # If the attribute is virtual and editable, call the setter method
            if ($attrdef->{$attr}->{is_editable}) {
                $self->$attr($hash->{$attr});
            }
        }
    }
    if ($updated) { $self->save(); }

    # Populate relations
    $self->_populateRelations(relations => $relations, override => $args{override_relations});

    return $self;
}


=pod
=begin classdoc

Remove records from the entire class hierarchy.

@optional trunc a class name with its hierachy, allows to delete
          a part of the class hierachy only.

=end classdoc
=cut

sub delete {
    my ($self, %args) = @_;
    my $dbix = $self->{_dbix};

    General::checkParams(args => \%args, optional => { 'trunc' => undef });

    if (defined $args{trunc}) {
        $args{trunc} = _buildClassNameFromString($args{trunc});
    }

    # Search for first mother table in the hierarchy
    while(1) {
        if ($dbix->can('parent')) {
            my $parentclass = _buildClassNameFromString(ref($dbix->parent));

            if (defined $args{trunc} and $parentclass eq $args{trunc}) {
                last;
            }

            # go to parent dbix
            $dbix = $dbix->parent;
            next;

        } else { last; }
    }

    if (defined $args{trunc}) {
        $self->{_dbix} = $dbix->parent;
    }

    $dbix->delete;

    return undef;
}


=pod
=begin classdoc

Generic method for object creation.

@return the created object instance

=end classdoc
=cut

sub create {
    my $class = shift;
    my %args = @_;

    return $class->new(%args);
}


=pod
=begin classdoc

Generic method for object deletion.

=end classdoc
=cut

sub remove {
    my $self = shift;
    my %args = @_;

    $self->delete();
}


=pod
=begin classdoc

Extend an object instance to a concreter type.

@return the promoted object

=end classdoc
=cut

sub promote {
    my ($class, %args) = @_;

    General::checkParams(args => \%args, required => [ 'promoted' ]);

    my $promoted = delete $args{promoted};

    # Check if the new type is in the same hierarchy
    my $baseclass = ref($promoted);
    if (not ($class =~ m/$baseclass/)) {
        $errmsg = "Unable to promote " . ref($promoted) . " to " . $class;
        throw Kanopya::Exception::Internal::IncorrectParam(error => $errmsg);
    }

    my $pattern = $baseclass . '::';
    my $subclass = $class;
    $subclass =~ s/^$pattern//g;

    my $nextclass = $subclass;
    $nextclass =~ s/\:\:.*$//g;

    # Set the primary key to the parent primary key value.
    my $primary_key = (BaseDB->_adm->{schema}->source($nextclass)->primary_columns)[0];
    $args{$primary_key} = $promoted->id;

    # Extract relation for futher handling
    my $relations = $class->_extractRelations(hash => \%args);

    # Merge the base object attributtes and new ones for attrs checking
    my %totalargs = (%args, $promoted->getAttrs);

    # Then extract only the attrs for new tables for insertion
    my $attrs = $class->checkAttrs(attrs => \%totalargs,
                                   trunc => $baseclass . '::' . $nextclass);

    my $self = $class->newDBix(attrs => $attrs, table => $nextclass);

    bless $self, $class;

    # Populate relations
    $self->_populateRelations(relations => $relations, foreign   => 1);

    # Set the class type to the new promotion class
    try {
        my $rs = $class->_getDbixFromHash(table => "ClassType",
                                          hash  => { class_type => $class })->single;

        $self->class_type_id($rs->get_column('class_type_id'));
    }
    catch ($err) {
        # Unregistred or abstract class name <$class>, assuming it is not an Entity.
    }

    return $self;
}


=pod
=begin classdoc

Generalize an object instance to a parent type.

@return the demoted object

=end classdoc
=cut

sub demote {
    my ($class, %args) = @_;

    General::checkParams(args => \%args, required => [ 'demoted' ]);

    # Check if the new type is in the same hierarchy
    my $baseclass = ref($args{demoted});
    if (not ($baseclass =~ m/$class/)) {
        $errmsg = "Unable to demote " . ref($args{demoted}) . " to " . $class;
        throw Kanopya::Exception::Internal::IncorrectParam(error => $errmsg);
    }

    # Delete row of tables bellow $class
    $args{demoted}->delete(trunc => $class);

    bless $args{demoted}, $class;

    # Set the class type to the new promotion class
    my $rs = $class->_getDbixFromHash(table => "ClassType",
                                      hash  => { class_type => $class })->single;

    $args{demoted}->class_type_id($rs->get_column('class_type_id'));

    return $args{demoted};
}


=pod
=begin classdoc

Retrieve a value given a name attribute, search this atribute throw the whole class hierarchy.

@param name name of the attribute to get the value

@return the attribute value

=end classdoc
=cut

sub getAttr {
    my ($self, %args) = @_;
    my $class = ref($self) or throw Kanopya::Exception::Method();

    General::checkParams(args => \%args, required => [ 'name' ],
                                         optional => { deep => 0 });

    my $found = 1;
    my $value = undef;
    my $dbix = $self->{_dbix};
    my $attr = $class->getAttrDefs()->{$args{name}};

    # Recursively search in the dbix objets, following
    # the 'parent' relation
    while ($found) {
        # The attr is a column
        if ($dbix->has_column($args{name})) {
            $value = $dbix->get_column($args{name});
            last;
        }
        # The attr is a relation
        elsif ($dbix->has_relationship($args{name})) {
            my $name = $args{name};
            my $relinfo = $dbix->relationship_info($args{name});
            if ($relinfo->{attrs}->{accessor} eq "multi") {
                return map { $class->fromDBIx(row => $_, deep => $args{deep}) } $dbix->$name;
            }
            else {
                if ($dbix->$name) {
                    $value = $class->fromDBIx(row => $dbix->$name, deep => $args{deep});
                }
            }
            last;
        }
        # The attr is a many to many relation
        elsif ($dbix->can($args{name})) {
            my $name = $args{name};
            return map { $class->fromDBIx(row => $_, deep => $args{deep}) } $dbix->$name;
        }
        # The attr is a virtual attr
        elsif (($self->can($args{name}) or $self->can(normalizeMethod($args{name}))) &&
               defined $attr and $attr->{is_virtual}) {
            # Firstly try to call method with camel-case style
            my $method = $args{name};
            eval {
                my $camelcased_method = normalizeMethod($method);
                $value = $self->$camelcased_method();
            };
            if ($@ and $self->can($method)) {
                # If failled with camel-cased, try the original attr name as method
                eval {
                    $value = $self->$method();
                };
                if ($@) {
                    $value = $@;
                }
            }

            last;
        }
        elsif ($dbix->can('parent')) {
            $dbix = $dbix->parent;
            next;
        }
        else {
            $found = 0;
            last;
        }
    }
    if (not $found) {
        throw Kanopya::Exception::Internal(error => "$self has no attribute <$args{name}>.");
    }
    return $value;
}


=pod
=begin classdoc

Set one name attribute with the given value, search this attribute throw the whole
class hierarchy, and check attribute validity.

@param name the name of the attribute to set the value

@optional value the value to set
@optional save a flag to save the object

@return the value set

=end classdoc
=cut

sub setAttr {
    my ($self, %args) = @_;
    my $class = ref($self) or throw Kanopya::Exception::Method();

    General::checkParams(args     => \%args,
                         required => [ 'name' ],
                         optional => { 'value' => undef, 'save'  => 0 });

    my ($name, $value) = ($args{name}, $args{value});
    my $dbix = $self->{_dbix};

    $self->checkAttr(%args);
    my $attr = $class->getAttrDefs()->{$name};

    # The attr is a virtual attr
    if (($self->can($args{name}) or $self->can(normalizeMethod($args{name}))) and
        defined $attr and $attr->{is_virtual}) {

        # Firstly try to call method with camel-case style
        eval {
            my $camelcased_method = normalizeMethod($name);
            $self->$camelcased_method($value);
        };
        if ($@ and $self->can($name)) {
            # If failled with camel-cased, try the original attr name as method
            $self->$name($value);
        }
        return;
    }

    my $found = 0;
    while(1) {
        # Search for attr in this dbix
        if ($dbix->has_column($name)) {
            $dbix->set_column($name, $value);
            $found = 1;
            last;
        }
        elsif($dbix->can('parent')) {
            # go to parent dbix
            $dbix = $dbix->parent;
            next;
        }
        else {
            last;
        }
    }

    if (not $found) {
        $errmsg = ref($self) . " setAttr no attr name $args{name}!";
        throw Kanopya::Exception::Internal(error => $errmsg);
    }

    if ($args{save}) {
        $self->save();
    }
#    $self->{_altered} = 1;

    return $value;
}


=pod
=begin classdoc

Retrieve one instance from an id

@param id the id of the object to get

@return the object instance

=end classdoc
=cut

sub get {
    my ($class, %args) = @_;

    General::checkParams(args => \%args, required => [ 'id' ],
                                         optional => { 'prefetch' => [ ] });

    return $class->find(hash     => { 'me.' . $class->getPrimaryKey => $args{id} },
                        prefetch => $args{prefetch},
                        deep     => 1);
}


=pod
=begin classdoc

Return the entries that match the 'hash' filter. It also accepts more or less
the same parameters than DBIx 'search' method. It fetches the attributes of
the whole class hierarchy and returns an object as a BaseDB derived object.

@param hash the keys/values describing the researched objects
@optional page the number of the requested page among all pages
          of the object list.
@optional rows the number of object entry in a page
@optional order_by the sorting policy for output list
@optional dataType the output format

@return the matching object list

=end classdoc
=cut

sub search {
    my ($class, %args) = @_;
    my @objs = ();

    General::checkParams(args     => \%args,
                         optional => { 'hash' => {}, 'page' => undef, 'rows' => undef, 'related' => undef,
                                       'join' => undef, 'order_by' => undef, 'dataType' => undef,
                                       'prefetch' => [], 'raw_hash' => {}, 'presets' => {} });

    # Syntax improvement to avoid to call searchRelated
    if (defined $args{related}) {
        my $related = delete $args{related};
        return $class->searchRelated(filters => [ $related ], %args);
    }

    my $merge = Hash::Merge->new('STORAGE_PRECEDENT');

    my $table = _buildClassNameFromString(join('::', getClassHierarchy($class)));

    # If the table does not match the class, the conrete table does not exists,
    # so filter on the class type.
    if ($class =~ m/::/ and $class !~ m/::$table$/) {
        $args{hash}->{'class_type.class_type'} = $class;
    }

    my $prefetch = $class->getJoin() || {};
    $prefetch = $merge->merge($prefetch, $args{join});

    for my $relation (@{ $args{prefetch} }) {
        my @comps = split(/\./, $relation);
        while (scalar @comps) {
            my $join_query = $class->getJoinQuery(comps => \@comps, indepth => 1);

            $prefetch = $merge->merge($prefetch, $join_query->{join});
            $args{hash} = $merge->merge($args{hash}, $join_query->{where});
            pop @comps;
        }
    }

    my $virtuals = {};
    my $attrdefs = $class->getAttrDefs();

    FILTER:
    for my $filter (keys %{ $args{hash} }) {
        # If the attr is virtual, move the filter to the virtuals hash
        if ($attrdefs->{$filter}->{is_virtual}) {
            $virtuals->{$filter} = delete $args{hash}->{$filter};
            next FILTER;
        }
        next FILTER if substr($filter, 0, 3) eq "me.";

        my @comps = split('\.', $filter);
        my $value = $args{hash}->{$filter};

        if (scalar (@comps) > 1) {
            my $value = $args{hash}->{$filter};
            my $attr = pop @comps;

            delete $args{hash}->{$filter};

            my $join_query = $class->getJoinQuery(comps => \@comps);
            $prefetch = $merge->merge($prefetch, $join_query->{join});
            $args{hash}->{$comps[-1] . '.' . $attr} = $value;
            $args{hash} = $merge->merge($args{hash}, $join_query->{where});
        }
    }

    my $virtual_order_by;
    if (defined $args{order_by}) {
        # TODO: handle multiple order_by
        my @orders = split(/ /, $args{order_by});
        $args{order_by} = '';

        ORDER:
        for my $order (@orders) {
            if (lc($order) =~ m/asc|desc/) {
                if (defined $virtual_order_by) {
                    $virtual_order_by .= ' ' . $order;
                }
                else {
                    $args{order_by} .= ' ' . $order;
                }
            }
            else {
                if ($attrdefs->{$order}->{is_virtual}) {
                    $virtual_order_by = $order;
                }
                else {
                    $args{order_by} .= ' ' . $order;
                }
            }
        }
    }

    $args{hash} = $merge->merge($args{hash}, $args{raw_hash});

    my $rs = $class->_getDbixFromHash('table' => $table,      'hash'     => $args{hash},
                                      'page'  => $args{page}, 'prefetch' => $prefetch,
                                      'rows'  => $args{rows}, 'order_by' => $args{order_by},
                                      'join'  => $args{join});

    # Instanciate Kanopya classes from DBIx result set
    try {
        while (my $row = $rs->next) {
            my $obj = { _dbix => $row };

            my $parent = $row;
            while ($parent->can('parent')) {
                $parent = $parent->parent;
            }

            my $class_type;
            if ($parent->has_column("class_type_id") and not ($class =~ m/^ClassType.*/)) {
                $class_type = $class->getClassType(id => $parent->get_column("class_type_id"));

                if (length($class_type) > length($class)) {
                    requireClass($class_type);
                    $obj = $class_type->get(id => $parent->get_column("entity_id"));
                }
                else {
                    bless $obj, $class_type;
                }
            }
            else {
                $class_type = $class;
                bless $obj, $class_type;
            }

            push @objs, $obj;
        }
    }
    catch (Kanopya::Exception $err) {
        $err->rethrow();
    }
    catch ($err) {
        throw Kanopya::Exception::Internal(error => "$err");
    }

    # Finally filter on virtual attributes if required
    for my $virtual (keys %{ $virtuals }) {
        my $op = '=';
        if (ref($virtuals->{$virtual}) eq "HASH") {
            map { $op = $_; $virtuals->{$virtual} = $virtuals->{$virtual}->{$_} } keys %{ $virtuals->{$virtual} };
        }
        @objs = grep { General::compareScalars(left_op  => $_->$virtual,
                                               right_op => $virtuals->{$virtual},
                                               op       => $op) } @objs;
    }

    # Sort by virtual attribute if required
    if ($virtual_order_by) {
        my ($attribute, $order) = split(/ /, $virtual_order_by);
        if (defined $order and lc($order) eq 'desc') {
            @objs = sort { $b->$attribute <=> $a->$attribute } @objs;
        }
        else {
            @objs = sort { $a->$attribute <=> $b->$attribute } @objs;
        }
    }

    if (defined ($args{dataType}) and $args{dataType} eq "hash") {
        my $total = (defined $args{page} or defined $args{rows}) ? $rs->pager->total_entries : $rs->count;

        return {
            page    => $args{page} || 1,
            pages   => ceil($total / ($args{rows} || ($args{page} ? 10 : 1))),
            records => scalar @objs,
            rows    => \@objs,
            total   => $total,
        }
    }

    return wantarray ? @objs : \@objs;
}

sub searchRelated {
    my ($self, %args) = @_;
    my $class = ref ($self) || $self;

    General::checkParams(args     => \%args,
                         required => [ 'filters' ],
                         optional => { 'hash' => { } });

    my $join;
    try {
        # If the function is called on a class that is only a base class of the
        # class the relation is on (for example 'virtual_machines' on a Host),
        # return a more understandable error message
        $join = $class->getJoinQuery(comps   => $args{filters},
                                     reverse => 1);
    }
    catch ($err) {
        throw Kanopya::Exception::Internal::NotFound(
                  error => "Could not find a relation " .
                           join('.', @{ $args{filters} }) . " on $self"
              );
    }

    my $merge = Hash::Merge->new('STORAGE_PRECEDENT');
    $args{hash} = $merge->merge($args{hash}, $join->{where});

    my $searched_class = classFromDbix($join->{source});
    requireClass($searched_class);

    my $method = $join->{accessor} eq "single" ? "find" : "search";
    return $searched_class->$method(%args, raw_hash => { $join->{on} => ref ($self) ? $self->id : $args{id} },
                                           hash     => $args{hash},
                                           join     => $join->{join});
}


=pod
=begin classdoc

Return a single element matching the specified criterias take the same arguments as 'search'.

@return the matching object

=end classdoc
=cut

sub find {
    my ($class, %args) = @_;

    General::checkParams(args => \%args, optional => { 'hash' => {}, 'deep' => 0 });

    my @objects = $class->search(%args);

    my $object = shift @objects;
    if (! defined $object) {
        throw Kanopya::Exception::Internal::NotFound(
                  error => "No entry found for " . $class . ", with hash " . Dumper($args{hash})
              );
    }
    return $object;
}


=pod
=begin classdoc

Return a single element matching the specified criterias take the same arguments as 'searchRelated'.

@return the matching object

=end classdoc
=cut

sub findRelated {
    my ($class, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'filters' ],
                         optional => { 'hash' => { } });

    my @objects = $class->searchRelated(%args);

    my $object = pop @objects;
    if (! defined $object) {
        throw Kanopya::Exception::Internal::NotFound(
                  error => "No entry found for " . $class . ", with hash " . Dumper($args{hash})
              );
    }
    return $object;
}


=pod
=begin classdoc

Return the object that matches the criterias
or creates it if it doesn't exist

@param args the criterias

@return the object found or created
=cut

sub findOrCreate {
    my ($class, %args) = @_;

    try {
        return $class->find(hash => \%args);
    }
    catch ($err) {
        return $class->new(%args);
    }
}


=pod
=begin classdoc

Return a single element matching the specified criterias take the same arguments as 'search'.

@return the matching object

=end classdoc
=cut

sub save {
    my ($self) = @_;
    my $dbix = $self->{_dbix};

    my $id;
    if ( $dbix->in_storage ) {
        $dbix->update;
        $self->{_dbix} = $dbix->get_from_storage;
        while ($dbix->can('parent')) {
            $dbix = $dbix->parent;
            $dbix->update;
        }
    } else {
        $errmsg = "$self" . "->save can't be called on a non saved instance! (new has not be called)";
        throw Kanopya::Exception::Internal::IncorrectParam(error => $errmsg);
    }
    return $self;
}


=pod
=begin classdoc

Build the full list of methods by concatenating methods hash of each classes
in the hierarchy, it also support miulti inherintance by using Class::ISA::self_and_super_path.

@return the hash of methods exported to the api for this class.

=end classdoc
=cut

sub getMethods {
    my ($self, %args) = @_;
    my $class = ref($self) || $self;

    General::checkParams(args => \%args, optional => { 'depth' => undef });

    my $methods = {};
    my @supers  = Class::ISA::self_and_super_path($class);
    my $merge   = Hash::Merge->new();

    if (not defined $args{depth}) {
        $args{depth} = scalar @supers;
    }
    elsif ($args{depth} < 0) {
        $args{depth} = (scalar @supers) + $args{depth};
    }

    SUPER:
    for my $sup (@supers) {
        if ($sup->can('methods')) {
            $methods = $merge->merge($methods, $sup->methods());
        }
        last SUPER if --$args{depth} == 0;
     }
     return $methods;
}


=pod
=begin classdoc

Authenticate the user on the permissions management system.

=end classdoc
=cut

sub authenticate {
    my $class = shift;
    my %args  = @_;

    General::checkParams(args => \%args, required => [ 'login', 'password' ]);

    my $user_data = BaseDB->_adm(no_user_check => 1)->{schema}->resultset('User')->search({
                        user_login    => $args{login},
                        user_password => General::cryptPassword(password => $args{password}),
                    })->single;

    if(not defined $user_data) {
        $errmsg = "Authentication failed for login " . $args{login};
        throw Kanopya::Exception::AuthenticationFailed(error => $errmsg);
    }
    else {
        $log->debug("Authentication succeed for login " . $args{login});
        $ENV{EID} = $user_data->id;
    }
}


=pod
=begin classdoc

Start a transction on the ORM.

=end classdoc
=cut

sub beginTransaction {
    my $self = shift;

    $log->debug("Beginning database transaction");
    $self->_adm->{schema}->txn_begin;
}


=pod
=begin classdoc

Commit a transaction according the database configuration.

=end classdoc
=cut

sub commitTransaction {
    my $self = shift;
    my $counter = 0;
    my $commited = 0;

    COMMIT:
    while ($counter++ < $self->_adm->{config}->{dbconf}->{txn_commit_retry}) {
        try {
            $log->debug("Committing transaction to database");

            $self->_adm->{schema}->txn_commit;
            last COMMIT;
        }
        catch ($err) {
            $log->error("Transaction commit failed: $err");
        }
        if ($commited) { last COMMIT; }
    }
}


=pod
=begin classdoc

Rollback (cancel) an openned transaction.

=end classdoc
=cut

sub rollbackTransaction {
    my $self = shift;

    $log->debug("Rollbacking database transaction");
    try {
        $self->_adm->{schema}->txn_rollback;
    }
    catch ($err) {
        $log->warn($err);
    }
}


=pod
=begin classdoc

Extract relations sub hashes from the hash represeting the object.

@param hash hash representing the object.

@return the original hash containing the relations sub hashes only

=end classdoc
=cut

sub _extractRelations {
    my ($self, %args) = @_;
    my $class = ref($self) || $self;

    General::checkParams(args => \%args, required => [ 'hash' ]);

    # Extrating relation from attrs
    my $relations = {};
    for my $attr (keys %{$args{hash}}) {
        if (ref($args{hash}->{$attr}) =~ m/ARRAY|HASH/) {
            $relations->{$attr} = delete $args{hash}->{$attr};
        }
    }
    return $relations;
}


=pod
=begin classdoc

Create or update relations. If a relation has the primary key set in this attributes,
we update the object, create it instead.

@param relations hash containing object relations only
@param foreign boolean to indicate the relations the create
       A value of '0' means we need to create the entities that have a foreign key to 'self'
       A value of '1' means we need to create the entities that 'self' points to

=end classdoc
=cut

sub _populateRelations {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'relations' ],
                         optional => { 'override' => 0, 'foreign' => 1, 'attrs' => undef });

    # For each relations type
    RELATION:
    for my $relation (keys %{ $args{relations} }) {
        my $rel_infos = $self->getRelationship(relation => $relation);
        if (($args{foreign} == 0 && $rel_infos->{relation} ne "single") ||
            ($args{override} == 0 && $args{foreign} == 1 && $rel_infos->{relation} eq "single")) {
            next RELATION;
        }

        my $relation_class = $rel_infos->{class};
        my $relation_schema = $rel_infos->{schema};
        my $key = $rel_infos->{linkfk} || "id";

        # For single relations, create or update the related instance
        if (defined $rel_infos->{relation} && $rel_infos->{relation} eq "single") {
            my $entry = $args{relations}->{$relation};
            if (ref($self) && $self->$relation) {
                # We have the relation id, it is a relation update
                $self->$relation->update(%$entry, override => $args{override});
            }
            else {
                # Id do not exists, it is a relation creation
                my $obj = $relation_class->create(%$entry);
                $args{attrs}->{$obj->getPrimaryKey} = $obj->id;
            }
        }
        # For multi relations, create/update/remove the related instances in funtion
        # of existing entries.
        else {
            my $existing = {};
            my @entries = $self->searchRelated(filters => [ $relation ]);
            %$existing = map { $_->$key => $_ } @entries;

            # Create/update all entries
            for my $entry (@{ $args{relations}->{$relation} }) {
                if (defined $rel_infos->{relation} && $rel_infos->{relation} eq 'single_multi') {
                    my $id = delete $entry->{@{$relation_schema->_primaries}[0]};
                    if ($id) {
                        # We have the relation id, it is a relation update
                        $relation_class->get(id => $id)->update(%$entry);
                        delete $existing->{$id};
                    }
                    else {
                        # Create the new relationships
                        $entry->{$rel_infos->{fk}} = $self->id;
                        # Id do not exists, it is a relation creation
                        $relation_class->create(%$entry);
                    }
                }
                elsif (defined $rel_infos->{relation} && $rel_infos->{relation} eq 'multi') {
                    # If instances are given in parameters instead of ids, use the ids
                    if (ref($entry)) {
                        $entry = $entry->id;
                    }

                    my $exists = delete $existing->{$entry};
                    if (not $exists) {
                        # Create entries in the link table
                        $relation_class->create($rel_infos->{fk}     => $self->id,
                                                $rel_infos->{linkfk} => $entry);
                    }
                }
            }

            # Finally delete remaining entries
            if ($args{override}) {
                for my $remaning (values %$existing) {
                    $remaning->remove();
                }
            }
        }
    }
}


=pod
=begin classdoc

Return a hash ref containing all ATTR_DEF for each class in the hierarchy.

@optional group_by outpout hash format policy (module|none)

@return the updated object

=end classdoc
=cut

sub getAttrDefs {
    my ($self, %args) = @_;
    my $class = ref($self) || $self;

    General::checkParams(args => \%args, optional => { 'group_by' => 'none' });

    my $attributedefs = {};

    if (exists $attr_defs_cache{$args{'group_by'}}{$class}) {
        return clone($attr_defs_cache{$args{'group_by'}}{$class});
    }

    my @hierarchy = getClassHierarchy($class);
    my $modulename = join('::', @hierarchy);

    while (@hierarchy) {
        my $attr_def = {};

        if ($modulename ne "BaseDB") {
            try {
                requireClass($modulename);
            }
            catch ($err) {
                # For component internal classes
                my $source = BaseDB->_adm->{schema}->source(_buildClassNameFromString($modulename));
                $modulename = classFromDbix($source);
                requireClass($modulename);
            }

            $attr_def = clone($modulename->getAttrDef());

            my $schema;
            try {
                $schema = $class->{_dbix}->result_source();
            }
            catch ($err) {
                $schema = BaseDB->_adm->{schema}->source(_buildClassNameFromString($modulename));
            }

            my @relnames = $schema->relationships();
            for my $relname (@relnames) {
                my $relinfo = $schema->relationship_info($relname);
                if ($relname ne "parent" &&
                    $relinfo->{attrs}->{is_foreign_key_constraint} &&
                    $schema->has_column($relname . "_id") && not defined ($relname . "_id")) {

                    $attr_def->{$relname . "_id"} = {
                        type         => 'relation',
                        relation     => $relinfo->{attrs}->{accessor},
                        pattern      => '^\d*$',
                        is_mandatory => 0,
                    };
                }
            }

            for my $column ($schema->columns) {
                if (not defined ($attr_def->{$column})) {
                    $attr_def->{$column} = {
                        pattern      => '^.*$',
                        is_mandatory => 0,
                    };
                    if (grep { $_ eq $column } @{$schema->_primaries}) {
                        $attr_def->{$column}->{is_primary} = 1;
                    }
                }
            }
        }

        if ($attr_def) {
            $attributedefs->{$modulename} = $attr_def;
        }

        pop @hierarchy;
        if (scalar(@hierarchy) > 0) {
            $modulename = join('::', @hierarchy);
        }
    }

    my $merge = Hash::Merge->new('RIGHT_PRECEDENT');

    # Add the BaseDB attrs to the upper class attrs
    $attributedefs->{$modulename} = $merge->merge($attributedefs->{$modulename}, BaseDB::getAttrDef());

    if ($args{group_by} eq 'module') {
        $attr_defs_cache{'module'}{$class} = $attributedefs;
        return clone($attributedefs);
    }

    # Finally merge all module attrs into one level hash
    my $result = {};
    foreach my $module (keys %$attributedefs) {
        $result = $merge->merge($result, $attributedefs->{$module});
    }

    $attr_defs_cache{$args{'group_by'}}{$class} = $result;

    return clone($result);
}


=pod
=begin classdoc

Check the value of an attrbiute with the pattertn defined in the ATTR_DEF.

@param name the name of the attribute to check the value
@param value the value to check with pattern

=end classdoc
=cut

sub checkAttr {
    my ($self, %args) = @_;
    my $class = ref($self) || $self;

    General::checkParams(args => \%args, required => [ 'name' ], optional => {'value' => undef});

    my $attributes_def = $class->getAttrDefs();
    if (exists $attributes_def->{$args{name}} && (not $attributes_def->{$args{name}}->{is_virtual}) &&
        defined $args{value} && $args{value} !~ m/($attributes_def->{$args{name}}->{pattern})/) {

        $errmsg = "Wrong value detected <$args{value}> for param <$args{name}> on class <$class>";
        throw Kanopya::Exception::Internal::WrongValue(error => $errmsg);
    }
}


=pod
=begin classdoc

Check attributes validity in the class hierarchy and build as the same time
a hashref structure to pass to 'new' method of dbix resultset for
the root class of the hierarchy.

@param attrs hash containing keys/values of attributes to check
@optional trunc a class name with its hierachy, allows to return
          a sub hash exluding attributes of classes in this hierachy.

@return the hash of keys/values of attributes of each module in the class hierachy,
        sorted by module name.

=end classdoc
=cut

sub checkAttrs {
    my ($self, %args) = @_;
    my $class = ref($self) || $self;
    my $final_attrs = {};

    General::checkParams(args => \%args, required => [ 'attrs' ], optional => { 'trunc' => undef });

    my $attributes_def = $class->getAttrDefs(group_by => 'module');
    foreach my $module (keys %$attributes_def) {
        $final_attrs->{$module} = {};
    }

    my $attrs = $args{attrs};
    # search unknown attribute or invalid value attribute
    ATTRLOOP:
    foreach my $attr (keys(%$attrs)) {
        foreach my $module (keys %$attributes_def) {
            if (exists $attributes_def->{$module}->{$attr}){
                my $value = $attrs->{$attr};
                my $pattern = $attributes_def->{$module}->{$attr}->{pattern};

                if (((not defined $value) and $attributes_def->{$module}->{$attr}->{is_mandatory}) or
                    ((defined $value and defined $pattern) and $value !~ m/($pattern)/) and
                    (not $attributes_def->{$module}->{$attr}->{is_virtual})) {

                    $errmsg = "Wrong value detected <$value> for param <$attr> on class <$module>";
                    throw Kanopya::Exception::Internal::WrongValue(error => $errmsg);
                }
                $final_attrs->{$module}->{$attr} = $value;
                next ATTRLOOP;
            }
        }
        $errmsg = "$class, wrong attribute detected <$attr>";
        throw Kanopya::Exception::Internal::IncorrectParam(error => $errmsg);
    }

    # search for non provided mandatory attribute and set primary keys to undef
    foreach my $module (keys %$attributes_def) {
        foreach my $attr (keys(%{$attributes_def->{$module}})) {
            if ((! $attributes_def->{$module}->{$attr}->{is_virtual}) &&
                ($attributes_def->{$module}->{$attr}->{is_mandatory}) && (! exists $attrs->{$attr})) {
                if (not defined $attributes_def->{$module}->{$attr}->{default}) {
                    $errmsg = "Missing attribute detected <$attr> on class <$module>";
                    throw Kanopya::Exception::Internal::IncorrectParam(error => $errmsg);
                }
                else {
                     $final_attrs->{$module}->{$attr} = $attributes_def->{$module}->{$attr}->{default};
                }
            }
        }
    }

    my @modules = sort keys %$final_attrs;
    # finaly restructure the hashref with dbix relationships
    for my $i (0..$#modules-1) {
        my $relation = _classToTable(_buildClassNameFromString($modules[$i+1]));
        $final_attrs->{$modules[$i]}->{$relation} = $final_attrs->{$modules[$i+1]};
    }

    # If trunc is defined, only return a sub hash
    my $result = $final_attrs->{$modules[0]};
    if (defined $args{trunc}) {
        my $trunc = $args{trunc};

        while ($trunc =~ m/\:\:/) {
            $trunc = _childClass($trunc);
            my $classname = $trunc;
            $classname =~ s/\:\:.*//g;

            $result = $result->{_classToTable($classname)};
        }
    }

    return $result;
}


=pod
=begin classdoc

Build a new dbix from class name and attributes, and insert it in database.

@param attrs hash containing keys / values of the new dbix attributes
@optional table the first table of the hierarchy

@return the object hash with the private _dbix.

=end classdoc
=cut

sub newDBix {
    my ($class, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'attrs' ],
                         optional => { 'table' => undef });

    my $dbixroot = $class->_newDbix(table => $args{table} || _rootTable($class),
                                    row   => $args{attrs});

    try {
        $dbixroot->insert;
    }
    catch ($err) {
        # Try to extract the reason msg only
        $err =~ s/\[.*$//g;
        $err =~ s/^.*://g;
        throw Kanopya::Exception::DB(error => "Unable to create a new $class: " .  $err);
    }

    return $class->get(id => getRowPrimaryKey(row => $dbixroot));
}


=pod
=begin classdoc

Construct the proper BaseDB based instance from a DBIx row

@param row a dbix row representing the object table row

@return the object instance.

=end classdoc
=cut

sub fromDBIx {
    my ($class, %args) = @_;

    General::checkParams(args => \%args, required => [ 'row' ],
                                         optional => { deep => 0 });

    my $modulename = classFromDbix($args{row}->result_source);

    try {
        requireClass($modulename);
    }
    catch ($err) {
        $modulename = $class->getClassType(class => $modulename) || $modulename;
        requireClass($modulename);
    }

    # TODO: We need to use prefetch to get the parent/childs attrs,
    #       and use the concrete class type. Use 'get' for instance.

    my $obj = bless { _dbix => $args{row} }, $modulename;

    # TODO: Do not hard code exceptions ("class_type", "component_type", "service_provider_type"),
    #       Those two types have no relation to class_type table,
    #       but have class_type_id as primary key column name.
    if ($args{deep} &&
        $args{row}->result_source->from() !~ m/^.*_type$/) {

        my $dbix = $args{row};
        do {
            if ($dbix->has_column('class_type_id')) {
                my $class_type = $class->getClassType(id => $dbix->get_column('class_type_id'));
                requireClass($class_type);
                return $class_type->get(id => $obj->id);
            }
            else {
                $dbix = $dbix->has_relationship("parent") ? $dbix->parent : undef;
            }
        } while ($dbix);
    }

    return $obj;
}


=pod
=begin classdoc

Retrieve all keys/values in the class hierarchy

@return a hash containing all object attributes with values

=end classdoc
=cut

sub getAttrs {
    my ($self) = @_;
    my $dbix = $self->{_dbix};

    # build hash corresponding to class table (with local changes)
    my %attrs = ();
    while(1) {
        # Search for attr in this dbix
        my %currentattrs = $dbix->get_columns;
        %attrs = (%attrs, %currentattrs);
        if($dbix->can('parent')) {
            $dbix = $dbix->parent;
            next;
        } else {
            last;
        }
    }
    return %attrs;
}


=pod
=begin classdoc

Return the class type name from a class type id, at the first call,
get all the entries and cache them into a hash for *LOT* faster accesses.

@param id the id of the class type

@return the class type name

=end classdoc
=cut

sub getClassType {
    my ($class, %args) = @_;

    if (not %class_type_cache) {
        my $class_types = $class->_getDbixFromHash(table => "ClassType", hash  => {});
        while (my $class_type = $class_types->next) {
            $class_type_cache{$class_type->get_column("class_type_id")}
                = $class_type->get_column("class_type");
        }
    }

    if (defined ($args{id})) {
        return $class_type_cache{$args{id}};
    }
    else {
        for my $class_type_id (keys %class_type_cache) {
            my $class_type = $class_type_cache{$class_type_id};
            if ($class_type =~ "::$args{class}\$") {
                return $class_type;
            }
        }
        return undef;
    }

    return "BaseDB";
}


=pod
=begin classdoc

Build the join query required to get all the attributes of the whole class hierarchy.

@return the join query

=end classdoc
=cut

sub getJoin {
    my ($class) = @_;

    my @hierarchy = getClassHierarchy($class);
    my $depth = scalar @hierarchy;

    my $current = $depth;
    my $parent_join;
    while ($current > 0) {
        last if $hierarchy[$current - 1] eq "BaseDB";
        $parent_join = BaseDB->_adm->{schema}->source($hierarchy[$current - 1])->has_relationship("parent") ?
                           ($parent_join ? { parent => $parent_join } : { "parent" => undef }) :
                           $parent_join;
        $current -= 1;
    }

    return $parent_join;
}


=pod
=begin classdoc

Build the JOIN query to get the attributes of a multi level depth relationship.

@return the join query

=end classdoc
=cut

sub getJoinQuery {
    my ($class, %args) = @_;

    my @comps = @{$args{comps}};
    my $source = $class->getResultSource;
    my $on = "";
    my $relation;
    my $where = {};
    my $accessor = "single";

    my @joins;
    my $i = 0;
    try {
        COMP:
        while ($i < scalar @comps) {
            my $comp = $comps[$i];
            my $many_to_many = $source->result_class->can("_m2m_metadata") &&
                               defined ($source->result_class->_m2m_metadata->{$comp});
            my @segment = ();

            M2M:
            while (!$source->has_relationship($comp) && !$many_to_many) {
                if ($args{reverse}) {
                    $relation = $source->reverse_relationship_info("parent");
                    @segment = ((keys %$relation)[0], @segment);
                }
                else {
                    @segment = ("parent", @segment);
                }
                last M2M if ! $source->has_relationship("parent");
                $source = $source->related_source("parent");
                $many_to_many = $source->result_class->can("_m2m_metadata") &&
                                defined ($source->result_class->_m2m_metadata->{$comp});
            }

            if ($source->result_class->can("_m2m_metadata") &&
                defined ($source->result_class->_m2m_metadata->{$comp})) {
                splice @comps, $i, 1, ($source->result_class->_m2m_metadata->{$comp}->{relation},
                                       $source->result_class->_m2m_metadata->{$comp}->{foreign_relation});
                @joins = (@joins, @segment);
                next COMP;
            }

            if ($args{reverse}) {
                $relation = $source->reverse_relationship_info($comp);
                my $name = (keys %$relation)[0];
                @joins = ($name, @segment, @joins);
                if (!$on) {
                    $on = $name . "." . ($relation->{$name}->{source}->primary_columns)[0];
                }
            }
            else {
                @joins = (@joins, @segment, $comp);
            }

            $relation = $source->relationship_info($comp);
            if ($relation->{attrs}->{accessor} eq "multi") {
                $accessor = "multi";
            }

            $where  = $relation->{attrs}->{where};
            $source = $source->related_source($comp);
            $i += 1;
        }
    }
    catch ($err) {
        throw Kanopya::Exception::Internal(error => "$err");
    }

    # Get all the hierarchy of the relation
    my @indepth;
    if ($args{indepth}) {
        my $depth_source = $source;
        while ($depth_source->has_relationship("parent")) {
            @indepth = ("parent", @indepth);
            $depth_source = $depth_source->related_source("parent");
        }
    }
    @joins = (@joins, @indepth);

    my $joins;
    for my $comp (reverse @joins) {
        $joins = { $comp => $joins };
    }

    return { source   => $source,
             join     => $joins,
             on       => $on,
             accessor => $accessor,
             where    => $where };
}


=pod
=begin classdoc

Generic method to build the string representation of the object.

@return the string the representing the object

=end classdoc
=cut

sub toString {
    my $self = shift;
    return ref($self);
}


=pod
=begin classdoc

Return the object as a hash so that it can be safely be converted to JSON.
Should be named differently but hey...
If called on the class, return the object description instead of attributes values

@optional no_relations force to remove the relations from the atrribute definition

@return the hash representing the object or the model

=end classdoc
=cut

sub toJSON {
    my ($self, %args) = @_;
    my $class = ref ($self) || $self;

    General::checkParams(args     => \%args,
                         optional => { 'no_relations' => 0, 'raw' => 0,
                                       'virtuals' => 1, 'expand' => [], 'deep' => 0 });

    my $pk;
    my $hash = {};
    my $attributes;
    my $conreteclass = $class;
    my $merge = Hash::Merge->new();

    $attributes = $class->getAttrDefs(group_by => 'module');
    foreach my $class (keys %$attributes) {
        foreach my $attr (keys %{$attributes->{$class}}) {
            next if ($args{raw} && $attributes->{$class}->{$attr}->{is_virtual});

            if (not ref($self)) {
                # Only add primary key attrs from the lower class in the hierarchy
                if (! ($attributes->{$class}->{$attr}->{is_primary} && "$class" ne "$conreteclass")) {
                    $hash->{attributes}->{$attr} = $attributes->{$class}->{$attr};
                }
            }
            else {
                my $type     = $attributes->{$class}->{$attr}->{type} || '';
                my $relation = $attributes->{$class}->{$attr}->{relation} || '';
                if (($args{virtuals} || ! $attributes->{$class}->{$attr}->{is_virtual}) &&
                    ($type ne 'relation' || $relation eq 'single')) {
                    # Set the value of the attribute
                    $hash->{$attr} = $self->getAttr(name => $attr);
                }
            }
        }
    }

    if ($args{expand}) {
        # Build the expands hash
        my $expands;
        if (ref($args{expand}) and ref($args{expand}) eq "HASH") {
            $expands = $args{expand};
        }
        else {
            $expands = {};
            for my $expand (@{ $args{expand} }) {
                my $current = $expands;
                my @comps   = split(/\./, $expand);
                for my $comp (@comps) {
                    if (not defined $current->{$comp}) {
                        $current->{$comp} = {};
                    }
                    $current = $current->{$comp};
                }
            }
        }

        for my $expand (keys %$expands) {
            my $obj  = $self;
            my $dbix = $self->{_dbix};
            my $is_relation = 0;

            COMPONENT:
            while ($expand && $dbix) {
                my $source = $dbix->result_source;
                my $many_to_many = $source->result_class->can("_m2m_metadata") &&
                                       defined ($source->result_class->_m2m_metadata->{$expand});

                if ($source->has_relationship($expand)) {
                    $is_relation = $source->relationship_info($expand)->{attrs}->{accessor};
                    last COMPONENT;
                }
                elsif ($many_to_many) {
                    $is_relation = "multi";
                    last COMPONENT;
                }
                $dbix = $dbix->result_source->has_relationship('parent') ? $dbix->parent : undef;
            }

            if ($is_relation) {
                $hash->{$expand} = [];
                if ($is_relation eq 'single_multi' || $is_relation eq 'multi') {
                    for my $item ($obj->getAttr(name => $expand, deep => $args{deep})) {
                        push @{$hash->{$expand}}, $item->toJSON(expand => $expands->{$expand},
                                                                deep   => $args{deep});
                    }
                }
                elsif ($is_relation eq 'single') {
                    my $obj = $self->getAttr(name => $expand, deep => 1);
                    if ($obj) {
                        $hash->{$expand} = $obj->toJSON(expand => $expands->{$expand},
                                                        deep   => $args{deep});
                    }
                }
            }
       }
    }

    if (not ref($self)) {
        my $table = _buildClassNameFromString($class);
        my @hierarchy = getClassHierarchy($class);
        my $depth = scalar @hierarchy;
        my $current = $depth;
        my $parent;

        for (my $current = $depth - 1; $current >= 0; $current--) {
            $parent = BaseDB->_adm->{schema}->source($hierarchy[$current]);
            my @relnames = $parent->relationships();
            for my $relname (@relnames) {
                my $relinfo = $parent->relationship_info($relname);

                if (scalar (grep { $_ eq (split('::', $relinfo->{source}))[-1] } @hierarchy) == 0 and
                    $relinfo->{attrs}->{is_foreign_key_constraint} or
                    $relinfo->{attrs}->{accessor} eq "multi") {

                    my $resource = lc((split("::", $relinfo->{class}))[-1]);
                    $resource =~ s/_//g;

                    $hash->{relations}->{$relname} = $relinfo;
                    $hash->{relations}->{$relname}->{from} = $hierarchy[$current];
                    $hash->{relations}->{$relname}->{resource} = $resource;

                    # We must have relation attrs within attrdef to keep
                    # informations as label, is_editable and is_mandatory.
                    # Except if we explicitly don't want it (no_relations option)

                    if ($args{no_relations}) {
                        delete $hash->{attributes}->{$relname . "_id"};
                    }
                }
            }
            pop @hierarchy;
        }
        $hash->{methods} = $self->getMethods;

        $hash->{pk} = {
            pattern      => '^\d*$',
            is_mandatory => 1,
            is_extended  => 0
        };
    }
    else {
        if (!$args{raw}) {
            $hash->{pk} = $self->id;
        }
    }
    return $hash;
}


sub getRelationship {
    my ($self, %args) = @_;
    my $class = ref($self) || $self;

    General::checkParams(args => \%args, required => [ 'relation' ]);

    my $relation = $args{relation};

    # For 'single' relation, the relation in the attrDefs ends with '_id'
    my $attrdef  = $class->getAttrDefs->{$relation} || $class->getAttrDefs->{$relation . '_id'};

    my $source_infos = $self->getRelatedSource($relation);

    my $dbix = $source_infos->{dbix};
    my $relation_schema = $source_infos->{source};

    my $relation_class = classFromDbix($relation_schema);
    $relation_class = $class->getClassType(class => $relation_class) || $relation_class;
    requireClass($relation_class);

    # Deduce the foreign key from relation def
    my $reldef = $dbix->relationship_info($relation);
    my @conds = keys %{$reldef->{cond}};
    my $fk = getForeignKeyFromCond(cond => $conds[0]);

    my $infos = {
        class    => $relation_class,
        schema   => $relation_schema,
        fk       => $fk,
        relation => $attrdef->{relation}
    };

    if (defined $attrdef->{relation} && $attrdef->{relation} eq 'multi') {
        # Deduce the foreign key attr for link entries in relations multi
        my $linked_reldef = $relation_schema->relationship_info($attrdef->{link_to});
        my @conds = values %{$linked_reldef->{cond}};
        $infos->{linkfk} = getKeyFromCond(cond => $conds[0]);
    }

    return $infos;
}


=pod
=begin classdoc

Return the dbix schema of an object of the given type and given id(s).

@param table DB table name
@param id the id of the object, possbile multiple

@return the db schema (dbix)

=end classdoc
=cut

sub getRow {
    my $class = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'id', 'table' ]);

    my $dbix;
    try {
        if (ref($args{id}) eq 'ARRAY') {
            $dbix = BaseDB->_adm->{schema}->resultset($args{table})->find(@{$args{id}});
        } else {
            $dbix = BaseDB->_adm->{schema}->resultset($args{table})->find($args{id});
        }
    }
    catch ($err) {
        throw Kanopya::Exception::DB(error => $err);
    }

    if (not $dbix) {
        $errmsg = "No row found with id $args{id} in table $args{table}";
        $log->warn($errmsg);
        throw Kanopya::Exception::Internal::NotFound(error => $errmsg);
    }

    return $dbix;
}


=pod
=begin classdoc

Instanciate dbix class mapped to corresponding raw in DB.

@param table DB table name
@param hash hash of constraints to find entity

@return the db schema (dbix)

=end classdoc
=cut

sub _getDbixFromHash {
    my $class = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['table', 'hash']);

    if (defined ($args{rows}) and not defined ($args{page})) {
        $args{page} = 1;
    }

    # Catch specifics warnings to avoid Dancer to raise an error 500 on warnings
    $SIG{__WARN__} = sub {
        my $warn_msg = $_[0];
        if ($warn_msg =~ m/Prefetching multiple has_many rel/) {
            $log->warn($warn_msg);
        }
        else {
            # TODO Test number of logs if we log in warn level
            $log->debug($warn_msg);
        }
    };

    try {
        return BaseDB->_adm->{schema}->resultset($args{table})->search($args{hash}, {
                   prefetch => $args{prefetch},
                   join     => $args{join},
                   rows     => $args{rows},
                   page     => $args{page},
                   order_by => $args{order_by}
               });
    }
    catch ($err) {
        throw Kanopya::Exception::Internal(error => "$err");
    }
}


=pod
=begin classdoc

Instanciate dbix class filled with <params>, doesn't add in DB.

@param table DB table name
@param row representing the new row (key mapped on <table> columns)

@return the db schema (dbix)

=end classdoc
=cut

sub _newDbix {
    my $class = shift;
    my %args  = @_;

    General::checkParams(args => \%args, required => [ 'table', 'row' ]);

    try {
        return BaseDB->_adm->{schema}->resultset($args{table})->new($args{row});
    }
    catch ($err) {
        throw Kanopya::Exception::Internal(error => "$err");
    }
}


=pod
=begin classdoc

Return the primary(ies) key(s) of a row.

@param row hash dbix row of the object

@return the primary key value

=end classdoc
=cut

sub getRowPrimaryKey {
    my (%args) = @_;

    General::checkParams(args => \%args, required => [ 'row' ]);

    # If the primary key is multiple, gevie the array ref to the get function
    my $id;
    my @multiple_id = $args{row}->id;
    if (scalar(@multiple_id) > 1) {
        $id = \@multiple_id;
    } else {
        $id = $multiple_id[0];
    }
    return $id;
}


=pod
=begin classdoc

Generic method to get the name of the attribute that identify the object.
Search for an attribute ending by '_name' within all attributes.

@optional attrs the attribute defintion of the object

@return the name of the attribute that identify the object

=end classdoc
=cut

sub getLabelAttr {
    my ($self, %args) = @_;
    my $class = ref ($self) || $self;

    General::checkParams(args => \%args, optional => { 'attrs' => $class->getAttrDefs });

    my @keys = keys %{$args{attrs}};

    my @attrs = grep { $_ =~ m/.*_name$/ } @keys;

    if (scalar @attrs) {
        return $attrs[0];
    }
    return undef;
}


=pod
=begin classdoc

Get the primary key column name

@return the primary key column name.

=end classdoc
=cut

sub getPrimaryKey {
    my $self = shift;
    my $class = ref($self) || $self;

    if (ref ($self)) {
        return ($self->{_dbix}->result_source->primary_columns)[0];
    } else {
        return ($class->getResultSource->primary_columns)[0];
    }
}

=pod
=begin classdoc

Parse ths dbix object relation definition to extract the foreign key
of the relation that link it to the object.

@param cond the 'cond' value of the dbix relation desciption hash

@return the foreign key name of the relation

=end classdoc
=cut

sub getForeignKeyFromCond {
    my (%args) = @_;

    General::checkParams(args => \%args, required => [ 'cond' ]);

    $args{cond} =~ s/.*foreign\.//g;
    return $args{cond};
}


=pod
=begin classdoc

Parse ths dbix object relation definition to extract the foreign key
of the relation that link it to the object.

@param cond the 'cond' value of the dbix relation desciption hash

@return the foreign key name of the relation

=end classdoc
=cut

sub getKeyFromCond {
    my (%args) = @_;

    General::checkParams(args => \%args, required => [ 'cond' ]);

    $args{cond} =~ s/.*self\.//g;
    return $args{cond};
}


=pod
=begin classdoc

Build an array of the base classes that have a schema

@return the array containing all classes in the hierarchy.

=end classdoc
=cut

sub getClassHierarchy {
    my $class = shift;

    my $classpath = (split("=", "$class"))[0];
    my @supers = Class::ISA::super_path($classpath);

    my @hierarchy;
    if (defined ($supers[0]) && $supers[0] eq 'BaseDB') {
        @hierarchy = _buildClassNameFromString($classpath);
    }
    else {
        @hierarchy = split(/::/, $classpath);
    }

    @hierarchy = grep { eval { BaseDB->_adm->{schema}->source($_) }; not $@ } @hierarchy;

    my @klasses;
    @hierarchy = grep { push @klasses, $_; $class->isa(join('::', @klasses)) or
                                           (join('::', @klasses) eq join('::', @hierarchy)) } @hierarchy;
    return wantarray ? @hierarchy : \@hierarchy;
}


=pod
=begin classdoc

@deprecated

Get the primary key of the object

@return the primary key value

=end classdoc
=cut

sub getId {
    my $self = shift;

    return $self->id;
}


=pod
=begin classdoc

Get the primary key of the object

@return the primary key value

=end classdoc
=cut

sub id {
    my $self = shift;

    return $self->{_dbix}->get_column($self->getPrimaryKey);
}


=pod
=begin classdoc

@param $class the full class name with the hierachy

@return the class name at the bottom of the hierarchy

=end classdoc
=cut

sub _childClass {
    my ($class) = @_;
    $class =~ s/^[a-zA-Z0-9]+\:\://g;
    return $class;
}


=pod
=begin classdoc

@param $class the full class name with the hierachy

@return the class name without its hierarchy

=end classdoc
=cut

sub _buildClassNameFromString {
    my ($class) = @_;
    $class =~ s/.*\:\://g;
    return $class;
}


=pod
=begin classdoc

@param $class the full class name with the hierachy

@return the class name at the top of the hierarchy of a full class name.

=end classdoc
=cut

sub _rootTable {
    my ($class) = @_;

    $class = join('::', getClassHierarchy($class));
    $class =~ s/\:\:.*$//g;
    return $class;
}


=pod
=begin classdoc

Convert a class name to table name

@param $class the full class name with the hierachy

@return the table name

=end classdoc
=cut

sub _classToTable {
    my ($class) = @_;

    $class =~ s/([A-Z])/_$1/g;
    my $table = lc( substr($class, 1) );

    return $table;
}


=pod
=begin classdoc

Normalize the specified name by removing underscores and upper casing
the characters that follows.

@param $name any name of database table

@return the normalized name

=end classdoc
=cut

sub normalizeName {
    join('', map(ucfirst, split('_', shift)));
}


=pod
=begin classdoc

Normalize the specified name by removing underscores and upper casing
the characters that follows, excepted the first character.

@param $name any name

@return the normalized name

=end classdoc
=cut

sub normalizeMethod {
    lcfirst(normalizeName(shift));
}


=pod
=begin classdoc

Build the name of the Kanopya class for the specified DBIx table schema.

@param $source a dbix result source

@return the class name

=end classdoc
=cut

sub classFromDbix {
    my $source = shift;
    my $args = @_;

    my $name = $source->source_name();
    my $class = BaseDB->getClassType(class => $name);
    if (!$class) {
        while (1) {
            last if not $source->has_relationship("parent");
            $source = $source->related_source("parent");
            $name = ucfirst($source->from) . "::" . $name;
        }
        $class = normalizeName($name);
    }
    return $class;
}

=pod
=begin classdoc

Return the DBIx ResultSource for this class.

=end classdoc
=cut

sub getResultSource {
    my $self  = shift;
    my $class = ref($self) || $self;

    $class = join("::", getClassHierarchy($class));
    return BaseDB->_adm->{schema}->source(_buildClassNameFromString($class));
}

=pod
=begin classdoc

Return the related source for a relation

=end classdoc
=cut

sub getRelatedSource {
    my ($self, $relation) = @_;
    my $class = ref($self) || $self;

    my $dbix = $class->getResultSource();
    while ($dbix && (! $dbix->has_relationship($relation)) && $dbix->has_relationship("parent")) {
        $dbix = $dbix->related_source("parent");
    }

    my $relation_schema;
    my $attrdef = $class->getAttrDefs->{$relation};
    if (defined ($attrdef->{type}) && $attrdef->{type} eq 'relation' and defined ($attrdef->{specialized})) {
        $relation_schema = BaseDB->_adm->{schema}->source($attrdef->{specialized});
    }
    else {
        try {
            $relation_schema = $dbix->related_source($relation);
        }
        catch ($err) {
            throw Kanopya::Exception::Internal::NotFound(error => "$err");
        }
    }
    return { dbix => $dbix, source => $relation_schema };
}

=pod
=begin classdoc

Dinamically load a module from the class name.

@param $class Class name corresponding to the module to load.

=end classdoc
=cut

sub requireClass {
    my $class = shift;
    my $location = General::getLocFromClass(entityclass => $class);

    try {
        require $location;
    }
    catch ($err) {
        throw Kanopya::Exception::Internal::UnknownClass(
                  error => "Could not find $location :\n$err"
              );
    }
}


=pod
=begin classdoc

Default label management
Label is the value of the attr returned by getLabelAttr() or the object id
Subclass can redefined this method to return specific label

@return the label string for this object

=end classdoc
=cut

sub label {
    my $self = shift;

    my $label = $self->getLabelAttr();
    return $label ? $self->$label : $self->id;
}


=pod
=begin classdoc

Method used during cloning and import process of object linked to another object (belongs_to relationship)
Clone this object and link the clone to the specified related object
Only clone if object doesn't alredy exist in destination object (based on label_attr_name arg)

@param dest_object_id id of the related object where to import cloned object
@param relationship name of the belongs_to relationship linking to owner object
@optional label_attr_name name of the attr used to know if object already exists in related objects of dest
@optional attrs_clone_handler function called to handle specific attrs cloning, must return the new attrs hash

@return the cloned object

=end classdoc
=cut

sub _importToRelated {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => ['dest_obj_id', 'relationship']);

    my %attrs = $self->getAttrs();
    my $caller_class = caller();

    # Don't clone If already exists (based on label_attr_name)
    if (defined $args{label_attr_name}) {
        try {
            return $caller_class->find(hash => {
                       $args{relationship} . '_id' => $args{dest_obj_id},
                       $args{label_attr_name}      => $attrs{$args{label_attr_name}}
                   });
        }
        catch ($err) {
            # Do not exists, create it.
        }
    }

    # Set the linked entity id to the dest entity id
    $attrs{$args{relationship} . '_id'} = $args{dest_obj_id};

    # Specific attrs cloning handler callback
    if ($args{attrs_clone_handler}) {
        %attrs = $args{attrs_clone_handler}(attrs => \%attrs);
    }

    # Remove all primary keys of hierachy of the origin obj
    my $class;
    for my $subclass (split('::', ref $self)) {
        $class .= $subclass;
        delete $attrs{$class->getPrimaryKey()};
        $class .= '::';
    }

    # Create the object
    return $caller_class->new(%attrs);
}


=pod

Utility method used to clone a formula
Clone all objects used in formula and translate formula to use cloned object ids

@param dest_sp_id id of the service provider where to import all cloned objects
@param formula string representing a formula (i.e operators and object ids in the format "idXXX")
@param formula_object_class class of object used in formula

@return the cloned object

=end classdoc
=cut

sub _cloneFormula {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => ['dest_sp_id', 'formula', 'formula_object_class']);

    my $formula = $args{formula};
    # Get ids in formula
    my %ids = map { $_ => undef } ($formula =~ m/id(\d+)/g);
    # Clone objects used in formula
    %ids = map {
        $_ =>   $args{formula_object_class}
                ->get( id => $_)
                ->clone( dest_service_provider_id => $args{dest_sp_id} )
                ->id
    } keys %ids;
    # Replace ids in formula with cloned objects ids
    $formula =~ s/id(\d+)/id$ids{$1}/g;

    return $formula;
}


=pod
=begin classdoc

Return the delegatee entity on which the permissions must be checked.
By default, permissions are checked on the entity itself.

@return the delegatee entity.

=end classdoc
=cut

sub getDelegatee {
    my $self = shift;

    throw Kanopya::Exception::NotImplemented(
              error => "Unbale to check permissions on non entity class <$self>, " .
                       "CRUD methods are supported by specifying a delegatee attr."
          );
}


=pod
=begin classdoc

Get the name of the attributue that define the relation to the delegatee object. 
If exists, the permission to create an object of the class is delegated to
the delegatee object on which the user need to have the 'update' permissions.

@return the delegatee attr name.

=end classdoc
=cut

sub getDelegateeAttr {
    my $self  = shift;
    my $class = ref($self) || $self;

    my $attrs = $class->getAttrDefs();
    my @delegatees = grep { defined $attrs->{$_}->{is_delegatee} && $attrs->{$_}->{is_delegatee} == 1 }
                         keys %{ $attrs };

    return (scalar(@delegatees) > 0) ? pop @delegatees : undef;
}


=pod
=begin classdoc

Propagate object specific permissions on a related object. This
method is called at creation of related objects that have tagged
the relation that link to this one as 'is_delegatee'.

@param related the related object on which propagate permissions.

=end classdoc
=cut

sub propagatePermissions {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'related' ]);
}


=pod
=begin classdoc

Method used by the api as entry point for methods calls.
It is convenient for centralizing permmissions checking.

@param method the method name to call
@optional params method call parameters

=end classdoc
=cut

sub methodCall {
    my $self  = shift;
    my $class = ref($self) || $self;
    my %args  = @_;

    General::checkParams(args => \%args, required => [ 'method' ],
                                         optional => { 'params' => {} });

    my $userid   = BaseDB->_adm->{user}->{user_id};
    my $usertype = BaseDB->_adm->{user}->{user_system};
    my $godmode  = defined BaseDB->_adm->{config}->{dbconf}->{god_mode} &&
                       BaseDB->_adm->{config}->{dbconf}->{god_mode} eq 1;

    if (not ($godmode || $usertype)) {
        $self->checkUserPerm(user_id => $userid, %args);
    }

    my $method = $args{method};
    return $self->$method(%{$args{params}});
}


=pod
=begin classdoc

Check permmissions on a method for a user.

=end classdoc
=cut

sub checkUserPerm {
    my $self  = shift;
    my $class = ref($self) || $self;
    my %args  = @_;

    General::checkParams(args => \%args, required => [ 'method', 'user_id' ],
                                         optional => { 'params' => {} });

    # For the class method get, intanciate the specified object from the id,
    # and delegate the permissions on get method to the object himself.
    if (!ref($self) && $args{method} eq 'get' && defined $args{params}->{id}) {
        return $class->get(id => $args{params}->{id})->checkUserPerm(%args);
    }

    # For delegated CRUD, check permission for 'update' on the delagated object
    my $delegateeattr = $class->getDelegateeAttr();
    if (defined $delegateeattr && $args{method} =~ m/^(get|create|update|remove)$/) {
        (my $delegateerel = $delegateeattr) =~ s/_id$//g;

        # If the method is 'create', or 'update' with the delegatee attr sepcified,
        # instanciate the delegatee from the delegatee attr param
        my $delegatee;
        if ($args{method} =~ m/^(create|update)$/ && defined $args{params}->{$delegateeattr}) {
            # Retreive the relation class to instanciate it
            my $delegateeclass = $self->getRelationship(relation => $delegateerel)->{class};
            $delegatee = $delegateeclass->get(id => $args{params}->{$delegateeattr});
        }
        # Else get the delegatee object from the instance
        else {
            $delegatee = $self->$delegateerel;
        }

        # Check the permission for update on the delagatee object
        try {
            $delegatee->checkUserPerm(user_id => $args{user_id}, method => "update");
        }
        catch (Kanopya::Exception::Permission::Denied $err) {
            my $msg = $self->_buildPermissionDeniedErrorMessage(method => $args{method}) . " from " .
                      _buildClassNameFromString(ref($delegatee)) . " <" . $delegatee->label . ">";
            throw Kanopya::Exception::Permission::Denied(error => $msg);
        }
        catch ($err) {
            $err->rethrow();
        }

        # Also check the permisions on the object himself if the other rights than CRUD are not delegated
        $delegatee = undef;
        eval {
            $delegatee = $self->getDelegatee;
        };
        if (! (ref($self) && ref($delegatee) eq ref($self))) {
            return;
        }
    }

    # Firstly check permssions on parameters
    foreach my $key (keys %{ $args{params} }) {
        my $param = $args{params}->{$key};
        if ((ref $param) eq "HASH" && defined ($param->{pk}) && defined ($param->{class_type_id})) {
            my $paramclass = $self->getClassType(id => $param->{class_type_id});
            try {
                $paramclass->getDelegatee->checkPerm(user_id => $args{user_id}, method => "get");
            }
            catch (Kanopya::Exception::Permission::Denied $err) {
                my $msg = "Permission denied to get parameter " . $param->{pk};
                throw Kanopya::Exception::Permission::Denied(error => $msg);
            }
            catch ($err) {
                $err->rethrow();
            }

            # TODO: use DBIx::Class::ResultSet->new_result and bless it to 'class' instead of a 'get'
            $args{params}->{$key} = $paramclass->get(id => $param->{pk});
        }
    }

    $log->debug("Check permission for user <" . $args{user_id} . "> on <" . $self->getDelegatee .
                "> to <$args{method}>");

    # Check the permissions for the logged user
    try {
        $self->getDelegatee->checkPerm(user_id => $args{user_id}, method => $args{method});
    }
    catch ($err) {
        throw Kanopya::Exception::Permission::Denied(
                  error => $self->_buildPermissionDeniedErrorMessage(method => $args{method})
              );
    }
}


=pod
=begin classdoc

Build the permssions error message from the requested method.

=end classdoc
=cut

sub _buildPermissionDeniedErrorMessage {
    my $self  = shift;
    my %args  = @_;
    my $class = ref($self) || $self;

    General::checkParams(args => \%args, required => [ 'method' ]);

    my $msg  = "Permission denied to " . $self->getMethods->{$args{method}}->{description};
    my $type = _buildClassNameFromString(ref($self) || $self);
    $type = ref($self) ? ($type . " <" . $self->label . ">") : $type;
    $msg =~ s/<object>/$type/g;
    return $msg;
}


=pod
=begin classdoc

Return the $adm instance if defined, instanciate it instead.
The $adm singleton contains the database schema to proccess
queries, the loaded configuration and the current user informations.

@return the adminitrator singleton

=end classdoc
=cut

sub _adm {
    my $class = shift;
    my %args  = @_;

    General::checkParams(args => \%args, optional => { 'no_user_check' => 0 });

    if (not defined $adm->{config}) {
        $adm->{config} = $class->_loadconfig();
    }
    if (not defined $adm->{schema}) {
        $adm->{schema} = $class->_connectdb(config => $adm->{config});
    }

    if (not $args{no_user_check}) {
        if (not exists $ENV{EID} or not defined $ENV{EID}) {
            $errmsg = "No valid session registered:";
            $errmsg .= " BaseDB->authenticate must be call with a valid login/password pair";
            throw Kanopya::Exception::AuthenticationRequired(error => $errmsg);
        }

        if (! defined $adm->{user} || $adm->{user}->{user_id} != $ENV{EID}) {
            my $user = $adm->{schema}->resultset('User')->find($ENV{EID});

            # Set new user infomations in the adm singleton
            if (defined $user) {
                $adm->{user} = {
                    user_id     => $user->id,
                    user_system => $user->user_system,
                };
            }
        }
    }
    return $adm;
}


=pod
=begin classdoc

Get the configuration config module and check the configuration
constants existance

@return the configuration hash

=end classdoc
=cut

sub _loadconfig {
    my $class = shift;

    my $config = Kanopya::Config::get('libkanopya');

    General::checkParams(args => $config->{dbconf}, required => [ 'name', 'password', 'type', 'host', 'user', 'port' ]);

    General::checkParams(args => $config->{amqp}, required => [ 'user', 'password' ]);

    if (! defined ($config->{dbconf}->{txn_commit_retry})) {
        $config->{dbconf}->{txn_commit_retry} = 10;
    }

    $config->{dbi} = "dbi:" . $config->{dbconf}->{type} . ":" . $config->{dbconf}->{name} .
                     ":" . $config->{dbconf}->{host} . ":" . $config->{dbconf}->{port};

    return $config;
}


=pod
=begin classdoc

Get the DBIx schema by connecting to the database server.

@return the whole databse schema

=end classdoc
=cut

sub _connectdb {
    my $class = shift;
    my %args  = @_;

    General::checkParams(args => \%args, required => [ 'config' ]);

    try {
        return AdministratorDB::Schema->connect($args{config}->{dbi},
                                                $args{config}->{dbconf}->{user},
                                                $args{config}->{dbconf}->{password},
                                                { mysql_enable_utf8 => 1 });
    }
    catch ($err) {
        throw Kanopya::Exception::Internal(error => $err);
    }
}


=pod
=begin classdoc

Update the PERL5LIB by adding additional components paths.

=end classdoc
=cut

sub _load_components {
    my ($self, @args) = @_;

    for my $component (glob(Kanopya::Config::getKanopyaDir . "/lib/component/*")) {
        push @INC, $component;
    }
}


=pod
=begin classdoc

We define an AUTOLOAD to mimic the DBIx behaviour, it simply calls 'getAttr'
that returns the specified attribute or the relation blessed to a BaseDB object.

@return the value returned by the call of the requested attribute.

=end classdoc
=cut

sub AUTOLOAD {
    my ($self, @args) = @_;

    my @autoload = split(/::/, $AUTOLOAD);
    my $accessor = $autoload[-1];

    if (scalar (@args)) {
        $self->setAttr(name => $accessor, value => $args[0], save => 1);
    } else {
        return $self->getAttr(name => $accessor, deep => 1);
    }
}


=pod
=begin classdoc

Method called at the object deletion.

=end classdoc
=cut

sub DESTROY {
    my $self = shift;

     # Commented the following block because the exceptions raised
     # by the call $self->save() are strangely not catched by the eval...
#    eval {
#        if ($self->{_altered}) {
#            $self->save();
#        }
#    };
#    if ($@) {
#        my $err = $@;
#        $log->debug("Unable to save <$self> at destroy: $err");
#    }
}


# Update the PERL5LIB for components
BEGIN {
    _load_components();
}

1;
