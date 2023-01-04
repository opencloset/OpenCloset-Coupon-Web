use utf8;

package OpenCloset::Coupon::Web::Controller::Seoul;
# ABSTRACT: OpenCloset::Coupon::Web::Controller::Seoul

use Mojo::Base "Mojolicious::Controller";

use Algorithm::CouponCode;
use Crypt::Mode::ECB;
use DateTime;
use Encode;
use HTTP::Tiny;
use Try::Tiny;

our $VERSION = '0.010';

sub _decrypt {
    my ( $self, $hex_ciphertext, $hex_key ) = @_;

    return q{} unless $hex_key;
    return q{} unless $hex_ciphertext;

    my $ciphertext = pack( 'H*', $hex_ciphertext );
    my $key        = pack( 'H*', $hex_key );
    my $m          = Crypt::Mode::ECB->new('AES');
    my $plaintext  = try {
        $m->decrypt( $ciphertext, $key );
    }
    catch {
        warn $_;
        return '';
    };

    return $plaintext;
}

sub _convert_inetpia_address {
    my ( $self, $m_address, $m_address2, $m_post ) = @_;

    ( my $q = $m_address ) =~ s/ \(.*$//;

    my $http   = HTTP::Tiny->new( timeout => 1 );
    my $url    = "https://postcodify.theopencloset.net/api/postcode/search";
    my $params = $http->www_form_urlencode( +{ q => $q } );
    my $res    = $http->get("$url?$params");
    return () unless $res->{success};

    my $data = Mojo::JSON::from_json( Encode::decode_utf8( $res->{content} ) );
    my $address = $data->{results}[0];
    return () unless $address;

    my $address1 = $address->{building_id};
    my $address2 = join( q{ }, $address->{ko_common}, $address->{ko_doro} );
    my $address3 = join( q{ }, $address->{ko_common}, $address->{ko_jibeon} );
    my $address4 = $address->{other_addresses};
    my $postcode = $address->{postcode5};

    return () unless $m_post eq $postcode;

    return ( $address1, $address2, $address3, $address4 );
}

sub _error_code {
    my ( $self, $code, $data ) = @_;

    my $return_url = "https://dressfree.net";

    my %common_seoul = (
        status  => 400,
        contact => "seoul",
        url     => $return_url,
    );
    my %common_opencloset = (
        status  => 500,
        contact => "opencloset",
        url     => "https://theopencloset.net",
    );
    my %common_both = (
        status  => 400,
        contact => "both",
        url     => $return_url,
    );

    my %error = (
        1001 => {
            %common_seoul,
            in  => "invalid encrypted rent_num: $data",
            out => "암호화된 취업날개 예약 번호 형식이 유효하지 않습니다.",
        },
        1002 => {
            %common_opencloset,
            in  => "invalid crypt key: $data",
            out => "암호화 키가 유효하지 않습니다.",
        },
        1003 => {
            %common_seoul,
            in  => "invalid rent_num: $data",
            out => "복호화된 취업날개 예약 번호 형식이 유효하지 않습니다.",
        },
        2001 => {
            %common_seoul,
            in  => "api request failed: $data",
            out => "취업날개로 보낸 예약 번호 확인 요청이 실패했습니다.",
        },
        2002 => {
            %common_seoul,
            in  => "invalid api response: $data",
            out => "취업날개에서 확인한 예약 번호 확인 응답이 유효하지 않습니다.",
        },
        3001 => {
            %common_seoul,
            in  => "unmatched rent_num: $data",
            out => "요청한 예약 번호와 획득한 예약 번호가 일치하지 않습니다.",
        },
        3002 => {
            %common_seoul,
            in  => "invalid rent_type",
            out => "유효하지 않은 예약 유형입니다.",
        },
        4001 => {
            %common_both,
            in  => "invalid phone: $data,",
            out => "취업날개와 열린옷장에서 입력한 전화번호가 일치하지 않습니다.",
        },
        4002 => {
            %common_both,
            in  => "invalid gender: $data,",
            out => "취업날개와 열린옷장에서 입력한 성별이 일치하지 않습니다.",
        },
        4003 => {
            %common_both,
            in  => "invalid birth: $data",
            out => "취업날개와 열린옷장에서 입력한 태어난 연도가 일치하지 않습니다.",
        },
        5001 => {
            %common_both,
            in  => "unmatched user name and phone: $data",
            out => "사용자 이름과 휴대폰 번호가 일치하지 않습니다.",
        },
        5002 => {
            %common_both,
            in  => "unmatched user information: $data",
            out => "취업날개와 열린옷장에서 입력한 사용자 정보가 일치하지 않습니다."
        },
        5003 => {
            %common_opencloset,
            in  => "failed to create a user and user info: $data",
            out => "사용자 생성에 실패했습니다.",
        },
        6001 => {
            %common_opencloset,
            in  => "invalid authcode: $data",
            out => "예약 번호 로그인에 실패했습니다.",
        },
        6002 => {
            %common_seoul,
            in  => "coupon via rent_num is already existed: $data",
            out => "취업날개 예약 번호를 두 번 이상 사용하셨습니다. 취업날개로 요청한 예약 번호는 이미 존재합니다.",
        },
        6003 => {
            %common_opencloset,
            in  => "failed to create coupon: $data",
            out => "쿠폰 생성에 실패했습니다.",
        },
    );

    return $error{$code};
}

sub _error {
    my ( $self, $code, $data ) = @_;

    my $error = $self->_error_code( $code, $data );

    return $self->error(
        $error->{status},
        {
            in         => "error($code): $error->{in}",
            out        => "오류($code): $error->{out}",
            contact    => $error->{contact},
            return_url => $error->{url},
        }
    );
}

sub _seoul_coupon_get {
    my ( $self, $coupon_id ) = @_;

    my $redirect = $self->param("redirect") || q{};
    my $encrypted_rent_num = $self->param("rent_num") || q{};

    my $visit_url  = $self->config->{url}{visit};
    my $share_url  = $self->config->{url}{share};
    my $seoul_url  = "https://dressfree.net/theopencloset/api_rentInfo.php";

    $self->stash( encrypted_rent_num => $encrypted_rent_num );

    #
    # validate rent_num
    #
    unless ( $encrypted_rent_num && $encrypted_rent_num =~ m/^[[:xdigit:]]{64}$/ ) {
        return $self->_error( 1001, $encrypted_rent_num );
    }
    $self->app->log->debug("encrypted rent_num: $encrypted_rent_num");
    my $hex_key = $self->config->{events}{seoul}{key};
    unless ($hex_key) {
        return $self->_error( 1002, $encrypted_rent_num );
    }
    my $rent_num = $self->_decrypt( $encrypted_rent_num, $hex_key );
    unless ( $rent_num && $rent_num =~ m/^\d{12}-\d{3}$/ ) {
        return $self->_error( 1003, $rent_num );
    }
    $self->app->log->debug("decrypted rent_num: $rent_num");

    my $res;
    {
        my $apicall_check = 0;
        my $max_retry     = 3;

        my $req_url = "$seoul_url?rent_num=$rent_num";
        $self->app->log->info("api request: $req_url");
        for my $retry ( 1 .. $max_retry ) {
            $res = HTTP::Tiny->new( timeout => 1 )->get($req_url);
            if ( $res->{success} ) {
                ++$apicall_check;
                last;
            }
            else {
                $self->app->log->warn(
                    "[$retry/$max_retry] api request failed: $res->{reason} $req_url"
                );
            }
        }
        unless ($apicall_check) {
            return $self->_error( 2001, "$res->{reason} $req_url" );
        }
    }

    my $data = Mojo::JSON::from_json( Encode::decode_utf8( $res->{content} ) );
    unless ( $data && $data->[0] ) {
        return $self->_error( 2002, "$encrypted_rent_num - $rent_num - " . Encode::decode_utf8( $res->{content} ) );
    }
    $data = $data->[0];

    # $data->{MberSn}
    # $data->{rent_num}
    # $data->{rent_type}
    # $data->{rent_date}
    # $data->{rent_time}
    # $data->{deli_fee}
    # $data->{user_name}
    # $data->{gender}
    # $data->{birth}
    # $data->{hp}
    # $data->{email}
    # $data->{m_post}
    # $data->{m_address}
    # $data->{m_address_2}
    my $rent_type =
          $data->{rent_type} eq "V" ? "offline"
        : $data->{rent_type} eq "D" ? "online"
        :                             q{};
    my $mbersn = $data->{MberSn};
    my $name   = $data->{user_name};
    my $email  = $data->{email};
    my $gender =
        $data->{gender} eq "M" ? "male" : $data->{gender} eq "F" ? "female" : q{};
    my $birth    = substr( $data->{birth}, 0, 4 );
    my $authcode = $data->{rent_num};
    my $now      = DateTime->now( time_zone => $self->config->{time_zone} );
    my $expires  = $now->add( minutes => 20 )->epoch;
    my $phone    = $data->{hp};
    $phone =~ s/\D//g;
    my $m_address  = $data->{m_address};
    my $m_address2 = $data->{m_address2};
    my $m_post     = $data->{m_post};

    unless ( $rent_num eq $authcode ) {
        return $self->_error( 3001, "$authcode != $rent_num" );
    }

    unless ( $rent_type eq "offline" || $rent_type eq "online" ) {
        return $self->_error(3002);
    }

    #
    # user find or create
    #
    my $user = $self->rs("User")->find(
        {
            name  => $name,
            email => $email,
        }
    );
    if ($user) {
        my $ui = $user->user_info;

        #
        # GH #1
        #   4001, 4002, 4003 오류 발생 시 취업날개 개인 정보 내용으로 갱신함
        #
        my $error;
        my $error_str = sprintf(
            "unmatched user information: name(%s) phone(%s) email(%s,%s) birth(%d,%d) gender(%s,%s)",
            $name,
            $phone,
            $ui->user->email, $email,
            $ui->birth,       $birth,
            $ui->gender,      $gender,
        );
        unless ( $ui->phone eq $phone ) {
            $error = $self->_error_code( 4001, $error_str );
            $self->app->log->warn( $error->{in} );
        }
        unless ( $ui->gender eq $gender ) {
            $error = $self->_error_code( 4002, $error_str );
            $self->app->log->warn( $error->{in} );
        }
        unless ( $ui->birth eq $birth ) {
            $error = $self->_error_code( 4003, $error_str );
            $self->app->log->warn( $error->{in} );
        }

        if ($error) {
            my $guard = $self->db->txn_scope_guard;
            $ui->update(
                {
                    phone  => $phone,
                    gender => $gender,
                    birth  => $birth,
                },
            );
            $guard->commit;
        }
    }
    else {
        my $ui = $self->rs("UserInfo")->find( { phone => $phone } );
        if ($ui) {
            if ( $ui->user->name ne $name ) {
                return $self->_error( 5001, $email . " $phone" );
            }

            if ( $ui->user->email || $ui->gender || $ui->birth ) {
                my $error_str = sprintf(
                    "unmatched user information: name(%s) phone(%s) email(%s,%s) birth(%d,%d) gender(%s,%s)",
                    $name,
                    $phone,
                    $ui->user->email, $email,
                    $ui->birth,       $birth,
                    $ui->gender,      $gender,
                );

                #
                # GH #1
                #   5002 오류 발생 시 취업날개 개인 정보 내용으로 갱신함
                #
                my $error = $self->_error_code( 5002, $error_str );
                $self->app->log->warn( $error->{in} );
            }

            my $guard = $self->db->txn_scope_guard;

            $ui->user->update( { email => $email } );
            $ui->update(
                {
                    phone  => $phone,
                    gender => $gender,
                    birth  => $birth,
                },
            );

            $guard->commit;

            $self->app->log->info(
                sprintf(
                    "update a user: id(%s), name(%s), email(%s), phone(%s), gender(%s), birth(%s)",
                    $ui->user->id,
                    $name,
                    $email,
                    $phone,
                    $gender,
                    $birth,
                )
            );
            $user = $ui->user;
        }
        else {
            my $guard = $self->db->txn_scope_guard;

            my $_user = $self->rs("User")->create(
                {
                    name  => $name,
                    email => $email,
                }
            );
            unless ($_user) {
                $self->app->log->warn("failed to create a user");
                last;
            }

            my $_user_info = $_user->create_related(
                "user_info",
                {
                    phone  => $phone,
                    gender => $gender,
                    birth  => $birth,
                },
            );
            unless ($_user_info) {
                $self->app->log->warn("failed to create a user_info");
                last;
            }

            $guard->commit;

            return $self->_error( 5003, "$name, $email" ) unless $_user;

            $self->app->log->info(
                sprintf(
                    "create a user: id(%s), name(%s), email(%s), phone(%s), gender(%s), birth(%s)",
                    $_user->id,
                    $name,
                    $email,
                    $phone,
                    $gender,
                    $birth,
                )
            );

            $user = $_user;
        }
    }

    #
    # update address
    #
    my ( $address1, $address2, $address3, $address4 ) = $self->_convert_inetpia_address( $m_address, $m_address2, $m_post );
    if ($address1) {
        $user->user_info->update(
            {
                address1 => $address1,
                address2 => $address2,
                address3 => $address3,
                address4 => "$m_address2 ($address4)",
            }
        );
    }
    else {
        $self->app->log->warn("failed to search address");
    }

    #
    # login with authcode
    #
    $user->update(
        {
            authcode => $authcode,
            expires  => $expires,
        },
    );
    unless ( $self->authenticate( $email, $authcode ) ) {
        return $self->_error( 6001, "$email, $authcode" );
    }
    $self->app->log->info("user: id(" . $user->id . "), name($name), email($email), phone($phone)");

    #
    # find coupon then revoke reservation
    #
    my $coupon_rs = $self->rs("Coupon")->search(
        {
            type   => "suit",
            desc   => { like => "$coupon_id|$rent_num|%" },
        }
    );
    if ( my @coupons = $coupon_rs->all ) {
        my $str = join q{, }, map { sprintf "%s(%s)", $_->code, $_->status || q{} } @coupons;

        return $self->_error( 6002, $str );
    }

    #
    # find or create coupon then save it into session
    #
    my $code = Algorithm::CouponCode::cc_generate( parts => 3 );
    my $event = $self->rs("Event")->search({ name => $coupon_id })->next;
    my $coupon = $self->rs("Coupon")->create(
        {
            event_id => $event ? $event->id : undef,
            code     => $code,
            type     => "suit",
            desc     => "$coupon_id|$rent_num|$mbersn",
            status   => "provided",
        }
    );
    unless ($coupon) {
        return $self->_error( 6003, "rent_num($rent_num), mbersn($mbersn)" );
    }
    $self->session( coupon_code => $coupon->code );
    $self->app->log->info("coupon: id(" . $user->id . "), name($name), email($email), phone($phone), coupon($code)");

    if ( $rent_type eq "offline" ) {
        my $url = $self->url_for($visit_url);
        $url->query(
            name  => $name,
            phone => $phone,
            sms   => $authcode,
            type  => "visit-info",
        );
        $self->app->log->info( "redirect_to: " . $url->to_string );
        $self->redirect_to($url);
    }
    elsif ( $rent_type eq "online" ) {
        $self->stash(
            title      => "취업날개 쿠폰 번호",
            code       => $code,
            return_url => $share_url,
        );
        $self->render( template => "seoul" );
    }
}

sub seoul_2022_1_get { $_[0]->_seoul_coupon_get("seoul-2022-1"); }
sub seoul_2023_1_get { $_[0]->_seoul_coupon_get("seoul-2023-1"); }

1;

__END__

=for Pod::Coverage

=head1 SYNOPSIS

    ...

=head1 DESCRIPTION

...

=method seoul_2022_1_get

=method seoul_2023_1_get
