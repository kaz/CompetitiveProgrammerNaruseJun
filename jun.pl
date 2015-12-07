use utf8;
use strict;
use warnings;
use Data::Dumper;
use Browser::Open;
use WWW::Mechanize;

###############
### INSTALL ###
###############

# cpan install WWW::Mechanize LWP::Protocol::https Browser::Open

##############
### CONFIG ###
##############

# login information
my $login = {
	"name" => "kazsw",
	"password" => ""
};

# working directory
my $workDir = "./jun";

my %langs = (
	"C++" => ["C++14", "C++11"],
	"Perl" => ["Perl"]
);
my %extension = (
	"C++" => "cpp",
	"Perl" => "pl"
);
my %buildCmd = (
	"C++" => sub { "g++", "-std=c++11", "-o", "${workDir}/run.tmp", @_ },
	"Perl" => sub { (&isWin ? "copy" : "cp"), @_, "${workDir}/run.tmp" }
);
my %testCmd = (
	"C++" => sub { "${workDir}/run.tmp", "<", @_ },
	"Perl" => sub { "perl", "${workDir}/run.tmp", "<", @_ },
);
my %template = (
#######################################
	"C++" => <<'EOS'
#include <bits/stdc++.h>
using namespace std;

int main(){
	cout << "Hello, world!" << endl;
}
EOS
#######################################
	,"Perl" => <<'EOS'
use utf8;
use strict;
use warnings;

print("Hello, world!", $/);
EOS
#######################################
);

my %sites = (
	"TokyoTechCoder" => \&_setupTTC,
	"AtCoder" => \&_setupAC
);

############
### MAIN ###
############

# select job
if($ARGV[0] eq "setup"){
	&setup;
}elsif($ARGV[0] eq "gen"){
	&gen;
}elsif($ARGV[0] eq "test"){
	&test($ARGV[1]);
}elsif($ARGV[0] eq "submit"){
	&submit($ARGV[1]);
}

############
### JOBS ###
############

# setup contest
sub setup {
	# prepare working directory
	mkdir($workDir, 0755);
	
	# generate mechanize instance
	my $mech = WWW::Mechanize->new();
	
	# setup
	$sites{userSelect("Select site", sort(keys(%sites)))}->($mech);
	
	# save cookie
	serialize("cookie.txt", $mech->cookie_jar());
	print("* Finished", $/);
}

# setup TokyoTechCoder
sub _setupTTC {
	
}

