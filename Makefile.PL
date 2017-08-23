use strict;
use warnings;

use 5.014000;

use ExtUtils::MakeMaker 6.17;

use File::ShareDir::Install;
$File::ShareDir::Install::INCLUDE_DOTFILES = 1;
$File::ShareDir::Install::INCLUDE_DOTDIRS = 1;
install_share dist => "lib\/OpenCloset\/Coupon\/Web\/files";


my %WriteMakefileArgs = (
  "ABSTRACT" => "OpenCloset::Coupon::Web",
  "AUTHOR" => "\x{ae40}\x{b3c4}\x{d615} - Keedi Kim <keedi\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.17",
    "File::ShareDir::Install" => "0.06"
  },
  "DISTNAME" => "OpenCloset-Coupon-Web",
  "EXE_FILES" => [
    "bin/opencloset-coupon-web.pl"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.014000",
  "NAME" => "OpenCloset::Coupon::Web",
  "PREREQ_PM" => {
    "Algorithm::CouponCode" => 0,
    "Crypt::Mode::ECB" => 0,
    "DateTime" => 0,
    "Encode" => 0,
    "File::ShareDir" => 0,
    "HTTP::Tiny" => 0,
    "Mojo::Base" => 0,
    "Mojolicious" => "7.23",
    "Mojolicious::Commands" => 0,
    "Mojolicious::Plugin::AssetPack" => "1.44",
    "Mojolicious::Plugin::Authentication" => 0,
    "OpenCloset::Schema" => "0.053",
    "Path::Tiny" => 0,
    "Try::Tiny" => 0,
    "experimental" => 0,
    "strict" => 0,
    "utf8" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "Test::More" => "0.88"
  },
  "VERSION" => "0.003",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Algorithm::CouponCode" => 0,
  "Crypt::Mode::ECB" => 0,
  "DateTime" => 0,
  "Encode" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::ShareDir" => 0,
  "File::Spec" => 0,
  "HTTP::Tiny" => 0,
  "Mojo::Base" => 0,
  "Mojolicious" => "7.23",
  "Mojolicious::Commands" => 0,
  "Mojolicious::Plugin::AssetPack" => "1.44",
  "Mojolicious::Plugin::Authentication" => 0,
  "OpenCloset::Schema" => "0.053",
  "Path::Tiny" => 0,
  "Test::More" => "0.88",
  "Try::Tiny" => 0,
  "experimental" => 0,
  "strict" => 0,
  "utf8" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

{
package
MY;
use File::ShareDir::Install qw(postamble);
}
