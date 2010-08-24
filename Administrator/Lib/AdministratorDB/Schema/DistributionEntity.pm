package AdministratorDB::Schema::DistributionEntity;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("+AdministratorDB::EntityBase", "Core");
__PACKAGE__->table("distribution_entity");
__PACKAGE__->add_columns(
  "entity_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 8 },
  "distribution_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 8 },
);
__PACKAGE__->set_primary_key("entity_id", "distribution_id");
__PACKAGE__->add_unique_constraint("fk_distribution_entity_2", ["distribution_id"]);
__PACKAGE__->add_unique_constraint("fk_distribution_entity_1", ["entity_id"]);
__PACKAGE__->belongs_to(
  "entity_id",
  "AdministratorDB::Schema::Entity",
  { entity_id => "entity_id" },
);
__PACKAGE__->belongs_to(
  "distribution_id",
  "AdministratorDB::Schema::Distribution",
  { distribution_id => "distribution_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-08-24 12:00:18
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:enRAcoNRn5f61t17Gd4x+g


# You can replace this text with custom content, and it will be preserved on regeneration
1;
