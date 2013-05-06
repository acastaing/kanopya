use utf8;
package AdministratorDB::Schema::Result::Cinder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

AdministratorDB::Schema::Result::Cinder

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<DBIx::Class::IntrospectableM2M>

=cut

use base 'DBIx::Class::IntrospectableM2M';

=head1 LEFT BASE CLASSES

=over 4

=item * L<DBIx::Class::Core>

=back

=cut

use base qw/DBIx::Class::Core/;

=head1 TABLE: C<cinder>

=cut

__PACKAGE__->table("cinder");

=head1 ACCESSORS

=head2 cinder_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 mysql5_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "cinder_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "mysql5_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</cinder_id>

=back

=cut

__PACKAGE__->set_primary_key("cinder_id");

=head1 RELATIONS

=head2 cinder

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::Component>

=cut

__PACKAGE__->belongs_to(
  "cinder",
  "AdministratorDB::Schema::Result::Component",
  { component_id => "cinder_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 mysql5

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::Mysql5>

=cut

__PACKAGE__->belongs_to(
  "mysql5",
  "AdministratorDB::Schema::Result::Mysql5",
  { mysql5_id => "mysql5_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 nova_controllers

Type: has_many

Related object: L<AdministratorDB::Schema::Result::NovaController>

=cut
 
__PACKAGE__->has_many(
  "nova_controllers",
  "AdministratorDB::Schema::Result::NovaController",
  { "foreign.cinder_id" => "self.cinder_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-05-07 01:08:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wqXgRVXSkSwiRktqruJUOA

__PACKAGE__->belongs_to(
  "parent",
  "AdministratorDB::Schema::Result::Component",
    { "foreign.component_id" => "self.cinder_id" },
    { cascade_copy => 0, cascade_delete => 1 });

1;
