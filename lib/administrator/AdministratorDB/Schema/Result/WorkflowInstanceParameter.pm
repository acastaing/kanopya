package AdministratorDB::Schema::Result::WorkflowInstanceParameter;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

AdministratorDB::Schema::Result::WorkflowInstanceParameter

=cut

__PACKAGE__->table("workflow_instance_parameter");

=head1 ACCESSORS

=head2 workflow_instance_parameter_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 workflow_instance_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 workflow_instance_parameter_name

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 workflow_instance_parameter_value

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 class_type_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "workflow_instance_parameter_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "workflow_instance_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "workflow_instance_parameter_name",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 0 },
  "workflow_instance_parameter_value",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 0 },
  "class_type_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);
__PACKAGE__->set_primary_key("workflow_instance_parameter_id");

=head1 RELATIONS

=head2 class_type

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::ClassType>

=cut

__PACKAGE__->belongs_to(
  "class_type",
  "AdministratorDB::Schema::Result::ClassType",
  { class_type_id => "class_type_id" },
  { on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 workflow_instance

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::WorkflowInstance>

=cut

__PACKAGE__->belongs_to(
  "workflow_instance",
  "AdministratorDB::Schema::Result::WorkflowInstance",
  { workflow_instance_id => "workflow_instance_id" },
  { on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2012-05-30 14:27:01
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:MN3jIF8PlyFHwkgftjUXig


# You can replace this text with custom content, and it will be preserved on regeneration
1;
