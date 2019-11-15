#-----------------------------------------------------------------------------
# Module: 		ViewMessage
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
package TotalLeader::Source::ViewMessage;
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
   };

sub FIELDS() { $fields; };

sub TEMPLATE() { 'view_message.html' };

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
# Function: 	post_check_module_setup
#-----------------------------------------------------------------------------
# Description:
# 					Used to setup the module after any checks are performed
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# NONE
#-----------------------------------------------------------------------------
sub post_check_module_setup
{
	my $self 	=	shift;

   $self->debug(8, 'ViewSquare::post_check_module_setup');
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

   $self->debug(8, 'ViewMessage::setup_tmpl_vars');
   my $tmpl_vars = $self->{'tmpl_vars'};

   if(exists($tmpl_vars->{'no_previous_message'}))
   {
      if(exists($self->{'cgi_vars'}->{'to_player_ID'}) && 
         $self->{'cgi_vars'}->{'to_player_ID'} != 0)
      {
         $tmpl_vars->{'new_message_member_ID'} = $self->get_member_ID($self->{'cgi_vars'}->{'to_player_ID'});
      } else {
         $tmpl_vars->{'new_message_member_ID'} = $self->{'cgi_vars'}->{'to_member_ID'};
      }
      my $member_details = $self->member_details($tmpl_vars->{'new_message_member_ID'});
      $tmpl_vars->{'send_to_name'} = $member_details->{'screen_name'};
   } else {
      my $tables = {
         'message'  => $self->config('message_table'),
         'member'    => $self->config('member_table'),
         'game'      => $self->config('game_table')
      };
      my $member_ID = $self->logged_on();
      my $message_ID = $self->{'cgi_vars'}->{'message_ID'};
      unless($message_ID)
      {
         $self->throw_error(ERROR_INVALID_PARAMETER, "No message ID");
      }
      my ($error_code, $details) = $self->db_select('get_message',
         $tables,
         $message_ID);
      if($error_code)
      {
         $self->throw_error($error_code,
                           "Select error in ViewMessage->setup_tmpl_vars");
      }
      if($details && @{$details})
      {
         $tmpl_vars->{'game_name'} = $details->[0]->{'game_name'} || 'None';
         if(exists($details->[0]->{'been_read'}) && $details->[0]->{'been_read'} >= 1)
         {
            $tmpl_vars->{'been_read'} = 1;
         } else {
            $self->set_read_message($message_ID);
         }
         if(exists($details->[0]->{'replied'}) && $details->[0]->{'replied'} >= 1)
         {
            $tmpl_vars->{'replied'} = 1;
         }
         if($details->[0]->{'from_member_ID'} == ADMIN_USER)
         {
            $details->[0]->{'admin_message'} = 1;
         }
         $tmpl_vars->{'from_screen_name'} = $details->[0]->{'from_screen_name'};
         $tmpl_vars->{'send_to_name'} = $details->[0]->{'from_screen_name'};
         $tmpl_vars->{'sent_date_time'} = $details->[0]->{'sent_date_time'};
         $tmpl_vars->{'subject'} = $details->[0]->{'subject'};
         $tmpl_vars->{'message'} = $details->[0]->{'message'};
         $tmpl_vars->{'new_message_member_ID'} = $details->[0]->{'from_member_ID'};
      }
   }
   
   # Clear this out or it appears in the state as plain text
   $self->move_from_cgi_vars_to_tmpl_vars(
      ['message_ID','reply_subject','reply_message'], OVERWRITE_DELETE_ONLY);
}

#-----------------------------------------------------------------------------
# Function: 	event_SendMessage
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
sub event_SendMessage
{
	my $self 	=	shift;

   $self->debug(8, 'ViewMessage::event_SendMessage');

   my $cgi_vars = $self->{'cgi_vars'};
   my $member_ID = $self->logged_on();
   my $to_member_ID = $cgi_vars->{'to_member_ID'};
   my $send_subject = $cgi_vars->{'send_subject'};
   my $send_message = $cgi_vars->{'send_message'};
   my $game_ID = $self->{'cgi_vars'}->{'game_ID'} || 0;
   my $message_ID = $self->{'cgi_vars'}->{'message_ID'} || 0;

   my $insert_details = {
         'from_member_ID'  => $member_ID,
         'to_member_ID'    => $to_member_ID,
         'game_ID'         => $game_ID,
         'subject'         => $send_subject,
         'message'         => $send_message

      };
   my ($error_code, $board_ID) = $self->db_insert(
         $self->config('message_table'), $insert_details);

   if($message_ID)
   {
      $self->set_replied_message($message_ID);
   }
   $self->{'tmpl_vars'}->{'no_previous_message'} = 1;

   return ('Messages',undef);
}

#-----------------------------------------------------------------------------
# Function: 	event_NewMessage
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
sub event_NewMessage
{
	my $self 	=	shift;

   $self->debug(8, 'ViewMessage::event_NewMessage');

   $self->{'tmpl_vars'}->{'no_previous_message'} = 1;
   return; 
}


1;
