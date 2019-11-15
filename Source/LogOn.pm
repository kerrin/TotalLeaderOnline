#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		LogOn
#-----------------------------------------------------------------------------
# Description:
# 					This module is used to allow members to log on
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2003/10/19 13:45:35 $
# $Revision: 1.6 $
#-----------------------------------------------------------------------------
package TotalLeader::Source::LogOn;
use strict;

my $project_path;
BEGIN
{
	unless($project_path = $ENV{'PROJECT_PATH'})
	{
		confess('Set enviroment variable PROJECT_PATH to the project path');
	}
	eval "use lib '$project_path';";
	
	# And associated package defaults
	use vars qw(@ISA @EXPORT);
	@ISA = qw(SWS::Source::FormBase TotalLeader::Source::CommonTools);
	@EXPORT = qw();
}

use SWS::Source::FormBase;
use SWS::Source::Log;
use SWS::Source::Config;
use SWS::Source::Error;
use SWS::Source::Database;
use SWS::Source::Constants;
use TotalLeader::Source::CommonTools;

sub TEMPLATE() { 'log_on.html' };

#-----------------------------------------------------------------------------
# Function: 	new
#-----------------------------------------------------------------------------
# Description:
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Arguments					IN:0	The arguments for all modules
#-----------------------------------------------------------------------------
sub new
{
	my $prototype 	= shift;
	my $config 		= $_[0];
	my $args 		= $_[1];

	# Get back the correct object name
	my $class = ref($prototype) || $prototype;
	
	# Call the base class to initialise basic elements
	my $self = $class->SUPER::new(@_);
	
	# And return the database enabled base object
	return $self;
}

#-----------------------------------------------------------------------------
# Function: 	setup_tmpl_vars
#-----------------------------------------------------------------------------
# Description:
# 					returns the site Identifier that invoked us
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
#-----------------------------------------------------------------------------
sub setup_tmpl_vars
{
	my $self 	=	shift;

}


#-----------------------------------------------------------------------------
# Function: 	event_LogOn
#-----------------------------------------------------------------------------
# Description:
# 					returns the site Identifier that invoked us
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Next Action				OUT:0	The module name to run next or undef for none
# Next Actions ArgumentsOUT:1	The arguments to pass to the next modules new
#-----------------------------------------------------------------------------
sub event_LogOn
{
	my $self 	=	shift;

   $self->debug(8, 'LogOn::event_LogOn');

   my $username = $self->{'cgi_vars'}->{'username'};
   my $password = $self->{'cgi_vars'}->{'password'};
   # Clear this out or it appears in the state as plain text
   delete $self->{'cgi_vars'}->{'username'};
   delete $self->{'cgi_vars'}->{'password'};
   $self->debug(8, "Log on member " . $username);

   my ($error_code, $member_ID) = 
      $self->authenticate_member($username,$password);
   $self->debug(8, "Results $error_code," . ($member_ID||'none'));
   
   if($error_code)
   {
      print "Error:$error_code\n";
      if($error_code == ERROR_INVALID_USER)
      {
         $self->event('User logon failed for member ' . $username);
         $self->{'tmpl_vars'}->{'error_message'} = 'Log on failed';
         return;
      } else {
         $self->throw_error($error_code, 'Error loging on');
      }
   }
   
   return ('Welcome',undef);
}

1;
