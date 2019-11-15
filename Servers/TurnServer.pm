#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		TurnServer
#-----------------------------------------------------------------------------
# Description:
# 					This module is a test server, used to demostrate a simple
# 					server
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2004/09/02 17:00:50 $
# $Revision: 1.16 $
#-----------------------------------------------------------------------------
package TotalLeader::Servers::TurnServer;
use strict;

use Time::HiRes qw(gettimeofday tv_interval);

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
	@ISA = qw(SWS::Source::ServerBase TotalLeader::Source::CommonTools);
	@EXPORT = qw();
}

use SWS::Source::ServerBase;
use SWS::Source::Error;
use SWS::Source::CommonTools;
use TotalLeader::Source::CommonTools;
use TotalLeader::Source::Constants;

#-----------------------------------------------------------------------------
# Function: 	new
#-----------------------------------------------------------------------------
# Description:
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
#
#-----------------------------------------------------------------------------
sub new
{
	my $prototype 	= shift;
	my $config 		= $_[0];
	my $args 		= $_[1];

   die('No server') unless(exists($args->{'server'}));
	# Get back the correct object name
	my $class = ref($prototype) || $prototype;
	
	# Call the base class to initialise basic elements
	my $self = $class->SUPER::new(@_);

	# And return the database enabled base object
	return $self;
}

