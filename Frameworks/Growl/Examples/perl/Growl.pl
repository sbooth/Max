#!/usr/bin/perl -w

require Mac::Growl;

use strict;

my $application_name = "Perl Test";
my $notification_name = "Test notification";
my @notifications = ($notification_name);
Mac::Growl::RegisterNotifications($application_name, \@notifications, \@notifications);
Mac::Growl::PostNotification($application_name, $notification_name, "Title", "Testing, one, two, three", 0, 0);

