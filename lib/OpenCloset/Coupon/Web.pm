use v5.14.0;
use utf8;

package OpenCloset::Coupon::Web;

# ABSTRACT: OpenCloset::Coupon::Web

use Mojo::Base "Mojolicious";

our $VERSION = '0.009';

use File::ShareDir "dist_dir";
use Path::Tiny;

use OpenCloset::Schema;

#
# specify plugins explicitly
#
use Mojolicious::Plugin::Authentication;

=attr db

=cut

has db => sub {
    my $self = shift;

    my $schema_class = "OpenCloset::Schema";
    my $schema       = $schema_class->connect(
        $self->config->{db}{dsn},      $self->config->{db}{username},
        $self->config->{db}{password}, $self->config->{db}{options},
        )
        or die "Could not connect to $schema_class using DSN "
        . $self->config->{db}{dsn};

    return $schema;
};

=attr home_path

=cut

has home_path => sub {
    my $path = $ENV{OPENCLOSET_COUPON_WEB_HOME} || q{.};
    return path($path)->absolute->stringify;
};

=attr config_file

=cut

has config_file => sub {
    my $self = shift;
    return $ENV{OPENCLOSET_COUPON_WEB_CONFIG} if $ENV{OPENCLOSET_COUPON_WEB_CONFIG};
    return path( $self->home_path . "/opencloset-coupon-web.conf" )->absolute->stringify;
};

=attr db_name

=attr db_username

=attr db_password

=cut

has db_name     => sub { $ENV{"OPENCLOSET_COUPON_WEB_DB_NAME"} || "opencloset" };
has db_username => sub { $ENV{"OPENCLOSET_COUPON_WEB_DB_USER"} || "opencloset" };
has db_password => sub { $ENV{"OPENCLOSET_COUPON_WEB_DB_PASS"} || "opencloset" };

=method default_config

=cut