#-----------------------------------------------------------------------------
# Function: 	prepolling
#-----------------------------------------------------------------------------
# Description:
# 					Performs the event, checks for shutdown, and sleeps
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
#-----------------------------------------------------------------------------
sub prepolling
{
	my $self 	=	shift;

   $self->debug(8, 'TotalLeader::turnServer->prepolling()');

   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function: 	perform_events
#-----------------------------------------------------------------------------
# Description:
# 					Performs the event, checks for shutdown, and sleeps
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
#-----------------------------------------------------------------------------
sub perform_events
{
	my $self 	=	shift;
   $self->debug(8, 'TotalLeader::turnServer->perform_events()');

   my $frequency = $self->config('perforn_event_frequency');
   unless(exists($self->{'last_run'}))
   {
      $self->{'last_run'} = [ gettimeofday() ];
      $self->{'last_run'}->[0] -= $frequency;
   }
   
   if(tv_interval($self->{'last_run'}) < $frequency)
   {
      return ERROR_NONE;
   }

   # Time to run our events
   # First we store the time, so we know next time
   $self->{'last_run'} = [ gettimeofday() ];
   
   eval
   {
      # First task is to start games
      $self->start_pending_games();
   };
   if($@)
   {
      $self->error(ERROR_SEVERITY_WARNING,ERROR_RUNTIME_ERROR, 'start_pending_games failed:' . $@);
   }
   
   eval
   {
      # Secondly we run the turns
      $self->run_pending_turns();
   };
   if($@)
   {
      $self->error(ERROR_SEVERITY_WARNING,ERROR_RUNTIME_ERROR, 'run_pending_turns failed:' . $@);
   }
   
   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function: 	start_pending_games
#-----------------------------------------------------------------------------
# Description:
# 					Start any pending games
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
#-----------------------------------------------------------------------------
sub start_pending_games
{
	my $self 	=	shift;
   $self->debug(8, 'TotalLeader::turnServer->start_pending_games()');
   
   my @time = gmtime(time);
   my $now = sprintf("%04d-%02d-%02d %02d:%02d:%02d",
               $time[5]+1900,$time[4]+1,$time[3],$time[2],$time[1],$time[0]);
   # Get the game IDs for all games that need starting
   my ($error_code, $games) = $self->db_select(
         'get_games_pending_starting_now',
         {'game' => $self->config('game_table')},
         $now);
   if($error_code)
   {
      $self->throw_error($error_code,
         'Select error in TurnServer->start_pending_games');
   }
   unless(defined($games))
   {
      $games = [];
   }

   $self->debug(8, 'We have found ' . @{$games} . ' pending start');
   # For each game
   foreach my $this_game (@{$games}) 
   {
      my $game_ID = $this_game->{'ID'};
      my $players = $this_game->{'players'};
      # Check we have enough players
      unless($self->check_and_update_number_of_players($game_ID,$players))
      {
         # Not enough players, so move on
         $self->debug(7, "Game $game_ID does not have enough players $players");
         next;
      }

      # Get game details
      my $game_details = $self->get_game_details($game_ID);
      next unless(defined($game_details));
      my $height = $game_details->{'height'};
      my $width = $game_details->{'width'};
      
      # Get player start information
      my $player_details;
      ($error_code, $player_details) = $self->db_select(
            'get_game_pending_start_details',
            {'pending_game_player_start' => 
               $self->config('pending_game_player_start_table')},
            $game_ID);
      if($error_code)
      {
         $self->throw_error($error_code,
            'Select error in TurnServer->start_pending_games');
      }
      unless(defined($player_details))
      {
         $self->debug(8, 'TurnServer->start_pending_games, No results');
         next;
      }
      
      my @pending_IDs;
      my $colour_ID = 1;
      foreach my $this_player (@{$player_details})
      {
         my $player_ID = $this_player->{'game_player_ID'};
         my $across = $this_player->{'across'};
         my $down = $this_player->{'down'};

         # Add bases at player starts
         $error_code = $self->add_expansion_to_square(
                           $game_ID, EXPANSION_TYPE_BASE, $across, $down);

         # Update all owned spaces to be 9 units
         my @cross = $self->get_cross_axis($down,$across,$height,$width);
         foreach (@cross)
         {
            $self->debug(9, 'Setting units to 9 for ' . $_->{'column'} .
               ' across and ' . $_->{'row'} . ' down in game ' . $game_ID);
            $error_code = $self->set_units($game_ID, 9, 
               $_->{'column'},$_->{'row'});
            if($error_code)
            {
               $self->error(ERROR_SEVERITY_WARNING,$error_code, 'set_units');
            }
         }

         # Assign player colour and create player look up entry
         $self->start_player($game_ID, $player_ID, $colour_ID);

         $colour_ID++;
         $self->debug(8, 'Added player ' . $player_ID);
         push @pending_IDs, $player_ID;
      }

      # Clean up the pending starts table
      # Due to the use of the IN function, we are by passing the delete
      if(@pending_IDs)
      {
         my $table = $self->config('pending_game_player_start_table');
         my $query = "DELETE FROM $table WHERE game_player_ID IN (" . 
            join(',',@pending_IDs) . ')';
         $self->debug(8, 'Deleting pending using:' . $query);
         my @values = ();
         my ($error_code,undef) = $self->run_query($query);
         if($error_code)
         {
            $self->throw_error($error_code,
               'Delete error in Board->set_pending_start');
         }
         $self->debug(8, 'Deleted ok');
      }

      # Update the turn and next turn values of the game entry
      $self->next_turn($game_ID);
   }

   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function: 	start_player
#-----------------------------------------------------------------------------
# Description:
# 					Sets up the player, at the start of a game
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 The return code
# Game ID               IN:0  The game the player is in
# Player ID             IN:1  The player to set up
# Colour                IN:2  The players colour
#-----------------------------------------------------------------------------
sub start_player
{
	my $self 	   =	shift;
   my $game_ID    = $_[0];
   my $player_ID  = $_[1];
   my $colour     = $_[2];

   $self->debug(8, 'TotalLeader::turnServer->start_player()');
   
   my $insert_details = {
      'game_ID'            => $game_ID,
      'game_player_ID'     => $player_ID,
      'units'              => (9*5),
      'science_per_turn'   => 1,
      'squares'            => 5
   };
   my ($error_code, $board_ID) = $self->db_insert(
         $self->config('game_player_quick_lookup_table'), $insert_details);
   return $error_code if $error_code;

   # Set the colour
   my $update =
      {
         'colour_ID'  => $colour
      };
   $error_code = $self->db_update(
      $self->config('game_player_table'), $update, { 'ID'    => $player_ID});
   
   return $error_code if($error_code);
   
   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function: 	check_and_update_number_of_players
#-----------------------------------------------------------------------------
# Description:
# 					Check the number of players is high enough.
# 					If the number of players is not the requested amount, set the
# 					maximum to the actual amount
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Enough Players        OUT:0 1 if enough players for game, 0 if not
# Game ID               IN:0  The game to check for enough players
# Requested Players     IN:1  The requested number of players to start
#-----------------------------------------------------------------------------
sub check_and_update_number_of_players
{
	my $self 	=	shift;
   my $game_ID = $_[0];
   my $players = $_[1];

   $self->debug(8, 'TotalLeader::turnServer->check_and_update_number_of_players()');
   
   my ($error_code, $details) = $self->db_select(
      'get_number_of_players_in_game',
      {'pending_game_player_start' => 
         $self->config('pending_game_player_start_table')},
      $game_ID);
   if($error_code)
   {
      $self->throw_error($error_code,
         'Select error in TurnServer->check_and_update_number_of_players');
   }
   unless(defined($details) && @{$details} > 0)
   {
      $self->throw_error(ERROR_DB_RESULTS, 'Error counting players');
   }

   if($details->[0]->{'number'} < 2)
   {
      # Not enough players, so disable it
      $self->debug(8, 'Not enough players (' . $details->[0] . 
         '), so disable it');
      my $update =
         {
            'done'  => 1
         };
      $error_code = $self->db_update($self->config('game_table'), $update,
         { 'ID'    => $game_ID});
      
      if($error_code)
      {
         $self->throw_error($error_code,
            "Update error in Board->check_and_update_number_of_players disable game on too few players");
      }
      
      return 0;
   }
   
   # Check for fewer playes
   if($details->[0]->{'number'} < $players)
   {
      # Less players, but enough, so update the number of players
      $self->debug(8, 'Less players (' . $details->[0]->{'number'} . 
         '), so reduce it');
      my $update =
         {
            'players'  => $details->[0]->{'number'}
         };
      $error_code = $self->db_update($self->config('game_table'), $update,
         { 'ID'    => $game_ID});
      
      if($error_code)
      {
         $self->throw_error($error_code,
            "Update error in Board->check_and_update_number_of_players reduce players");
      }
   }
   return 1;
}

#-----------------------------------------------------------------------------
# Function: 	run_pending_turns
#-----------------------------------------------------------------------------
# Description:
# 					Performs the event, checks for shutdown, and sleeps
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
#-----------------------------------------------------------------------------
sub run_pending_turns
{
	my $self 	=	shift;
   $self->debug(8, 'TotalLeader::turnServer->run_pending_turns()');
   
   # Check for a game we have half processed, and finish running if one found
   $self->run_partial_processed();
   
   my @time = gmtime(time);
   my $now = sprintf("%04d-%02d-%02d %02d:%02d:%02d",
               $time[5]+1900,$time[4]+1,$time[3],$time[2],$time[1],$time[0]);
   # Get the game IDs for all games that have ticked
   my ($error_code, $games) = $self->db_select(
         'get_games_pending_turns_now',
         {'game' => $self->config('game_table')},
         $now);
   if($error_code)
   {
      $self->throw_error($error_code,
         'Select error in TurnServer->run_pending_turns');
   }
   unless(defined($games))
   {
      $games = [];
   }

   # For each game
   foreach my $this_game (@{$games}) 
   {
      my $error_code = $self->run_game_turn($this_game);
   }

   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function: 	run_partial_processed
#-----------------------------------------------------------------------------
# Description:
# 					Checks for a partially processed game, and if it finds one,
# 					finishes processing it.
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
#-----------------------------------------------------------------------------
sub run_partial_processed
{
	my $self 	=	shift;

   $self->debug(8, 'TotalLeader::turnServer->run_partial_processed()');
   # Check the processing details table
   my ($error_code, $processing) = $self->db_select(
         'get_processing_details',
         {'processing_details' => $self->config('processing_details_table')});
   if($error_code)
   {
      $self->throw_error($error_code,
         'Select error in TurnServer->run_pending_turns');
   }
   unless(defined($processing))
   {
      $processing = [{'ID' => 1, 'game_ID' => 0, 'stage' => PROCESS_STAGE_NONE}];
   }
   
   # If we found a game, get it's details, and finish processing it
   if($processing->[0]->{'game_ID'} > 0)
   {
      my $game_ID = $processing->[0]->{'game_ID'};
      my $stage = $processing->[0]->{'stage'};
      
      $self->debug(8, "Found game $game_ID at stage $stage of processing");
      my $game_details = $self->get_game_details($game_ID);
      unless(defined($game_details))
      {
         $self->throw_error($error_code,
            'Select error in TurnServer->run_pending_turns');
      }

      $error_code = $self->run_game_turn($game_details,$stage);
   }
   
   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function: 	run_game_turn
#-----------------------------------------------------------------------------
# Description:
# 					Performs the event, checks for shutdown, and sleeps
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
#-----------------------------------------------------------------------------
sub run_game_turn
{
	my $self 	=	shift;
   my $this_game = $_[0];
   my $process_stage = $_[1] || PROCESS_STAGE_NONE;

   $self->debug(8, "TotalLeader::turnServer->run_game_turn(game,$process_stage)");
   my $game_ID = $this_game->{'ID'};
   my $players = $this_game->{'players'};
   my $height = $this_game->{'height'};
   my $width = $this_game->{'width'};
   my $max_turns = $this_game->{'max_turns'};
   my $turn = $this_game->{'turn'};
   my $turn_frequency_hours = $this_game->{'turn_frequency_hours'};
   my $turn_start_time = $this_game->{'turn_start_time'};
   my $turn_stop_time = $this_game->{'turn_stop_time'};

   if($process_stage == PROCESS_STAGE_NONE || 
      $process_stage == PROCESS_STAGE_MOVING_PENDING_UNITS)
   {
      # Remove the used units from the board, and put on pending move board
      $self->move_pending_units($game_ID);
      $process_stage = PROCESS_STAGE_MOVED_PENDING_UNITS;
   }
   
   if($process_stage == PROCESS_STAGE_MOVED_PENDING_UNITS)
   {
      # Reduce scouts
      $self->db_update($self->config('square_effect_details_table'),
                        {'#turns_left' => 'turns_left - 1'},
                        {'game_ID' => $game_ID,
                         '^turns_left' => 0});
      # Increase units on squares with scounts on
      $self->adjust_units_with_effect($game_ID,EFFECT_TYPE_SCOUT,1);
      # Decrease units on squares with kamakazi scouts on
      $self->adjust_units_with_effect($game_ID,EFFECT_TYPE_KAMIKAZE_SCOUT,-1);
      # Remove effects no longer in effect
      $self->db_delete($self->config('square_effect_details_table'),
                                  {'turns_left' => 0});
      
      $process_stage = PROCESS_STAGE_UPDATED_EFFECTS;
      $self->set_processing_details($game_ID,PROCESS_STAGE_UPDATED_EFFECTS);
   }
   my $error_code;
   if($process_stage == PROCESS_STAGE_UPDATED_EFFECTS) 
   {
      # Get the games moves
      my $moves;
      ($error_code, $moves) = $self->db_select(
            'get_game_moves',
            {'game_board_move'   => $self->config('game_board_move_table')},
            $game_ID);
      if($error_code)
      {
         $self->throw_error($error_code,
            'Select error in TurnServer->run_pending_turns');
      }
      unless(defined($moves))
      {
         $moves = [];
      }
      $self->debug(8, 'There are '. @{$moves} . " pending for game $game_ID");
      foreach my $move (@{$moves})
      {
         $self->process_move($game_ID, $move);
      }

      # Check for unused pending units in the PROCESSING_BOARD table
      # Best put them back, and flag as an error
      $error_code = $self->check_processing_details($game_ID);
      
      # Set process stage to PROCESS_STAGE_MOVED_UNITS
      $self->set_processing_details($game_ID,PROCESS_STAGE_MOVED_UNITS);
      $process_stage = PROCESS_STAGE_MOVED_UNITS;
   }
   
   if($process_stage == PROCESS_STAGE_MOVED_UNITS)
   {
      $self->calculate_storms($game_ID);
      $self->calculate_fires($game_ID);
      
      # Set process stage to PROCESS_STAGE_MOVED_UNITS
      $self->set_processing_details($game_ID,PROCESS_STAGE_CALCULATED_RANDOM_EVENTS);
      $process_stage = PROCESS_STAGE_CALCULATED_RANDOM_EVENTS;
   }

   if($process_stage == PROCESS_STAGE_CALCULATED_RANDOM_EVENTS)
   {
      # Put units back on board who were building
      $self->db_update($self->config('game_board_table'),
                        {'units'  => 9},
                        {'game_ID' => $game_ID,
                         'expansion_to_build'  => 1});
      # Move on buildings
      $self->db_update($self->config('game_board_table'),
                        {'#expansion_to_build'  => 'expansion_to_build - 1'},
                        {'game_ID' => $game_ID,
                         '^expansion_to_build'  => 0});
   }
      
   if($process_stage == PROCESS_STAGE_CALCULATED_RANDOM_EVENTS)
   {
      # Update player money, technology, etc
      
      # Get player details
      my $player_details;
      ($error_code, $player_details) = $self->db_select(
            'get_game_player_details',
            {'game_player' => $self->config('game_player_table')},
            $game_ID);
      if($error_code)
      {
         $self->throw_error($error_code,
            'Select error in TurnServer->run_pending_turns');
      }
      unless(defined($player_details))
      {
         $self->throw_error($error_code,
            'Select error in TurnServer->run_pending_turns');
      }

      foreach my $this_player (@{$player_details})
      {
         my $player_ID = $this_player->{'game_player_ID'};

         # Recalculate the quick lookup entry
         my $quicklookup_details;
         ($error_code,$quicklookup_details) = 
                        $self->recalculate_player_quick_lookup(
                                 $game_ID, $this_player->{'player_ID'});

         # Get players technology and advance
         $error_code = $self->calculate_player_technology($quicklookup_details);
         
         # Calculate money income and increase
         $error_code = $self->calculate_player_money($quicklookup_details);
         
         # Calculate recruits, and increase 
         $error_code = $self->calculate_player_recruits($quicklookup_details);
      }

      # Set process stage to PROCESS_STAGE_UPDATED_PLAYER_DETAILS
      $self->set_processing_details($game_ID,
         PROCESS_STAGE_UPDATED_PLAYER_DETAILS);
      $process_stage = PROCESS_STAGE_UPDATED_PLAYER_DETAILS;
   }      
   if($process_stage == PROCESS_STAGE_UPDATED_PLAYER_DETAILS)
   {
      $self->clear_ownerships($game_ID);
      $self->set_processing_details($game_ID,
         PROCESS_STAGE_CLEANUP);
      $process_stage = PROCESS_STAGE_CLEANUP;
   }

   # Move to the next turn
   $self->next_turn($game_ID);
   
   # Set the process stage as done
   $self->set_processing_details(0, PROCESS_STAGE_NONE);
   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function: 	recalculate_player_quick_lookup
#-----------------------------------------------------------------------------
# Description:
# 					Regenerate the players quick lookup details, store and 
# 					return them
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# Details               OUT:1 The updated details
# Game ID               IN:0  The game to work on
# Player ID             IN:1  The player to update
#-----------------------------------------------------------------------------
sub recalculate_player_quick_lookup
{
	my $self 	   = shift;
   my $game_ID  = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Game ID missing in recalculate_player_quick_lookup');
   my $player_ID  = $_[1] || $self->throw_error(ERROR_MISSING_PARAMETER,'player ID missing in recalculate_player_quick_lookup');

   $self->debug(8, "TotalLeader::turnServer->recalculate_player_quick_lookup($game_ID,$player_ID)");
   my ($error_code, $count_details) =
            $self->db_select('get_game_player_counts',
                        {'game_board' => $self->config('game_board_table')},
                        $player_ID, $game_ID);
   
   if($error_code)
   {
      $self->error(ERROR_SEVERITY_WARNING,$error_code,
                  'Select error in Board->recalculate_player_quick_lookup');
      return ($error_code, {});
   }
   if(defined($count_details) && @{$count_details} == 1)
   {
      $count_details = $count_details->[0];
   } else {
      $self->error(ERROR_SEVERITY_WARNING, ERROR_DB_RESULTS,
         'Select error in Board->recalculate_player_quick_lookup no results');
      return (ERROR_DB_RESULTS, {});
   }

   my $science_points = $self->get_player_science_points($game_ID, $player_ID);
   $self->debug(8, "Player $player_ID, Game $game_ID, Squares " . $count_details->{'total_squares'} . ", Science $science_points, Units " . $count_details->{'total_units'});
   my $update =
      { 
         'squares'            => $count_details->{'total_squares'},
         'science_per_turn'   => $science_points,
         'units'              => $count_details->{'total_units'}
      };
   $error_code = $self->db_update(
                        $self->config('game_player_quick_lookup_table'), 
                        $update, 
                        {
                         'game_player_ID' => $player_ID,
                         'game_ID'        => $game_ID
                        }
                     );
   if($error_code)
   {
      $self->error(ERROR_SEVERITY_WARNING,$error_code,
                  'Update error in Board->recalculate_player_quick_lookup');
      return ($error_code,$update);
   }
   
   my  $details =
      {
         'game_ID'            => $game_ID,
         'player_ID'          => $player_ID,
         'squares'            => $count_details->{'total_squares'},
         'science_per_turn'   => $science_points,
         'units'              => $count_details->{'total_units'},
      };
   
   return (ERROR_NONE, $details);
}

#-----------------------------------------------------------------------------
# Function: 	calculate_player_technology
#-----------------------------------------------------------------------------
# Description:
# 					Update the players technology
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# Player Details        IN:0  The players quick look up details
#-----------------------------------------------------------------------------
sub calculate_player_technology
{
	my $self    = shift;
   my $details = $_[0];

   my $game_ID = $details->{'game_ID'};
   my $player_ID = $details->{'player_ID'};
   my $science_per_turn = $details->{'science_per_turn'};
   
   my ($error_code, $tech_details) = $self->db_select(
            'find_player_researching_technology',
            {'game_player_technology_link' => 
                  $self->config('game_player_technology_link_table')},
            $player_ID);
   if($error_code)
   {
      $self->throw_error($error_code,
         'Select error in CommonTools->player_getting_technology for ' .
         "player ID $player_ID");
   }
   my ($tech_ID, $tech_points);
   if(defined($tech_details) && @{$tech_details})
   {
      $tech_ID = $tech_details->[0]->{'ID'};
      $tech_points = $tech_details->[0]->{'tech_points'};
   } else { 
      # Nothing being researched
      return ERROR_NONE;
   }

   $tech_points -= $science_per_turn;
   $tech_points = 0 if($tech_points < 0);
   
   $self->debug(9, "Player $player_ID in game $game_ID, has $tech_points left to research after researching $science_per_turn science (Tech Link $tech_ID)");

   my $update =
      { 
         'tech_points' => $tech_points
      };
   $error_code = $self->db_update(
                        $self->config('game_player_technology_link_table'), 
                        $update, 
                        {
                           'ID'              => $tech_ID,
                           'game_player_ID'  => $player_ID,
                           'game_ID'         => $game_ID
                        }
                     );
   if($error_code)
   {
      $self->error(ERROR_SEVERITY_WARNING,$error_code,
                  'Update error in TurnServer->calculate_player_technology');
      return $error_code;
   }
   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function: 	calculate_player_money
#-----------------------------------------------------------------------------
# Description:
# 					Update the players money
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# Player Details        IN:0  The players quick look up details
#-----------------------------------------------------------------------------
sub calculate_player_money
{
	my $self    = shift;
   my $details = $_[0];

   my $game_ID = $details->{'game_ID'};
   my $player_ID = $details->{'player_ID'};
   my $units = $details->{'units'};
   
   my $money = $units;
   # Calculate modifiers
   # Find out unit count on squares in celebration
   my ($error_code,$celb_squares, $celb_units) = $self->get_effect_count(
         $game_ID,$player_ID,EFFECT_TYPE_CELEBRATION);
   $money += $celb_units; 
   
   # Count units on irrageted squares owned and add to unit count
   my $irragation_units = 
      $self->get_player_irragation_units($game_ID,$player_ID);
   $self->debug(9, "Player $player_ID in game $game_ID, has " .
         "$irragation_units irragation units");
   $money += $irragation_units; 
   
   $self->debug(9, "Player $player_ID in game $game_ID, has gained $money money for having $units units");

   my $update =
      { 
         '#money' => "money + $money"
      };
   $error_code = $self->db_update(
                        $self->config('game_player_table'), 
                        $update, 
                        {
                         'ID'       => $player_ID,
                         'game_ID'  => $game_ID
                        }
                     );
   if($error_code)
   {
      $self->error(ERROR_SEVERITY_WARNING,$error_code,
                  'Update error in TurnServer->calculate_player_recruits');
      return $error_code;
   }
   
   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function: 	calculate_player_recruits
#-----------------------------------------------------------------------------
# Description:
# 					Update the players recruits
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# Player Details        IN:0  The players quick look up details
#-----------------------------------------------------------------------------
sub calculate_player_recruits
{
	my $self    = shift;
   my $details = $_[0];

   my $game_ID = $details->{'game_ID'};
   my $player_ID = $details->{'player_ID'};
   my $squares = $details->{'squares'};
   
   # other modifiers, like expansions, and celebration
   # Count irrageted squares owned and add to square count
   my $irragation_squares = $self->get_player_expansion_counts(
         $game_ID,$player_ID,EXPANSION_TYPE_IRRAGATION);

   $squares += $irragation_squares;
   $self->debug(9, "Player $player_ID in game $game_ID, has " .
         $irragation_squares . ' irragation squares');

   my $player_recruits = int($squares / 5);

   $self->debug(9, "Player $player_ID in game $game_ID, has gained $player_recruits recruits for having $squares squares");

   my $update =
      { 
         '#recruits_left' => "recruits_left + $player_recruits"
      };
   my $error_code = $self->db_update(
                        $self->config('game_player_table'), 
                        $update, 
                        {
                         'ID'       => $player_ID,
                         'game_ID'  => $game_ID
                        }
                     );
   if($error_code)
   {
      $self->error(ERROR_SEVERITY_WARNING,$error_code,
                  'Update error in TurnServer->calculate_player_recruits');
      return $error_code;
   }
   
   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function: 	process_move
#-----------------------------------------------------------------------------
# Description:
# 					Performs the event, checks for shutdown, and sleeps
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
#-----------------------------------------------------------------------------
sub process_move
{
	my $self 	      =	shift;
	my $game_ID       =	$_[0];
	my $move_details 	=	$_[1];
   $self->debug(8, 'TotalLeader::turnServer->process_move()');

   my $from_across = $move_details->{'from_across'};
   my $from_down = $move_details->{'from_down'};
   my $to_across = $move_details->{'to_across'};
   my $to_down = $move_details->{'to_down'};
   my $units = $move_details->{'units'};
   my $move_type_ID = $move_details->{'move_type_ID'};
   
   $self->debug(9, "From: A$from_across,D$from_down To: A$to_across,D$to_down U:$units T:$move_type_ID");
   my $error_code;
   # Get some information about the move and players involved
   my ($current_from_units, $current_from_player);
   ($error_code, $current_from_units, $current_from_player) =
      $self->get_units($game_ID,$from_across,$from_down);
   return $error_code if($error_code);
   my ($current_to_units, $current_to_player);
   ($error_code, $current_to_units, $current_to_player) =
      $self->get_units($game_ID,$to_across,$to_down, 1);
   return $error_code if($error_code);
   my $from_player_details = $self->get_player_details(
                           $game_ID, $current_from_player);
   unless(defined($from_player_details))
   {
      $self->error(ERROR_SEVERITY_ERROR, ERROR_DB_RESULTS, 
         'TurnServer->process_move, move player not found');
      return ERROR_DB_RESULTS;
   }

   if($move_type_ID == MOVE_TYPE_MOVE)
   {
      if($current_to_player == $current_from_player)
      {
         $self->debug(9, "Move in own territory");
         $self->set_units($game_ID, ($current_to_units + $units), 
            $to_across, $to_down);
         # Remove the units from processing_board table
         my $pending_units;
         ($error_code, $pending_units, undef) =
            $self->get_units($game_ID, $from_across, $from_down, 0, 1);
         # Remove the units from processing_board table
         # DONE LATER
         #         $self->set_units($game_ID, ($pending_units - $units), 
         #            $from_across, $from_down, 1);
#      } elsif(ALLIENCE) {
         # Allience
         # ...
      } else {
         # Fight
         $self->debug(9, "Fight between D:$current_to_player and A:$current_from_player");
         my $defend_modifier = 0;
         my $attack_modifier = 0;
         # Check Effects modifiers
         my $effects;
         ($error_code,$effects) = 
            $self->get_square_effects($game_ID, $to_across,$to_down);
         foreach my $this_effect (@{$effects})
         {
            my $effect_type_ID = $this_effect->{'effect_type_ID'};
            if($effect_type_ID == EFFECT_TYPE_FIRE)
            {
               $defend_modifier--;
            } elsif($effect_type_ID == EFFECT_TYPE_STORM) {
               $defend_modifier--;
               $attack_modifier--;
            } elsif($effect_type_ID == EFFECT_TYPE_PLAGUE) {
               $defend_modifier--;
            } elsif($effect_type_ID == EFFECT_TYPE_CELEBRATION) {
               $defend_modifier++;
            } elsif($effect_type_ID == EFFECT_TYPE_PEACE) {
               # No fight
               # Put attacking units back
               $self->set_units($game_ID, $units, $from_across, $from_down);

               # Remove the units from processing_board table
               my $pending_units;
               ($error_code, $pending_units, undef) =
                  $self->get_units($game_ID, $from_across, $from_down, 0, 1);
               $self->set_units($game_ID, ($pending_units - $units), 
                  $from_across, $from_down, 1);
               return ERROR_NONE;
            }
         }

         my $square_details;
         ($error_code, $square_details) = $self->get_square_details(
               $game_ID,$from_across,$from_down);
         return $error_code if($error_code);

         my $attack_land_type = $square_details->{'land_type_ID'};
         my $attack_expansion_type = $square_details->{'expansion_type_ID'};
         my $attack_expansion_hp = $square_details->{'expansion_hp'};

         ($error_code, $square_details) = $self->get_square_details(
               $game_ID,$to_across,$to_down);
         if($error_code)
         {
            # Remove the units from processing_board table
            my $pending_units;
            ($error_code, $pending_units, undef) =
               $self->get_units($game_ID, $from_across, $from_down, 0, 1);
            $self->set_units($game_ID, ($pending_units - $units), 
               $from_across, $from_down, 1);
            return $error_code;
         }

         my $defend_land_type = $square_details->{'land_type_ID'};
         my $defend_expansion_type = $square_details->{'expansion_type_ID'};
         my $defend_expansion_hp = $square_details->{'expansion_hp'};

         $defend_modifier++ if($defend_land_type == LAND_TYPE_MOUNTAIN);
         $attack_modifier++ if($attack_land_type == LAND_TYPE_MOUNTAIN);
         $defend_modifier++ if($defend_land_type == LAND_TYPE_FOREST);
         if($defend_expansion_type == EXPANSION_TYPE_BASE || 
            $defend_expansion_type == EXPANSION_TYPE_FORT)
         {
            $defend_modifier++ 
         }
         if($attack_expansion_type == EXPANSION_TYPE_BASE || 
            $attack_expansion_type == EXPANSION_TYPE_FORT)
         {
            $attack_modifier++ 
         }

         ($attack_modifier, $defend_modifier) = 
            $self->calcualte_fight_modifiers(
               $current_from_player,$current_to_player,
               $attack_modifier, $defend_modifier
            );

         # Minor squares are easier to defend
         $defend_modifier++ unless(($to_across + $to_down) % 2);
         
         $error_code = $self->do_fight($game_ID,$to_across,$to_down, 
            $from_across, $from_down, $current_to_units, $units, 
            $defend_modifier, $attack_modifier, 
            $current_from_player,$current_from_units);
         $self->debug(9, 'Fight done');
      }
   } elsif($move_type_ID == MOVE_TYPE_RECRUIT) {
      my $actual_units;
      $self->debug(9, "Assigning ($current_from_units + $units) recruits on square $to_across, $to_down");
      ($error_code, $actual_units) = 
         $self->set_units($game_ID, ($current_from_units + $units), 
            $to_across, $to_down);
      if($actual_units < ($current_from_units + $units))
      {
         $actual_units -= $current_from_units;
         $self->debug(8, "Unit overflow of $actual_units, on square $to_across, $to_down");
      }
   } elsif($self->move_type_expansion($move_type_ID)) {
      my $expansion_type_ID = $move_type_ID;
      my $details = $self->get_expansion_details($expansion_type_ID);

      my $set_player = 0;
      my $ignore = 0;
      if($move_type_ID == MOVE_TYPE_BRIDGE)
      {
         if($current_to_player == 0 || $current_to_units == 0)
         {
            $set_player = $current_from_player;
         } else {
            $ignore = 1;
            # Put units back
            $self->set_units($game_ID, $units, $from_across, $from_down);
         }
      }
      unless($ignore)
      {
         # Building expansion
         $error_code = 
            $self->add_expansion_to_square($game_ID, $expansion_type_ID, 
               $to_across, $to_down,
               $details->{'turns'},$self->config('expansion_hp'),$set_player);
         if($error_code)
         {
            # Remove the units from processing_board table
            my $pending_units;
            ($error_code, $pending_units, undef) =
               $self->get_units($game_ID, $from_across, $from_down, 0, 1);
            $self->set_units($game_ID, ($pending_units - $units), 
               $from_across, $from_down, 1);
            return $error_code;
         }
      }
   } elsif( $move_type_ID == MOVE_TYPE_FIRE ||
            $move_type_ID == MOVE_TYPE_SCOUT ||
            $move_type_ID == MOVE_TYPE_SUICIDE ||
            $move_type_ID == MOVE_TYPE_KAMIKAZE ||
            $move_type_ID == MOVE_TYPE_PLAGUE ||
            $move_type_ID == MOVE_TYPE_CELEBRATION ||
            $move_type_ID == MOVE_TYPE_PEACE) 
   {
      my $turns = 0;
      my $effect_ID = 0;
      if($move_type_ID == MOVE_TYPE_FIRE) {
         $turns = 1;
         $effect_ID = EFFECT_TYPE_FIRE;
         # Random loss of unit, else give back
         my $random_number = 
            int(rand($self->config('fire_chance_of_starter_loss')));
         $units = 0 unless($random_number); # Don't lose a unit
      } elsif($move_type_ID == MOVE_TYPE_SCOUT) {
         $turns = $units;
         $effect_ID = EFFECT_TYPE_SCOUT;
      } elsif($move_type_ID == MOVE_TYPE_SUICIDE) {
         $turns = $units;
         $effect_ID = EFFECT_TYPE_SUICIDAL_SCOUT;
      } elsif($move_type_ID == MOVE_TYPE_KAMIKAZE) {
         $turns = $units;
         $effect_ID = EFFECT_TYPE_KAMIKAZE_SCOUT;
      } elsif($move_type_ID == MOVE_TYPE_PLAGUE) {
         $turns = $units;
         $effect_ID = EFFECT_TYPE_PLAGUE;
      } elsif($move_type_ID == MOVE_TYPE_CELEBRATION) {
         $turns = 1;
         $effect_ID = EFFECT_TYPE_CELEBRATION;
      } elsif($move_type_ID == MOVE_TYPE_PEACE) {
         $turns = 1;
         $effect_ID = EFFECT_TYPE_PEACE;
      }
      $self->debug(8, "Adding effect $effect_ID to game $game_ID, at A$to_across, D$to_down, owned by $current_from_player, for $turns Turns");
      $self->add_effect_to_square($game_ID, $effect_ID, $to_across, $to_down, 
                                    $current_from_player, $turns);
   } else {
      # Error
      $self->error(ERROR_SEVERITY_ERROR,ERROR_INVALID_PARAMETER,
         "Unknown move type $move_type_ID");
      $error_code = ERROR_INVALID_PARAMETER;
      # Put attacking units back
      $self->set_units($game_ID, $units, $from_across, $from_down);
   }
   
   # Remove move from database
   $error_code = $self->db_delete($self->config('game_board_move_table'),
                                  {'ID' => $move_details->{'ID'}});
   
   # Remove the units from processing_board table
   my $pending_units;
   $self->debug(8, "Removing units from processing ($from_across, $from_down)");
   ($error_code, $pending_units, undef) =
      $self->get_units($game_ID, $from_across, $from_down, 0, 1);
   $self->debug(8, "Was $pending_units, will be " . ($pending_units - $units));
   $self->set_units($game_ID, ($pending_units - $units), $from_across, $from_down, 1);
   
   return $error_code;
}

#-----------------------------------------------------------------------------
# Function:    do_fight
#-----------------------------------------------------------------------------
# Description:
# 					Performs the fight, based on details given
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
#-----------------------------------------------------------------------------
sub do_fight
{
	my $self 	            =	shift;
	my $game_ID             =	$_[0];
	my $to_across           =	$_[1];
	my $to_down             =	$_[2];
	my $from_across         =	$_[3];
	my $from_down           =	$_[4];
	my $defending_units     =	$_[5];
	my $attacking_units     =	$_[6];
	my $defending_modifier  =	$_[7];
	my $attacking_modifier  =	$_[8];
	my $attacking_player_ID =	$_[9];
	my $from_current_units  =	$_[10];

   $self->debug(8, 'TotalLeader::turnServer->do_fight(' . join(',',@_) . ')');

   unless($defending_units > 0)
   {
      $defending_modifier = 0;
   }
   
   my $defending = $defending_units + $defending_modifier;
   my $attacking = $attacking_units + $attacking_modifier;
   my $attacker_win = 0;
   
   # Units can not go below 0
   $defending = 0 if($defending < 0);
   $attacking = 0 if($attacking < 0);
   
   if($attacking > $defending) 
   {
      if($defending == 0 || $defending == 2)
      {
         $defending_units = 0;
         $attacker_win = 1;
      } elsif($defending == 1 || $defending < 0) {
         $attacking_units += 1;
         $defending_units = 0;
         $attacker_win = 1;
      } elsif($defending > 2) {
         $attacking_units -= ($defending-2);
         $attacker_win = 1;
      }
   } elsif($attacking == 1 && $defending > 1) {
      $defending_units += $attacking;
   } elsif($attacking < $defending && $defending > 1) {
      $defending_units  -= ($defending-1);
   } elsif($defending == $attacking) {
      $defending_units = 1 if($defending_units); # Is their real defense is 0
      $attacking_units = 1;
   }
   
   my $update =
      {
         'units' => $defending_units
      };
   if($attacker_win)
   {
      $self->debug(9, 'Attack win, resulting units ' . $defending_units);
      $update = 
      {
         'units'     => $attacking_units,
         'owner_ID'  => $attacking_player_ID
      };
   }
   my $error_code = $self->db_update($self->config('game_board_table'),
                  $update,
                  {  'game_ID'   => $game_ID,
                     'across'    => $to_across,
                     'down'      => $to_down
                  }); 
   return $error_code if($error_code);

   unless($attacker_win)
   {
      my $remaining_units = $attacking_units + $from_current_units;
      $self->debug(9, 'Attack lost, remaining units ' . $remaining_units);
      $update = 
      {
         'units'     => $remaining_units
      };
      $error_code = $self->db_update($self->config('game_board_table'),
                     $update,
                     {  'game_ID'   => $game_ID,
                        'across'    => $from_across,
                        'down'      => $from_down
                     }); 
      return $error_code if($error_code);
   }
   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function:    move_pending_units
#-----------------------------------------------------------------------------
# Description:
# 					Performs the fight, based on details given
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# Game ID               IN:0  The game to move units for
#-----------------------------------------------------------------------------
sub move_pending_units
{
	my $self 	            =	shift;
	my $game_ID             =	$_[0];
   $self->debug(8, 'TotalLeader::turnServer->move_pending_units(' . join(',',@_) . ')');

   # Update Process stage to PROCESS_STAGE_MOVING_PENDING_UNITS
   # And put the game_ID in the table
   $self->set_processing_details($game_ID,PROCESS_STAGE_MOVING_PENDING_UNITS);
 
   my $game_details = $self->get_game_details($game_ID);
   
   $self->debug(9, 'Height: ' . $game_details->{'height'} . ', Width: ' .
      $game_details->{'width'});
   # For all the squares on the board move the units from the board to the
   # processing board table
   for(my $row = 0; $row < $game_details->{'height'}; $row++)
   {
      for(my $col = 0; $col < $game_details->{'width'}; $col++)
      {
         # Check the processing board table to see if we moved units already
         my ($error_code, $details) = $self->db_select(
               'get_processing_board_details',
               {'processing_board' => $self->config('processing_board_table')},
               $col,$row);
         if($error_code)
         {
            $self->error(ERROR_SEVERITY_FATAL,$error_code,
               'Select error in TurnServer->move_pending_units');
         }
         my $units = 0;
         if(defined($details))
         {
            $units = $details->[0]->{'units'};
         }
         # If there are units here, this square has been processed, so passover
         if($units == 0)
         {
            # Calculate units in use from this square
            my $moves;
            ($error_code, $moves) =
               $self->get_square_moves($game_ID, $col, $row);
            if($error_code)
            {
               $self->error(ERROR_SEVERITY_WARNING,$error_code,
                            "Failed to get square moves for game $game_ID, " .
                            "column $col, row $row");
               next;
            }

            my $used_units = 0;
            my $used_units_with_rec = 0;
            foreach my $move (@{$moves})
            {
               if($move->{'from_across'} == $col && 
                  $move->{'from_down'} == $row)
               {
                  if($move->{'move_type_ID'} != MOVE_TYPE_RECRUIT)
                  {
                     $used_units += $move->{'units'};
                  }
                  $used_units_with_rec += $move->{'units'};
               }
            }

            next unless($used_units_with_rec > 0);

            # Move the units to processing board table
            $error_code = $self->db_update($self->config('game_board_table'),
                                          {'#units' => "units - $used_units"},
                                          {'game_ID'   => $game_ID,
                                           'across'    => $col,
                                           'down'      => $row
                                          });
            if($error_code)
            {
               $self->error(ERROR_SEVERITY_WARNING,$error_code,
                               "Failed to update units for game $game_ID, " .
                               "column $col, row $row");
               next;
            }

            $error_code = $self->db_update(
                                 $self->config('processing_board_table'),
                                 {'#units' => "units + $used_units_with_rec"},
                                 {'across'    => $col,
                                  'down'      => $row
                                 });
            if($error_code)
            {
               $self->error(ERROR_SEVERITY_WARNING,$error_code,
                            "Failed to update processing units for " .
                            "column $col, row $row");
               next;
            }
         } else {
            $self->debug(8, "Found $units units for column $col, row $row, while moving pending units");
         }
      }
   }
   
   # Update Process stage to PROCESS_STAGE_MOVED_PENDING_UNITS
   $self->set_processing_details($game_ID,PROCESS_STAGE_MOVED_PENDING_UNITS);
   
   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function:    set_processing_details
#-----------------------------------------------------------------------------
# Description:
#              Updates the processing details table
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code   OUT:0 0 successful, or an error code
# Game ID               IN:0  The game ID to set
# Stage                 IN:1  The stage to set
#-----------------------------------------------------------------------------
sub set_processing_details
{
   my $self    =  shift;
   my $game_ID =  $_[0];
   my $stage   =  $_[1];

   my $error_code = $self->db_update($self->config('processing_details_table'),
                                 {'game_ID' => $game_ID, 'stage' => $stage},
                                 {'ID' => 1});
   
   return $error_code;
}

#-----------------------------------------------------------------------------
# Function:    check_processing_details
#-----------------------------------------------------------------------------
# Description:
#              Checks the processing details table has no units left in
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code   OUT:0 0 successful, or an error code
# Game ID               IN:0  The game we are in, used for error correction
#-----------------------------------------------------------------------------
sub check_processing_details
{
   my $self    =  shift;
   my $game_ID = $_[0];

   $self->debug(8, 'TotalLeader::turnServer->check_processing_details(' . join(',',@_) . ')');

   my ($error_code, $rows) = $self->db_select(
         'check_processing_board_for_units',
         {'processing_board' => $self->config('processing_board_table')});
   return $error_code if($error_code);

   return ERROR_NONE unless(defined($rows) && @{$rows});

   # We found some, we better tidy them up
   $self->error(ERROR_SEVERITY_ERROR, ERROR_RUNTIME_ERROR,
      "Unprocessed units found in game $game_ID. (". @{$rows} .')');
   foreach my $row(@{$rows})
   {
      $self->error(ERROR_SEVERITY_ERROR, ERROR_RUNTIME_ERROR,
         "Putting back $row->{'units'} units for game $game_ID, row " .
            $row->{'down'} . ', col ' . $row->{'across'});
      # Put units back where they came from
      # If ownership has changed, tough!
      $self->set_units($game_ID, $row->{'units'}, 
         $row->{'across'}, $row->{'down'});

      # Remove the units from processing_board table
      $self->set_units($game_ID, 0, $row->{'across'}, $row->{'down'}, 1);
   }
   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function:    calculate_storms
#-----------------------------------------------------------------------------
# Description:
#              Generates and moves storms
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code   OUT:0 0 successful, or an error code
# Game ID               IN:0  The game we are in, used for error correction
#-----------------------------------------------------------------------------
sub calculate_storms
{
   my $self    =  shift;
   my $game_ID = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Game ID missing in calculate storms');

   $self->setup_game_details($game_ID);

   # Move existing storms
   my ($error_code,$effects) = 
      $self->get_effect_squares($game_ID,EFFECT_TYPE_STORM);
   foreach my $this_effect (@{$effects})
   {
      # Remove current storm
      ($error_code) = $self->db_delete(
                                 $self->config('square_effect_details_table'),
                                 {'ID' => $this_effect->{'ID'}});

      my ($row,$column) = (-1,-1);
      my $random_number = int(rand($self->config('storm_chance_move')));
      if($random_number)
      {
         $random_number = int(rand($self->config('storm_chance_stay')));
         unless($random_number)
         {
            # Keep storm
            $row = $this_effect->{'down'};
            $column = $this_effect->{'across'};
         }
      } else {
         # Storm Move in a random direction
         my $rows = $self->{'game_details'}->{'board_rows'};
         my $columns = $self->{'game_details'}->{'board_columns'};
         $row = $this_effect->{'down'} + (int(rand(2)) - 1);
         $column = $this_effect->{'across'} + (int(rand(2)) - 1);
         $row = $rows - 1 if($row < 0);     
         $column = $columns - 1 if($column < 0);     
         $row -= $rows if($row >= $rows);
         $column -= $columns if($column >= $columns);
      }
      if($row >= 0 && $column >= 0)
      {
         $self->add_effect_to_square($game_ID, EFFECT_TYPE_STORM, 
                                    $column, $row, 0, 1);
         # Random damage to expansions
         $random_number = int(rand($self->config('storm_chance_damage')));
         unless($random_number && (($row + $column) % 2) == 1)
         {
            # Damage occurs
            $random_number = int(rand($self->config('storm_max_damage')));
            $self->damage_expansion_on_square(
                  $game_ID, $random_number, $column,$row);
         }
      }
   }

   # Random Storms
   my $random_number = int(rand($self->config('storm_chance')));
   unless($random_number)
   {
      # New storm
      my $rows = $self->{'game_details'}->{'board_rows'};
      my $columns = $self->{'game_details'}->{'board_columns'};
      my $row = int(rand($rows));
      my $column = int(rand($columns));

      $self->add_effect_to_square($game_ID, EFFECT_TYPE_STORM, 
                                 $column, $row, 0, 1);
      # Random damage to expansions
      $random_number = int(rand($self->config('storm_chance_damage')));
      unless($random_number && (($row + $column) % 2) == 1)
      {
         # Damage occurs
         $random_number = int(rand($self->config('storm_max_damage')));
         $self->damage_expansion_on_square(
               $game_ID, $random_number, $column,$row);
      }
   }
}

#-----------------------------------------------------------------------------
# Function:    calculate_fires
#-----------------------------------------------------------------------------
# Description:
#              Generates and moves fires
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code   OUT:0 0 successful, or an error code
# Game ID               IN:0  The game we are in, used for error correction
#-----------------------------------------------------------------------------
sub calculate_fires
{
   my $self    =  shift;
   my $game_ID = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Game ID missing in calculate fires');

   $self->setup_game_details($game_ID);

   # Move existing fires
   my ($error_code,$effects) = 
      $self->get_effect_squares($game_ID,EFFECT_TYPE_FIRE);
   foreach my $this_effect (@{$effects})
   {
      # Remove current fire
      ($error_code) = $self->db_delete(
                                 $self->config('square_effect_details_table'),
                                 {'ID' => $this_effect->{'ID'}});

      my ($row,$column) = (-1,-1);
      my $random_number = int(rand($self->config('fire_chance_move')));
      unless($random_number)
      {
         # Fire Move in a random direction
         my $rows = $self->{'game_details'}->{'board_rows'};
         my $columns = $self->{'game_details'}->{'board_columns'};
         $row = $this_effect->{'down'} + (int(rand(2)) - 1);
         $column = $this_effect->{'across'} + (int(rand(2)) - 1);
         $row = $rows - 1 if($row < 0);     
         $column = $columns - 1 if($column < 0);     
         $row -= $rows if($row >= $rows);
         $column -= $columns if($column >= $columns);
         $self->add_effect_to_square($game_ID, EFFECT_TYPE_STORM, 
                                    $column, $row, 0, 1);
         # Random loss of units
         $random_number = int(rand($self->config('fire_chance_of_unit_loss')));
         unless($random_number)
         {
            # A Units Dies
            my $current_units;
            ($error_code,$current_units) = 
               $self->get_units($game_ID, $row, $column);
            $current_units -= 1;
            if($current_units >= 0)
            {
               $self->set_units($game_ID, $current_units, $row, $column);
            }
         }
      }
      $random_number = int(rand($self->config('fire_chance_stay')));
      unless($random_number)
      {
         # Keep fire
         $row = $this_effect->{'down'};
         $column = $this_effect->{'across'};
         $self->add_effect_to_square($game_ID, EFFECT_TYPE_STORM, 
                                    $column, $row, 0, 1);
         # Random loss of units
         $random_number = int(rand($self->config('fire_chance_of_unit_loss')));
         unless($random_number)
         {
            # A Units Dies
            my $current_units;
            ($error_code,$current_units) = 
               $self->get_units($game_ID, $row, $column);
            $current_units -= 1;
            if($current_units >= 0)
            {
               $self->set_units($game_ID, $current_units, $row, $column);
            }
         }
      }
   }
}

1;
