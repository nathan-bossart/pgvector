use strict;
use warnings;
use PostgresNode;
use TestLib;
use Test::More;

my $node;
my @queries = ();
my $dim = 5;
my $array_sql = join(",", ('floor(random() * 4)::int - 2') x $dim);

# Initialize node
$node = get_new_node('node');
$node->init;
$node->start;

# Create table
$node->safe_psql("postgres", "CREATE EXTENSION vector;");
$node->safe_psql("postgres", "CREATE TABLE tst (v vector($dim));");
$node->safe_psql("postgres",
	"INSERT INTO tst SELECT ARRAY[$array_sql] FROM generate_series(1, 10000) i;"
);

# Generate queries
for (1 .. 20)
{
	my @r = ();
	for (1 .. $dim)
	{
		push(@r, int(rand() * 4) - 2);
	}
	push(@queries, "[" . join(",", @r) . "]");
}

# Check each distance function
my @functions = ("l2_distance", "inner_product", "cosine_distance", "l1_distance");

for my $function (@functions)
{
	for my $query (@queries)
	{
		my $expected = $node->safe_psql("postgres", "SELECT $function(v, '$query') FROM tst");
		my $actual = $node->safe_psql("postgres", "SELECT $function(v::sparsevec, '$query'::vector::sparsevec) FROM tst");
		is($expected, $actual, $function);
	}
}

done_testing();
