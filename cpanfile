requires 'perl', '5.10.0';
requires 'Plack', '1.0';
requires 'JSON', '2.0';
requires 'Plack::Middleware::Access', '0.3';

on 'test' => sub {
    requires 'HTTP::Response';
    requires 'HTTP::Request::Common';
};

suggests 'Plack::Middleware::HubSignature';
