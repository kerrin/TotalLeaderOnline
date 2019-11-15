#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		Activate
#-----------------------------------------------------------------------------
# Description:
# 					This module encompasses access to all the other modules. 
# 					All non-core modules will inherit from this.
# 					This provides debug, error, and event logs, with access to 
# 					creating additional logs
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2003/09/27 14:32:03 $
# $Revision: 1.1 $
#-----------------------------------------------------------------------------
package TotalLeader::Source::Activate;
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
use TotalLeader::Source::Constants;

my $fields =
   {
      'check'           => {'type' => FIELD_TYPE_STRING,'required' => 1,
                           'display_name' => 'Checksum'},
      'member_ID'          => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 1,'required' => 1,
                           'display_name' => 'Member Identifier'},

   };
sub FIELDS() { $fields; };
sub TEMPLATE() { 'activate.html' };

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
# Function:    check_cgi_vars
#-----------------------------------------------------------------------------
# Description:
#              Used to check the cgi variables are as expected
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 The return code, 0 for ok, ERROR_CHECK_FAIL
#-----------------------------------------------------------------------------
sub check_cgi_vars
{
   my $self    =  shift;

   $self->debug(8, 'Activate::check_cgi_vars');

   my $return_code = $self->SUPER::check_cgi_vars(@_);
   return $return_code if($return_code);
   my $vars = $self->{'cgi_vars'};
   unless(exists($vars->{'event'}) && $vars->{'event'} eq 'Activate')
   {
      $self->{'tmpl_vars'}->{'error_message'} = 'Invalid activation';
      return ERROR_CHECK_FAIL;
   }
   
   my $member_ID = $vars->{'member_ID'};
   my $check = $vars->{'check'};
   delete $vars->{'check'};
   my $member_ID_check;
   ($return_code, $member_ID_check) = $self->generate_md5($member_ID);
   return $return_code if($return_code);

   unless($member_ID_check eq $check)
   {
      $self->{'tmpl_vars'}->{'error_message'} = 'Checksum mismatch';
      $return_code = ERROR_CHECK_FAIL;
   }
   
   return $return_code;
}

#-----------------------------------------------------------------------------
# Function: 	setup_tmpl_vars
#-----------------------------------------------------------------------------
# Description:
# 					Sets up any tmpl vars required
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
# Function:    event_Activate
#-----------------------------------------------------------------------------
# Description:
#              activates a user
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Next Action           OUT:0 The module name to run next or undef for none
# Next Actions ArgumentsOUT:1 The arguments to pass to the next modules new
#-----------------------------------------------------------------------------
sub event_Activate
{
   my $self    =  shift;

   $self->debug(8, 'Activate::event_Activate');

   my $member_ID = $self->{'cgi_vars'}->{'member_ID'};
   delete $self->{'cgi_vars'}->{'member_ID'};
   my ($error_code, $details) = $self->db_select(
      'get_inactive_member',
      {'member' => $self->config('member_table')},
      $member_ID, MEMBER_STATE_REGISTERED);
   if($error_code)
   {
      $self->throw_error($error_code,
         "Select error in Activate->event_Activate");
   }
   unless(defined($details) && @{$details} == 1)
   {
      $self->{'tmpl_vars'}->{'error_message'} = 
         'That account cannot be activated, it may have been already';
      return;
   }
   my $update =
      {
         'state_ID'  => MEMBER_STATE_ENABLED
      };
   $error_code = $self->db_update($self->config('member_table'), $update,
      {'ID' => $member_ID});
   if($error_code)
   {
      $self->throw_error($error_code,
         "Update error in Activate->event_Activate");
   }

   $self->{'tmpl_vars'}->{'message'} = 'Account activated successfully';
   return;
}
1;
