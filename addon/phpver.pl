#!/usr/bin/perl
BEGIN { push @INC, '/usr/local/ispmgr/lib/perl' }
use CGI;
use LWP::UserAgent;
use CGI::Carp qw(fatalsToBrowser);
use LWP::UserAgent;
use Time::localtime;
#use strict;
#use warnings;
use XML::Simple;
use Mgr;
#take a time
sub timestamp 
{
 	my $t = localtime;
    return sprintf( "%04d-%02d-%02d_%02d-%02d-%02d",
    $t->year + 1900, $t->mon + 1, $t->mday,
    $t->hour, $t->min, $t->sec );
}

#prepare
my $v53 = "#!/opt/php/php53-cgi";
my $v54 = "#!/usr/bin/php-cgi";
my $v55 = "#!/opt/php/php55-cgi";
my $v56 = "#!/opt/php/php56-cgi";
my $v70 = "#!/opt/php/php70-cgi";

#Get current user php version
my $Q = new CGI;
open DATA, "<phpchanger/domain.user";
my @rows = <DATA>;
close DATA;
my $user = $ENV{"REMOTE_USER"};
my $curdomain = $Q->param("domain");
my $newphp = $Q->param("phpver");
my $cdomain = $Q->param("elid");
my $usercurrentphpver = "5.4";
foreach $row (@rows) 
	{
		my @elems = split / /, $row, 3;
		if ($elems[0] eq $user && $elems[1] eq $cdomain)
		{
			my $usercurrentphpver = $elems[2];
		}
	}

if ($Q->param("sok")) 
{
		my $wrapper = "/var/www/php-bin/$user/php-$curdomain";

		#Writing changed setting
        open DATA, ">phpchanger/domain.user";
        foreach $row (@rows)
		{
            my @elems = split / /, $row, 3;
            printf DATA "%s", $row if ($elems[1] ne $curdomain);
        }
        printf DATA "%s %s %s\n", $user, $curdomain, $newphp;
        close DATA;

		#wrapping
		my $chphp = "";
		if (!-e $wrapper)
		{
			system ("touch $wrapper");
			system ("chown ".$user.":".$user." $wrapper");
			system ("chmod 0555 $wrapper");
			#my $lfh;
			#open($lfh, '>', $wrapper);
			#close($lfh);
			#my $uid = getpwnam $user;
			#my $gid = getgrnam $user;
			#chown $uid, $gid, $wrapper;
			#chmod 0555, $wrapper;
		}

		if($newphp == 5.3){
			$chphp = 5.3;
			system ("chflags noschg $wrapper");
			system ("echo '$v53' > $wrapper");
			system ("chflags schg $wrapper");
            system ("pkill -9 -u $user");
		}
		if($newphp == 5.4){
			$chphp = 5.4;
			system ("chflags noschg $wrapper");
			system ("echo '$v54' > $wrapper");
			system ("chflags schg $wrapper");
            system ("pkill -9 -u $user");
		}
		if($newphp == 5.5){
			$chphp = 5.5;
			system ("chflags noschg $wrapper");
			system ("echo '$v55' > $wrapper");
			system ("chflags schg $wrapper");
            system ("pkill -9 -u $user");
		}
		if($newphp == 5.6){
			$chphp = 5.6;
			system ("chflags noschg $wrapper");
			system ("echo '$v56' > $wrapper");
			system ("chflags schg $wrapper");
            system ("pkill -9 -u $user");
		}
		if($newphp == 7.0){
			$chphp = 7.0;
			system ("chflags noschg $wrapper");
			system ("echo '$v70' > $wrapper");
			system ("chflags schg $wrapper");
            system ("pkill -9 -u $user");
		}
		# Запишем в лог
		open (MyFile, ">>" , "phpchanger/domain.change") ;
		print MyFile '[' . timestamp() . '] '.$user.' php was changed from '.$usercurrentphpver.' to '.$chphp."\n";
		close MyFile;

		#Getting apache's conf
		my $apacheconf = '/etc/apache2/apache2.conf';
		open(my $fh, '<:encoding(UTF-8)', $apacheconf);		

		#Setting text to replace
		my $newtext = "\n\tOptions +ExecCGI -Includes\n";
		$newtext .= "\tFCGIWrapper "."$wrapper"." .php\n";
		$newtext .= "\tFCGIWrapper "."$wrapper"." .php3\n";
		$newtext .= "\tFCGIWrapper "."$wrapper"." .php4\n";
		$newtext .= "\tFCGIWrapper "."$wrapper"." .php5\n";
		$newtext .= "\tFCGIWrapper "."$wrapper"." .phhtml\n";
		
		#Setting find rule
		my $find = "/var/www/$user/data/www/$curdomain";
		
		#Getting config to a string
		my $str = "";

		while (my $rowa = <$fh>) {
		  chomp $rowa;
		  $str .= "$rowa\n";
		}
		close $fh;
		my $string = $str;
		$string =~ s/(\<Directory $find\>).*?(\<\/Directory\>)/$1$newtext$2/gis;
		
		#backupping apache's config
		system("cp -f /etc/apache2/apache2.conf /usr/local/ispmgr/phpchanger/bkp/".timestamp()."_apache2.conf");
		
		#writing to apache's conf file
		open (MyApache, ">" , "/etc/apache2/apache2.conf");
		print MyApache $string;
		close MyApache;
		
		system('service apache2 reload >/dev/null 2>&1');
		
        print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<doc>\n<ok></ok>\n</doc>\n";
} else {
        #checking for php-cgi 
		($xmldoc, $xmlroot) = Mgr::query ('wwwdomain.edit', [ ['elid', $cdomain] ]);
		my $php_check = XMLin($xmldoc);
		
		#check for disabled domain 
		open DATA, "</usr/local/ispmgr/etc/ispmgr.conf";
		my @ispdomains = <DATA>;
		close DATA;
		
		print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<doc>\n";

		foreach $row (@ispdomains) {
			chomp($row);
			my @elems = split / /, $row, 3;
			if ($elems[0] eq "DisabledWebDomain" && $cdomain eq $elems[1] && "on" eq $elems[2]) {
				print "<error code=\"9\">Сайт отключен. Изменение версии PHP на отключенных сайтах невозможно.</error>\n";
				last;
				exit;
			}
		}
		
		if($php_check->{php} eq "phpmod")
		{
			print "<error code=\"9\">На сайте не включен режим CGI или FastCGI. Пожалуйста, включите режим в настройках WWW - домена.</error>\n";
		}
		
		if(-e "/var/www/php-bin/$user/php-$cdomain")
		{
			foreach $row (@rows) {
				chomp($row);
				my @elems = split / /, $row, 3;
				if ($elems[0] eq $user && $cdomain eq $elems[1]) {
					$elems[2] =~ s/\R//g;
					print "<phpver>$elems[2]</phpver>\n";
					last;
				}
			}
		} else {
			print "<phpver>5.4</phpver>\n";
		}
		print "<domain>$cdomain</domain>\n";
        # Заполняем список возможных версий
        print "<slist name=\"phpver\">\n";
        open WLIST, "<phpchanger/phpver.list";
        my @wlist = <WLIST>;
        close WLIST;
        foreach $phpver (@wlist) {
            my @elems = split / /, $phpver, 2;
        	$elems[0] =~ s/\R//g;
            print "<msg name='$elems[0]'>$elems[0]</msg>\n";
        }
        print "</slist>\n";
        print "</doc>\n";
}
