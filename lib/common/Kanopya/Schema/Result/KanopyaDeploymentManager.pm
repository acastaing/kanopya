use utf8;
package Kanopya::Schema::Result::KanopyaDeploymentManager;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanopya::Schema::Result::KanopyaDeploymentManager

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

=head1 TABLE: C<kanopya_deployment_manager>

=cut

__PACKAGE__->table("kanopya_deployment_manager");

=head1 ACCESSORS

=head2 kanopya_deployment_manager_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 kanopya_executor_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 dhcp_component_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 tftp_component_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 system_component_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "kanopya_deployment_manager_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "kanopya_executor_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "dhcp_component_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "tftp_component_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "system_component_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</kanopya_deployment_manager_id>

=back

=cut

__PACKAGE__->set_primary_key("kanopya_deployment_manager_id");

=head1 RELATIONS

=head2 dhcp_component

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Component>

=cut

__PACKAGE__->belongs_to(
  "dhcp_component",
  "Kanopya::Schema::Result::Component",
  { component_id => "dhcp_component_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 kanopya_deployment_manager

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Component>

=cut

__PACKAGE__->belongs_to(
  "kanopya_deployment_manager",
  "Kanopya::Schema::Result::Component",
  { component_id => "kanopya_deployment_manager_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 kanopya_executor

Type: belongs_to

Related object: L<Kanopya::Schema::Result::KanopyaExecutor>

=cut

__PACKAGE__->belongs_to(
  "kanopya_executor",
  "Kanopya::Schema::Result::KanopyaExecutor",
  { kanopya_executor_id => "kanopya_executor_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 system_component

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Component>

=cut

__PACKAGE__->belongs_to(
  "system_component",
  "Kanopya::Schema::Result::Component",
  { component_id => "system_component_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 tftp_component

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Component>

=cut

__PACKAGE__->belongs_to(
  "tftp_component",
  "Kanopya::Schema::Result::Component",
  { component_id => "tftp_component_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-04-11 12:10:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HX5ile4gWMd77O6Hq8heoQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
