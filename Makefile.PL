use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'WWW::Bing::Translate',
    AUTHOR        => 'Larion Garaczi <l4rion@gmail.com>',
    VERSION_FROM  => 'lib/WWW/Bing/Translate.pm',
    ABSTRACT_FROM => 'lib/WWW/Bing/Translate.pm',
    PREREQ_PM => {
        'Test::More'                => 0,
        'LWP::UserAgent'            => 0,
        'JSON'                      => 0,
        'Moose'                     => 0,
        'MooseX::HasDefaults::RO'   => 0,
        'MooseX::StrictConstructor' => 0,
        'URI'                       => 0,
        'XML::Simple'               => 0,
        'namespace::autoclean'      => 0,
        'Carp'                      => 0,
        'Test::Fatal'               => 0,
        'Params::Validate'          => 0,
    },
);
