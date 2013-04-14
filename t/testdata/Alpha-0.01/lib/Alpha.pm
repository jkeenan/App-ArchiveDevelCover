package Alpha;
use strict;

BEGIN {
    use Exporter ();
    our ( $VERSION, @ISA, @EXPORT_OK);
    $VERSION     = '0.01';
    @ISA         = qw(Exporter);
    @EXPORT_OK   = qw( greet pair );
}

sub greet {
    my $lang = shift;
    if ($lang eq 'en') {
        return "Hello";
    } elsif ($lang eq 'fr') {
        return "Bonjour";
    } elsif ($lang eq 'es') {
        return "Hola";
    } else {
        return "No habla su lengua";
    }
}

sub pair {
    my ($alpha, $beta) = @_;
    $alpha and $beta and do {
        return 1;
    };
    return;
}

1;

