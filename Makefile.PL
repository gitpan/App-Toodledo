use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'App::Toodledo',
    AUTHOR              => 'Peter J. Scott <cpan@psdt.com>',
    VERSION_FROM        => 'lib/App/Toodledo.pm',
    ABSTRACT_FROM       => 'lib/App/Toodledo.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Test::NoWarnings' => 0,
        'Test::Exception' => 0,
        'Test::MockModule' => 0,
        'Test::MockObject::Extends' => 0,
        'REST::Client' => 0,
        'Moose' => 0,
        'MooseX::Method' => 0,
        'XML::LibXML' => 0,
        'Digest::MD5' => 0,
        'Date::Parse' => 0,
        'File::HomeDir' => 0,
        'YAML' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'App-Toodledo-*' },
);
