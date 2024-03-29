requires "Algorithm::CouponCode" => "0";
requires "Crypt::Mode::ECB" => "0";
requires "DateTime" => "0";
requires "Encode" => "0";
requires "File::ShareDir" => "0";
requires "HTTP::Tiny" => "0";
requires "Mojo::Base" => "0";
requires "Mojolicious" => "7.23";
requires "Mojolicious::Commands" => "0";
requires "Mojolicious::Plugin::AssetPack" => "1.44";
requires "Mojolicious::Plugin::Authentication" => "0";
requires "OpenCloset::Schema" => "0.059";
requires "Path::Tiny" => "0";
requires "Try::Tiny" => "0";
requires "experimental" => "0";
requires "perl" => "v5.14.0";
requires "strict" => "0";
requires "utf8" => "0";
requires "warnings" => "0";

on 'test' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "File::Spec" => "0";
  requires "Test::More" => "0.88";
  requires "perl" => "v5.14.0";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "2.120900";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "6.17";
  requires "File::ShareDir::Install" => "0.06";
  requires "perl" => "v5.14.0";
};

on 'develop' => sub {
  requires "Dist::Zilla" => "5";
  requires "Dist::Zilla::Plugin::Encoding" => "0";
  requires "Dist::Zilla::Plugin::Prereqs" => "0";
  requires "Dist::Zilla::Plugin::ShareDir" => "0";
  requires "Dist::Zilla::PluginBundle::DAGOLDEN" => "0";
  requires "File::Spec" => "0";
  requires "File::Temp" => "0";
  requires "IO::Handle" => "0";
  requires "IPC::Open3" => "0";
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Pod::Wordlist" => "0";
  requires "Software::License::Perl_5" => "0";
  requires "Test::CPAN::Meta" => "0";
  requires "Test::MinimumVersion" => "0";
  requires "Test::More" => "0";
  requires "Test::Perl::Critic" => "0";
  requires "Test::Pod" => "1.41";
  requires "Test::Pod::Coverage" => "1.08";
  requires "Test::Portability::Files" => "0";
  requires "Test::Spelling" => "0.12";
  requires "Test::Version" => "1";
};
