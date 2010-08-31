package AdministratorDB::Schema::ProcessorModelEntity;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("+AdministratorDB::EntityBase", "Core");
__PACKAGE__->table("processor_model_entity");
__PACKAGE__->add_columns(
  "entity_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 8 },
  "processor_model_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 8 },
);
__PACKAGE__->set_primary_key("entity_id", "processor_model_id");
__PACKAGE__->add_unique_constraint("fk_processor_model_entity_2", ["processor_model_id"]);
__PACKAGE__->add_unique_constraint("fk_processor_model_entity_1", ["entity_id"]);
__PACKAGE__->belongs_to(
  "entity_id",
  "AdministratorDB::Schema::Entity",
  { entity_id => "entity_id" },
);
__PACKAGE__->belongs_to(
  "processor_model_id",
  "AdministratorDB::Schema::ProcessorModel",
  { processor_model_id => "processor_model_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-08-31 11:15:04
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:b9zvNLClUTUPREn5qVLWwA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
