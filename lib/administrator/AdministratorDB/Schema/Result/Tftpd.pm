package AdministratorDB::Schema::Result::Tftpd;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

AdministratorDB::Schema::Result::Tftpd

=cut

__PACKAGE__->table("tftpd");

=head1 ACCESSORS

=head2 tftpd_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 tftpd_repository

  data_type: 'char'
  is_nullable: 1
  size: 64

=cut

__PACKAGE__->add_columns(
  "tftpd_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "tftpd_repository",
  { data_type => "char", is_nullable => 1, size => 64 },
);
__PACKAGE__->set_primary_key("tftpd_id");

=head1 RELATIONS

=head2 tftpd

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::Component>

=cut

__PACKAGE__->belongs_to(
  "tftpd",
  "AdministratorDB::Schema::Result::Component",
  { component_id => "tftpd_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-01-26 16:29:02
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:oK+lLPcB20mmsVVOOGELZA


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->belongs_to(
  "parent",
  "AdministratorDB::Schema::Result::Component",
    { "foreign.component_id" => "self.tftpd_id" },
    { cascade_copy => 0, cascade_delete => 1 });
1;
