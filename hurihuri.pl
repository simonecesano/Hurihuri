#!/usr/bin/env perl
use Mojolicious::Lite;
use Mojo::Util qw/dumper/;
use FindBin qw($Bin);
use lib "$Bin/lib";

use Hurihuri::Switch;

plugin Config => {file => 'hurihuri.conf'};
plugin Config => {file => 'switches.conf'};


get '/' => sub {
    my $c = shift;
    $c->app->log->info(Mojo::IOLoop->is_running);

    $c->render(template => 'index');
};

# curl http://192.168.1.217/cm?cmnd=Power%20TOGGLE
# curl http://192.168.1.217/cm?cmnd=Status

post '/switch' => sub {
    my $c = shift;
    # $c->app->log->info(dumper $c->req->json);
    my $ip = $c->req->json->{switch};
    
    my $type = $c->app->config->{switches}->{$ip}->{type};

    # my $status = $c->toggle($ip, $type);
    # $c->app->log->info($type, $ip);

    $c->render_later;

    my $h = Hurihuri::Switch->new({ type => $type, address => $ip });

    $c->app->log->info($h);
    $h->toggle
	->then(sub {
		   my $res = shift;
		   $c->app->log->info($res);
		   $c->render(json => $res )
	       })
	->catch(sub {
		   $c->render(json => { error => shift })
		});
    
};


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
</html>
