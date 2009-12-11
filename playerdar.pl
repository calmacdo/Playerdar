#!/usr/bin/perl -w
# $Rev: 1 $
# $Author: calmacdo $
# $Date: 2009-12-08 23:09:47 -0700 (Sat, 23 May 2009) $
 
use strict;
use WWW::Mechanize;
use JSON -support_by_pp;
use XML::Simple;
use Data::Dumper;
use LWP::Simple;
use Net::LastFM;
use 5.010;

our @listened = ('Empty');

my $APIk = "798a758e559cd1e31620e210916717b1";
my $APIs = "7d51c832818ae8db3d7f42f2fbb68cc6";

print "Enter Artist: ";
my $artist = <>;
#print "\n";
print "Enter Track: ";
my $track = <>;
#print "\n";

my $Nart = $artist;
my $Ntrk = $track;

$artist =~ s/ /+/g;
$artist =~ s/\n//g;
$track =~ s/ /+/g;
$track =~ s/\n//g;

$Nart =~ s/\n//g;
$Ntrk =~ s/\n//g;

print "Artist: $artist - Track: $track \n";

my $qid = &fetch_id("http://localhost:60210/api/?method=resolve&artist=$artist&album=&track=$track" , "qid");
sleep 2;
my $sid = &fetch_id("http://localhost:60210/api/?method=get_results&qid=$qid" , "sid");

print "Resolve qid: $qid \n";
print "Player sid: $sid \n";

if ($sid ne "Fail"){
  updatelist($Ntrk);
  play($sid);
}
 
while ($sid ne "Fail"){

  ($artist , $track , $sid) = &fetch_sim($APIk, $APIs , $Nart , $Ntrk);

  print "Similar Track: $artist - $track:$sid \n";

  if ($sid ne "Fail"){
    updatelist($track);
    play($sid);
  }
}

sub fetch_id {
  my $returnid = '';
  my ($json_url, $request) = @_;
  my $browser = WWW::Mechanize->new();
  eval{
    # download the json page:
    print "Getting json $json_url\n";
    $browser->get( $json_url );
    my $content = $browser->content();
    my $json = new JSON;
 
    # these are some nice json options to relax restrictions a bit:
    my $json_text = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($content);
    
    if ($request eq "qid") {
       $returnid = $json_text->{qid};
    } elsif (@{$json_text->{results}} != 0){
          my $score = 0;
	  my $id = "Fail";
	  my $testURL = '';
	  my $check = '';
	  my $listen = '';

	  foreach my $result(@{$json_text->{results}}){
	    $testURL = "http://localhost:60210/sid/$result->{sid}";
	    $check = CheckUrl($testURL);
	    $listen = CheckPlayed($result->{track});
	    
	    #print "$check - $result->{score}  - $score \n";

	    if (($check eq "Ok") && ($result->{score} > $score ) && ($listen eq "Ok")) {
	      $score = $result->{score};
	      $id = $result->{sid};
	    }
          }
	  print "\n";
	  $returnid = $id;
       } else {
          $returnid = "Fail";
       }
    
  };
  # catch crashes:
  if($@){
    print "[[Playdar ERROR]] JSON parser crashed! $@\n";
  }

  return $returnid;

}

sub play {

  my ($id) = @_;
  my $cmd = "/usr/local/bin/mplayer http://localhost:60210/sid/$id";

  system $cmd;
}

sub fetch_sim {
  
  my ($apiK, $apiS, $art, $trk) = @_;
  my $id = "Fail";
  my $testArt = '';
  my $testTrk = '';
  my $simqid = '';
  my $simsid = '';
  #my $match = 0;

  my $lastfm = Net::LastFM->new(
    api_key    => $apiK,
    api_secret => $apiS,
  );
  my $data = $lastfm->request_signed(
      method => 'track.getSimilar',
      track   => $trk,
      artist => $art,
  );
  
  foreach my $simtrack (@{$data->{similartracks}->{track}}){
  
    if ($id eq "Fail"){

      $testArt = $simtrack->{artist}->{name};
      $testTrk = $simtrack->{name};

      $testArt =~ s/ /+/g;
      $testArt =~ s/\n//g;
      $testTrk =~ s/ /+/g;
      $testTrk =~ s/\n//g;
    
      $simqid = &fetch_id("http://localhost:60210/api/?method=resolve&artist=$testArt&album=&track=$testTrk" , "qid");
      sleep 2;
      $simsid = &fetch_id("http://localhost:60210/api/?method=get_results&qid=$simqid" , "sid");
    

      if ($simsid ne "Fail") {
  
	#$match = $simtrack->{match};
	$art = $simtrack->{artist}->{name};
	$trk = $simtrack->{name};
	$id = $simsid;

      }
    }
  }
  return ($art, $trk, $id);
}

sub CheckUrl {
  my ($url) = @_;
  my $response = '';
  my $check = head($url);

  print ".";
  
  #print Dumper($check);
  
  if (defined $check) {
    $response = "Ok";
  } else {
    $response = "Fail";
  }
  
  return $response;

}

sub CheckPlayed {

  my ($Cid) = @_;
  my $response = '';
  
  if ( $Cid ~~ @listened ) {
    
    $response = "Fail";

  } else {

    $response = "Ok";

  }

return $response;

}

sub updatelist {

  my ($trklist) = @_;

  if ( @listened == 10 ){

    shift(@listened);
    push(@listened,$trklist);

  } else {

    push(@listened,$trklist);

  }
  print "@listened \n";

}


