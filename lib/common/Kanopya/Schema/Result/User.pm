use utf8;
package Kanopya::Schema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanopya::Schema::Result::User

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<DBIx::Class::IntrospectableM2M>

=cut

use base 'DBIx::Class::IntrospectableM2M';

=head1 LEFT BASE CLASSES

=over 4

=item * L<DBIx::Class::Core>

=back

=cut

use base qw/DBIx::Class::Core/;

=head1 TABLE: C<user>

=cut

__PACKAGE__->table("user");

=head1 ACCESSORS

=head2 user_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 user_system

  data_type: 'integer'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 user_login

  data_type: 'char'
  is_nullable: 0
  size: 32

=head2 user_password

  data_type: 'char'
  is_nullable: 0
  size: 255

=head2 user_firstname

  data_type: 'char'
  is_nullable: 1
  size: 64

=head2 user_lastname

  data_type: 'char'
  is_nullable: 1
  size: 64

=head2 user_email

  data_type: 'char'
  is_nullable: 1
  size: 255

=head2 user_creationdate

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 user_lastaccess

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 user_desc

  data_type: 'char'
  default_value: 'Note concerning this user'
  is_nullable: 1
  size: 255

=head2 user_sshkey

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "user_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "user_system",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "user_login",
  { data_type => "char", is_nullable => 0, size => 32 },
  "user_password",
  { data_type => "char", is_nullable => 0, size => 255 },
  "user_firstname",
  { data_type => "char", is_nullable => 1, size => 64 },
  "user_lastname",
  { data_type => "char", is_nullable => 1, size => 64 },
  "user_email",
  { data_type => "char", is_nullable => 1, size => 255 },
  "user_creationdate",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "user_lastaccess",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "user_desc",
  {
    data_type => "char",
    default_value => "Note concerning this user",
    is_nullable => 1,
    size => 255,
  },
  "user_sshkey",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</user_id>

=back

=cut

__PACKAGE__->set_primary_key("user_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<user_login>

=over 4

=item * L</user_login>

=back

=cut

__PACKAGE__->add_unique_constraint("user_login", ["user_login"]);

=head1 RELATIONS

=head2 customer

Type: might_have

Related object: L<Kanopya::Schema::Result::Customer>

=cut

__PACKAGE__->might_have(
  "customer",
  "Kanopya::Schema::Result::Customer",
  { "foreign.customer_id" => "self.user_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 entities

Type: has_many

Related object: L<Kanopya::Schema::Result::Entity>

=cut

__PACKAGE__->has_many(
  "entities",
  "Kanopya::Schema::Result::Entity",
  { "foreign.owner_id" => "self.user_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 messages

Type: has_many

Related object: L<Kanopya::Schema::Result::Message>

=cut

__PACKAGE__->has_many(
  "messages",
  "Kanopya::Schema::Result::Message",
  { "foreign.user_id" => "self.user_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 old_operations

Type: has_many

Related object: L<Kanopya::Schema::Result::OldOperation>

=cut

__PACKAGE__->has_many(
  "old_operations",
  "Kanopya::Schema::Result::OldOperation",
  { "foreign.user_id" => "self.user_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 quotas

Type: has_many

Related object: L<Kanopya::Schema::Result::Quota>

=cut

__PACKAGE__->has_many(
  "quotas",
  "Kanopya::Schema::Result::Quota",
  { "foreign.user_id" => "self.user_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Entity>

=cut

__PACKAGE__->belongs_to(
  "user",
  "Kanopya::Schema::Result::Entity",
  { entity_id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 user_extensions

Type: has_many

Related object: L<Kanopya::Schema::Result::UserExtension>

=cut

__PACKAGE__->has_many(
  "user_extensions",
  "Kanopya::Schema::Result::UserExtension",
  { "foreign.user_id" => "self.user_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_profiles

Type: has_many

Related object: L<Kanopya::Schema::Result::UserProfile>

=cut

__PACKAGE__->has_many(
  "user_profiles",
  "Kanopya::Schema::Result::UserProfile",
  { "foreign.user_id" => "self.user_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 profiles

Type: many_to_many

Composing rels: L</user_profiles> -> profile

=cut

__PACKAGE__->many_to_many("profiles", "user_profiles", "profile");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-06-27 11:45:21
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WvfBatcsQdhrsoXiFSRuyg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
