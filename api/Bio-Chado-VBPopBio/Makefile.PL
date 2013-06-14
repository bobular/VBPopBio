use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Bio::Chado::VBPopBio',
    AUTHOR              => q{VectorBase <info@vectorbase.org>},
    VERSION_FROM        => 'lib/Bio/Chado/VBPopBio.pm',
    ABSTRACT            => 'A module to simplify dealing with the GMOD Chado Natural Diversity Schema',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
	'DBIx::Class' =>  0.08250,
	'DBIx::Class::DynamicSubclass' => 0,
	'Bio::Parser::ISATab' => 0.05, # not in CPAN - https://github.com/bobular/Bio-Parser-ISATab
	'Text::CSV_XS' => 0, # actually a dependency of ISATab Parser
	'Bio::Chado::Schema' => 0.2,
        'Iterator::Simple' => 0,
	'DateTime::Format::ISO8601' => 0,
	'Tie::Hash::Indexed' => 0,
        'Mouse' => 0,
	'Memoize' => 0,
	'Digest::MD5' => 0,
	'Try::Tiny' => 0,
	'JSON' => 0,
	'aliased' => 0,
	'DBD::Pg' => 0,
	'Config::General' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Bio-Chado-VBPopBio-*' },
);
