package Hurihuri::Switch::Tasmota;

use Mojo::UserAgent;
use Mojo::Base -base;

has ua => sub { Mojo::UserAgent->new };

has 'address';

sub toggle {
    my $self = shift;
    my $address = shift || $self->address;
    return $self->ua->get_p(sprintf 'http://%s/cm?cmnd=Power%%20TOGGLE', $address);
}

sub state {
    my $self = shift;
    my $address = shift || $self->address;
    my $ua = $self->ua;
    return $ua->get_p(sprintf 'http://%s/cm?cmnd=Power', $address)
	->then(sub {
		   my $tx = shift;
		   my $ua = $ua;
		   my $json = $tx->res->json;
		   return Mojo::Promise->resolve($json->{POWER} eq 'ON' ? 1 : 0)
	       })
}

1
