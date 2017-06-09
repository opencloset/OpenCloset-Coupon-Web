#!perl
# ABSTRACT: utility to launch OpenCloset::Coupon::Web
# PODNAME: opencloset-coupon-web.pl

use strict;
use warnings;

use Path::Tiny;

# Source directory has precedence
my $base = path(__FILE__)->parent(2);
my $lib  = "$base/lib";
path( "$base/t" )->exists ? unshift( @INC, $lib ) : push( @INC, $lib );

# Start commands for application
require Mojolicious::Commands;
Mojolicious::Commands->start_app("OpenCloset::Coupon::Web");
