# MakeSchema.pl This file allows to generate/update ORM modules
#    Copyright © 2011 Hedera Technology SAS
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as
#    published by the Free Software Foundation, either version 3 of the
#    License, or (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.
# Created 14 july 2010
use DBIx::Class::Schema::Loader qw/ make_schema_at /;

use Term::ReadKey;

use General;

# INFO
# We can specify the table we want load with the option 'constraint'
# but in this case relationships are not generated, so we don't use it.
# Principe: generate all schema in /tmp and then mv the wanted schema in kanopya arbo
#   this work fine for new schema,
#   for already existing schema we can't do this to avoid erasing manual modification


# Check Loader version
if (not ($DBIx::Class::Schema::Loader::VERSION =~ "0.07")) {
    print "Bad version of DBIx::Class::Schema::Loader\n";
    print "abort.\n";
    exit;
}

# Get param
my $table = $ARGV[0];
if (not defined $table) {
    print "Params:\n";
    print "all : regenerate/update all schema [dangerous]\n";
    print "<table name>: generate a new schema corresponding to <table name>\n";
    exit;
}

# Quick input for db user/pwd
print "db user : ";
my $db_user = <STDIN>;
chomp $db_user;
print "db pwd : ";
ReadMode "noecho";
my $db_pwd = <STDIN>;
ReadMode "restore";
print "\n";
chomp $db_pwd;

# Define globals
my $schema_class_name = 'Kanopya::Schema';

my $connect_info = [ 'dbi:mysql:kanopya:localhost:3306', $db_user, $db_pwd ];

my $dump_dir = '/opt/kanopya/lib/common';

if ($table eq 'all') {
    # Update all existing schema and create schema for new tables
    make_schema_at(
        $schema_class_name,
        { debug => 1,
          dump_directory => $dump_dir,
          overwrite_modifications => 1,
          result_base_class => "DBIx::Class::IntrospectableM2M",
          left_base_classes => [ "DBIx::Class::Core" ],
          schema_base_class => "Kanopya::Schema::Custom",
          moniker_map => {
             ipmi_credentials => "IpmiCredentials"
          },
        },
        $connect_info,
    );
}
else { 
    # Create schema for new table
    throw Kanopya::Exception::Internal::Deprecated(
              error => "Generate schema for single tbale is deprecated, use 'MakeSchema.pl all' instead."
          );

    my $tmp_dump_dir = '/tmp/kanopya_schema';
    print "Generate schema...\n";
    make_schema_at(
        $schema_class_name,
        { #debug => 1,
          dump_directory => $tmp_dump_dir,
          overwrite_modifications => 1,
          skip_load_external => 1,
          result_base_class => "DBIx::Class::IntrospectableM2M",
          left_base_classes => [ "DBIx::Class::Core" ],
          schema_base_class => "Kanopya::Schema::Custom"
        },
        $connect_info,
    );

    my $schema_name = join ( '', map { ucfirst $_ } (split '_', $table));
    my $subdir = $schema_class_name;
    $subdir =~ s/::/\//;
    my $target_dir = "$dump_dir/$subdir/Result";
    my $tmp_dir = "$tmp_dump_dir/$subdir/Result";

    if ( -e "$target_dir/$schema_name.pm" ) {
        print "WARNING: $schema_name.pm already exists in $target_dir\n";
        print "You may lose custom content. Please check manually.\n";
        print "\t[generated] $tmp_dir/$schema_name.pm\n\t[existing] $target_dir/$schema_name.pm\n[press enter to display diff]";
        my $in = <STDIN>;
        exec("diff -u $target_dir/$schema_name.pm $tmp_dir/$schema_name.pm");
    }
    print "Move schema $schema_name.pm in $target_dir...\n";
    `mv $tmp_dir/$schema_name.pm $target_dir/`;

    print "Done.\n"
}