sub default_config {
    my $app = shift;

    my $db_name     = $app->db_name;
    my $db_username = $app->db_username;
    my $db_password = $app->db_password;

    return +{
        hypnotoad => {
            listen   => ["http://*:8016"],
            workers  => 4,
            pid_file => "hypnotoad.pid",
        },
        db => {
            dsn      => "dbi:mysql:$db_name:127.0.0.1",
            username => $db_username,
            password => $db_password,
            options  => {
                mysql_enable_utf8 => 1,
                quote_char        => q{`},
                on_connect_do     => "SET NAMES utf8",
                RaiseError        => 1,
                AutoCommit        => 1,
            },
        },
        cookie => {
            domain => undef,
            name   => "opencloset-coupon-web",
            path   => "/",
        },
        site      => { name => "OpenCloset::Coupon::Web", },
        time_zone => "Asia/Seoul",
        copyright => "2015-2021 THE OPEN CLOSET",
        secrets   => [],
        extra_static_paths   => [ "assets", "static" ],
        extra_renderer_paths => ["templates"],
        links                => [
            {
                name => "홈페이지",
                url  => "https://theopencloset.net",
            },
            {
                name => "방문 예약",
                url  => "https://visit.theopencloset.net",
            },
            {
                name => "온라인 예약",
                url  => "https://share.theopencloset.net",
            },
            {
                name => "정장 기증",
                url  => "https://donation.theopencloset.net",
            },
            {
                name => "열린봉사자 모집",
                url  => "https://volunteer.theopencloset.net",
            },
        ],
        page => {
            "error" => {
                title       => "오류",
                title_short => "오류",
                url         => q{},
                breadcrumb  => [],
            },
            "code-400" => {
                title       => "요청이 잘못되었습니다",
                title_short => "400 Bad Request",
                url         => q{},
                breadcrumb  => [
                    qw/
                        index
                        error
                        code-400
                        /
                ],
            },
            "code-404" => {
                title       => "페이지를 찾을 수 없습니다",
                title_short => "404 Not Found",
                url         => q{},
                breadcrumb  => [
                    qw/
                        index
                        error
                        code-404
                        /
                ],
            },
            "code-500" => {
                title       => "내부 서버 오류입니다",
                title_short => "500 Internal Server Error",
                url         => q{},
                breadcrumb  => [
                    qw/
                        index
                        error
                        code-500
                        /
                ],
            },
            "index" => {
                title       => "첫 화면",
                title_short => "첫 화면",
                url         => "/",
                breadcrumb  => [],
            },
            "login" => {
                title       => "로그인",
                title_short => "로그인",
                url         => "/login",
                breadcrumb  => [],
            },
            "signup" => {
                title       => "회원 가입",
                title_short => "회원 가입",
                url         => "/signup",
                breadcrumb  => [],
            },
            "forgot" => {
                title       => "비밀번호 변경",
                title_short => "비밀번호 변경",
                url         => "/login/forgot",
                breadcrumb  => [],
            },
            "coupon" => {
                title       => "쿠폰",
                title_short => "쿠폰",
                url         => q{},
                breadcrumb  => [],
            },
        },
        url => {
            visit => "http://localhost:8001/visit",
            share => "http://localhost:8010",
        },
        events => {
            seoul => {
                key => q{},
            },
        },
    };
}

=method startup

=cut

sub startup {
    my $app = shift;

    $app->_home_path;
    $app->_log_path;
    $app->_plugins;
    $app->_helpers;
    $app->_share_dir;
    $app->_sessions;
    $app->_static_paths;
    $app->_renderer_paths;
    $app->_namespaces;
    $app->_public_routes;
    #$app->_private_routes;
}

sub _home_path {
    my $app = shift;

    # set home folder
    $app->home( $app->home->new( $app->home_path ) );
}

sub _log_path {
    my $app = shift;

    # setup logging path
    # code stolen from Mojolicious.pm
    my $mode = $app->mode;

    $app->log->path( $app->home->rel_file("log/$mode.log") )
        if -w $app->home->rel_file("log");
}

sub _plugins {
    my $app = shift;

    #
    # Mojolicious::Plugin::Config
    #
    $app->plugin(
        Config => {
            file    => $app->config_file,
            default => $app->default_config,
        },
    );
    my @export_keys = (
        qw/
            site
            page
            links
            copyright
            time_zone
            /
    );
    $app->defaults( { map { $_ => $app->config->{$_} } @export_keys } );

    #
    # Mojolicious::Plugin::AssetPack
    #
    $app->plugin(
        "AssetPack" => { pipes => [qw(Sass Css CoffeeScript JavaScript Combine)] } );
    {
        # use content from directories under lib/OpenCloset/Coupon/Web/files or using File::ShareDir
        my $lib_base = path( ( path(__FILE__)->absolute =~ s/\.pm$//r ) . "/files" );

        my $public = path("$lib_base/public");
        my $final =
              $public->is_dir
            ? $public->stringify
            : path( dist_dir("OpenCloset-Coupon-Web") . "/public" )->stringify;
        push @{ $app->asset->store->paths }, $final;
    }
    {
        use experimental qw( smartmatch );
        my @skip_asset_process = qw(
            help
            setup
        );
        $app->asset->process unless $ARGV[0] && $ARGV[0] ~~ @skip_asset_process;
    }

    #
    # Mojolicious::Plugin::Authentication
    #
    $app->plugin(
        "authentication" => {
            autoload_user => 1,
            load_user     => sub {
                my ( $self, $uid ) = @_;

                my $user_obj = $self->rs("User")->find($uid);
                return $user_obj;
            },
            session_key   => "access_token",
            validate_user => sub {
                my ( $self, $user, $pass, $extradata ) = @_;

                my $user_obj = $self->rs("User")->find( { email => $user } );
                unless ($user_obj) {
                    $self->app->log->warn("cannot find such user: $user");
                    return;
                }

                #
                # GitHub #199
                #
                # check expires when login
                #
                my $now = DateTime->now( time_zone => $self->config->{time_zone} )->epoch;
                unless ( $user_obj->expires && $user_obj->expires > $now ) {
                    $self->app->log->warn("$user\'s password is expired");
                    return;
                }

                my $password_check = 0;
                my $authcode_check = 0;
                ++$password_check if $user_obj->password && $user_obj->check_password($pass);
                ++$authcode_check if $user_obj->authcode && $user_obj->authcode eq $pass;

                unless ( $password_check || $authcode_check ) {
                    $self->app->log->warn(
                        "$user\'s auth failed: password($password_check), authcode($authcode_check)");
                    return;
                }

                return $user_obj->id;
            },
        }
    );

    #
    # Mojolicious::Plugin::*
    #
    #$app->plugin( "OpenCloset::Coupon::Web::Plugin::FooBar", { ... } );
}

sub _helpers {
    my $app = shift;

    #
    # Helpers
    #
    $app->helper(
        db => sub {
            my $self = shift;

            return $self->app->db;
        }
    );
    $app->helper(
        rs => sub {
            my ( $self, $result_set_name ) = @_;

            return unless $result_set_name;

            my $db = $self->app->db;
            return unless $db;

            return $db->resultset($result_set_name);
        }
    );
    $app->helper(
        error => sub {
            my ( $self, $status, $error, $template ) = @_;

            my $now = DateTime->now( time_zone => $app->config->{time_zone} );

            $self->app->log->error( $error->{in} );
            $self->app->log->debug($template) if $template;

            unless ($template) {
                no warnings "experimental";
                given ($status) {
                    $template = "bad_request" when 400;
                    $template = "not_found" when 404;
                    $template = "exception" when 500;
                    default { $template = "unknown" }
                }
            }

            $self->respond_to(
                json => {
                    status => $status,
                    json   => { error => $error->{out} || q{} }
                },
                html => {
                    status     => $status,
                    template   => $template,
                    dt         => $now,
                    error      => $error->{out} || q{},
                    return_url => $error->{return_url} || q{},
                    contact    => $error->{contact} || q{},
                },
            );

            return;
        }
    );
}

sub _share_dir {
    my $app = shift;

    # use content from directories under lib/OpenCloset/Coupon/Web/files or using File::ShareDir
    my $lib_base = path( ( path(__FILE__)->absolute =~ s/\.pm$//r ) . "/files" );

    my $public = path("$lib_base/public");
    $app->static->paths->[-1] =
          $public->is_dir
        ? $public->stringify
        : path( dist_dir("OpenCloset-Coupon-Web") . "/public" )->stringify;

    my $templates = path("$lib_base/templates");
    $app->renderer->paths->[-1] =
          $templates->is_dir
        ? $templates->stringify
        : path( dist_dir("OpenCloset-Coupon-Web") . "/templates" )->stringify;
}

sub _sessions {
    my $app = shift;

    $app->sessions->cookie_domain( $app->config->{cookie}{domain} );
    $app->sessions->cookie_name( $app->config->{cookie}{name} );
    $app->sessions->cookie_path( $app->config->{cookie}{path} );
    $app->secrets( $app->config->{secrets} ) if @{ $app->config->{secrets} };
}

sub _to_abs {
    my ( $self, $dir ) = @_;

    $dir = $self->home->rel_file($dir)->to_abs->to_string unless $dir =~ m{^/};

    return $dir;
}

sub _static_paths {
    my $app = shift;

    # add the files directories to array of static content folders
    for my $dir ( reverse @{ $app->config->{extra_static_paths} } ) {
        # convert relative paths to relative one (to home dir)
        $dir = $app->_to_abs($dir);
        unshift @{ $app->static->paths }, $dir if -d $dir;
    }
}

sub _renderer_paths {
    my $app = shift;

    for my $dir ( reverse @{ $app->config->{extra_renderer_paths} } ) {
        # convert relative paths to relative one (to home dir)
        $dir = $app->_to_abs($dir);
        unshift @{ $app->renderer->paths }, $dir if -d $dir;
    }
}

sub _namespaces {
    my $app = shift;

    # use commands from OpenCloset::Coupon::Web::Command namespace
    push @{ $app->commands->namespaces }, "OpenCloset::Coupon::Web::Command";
}

sub _public_routes {
    my $app = shift;

    my $r = $app->routes;
    #$r->get("/login")->to("login#login_get");
    #$r->post("/login")->to("login#login_post");
    #$r->get("/signup")->to("login#signup_get");
    #$r->post("/signup")->to("login#signup_post");
    #$r->get("/login/forgot")->to("login#forgot_get");
    #$r->post("/login/forgot")->to("login#forgot_post");

    #
    # NOW
    #
    # - 이제 해당 년도에는 정확한 해당 연도 쿠폰 URL으로 요청하도록 전달함
    # - 구 주소는 모두 제거하고 지원하지 않음
    #
    # PREVIOUS
    #
    # - 아이넷피아에서 넘어오는 URL 이 2020 년도임에도 2019 로 넘어옴
    # - 이를 2019 쿠폰 요청이 넘어올 일은 없다고 가정하고, 임시로 2019 로 와도 2020 으로 처리
    # - 2020 으로 바꿔달라고 요청할 것이고 변경된 이후에는 2019 로 들어오는 요청은 유효하지 않도록 처리할 예정
    #
    # SEE ALSO
    #
    # - https://github.com/opencloset/opencloset/issues/1646
    # - https://lh3.googleusercontent.com/-cWSkd3LpTrM/XiHQY1CM4OI/AAAAAAAAJuk/8Xo5ilaSu0AXPU28uAdNAIfvhNQcl-dGACK8BGAsYHg/s0/2020-01-17.jpg
    #
    $r->get("/seoul/2021/1")->to("seoul#seoul_2021_1_get");
}

sub _private_routes {
    my $app = shift;

    my $r     = $app->routes;
    my $login = $r->under("/")->to("login#login");
    $login->get("/logout")->to("login#logout_get");
    $login->get("/")->to("root#index_get");
}

1;
__END__

=head1 SYNOPSIS

    $ mkdir -p service/opencloset-coupon-web
    $ cd service/opencloset-coupon-web
    $ opencloset-coupon-web.pl setup
    $ opencloset-coupon-web.pl daemon


=head1 INSTALLATION

L<OpenCloset::Coupon::Web> uses well-tested and widely-used CPAN modules, so installation should be as simple as

    $ cpanm --mirror=https://cpan.theopencloset.net --mirror=http://cpan.silex.kr --mirror-only OpenCloset::Coupon::Web

when using L<App::cpanminus>. Of course you can use your favorite CPAN client or install manually by cloning the L</"Source Code">.


=head1 SETUP

=head2 Environment

Although most of L<OpenCloset::Coupon::Web> is controlled by a configuration file, a few properties must be set before that file can be read.
These properties are controlled by the following environment variables.

=for :list
* C<OPENCLOSET_COUPON_WEB_HOME>
This is the directory where L<OpenCloset::Coupon::Web> expects additional files.
These include the configuration file and log files.
The default value is the current working directory (C<cwd>).
* C<OPENCLOSET_COUPON_WEB_CONFIG>
This is the full path to a configuration file.
The default is a file named F<opencloset-coupon-web.conf> in the C<OPENCLOSET_COUPON_WEB_HOME> path,
however this file need not actually exist, defaults may be used instead.


=head1 RUNNING THE APPLICATION

    $ opencloset-coupon-web.pl daemon

After the database has been setup, you can run C<opencloset-coupon-web.pl daemon> to start the server.

You may also use L<morbo> (Mojolicious' development server) or L<hypnotoad> (Mojolicious' production server).
You may even use any other server that Mojolicious supports, however for full functionality it must support websockets.
When doing so you will need to know the full path to the C<opencloset-coupon-web.pl> application.
A useful recipe might be

    $ hypnotoad `which opencloset-coupon-web.pl`

where you may replace C<hypnotoad> with your server of choice.


=head2 Logging

Logging in L<OpenCloset::Coupon::Web> is the same as in L<Mojolicious|Mojolicious::Lite/Logging>.
Messages will be printed to C<STDERR> unless a directory named F<log> exists in the C<OPENCLOSET_COUPON_WEB_HOME> path,
in which case messages will be logged to a file in that directory.


=head2 Extra Static Paths

By default, if L<OpenCloset::Coupon::Web> detects a folder named F<static> inside the C<OPENCLOSET_COUPON_WEB_HOME> path,
that path is added to the list of folders for serving static files.
The name of this folder may be changed in the configuration file via the key C<extra_static_paths>,
which expects an array reference of strings representing paths.
If any path is relative it will be relative to C<OPENCLOSET_COUPON_WEB_HOME>.


=head2 Extra Renderer Paths

By default, if L<OpenCloset::Coupon::Web> detects a folder named F<templates> inside the C<OPENCLOSET_COUPON_WEB_HOME> path,
that path is added to the list of folders for serving templates.
The name of this folder may be changed in the configuration file via the key C<extra_renderer_paths>,
which expects an array reference of strings representing paths.
If any path is relative it will be relative to C<OPENCLOSET_COUPON_WEB_HOME>.
