#! /usr/bin/perl

#Known issue : the log does not contain installation from Arch iso and thus can't retrieve their version

use Getopt::Std;
use strict;

sub print_usage_help;
sub trim($);

my $all_packages = 0;
my $quiet = 0;
my $log_file = "/var/log/pacman.log";
my $verbose = 0;
my $wanted_date = "";
my %options = ();
my %packages = ();
my @target_packages = ();

getopts("hvap:d:l:n", \%options);

if(exists($options{'h'}))
{
  print_usage_help();
  exit 2;
}

if(exists($options{'v'}))
{
  $verbose = 1;
}

if(exists($options{'a'}))
{
  $all_packages = 1;
}

if(exists($options{'n'}))
{
  $quiet = 1;
}

if(exists($options{'p'}))
{
  if($options{'p'} eq "")
  {
    print "-p requires packages name\n";
    exit 2;
  }

  @target_packages = grep(s/\s*//g, split(',', $options{'p'}));
}

my $target_packages_count = @target_packages;
if($all_packages == 0 && $target_packages_count == 0)
{
  print "You must either pass -a to show all packages or provide -p with a list of comma-separated packages\n";
  exit 2;
}

if(exists($options{'d'}))
{
  $wanted_date = $options{'d'};
  if($wanted_date =~ /^\s*(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{1,2})\s*$/)
  {
    $wanted_date = "$1-$2-$3 $4:$5";
    if($verbose)
    {
      print "Date set to $1-$2-$3 $4:$5 (\"$wanted_date\")\n";
    }
   }
  elsif($wanted_date =~ /^\s*(\d{4})-(\d{2})-(\d{2})\s*$/)
  {
    $wanted_date = "$1-$2-$3 00:00";
    if($verbose)
    {
      print "Date set to $1-$2-$3 00:00 (\"$wanted_date\")\n";
    }
  }
  else
  {
    print "Date format is wrong, use this format : \"2012-11-29 [11:42]\"\n";
    exit 1;
  }
}
else
{
  printf "You must specify a date using -d\n";
  exit 1;
}

if(exists($options{'l'}))
{
  $log_file = $options{'l'};
}

open(PACMAN_LOG_FILE_FD, "$log_file")
  or die "cannot open log_file: $!";

while(my $log_line = <PACMAN_LOG_FILE_FD>)
{
  if($log_line =~ /\[(.*)\]\s*removed\s*(.+)\s*\((.+)\)/)
  {
    my $date = $1;
    my $package_name = trim($2);

    if("$date" gt "$wanted_date")
    {
      last;
    }

    delete $packages{$package_name};
  }
  elsif($log_line =~ /\[(.*)\]\s*upgraded\s*(.+)\s*\((.+)\s*->\s*(.+)\)/)
  {
    my $date = $1;
    my $package_name = trim($2);
    my $package_version_from = trim($3);
    my $package_version_to = trim($4);

    if("$date" gt "$wanted_date")
    {
      last;
    }

    if($verbose)
    {
      if(exists($packages{$package_name}))
      {
        if($packages{$package_name} ne $package_version_from)
        {
          print "Notice : Upgraded $package_name ( \"$package_version_from\" -> $package_version_to) from a version not installed (\"$packages{$package_name}\")\n";
        }
      }
      else
      {
        print "Notice : Upgraded $package_name when not found as previously installed\n";
      }
    }

    $packages{$package_name} = $package_version_to;
  }
  elsif($log_line =~ /\[(.*)\]\s*installed\s*(.+)\s*\((.+)\)/)
  {
    my $date = $1;
    my $package_name = trim($2);

    if("$date" gt "$wanted_date")
    {
      last;
    }

    $packages{$package_name} = $3;
  }
}

close(PACMAN_LOG_FILE_FD);

if($all_packages)
{
 foreach my $key (sort keys %packages)
 {
    print "$key $packages{$key}\n";
 }
}
else
{
  foreach(@target_packages)
  {
    if(exists($packages{$_}))
    {
      print "$_ : $packages{$_}\n";
    }
    elsif(! $quiet)
    {
      print "$_ not found for this date\n";
    }
  }
}

sub print_usage_help
{
  print "pacintime allows you to query what package versions were installed at any given time.\n";
  print "As it relies solely on logs, having a misconfigured date or\n";
  print "having cleared pacman.log in the past will result in probably wrong results.\n\n";
  print "Usage : pacintime -d DATE [OPTIONS]\n";
  print "OPTIONS:\n";
  print "-h                           print help\n";
  print "-v                           verbose\n";
  print "-a                           show all packages installed at the specified date\n";
  print "-p {package1,package2,...}   comma-sperated packages lists to query\n";
  print "-d date                      date to check packages for\n";
  print "-l file                      specify a non-default pacman.log\n";
  print "-n                           do not print not found packages error\n";
  print "\n";
  print "DATE : date to get the snapshot from, form : -d \"2012-11-29 02:02\"\n";
  print "       the hours and minutes can be omitted, defaults to 00:00\n";
  print "       A date in the future is synonym of \"now\"\n";
  print "\n";
  print "Example : ./pacintime.pl -d \"2011-11-20\" -p xorg-server,ati-dri\n";
}

sub trim($)
{
  my $string = shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  return $string;
}
