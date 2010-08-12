package AdministratorDB::Schema::Motherboard;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("+AdministratorDB::EntityBase", "Core");
__PACKAGE__->table("motherboard");
__PACKAGE__->add_columns(
  "motherboard_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 8 },
  "motherboard_model_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 8 },
  "processor_model_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 8 },
  "kernel_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 8 },
  "motherboard_sn",
  { data_type => "CHAR", default_value => undef, is_nullable => 0, size => 64 },
  "motherboard_slot_position",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 1 },
  "motherboard_desc",
  { data_type => "CHAR", default_value => undef, is_nullable => 1, size => 255 },
  "active",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 1 },
  "motherboard_mac_address",
  { data_type => "CHAR", default_value => undef, is_nullable => 0, size => 18 },
  "motherboard_initiatorname",
  { data_type => "CHAR", default_value => undef, is_nullable => 1, size => 64 },
  "motherboard_internal_ip",
  { data_type => "CHAR", default_value => undef, is_nullable => 1, size => 15 },
  "motherboard_hostname",
  { data_type => "CHAR", default_value => undef, is_nullable => 1, size => 32 },
  "etc_device_id",
  { data_type => "INT", default_value => undef, is_nullable => 1, size => 8 },
);
__PACKAGE__->set_primary_key("motherboard_id");
__PACKAGE__->add_unique_constraint("motherboard_internal_ip_UNIQUE", ["motherboard_internal_ip"]);
__PACKAGE__->belongs_to(
  "motherboard_model_id",
  "AdministratorDB::Schema::MotherboardModel",
  { motherboard_model_id => "motherboard_model_id" },
);
__PACKAGE__->belongs_to(
  "processor_model_id",
  "AdministratorDB::Schema::ProcessorModel",
  { processor_model_id => "processor_model_id" },
);
__PACKAGE__->belongs_to(
  "kernel_id",
  "AdministratorDB::Schema::Kernel",
  { kernel_id => "kernel_id" },
);
__PACKAGE__->belongs_to(
  "etc_device_id",
  "AdministratorDB::Schema::Lvm2Lv",
  { lvm2_lv_id => "etc_device_id" },
);
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
__PACKAGE__->has_many(
  "nodes",
  "AdministratorDB::Schema::Node",
  { "foreign.motherboard_id" => "self.motherboard_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-08-12 12:39:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2K5MpbohFt6rC8wqgUOpbQ


# You can replace this text with custom content, and it will be preserved on regeneration

__PACKAGE__->has_one(
  "entitylink",
  "AdministratorDB::Schema::MotherboardEntity",
  { "foreign.motherboard_id" => "self.motherboard_id" },
);

__PACKAGE__->has_many(
  "motherboardext",
  "AdministratorDB::Schema::Motherboarddetails",
  { "foreign.motherboard_id" => "self.motherboard_id" },
);
1;
