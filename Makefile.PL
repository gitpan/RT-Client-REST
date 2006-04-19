use ExtUtils::MakeMaker;

WriteMakefile(
    NAME            => 'RT::Client::REST',
    VERSION_FROM    => 'REST.pm',
    PREREQ_PM       => {
                        'Error'                 => 0,
                        'Exception::Class'      => 0,
                        'HTTP::Cookies'         => 0,
                        'HTTP::Request::Common' => 0,
                        'LWP'                   => 0,
                        'RT::Interface::REST'   => 0
    },
);
