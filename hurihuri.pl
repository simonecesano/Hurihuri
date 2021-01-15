#!/usr/bin/env perl
use Mojolicious::Lite -signatures;
use Mojo::Util qw/dumper/;
use FindBin qw($Bin);
use lib "$Bin/lib";

use Hurihuri::Switch;

plugin Config => {file => 'hurihuri.conf'};
plugin Config => {file => 'switches.conf'};

my $clients = {};

helper 'sendall' => sub {
    my $c = shift;
    my $json = shift;
    for (keys %$clients) {
	$clients->{$_}->send({ json => $json });
    }
};

helper 'switch' => sub {
    my $c = shift;
    my $ip = shift;
    my $h = Hurihuri::Switch->new({ type => $c->app->config->{switches}->{$ip}->{type}, address => $ip });
    return $h;
};

get '/' => sub {
    my $c = shift;
    $c->app->log->info(Mojo::IOLoop->is_running);
    $c->render(template => 'index');
};


get '/state/*ip' => sub {
    my $c = shift;
    $c->render_later;
    $c->inactivity_timeout(5);

    my $h = $c->switch($c->stash('ip'));

    $h->state
	->then(sub {
		   my $res = shift;
		   my $h = $h;
		   $c->render(json => { ip => $c->stash('ip'), state => $res })
	       })
	->catch(sub {
		    my $err = shift;
		    $c->render(json => { ip => $c->stash('ip'), error => $err })
		});
};

post '/switch' => sub {
    my $c = shift;
    # $c->app->log->info(dumper $c->req->json);
    my $ip = $c->req->json->{switch};

    my $type = $c->app->config->{switches}->{$ip}->{type};

    $c->render_later;

    my $h = Hurihuri::Switch->new({ type => $type, address => $ip });

    $c->app->log->info($h);
    $h->toggle
	->then(sub {
		   my $res = shift;
		   $c->update_status($ip);
		   $c->render(json => $res )
	       })
	->catch(sub {
		   $c->render(json => { error => shift })
		});
};


websocket '/state' => sub {
    my $c = shift;
    $c->app->log->debug(sprintf 'Client connected: %s', $c->tx);

    my $id = $c->tx =~ s/.+?HASH\((.+?)\)/$1/r;

    $clients->{"$id"} = $c->tx;

    $c->tx->send({ json => { id => "$id" }});

    $c->on(message => sub {
	       my ($c, $msg) = @_;
	       $c->send({  json => { echo => $msg } });
	   });
};

helper 'update_status' => sub {
    my $c = shift;
    my $ip = shift;
    my $h = $c->switch($ip);
    $h->state
	->then(sub {
		   my $res = shift;
		   my $h = $h;
		   for (keys %$clients) {
		       $clients->{$_}->send({ json => { ip => $ip, state => $res }});
		   }
	       })
	->catch(sub {
		    my $err = shift;
		    for (keys %$clients) {
			$clients->{$_}->send({ json => { ip => $ip, state => $err }});
		    }
		});
};

my $id = Mojo::IOLoop->recurring(3 => sub ($loop) {
				     for (keys %{app->config->{switches}}) {
					 my $ip = $_;
					 app->update_status($ip);
				     }
				 });

app->start;


__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
% for (sort keys %{app->config->{switches}}) {
<div class="tile on" 
     data-switch-id="<%= $_ %>"><%= app->config->{switches}->{$_}->{name} || $_ %></div>
% }
<script type="fluor">
  on("click", ".tile",
     function(e){
	 var s = e.target
	 console.log(s.dataset.switchId)
	 s.classList.toggle('on');
	 axios.post("<%= url_for('/switch') %>", { switch: s.dataset.switchId, toggle: true })
	     .then(d => {
		 console.log(d.data);
	     })
     })
</script>
@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">

    <link href="https://fonts.googleapis.com/css?family=Montserrat:400,400i,800,900&display=swap" rel="stylesheet">

    <link rel="stylesheet" type="text/css" href="./style.css" media="screen">
    <script src="./axios.min.js"></script>
    <script type="module" src="./fluor.min.js"></script>
  </head>
  <body><%= content %></body>
  <script src="./socket.js"></script>
</html>
