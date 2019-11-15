#-----------------------------------------------------------------------------
# Module: 		Messages
#-----------------------------------------------------------------------------
# Description:
# 					This module is used to display the games searched on
# 					This takes in a flag for displaying games belonging to the
# 					current member
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2004/09/04 21:28:17 $
# $Revision: 1.1 $
#-----------------------------------------------------------------------------
package TotalLeader::Source::Messages;
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
	@ISA = qw(SWS::Source::ResultBase TotalLeader::Source::CommonTools);
	@EXPORT = qw();
}

use SWS::Source::ResultBase;
use SWS::Source::Log;
use SWS::Source::Config;
use SWS::Source::Error;
use SWS::Source::Database;
use SWS::Source::Constants;
use TotalLeader::Source::CommonTools;
use TotalLeader::Source::Constants;

sub TEMPLATE() { 'messages.html' };

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
# 					Used to fill out the tmpl_vars
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# NONE
#-----------------------------------------------------------------------------
sub setup_tmpl_vars
{
	my $self 	=	shift;

   $self->debug(8, 'Messages::setup_tmpl_vars');
   
   foreach my $row (@{$self->{'tmpl_vars'}->{'results_loop'}})
   {
      if(!exists($row->{'game_name'}))
      {
         $row->{'game_name'} = "None";
      }
      if(exists($row->{'been_read'}) && $row->{'been_read'} < 1)
      {
         delete $row->{'been_read'};
      }
      if(exists($row->{'replied'}) && $row->{'replied'} < 1)
      {
         delete $row->{'replied'};
      }
      if($row->{'from_member_ID'} == ADMIN_USER)
      {
         $row->{'admin_message'} = 1;
      }
   }
   
   # Clear this out or it appears in the state as plain text
   #   $self->move_from_cgi_vars_to_tmpl_vars([''], OVERWRITE_MOVE_ANYWAY);
}

#-----------------------------------------------------------------------------
# Function: 	event_Delete
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
sub event_Delete
{
	my $self 	=	shift;

   $self->debug(8, 'Messages::event_Delete');

   my $member_ID = $self->logged_on();
   my $message_ID = $self->{'cgi_vars'}->{'message_ID'};
   $self->debug(8, 'Delete Message ' . $message_ID);

   my $error_code = $self->db_update($self->config('message_table'), 
                     {'deleted' => 1}, 
                     {'ID' => $message_ID, 
                      'to_member_ID' => $member_ID});
   if($error_code)
   {
      $self->error(ERROR_SEVERITY_WARNING,$error_code,'Update failed');
   }

   return ('Messages',undef);
}

#-----------------------------------------------------------------------------
# Function:    generate_search
#-----------------------------------------------------------------------------
# Description:
#              Used to generate the search variables
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Response Code         OUT:0 0 successful, or an error code
# Handle                OUT:1 The search query handle
# Variables             OUT:2 The replacement variables hash
# Parameters            OUT:3 The queries parameters
#-----------------------------------------------------------------------------
sub generate_search
{
   my $self = shift;
   $self->debug(8, 'Messages::generate_search');

   my ($handle,$variables,@params);
   $variables = {
      'message'  => $self->config('message_table'),
      'member'    => $self->config('member_table'),
      'game'      => $self->config('game_table')
   };
   $handle = 'list_member_messages';
   $variables->{'member_ID'} = $self->logged_on();
   $self->debug(8, 'Searching with query handle ' . $handle);

   return (ERROR_NONE,$handle,$variables,@params);
}

#-----------------------------------------------------------------------------
# Function:    empty_results
#-----------------------------------------------------------------------------
# Description:
#              Used to return the message to display if no results are found
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Message               OUT:0 The message to set if no results found
#-----------------------------------------------------------------------------
sub empty_results
{
   my $self = shift;
   $self->debug(8, 'Messages::empty_results');

   return 'No Messages Found';
}

1;
