package AdministratorDB::Schema::Result::Gp;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

AdministratorDB::Schema::Result::Gp

=cut

__PACKAGE__->table("gp");

=head1 ACCESSORS

=head2 gp_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 gp_name

  data_type: 'char'
  is_nullable: 0
  size: 32

=head2 gp_type

  data_type: 'char'
  is_nullable: 0
  size: 32

=head2 gp_desc

  data_type: 'char'
  is_nullable: 1
  size: 255

=head2 gp_system

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "gp_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "gp_name",
  { data_type => "char", is_nullable => 0, size => 32 },
  "gp_type",
  { data_type => "char", is_nullable => 0, size => 32 },
  "gp_desc",
  { data_type => "char", is_nullable => 1, size => 255 },
  "gp_system",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("gp_id");
__PACKAGE__->add_unique_constraint("gp_name", ["gp_name"]);

=head1 RELATIONS

=head2 gp

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::Entity>

=cut

__PACKAGE__->belongs_to(
  "gp",
  "AdministratorDB::Schema::Result::Entity",
  { entity_id => "gp_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 ingroups

Type: has_many

Related object: L<AdministratorDB::Schema::Result::Ingroup>

=cut

__PACKAGE__->has_many(
  "ingroups",
  "AdministratorDB::Schema::Result::Ingroup",
  { "foreign.gp_id" => "self.gp_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 profile_gps

Type: has_many

Related object: L<AdministratorDB::Schema::Result::ProfileGp>

=cut

__PACKAGE__->has_many(
  "profile_gps",
  "AdministratorDB::Schema::Result::ProfileGp",
  { "foreign.gp_id" => "self.gp_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-07-27 15:30:11
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Kk4td0dA8zemg+FRBHvofQ

__PACKAGE__->belongs_to(
  "parent",
  "AdministratorDB::Schema::Result::Entity",
  { entity_id => "gp_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

1;
