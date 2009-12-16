#!/usr/bin/perl -w
# $Rev: 1 $
# $Author: calmacdo
# $Date: 2009-12-08 23:09:47 -0700 (Sat, 23 May 2009)

#    Copyright 2009 Calum Macdonald

#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at

#	http://www.apache.org/licenses/LICENSE-2.0

#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

 
use strict;
use WWW::Mechanize;
use JSON -support_by_pp;
use Audio::Play::MPlayer;
use Data::Dumper;
use LWP::Simple;
use Net::LastFM;
use Proc::Simple;

our @listened = ('Empty');
our @playlist = ();
our @si = ();
our @so = ();

our $APIk = "798a758e559cd1e31620e210916717b1";
our $APIs = "7d51c832818ae8db3d7f42f2fbb68cc6";

print "Enter Artist: ";
my $artist = <>;
print "Enter Track: ";
my $track = <>;

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
  player($sid, $Nart, $Ntrk);
}

sub fetch_id {
  my $returnid = '';
  my ($json_url, $request) = @_;
  my $browser = WWW::Mechanize->new();
  eval{
    # download the json page:
    #print "Getting json $json_url\n";
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
	  my $intrack = '';
	  my $outtrack = '';

	  foreach my $result(@{$json_text->{results}}){
	    $testURL = "http://localhost:60210/sid/$result->{sid}";
	    
	    $intrack = $json_text->{query}->{track};
	    $outtrack = $result->{track};

	    $intrack =~ tr/[A-Z]/[a-z]/;
	    $outtrack =~ tr/[A-Z]/[a-z]/;

	    if (($result->{score} > $score ) && ($intrack eq $outtrack)) {
	      if ((CheckUrl($testURL) eq "Ok") && (CheckPlayed($result->{track}) eq "Ok")){
		$score = $result->{score};
		$id = $result->{sid};
	      }
	    }
          }
	  #print "\n";
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

sub player {

  my ($id, $singer, $song) = @_;
  my $myproc = Proc::Simple->new();
  my $cmd = "/usr/bin/mplayer http://localhost:60210/sid/$id";
  my $tmpSing = "";
  my $tmpSong = "";
  my $tmp = "";
  
  push(@playlist, $id);
  push(@si,$singer);
  push(@so,$song);

  my $next = shift @playlist;
  shift @playlist;
  shift @si;
  shift @so;

  $myproc->start($cmd);

  my $pid = $myproc->pid;

  #print "\nProcess: $pid\n";
  
  my $exists = kill 0, $pid;

  $cmd = '/usr/bin/kdialog --title "Playerdar Info" --passivepopup "Now Playing: '. $singer . ' - ' . $song . '"';
  system $cmd;

  while ($next ne "Fail") {

    while ($exists) {

      if (@playlist == 10) {
	$exists = kill 0, $pid;
      } else {

	$tmpSing = $singer;
	$tmpSong = $song;

	($singer , $song , $id) = &fetch_sim($tmpSing , $tmpSong);
	updatelist($song);
	push(@playlist,$id);
	push(@si,$singer);
	push(@so,$song);

	$exists = kill 0, $pid;

      }
    }
    
    $next = "";

    foreach $tmp (@playlist){

      if ($next eq "") {
	$next = $tmp;
      }

    }

    $tmpSing = "";

    foreach $tmp (@si){

      if ($tmpSing eq "") {
	$tmpSing = $tmp;
      }

    }

    $tmpSong = "";

    foreach $tmp (@so){

      if ($tmpSong eq "") {
	$tmpSong = $tmp;
      }

    }

    $myproc->kill();
    shift @playlist;
    shift @so;
    shift @si;
    print "\n\nNext Track: $tmpSing - $tmpSong\n\n";
    $cmd = "/usr/bin/mplayer http://localhost:60210/sid/$next";
    $myproc->start($cmd);
    $pid = $myproc->pid;
    $exists = kill 0, $pid;

    if (-e "/usr/bin/kdialog") {
      $cmd = '/usr/bin/kdialog --title "Playerdar Info" --passivepopup "Now Playing: '. $tmpSing . ' - ' . $tmpSong . '"';
      system $cmd;
    }


  }

  print "Done";

}

sub play {

  my ($id) = @_;
  my $cmd = "http://localhost:60210/sid/$id";
  
  my $player = Audio::Play::MPlayer->new;
  $player->load( $cmd );
  
  #print Dumper($player);
  #write loop to keep playlist at 10 then play first in playlist
    while ($player->state == 2){
      #sleep 1;
      $player->poll( 1 )
    }

  $player->load( "http://localhost:60210/sid/$playlist[0]" );
  shift(@playlist);
  

#print $player->state;
#system $cmd;
}

sub fetch_sim {
  
  my ($art, $trk) = @_;
  my $id = "Fail";
  my $testArt = '';
  my $testTrk = '';
  my $simqid = '';
  my $simsid = '';
  #my $match = 0;

  my $lastfm = Net::LastFM->new(
    api_key    => $APIk,
    api_secret => $APIs,
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

  #print ".";
  
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
  my $response = "Ok";
  
  foreach my $try (@listened) {
  
  $try =~ tr/[A-Z]/[a-z]/;
  $Cid =~ tr/[A-Z]/[a-z]/;

  if ( $Cid eq $try ) {
    
    $response = "Fail";

  } else {

    if ($response ne "Fail") {

      $response = "Ok";
    
    }
    }
    
    #print "$Cid - $try - $response \n";

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
  #print "@listened \n";

}


