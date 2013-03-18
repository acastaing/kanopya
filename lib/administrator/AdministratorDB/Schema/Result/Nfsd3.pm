package AdministratorDB::Schema::Result::Nfsd3;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

AdministratorDB::Schema::Result::Nfsd3

=cut

__PACKAGE__->table("nfsd3");

=head1 ACCESSORS

=head2 nfsd3_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 nfsd3_statdopts

  data_type: 'char'
  is_nullable: 1
  size: 128

=head2 nfsd3_need_gssd

  data_type: 'enum'
  default_value: 'no'
  extra: {list => ["yes","no"]}
  is_nullable: 0

=head2 nfsd3_rpcnfsdcount

  data_type: 'integer'
  default_value: 8
  extra: {unsigned => 1}
  is_nullable: 0

=head2 nfsd3_rpcnfsdpriority

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 nfsd3_rpcmountopts

  data_type: 'char'
  is_nullable: 1
  size: 255

=head2 nfsd3_need_svcgssd

  data_type: 'enum'
  default_value: 'no'
  extra: {list => ["yes","no"]}
  is_nullable: 0

=head2 nfsd3_rpcsvcgssdopts

  data_type: 'char'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "nfsd3_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "nfsd3_statdopts",
  { data_type => "char", is_nullable => 1, size => 128 },
  "nfsd3_need_gssd",
  {
    data_type => "enum",
    default_value => "no",
    extra => { list => ["yes", "no"] },
    is_nullable => 0,
  },
  "nfsd3_rpcnfsdcount",
  {
    data_type => "integer",
    default_value => 8,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "nfsd3_rpcnfsdpriority",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "nfsd3_rpcmountopts",
  { data_type => "char", is_nullable => 1, size => 255 },
  "nfsd3_need_svcgssd",
  {
    data_type => "enum",
    default_value => "no",
    extra => { list => ["yes", "no"] },
    is_nullable => 0,
  },
  "nfsd3_rpcsvcgssdopts",
  { data_type => "char", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("nfsd3_id");

=head1 RELATIONS

=head2 nfsd3

Type: belongs_to

Related object: L<AdministratorDB::Schema::Result::Component>

=cut

__PACKAGE__->belongs_to(
  "nfsd3",
  "AdministratorDB::Schema::Result::Component",
  { component_id => "nfsd3_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);



# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-01-26 16:29:02
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:K8ME7Rj+8E+gm/YdpgaXoQ



# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->belongs_to(
  "parent",
  "AdministratorDB::Schema::Result::Component",
    { "foreign.component_id" => "self.nfsd3_id" },
    { cascade_copy => 0, cascade_delete => 1 });
1;
