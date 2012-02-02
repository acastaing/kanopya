package AdministratorDB::Schema::Result::Keepalived1;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

AdministratorDB::Schema::Result::Keepalived1

=cut

__PACKAGE__->table("keepalived1");

=head1 ACCESSORS

=head2 keepalived_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 daemon_method

  data_type: 'enum'
  default_value: 'master'
  extra: {list => ["master","backup","both"]}
  is_nullable: 0

=head2 iface

  data_type: 'char'
  is_nullable: 1
  size: 64

=head2 notification_email

  data_type: 'char'
  default_value: 'admin@hedera-technology.com'
  is_nullable: 1
  size: 255

=head2 notification_email_from

  data_type: 'char'
  default_value: 'keepalived@some-cluster.com'
  is_nullable: 1
  size: 255

=head2 smtp_server

  data_type: 'char'
  is_nullable: 0
  size: 39

=head2 smtp_connect_timeout

  data_type: 'integer'
  default_value: 30
  extra: {unsigned => 1}
  is_nullable: 0

=head2 lvs_id

  data_type: 'char'
  default_value: 'MAIN_LVS'
  is_nullable: 0
  size: 32

=cut

__PACKAGE__->add_columns(
  "keepalived_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "daemon_method",
  {
    data_type => "enum",
    default_value => "master",
    extra => { list => ["master", "backup", "both"] },
    is_nullable => 0,
  },
  "iface",
  { data_type => "char", is_nullable => 1, size => 64 },
  "notification_email",
  {
    data_type => "char",
    default_value => "admin\@hedera-technology.com",
    is_nullable => 1,
    size => 255,
  },
  "notification_email_from",
  {
    data_type => "char",
    default_value => "keepalived\@some-cluster.com",
    is_nullable => 1,
    size => 255,
  },
  "smtp_server",
  { data_type => "char", is_nullable => 0, size => 39 },
  "smtp_connect_timeout",
  {
    data_type => "integer",
    default_value => 30,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "lvs_id",
  {
    data_type => "char",
    default_value => "MAIN_LVS",
    is_nullable => 0,
    size => 32,
  },
);
__PACKAGE__->set_primary_key("keepalived_id");

=head1 RELATIONS

=head2 keepalived

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::Component>

=cut

__PACKAGE__->belongs_to(
  "keepalived",
  "AdministratorDB::Schema::Result::Component",
  { component_id => "keepalived_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 keepalived1_virtualservers

Type: has_many

Related object: L<AdministratorDB::Schema::Result::Keepalived1Virtualserver>

=cut

__PACKAGE__->has_many(
  "keepalived1_virtualservers",
  "AdministratorDB::Schema::Result::Keepalived1Virtualserver",
  { "foreign.keepalived_id" => "self.keepalived_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-01-26 17:01:55
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:pxoNDB0lrkMWX49S5MwDNA


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->belongs_to(
  "parent",
  "AdministratorDB::Schema::Result::Component",
    { "foreign.component_id" => "self.keepalived_id" },
    { cascade_copy => 0, cascade_delete => 1 });
1;
