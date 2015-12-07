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

###################
### USER CONFIG ###
###################

# login information (AizuOnlineJudge)
my $aojLogin = {
	"userID" => "kazsw",
	"password" => ""
};
# login information (AtCoder)
my $acLogin = {
	"name" => "kazsw",
	"password" => ""
};

#####################
### SYSTEM CONFIG ###
#####################

# working directory
my $workDir = "./jun";

# setup job mapping
my %sites = (
	"TokyoTechCoder" => \&_setupTTC,
	"AizuOnlineJudge" => \&_setupAOJ,
	"AtCoder" => \&_setupAC
);

# language definition
my %langs = (
	"C++" => ["C++14", "C++11"],
	"Perl" => ["Perl"]
);
# language extension
my %extension = (
	"C++" => "cpp",
	"Perl" => "pl"
);
# build commands
my %buildCmd = (
	"C++" => sub { "g++", "-std=c++11", "-o", "${workDir}/run.tmp", @_ },
	"Perl" => sub { (&isWin ? "copy" : "cp"), @_, "${workDir}/run.tmp" }
);
# test commands
my %testCmd = (
	"C++" => sub { "${workDir}/run.tmp", "<", @_ },
	"Perl" => sub { "perl", "${workDir}/run.tmp", "<", @_ },
);
# language templates
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

############
### MAIN ###
############

