use utf8;
package AdministratorDB::Schema::Result::Clustermetric;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

AdministratorDB::Schema::Result::Clustermetric

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<clustermetric>

=cut

__PACKAGE__->table("clustermetric");

=head1 ACCESSORS

=head2 clustermetric_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 clustermetric_label

  data_type: 'char'
  is_nullable: 1
  size: 255

=head2 clustermetric_service_provider_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 clustermetric_indicator_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 clustermetric_statistics_function_name

  data_type: 'char'
  is_nullable: 0
  size: 32

=head2 clustermetric_formula_string

  data_type: 'text'
  is_nullable: 0

=head2 clustermetric_window_time

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "clustermetric_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "clustermetric_label",
  { data_type => "char", is_nullable => 1, size => 255 },
  "clustermetric_service_provider_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "clustermetric_indicator_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "clustermetric_statistics_function_name",
  { data_type => "char", is_nullable => 0, size => 32 },
  "clustermetric_formula_string",
  { data_type => "text", is_nullable => 0 },
  "clustermetric_window_time",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</clustermetric_id>

=back

=cut

__PACKAGE__->set_primary_key("clustermetric_id");

=head1 RELATIONS

=head2 clustermetric

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::Entity>

=cut

__PACKAGE__->belongs_to(
  "clustermetric",
  "AdministratorDB::Schema::Result::Entity",
  { entity_id => "clustermetric_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 clustermetric_indicator

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::CollectorIndicator>

=cut

__PACKAGE__->belongs_to(
  "clustermetric_indicator",
  "AdministratorDB::Schema::Result::CollectorIndicator",
  { collector_indicator_id => "clustermetric_indicator_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 clustermetric_service_provider

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::ServiceProvider>

=cut

__PACKAGE__->belongs_to(
  "clustermetric_service_provider",
  "AdministratorDB::Schema::Result::ServiceProvider",
  { service_provider_id => "clustermetric_service_provider_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07015 @ 2012-10-31 16:06:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/C5qvnV5AI45J/F81F2scQ

 __PACKAGE__->belongs_to(
   "parent",
     "AdministratorDB::Schema::Result::Entity",
         { "foreign.entity_id" => "self.clustermetric_id" },
             { cascade_copy => 0, cascade_delete => 1 }
 );


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
