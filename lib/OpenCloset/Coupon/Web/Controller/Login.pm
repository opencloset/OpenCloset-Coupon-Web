package OpenCloset::Coupon::Web::Controller::Login;
# ABSTRACT: OpenCloset::Coupon::Web::Controller::Login

use Mojo::Base "Mojolicious::Controller";

our $VERSION = '0.005';

sub login {
    my $self = shift;

    $self->stash(
        user      => undef,
        user_info => undef,
    );

    my $req = $self->req;
    if ( !$self->is_user_authenticated && $req->url->path ne "/login" ) {
        $self->app->log->info(
            sprintf(
                "unauthorized request: %s %s %s %s",
                $req->method,
                $req->url->path,
                $self->tx->remote_address,
                $req->headers->user_agent,
            ),
        );
        $self->app->log->info("redirect to: /login");
        $self->redirect_to( $self->url_for("/login") );
        return;
    }

    $self->stash(
        user      => $self->current_user,
        user_info => $self->current_user->user_info,
    );

    return 1;
}

sub login_get {
    my $self = shift;

    my $redirect = $self->param("redirect") || q{};

    if ($redirect) {
        if ( $self->is_user_authenticated ) {
            $self->redirect_to( $self->url_for($redirect) );
            return;
        }
        else {
            $self->stash( redirect => $redirect );
            $self->render( template => "login/index" );
            return;
        }
    }
    else {
        if ( $self->is_user_authenticated ) {
            $self->redirect_to( $self->url_for("/") );
            return;
        }
        else {
            $self->render( template => "login/index" );
            return;
        }
    }
}

sub login_post {
    my $self = shift;

    my $username = $self->param("email")    || q{};
    my $password = $self->param("password") || q{};
    my $redirect = $self->param("redirect") || q{};

    $self->app->log->debug("login: username($username), redirect($redirect)");
    if ( $self->authenticate( $username, $password ) ) {
        $self->app->log->info("login success: [$username]");
        my $user = $self->current_user;

        $redirect ||= "/";
        $self->app->log->info("redirect to: $redirect");
        $self->redirect_to( $self->url_for($redirect) );
    }
    else {
        $self->app->log->info("login failure: [$username]");
        $self->stash( redirect => $redirect );
        $self->render( template => "login/index" );
    }
}

sub logout_get {
    my $self = shift;

    my $redirect = $self->param("redirect") || q{};

    $self->session( expires => 1 );

    if ($redirect) {
        $self->redirect_to( $self->url_for($redirect) );
        return;
    }
    else {
        $self->redirect_to( $self->url_for("/login") );
        return;
    }
}

sub signup_get {
    my $self = shift;

    $self->render("login/signup");
}

sub signup_post {
    my $self = shift;

    $self->render("login/signup");
}

sub forgot_get {
    my $self = shift;

    $self->render("login/forgot");
}

sub forgot_post {
    my $self = shift;

    $self->render("login/forgot");
}

1;

__END__

=for Pod::Coverage

=head1 SYNOPSIS

    ...

=head1 DESCRIPTION

...

=method login

=method login_get

=method login_post

=method logout_get

=method signup_get

=method signup_post

=method forgot_get

=method forgot_post
