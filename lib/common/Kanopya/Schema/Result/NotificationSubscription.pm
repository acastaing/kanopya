use utf8;
package Kanopya::Schema::Result::NotificationSubscription;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanopya::Schema::Result::NotificationSubscription

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

=head1 TABLE: C<notification_subscription>

=cut

__PACKAGE__->table("notification_subscription");

=head1 ACCESSORS

=head2 notification_subscription_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 subscriber_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 entity_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 operationtype_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 operation_state

  data_type: 'char'
  default_value: 'processing'
  is_nullable: 0
  size: 32

=head2 validation

  data_type: 'integer'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "notification_subscription_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "subscriber_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "entity_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "operationtype_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "operation_state",
  {
    data_type => "char",
    default_value => "processing",
    is_nullable => 0,
    size => 32,
  },
  "validation",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</notification_subscription_id>

=back

=cut

__PACKAGE__->set_primary_key("notification_subscription_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<subscriber_id>

=over 4

=item * L</subscriber_id>

=item * L</entity_id>

=item * L</operationtype_id>

=item * L</operation_state>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "subscriber_id",
  [
    "subscriber_id",
    "entity_id",
    "operationtype_id",
    "operation_state",
  ],
);

=head1 RELATIONS

=head2 entity

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Entity>

=cut

__PACKAGE__->belongs_to(
  "entity",
  "Kanopya::Schema::Result::Entity",
  { entity_id => "entity_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 operationtype

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Operationtype>

=cut

__PACKAGE__->belongs_to(
  "operationtype",
  "Kanopya::Schema::Result::Operationtype",
  { operationtype_id => "operationtype_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);

=head2 subscriber

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Entity>

=cut

__PACKAGE__->belongs_to(
  "subscriber",
  "Kanopya::Schema::Result::Entity",
  { entity_id => "subscriber_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-05-13 11:28:31
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:98orsMM2hLh3k1PThR4Low


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
