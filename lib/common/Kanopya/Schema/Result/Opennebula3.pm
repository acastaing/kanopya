use utf8;
package Kanopya::Schema::Result::Opennebula3;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanopya::Schema::Result::Opennebula3

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

=head1 TABLE: C<opennebula3>

=cut

__PACKAGE__->table("opennebula3");

=head1 ACCESSORS

=head2 opennebula3_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 install_dir

  data_type: 'char'
  default_value: '/srv/cloud/one'
  is_nullable: 0
  size: 255

=head2 host_monitoring_interval

  data_type: 'integer'
  default_value: 600
  extra: {unsigned => 1}
  is_nullable: 0

=head2 vm_polling_interval

  data_type: 'integer'
  default_value: 600
  extra: {unsigned => 1}
  is_nullable: 0

=head2 vm_dir

  data_type: 'char'
  default_value: '/srv/cloud/one/var'
  is_nullable: 0
  size: 255

=head2 scripts_remote_dir

  data_type: 'char'
  default_value: '/var/tmp/one'
  is_nullable: 0
  size: 255

=head2 image_repository_path

  data_type: 'char'
  default_value: '/srv/cloud/images'
  is_nullable: 0
  size: 255

=head2 port

  data_type: 'integer'
  default_value: 2633
  extra: {unsigned => 1}
  is_nullable: 0

=head2 hypervisor

  data_type: 'char'
  default_value: 'xen'
  is_nullable: 0
  size: 255

=head2 debug_level

  data_type: 'enum'
  default_value: 3
  extra: {list => [0,1,2,3]}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "opennebula3_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "install_dir",
  {
    data_type => "char",
    default_value => "/srv/cloud/one",
    is_nullable => 0,
    size => 255,
  },
  "host_monitoring_interval",
  {
    data_type => "integer",
    default_value => 600,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "vm_polling_interval",
  {
    data_type => "integer",
    default_value => 600,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "vm_dir",
  {
    data_type => "char",
    default_value => "/srv/cloud/one/var",
    is_nullable => 0,
    size => 255,
  },
  "scripts_remote_dir",
  {
    data_type => "char",
    default_value => "/var/tmp/one",
    is_nullable => 0,
    size => 255,
  },
  "image_repository_path",
  {
    data_type => "char",
    default_value => "/srv/cloud/images",
    is_nullable => 0,
    size => 255,
  },
  "port",
  {
    data_type => "integer",
    default_value => 2633,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "hypervisor",
  { data_type => "char", default_value => "xen", is_nullable => 0, size => 255 },
  "debug_level",
  {
    data_type => "enum",
    default_value => 3,
    extra => { list => [0 .. 3] },
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</opennebula3_id>

=back

=cut

__PACKAGE__->set_primary_key("opennebula3_id");

=head1 RELATIONS

=head2 opennebula3

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Virtualization>

=cut

__PACKAGE__->belongs_to(
  "opennebula3",
  "Kanopya::Schema::Result::Virtualization",
  { virtualization_id => "opennebula3_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 opennebula3_vms

Type: has_many

Related object: L<Kanopya::Schema::Result::Opennebula3Vm>

=cut

__PACKAGE__->has_many(
  "opennebula3_vms",
  "Kanopya::Schema::Result::Opennebula3Vm",
  { "foreign.opennebula3_id" => "self.opennebula3_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-08-26 16:00:13
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:by+eKD+1aVz2mf2wS7ubWg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
