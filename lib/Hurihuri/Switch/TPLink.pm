package Hurihuri::Switch::TPLink;

use Mojo::Base -base;

use Mojo::IOLoop::Client;
use JSON::XS;

has 'address';

my $commands = {
		info      =>  { system => { get_sysinfo=> {} } } ,
		on        =>  { system => { set_relay_state => { state => 1} } } ,
		off       =>  { system => { set_relay_state => { state => 0} } } ,
		cloudinfo =>  { cnCloud => { get_info => {} } } ,
		wlanscan  =>  { netif => { get_scaninfo => { refresh => 0} } } ,
		time      =>  { time => { get_time => {} } } ,
		schedule  =>  { schedule => { get_rules => {} } } ,
		countdown =>  { count_down => { get_rules => {} } } ,
		antitheft =>  { anti_theft => { get_rules => {} } } ,
		reboot    =>  { system => { reboot => { delay => 1 } } } ,
		reset     =>  { system=> { reset=>{ delay => 1 } } }, 
		scan_ssid =>  { netif => {"get_scaninfo" => {"refresh" => 1}}}
	       };

sub command {
    my $self = shift;
    my $command = pop;
    my ($address) = shift || $self->address;

    my $promise =  Mojo::Promise->new;

    return $promise->reject('need an address') unless $address;
    return $promise->reject('need a command')  unless $command;

    $command = encrypt(encode_json($commands->{$command}));

    my $port = 9999;

    my $id = Mojo::IOLoop->client({ address => $address, port => 9999 } => sub {
				      my ($loop, $err, $stream) = @_;

				      return $promise->reject('could not open stream') unless $stream;

				      $stream->on(read => sub {
						      my ($stream, $bytes) = @_;
						      $stream->close;
						      my $res = decode_json(decrypt($bytes));

						      $promise->reject('response error') if is_error($res);

						      $promise->resolve($res);
						  });

				      $stream->on(error => sub {
						      my $err = shift;
						      $promise->reject($err);
						  });

				      $stream->write($command);
				  });

    
    return $promise;
}

sub is_error {
    my $res = shift;
    return [ values %{$res->{system}} ]->[0]->{err_code} > 0;
    
}

sub encrypt {
    my $s = shift;
    my ($i, $a);
    
    my ($r, $k) = ("\0\0\0\0", 171);

    $r = pack 'N', length($s);

    for (split '', $s) {
	# print;
	$a = $k ^ ord($_);
	$k = $a;
	$r .= chr($a);
    }
    return $r;
}

sub decrypt {
    my $s = shift;

    $s = substr($s, 4);
    
    my ($i, $a);
    my ($r, $k) = ("", 171);
    for (split '', $s) {
	$a = $k ^ ord($_);
	$k = ord($_);
	$r .= chr($a);
    }
    return $r;
}


sub on {
    my ($self, $address) = @_;
    $self->command($address, 'on')
}

sub off {
    my ($self, $address) = @_;
    $self->command($address, 'off')
}

sub toggle {
    my ($self, $address) = @_;

    $self->state($address)
	->then(sub {
		   my $s = shift;
		   $s ? $self->off($address) : $self->on($address)
	       })
    }

sub state {
    my ($self, $address) = @_;
    
    $self->command($address, 'info')
	->then(sub {
		   my $res = shift;
		   return Mojo::Promise->resolve([ values %{$res->{system}} ]->[0]->{relay_state})
	       })
    }

1
