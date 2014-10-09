use utf8;
package Kanopya::Schema::Result::Customer;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanopya::Schema::Result::Customer

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

=head1 TABLE: C<customer>

=cut

__PACKAGE__->table("customer");

=head1 ACCESSORS

=head2 customer_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "customer_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</customer_id>

=back

=cut

__PACKAGE__->set_primary_key("customer_id");

=head1 RELATIONS

=head2 customer

Type: belongs_to

Related object: L<Kanopya::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "customer",
  "Kanopya::Schema::Result::User",
  { user_id => "customer_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 stack_builder_customer

Type: might_have

Related object: L<Kanopya::Schema::Result::StackBuilderCustomer>

=cut

__PACKAGE__->might_have(
  "stack_builder_customer",
  "Kanopya::Schema::Result::StackBuilderCustomer",
  { "foreign.stack_builder_customer_id" => "self.customer_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-06-27 16:11:24
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:0lHRD54Oxsl655gd10j3jg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
