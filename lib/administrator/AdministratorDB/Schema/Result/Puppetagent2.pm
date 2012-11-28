package AdministratorDB::Schema::Result::Puppetagent2;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

AdministratorDB::Schema::Result::Puppetagent2

=cut

__PACKAGE__->table("puppetagent2");

=head1 ACCESSORS

=head2 puppetagent2_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 puppetagent2_options

  data_type: 'char'
  is_nullable: 1
  size: 255

=head2 puppetagent2_mode

  data_type: 'enum'
  default_value: 'kanopya'
  extra: {list => ["kanopya","custom"]}
  is_nullable: 0

=head2 puppetagent2_masterip

  data_type: 'char'
  is_nullable: 0
  size: 15

=head2 puppetagent2_masterfqdn

  data_type: 'char'
  is_nullable: 0
  size: 255

=cut

__PACKAGE__->add_columns(
  "puppetagent2_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "puppetagent2_options",
  { data_type => "char", is_nullable => 1, size => 255 },
  "puppetagent2_mode",
  {
    data_type => "enum",
    default_value => "kanopya",
    extra => { list => ["kanopya", "custom"] },
    is_nullable => 0,
  },
  "puppetagent2_masterip",
  { data_type => "char", is_nullable => 0, size => 15 },
  "puppetagent2_masterfqdn",
  { data_type => "char", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("puppetagent2_id");

=head1 RELATIONS

=head2 puppetagent2

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::Component>

=cut

__PACKAGE__->belongs_to(
  "puppetagent2",
  "AdministratorDB::Schema::Result::Component",
  { component_id => "puppetagent2_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-05-04 15:17:05
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:QnPLOylQQF7YKtBMrl1oyA

__PACKAGE__->belongs_to(
    "parent",
    "AdministratorDB::Schema::Result::Component",
    { "foreign.component_id" => "self.puppetagent2_id" },
    { cascade_copy => 0, cascade_delete => 1 });

1;
