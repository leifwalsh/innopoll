#!/usr/bin/perl -w

=head1 NAME

innopoll.pl - poll some specific stats from InnoDB

=head1 SYNOPSIS

For a paper, we want to extract some stats out of InnoDB about the insert
buffer.  This script eats SHOW ENGINE INNODB STATUS output and selects a
few fields we care about.

    $ ./innopoll.pl [--debug] [--period N] [-u|--user user] [-p|--pass pass] [--host host[:port]]

=head1 LICENSE

Artistic License 2.0

=head1 COPYRIGHT

Copyright (c) 2014 Leif Walsh

=cut

use strict;

use Getopt::Long;
use DBI;
use Text::CSV_XS;
use Time::Local;
use Pod::Usage;
use POSIX qw(strftime);

my $help = 0;
my $man = 0;
my $debug = 0;
my $period = 5;
my $user = 'root';
my $pass = undef;
my $host = '127.0.0.1';
my $port = undef;
GetOptions(
           'help|?' => \$help,
           man => \$man,
           debug => \$debug,
           'period=i' => \$period,
           'user|u=s' => \$user,
           'pass|p=s' => \$pass,
           'host=s' => sub { ($host, $port) = split /:/, $_[1]; }
          )
  or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;

my $tsv = Text::CSV_XS->new({
    #quote_char      => undef,
    #escape_char     => undef,
    sep_char        => ",",
    eol             => "\n",
    quote_space     => 0,
    quote_null      => 0,
});

my $connstring = "DBI:mysql:database=test;host=$host";
if (defined($port)) {
  $connstring .= ";port=$port";
}
my $dbh = DBI->connect($connstring, $user, $pass) or die;
my $query = "SHOW ENGINE INNODB STATUS";

my $d = qr((\d+));
my $f = qr((\d+.\d+));

my @headers =
  qw(
      timestamp

      ib_size ib_free_len ib_seg_size ib_merges
      ib_merged_inserts ib_merged_delete_mark ib_merged_delete
      ib_discarded_inserts ib_discarded_delete_mark ib_discarded_delete

      io_rd_num io_wr_num io_sync_num
      io_rd_per_sec io_bytes_per_rd io_wr_per_sec io_sync_per_sec

      ro_inserts ro_updates ro_deletes ro_reads
      ro_inserts_ps ro_updates_ps ro_deletes_ps ro_reads_ps

      bp_mem_alloc bp_mem_addl
      bp_dict_mem_alloc
      bp_size
      bp_free
      bp_db_pages
      bp_db_pages_old
      bp_db_pages_dirty
      bp_pending_reads
      bp_pending_writes_lru bp_pending_writes_flush bp_pending_writes_single
      bp_made_young bp_made_not_young
      bp_made_young_ps bp_made_not_young_ps
      bp_reads bp_creates bp_writes
      bp_reads_ps bp_creates_ps bp_writes_ps
   );

$tsv->print(\*STDOUT, \@headers);

# enable autoflush
$| = 1;

my @vals = my ($timestamp,

               $ib_size, $ib_free_len, $ib_seg_size, $ib_merges,
               $ib_merged_inserts, $ib_merged_delete_mark, $ib_merged_delete,
               $ib_discarded_inserts, $ib_discarded_delete_mark, $ib_discarded_delete,

               $io_rd_num, $io_wr_num, $io_sync_num,
               $io_rd_per_sec, $io_bytes_per_rd, $io_wr_per_sec, $io_sync_per_sec,

               $ro_inserts, $ro_updates, $ro_deletes, $ro_reads,
               $ro_inserts_ps, $ro_updates_ps, $ro_deletes_ps, $ro_reads_ps,

               $bp_mem_alloc, $bp_mem_addl,
               $bp_dict_mem_alloc,
               $bp_size,
               $bp_free,
               $bp_db_pages,
               $bp_db_pages_old,
               $bp_db_pages_dirty,
               $bp_pending_reads,
               $bp_pending_writes_lru, $bp_pending_writes_flush, $bp_pending_writes_single,
               $bp_made_young, $bp_made_not_young,
               $bp_made_young_ps, $bp_made_not_young_ps,
               $bp_reads, $bp_creates, $bp_writes,
               $bp_reads_ps, $bp_creates_ps, $bp_writes_ps);

$tsv->bind_columns(\$timestamp,

                   \$ib_size, \$ib_free_len, \$ib_seg_size, \$ib_merges,
                   \$ib_merged_inserts, \$ib_merged_delete_mark, \$ib_merged_delete,
                   \$ib_discarded_inserts, \$ib_discarded_delete_mark, \$ib_discarded_delete,

                   \$io_rd_num, \$io_wr_num, \$io_sync_num,
                   \$io_rd_per_sec, \$io_bytes_per_rd, \$io_wr_per_sec, \$io_sync_per_sec,

                   \$ro_inserts, \$ro_updates, \$ro_deletes, \$ro_reads,
                   \$ro_inserts_ps, \$ro_updates_ps, \$ro_deletes_ps, \$ro_reads_ps,

                   \$bp_mem_alloc, \$bp_mem_addl,
                   \$bp_dict_mem_alloc,
                   \$bp_size,
                   \$bp_free,
                   \$bp_db_pages,
                   \$bp_db_pages_old,
                   \$bp_db_pages_dirty,
                   \$bp_pending_reads,
                   \$bp_pending_writes_lru, \$bp_pending_writes_flush, \$bp_pending_writes_single,
                   \$bp_made_young, \$bp_made_not_young,
                   \$bp_made_young_ps, \$bp_made_not_young_ps,
                   \$bp_reads, \$bp_creates, \$bp_writes,
                   \$bp_reads_ps, \$bp_creates_ps, \$bp_writes_ps);

