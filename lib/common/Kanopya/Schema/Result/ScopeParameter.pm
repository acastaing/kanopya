use utf8;
package Kanopya::Schema::Result::ScopeParameter;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanopya::Schema::Result::ScopeParameter

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

=head1 TABLE: C<scope_parameter>

=cut

__PACKAGE__->table("scope_parameter");

=head1 ACCESSORS

=head2 scope_parameter_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 scope_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 scope_parameter_name

  data_type: 'char'
  is_nullable: 0
  size: 64

=cut

__PACKAGE__->add_columns(
  "scope_parameter_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "scope_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "scope_parameter_name",
  { data_type => "char", is_nullable => 0, size => 64 },
);

=head1 PRIMARY KEY

=over 4

=item * L</scope_parameter_id>

=back

=cut

__PACKAGE__->set_primary_key("scope_parameter_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<scope_id>

=over 4

=item * L</scope_id>

=item * L</scope_parameter_name>

=back

=cut

__PACKAGE__->add_unique_constraint("scope_id", ["scope_id", "scope_parameter_name"]);

=head1 RELATIONS

=head2 scope

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Scope>

=cut

__PACKAGE__->belongs_to(
  "scope",
  "Kanopya::Schema::Result::Scope",
  { scope_id => "scope_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-11-20 15:15:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/mlUjMgCeKYrl3ni4sAMRA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
