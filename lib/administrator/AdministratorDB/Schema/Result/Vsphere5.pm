use utf8;
package AdministratorDB::Schema::Result::Vsphere5;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

AdministratorDB::Schema::Result::Vsphere5

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<vsphere5>

=cut

__PACKAGE__->table("vsphere5");

=head1 ACCESSORS

=head2 vsphere5_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "vsphere5_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</vsphere5_id>

=back

=cut

__PACKAGE__->set_primary_key("vsphere5_id");

=head1 RELATIONS

=head2 vsphere5

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::Component>

=cut

__PACKAGE__->belongs_to(
  "vsphere5",
  "AdministratorDB::Schema::Result::Component",
  { component_id => "vsphere5_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 vsphere5_hypervisors

Type: has_many

Related object: L<AdministratorDB::Schema::Result::Vsphere5Hypervisor>

=cut

__PACKAGE__->has_many(
  "vsphere5_hypervisors",
  "AdministratorDB::Schema::Result::Vsphere5Hypervisor",
  { "foreign.vsphere5_id" => "self.vsphere5_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 vsphere5_vms

Type: has_many

Related object: L<AdministratorDB::Schema::Result::Vsphere5Vm>

=cut

__PACKAGE__->has_many(
  "vsphere5_vms",
  "AdministratorDB::Schema::Result::Vsphere5Vm",
  { "foreign.vsphere5_id" => "self.vsphere5_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-08-14 19:34:40
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qHiHJ3fQNFaMBurxxiXVGw

__PACKAGE__->belongs_to(
  "parent",
  "AdministratorDB::Schema::Result::Component",
    { "foreign.component_id" => "self.vsphere5_id" },
    { cascade_copy => 0, cascade_delete => 1 } 
);

1;
