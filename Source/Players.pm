#-----------------------------------------------------------------------------
# Module: 		Players
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
# $Revision: 1.2 $
#-----------------------------------------------------------------------------
package TotalLeader::Source::Players;
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

sub TEMPLATE() { 'players.html' };

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

   $self->debug(8, 'Players::setup_tmpl_vars');
   
   foreach my $row (@{$self->{'tmpl_vars'}->{'results_loop'}})
   {
   }
   
   # Clear this out or it appears in the state as plain text
   #   $self->move_from_cgi_vars_to_tmpl_vars([''], OVERWRITE_MOVE_ANYWAY);
}

#-----------------------------------------------------------------------------
# Function: 	event_SelectPlayer
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
sub event_SelectPlayer
{
	my $self 	=	shift;

   $self->debug(8, 'Players::event_SelectPlayer');

   my $selected_player_ID = $self->{'cgi_vars'}->{'selected_player_ID'};
   $self->debug(8, 'Selected Player' . $selected_player_ID);
#   $self->{'state'}->{'selected_player_ID'} = $selected_player_ID;

   return ('Players',undef);
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
   $self->debug(8, 'Players::generate_search');

   my ($handle,$variables,@params);
   $variables = {
      'member'                   => $self->config('member_table'),
      'game_player'              => $self->config('game_player_table'),
      'game_player_quick_lookup' => $self->config('game_player_quick_lookup_table'),
      'player_colour'            => $self->config('player_colour_table')
   };
   $handle = 'list_game_players';
   $variables->{'game_ID'} = $self->{'cgi_vars'}->{'game_ID'};
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
   $self->debug(8, 'Players::empty_results');

   return 'No Players Found';
}

1;
