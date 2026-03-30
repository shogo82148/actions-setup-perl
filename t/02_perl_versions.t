use Test::More;
use Actions::Core qw(perl_versions);

# use in array context
my @versions = perl_versions();
is $versions[-1], '5.6.2', 'the oldest version of perl';

# use in scalar context
my $versions = perl_versions();
is $versions->[-1], '5.6.2', 'the oldest version of perl';

$versions = perl_versions(patch => 1);
is $versions->[-1], '5.6.0', 'the oldest version of perl';

# distribution: 'stawberry'
$versions = perl_versions( platform => 'win32', distribution => 'strawberry' );
is $versions->[-1], '5.14.4', 'the oldest version of strawberry perl 5.14.x';

done_testing;
