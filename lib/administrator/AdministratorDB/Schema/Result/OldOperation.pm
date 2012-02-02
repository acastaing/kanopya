package AdministratorDB::Schema::Result::OldOperation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

AdministratorDB::Schema::Result::OldOperation

=cut

__PACKAGE__->table("old_operation");

=head1 ACCESSORS

=head2 old_operation_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 type

  data_type: 'char'
  is_foreign_key: 1
  is_nullable: 0
  size: 64

=head2 user_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 priority

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 creation_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 creation_time

  data_type: 'time'
  is_nullable: 0

=head2 execution_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 execution_time

  data_type: 'time'
  is_nullable: 0

=head2 execution_status

  data_type: 'char'
  is_nullable: 0
  size: 32

=cut

__PACKAGE__->add_columns(
  "old_operation_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "type",
  { data_type => "char", is_foreign_key => 1, is_nullable => 0, size => 64 },
  "user_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "priority",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 0 },
  "creation_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 0 },
  "creation_time",
  { data_type => "time", is_nullable => 0 },
  "execution_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 0 },
  "execution_time",
  { data_type => "time", is_nullable => 0 },
  "execution_status",
  { data_type => "char", is_nullable => 0, size => 32 },
);
__PACKAGE__->set_primary_key("old_operation_id");

=head1 RELATIONS

=head2 user

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "AdministratorDB::Schema::Result::User",
  { user_id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 type

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::Operationtype>

=cut

__PACKAGE__->belongs_to(
  "type",
  "AdministratorDB::Schema::Result::Operationtype",
  { operationtype_name => "type" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 old_operation_parameters

Type: has_many

Related object: L<AdministratorDB::Schema::Result::OldOperationParameter>

=cut

__PACKAGE__->has_many(
  "old_operation_parameters",
  "AdministratorDB::Schema::Result::OldOperationParameter",
  { "foreign.old_operation_id" => "self.old_operation_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-01-25 14:17:36
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ifJb/JogJIEYY/ot4YdwKQ


# You can replace this text with custom content, and it will be preserved on regeneration

1;