do {
  my $text  = $dbh->selectall_arrayref($query)->[0]->[2];

  my ($ts_text) = $text =~ m/(\d{4}-\d{2}-\d{2}\s+\d{1,2}:\d{2}:\d{2})\s+[0-9a-f]+\s+INNODB MONITOR OUTPUT/;
  my ($year, $month, $day, $hour, $minute, $second) = $ts_text =~ m/$d-$d-$d\s+$d:$d:$d/;
  my $time = timelocal($second, $minute, $hour, $day, $month-1, $year);

  # ISO8601 business
  my $tz = strftime("%z", localtime($time));
  $tz =~ s/(\d{2})(\d{2})/$1:$2/;
  $timestamp = strftime("%Y-%m-%dT%H:%M:%S", localtime($time)) . $tz;

  my ($ib_text) = $text =~ m/INSERT BUFFER AND ADAPTIVE HASH INDEX\n-*\n(.*\n.*\n.*\n.*\n.*\n)/m;
  ($ib_size, $ib_free_len, $ib_seg_size, $ib_merges,
   $ib_merged_inserts, $ib_merged_delete_mark, $ib_merged_delete,
   $ib_discarded_inserts, $ib_discarded_delete_mark, $ib_discarded_delete) = my @ib_data =
     $ib_text =~ m/Ibuf: size $d, free list len $d, seg size $d, $d merges
merged operations:
 insert $d, delete mark $d, delete $d
discarded operations:
 insert $d, delete mark $d, delete $d/m;
  print STDERR join(", ", @ib_data), $/, $/ if $debug;

  my ($io_text) = $text =~ m/FILE I\/O\n-*\n(?:I\/O thread \d+ state:.*\n)*.*\n.*\n.*\n(.*\n(?:\d+ pending preads, \d+ pending pwrites\n)?.*\n)/m;
  ($io_rd_num, $io_wr_num, $io_sync_num,
   $io_rd_per_sec, $io_bytes_per_rd, $io_wr_per_sec, $io_sync_per_sec) = my @io_data = 
     $io_text =~ m/$d OS file reads, $d OS file writes, $d OS fsyncs(?:
\d+ pending preads, \d+ pending pwrites)?
$f reads\/s, $d avg bytes\/read, $f writes\/s, $f fsyncs\/s/m;
  print STDERR join(", ", @io_data), $/, $/ if $debug;

  my ($ro_text) = $text =~ m/ROW OPERATIONS\n-*\n.*\n.*\n.*\n(.*\n.*\n)/m;
  ($ro_inserts, $ro_updates, $ro_deletes, $ro_reads,
   $ro_inserts_ps, $ro_updates_ps, $ro_deletes_ps, $ro_reads_ps) = my @ro_data = 
     $ro_text =~ m/Number of rows inserted $d, updated $d, deleted $d, read $d
$f inserts\/s, $f updates\/s, $f deletes\/s, $f reads\/s/m;
  print STDERR join(", ", @ro_data), $/, $/ if $debug;

  my ($bp_text) = $text =~ m/BUFFER POOL AND MEMORY\n-*\n(.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n)/m;
  ($bp_mem_alloc, $bp_mem_addl,
   $bp_dict_mem_alloc,
   $bp_size,
   $bp_free,
   $bp_db_pages,
   $bp_db_pages_old,
   $bp_db_pages_dirty,
   $bp_pending_reads,
   $bp_pending_writes_lru, $bp_pending_writes_flush, $bp_pending_writes_single,
   $bp_made_young, $bp_made_not_young,
   $bp_made_young_ps, $bp_made_not_young_ps,
   $bp_reads, $bp_creates, $bp_writes,
   $bp_reads_ps, $bp_creates_ps, $bp_writes_ps) = my @bp_data =
     $bp_text =~ m/Total memory allocated $d; in additional pool allocated $d
Dictionary memory allocated\s+$d
Buffer pool size\s+$d
Free buffers\s+$d
Database pages\s+$d
Old database pages\s+$d
Modified db pages\s+$d
Pending reads\s+$d
Pending writes: LRU $d, flush list $d, single page $d
Pages made young $d, not young $d
$f youngs\/s, $f non-youngs\/s
Pages read $d, created $d, written $d
$f reads\/s, $f creates\/s, $f writes\/s/m;
  print STDERR join(", ", @bp_data), $/, $/ if $debug;

  $tsv->print(\*STDOUT, undef);
} while (sleep $period);
