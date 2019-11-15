#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		Technology
#-----------------------------------------------------------------------------
# Description:
# 					This module is used to allow members to log on
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2004/09/02 17:02:41 $
# $Revision: 1.5 $
#-----------------------------------------------------------------------------
package TotalLeader::Source::Technology;
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
use TotalLeader::Source::Constants;
use TotalLeader::Source::CommonTools;

my $fields =
   {

   };
sub FIELDS() { $fields; };

sub TEMPLATE() { 'technology.html' };

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
# Function: 	check_cgi_vars
#-----------------------------------------------------------------------------
# Description:
# 					Used to check the cgi variables are as expected
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0	The return code, 0 for ok, ERROR_CHECK_FAIL
#-----------------------------------------------------------------------------
#sub check_cgi_vars
#{
#	my $self 	=	shift;
#
#   $self->debug(8, 'Technology::check_cgi_vars');
#
#	return $self->SUPER::check_cgi_vars(@_); 
#}

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

   $self->debug(8, 'Technology::setup_tmpl_vars');
   
   my $tech_loop = TECH_TREE;
   my $game_ID = $self->{'cgi_vars'}->{'game_ID'} || 0;
   my $member_ID = $self->logged_on();
   my $player_ID = $self->get_player_ID($member_ID,$game_ID);

   foreach my $tech (@{$tech_loop})
   {
      next unless($tech->{'ID'});
      my $details = $self->get_technology_details($tech->{'ID'});
      if(defined($details))
      {
         $tech->{'name'} = $details->{'name'};
         $tech->{'description'} = $details->{'description'};
         $tech->{'tech_points'} = $details->{'tech_points'};
         $tech->{'require_ID'} = $details->{'require_ID'};
         $tech->{'image'} = $details->{'image'};
         if(!$tech->{'require_ID'} ||
            $self->player_has_technology($player_ID,$tech->{'require_ID'}))
         {
            $tech->{'can_get'} = 1;
         }
      }
      if($self->player_has_technology($player_ID,$tech->{'ID'}))
      {
         $tech->{'has'} = 1;
      } elsif($self->player_getting_technology($player_ID,$tech->{'ID'}))
      {
         $self->debug(8, "Player $player_ID getting " . $tech->{'ID'});
         $tech->{'getting_this'} = 1;
         $self->{'tmpl_vars'}->{'getting'} = 1;
      }
   }

   $self->{'tmpl_vars'}->{'tech_loop'} = $tech_loop;
   
   $self->populate_summary($game_ID, $player_ID);

   # Clear this out or it appears in the state as plain text
   #   $self->move_from_cgi_vars_to_tmpl_vars(
#        [],
#      OVERWRITE_MOVE_ANYWAY);
}

#-----------------------------------------------------------------------------
# Function: 	start_research
#-----------------------------------------------------------------------------
# Description:
# 					registers a user
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0	The return code
# Game ID               IN:0  The game this is for
# Player ID             IN:1  The player this is for
# Technology ID         IN:2  The technology to start research of
# Technology Points     IN:3  The technology points required to research
#-----------------------------------------------------------------------------
sub start_research
{
	my $self 	      =	shift;
   my $game_ID       = $_[0];
   my $player_ID     = $_[1];
   my $tech_ID       = $_[2];
   my $tech_points   = $_[3];
   $self->debug(8, 'Technology::start_research');

   my $insert_details = {
      'game_ID'         => $game_ID,
      'game_player_ID'  => $player_ID,
      'technology_ID'   => $tech_ID,
      'tech_points'     => $tech_points
   };
   return $self->db_insert($self->config('game_player_technology_link_table'),
                           $insert_details);
}

