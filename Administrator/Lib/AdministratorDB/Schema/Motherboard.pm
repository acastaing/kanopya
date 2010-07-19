package AdministratorDB::Schema::Motherboard;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("motherboard");
__PACKAGE__->add_columns(
  "motherboard_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 8 },
  "motherboardtemplate_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 8 },
  "processortemplate_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 8 },
  "kernel_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 8 },
  "motherboard_sn",
  { data_type => "CHAR", default_value => undef, is_nullable => 0, size => 64 },
  "motherboard_slot_position",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 1 },
  "motherboard_desc",
  { data_type => "CHAR", default_value => undef, is_nullable => 1, size => 255 },
  "motherboard_active",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 1 },
);
__PACKAGE__->set_primary_key("motherboard_id");
__PACKAGE__->has_many(
  "motherboard_entities",
  "AdministratorDB::Schema::MotherboardEntity",
  { "foreign.motherboard_id" => "self.motherboard_id" },
);
__PACKAGE__->has_many(
  "motherboarddetails",
  "AdministratorDB::Schema::Motherboarddetails",
  { "foreign.motherboard_id" => "self.motherboard_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-07-19 01:22:21
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:EGXRWbcxVKtLcxHvXVMq5Q


# You can replace this text with custom content, and it will be preserved on regeneration
1;
