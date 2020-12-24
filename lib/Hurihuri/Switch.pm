package Hurihuri::Switch;

use Mojo::Loader qw(data_section find_modules load_class);

use Mojo::Base -base;
use Class::Method::Modifiers;

# use Hurihuri::Switch::Tasmota;
# use Hurihuri::Switch::TPLink;

has 'type';
has 'address';

$|++;

sub BEGIN {
    for (find_modules __PACKAGE__) {
	load_class $_;
    }
}

around 'new' => sub {
    my $orig = shift;

    my $ret = $orig->(@_);

    shift;

    my $class = join '', (ref $ret), '::', $ret->type;
    $ret = $class->new(@_);
    $ret;
};



1;

