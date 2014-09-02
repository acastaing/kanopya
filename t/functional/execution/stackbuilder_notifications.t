#!/usr/bin/perl -w

=head1 SCOPE

TODO

=head1 PRE-REQUISITE

TODO

=cut

use Test::More 'no_plan';
use Test::Exception;
use Test::Differences;

use Kanopya::Tools::Execution;

use EEntity;
use Entity::User::Customer::StackBuilderCustomer;
use Entity::Component::KanopyaStackBuilder;
use Entity::Component::KanopyaExecutor;
use Entity::Operation;
use Entity::Operationtype;
use NotificationSubscription;

use Data::Dumper;
use TryCatch;
use Log::Log4perl qw(:easy get_logger);
Log::Log4perl->easy_init({
    level  => 'INFO',
    file   => __FILE__.'.log',
    layout => '%d [ %H - %P ] %p -> %M - %m%n'
});


my $testing = 0;

# Get the stackbuilder
my $stackbuilder;
lives_ok {
    $stackbuilder = Entity::Component::KanopyaStackBuilder->find();
} 'Get the KanopyaStackBuilder component';


my $firstname = "First";
my $login = "flast";
my $admin_password = "password";
my $stackid = 123;
my $access_ip = $stackbuilder->getAccessIp();

# Expected mail body
# Copy/Paste from stack-builder-owner-notification-mail.tt
# Template variables replaced by their corresponding perl var
# WARNING : var are interpolated so you have to escape $, % and @ if it's part of the mail
my $expected_message = <<MAIL;
Hi $firstname,
Your stack has been deployed.
Before accessing your stack, please read the entire email.

How to connect to your Stack ?
    1) Sign in on www.pimpmystack.net
    2) Activate your access to the platform by clicking the "activate access" button on your profil page : www.pimpmystack.net/user
       ( note : for security matters your access will be deactivated every 12 hours)
    3) Download your vpn file from your profil page
    4) Open a VPN client with your vpn file
       (note: if you need help using your vpn file please refer to the How to section below)

Please find below the information you need to use your stack
Horizon URL:        http://$access_ip/
OpenStack login:    admin
OpenStack Password: $admin_password

Your host login: $login
Your hosts IP adresses are displayed in the Stack Builder : www.pimpmystack.net?q=content/builder/#/$stackid

Keep in mind that complete guides and test scenarios are available on the scenarios menu:
- How to : Open a VPN connection with OpenVPN
- How to : Connect to your hosts (using your SSH key)

If you have any technical troubles, you can contact us with the contact form at www.pimpmystack.net/content/contact

Thank you for using PimpMyStack!

The PimpMyStack Team
MAIL

main();

sub main {

    if ($testing == 1) {
        Kanopya::Database::beginTransaction;
    }

    # Create a customer to use as subscriber
    my $customer;
    lives_ok {
        $customer = Entity::User::Customer::StackBuilderCustomer->findOrCreate(
            user_login     => $login,
            user_password  => 'flastpass',
            user_firstname => $firstname,
            user_lastname  => 'Last',
            user_email     => 'kpouget@hederatech.com',
        );
    } 'Create a customer stack_builder_test for the subscriber';

    my $operation = EEntity::EOperation->new(operation => Entity::Operation->new(
                        priority      => 200,
                        operationtype => Entity::Operationtype->find(hash => { operationtype_name => "ConfigureStack" }),
                        params        => {
                            context => {
                                stack_builder  => $stackbuilder,
                                user           => $customer,
                                # We use any component here as the message builder method will call ->adminIp only
                                novacontroller => $stackbuilder
                            },
                            stack_id => $stackid,
                            admin_password => $admin_password
                        },
                        workflow_manager => Entity::Component::KanopyaExecutor->find
                    ));

    my $message =  EEntity->new(entity => $customer)->notificationMessage(operation  => $operation,
                                                                          state      => 'succeeded',
                                                                          subscriber => $customer);

    eq_or_diff $expected_message, $message, "Compare builded notification with the execpted one";

    if ($testing == 1) {
        Kanopya::Database::rollbackTransaction;
    }
}

1;
