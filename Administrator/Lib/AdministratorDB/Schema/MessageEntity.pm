package AdministratorDB::Schema::MessageEntity;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("+AdministratorDB::EntityBase", "Core");
__PACKAGE__->table("message_entity");
__PACKAGE__->add_columns(
  "entity_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 8 },
  "message_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 8 },
);
__PACKAGE__->set_primary_key("entity_id", "message_id");
__PACKAGE__->belongs_to(
  "entity_id",
  "AdministratorDB::Schema::Entity",
  { entity_id => "entity_id" },
);
__PACKAGE__->belongs_to(
  "message_id",
  "AdministratorDB::Schema::Message",
  { message_id => "message_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-08-08 19:33:18
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:aUzx166w/ojqQawDKYiU+A


# You can replace this text with custom content, and it will be preserved on regeneration
1;
