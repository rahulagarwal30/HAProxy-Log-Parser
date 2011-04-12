#!/usr/bin/perl

use XML::RSS;
use Cwd;

my $dir = getcwd;
open(CONFIG, "< $dir/config");
while (<CONFIG>) {
	chomp;                  # no newline
	s/#.*//;                # no comments
	s/^\s+//;               # no leading white
	s/\s+$//;               # no trailing white
	next unless length;     # anything left?
	my ($var, $value) = split(/\s*=\s*/, $_, 2);
	$ENV{$var} = $value;
} 
close(CONFIG);

while(<>) {
 my $logline = $_;
 my @tokens = split( /\s+/, $_);
 my $store = $tokens[0];
 my @vals = split(/,/, $tokens[1]);

 my $type = $vals[0];
 my $bytes = $vals[3];
 my $frontend_id = $vals[9];
 my $backend_id = $vals[10];
 my $server_id = $vals[11];
 my $tt = $vals[2];
 my $response_code = $vals[1];
 my $term = $vals[12];

 # remove any hyphens, they are significant to collectd
 $frontend_id =~ s/\-/_/g;
 $backend_id =~ s/\-/_/g;
 $server_id =~ s/\-/_/g;

 $response_codes{$response_code}++;
 $frontend{$frontend_id}++;
 $frontend_bytes{$frontend_id} += $bytes;
 $backend{$backend_id}++;
 $backend_bytes{$backend_id} += $bytes;
 $server{$server_id}++;
 $server_bytes{$server_id} += $bytes;
 $requests{$type}++;

 if ( "$term" eq "server_error" ) {
    $session_err{$server_id}++;
    $session_err{$frontend_id}++;
    $session_err{$backend_id}++;
 }

 # Record hits against storenames
 $hit{$store}++;

 #print "Store:$store\tfrontend:$frontend_id Backend:$backend_id Server:$server_id Time:$tt Bytes:$bytes Code:$response_code Term:$term\n";
}

# Generate Top 10 RSS data
#

if (defined($ENV{top10rss})) {
 my $rss = new XML::RSS (version => '1.0');
 $rss->channel(
        title   =>      "Top 10",
        link    =>      "http://storestats.uks.talis/cgi/report.pl",
        description     => "Platform store requests last min",
 );

  my $links = 0;
  foreach ( sort { $hit{$b} <=> $hit{$a} } keys %hit ) {
    if ( $links < 10 ) {
      $rss->add_item(
        title           => "$_",
        link            => "http://responsetimes.uks.talis/index.php?storename=$_&len=180",
        description     => "$_ ($hit{$_})",
      );
      $links++;
    }
  }
  open(RSS," > $ENV{top10rss}");
  print RSS $rss->as_string;
  close(RSS);
}

# Collectd PUTVAL output 
#
foreach ( keys %frontend ) {
        if ( length($session_err{$_}) != 0 ) {
                $err_count = $session_err{$_};
        } else {
                $err_count = 0;
        }
        print "PUTVAL ha-00.uks.talis/haproxy/haproxy_frontend-$_ interval=60 N:$frontend{$_}:$frontend_bytes{$_}:$err_count\n";
}
foreach ( keys %backend ) {
        if ( length($session_err{$_}) != 0 ) {
                $err_count = $session_err{$_};
        } else {
                $err_count = 0;
        }
        print "PUTVAL ha-00.uks.talis/haproxy/haproxy_backend-$_ interval=60 N:$backend{$_}:$backend_bytes{$_}:$err_count\n";
}
foreach my $server ( keys %server ) {
        if ( length($session_err{$server}) != 0 ) {
                $err_count = $session_err{$server};
        } else {
                $err_count = 0;
        }
        print "PUTVAL ha-00.uks.talis/haproxy/haproxy_server-$server interval=60 N:$server{$server}:$server_bytes{$server}:$err_count\n";
}
foreach ( keys %response_codes ) {
        print "PUTVAL ha-00.uks.talis/haproxy/haproxy_response_codes-$_ interval=60 N:$response_codes{$_}\n";
}
for $type ( keys %requests ) {
	print "PUTVAL ha-00.uks.talis/haproxy/api_requests-$type interval=60 N:$requests{$type} \n";
}
