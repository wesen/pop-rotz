#!/usr/bin/perl -w

use strict;
use IO::Socket;
use POSIX qw(:sys_wait_h);
my $client;
my $state = "auth";
my ($mail, $mid, $user, $pass);

sub poprotz_mid {
   return (rand 239849283).".".(rand 239489283)."\@entropia.de";
}

sub poprotz_header {
   my $str = "Date: ".(localtime)."\r\n";
   $str .= "From: r00t\@entr0pia.de\r\n";
   $str .= "To: 3v1luser\@entr0pia.de\r\n";
   $str .= "Subject: Du bist ja doof\r\n";
   $str .= "Message-ID: ".(shift)."\r\n\r\n";
}

sub poprotz_body {
   my $str = "Geh sterben du Luser! Dein Account ist \"$user\"/\"$pass\"!\n";
   return $str;
}

sub poprotz_makemail {
   $mid = poprotz_mid;
   $mail = poprotz_header($mid).poprotz_body;
}

# XXX
sub REAPER {
   waitpid(-1, WNOHANG);
   $SIG{CHLD} = \&REAPER;                 # unless $] >= 5.002
}

sub pop_send {
   my $txt = shift;

   $txt = "" if (!defined($txt));
   print "Sending: $txt\n";
   my $len = $client->send("$txt\r\n");

   if (!defined($len) || ($len == 0)) {
      $client->close;
      exit;
   }
}
sub pop_ok {
   pop_send("+OK ".shift);
}

sub pop_err {
   pop_send("-ERR ".shift);
}

sub poprotz_banner {
   pop_ok("POP3 ready");
}

sub poprotz_user {
   $user = shift;
   if (!defined($user)) {
      pop_err("Invalid user");
   } else {
      pop_ok("May I have your password, please?");
      $state = "user";
   }
}

sub poprotz_pass {
   $pass = shift;

   if ($state eq "user") {
      $pass = "" if (!defined($pass));
      pop_ok("User authorized.");
      poprotz_makemail;
      $state = "trans";
   } else {
      pop_err("User comes first");
   }
}

sub poprotz_stat {
   if ($state eq "trans") {
      pop_ok("1 ".length $mail);
   } else {
      pop_err("Unknown command");
   }
}

sub poprotz_list {
   if ($state eq "trans") {
      pop_ok("LIST 1 message (".(length $mail)." octets)");
      pop_send("1 ".(length $mail)."\r\n.");
   } else {
      pop_err("Unknown command");
   }
}

sub poprotz_retr {
   if ($state eq "trans") {
      my $num = shift;
      if (defined($num) && ($num == 1)) {
         pop_ok((length $mail)." octets");
         pop_send("$mail\r\n.");
      }
   } else {
      pop_err("Unknown command");
   }
}

sub poprotz_uidl {
   if ($state eq "trans") {
      if (defined(shift)) {
         pop_ok("1 $mid");
      } else {
         pop_ok("");
         pop_send("1 $mid\r\n.");
      }
   } else {
      pop_err("Unknown command");
   }
}

sub poprotz_dele {
   if ($state eq "trans") {
      pop_ok("Message deleted");
   } else {
      pop_err("Unknown command");
   }
}

sub poprotz_noop {
   pop_ok("NOOP");
}

sub poprotz_quit {
   $client->close;
   exit;
}

my %poprotz_handlers = (
   "USER"       => \&poprotz_user,
   "PASS"       => \&poprotz_pass,
   "QUIT"       => \&poprotz_quit,
   "STAT"       => \&poprotz_stat,
   "LIST"       => \&poprotz_list,
   "RETR"       => \&poprotz_retr,
   "TOP"        => \&poprotz_retr,
   "UIDL"       => \&poprotz_uidl,
   "DELE"       => \&poprotz_dele,
   "NOOP"       => \&poprotz_noop,
);

sub poprotz {
   my $str;

   poprotz_banner();

   while (defined($client->recv($str, 512))) {
      chomp($str);
      my ($cmd, @args) = split /\s+/, $str;
      
      next unless (defined($cmd));
      $cmd = "\U$cmd";

      print "Received: $str\n";

      if (defined($poprotz_handlers{$cmd})) {
         $poprotz_handlers{$cmd}->(@args);
      } else {
         pop_err("Unknown command.");
      }
   }
}

$SIG{CHLD} = \&REAPER;

if (@ARGV != 2) {
    print "poprotz.pl <bindaddr> <port>\n";
    exit 1;
}

my $server = IO::Socket::INET->new(LocalAddr => $ARGV[0],
                                   LocalPort => $ARGV[1],
                                   Type      => SOCK_STREAM,
                                   Reuse     => 1,
                                   Listen    => 255)
or die "Couldn't be a tcp server: $@\n";

while ($client = $server->accept()) {
   my $pid;

   #die "fork: $!" unless defined $pid;     # failure

   next if $pid = fork;                    # parent
   next unless defined $pid;
   poprotz;
   $client->close;
   exit;                                   # child leaves
} continue {
   $client->close;
}