#-----------------------------------------------------------------------------
# Function:    populate_summary
#-----------------------------------------------------------------------------
# Description:
#              Populates the summary template variables
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0
# Game ID               IN:0  The Game ID to look up
# Player ID             IN:1  The Player ID to lookup
#-----------------------------------------------------------------------------
sub populate_summary
{
   my $self       =  shift;
   my $game_ID       = $_[0] || $self->{'cgi_vars'}->{'game_ID'};
   my $player_ID     = $_[1];
   unless(defined($player_ID))
   {
      my $member_ID = $self->logged_on();
      $player_ID = $self->get_player_ID($member_ID,$game_ID);
   }

   $self->debug(8, "Technology->populate_summary ($game_ID,$player_ID)");
   my $tmpl_vars = $self->{'tmpl_vars'};

   my ($error_code, $details) = $self->db_select(
      'get_game_player_quick_lookup_details',
      {'game_player_quick_lookup' => $self->config('game_player_quick_lookup_table')},
      $game_ID, $player_ID);
   if($error_code)
   {
      $self->throw_error($error_code,
         'Select error in "Technology->populate_summary for Player ID ' .
         $player_ID);
   }
   if(defined($details))
   {
      $tmpl_vars->{'tech_points'} = $details->[0]->{'science_per_turn'};
   } else {
      $tmpl_vars->{'tech_points'} = 0;
   }

   ($error_code, $details) = $self->db_select(
      'find_player_researching_technology',
      {'game_player_technology_link' => $self->config('game_player_technology_link_table')},
      $player_ID);
   if($error_code)
   {
      $self->throw_error($error_code,
         'Select error in "Technology->populate_summary for Player ID ' .
         $player_ID);
   }
   if(defined($details))
   {
      $tmpl_vars->{'current_research_left'} = $details->[0]->{'tech_points'};
      ($error_code, $details) = $self->db_select(
         'get_technology_details',
         {'technology_type_const' => $self->config('technology_type_const_table')},
         $details->[0]->{'technology_ID'});
      if($error_code)
      {
         $self->throw_error($error_code,
            'Select error in "Technology->populate_summary for Player ID ' .
            $player_ID);
      }
      if(defined($details))
      {
         $tmpl_vars->{'current_research'} = $details->[0]->{'name'};
      } else {
         $tmpl_vars->{'current_research'} = 'Unknown';
      }
   } else {
      $tmpl_vars->{'current_research'} = 'None';
      $tmpl_vars->{'current_research_left'} = 0;
   }
   ($tmpl_vars->{'attack_modifier'}, $tmpl_vars->{'defense_modifier'}) = 
      $self->calcualte_fight_modifiers($player_ID,$player_ID);

   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function: 	event_research
#-----------------------------------------------------------------------------
# Description:
# 					registers a user
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Next Action				OUT:0	The module name to run next or undef for none
# Next Actions ArgumentsOUT:1	The arguments to pass to the next modules new
#-----------------------------------------------------------------------------
sub event_research
{
	my $self 	=	shift;

   $self->debug(8, 'Technology::event_research');
   my $tech_ID = $self->{'cgi_vars'}->{'tech_ID'};
   my $game_ID = $self->{'cgi_vars'}->{'game_ID'} || 0;
   my $member_ID = $self->logged_on();
   my $player_ID = $self->get_player_ID($member_ID,$game_ID);
 
   my $getting_ID = $self->player_getting_technology($player_ID);
   if($getting_ID)
   {
      $self->debug(8, "Player $player_ID already researching");
      my $details = $self->get_technology_details($getting_ID);
      if(defined($details))
      {
         $self->{'tmpl_vars'}->{'error_message'} = 
            'You are already reseaching ' . $details->{'name'};
      } else {
         $self->{'tmpl_vars'}->{'error_message'} = 'You are already reseaching';
      }
      return;
   }
   my $details = $self->get_technology_details($tech_ID);
   unless(defined($details))
   {
      $self->{'tmpl_vars'}->{'error_message'} =
         'Error getting technology details, please try again later';
      return;
   }
   $self->debug(8, "Player $player_ID about to research " . $details->{'name'});
   
   my $rc = $self->start_research(
      $game_ID, $player_ID, $tech_ID, $details->{'tech_points'});
   
   $self->{'tmpl_vars'}->{'message'} = 'Reseaching ' . $details->{'name'};
   return;
}

1;
