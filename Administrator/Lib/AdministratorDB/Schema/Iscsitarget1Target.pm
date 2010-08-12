package AdministratorDB::Schema::Iscsitarget1Target;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("+AdministratorDB::EntityBase", "Core");
__PACKAGE__->table("iscsitarget1_target");
__PACKAGE__->add_columns(
  "component_instance_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 8 },
  "iscsitarget1_target_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 8 },
  "iscsitarget1_target_name",
  { data_type => "CHAR", default_value => undef, is_nullable => 0, size => 128 },
  "mountpoint",
  { data_type => "CHAR", default_value => undef, is_nullable => 1, size => 64 },
  "mount_option",
  { data_type => "CHAR", default_value => undef, is_nullable => 1, size => 32 },
);
__PACKAGE__->set_primary_key("iscsitarget1_target_id");
__PACKAGE__->has_many(
  "iscsitarget1_luns",
  "AdministratorDB::Schema::Iscsitarget1Lun",
  {
    "foreign.iscsitarget1_target_id" => "self.iscsitarget1_target_id",
  },
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-08-12 14:38:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:k9i4JTQBzchPUKz6pDwhGA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
