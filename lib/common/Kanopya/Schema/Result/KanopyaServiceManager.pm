use utf8;
package Kanopya::Schema::Result::KanopyaServiceManager;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanopya::Schema::Result::KanopyaServiceManager

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

=head1 TABLE: C<kanopya_service_manager>

=cut

__PACKAGE__->table("kanopya_service_manager");

=head1 ACCESSORS

=head2 kanopya_service_manager_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 kanopya_executor_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "kanopya_service_manager_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "kanopya_executor_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</kanopya_service_manager_id>

=back

=cut

__PACKAGE__->set_primary_key("kanopya_service_manager_id");

=head1 RELATIONS

=head2 kanopya_executor

Type: belongs_to

Related object: L<Kanopya::Schema::Result::KanopyaExecutor>

=cut

__PACKAGE__->belongs_to(
  "kanopya_executor",
  "Kanopya::Schema::Result::KanopyaExecutor",
  { kanopya_executor_id => "kanopya_executor_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 kanopya_service_manager

Type: belongs_to

Related object: L<Kanopya::Schema::Result::Component>

=cut

__PACKAGE__->belongs_to(
  "kanopya_service_manager",
  "Kanopya::Schema::Result::Component",
  { component_id => "kanopya_service_manager_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-04-09 17:48:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:15n/yyVHuryh9Ht4bxzbtg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
