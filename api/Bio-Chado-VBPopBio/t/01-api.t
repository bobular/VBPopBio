use Test::More tests => 3;

# the next 3 lines were tested by 00-load.t
use Bio::Chado::VBPopBio;
my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });

ok(defined $schema, "schema object OK");

my $stocks = $schema->stocks();

isa_ok($stocks, 'Bio::Chado::VBPopBio::ResultSet::Stock', "stocks is correct class");
can_ok($schema->storage, '_use_join_optimizer');