# select job
unless(scalar(@ARGV)){
	die("No job was specified");
}elsif($ARGV[0] eq "setup"){
	&setup(@ARGV[1..$#ARGV]);
}elsif($ARGV[0] eq "make"){
	&make(@ARGV[1..$#ARGV])
}elsif($ARGV[0] eq "test"){
	&test(@ARGV[1..$#ARGV])
}elsif($ARGV[0] eq "submit"){
	&submit(@ARGV[1..$#ARGV])
}

############
### JOBS ###
############

# setup contest
sub setup {
	# prepare working directory
	mkdir($workDir, 0755);
	
	# start setup
	my $mech = getMechanize();
	my $siteName = do {
		my @siteNames = sort(keys(%sites));
		userSelectIfNotMatch(uc(shift || 0), [map { s/[a-z]//gr } @siteNames], "site", \@siteNames);
	};
	$sites{$siteName}->($mech, @_);
	
	# save cookie
	serialize("cookie.txt", $mech->cookie_jar());
	print("* Finished", $/);
}

# setup TokyoTechCoder
sub _setupTTC {
	my $mech = $_[0];
	
	# select contest
	my $contestId = do {
		if($_[1]){
			$_[1];
		}else{
			userSelect("Select contest", do {
				print("* Fetching contest list ...", $/);
				$mech->get("http://ttc.wanko.cc/");
				$_ = $mech->content();
				
				my @contests;
				while(/\/contests\/([^"]+)/g){
					push(@contests, $1);
				}
				@contests[0..($#contests < 4 ? $#contests : 4)];
			});
		}
	};
	
	# get problem list
	print("* Fetching problem list ...", $/);
	$mech->get("http://ttc.wanko.cc/contests/${contestId}");
	$_ = $mech->content();
	
	# get problem info
	unlink("${workDir}/problem.txt");
	while(/\/aoj\/(\d+)/g){
		&_setupAOJ($mech, $1);
	}
}

# setup AizuOnlineJudge
sub _setupAOJ {
	my $mech = $_[0];
	
	# get problem id
	my $problemId = do {
		unless($_[1]){
			print("Input problem ID: ");
			$_[1] = <STDIN>;
			chop($_[1]);
		}
		$_[1];
	};
	
	# get problem info
	print("* Fetching problem aoj${problemId} ...", $/);
	$mech->get("http://judge.u-aizu.ac.jp/onlinejudge/description.jsp?id=${problemId}");
	
	# parse and save test cases
	save("aoj${problemId}", do {
		local $_ = $mech->content();
		
		my @tests;
		while(/<pre>(.+?)<\/pre>/gs){
			push(@tests, $1);
		}
		if(scalar(@tests) % 2){
			shift(@tests);
		}
		
		my %data;
		for(my $i = 1; scalar(@tests);){
			my $in = formatTestCase(shift(@tests));
			my $out = formatTestCase(shift(@tests));
			if($in !~ /<.+>/ && $out !~ /<.+>/){
				$data{"in"}{$i} = $in;
				$data{"out"}{$i++} = $out;
			}
		}
		\%data;
	});
	
	# add submission info to problem.txt
	serialize("problem.txt", do {
		my $problem = do {
			if(-e "${workDir}/problem.txt"){
				deserialize("problem.txt");
			}else{
				{};
			}
		};
		
		unless($mech->content() =~ /[^"]+#submit[^"]+/){
			die("Could not find submit URL");
		}
		$problem->{"aoj${problemId}"} = "http://judge.u-aizu.ac.jp/onlinejudge/${&}";
		$problem;
	});
}

# setup AtCoder
sub _setupAC {
	my $mech = $_[0];
	
	# select contest
	my $url = do {
		"https://" . do {
			if($_[1]){
				$_[1];
			}else{
				userSelect("Select contest", do {
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
			}
		} . ".contest.atcoder.jp";
	};
	
	# login
	print("* Logging in ...", $/);
	$mech->get("${url}/login");
	$mech->submit_form(fields => $acLogin);
	
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
				$data{$1} = formatTestCase($2);
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
sub make {
	# select problem and language
	my $problem = do {
		my @problems = sort(keys(%{deserialize("problem.txt")}));
		userSelectIfNotMatch(uc(shift || 0), [map { uc } @problems], "problem", \@problems);
	};
	my $language = do {
		my @languages = sort(keys(%langs));
		userSelectIfNotMatch(uc(shift || 0), [map { uc } @languages], "language", \@languages);
	};
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
	print($fileName);
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
					"------- INPUT --------", $/,
					$testCases->{"in"}->{$_}, $/,
					"------ EXPECTED ------", $/,
					$expected, $/,
					"------- ACTUAL -------", $/,
					$actual, $/,
					"----------------------"
				);
				
				if(($actual =~ s/\s//gr) eq ($expected =~ s/\s//gr)){
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
	
	# prepare mechanize
	my $mech = getMechanize();
	
	# open result on browser
	Browser::Open::open_browser(do {
		if($url =~ /judge\.u-aizu\.ac\.jp\//){
			# get language name
			my $langName = eval {
				print("Fetching language list ...", $/);
				$mech->get($url);
				$_ = $mech->content();
				
				foreach my $target (@{$langs{$lang}}){
					$target = quotemeta($target);
					if(/"(${target})"/){
						return $1;
					}
				}
				die("Could not find language name");
			};
			# submit code
			print("Submitting source code ...", $/);
			$mech->post("http://judge.u-aizu.ac.jp/onlinejudge/webservice/submit", {
				"language" => $langName,
				"lessonID" => "",
				"problemNO" => sprintf("%04d", $url =~ s/^.+(\d+)$/$1/r),
				"sourceCode" => readFile($_[0]),
				%$aojLogin
			});
			sleep(1);
			
			# find submission detail page
			print("Finding submission ...", $/);
			$mech->get("http://judge.u-aizu.ac.jp/onlinejudge/status.jsp");
			unless($mech->content() =~ /rid=(\d+).+?\s+.+$aojLogin->{"userID"}/){
				die("Could not find submission");
			}
			"http://judge.u-aizu.ac.jp/onlinejudge/review.jsp?rid=${1}#2";
		}elsif($url =~ /contest\.atcoder\.jp\//){
			# get language id
			my $taskId = do {
				$url =~ /\d+$/;
				$&;
			};
			my $langId = eval {
				print("Fetching language list ...", $/);
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
			};
			
			# submit code
			print("Submitting source code ...", $/);
			$mech->submit_form(fields => {
				"source_code" => readFile($_[0]),
				"language_id_${taskId}" => $langId
			});
			
			# find submission detail
			unless($mech->content() =~ /\/submissions\/\d+/){
				die("Could not find submission");
			}
			$_ = $&;
			$url =~ s/(atcoder\.jp\/).+$/$1$_/r;
		}else{
			die("Could not find submission-method");
		}
	});
}

###################
### SUBROUTINES ###
###################

# get mechanize instance
sub getMechanize {
	my $mech = WWW::Mechanize->new();
	if(-e "${workDir}/cookie.txt"){
		$mech->cookie_jar(deserialize("cookie.txt"));
	}
	$mech;
}

# ask user to select something
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

# ask user when user-specified selection is not found
sub userSelectIfNotMatch {
	if($_[0]){
		for(my $i=0; $i<scalar(@{$_[1]}); $i++){
			if($_[0] eq $_[1]->[$i]){
				return $_[3]->[$i];
			}
		}
		die("No such ${_[2]}");
	}
	userSelect($_[2], @{$_[3]});
}

# format test case
sub formatTestCase {
	($_[0] =~ s/^\s*(.+?)\s*$/$1\n/sr) =~ s/[\r\n]+/\n/gr;
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
		@_ = map { s/\//\\/gr; } @_;
	}
	system(@_);
}
sub runGetOutput {
	if(&isWin){
		@_ = map { s/\//\\/gr; } @_;
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
