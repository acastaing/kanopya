use utf8;
package Kanopya::Schema::Result::SystemimageContainerAccess;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanopya::Schema::Result::SystemimageContainerAccess

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

=head1 TABLE: C<systemimage_container_access>

=cut

__PACKAGE__->table("systemimage_container_access");

=head1 ACCESSORS

=head2 systemimage_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 container_access_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "systemimage_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "container_access_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</systemimage_id>

=item * L</container_access_id>

=back

=cut

__PACKAGE__->set_primary_key("systemimage_id", "container_access_id");

=head1 RELATIONS

=head2 container_access

Type: belongs_to

Related object: L<Kanopya::Schema::Result::ContainerAccess>

=cut

__PACKAGE__->belongs_to(
  "container_access",
  "Kanopya::Schema::Result::ContainerAccess",
  { container_access_id => "container_access_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 systemimage

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Systemimage>

=cut

__PACKAGE__->belongs_to(
  "systemimage",
  "Kanopya::Schema::Result::Systemimage",
  { systemimage_id => "systemimage_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-11-20 15:15:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:vG0ZQ1hIIwTpSTyR7A2RSA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
