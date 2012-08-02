package AdministratorDB::Schema::Result::AggregateRule;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

AdministratorDB::Schema::Result::AggregateRule

=cut

__PACKAGE__->table("aggregate_rule");

=head1 ACCESSORS

=head2 aggregate_rule_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 aggregate_rule_label

  data_type: 'char'
  is_nullable: 1
  size: 255

=head2 aggregate_rule_service_provider_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 aggregate_rule_formula

  data_type: 'char'
  is_nullable: 0
  size: 32

=head2 aggregate_rule_last_eval

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 aggregate_rule_timestamp

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 aggregate_rule_state

  data_type: 'char'
  is_nullable: 0
  size: 32

=head2 workflow_def_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 aggregate_rule_description

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "aggregate_rule_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "aggregate_rule_label",
  { data_type => "char", is_nullable => 1, size => 255 },
  "aggregate_rule_service_provider_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "aggregate_rule_formula",
  { data_type => "char", is_nullable => 0, size => 32 },
  "aggregate_rule_last_eval",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "aggregate_rule_timestamp",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "aggregate_rule_state",
  { data_type => "char", is_nullable => 0, size => 32 },
  "workflow_def_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "aggregate_rule_description",
  { data_type => "text", is_nullable => 1 },
  "workflow_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "workflow_untriggerable_timestamp",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },

);
__PACKAGE__->set_primary_key("aggregate_rule_id");

=head1 RELATIONS

=head2 workflow_def

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::WorkflowDef>

=cut

__PACKAGE__->belongs_to(
  "workflow_def",
  "AdministratorDB::Schema::Result::WorkflowDef",
  { workflow_def_id => "workflow_def_id" },
  { join_type => "LEFT", on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 aggregate_rule_service_provider

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::ServiceProvider>

=cut

__PACKAGE__->belongs_to(
  "aggregate_rule_service_provider",
  "AdministratorDB::Schema::Result::ServiceProvider",
  { service_provider_id => "aggregate_rule_service_provider_id" },
  { on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 workflow

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::Workflow>

=cut

__PACKAGE__->belongs_to(
  "workflow",
  "AdministratorDB::Schema::Result::Workflow",
  { workflow_id => "workflow_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

# Created by DBIx::Class::Schema::Loader v0.07000 @ 2012-06-15 11:21:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:88/0pacUNSkKLngBmLPsNg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
