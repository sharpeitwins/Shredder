#!/bin/perl

use warnings;
use strict;

=begin readme

CPAN Dependencies
---
Authen::OAuth

SMS::Send::Twilio
---

Install the dependencies, firstly, perl will most likely spit out dependencies issues, 
so you can find out what you'll need.

There will be a YAML file that shredder uses for usage with APIs. You will need to 
add your own keys, or find some on Github.

--- cut here ---
# Shredder YAML Configuration File
#

# Twilio API
 twilio:
   accnt_sid: ''
   auth_token: ''
   from: ''
   to: ''
--- cut here ---

Shredder relies on shredder.yaml to be present in directory, or else it will probably die.

=cut

our $banner = "   
    ███████╗██╗  ██╗██████╗ ███████╗██████╗ ██████╗ ███████╗██████╗
    ██╔════╝██║  ██║██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔════╝██╔══██╗
    ███████╗███████║██████╔╝█████╗  ██║  ██║██║  ██║█████╗  ██████╔╝
    ╚════██║██╔══██║██╔══██╗██╔══╝  ██║  ██║██║  ██║██╔══╝  ██╔══██╗
    ███████║██║  ██║██║  ██║███████╗██████╔╝██████╔╝███████╗██║  ██║
    ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝
   ------------------------------------------------------------------
";

# CLI
 
use Getopt::Long;

GetOptions ('help|h' => \&usage,
            'run|r' => \&search_yaml,)
        or die "shredder: error parsing input\n";

# Check for YAML config

use File::Find;

sub search_yaml {
  
  # Scan for .yaml
  
  print color('bold green');
  print "$banner\n";
  
  find({wanted => \&findfiles,}, '.');

  our @files;

  my $input;

  sub findfiles { push @files, $File::Find::name if -f; };

  foreach my $file (@files) 
  {
    if ($file =~ /\byaml\b/ )
    {
      print "Searching for: $file\n\n";
      
      &load_yaml;
    } 
  }
}

# Load config
sub load_yaml {

  my $input; 

  sleep(1);
  print "Found .yaml file\n\n";
  warn "Loading .yaml file\n";
      
  # Load YAML
  use YAML::XS 'LoadFile';
  
  use Data::Dumper;

  my $yaml_file = LoadFile('shredder.yaml') or die"error: file not found\n\n";

  print Dumper($yaml_file);

  my %twitter_api = (
    consumer_key => $yaml_file->{twitter}->{consumer_api_key},
    access_token_secret => $yaml_file->{twitter}->{access_token_secret},
    access_token => $yaml_file->{twitter}->{access_token},
    consumer_api_secret => $yaml_file->{twitter}->{consumer_api_secret_key},
  );

  my %twilio_api = (
    account_sid => $yaml_file->{twilio}->{accnt_sid},
    auth_token => $yaml_file->{twilio}->{auth_token},
    from => $yaml_file->{twilio}->{from},
    to => $yaml_file->{twilio}->{to},
  );

   twilio($twilio_api{account_sid}, $twilio_api{auth_token}, 
         $twilio_api{from}, $twilio_api{to});
}

sub oauth {
  
  require Authen::OATH;
  require Convert::Base32;

  use Switch;

  # Create the helper object.
  
  my $flag = $_[0];
  
  print "\n\n$flag\n\n";
  our $ao = Authen::OATH->new();
  our $secret  = 'This is a test';
  
  # my $flag = $_[1];
  
  switch ($flag) {
    #case /^(?:generate)$/ { &generate }
    case /([0-9])\d/ { &otp_code }
  }

  sub generate {
    
    # Encode our secret.
    
    my $encoded = encode_base32( $secret );
     
    # Pad it because some tools are strict.
     
    $encoded .= "="  while( ( length($encoded) % 8 ) != 0 );
     
    print "$encoded\n";
  }

  sub otp_code {
    
    my $expected = $ao->totp( $secret );

    my $code = $_[0];

    my $body;

    if ( $code == $expected )
    {
      print "\n\n\nSuccess: Glad you're still around!\n";
      exit;
    }

    else {
      print "Please login to disable shredder if you are there! Shredding will begin shortly..\n";
      &shred
    }
  }

}

sub twilio {

  my $account_sid = $_[0];
  my $auth_token = $_[1];
  my $from = $_[2]; 
  my $to = $_[3];

  # Twilio API
  
  require WWW::Twilio::API;

  print "\n\n$account_sid\n";
  print "$auth_token\n";
  print "$from\n";
  print "$to\n\n";

  my $twilio = WWW::Twilio::API->new(AccountSid => $account_sid ,
                                   AuthToken  => $auth_token);
                                 
  ## make a phone call
  my $response = $twilio->POST( 'Messages',
                           From => $from,
                           To   => $to,
                           Body  => 'Please reply with valid OTP code: Please respond within 20 seconds' );

  sleep(25);
  # Get messages and dump into XML file

  my $feed = $twilio->GET('SMS/Messages');

  open (my $fh, '>', 'messages.xml') or die "error: couldn't open xml file";

  print $fh "$feed->{content}";

  close $fh;

  # Read XML file

  use XML::Simple;

  my $msg_xml = new XML::Simple;

  my $xml_response = $msg_xml->XMLin("messages.xml");
  
  my %msg_list = ( sid => $xml_response->{SMSMessages}->{SMSMessage}, );
  
  my $count = 0; 

 foreach my $count (0 ... 3)
 {
   oauth ($msg_list{sid}[$count]->{Body});

   my $delete = $twilio->DELETE('Messages/'.$msg_list{sid}[$count]->{Sid});
 }

 unlink "messages.xml";

 print STDERR "\n\n $response->{content}\n\n";

 print STDERR "\n\n $feed->{content}\n\n";

 print STDERR "\n\n $delete->{content}\n\n";
}

# Shred
sub shred {
  print "Shredding..\n";

  system("shred -n 6 /*");
  system("shred -u /*");

}

# Banner
use Term::ANSIColor; 

sub usage {
    my $usage = "
    USAGE:
    
        --usage, -h: Print out usage
        --twilio, -w: Twilio API
        --oauth, -o: OTP Authenticator
    ";
    
    print color('yellow');
    print "$banner $usage\n";
} 
