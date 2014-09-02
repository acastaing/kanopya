use utf8;
package Kanopya::Schema::Result::Iface;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanopya::Schema::Result::Iface

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

=head1 TABLE: C<iface>

=cut

__PACKAGE__->table("iface");

=head1 ACCESSORS

=head2 iface_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 iface_name

  data_type: 'char'
  is_nullable: 0
  size: 32

=head2 iface_mac_addr

  data_type: 'char'
  is_nullable: 1
  size: 18

=head2 iface_pxe

  data_type: 'integer'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 1

=head2 host_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 master

  data_type: 'char'
  default_value: (empty string)
  is_nullable: 1
  size: 32

=cut

__PACKAGE__->add_columns(
  "iface_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "iface_name",
  { data_type => "char", is_nullable => 0, size => 32 },
  "iface_mac_addr",
  { data_type => "char", is_nullable => 1, size => 18 },
  "iface_pxe",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 1,
  },
  "host_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "master",
  { data_type => "char", default_value => "", is_nullable => 1, size => 32 },
);

=head1 PRIMARY KEY

=over 4

=item * L</iface_id>

=back

=cut

__PACKAGE__->set_primary_key("iface_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<iface_mac_addr>

=over 4

=item * L</iface_mac_addr>

=back

=cut

__PACKAGE__->add_unique_constraint("iface_mac_addr", ["iface_mac_addr"]);

=head2 C<iface_name>

=over 4

=item * L</iface_name>

=item * L</host_id>

=back

=cut

__PACKAGE__->add_unique_constraint("iface_name", ["iface_name", "host_id"]);

=head1 RELATIONS

=head2 host

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Host>

=cut

__PACKAGE__->belongs_to(
  "host",
  "Kanopya::Schema::Result::Host",
  { host_id => "host_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 iface

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Entity>

=cut

__PACKAGE__->belongs_to(
  "iface",
  "Kanopya::Schema::Result::Entity",
  { entity_id => "iface_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 ips

Type: has_many

Related object: L<Kanopya::Schema::Result::Ip>

=cut

__PACKAGE__->has_many(
  "ips",
  "Kanopya::Schema::Result::Ip",
  { "foreign.iface_id" => "self.iface_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 netconf_ifaces

Type: has_many

Related object: L<Kanopya::Schema::Result::NetconfIface>

=cut

__PACKAGE__->has_many(
  "netconf_ifaces",
  "Kanopya::Schema::Result::NetconfIface",
  { "foreign.iface_id" => "self.iface_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 netconfs

Type: many_to_many

Composing rels: L</netconf_ifaces> -> netconf

=cut

__PACKAGE__->many_to_many("netconfs", "netconf_ifaces", "netconf");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-06-27 11:45:21
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:y9JkgywxVHm+5Fif832GiA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
