package WeBWorK::ContentGenerator::Instructor;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Instructor - Abstract superclass for the Instructor pages

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::DB::Utils qw(global2user initializeUserProblem);

sub hiddenEditForUserFields {
	my ($self, @editForUser) = @_;
	my $return = "";
	foreach my $editUser (@editForUser) {
		$return .= CGI::input({type=>"hidden", name=>"editForUser", value=>$editUser});
	}
	
	return $return;
}

sub userCountMessage {
	my ($self, $count, $numUsers) = @_;
	
	my $message;
	if ($count == 0) {
		$message = CGI::em("no users");
	} elsif ($count == $numUsers) {
		$message = "all users";
	} elsif ($count == 1) {
		$message = "1 user";
	} elsif ($count > $numUsers || $count < 0) {
		$message = CGI::em("an impossible number of users: $count out of $numUsers");
	} else {
		$message = "$count users";
	}
	
	return $message;
}

### Utility functions for assigning sets to users.
# These silently fail if the problem or set exists for the user.

sub assignProblemToUser {
	my ($self, $user, $globalProblem) = @_;
	my $db = $self->{db};
	my $userProblem = $db->{problem_user}->{record}->new;

	# Set up the key
	$userProblem->user_id($user);
	$userProblem->set_id($globalProblem->set_id);
	$userProblem->problem_id($globalProblem->problem_id);
	
	initializeUserProblem($userProblem);
	eval {$db->addUserProblem($userProblem)};
	warn $@ if $@ and not $@ =~ m/user problem exists/;
}

sub assignSetToUser {
	my ($self, $user, $globalSet) = @_;
	my $db = $self->{db};
	my $userSet = $db->{set_user}->{record}->new;
	my $setID = $globalSet->set_id;

	$userSet->user_id($user);
	$userSet->set_id($setID);
	eval {$db->addUserSet($userSet)};
	warn $@ if $@ and not $@ =~ m/user set exists/;
	
	foreach my $problemID ($db->listGlobalProblems($setID)) {
		my $problemRecord = $db->getGlobalProblem($setID, $problemID);
		$self->assignProblemToUser($user, $problemRecord);
	}
}

# When a new problem is added to a set, all students to whom the set 
# it belongs to is assigned should have it assigned to them.
# Note that this does NOT assign to all users of a course, just all users
# of a set.
sub assignProblemToAllSetUsers {
	my ($self, $globalProblem) = @_;
	my $db = $self->{db};
	my $setID = $globalProblem->set_id;
	my @users = $db->listSetUsers($setID);
	
	foreach my $user (@users) {
		$self->assignProblemToUser($user, $globalProblem);
	}
}

# READ THIS: Unlike the above function, "All" here refers to all of the
# users of a course.
# This function caches database data as a speed optimization.
sub assignSetToAllUsers {
	my ($self, $setID) = @_;
	my $db = $self->{db};
	my @problems = ();
	my @users = $db->listUsers;
	my @problemRecords = map {$db->getGlobalProblem($setID, $_)} $db->listGlobalProblems($setID);
	
	foreach my $user (@users) {
		# FIXME: Create a UserSet record for the user!!!!
		my $userSet = $db->{set_user}->{record}->new;
		$userSet->user_id($user);
		$userSet->set_id($setID);
		eval {$db->addUserSet($userSet)};
		foreach my $problemRecord (@problemRecords) {
			$self->assignProblemToUser($user, $problemRecord);
		}
	}
}

sub read_dir {  # read a directory
	my $self      = shift;
	my $directory = shift;
	my $pattern   = shift;
	my @files = grep /$pattern/, WeBWorK::Utils::readDirectory($directory); 
	return sort @files;
}

sub read_scoring_file    { # used in SendMail and ....?
	my $self            = shift;
	my $fileName        = shift;
	my $delimiter       = shift;
	$delimiter          = ',' unless defined($delimiter);
	my $scoringDirectory= $self->{ce}->{courseDirs}->{scoring};
	my $filePath        = "$scoringDirectory/$fileName";  
        #       Takes a delimited file as a parameter and returns an
        #       associative array with the first field as the key.
        #       Blank lines are skipped. White space is removed
    my(@dbArray,$key,$dbString);
    my %assocArray = ();
    local(*FILE);
    if ($fileName eq 'None') {
    	# do nothing
    } elsif ( open(FILE, "$filePath")  )   {
		my $index=0;
		while (<FILE>){
			unless ($_ =~ /\S/)  {next;}               ## skip blank lines
			chomp;
			@{$dbArray[$index]} =$self->getRecord($_,$delimiter);
			$key    =$dbArray[$index][0];
			$assocArray{$key}=$dbArray[$index];
			$index++;
		}
		close(FILE);
     } else {
     	warn "Couldn't read file $filePath";
     }
     return \%assocArray;
}
## Template Escapes ##

sub links {
 	my $self 		= shift;
#  	FIXME these links are being placed in ContentGenerator.pm
#  	
#  	my $pathString 	= "";
#  	
# 	
# 	my $ce = $self->{ce};
# 	my $db = $self->{db};
# 	my $userName = $self->{r}->param("user");
# 	my $courseName = $ce->{courseName};
# 	my $root = $ce->{webworkURLs}->{root};
# 	my $permLevel = $db->getPermissionLevel($userName)->permission();
# 	my $key = $db->getKey($userName)->key();
# 	return "" unless defined $key;
# 	
# 	# new URLS
# 	my $classList	= "$root/$courseName/instructor/users/?". $self->url_authen_args();
# 	my $addStudent  = "$root/$courseName/instructor/addStudent/?". $self->url_authen_args();
# 	my $problemSetList = "$root/$courseName/instructor/sets/?". $self->url_authen_args();
# 	
# 	if ($permLevel > 0 ) {
# 		$pathString .="<hr>";
# 		$pathString .=  CGI::a({-href=>$classList}, "Class&nbsp;editor") . CGI::br();
# 		$pathString .= CGI::a({-href=>$problemSetList}, "Set editor") . CGI::br();
# 	}
	return $self->SUPER::links(); # . $pathString;
}

1;
