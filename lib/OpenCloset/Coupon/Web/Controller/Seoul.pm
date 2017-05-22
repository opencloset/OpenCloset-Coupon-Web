package OpenCloset::Coupon::Web::Controller::Seoul;
# ABSTRACT: OpenCloset::Coupon::Web::Controller::Seoul

use Mojo::Base "Mojolicious::Controller";

use Algorithm::CouponCode;
use DateTime;
use Encode;
use HTTP::Tiny;

our $VERSION = '0.000';

sub _decrypt_inetpia {
    my ( $self, $encrypted ) = @_;

    my $decrypted2 = substr( $encrypted, 0,  10 );
    my $decrypted1 = substr( $encrypted, 10, 20 );
    $decrypted1 = $decrypted1 / 3;
    $decrypted2 = $decrypted2 / 7;
    $decrypted1 = $decrypted1 - 712938454;
    $decrypted2 = $decrypted2 - 240279371;

    my $decrypted = $decrypted1 . $decrypted2;
    $decrypted1 = substr( $decrypted, 1, 12 );
    $decrypted2 = substr( $decrypted, -3 );
    $decrypted  = $decrypted1 . "-" . $decrypted2;

    return $decrypted;
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

sub seoul_2017_2_get {
    my $self = shift;

    my $redirect = $self->param("redirect") || q{};
    my $encrypted_rent_num = $self->param("rent_num") || q{};

    my $visit_url  = $self->config->{url}{visit};
    my $share_url  = $self->config->{url}{share};
    my $return_url = "https://dressfree.net";
    my $seoul_url  = "https://dressfree.net/theopencloset/api_rentInfo.php";

    #
    # validate rent_num
    #
    unless ( $encrypted_rent_num && $encrypted_rent_num =~ m/^\d{20}$/ ) {
        my $in  = "invalid encrypted rent_num: $encrypted_rent_num";
        my $out = "암호화된 취업날개 예약 번호 형식이 유효하지 않습니다. 취업날개 서비스에 문의해주세요.";
		return $self->error( 400, { in => $in, out => $out, return_url => $return_url } );
    }
    $self->app->log->debug("encrypted rent_num: $encrypted_rent_num");
    my $rent_num = $self->_decrypt_inetpia($encrypted_rent_num);
    unless ($rent_num && $rent_num =~ m/^\d{12}-\d{3}$/ ) {
        my $in  = "invalid rent_num: $rent_num";
        my $out = "복호화된 취업날개 예약 번호 형식이 유효하지 않습니다. 취업날개 서비스에 문의해주세요.";
		return $self->error( 400, { in => $in, out => $out, return_url => $return_url } );
    }
    $self->app->log->debug("decrypted rent_num: $rent_num");

    my $res;
    {
        my $apicall_check = 0;
        my $max_retry     = 3;
        for my $retry ( 1 .. $max_retry ) {
            $res = HTTP::Tiny->new( timeout => 1 )->get("$seoul_url?rent_num=$rent_num");
            if ( $res->{success} ) {
                ++$apicall_check;
                last;
            }
            else {
                $self->app->log->warn(
                    "[$retry/$max_retry] api request failed: $res->{reason} $seoul_url?rent_num=$rent_num"
                );
            }
        }
        unless ($apicall_check) {
            my $in = "api request failed: $res->{reason} $seoul_url?rent_num=$rent_num";
            my $out =
                "취업날개로 보낸 예약 번호 확인 요청이 실패했습니다. 취업날개 서비스에 문의해주세요.";
            return $self->error( 400, { in => $in, out => $out, return_url => $return_url } );
        }
    }

    my $data = Mojo::JSON::from_json( Encode::decode_utf8( $res->{content} ) );
    $data = $data->[0] if $data && $data->[0];

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
        my $in = "unmatched rent_num: $authcode != $rent_num";
        my $out =
            "요청한 예약 번호와 획득한 예약 번호가 일치하지 않습니다. 취업날개 서비스에 문의해주세요.";
        return $self->error( 400, { in => $in, out => $out, return_url => $return_url } );
    }

    unless ( $rent_type eq "offline" || $rent_type eq "online" ) {
        my $in = "invalid rent_type";
        my $out =
            "유효하지 않은 예약 유형입니다. 취업날개 서비스에 문의해주세요.";
        return $self->error( 400, { in => $in, out => $out, return_url => $return_url } );
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
        unless ( $ui->phone eq $phone ) {
            my $in  = "invalid phone: $email, $phone";
            my $out = "열린옷장에서 입력한 전화번호와 취업날개에서 입력한 전화번호가 일치하지 않습니다. 취업날개 또는 열린옷장에 문의해주세요.";
            return $self->error( 400, { in => $in, out => $out, return_url => $return_url } );
        }
        unless ( $ui->gender eq $gender ) {
            my $in  = "invalid gender: $email, $gender";
            my $out = "열린옷장에서 입력한 성별과 취업날개에서 입력한 성별이 일치하지 않습니다. 취업날개 또는 열린옷장에 문의해주세요.";
            return $self->error( 400, { in => $in, out => $out, return_url => $return_url } );
        }
        unless ( $ui->birth eq $birth ) {
            my $in  = "invalid birth: $email, $birth";
            my $out = "열린옷장에서 입력한 태어난 연도와 취업날개에서 입력한 태어난 연도가 일치하지 않습니다. 취업날개 또는 열린옷장에 문의해주세요.";
            return $self->error( 400, { in => $in, out => $out, return_url => $return_url } );
        }
    }
    else {
        my $ui = $self->rs("UserInfo")->find( { phone => $phone } );
        unless ( $ui && $user->name eq $name && !$user->email && !$user->gender && !$user->birth ) {
            my $in  = "duplicated phone number: $phone";
            my $out = "이미 존재하는 휴대폰 번호입니다. 취업날개 또는 열린옷장에 문의해주세요.";
            return $self->error( 400, { in => $in, out => $out, return_url => $return_url } );
        }
        if ($ui) {
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

            $self->app->log->info("update a user: id(" . $user->id . "), name($name), email($email), phone($phone), gender($gender), birth($birth)");

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

            unless ($_user) {
                my $in  = "failed to create a user and user info: $email";
                my $out = "사용자 생성에 실패했습니다. 열린옷장에 문의해주세요.";
                return $self->error( 400, { in => $in, out => $out, return_url => "https://theopencloset.net" } );
            }

            $self->app->log->info("create a user: id(" . $user->id . "), name($name), email($email), phone($phone), gender($gender), birth($birth)");

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
        my $in  = "invalid authcode: $email, $authcode";
        my $out = "예약 번호 로그인에 실패했습니다. 열린옷장에 문의해주세요.";
        return $self->error( 400, { in => $in, out => $out, return_url => "https://theopencloset.net" } );
    }

	#
    # find coupon then revoke reservation
    #
    my $coupon_rs = $self->rs("Coupon")->search(
        {
            type   => "suit",
            desc   => { like => "seoul-2017-2|$rent_num|%" },
        }
    );
    if ( my @coupons = $coupon_rs->all ) {
        my $str = join q{, }, map { sprintf "%s(%s)", $_->code, $_->status || q{} } @coupons;
        my $in  = "coupon via rent_num is already existed: $str";
        my $out = "취업날개 예약 번호를 두 번 이상 사용하셨습니다. 취업날개로 요청하신 예약 번호는 이미 존재합니다. 취업날개 서비스에 문의해주세요.";
        return $self->error( 400, { in => $in, out => $out, return_url => $return_url } );
    }

	#
    # find or create coupon then save it into session
    #
	my $code = Algorithm::CouponCode::cc_generate( parts => 3 );
    my $coupon = $self->rs("Coupon")->create(
        {
            code   => $code,
            type   => "suit",
            desc   => "seoul-2017-2|$rent_num|$mbersn",
            status => "provided",
        }
    );
    unless ($coupon) {
        my $in  = "failed to create coupon: rent_num($rent_num), mbersn($mbersn)";
        my $out = "쿠폰 생성에 실패했습니다. 열린옷장에 문의해주세요.";
        return $self->error( 500, { in => $in, out => $out, return_url => "https://theopencloset.net" } );
    }
    $self->session( coupon_code => $coupon->code );
    $self->app->log->info("coupon: id(" . $user->id . "), name($name), email($email), phone($phone), coupon($code)");

    if ( $rent_type eq "offline" ) {
        my $url = $self->url_for($visit_url);
        $self->redirect_to(
            $url->query(
                name  => $name,
                phone => $phone,
                sms   => $authcode,
                type  => "visit-info",
            )
        );
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
