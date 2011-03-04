#!/usr/bin/perl
#

use URI;
use URI::Escape;
use DBI;
use HTTP::Cookies;
use HTTP::Headers;
use LWP::UserAgent;
use HTTP::Request;
use Data::Dumper;
use Digest::MD5 qw(md5 md5_hex md5_base64);

$x_id='迅雷号';
$x_pass='迅雷的密码';
#下面的userid需要抓包看一下，每个人不一样


if ($ARGV[0]=~/^\d+$/){
	$pagecnt=$ARGV[0];
}
else {
	$pagecnt=1;
}

#set cookie file
my $cookie_jar = HTTP::Cookies->new(
		file => "lwp_cookies.dat",
		autosave => 1,
		ignore_discard => 1
		);
#不写ignore_discard => 1,脚本退出后会把cookies文件清空




my $ua= LWP::UserAgent->new;
$ua->cookie_jar($cookie_jar);

my $response = $ua->get(
		'http://lixian.vip.xunlei.com/task.html',
		);

$response = $ua->get(
		'http://web.stat.xunlei.com//pv?&sd=&vb=&vd=1&dm=xunlei.com&ul=http%3A%2F%2Flixian.vip.xunlei.com%2Ftask.html&vc=0&st=&co=24&jv=&fv=10.1&ru=136600768&os=Win7&br=Firefox%2F3.6.13&ln=zh-cn&zn=-8&al=0&tt=%E7%A6%BB%E7%BA%BF%E4%B8%8B%E8%BD%BD%EF%BC%8D%E7%99%BB%E5%BD%95&rf=http%3A%2F%2Flixian.xunlei.com%2F&lul=&pi=100&usr0=&usr1=&usrId=&bfg=1299216505318&pst=0&clp=&_a=&gs=GSID_001_001_001_034&1299216505000'
		);


$response = $ua->get(
		'http://login.xunlei.com/check?&u='.$x_id.'&cachetime='.time(),
		);

##($version,$val,$port,$path_spec,$secure,$expires,$discard
##所以取数组[1]为所存内容
		$c=$cookie_jar->{COOKIES}{'.xunlei.com'}{'/'}{'check_result'}[1];
		$c=~ m/:(.*$)/;
		$c=$1;
		$check_result=uri_escape_utf8($c);


		$u='u='.$x_id;
		$p='p='.md5_hex(md5_hex(md5_hex($x_pass)).$c);
		$v='verifycode='.$check_result;
		$le = 'login_enable=0';
		$lh = 'login_hour=720';
		$data=join '&',$u,$p,$v,$le,$lh;

		my $req = HTTP::Request->new(POST => 'http://login.xunlei.com/sec2login/');
		$req->content_type('application/x-www-form-urlencoded');
		$req->content($data);
		$response = $ua->request($req);

		$time1=time();
$response = $ua->get(
		'http://dynamic.lixian.vip.xunlei.com/login?cachetime='.$time1.'&cachetime='.time().'&from=0',
		);

$response = $ua->get(
		'http://dynamic.lixian.vip.xunlei.com/user_task?userid=107801179&st=0',
		);
$response->content=~/id=\"cok\" value=\"(.*?)\"/;
$gdriveid=$1;
print "gdriveid:$gdriveid\n";

# database initiate
$ds="DBI:mysql:database=lixian;host=localhost";
$user="lixian";
$pass="xiazai";
$dbh=DBI->connect($ds,$user,$pass,{'RaiseError'=>1});
$sth=$dbh->prepare("INSERT IGNORE INTO info SET filename=?,url=?,size=?");



for($i = 1; $i <= $pagecnt; $i++) {
	$url='http://dynamic.lixian.vip.xunlei.com/user_task?userid=107801179&st=0&p='.$i;

	$cnt=0;
	$total=0;
	$response = $ua->get($url);
	$html=$response->content;
	my @ids;
	while($html =~ /dcid(\d+)/g){
		push @ids,$1;
	}
	foreach $id (@ids){
		$html =~/taskname$id.*?value=\"(.*?)\"/;
		my $filename=$1;

		$html =~/dl_url$id.*?value=\"(.*?)\"/;
		my $dl_url=$1;

		$html =~/size$id\">(.*?)</;
		my $size=$1;

		$n=$sth->execute($filename,$dl_url,$size);
		if($n > 0){
			$cnt+=1;
		}
		$total+=1;
	}

	print "the $i page:$cnt / $total inserted!\n";
}
$sth->finish();
$dbh->disconnect();


$cookie_jar->saveN("cookies.txt");

open ck,">>cookies.txt";
print ck ".vip.xunlei.com	TRUE	/	FALSE	0	gdriveid	$gdriveid";
close ck;
