use utf8;
package Kanopya::Schema::Result::WorkflowDef;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanopya::Schema::Result::WorkflowDef

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

=head1 TABLE: C<workflow_def>

=cut

__PACKAGE__->table("workflow_def");

=head1 ACCESSORS

=head2 workflow_def_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 workflow_def_name

  data_type: 'char'
  is_nullable: 1
  size: 64

=head2 param_preset_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 workflow_def_origin_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "workflow_def_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "workflow_def_name",
  { data_type => "char", is_nullable => 1, size => 64 },
  "param_preset_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "workflow_def_origin_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</workflow_def_id>

=back

=cut

__PACKAGE__->set_primary_key("workflow_def_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<workflow_def_name>

=over 4

=item * L</workflow_def_name>

=back

=cut

__PACKAGE__->add_unique_constraint("workflow_def_name", ["workflow_def_name"]);

=head1 RELATIONS

=head2 param_preset

Type: belongs_to

Related object: L<Kanopya::Schema::Result::ParamPreset>

=cut

__PACKAGE__->belongs_to(
  "param_preset",
  "Kanopya::Schema::Result::ParamPreset",
  { param_preset_id => "param_preset_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);

=head2 rules

Type: has_many

Related object: L<Kanopya::Schema::Result::Rule>

=cut

__PACKAGE__->has_many(
  "rules",
  "Kanopya::Schema::Result::Rule",
  { "foreign.workflow_def_id" => "self.workflow_def_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 workflow_def

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Entity>

=cut

__PACKAGE__->belongs_to(
  "workflow_def",
  "Kanopya::Schema::Result::Entity",
  { entity_id => "workflow_def_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 workflow_def_managers

Type: has_many

Related object: L<Kanopya::Schema::Result::WorkflowDefManager>

=cut

__PACKAGE__->has_many(
  "workflow_def_managers",
  "Kanopya::Schema::Result::WorkflowDefManager",
  { "foreign.workflow_def_id" => "self.workflow_def_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 workflow_def_origin

Type: belongs_to

Related object: L<Kanopya::Schema::Result::WorkflowDef>

=cut

__PACKAGE__->belongs_to(
  "workflow_def_origin",
  "Kanopya::Schema::Result::WorkflowDef",
  { workflow_def_id => "workflow_def_origin_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);

=head2 workflow_defs

Type: has_many

Related object: L<Kanopya::Schema::Result::WorkflowDef>

=cut

__PACKAGE__->has_many(
  "workflow_defs",
  "Kanopya::Schema::Result::WorkflowDef",
  { "foreign.workflow_def_origin_id" => "self.workflow_def_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 workflow_steps

Type: has_many

Related object: L<Kanopya::Schema::Result::WorkflowStep>

=cut

__PACKAGE__->has_many(
  "workflow_steps",
  "Kanopya::Schema::Result::WorkflowStep",
  { "foreign.workflow_def_id" => "self.workflow_def_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-11-20 15:15:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8E1xiFmn8qSZGdjadG9iUg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;