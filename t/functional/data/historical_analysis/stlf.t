=head1 SCOPE

STL Forecast

=head1 PRE-REQUISITE

=cut

use strict;
use warnings;
 
use Test::More 'no_plan';
use Kanopya::Tools::TestUtils 'expectedException';
use Test::Exception;

use Entity::DataModel::RDataModel::StlForecast;

main();

sub main {
    checkExceptions();
    checkPredict();
}

sub checkPredict {
    lives_ok {
        # The data used for the test
        my @data = (5, 12, 13, 15, 13, 12, 5, 12, 13, 15, 13, 12, 5, 12, 13, 15, 13, 12);

        # Expected values (manually computed from R)
        my @expected_values = (5, 12, 13, 15, 13);
        my $forecast = Entity::DataModel::RDataModel::StlForecast->predict(
            data => \@data,
            freq     => 6,
            predict_end => 23,
        );
        my @forecasted_values = @{$forecast};
        for my $index (0..scalar(@expected_values) - 1) {
            unless ($expected_values[$index] == $forecasted_values[$index]) {
                die ("StlForecast : Incorrect value returned in the forecast " .
                     " ($expected_values[$index] expected, got $forecasted_values[$index])");
            }
        }
    } 'Testing outputs of the StlForecast predict method'
}

sub checkExceptions {

    throws_ok {
        my %data = (
            1 => 5,
            2 => 12,
            3 => 13,
            4 => 15,
            5 => 13,
            6 => 12,
        );
        Entity::DataModel::RDataModel::StlForecast->predict(
            data => \%data,
            freq     => 6,
            end_time => 8,
        );
    } 'Kanopya::Exception',
      'StlForecast predict method called with a dataset which contains less than two period';

    throws_ok {
        my %data = (
            1  => 5,
            2  => 12,
            3  => 13,
            4  => 15,
            5  => 13,
            6  => 12,
            7  => 5,
            8  => 12,
            9  => 13,
            10 => 15,
            11 => 13,
            12 => 12,
            13 => 5,
            14 => 12,
            15 => 13,
            16 => 15,
            17 => 13,
            18 => 12,
        );
        Entity::DataModel::RDataModel::StlForecast->predict(
            data => \%data,
            freq     => 6,
            end_time => 8,
        );
    } 'Kanopya::Exception',
      'StlForecast predict method called for forecasting a value before the last value of the ' .
      'dataset';

    throws_ok {
        my %data = (
            1  => 5,
            2  => 12,
            3  => 13,
            4  => 15,
            5  => 13,
            6  => 12,
            7  => 5,
            8  => 12,
            9  => 13,
            10 => 15,
            11 => 13,
            12 => 12,
            13 => 5,
            14 => 12,
            15 => 13,
            16 => 15,
            17 => 13,
            18 => 12,
        );
        Entity::DataModel::RDataModel::StlForecast->predict(
            data => \%data,
            freq     => 1,
            end_time => 25,
        );
    } 'Kanopya::Exception',
      'StlForecast predict method called for forecasting a non seasonal time serie ';
}