package AdministratorDB::Schema::Result::Syslogng3Log;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

AdministratorDB::Schema::Result::Syslogng3Log

=cut

__PACKAGE__->table("syslogng3_log");

=head1 ACCESSORS

=head2 syslogng3_log_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 syslogng3_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "syslogng3_log_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "syslogng3_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);
__PACKAGE__->set_primary_key("syslogng3_log_id");

=head1 RELATIONS

=head2 syslogng3

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::Syslogng3>

=cut

__PACKAGE__->belongs_to(
  "syslogng3",
  "AdministratorDB::Schema::Result::Syslogng3",
  { syslogng3_id => "syslogng3_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 syslogng3_log_params

Type: has_many

Related object: L<AdministratorDB::Schema::Result::Syslogng3LogParam>

=cut

__PACKAGE__->has_many(
  "syslogng3_log_params",
  "AdministratorDB::Schema::Result::Syslogng3LogParam",
  { "foreign.syslogng3_log_id" => "self.syslogng3_log_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-01-25 14:17:36
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2f3TQ5nz+4hfRY54yYwUxg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
