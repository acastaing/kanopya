use utf8;
package Kanopya::Schema::Result::NovaController;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanopya::Schema::Result::NovaController

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

=head1 TABLE: C<nova_controller>

=cut

__PACKAGE__->table("nova_controller");

=head1 ACCESSORS

=head2 nova_controller_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 mysql5_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 amqp_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 keystone_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 kanopya_openstack_sync_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 api_user

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 api_password

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "nova_controller_id",
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
  "amqp_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "keystone_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "kanopya_openstack_sync_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "api_user",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "api_password",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</nova_controller_id>

=back

=cut

__PACKAGE__->set_primary_key("nova_controller_id");

=head1 RELATIONS

=head2 amqp

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Amqp>

=cut

__PACKAGE__->belongs_to(
  "amqp",
  "Kanopya::Schema::Result::Amqp",
  { amqp_id => "amqp_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);

=head2 cinders

Type: has_many

Related object: L<Kanopya::Schema::Result::Cinder>

=cut

__PACKAGE__->has_many(
  "cinders",
  "Kanopya::Schema::Result::Cinder",
  { "foreign.nova_controller_id" => "self.nova_controller_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 glances

Type: has_many

Related object: L<Kanopya::Schema::Result::Glance>

=cut

__PACKAGE__->has_many(
  "glances",
  "Kanopya::Schema::Result::Glance",
  { "foreign.nova_controller_id" => "self.nova_controller_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 kanopya_openstack_sync

Type: belongs_to

Related object: L<Kanopya::Schema::Result::KanopyaOpenstackSync>

=cut

__PACKAGE__->belongs_to(
  "kanopya_openstack_sync",
  "Kanopya::Schema::Result::KanopyaOpenstackSync",
  { kanopya_openstack_sync_id => "kanopya_openstack_sync_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);

=head2 keystone

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Keystone>

=cut

__PACKAGE__->belongs_to(
  "keystone",
  "Kanopya::Schema::Result::Keystone",
  { keystone_id => "keystone_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);

=head2 mysql5

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Mysql5>

=cut

__PACKAGE__->belongs_to(
  "mysql5",
  "Kanopya::Schema::Result::Mysql5",
  { mysql5_id => "mysql5_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);

=head2 neutrons

Type: has_many

Related object: L<Kanopya::Schema::Result::Neutron>

=cut

__PACKAGE__->has_many(
  "neutrons",
  "Kanopya::Schema::Result::Neutron",
  { "foreign.nova_controller_id" => "self.nova_controller_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nova_controller

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Virtualization>

=cut

__PACKAGE__->belongs_to(
  "nova_controller",
  "Kanopya::Schema::Result::Virtualization",
  { virtualization_id => "nova_controller_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-08-22 14:07:48
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:RISh1ROPZsizkD5FwdX8SA

# You can replace this text with custom code or comments, and it will be preserved on regeneration

1;
