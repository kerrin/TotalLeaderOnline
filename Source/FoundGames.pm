#-----------------------------------------------------------------------------
# Module: 		FoundGames
#-----------------------------------------------------------------------------
# Description:
# 					This module is used to display the games searched on
# 					This takes in a flag for displaying games belonging to the
# 					current member
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2004/09/11 12:44:59 $
# $Revision: 1.6 $
#-----------------------------------------------------------------------------
package TotalLeader::Source::FoundGames;
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

sub TEMPLATE() { 'found_games.html' };

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

   $self->debug(8, 'FoundGames::setup_tmpl_vars');
   
   foreach my $row (@{$self->{'tmpl_vars'}->{'results_loop'}})
   {
      if($row->{'done'} == 1 || $row->{'turn'} > $row->{'max_turns'})
      {
         $row->{'turn'} = 'Done';
      }
      if($row->{'frequency_weekday_type_ID'} == FREQUENCY_TYPE_ALL)
      {
         $row->{'frequency_weekday_name'} = 'All';
      } elsif($row->{'frequency_weekday_type_ID'} == FREQUENCY_TYPE_WEEKDAYS) {
         $row->{'frequency_weekday_name'} = 'Weekdays';
      } elsif($row->{'frequency_weekday_type_ID'} == FREQUENCY_TYPE_WEEKENDS) {
         $row->{'frequency_weekday_name'} = 'Weekends';
      }
      my $hour_lookup =
            { 1 => '1 hour',
            2 => '2 hours',
            3 => '3 hours',
            6 => '6 hours',
            12 => '12 hours',
            24 => '1 day',
            48 => '2 days',
            72 => '3 days',
            96 => '4 days',
            120 => '5 days',
            144 => '6 days',
            168 => '1 week'};
       $row->{'frequency_name'} = 
         $hour_lookup->{$row->{'turn_frequency_hours'}};
   }
   
   # Clear this out or it appears in the state as plain text
   #   $self->move_from_cgi_vars_to_tmpl_vars([''], OVERWRITE_MOVE_ANYWAY);
}

#-----------------------------------------------------------------------------
# Function: 	event_SelectGame
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
sub event_SelectGame
{
	my $self 	=	shift;

   $self->debug(8, 'FoundGames::event_SelectGame');

   my $game_ID = $self->{'cgi_vars'}->{'game_ID'};
   $self->debug(8, 'Selected Game ' . $game_ID);
   $self->{'state'}->{'game_ID'} = $game_ID;

   return ('Board',undef);
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
   $self->debug(8, 'FoundGames::generate_search');

   my ($handle,$variables,@params);
   $variables = {
      'game'  => $self->config('game_table')
   };
   if($self->{'cgi_vars'}->{'my_games'})
   {
      $handle = 'my_games';
      delete($self->{'cgi_vars'}->{'my_games'});
      push @params, $self->logged_on();
      push @params, $self->logged_on();
      $variables->{'game_player'} = $self->config('game_player_table');
   } else {
      $handle = 'find_games';
      $variables->{'search_params'} = 
         'start_date_time > NOW() ORDER BY start_date_time';
   }
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
   $self->debug(8, 'FoundGames::empty_results');

   return 'No Games Found';
}

1;
