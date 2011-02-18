package AdministratorDB::Schema::Result::ProcessormodelEntity;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

AdministratorDB::Schema::Result::ProcessormodelEntity

=cut

__PACKAGE__->table("processormodel_entity");

=head1 ACCESSORS

=head2 entity_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 processormodel_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "entity_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "processormodel_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);
__PACKAGE__->set_primary_key("entity_id", "processormodel_id");
__PACKAGE__->add_unique_constraint("fk_processormodel_entity_1", ["entity_id"]);
__PACKAGE__->add_unique_constraint("fk_processormodel_entity_2", ["processormodel_id"]);

=head1 RELATIONS

=head2 entity

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::Entity>

=cut

__PACKAGE__->belongs_to(
  "entity",
  "AdministratorDB::Schema::Result::Entity",
  { entity_id => "entity_id" },
  { on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 processormodel

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::Processormodel>

=cut

__PACKAGE__->belongs_to(
  "processormodel",
  "AdministratorDB::Schema::Result::Processormodel",
  { processormodel_id => "processormodel_id" },
  { on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2011-02-18 11:02:24
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kqajwrtQotRjeYK+URtRgQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
