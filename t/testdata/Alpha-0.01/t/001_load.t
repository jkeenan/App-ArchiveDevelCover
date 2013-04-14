# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More qw(no_plan); # tests => 2;

BEGIN { use_ok( 'Alpha', qw| greet pair | ); }

is( greet('en'), 'Hello', "English okay");
is( greet('fr'), 'Bonjour', "French okay");

__END__

is( greet('es'), 'Hola', "Spanish okay");
is( greet('ru'), 'No habla su lengua', "Russian not yet okay");
ok( pair( 'phi', 'beta' ), "Paired up nicely");
ok( ! defined pair( 'phi', 0 ), "Not paired up nicely");
ok( ! defined pair( undef, 17 ), "Not paired up nicely");


