package OpenCloset::Coupon::Web::Command::setup;
# ABSTRACT: OpenCloset::Coupon::Web::Command::setup

use Mojo::Base "Mojolicious::Command";

our $VERSION = '0.008';

use Path::Tiny;

has description => "Setup default configuration and theme for OpenCloset::Coupon::Web\n";

sub run {
    my ( $self, @args ) = @_;

    my $app = $self->app;

    {
        my $conf    = "tidyall.ini";
        my $content = <<"END_CONTENT";
[PerlTidy]
select = opencloset-coupon-web.conf
select = opencloset-coupon-web.conf.sample
END_CONTENT
        path($conf)->spew_utf8($content) unless -e $conf;
    }

    {
        my $conf = $app->config_file . ".sample";
        $app->log->debug("generate sample configuration file: $conf");
        my $content = $app->dumper( $app->default_config );
        $content =~ s/\\x\{([^}]+)\}/chr(hex("0x$1"))/eg;
        $content =~ s/(\n\s*[\)}\]])/,$1/gms;
        my $vim_conf = "# vim: ts=8 sts=4 sw=4 ft=perl et:";
        path($conf)->spew_utf8( $content, $vim_conf );
        system "tidyall", "-a";
    }

    {
        my $conf = ".bowerrc";
        my $dir  = path( $app->config->{extra_static_paths}[0] )->relative(".");
        $app->log->debug("generate $conf");
        my $content = <<"END_CONTENT";
{
    "directory": "$dir/vendor"
}
END_CONTENT
        path($conf)->spew_utf8($content);
    }

    {
        my $conf = "bower.json";
        $app->log->debug("generate $conf");
        my $theme_name = $app->config->{theme}{name};
        my $theme_repo = $app->config->{theme}{repo};
        my $content    = <<"END_CONTENT";
{
  "name": "opencloset-coupon-web",
  "dependencies": {
    "Materialize": "materialize#~0.98.0",
    "fontawesome": "~4.7.0",
    "jquery": "~3.1.1",
    "parsleyjs": "~2.6.2"
  }
}
END_CONTENT
        path($conf)->spew_utf8($content);
    }

    {
        system "bower", "install";
    }

    {
        my @srcs = qw(
            assets/vendor/Materialize/dist/fonts
            assets/vendor/fontawesome/fonts
        );

        my $dir  = path( $app->config->{extra_static_paths}[0] )->relative(".");
        my $dest = "$dir/asset/fonts";
        path($dest)->mkpath;

        for my $src (@srcs) {
            next unless -e $src;

            my @fonts = path($src)->children;
            for my $font (@fonts) {
                my $link = "$dest/" . $font->basename;
                symlink "../../../$font", $link unless -e $link;
            }
        }
    }

    {
        my $dir = path( $app->config->{extra_static_paths}[0] )->relative(".");
        $dir->mkpath;

        my $conf = "$dir/assetpack.def";
        $app->log->debug("generate $conf");
        my $content = <<"END_CONTENT";
!  app.css
<  https://fonts.googleapis.com/earlyaccess/nanumbrushscript.css
<  https://fonts.googleapis.com/earlyaccess/nanumgothic.css
<  https://fonts.googleapis.com/earlyaccess/nanummyeongjo.css
<  https://fonts.googleapis.com/earlyaccess/nanumpenscript.css
<  https://fonts.googleapis.com/earlyaccess/notosanskr.css
<  https://fonts.googleapis.com/css?family=Roboto+Slab:400,700
<  https://fonts.googleapis.com/css?family=Roboto:400,700
<  https://fonts.googleapis.com/css?family=Open+Sans:800i
<  https://fonts.googleapis.com/icon?family=Material+Icons
<  /vendor/Materialize/sass/materialize.scss
<  /vendor/fontawesome/scss/font-awesome.scss
<  sass/style.scss

!  app.js
#
# jQuery
#
<  /vendor/jquery/dist/jquery.js
#
# materialize
#
<  /vendor/Materialize/js/initial.js
<  /vendor/Materialize/js/jquery.easing.1.3.js
<  /vendor/Materialize/js/animation.js
<  /vendor/Materialize/js/velocity.min.js
<  /vendor/Materialize/js/hammer.min.js
<  /vendor/Materialize/js/jquery.hammer.js
<  /vendor/Materialize/js/global.js
<  /vendor/Materialize/js/collapsible.js
<  /vendor/Materialize/js/dropdown.js
<  /vendor/Materialize/js/modal.js
<  /vendor/Materialize/js/materialbox.js
<  /vendor/Materialize/js/parallax.js
<  /vendor/Materialize/js/tabs.js
<  /vendor/Materialize/js/tooltip.js
<  /vendor/Materialize/js/waves.js
<  /vendor/Materialize/js/toasts.js
<  /vendor/Materialize/js/sideNav.js
<  /vendor/Materialize/js/scrollspy.js
<  /vendor/Materialize/js/forms.js
<  /vendor/Materialize/js/slider.js
<  /vendor/Materialize/js/cards.js
<  /vendor/Materialize/js/chips.js
<  /vendor/Materialize/js/pushpin.js
<  /vendor/Materialize/js/buttons.js
<  /vendor/Materialize/js/transitions.js
<  /vendor/Materialize/js/scrollFire.js
<  /vendor/Materialize/js/date_picker/picker.js
<  /vendor/Materialize/js/date_picker/picker.date.js
<  /vendor/Materialize/js/character_counter.js
<  /vendor/Materialize/js/carousel.js
#
# etc
#
<  /vendor/parsleyjs/dist/parsley.min.js
<  /vendor/parsleyjs/dist/i18n/ko.js

!  auth.js
<  /coffee/main.coffee

!  error.css
<  /sass/error.scss

!  coupon.css
<  /sass/coupon.scss

!  login-common.js
<  /coffee/login-common.coffee

!  login-common.css
<  /sass/login-common.scss
END_CONTENT
        path($conf)->spew_utf8($content);
    }
}

1;

__END__

=for Pod::Coverage

=head1 SYNOPSIS

    ...

=head1 DESCRIPTION

...

=attr description

=method run
