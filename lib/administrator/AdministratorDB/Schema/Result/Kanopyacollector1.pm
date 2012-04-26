use utf8;
package AdministratorDB::Schema::Result::Kanopyacollector1;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

AdministratorDB::Schema::Result::Kanopyacollector1

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<kanopyacollector1>

=cut

__PACKAGE__->table("kanopyacollector1");

=head1 ACCESSORS

=head2 kanopyacollector1_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 collect_frequency

  data_type: 'integer'
  default_value: 3600
  extra: {unsigned => 1}
  is_nullable: 0

=head2 storage_time

  data_type: 'integer'
  default_value: 86400
  extra: {unsigned => 1}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "kanopyacollector1_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "collect_frequency",
  {
    data_type => "integer",
    default_value => 3600,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "storage_time",
  {
    data_type => "integer",
    default_value => 86400,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
);

__PACKAGE__->set_primary_key("kanopyacollector1_id");

=head1 PRIMARY KEY

=over 4

=item * L</kanopyacollector1_id>

=back

=cut

__PACKAGE__->set_primary_key("kanopyacollector1_id");

=head1 RELATIONS

=head2 kanopyacollector1

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::Component>

=cut

__PACKAGE__->belongs_to(
  "kanopyacollector1",
  "AdministratorDB::Schema::Result::Component",
  { component_id => "kanopyacollector1_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->belongs_to(
  "parent",
  "AdministratorDB::Schema::Result::Component",
    { "foreign.component_id" => "self.kanopyacollector1_id" },
    { cascade_copy => 0, cascade_delete => 1 }
);


1;
