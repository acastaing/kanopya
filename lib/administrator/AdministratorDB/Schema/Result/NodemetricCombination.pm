package AdministratorDB::Schema::Result::NodemetricCombination;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

AdministratorDB::Schema::Result::NodemetricCombination

=cut

__PACKAGE__->table("nodemetric_combination");

=head1 ACCESSORS

=head2 nodemetric_combination_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 nodemetric_combination_formula

  data_type: 'char'
  is_nullable: 0
  size: 32

=head2 class_type_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "nodemetric_combination_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
    "nodemetric_combination_label",
  { data_type => "char", is_nullable => 1, size => 255 },
  "nodemetric_combination_formula",
  { data_type => "char", is_nullable => 0, size => 32 },
  "class_type_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);
__PACKAGE__->set_primary_key("nodemetric_combination_id");

=head1 RELATIONS

=head2 class_type

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::ClassType>

=cut

__PACKAGE__->belongs_to(
  "class_type",
  "AdministratorDB::Schema::Result::ClassType",
  { class_type_id => "class_type_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 nodemetric_conditions

Type: has_many

Related object: L<AdministratorDB::Schema::Result::NodemetricCondition>

=cut

__PACKAGE__->has_many(
  "nodemetric_conditions",
  "AdministratorDB::Schema::Result::NodemetricCondition",
  {
    "foreign.nodemetric_condition_combination_id" => "self.nodemetric_combination_id",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-03-05 14:43:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3S/VTpOrH6qNxzL0jXRSeQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