# setup AtCoder
sub _setupAC {
	my $mech = $_[0];
	
	# select contest
	my $url = do {
		my $contestId = userSelect("Select contest", do {
			print("* Fetching contest list ...", $/);
			$mech->get("http://atcoder.jp/");
			unless($mech->content() =~ /次回コンテスト<\/h3>(.+?)<h3>/s){
				die("Could not find contest list");
			}
			$_ = $1;
			
			my @contests;
			while(/\/\/([^.]+)\.contest/g){
				push(@contests, $1);
			}
			@contests;
		});
		"https://${contestId}.contest.atcoder.jp";
	};
	
	# login
	print("* Logging in ...", $/);
	$mech->get("${url}/login");
	$mech->submit_form(fields => $login);
	
	# save problem info
	serialize("problem.txt", do {
		print("* Fetching problem list ...", $/);
		$mech->get("${url}/assignments");
		$_ = $mech->content();
		
		my @tasks;
		while(/tasks\/([^"]+)/g){
			unless(grep {$_ eq $1} @tasks){
				push(@tasks, $1);
			}
		}
		
		unless(scalar(@tasks)){
			die("Could not find problem list");
		}
		
		my $parse = sub {
			my %data;
			while($_[0] =~ /${_[1]}例\s*(\d+)(?:.|\s)+?<pre.*?>((?:.|\s)+?)<\/pre>/g){
				my $ref = \$data{$1};
				$$ref = $2;
				$$ref =~ s/^\s*(.+?)\s*$/$1\n/s;
				$$ref =~ s/[\r\n]+/\n/g;
			}
			\%data;
		};
		
		my %problem;
		foreach(@tasks){
			print("* Fetching problem ${_} ...", $/);
			$mech->get("${url}/tasks/${_}");
			unless($mech->content() =~ /[^"]+task_id[^"]+/){
				die("Could not find submit URL (${_})");
			}
			$problem{$_} = $url . $&;
			
			save($_, {
				"in" => $parse->($mech->content(), "入力"),
				"out" => $parse->($mech->content(), "出力")
			});
		}
		\%problem;
	});
}

# create source file
sub gen {
	# select problem and language
	my $problem = userSelect("Select problem", sort(keys(%{deserialize("problem.txt")})));
	my $language = userSelect("Select language", sort(keys(%langs)));
	my $fileName = "./${problem}.${extension{$language}}";
	
	# ask if file exists
	if(-e $fileName){
		print("Overwrite? (y/n): ");
		$_ = <STDIN>;
		unless(/y/i){
			return;
		}
	}
	
	# create
	writeFile($fileName, $template{$language});
}

# test program
sub test {
	# guess problem and language
	my($testCases, $lang) = parse($_[0]);
	unless($testCases = load($testCases)){
		die("Could not find test case");
	}
	
	# compile
	print("Compiling program ...", $/);
	if(runGetStatusCode($buildCmd{$lang}->($_[0]))){
		die("Compile failed");
	}
	
	# test
	foreach(sort(keys(%{$testCases->{"in"}}))){
		print($/, "#${_}: ");
		print(do {
			writeFile("${workDir}/test.tmp", $testCases->{"in"}->{$_});
			my $actual = runGetOutput($testCmd{$lang}->("${workDir}/test.tmp"));
			my $expected = $testCases->{"out"}->{$_};
			$actual =~ s/[\r\n]+/\n/g;
			$expected =~ s/[\r\n]+/\n/g;
			
			if($?){
				"[RuntimeError]";
			}elsif($actual eq $expected){
				"[Accepted]";
			}else{
				my @report = (
					"------ EXPECTED ------", $/,
					$expected, $/,
					"------- ACTUAL -------", $/,
					$actual, $/,
					"----------------------"
				);
				
				$actual =~ s/\s//g;
				$expected =~ s/\s//g;
				if($actual eq $expected){
					("[PresentaionError]", $/, @report);
				}else{
					("[WrongAnswer]", $/, @report);
				}
			}
		}, $/);
	}
	
	# delete temp file
	unlink("${workDir}/test.tmp");
	unlink("${workDir}/run.tmp");
}

# submit source code
sub submit {
	# guess problem and language
	my($url, $lang) = parse($_[0]);
	unless($url = deserialize("problem.txt")->{$url}){
		die("Could not find problem ID");
	}
	my $taskId = do {
		$url =~ /\d+$/;
		$&;
	};
	
	# prepare mechanize
	my $mech = WWW::Mechanize->new();
	$mech->cookie_jar(deserialize("cookie.txt"));
	
	# submit code
	print("Submitting source code ...", $/);
	$mech->submit_form(fields => {
		"source_code" => readFile($_[0]),
		"language_id_${taskId}" => eval {
			$mech->get($url);
			unless($mech->content() =~ /selector-${taskId}(.+?)<\/select>/s){
				die("Could not find language list");
			}
			$_ = $1;
			
			my %langIds;
			while(/value="(\d+)">(.+)</g){
				$langIds{$2} = $1;
			}
			
			foreach my $target (@{$langs{$lang}}){
				$target = quotemeta($target);
				foreach(keys(%langIds)){
					if(/^${target}/){
						return $langIds{$_};
					}
				}
			}
			die("Could not find language ID");
		}
	});
	
	# open result on browser
	Browser::Open::open_browser(do {
		unless($mech->content() =~ /\/submissions\/\d+/){
			die("Could not submission");
		}
		$_ = $&;
		$url =~ s/(atcoder\.jp\/).+$/$1$_/;
		$url;
	});
}

###################
### SUBROUTINES ###
###################

# selecting something subroutine
sub userSelect {
	print($/);
	
	for(my $i=1; $i<scalar(@_); $i++){
		print($i, ": ", $_[$i], $/);
	}
	
	print($/, $_[0], ": ");
	my $select = <STDIN>;
	chop($select);
	
	if($select =~ /^\d+$/){
		unless($select = $_[$select]){
			die("No such option");
		}
	}
	$select;
}

# parse file name
sub parse {
	(do {
		unless($_[0] =~ /([^\/\\]+?)\..+?$/){
			die("Could not find problem name");
		}
		$1;
	}, do {
		unless($_[0] =~ /\.(.+?)$/){
			die("Could not find extension");
		}
		my @langs = grep { $extension{$_} eq $1 } keys(%extension);
		$langs[0];
	});
}

# check operating system
sub isWin {
	$^O =~ /win/i;
}

# execute external program
sub runGetStatusCode {
	if(&isWin){
		@_ = map { s/\//\\/g; $_; } @_;
	}
	system(@_);
}
sub runGetOutput {
	if(&isWin){
		$_[0] =~ s/\//\\/g;
	}
	local $_ = join(" ", @_);
	`$_`;
}

# file IO subroutine
sub writeFile {
	open(FILE, ">${_[0]}");
	binmode(FILE);
	print(FILE $_[1]);
	close(FILE);
}
sub readFile {
	local $/;
	unless(open(FILE, "<${_[0]}")){
		die("Could not open ${_[0]}");
	}
	binmode(FILE);
	$/ = <FILE>;
	close(FILE);
	$/;
}

# test case serializing subroutine
sub save {
	mkdir("${workDir}/${_[0]}");
	for my $type (keys(%{$_[1]})){
		for(keys(%{$_[1]->{$type}})){
			writeFile("${workDir}/${_[0]}/${type}_${_}.txt", $_[1]->{$type}->{$_});
		}
	}
}
sub load {
	my $dir = "${workDir}/$_[0]";
	unless(opendir(DIR, $dir)){
		die("Could not open ${dir}");
	}
	my %data;
	while($_ = readdir(DIR)){
		if(/^(.+)_(.+)\.txt$/){
			$data{$1}{$2} = readFile("${dir}/${_}");
		}
	}
	closedir(DIR);
	\%data;
}

# variable serializing subroutine
sub serialize {
	writeFile("${workDir}/${_[0]}", Dumper($_[1]));
}
sub deserialize {
	my $VAR1;
	eval(readFile("${workDir}/${_[0]}"));
}
