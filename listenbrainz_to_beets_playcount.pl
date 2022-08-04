#!/usr/bin/perl

# A Messy and Dirty script to import playcounts from listenbrainz
# into beets.  I try and run this script a couple of times a year
# I don't need up-to-date counts, just an idea of what I've liked
# over the years and what might be good to check out, which this
# does.

# Get your data from https://listenbrainz.org/profile/export/
# Click on Download Listens.  Drop file in current
# directory, change filename below to match.

# Run the script.  It'll create a new file named `output.beets`.
# run it with `sh output.beets`.  It'll take a LONG TIME.

# When your done, delete the json file and output.beets

# - Known Bugs ----------------------------------------------------------------
# 1. Dupes when songs have words with a ' or a ’ - same with ... (or utf char 
#    for the same)  even have a few tracks with same name but no apostrophe
#     fix: figure out it's a dupe, add both counts together, submit two times to
#     beets? how to match dupes?
# 2. beet import process is super slow.  Maybe open library and
#    update with sqllite queries?
# 3. Need to store timestamp of last run.  Only produce new beets commands
#    for updated tracks

use JSON::PP;
use utf8;

my $filename = 'xterminus_lb-2022-08-04.json';

my %counter;
my $data;

# Read JSON in as a string.  Use Perl's JSON module
# to make a perl hash with the JSON data.
if (open (my $json_stream, $filename))
{
	local $/ = undef;
	my $json = JSON::PP->new;
	$data = $json->decode(<$json_stream>);
	close($json_stream);
}

# Pluck the unique data we want from the current listen
# hash.  Make it into a unique string.  And Count it.
foreach my $submission (@$data) {
  my $string;

  if ( $submission->{track_metadata}->{additional_info}->{track_mbid} ) {

    $string = "mbid:$submission->{track_metadata}->{additional_info}->{track_mbid}";

  } else {

  # lowercase, and clean the crap out of strings... I recurse the cleanup
  # to catch multiple featured... type tags.  You would not believe the crappy
  # track titlenames that get submitted....

  my $artist = uc( Cleanup( Cleanup( $submission->{track_metadata}->{artist_name} ) ) );
  my $album  = lc( Cleanup( Cleanup( $submission->{track_metadata}->{release_name} ) ) );
  my $track  = lc( Cleanup( Cleanup( $submission->{track_metadata}->{track_name} ) ) );

 next unless (defined $artist and length $artist) ; # Happens sometimes... Stripped too much?
 next unless (defined $album and length $album) ;   # Happens sometimes... Stripped too much?
 next unless (defined $track and length $track);    # Happens sometimes... Stripped too much?
 # Without above, a lot of playcount clobbering happens.

  # Use :: as a field seperator... for reasons...
   $string = "$artist :: $album :: $track";
 }
 # Increment counter  
 $counter{ $string }++;
}
# Clear up some Memory, We're done with the original hash.
undef $data;

# Open a file handle.
use open ':encoding(utf-8)';
open (my $FH, ">", "output.beets") or die$!;

# Now pull the hash apart again and create a beets command
foreach my $result (sort keys %counter) {
 # If we have a musicbrainz track_id, that's perfect.
 if ($result =~ /mbid:(.*)/) {
   print $FH "beet modify -y -W playcount=$counter{ $result } \'mb_trackid:$1\'\n";
 # Otherwise, try and grab a generic match
 } else {
 my @array = split(' :: ',$result,);
 my $artist = quotemeta( $array[0] );
 my $album  = quotemeta( $array[1] );
 my $title  = quotemeta( $array[2] );

 # -y (don't ask)
 # -W (don't write tags, just write to beet database)
 # I don't think the playcount tag can be written anyway, it's not standard id3
 print $FH "echo\n";
 print $FH "echo beeting on $artist :: $album :: $title ...\n";
 print $FH "beet modify -y -W playcount=$counter{ $result } artist:$artist album:$album title:$title\n";
 }
}

# Done

sub Cleanup{

 my $phrase = $_[0];
 my $output;

 # Strip featuring tags... " feat"
 if ( $phrase =~ /^(.*)\ .*feat.*/gi ) {
  $output = $1; 
 }
 
# Strip featuring tags... "feat."
 if ( $phrase =~ /^(.*).*feat\.\ .*/gi ) {
  $output = $1; 
 }

# Strip featuring tags... "[ or (" and then "feat"
 if ( $phrase =~ /^(.*)\ [\(|\[].*feat.*/gi ) {
  $output = $1; 
 }

# Strip extra crap... "[ or (" and then "list of stuff below"
 if ( $phrase =~ /^(.*)[\(|\[].*[Cut|Radio|UK|Mixed|Edit|Single|Deluxe|Remix|Version].*/gi ) {
  $output = $1; 
 }

 if ( defined($output) ) { 
  # Trim spaces on both sides of string
  $output =~ s/^\s+|\s+$//g; 
  return $output; 
 } else { 
  return $phrase; 
 }
}
