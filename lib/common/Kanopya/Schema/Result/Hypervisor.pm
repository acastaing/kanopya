use utf8;
package Kanopya::Schema::Result::Hypervisor;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanopya::Schema::Result::Hypervisor

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

=head1 TABLE: C<hypervisor>

=cut

__PACKAGE__->table("hypervisor");

=head1 ACCESSORS

=head2 hypervisor_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "hypervisor_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</hypervisor_id>

=back

=cut

__PACKAGE__->set_primary_key("hypervisor_id");

=head1 RELATIONS

=head2 hypervisor

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Host>

=cut

__PACKAGE__->belongs_to(
  "hypervisor",
  "Kanopya::Schema::Result::Host",
  { host_id => "hypervisor_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 virtual_machines

Type: has_many

Related object: L<Kanopya::Schema::Result::VirtualMachine>

=cut

__PACKAGE__->has_many(
  "virtual_machines",
  "Kanopya::Schema::Result::VirtualMachine",
  { "foreign.hypervisor_id" => "self.hypervisor_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-06-27 11:45:21
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GgG+lq+vxCgGe0iRNtU4WQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
