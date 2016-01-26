use Test::More;
use WWW::Bing::Translate;
use HTTP::Response;
use JSON;
use URI;
use feature 'state';

{
    no warnings 'once', 'redefine';

    my $call_counter = 0;

    my $mock_token_response = sub {
        my ($self, $url, $args) = @_;

        is(our $method, 'POST', 'token request - Called with POST');
        is($url, "http://auth.url.com", "token request - oauth url");
        is_deeply(
            $args,
            {
                grant_type     => 'client_credentials',
                client_id      => 'Myapp',
                client_secret  => 's3cr3t',
                scope          => "http://api.microsofttranslator.com",
            },
            "token request - payload"
        );

        return HTTP::Response->new(200, undef, [], '{"access_token":"666","expires_in":"100"}');
    };

    my $mock_translate_response = sub {
        my ($self, $url) = @_;

        is(our $method, 'GET', 'translate request - Called with GET');
        my %qs   = URI->new($url)->query_form;
        like($url, qr(^http://api.url.com/Translate\?), 'translate request - right url up to query string');
        is_deeply(\%qs, {
            text => 'Big Mac',
            from => 'en',
            to   => 'fr',
        }, "translate request - query form");
        is(
            $self->default_header('Authorization'),
            'Bearer 666',
            'translate request - token in Authorization header'
        );

        return HTTP::Response->new(
            200,
            undef,
            [],
            '<string xmlns="http://schemas.microsoft.com/2003/10/Serialization/">le Big Mac</string>'
        );
    };

    my $mock_speak_response = sub {
        my ($self, $url) = @_;

        is(our $method, 'GET', 'speak request - Called with GET');
        my %qs   = URI->new($url)->query_form;
        like($url, qr(^http://api.url.com/speak\?), 'speak request - right url up to query string');
        is_deeply(\%qs, {
            text     => 'le Big Mac',
            language => 'fr',
        }, "speak request - query form");
        is(
            $self->default_header('Authorization'),
            'Bearer 666',
            'speak request - token in Authorization header'
        );

        return HTTP::Response->new(
            200,
            undef,
            [],
            'some binary data'
        );
    };

    my $mock_detect_response = sub {
        my ($self, $url) = @_;

        is(our $method, 'GET', 'detect request - Called with GET');
        my %qs   = URI->new($url)->query_form;
        like($url, qr(^http://api.url.com/Detect\?), 'detect request - right url up to query string');
        is_deeply(\%qs, {
            text => 'le Big Mac',
        }, "detect request - query form");
        is(
            $self->default_header('Authorization'),
            'Bearer 666',
            'detect request - token in Authorization header'
        );

        return HTTP::Response->new(
            200,
            undef,
            [],
            '<string xmlns="http://schemas.microsoft.com/2003/10/Serialization/">fr</string>'
        );
    };

    my $mock_get_translations_response = sub {
        my ($self, $url, $args) = @_;

        is(our $method, 'POST', 'get_translations_request - Called with POST');
        my %qs   = URI->new($url)->query_form;
        like($url, qr(^http://api.url.com/GetTranslations), 'get_translations request - right url');
        is_deeply(\%qs, {
            text            => 'wall',
            from            => 'en',
            to              => 'nl',
            maxTranslations => 3,
        }, "get_translations request - query form");
        is(
            $self->default_header('Authorization'),
            'Bearer 666',
            'get_translations request - token in Authorization header'
        );

        return HTTP::Response->new(
            200,
            undef,
            [],
            '<GetTranslationsResponse xmlns="http://schemas.datacontract.org/2004/07/Microsoft.MT.Web.Service.V2" xmlns:i="http://www.w3.org/2001/XMLSchema-instance"><From>en</From><Translations><TranslationMatch><Count>0</Count><MatchDegree>100</MatchDegree><MatchedOriginalText/><Rating>5</Rating><TranslatedText>muur</TranslatedText></TranslationMatch><TranslationMatch><Count>4</Count><MatchDegree>100</MatchDegree><MatchedOriginalText>wall</MatchedOriginalText><Rating>1</Rating><TranslatedText>wand</TranslatedText></TranslationMatch></Translations></GetTranslationsResponse>',
        );
    };

    my $mock_lwp_request = sub {
        my $mk_cb_pattern = sub {
            my $cb = shift;
            return (
                $mock_token_response,
                $cb,
                $cb,
                $mock_token_response,
                $cb,
                $mock_token_response,
                $cb,
            );
        };
        state $tests = [
            $mk_cb_pattern->($mock_detect_response),
            $mk_cb_pattern->($mock_get_translations_response),
            $mk_cb_pattern->($mock_speak_response),
            $mk_cb_pattern->($mock_translate_response),
        ];
        $call_counter++;
        my $mock = shift @$tests;
        return $mock->(@_);
    };

    local *LWP::UserAgent::post = sub {our $method = 'POST'; goto $mock_lwp_request};
    local *LWP::UserAgent::get  = sub {our $method = 'GET'; goto $mock_lwp_request};

    my $tcs = {
        "translate" => {
            args     => ['en', 'fr', 'Big Mac'],
            expected => 'le Big Mac',
        },
        "get_translations" => {
            args     => ['en', 'nl', 'wall', {max_translations => 3}],
            expected => ['muur', 'wand'],
        },
        "detect" => {
            args     => ['le Big Mac'],
            expected => 'fr',
        },
        "speak" => {
            args     => ['fr', 'le Big Mac'],
            expected => 'some binary data',
        },
    };

    for my $method (sort keys %$tcs) {
        note "->$method";

        my $tc  = $tcs->{$method};
        my ($args, $expected) = @{$tc}{qw/args expected/};

        # reset counter
        $call_counter = 0;

        my $bing = WWW::Bing::Translate->new(
            api_key  => 's3cr3t',
            app_id   => 'Myapp',
            auth_url => 'http://auth.url.com',
            api_url  => 'http://api.url.com',
        );

        is_deeply(scalar $bing->$method(@$args), $expected, "right results");
        is($call_counter, 2, "There was 1 request to fetch the token + 1 request for the api call");

        is_deeply(scalar $bing->$method(@$args), $expected, "right results");
        is($call_counter, 3, "Token is reused, so only one extra call");

        $bing = WWW::Bing::Translate->new(
            api_key  => 's3cr3t',
            app_id   => 'Myapp',
            auth_url => 'http://auth.url.com',
            api_url  => 'http://api.url.com',
            clock    => sub {
                shift @{state $return_values = [
                    14533976641,
                    14533990000,
                    14533990000,
                ]};
            },
        );
        $bing->clock;

        is_deeply(scalar $bing->$method(@$args), $expected, "right result ($method)");
        is($call_counter, 5, "There was 1 request to fetch the token + 1 request for the api call");

        is_deeply(scalar $bing->$method(@$args), $expected, "right result ($method)");
        is($call_counter, 7, "Token expiry");
    }
}

done_testing;
