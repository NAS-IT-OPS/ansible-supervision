#!/usr/bin/perl -w
# 15-10-20 - cvidal  :  creation
# 19-09-04 - cvidal  :  migration on s3
# 2021-10-26 - Valery NAHUM / Maxime KERMARQUER : backup on AWS



# loading modules
use lib '/root/perl5/lib/perl5/';
use strict;
use warnings;
use diagnostics;
use DBI;
use POSIX qw( strftime );

use Getopt::Long;
use MIME::Lite;



# database connection parameters
my $bd            = 'mysql';
my $serveur       = 'localhost'; # IP address also possible
my $user          = 'root';      # user
my $password      = $ENV{'PASSWORD'};
my $port          = '';




# database connection
my $dbh = DBI->connect( "DBI:mysql:database=$bd;host=$serveur;port=$port",
$user, "$password", {
  RaiseError => 1,
}
) ||  die "database connection unavailable for $bd - error is $DBI::errstr";




# variable declarations
my $dir_base        = "/home";
my $folder          = "backupsvc";
my $dir_backup      = "$dir_base/$folder";
my $bucket_backup   = "s3://databases-glpi-backup-1635253440";
my $databases       = $dbh->selectcol_arrayref('show databases');
my $D0              = strftime("%Y-%m-%d", localtime);
my $H0              = strftime("%H:%M:%S", localtime);
my $logfile         = "/var/log/mysqldump/$D0\_mysqlDB_backup.log";
my $archive         = "$D0\_srvmysql_mysql-dumps.tar.gz";
my $erreur          = 0;
my $copy            = ""; # test copy on s3 bucket
my $rm_sql;               # output rm .sql command
my $subject;              # email subject




# log file initialisation
if (! -e $dir_backup) {
  system("mkdir $dir_backup");
}
system "/usr/bin/touch $logfile";
open(LOG , ">>$logfile") or die("open: $!");
print LOG "005-MYSQL\n";
print LOG "Starting daily backup - $D0 $H0\n\n\n";
print LOG "  * Running dumps \n";


# run dump for each mysql instance
foreach my $db (@$databases){
        my $D2 = strftime("%Y-%m-%d", localtime);
        my $H2 = strftime("%H:%M:%S", localtime);

        print LOG "\n   + [$db] - $D2 - $H2\n";

        my $file = "$dir_backup/$D2\_$db.sql";

  my $cmd_backup = "/usr/bin/mysqldump -R --opt $db --user $user -p'$password' --single-transaction";
        my $cmd_backup_output = `$cmd_backup 2>&1 1>$file`;
  chomp($cmd_backup_output);

        # test command STDERR
        if ($cmd_backup_output eq "Warning: Using a password on the command line interface can be insecure.") {
                print LOG "     - OK -- Database [$db] backup successfull\n";
        }
        else {
                print LOG "     - ERROR -- Database dump [$db] error : [$cmd_backup_output]\n";
    $erreur++;
        }


        # test file exists
        if (-e $file) {
                print LOG "     - OK -- Dump creation for [$db]\n";
        }
        else {
                print LOG "     - ERROR -- Database dump for [$db] does not exists \n";
    $erreur++;
        }

}



# dump compression
print LOG "\n * Dump compression \n";
my $output_archive = `/bin/tar -cvzf $archive -C $dir_base $folder 2>&1 1>/dev/null`;
chomp($output_archive);
if (! $output_archive eq "" || ! $output_archive eq "/bin/tar: Suppression de « / » au début des noms des membres") {
        print LOG "     - ERROR -- Dump compression error for [$output_archive]\n";
  $erreur++;
}



# check if archive exists and put message in log file
if (-e $archive) {
        print LOG "     - OK -- Archive creation\n";
}
else {
        print LOG "     - ERREUR -- Archive does not exists\n";
  $erreur++;
}



# dump copy on S3 bucket
print LOG "\n * Copy on S3 bucket\n";
my $output_copy_s3 = `/usr/bin/aws  --profile glpi-backup s3 cp $archive $bucket_backup/$archive 2>&1 1>/dev/null`;
if (!$output_copy_s3 eq "") {
        print LOG "     - ERROR -- Copy on S3 bucket $bucket_backup : $output_copy_s3\n";
  $erreur++;
}


# check file exists on bucket
my $output_s3_file_exists = `/usr/bin/aws --profile glpi-backup s3 ls $bucket_backup/ | grep $archive 2>>/dev/null`;
if (!$output_s3_file_exists eq "") {
  print LOG "     - OK -- Archive exists on S3 bucket\n";
  $copy = "ok";
}
else {
  print LOG "     - ERREUR -- Archive does not exist on S3 bucket\n";
  $erreur++;
}


# if copy ok, delete .sql and archive
if ($copy eq "ok") {
  print LOG "\n * Deleting .sql and archive\n";
  $rm_sql = `rm -f $dir_backup\/*.sql 2>&1 1>/dev/null`;
  if (! $rm_sql eq "") {
    print LOG "     - ERROR -- .sql deletion pb : [$rm_sql]\n";
    $erreur++;
  }


  my $rm_targz = `rm -f $archive 2>&1 1>/dev/null`;
   if (! $rm_targz eq "") {
    print LOG "     - ERROR -- Archive deletion pb : $rm_targz\n";
    $erreur++;
  }
}



# closing log file & send email
my $D3 = strftime("%Y-%m-%d", localtime);
my $H3 = strftime("%H:%M:%S", localtime);
print LOG "\n\nBackup end at : $D3 - $H3\n";
close(LOG);

if ($erreur == 0) {
  $subject = "[005] OK -- MYSQL - mysql backup";
}
else {
  $subject = "[005] NOK -- MYSQL - mysql backup : $erreur error(s)";
}



# send email parameters
my $smtpserver = 'postfix';
my $from       = 'backup@srvmysql-icm';
my $to         = 'admins@icm-institute.org';
my $message;



# include log file in message
open( my $fh, '<', $logfile);
while ( my $ligne = <$fh> ) { $message .= $ligne; }
close($fh);



# sending email
my $mail = new MIME::Lite
  From    => $from,
  To      => $to,
  Subject => $subject,
  Type    => 'text/plain',
  Data    => $message;

$mail->send_by_smtp($smtpserver) or die "mail not sent\n$!\n\n";
