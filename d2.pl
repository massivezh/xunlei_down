#!/usr/bin/perl
#
use DBI;
use Filesys::Df;
use Proc::ProcessTable;
my $lock_file='/var/lock/download';
my ($id,$filename,$url);
my $d_re=0;
$ds="DBI:mysql:database=lixian;host=localhost";
$user="lixian";
$pass="xiazai";
$SIG{INT}=\&int_handler;

#检查是否是唯一进程
sub chk_uni{
	my $t = new Proc::ProcessTable;
	if (-e $lock_file){

		open lock_f,"$lock_file";
		my $lock_pid=<lock_f>;
		foreach my $p (@{$t->table}){ 
			if ($p->pid == $lock_pid){
				exit;
			}
		}
		close lock_f;
	}
	open lock_f,">$lock_file";
	print lock_f $$;
	close lock_f;
}
#检查剩余磁盘空间
sub chk_space{
	my $ref = df("/down");  # Default output is 1K blocks
		if($ref->{bavail} < 10000){
			print $ref->{bavail}."is less than 10000\n";
			return 0;
		}
	return 1;
}
#开始从数据库提取一条数据下载
sub fetch_data{
	$dbh=DBI->connect($ds,$user,$pass,{'RaiseError'=>1});
	$sth=$dbh->prepare("select id,filename,url from info where stat=\'no\' limit 1")
		or warn "Can't prepare: ", $dbh->errstr;
	$sth->execute
		or warn "Can't execute: ", $dbh->execute;
	$sth->bind_columns(\$id,\$filename,\$url);
	my $db_re=$sth->fetch;
	$sth->finish;
	$dbh->disconnect;
	return $db_re;
}
sub download_file{
	$d_re=system "/usr/bin/wget","-c","--load-cookies","/down/cookies.txt",$url,"-O","unfin/".$filename;
	if(!$d_re){
		$dbh=DBI->connect($ds,$user,$pass,{'RaiseError'=>1});
		$dbh->do("update info set stat=\'yes\' where id=$id");
		print "downloaded $filename\n";
		system "mv","unfin/".$filename, "done/".$filename;
		$dbh->disconnect;
	}
}
sub clean_up{
	$dbh->disconnect;
#删除lock文件
	unlink $lock_file;
}
sub int_handler{
	&clean_up;
	die "interrupted. exiting...\n";
}

&chk_uni;
while(&chk_space && $d_re==0 && &fetch_data){
#SIGINT SIGQUIT are ignore by system(),
	&download_file;
}
&clean_up;
