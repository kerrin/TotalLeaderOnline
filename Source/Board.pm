#-----------------------------------------------------------------------------
# Module: 		Board
#-----------------------------------------------------------------------------
# Description:
# 					This module is used to display the games searched on
# 					This takes in a flag for displaying games belonging to the
# 					current member
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2004/09/02 13:56:07 $
# $Revision: 1.27 $
#-----------------------------------------------------------------------------
package TotalLeader::Source::Board;
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
use TotalLeader::Source::Constants;
use TotalLeader::Source::CommonTools;

sub TEMPLATE() { 'board.html' };

my $show_rows;
my $show_columns;

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

   my $land_type;
   my $effect_type;
   my $expansion_type;
   my $owner;

   $self->debug(8, 'Board::setup_tmpl_vars');

   my @action_type = (
            {'ID' => ACTION_TYPE_MOVE_VIEW, 'name' => 'Move View'}
         );

   my ($open_game, $my_game, $pending_game) = $self->check_game_details();
   if($open_game)
   {
      # Open Game
      $self->debug(8, 'Open Game');
      push @action_type, {'ID' => ACTION_TYPE_SELECT_START, 'name' => 'Start'};
   } elsif($my_game) {
      # Started game that member is in
      $self->debug(8, 'My Game');
      push @action_type,{'ID' => ACTION_TYPE_VIEW, 'name' => 'View'};
   }
   $self->create_drop_down_from_array(
      'action_type', $self->{'cgi_vars'}->{'action_type'}, @action_type);

   my ($error_code, $details) = $self->db_select('get_land_details',
      {'land_type_const' => $self->config('land_type_const_table')});
   if($error_code)
   {
      $self->throw_error($error_code,
         "Select error in Board->setup_tmpl_vars");
   }
   foreach my $row (@{$details})
   {
      my $temp = {'major' => $row->{'image'}, 
                  'minor' => 'small_' . $row->{'image'}};   
      $land_type->{$row->{'ID'}} = $temp;
   }
   $self->debug(8,'Land Types');   
   $self->debug_dumper(8,$land_type);   

   my $game_ID = $self->{'cgi_vars'}->{'game_ID'} || 0;
   ($error_code, $details) = $self->db_select('get_owner_details',
      {'game_player'    => $self->config('game_player_table'),
       'player_colour'  => $self->config('player_colour_table')},
      $game_ID);
   if($error_code)
   {
      $self->throw_error($error_code,
         "Select error in Board->setup_tmpl_vars");
   }
   my $member_ID = $self->logged_on();
   my $player_ID = $self->get_player_ID($member_ID,$game_ID);
   foreach my $row (@{$details})
   {
      $self->debug(9,
         'Setting owner ' . $row->{'ID'} . ' to colour ' . $row->{'image'});   
      $owner->{$row->{'ID'}} = $row->{'image'};
   }
   $self->debug(8,'Owner');   
   $self->debug_dumper(8,$owner);   

   ($error_code, $details) = $self->db_select('get_expansion_details',
      {'expansion_type_const' => $self->config('expansion_type_const_table')});
   if($error_code)
   {
      $self->throw_error($error_code,
         "Select error in Board->setup_tmpl_vars");
   }
   foreach my $row (@{$details})
   {
      $expansion_type->{$row->{'ID'}} = $row->{'image'};
   }
   $self->debug(8,'Expansion Types');   
   $self->debug_dumper(8,$expansion_type);   

   ($error_code, $details) = $self->db_select('get_effect_details',
      {'effect_type_const' => $self->config('effect_type_const_table')});
   if($error_code)
   {
      $self->throw_error($error_code,
         "Select error in Board->setup_tmpl_vars");
   }
   foreach my $row (@{$details})
   {
      $effect_type->{$row->{'ID'}} = $row->{'image'};
   }
   $self->debug(8,'Effect Types');   
   $self->debug_dumper(8,$effect_type);   

   my $results = $self->{'tmpl_vars'}->{'results_loop'};
   delete $self->{'tmpl_vars'}->{'results_loop'};
   my $board = {};
   foreach my $square (@{$results})
   {
      $self->debug(9, 'Generating Row ' . $square->{'down'} . ' column ' .
         $square->{'across'});
      my $row = $board->{$square->{'down'}} || {};

      $row->{$square->{'across'}} = $square;
      $board->{$square->{'down'}} = $row;
   }

   # Now we need to create an array of the rows in the correct order
   # This is complicared by the possiblity the area to be displayed is
   # over a border, as the board wraps (our world is a donut!)
   my $row_index = $self->{'tmpl_vars'}->{'row_start'};
   my $row_count = 0;
   $self->{'tmpl_vars'}->{'visable_squares_not_fully_moved'} = 0;
   while($row_index != $self->{'tmpl_vars'}->{'row_finish'})
   {
      my $row = {};
      my $column_index = $self->{'tmpl_vars'}->{'column_start'};
      my $column_count = 0;
      while($column_index != $self->{'tmpl_vars'}->{'column_finish'})
      {
         $self->debug(9, "Setting up Row $row_index column $column_index");
         $board->{$row_index}->{$column_index}->{'top'} = 
            20 + ($row_count * 87);
         $board->{$row_index}->{$column_index}->{'left'} = 
            20 + ($column_count * 87);
         if(($row_index + $column_index) % 2)
         {
            $board->{$row_index}->{$column_index}->{'center_left'} = 
               $board->{$row_index}->{$column_index}->{'left'} + 37;
            $board->{$row_index}->{$column_index}->{'center_top'} = 
               $board->{$row_index}->{$column_index}->{'top'} + 37;
            $board->{$row_index}->{$column_index}->{'major'} = 1;
            $board->{$row_index}->{$column_index}->{'land_image'} = '/Images/'.
               $land_type->{$board->{$row_index}->{$column_index}->{'land_type_ID'}}->{'major'};
         } else {
            $board->{$row_index}->{$column_index}->{'left'} += 37;
            $board->{$row_index}->{$column_index}->{'center_left'} = 
               $board->{$row_index}->{$column_index}->{'left'};
            $board->{$row_index}->{$column_index}->{'top'} += 37;
            $board->{$row_index}->{$column_index}->{'center_top'} = 
               $board->{$row_index}->{$column_index}->{'top'};
            $board->{$row_index}->{$column_index}->{'land_image'} = '/Images/'.
               $land_type->{$board->{$row_index}->{$column_index}->{'land_type_ID'}}->{'minor'};
         }
         if($self->is_visable_by_player(
               $player_ID,$board,$column_index,$row_index))
         {
            if($board->{$row_index}->{$column_index}->{'units'} > 0)
            {
               $board->{$row_index}->{$column_index}->{'units_image'} = 
                  '/Images/units_' . 
                  $board->{$row_index}->{$column_index}->{'units'} . '.gif';
            }
            if($board->{$row_index}->{$column_index}->{'owner_ID'} > 0)
            {
               $self->debug(8,"Square $row_index,$column_index owned by " .
                  $board->{$row_index}->{$column_index}->{'owner_ID'});
               $board->{$row_index}->{$column_index}->{'owner_image'} = 
                  '/Images/' . 
                  $owner->{$board->{$row_index}->{$column_index}->{'owner_ID'}};
               if($board->{$row_index}->{$column_index}->{'owner_ID'} == $player_ID && $board->{$row_index}->{$column_index}->{'units'} > 0)
               {
                  if($self->player_moved_units_for_square(
                     $game_ID, $player_ID, $column_index,$row_index,
                     $board->{$row_index}->{$column_index}->{'units'}))
                  {
                     $board->{$row_index}->{$column_index}->{'moved_all'} = 1;
                  } else {
                     $self->debug(8,"Square $row_index,$column_index not moved");
                     $board->{$row_index}->{$column_index}->{'moved_image'} =
                        '/Images/not_moved_all.gif';
                     $self->{'tmpl_vars'}->{'visible_squares_not_fully_moved'}++;
                  }
               }
            }
            if($board->{$row_index}->{$column_index}->{'expansion_type_ID'} > 0)
            {
               $board->{$row_index}->{$column_index}->{'exp_image'} = 
                  '/Images/' . 
                  $expansion_type->{$board->{$row_index}->{$column_index}->{'expansion_type_ID'}};
               if($board->{$row_index}->{$column_index}->{'expansion_to_build'} > 0)
               {
                  $board->{$row_index}->{$column_index}->{'building_image'} = 
                     '/Images/' .  BUILDING_IMAGE
               }
            }
            if(exists($board->{$row_index}->{$column_index}->{'effect_type_ID'}) && defined($board->{$row_index}->{$column_index}->{'effect_type_ID'}) && $board->{$row_index}->{$column_index}->{'effect_type_ID'} > 0)
            {
               $board->{$row_index}->{$column_index}->{'effect_image'} = 
                  '/Images/' . 
                  $effect_type->{$board->{$row_index}->{$column_index}->{'effect_type_ID'}};
            }
         } else {
            $self->debug(8,"Fog of war on square $column_index,$row_index");
            $board->{$row_index}->{$column_index}->{'owner_image'} = 
                  '/Images/fow.gif';

         }
         
         # Add our square here
         push @{$row->{'column_loop'}}, $board->{$row_index}->{$column_index};
         
         # Now move on to the next column
         $column_index++;
         $column_count++;
         if($column_index == ($self->{'tmpl_vars'}->{'column_wrap'}||0))
         {
            $column_index = 0;
         }
      }
      push @{$self->{'tmpl_vars'}->{'row_loop'}}, $row;

      # Now move on to the next row
      $row_index++;
      $row_count++;
      if($row_index == ($self->{'tmpl_vars'}->{'row_wrap'}||0))
      {
         $row_index = 0;
      }
   }

   $self->calculate_borders($self->{'tmpl_vars'}->{'row_loop'});
   
   # Clear this out or it appears in the state as plain text
   $self->move_from_cgi_vars_to_tmpl_vars(['row','column','action_type'], 
      OVERWRITE_MOVE_ANYWAY);
}

#-----------------------------------------------------------------------------
# Function: 	check_game_details
#-----------------------------------------------------------------------------
# Description:
# 					Returns if this is an open game, or is a game the player is in
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# open game             OUT:0 Game still to be started and pending players
# my game               OUT:1 Game that this player is in, or started
# pending game          OUT:2 Game has not started yet
#-----------------------------------------------------------------------------
sub check_game_details
{
	my $self 	   =	shift;

   $self->debug(8, 'Board::check_game_details');
   my ($open_game, $my_game, $pending_game);
   $open_game = ($self->{'game_details'}->{'turn'} == 0);
   $open_game = 0 if($self->{'game_details'}->{'done'});
   my $game_ID = $self->{'cgi_vars'}->{'game_ID'} || 0;
   my $member_ID = $self->logged_on();
   my $player_ID = $self->get_player_ID($member_ID,$game_ID);
   $my_game = ($self->{'game_details'}->{'creator_ID'} == $member_ID);
   $pending_game = ($self->{'game_details'}->{'turn'} == 0);

   # Now we check if the player is in the game already
   my $details = $self->get_game_players_details($game_ID);
   return ($open_game, $my_game, $pending_game) unless(@{$details});

   $self->debug(8, "Game $game_ID has " . @{$details} . ' players');
   my $index = 0;
   while(!$my_game && $index < @{$details})
   {
      $my_game = ($details->[$index]->{'player_ID'} == $player_ID);
      $index++;
   }
   $index-- unless($index < @{$details});
   
   return ($open_game, $my_game, $pending_game);
}

#-----------------------------------------------------------------------------
# Function: 	calculate_borders
#-----------------------------------------------------------------------------
# Description:
# 					Sets up the template variables to store the offsets of the
# 					board borders.
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Rows                  IN:0  The rows hash
#-----------------------------------------------------------------------------
sub calculate_borders
{
	my $self 	   =	shift;
   my $rows_array  = $_[0];

   $self->debug(8, 'Board::calculate_borders');

   my $rows = @{$rows_array};
   return unless($rows);
   my $columns = @{$rows_array->[0]->{'column_loop'}};
   $self->debug(8, "The board is $rows rows by $columns columns");
   
   $self->{'tmpl_vars'}->{'left_of_board_in'} = 50;
   $self->{'tmpl_vars'}->{'left_of_board_out'} = 0;
   $self->{'tmpl_vars'}->{'right_of_board_in'} = 20 + ($columns * 87);
   $self->{'tmpl_vars'}->{'right_of_board_out'} = 70 + ($columns * 87);
   $self->{'tmpl_vars'}->{'top_of_board_in'} = 50;
   $self->{'tmpl_vars'}->{'top_of_board_out'} = 0;
   $self->{'tmpl_vars'}->{'base_of_board_in'} = 20 + ($rows * 87);
   $self->{'tmpl_vars'}->{'base_of_board_out'} = 70 + ($rows * 87);
   $self->{'tmpl_vars'}->{'center_of_board'} = 70 + ($columns * 87 / 2);

   my $across = $self->{'cgi_vars'}->{'column'};
   my $down = $self->{'cgi_vars'}->{'row'};
   my $half_rows = int($show_rows / 2);
   my $half_columns = int($show_columns / 2);
   $self->debug(8, "Current across $across, down $down");
   $self->debug(8, "Half Show rows $half_rows, columns $half_columns");
   $self->{'tmpl_vars'}->{'left_across'} = $across - $half_rows;
   if($self->{'tmpl_vars'}->{'left_across'} < 0)
   {
      $self->{'tmpl_vars'}->{'left_across'} += $self->{'game_details'}->{'board_rows'};
   }
   $self->debug(8, 'To move left go to row ' . $self->{'tmpl_vars'}->{'left_across'});
   $self->{'tmpl_vars'}->{'right_across'} = $across + $half_rows;
   if($self->{'tmpl_vars'}->{'right_across'} >= $self->{'game_details'}->{'board_rows'})
   {
      $self->{'tmpl_vars'}->{'right_across'} -= $self->{'game_details'}->{'board_rows'};
   }
   $self->debug(8, 'To move right go to row ' . $self->{'tmpl_vars'}->{'right_across'});
   $self->{'tmpl_vars'}->{'up_down'} = $down - $half_columns;
   if($self->{'tmpl_vars'}->{'up_down'} < 0)
   {
      $self->{'tmpl_vars'}->{'up_down'} += $self->{'game_details'}->{'board_columns'};
   }
   $self->debug(8, 'To move up go to column ' . $self->{'tmpl_vars'}->{'up_down'});
   $self->{'tmpl_vars'}->{'down_down'} = $down + $half_columns;
   if($self->{'tmpl_vars'}->{'down_down'} >= $self->{'game_details'}->{'board_columns'})
   {
      $self->{'tmpl_vars'}->{'down_down'} -= $self->{'game_details'}->{'board_columns'};
   }
   $self->debug(8, 'To move down go to column ' . $self->{'tmpl_vars'}->{'down_down'});
}

#-----------------------------------------------------------------------------
# Function: 	event_SelectSquare
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
sub event_SelectSquare
{
	my $self 	=	shift;

   $self->debug(8, 'Board::event_SelectSquare');

   my $row = $self->{'cgi_vars'}->{'row'};
   my $column = $self->{'cgi_vars'}->{'column'};
   $self->debug(8, "Selected square Row $row, Column $column");

   if($self->{'cgi_vars'}->{'action_type'} == ACTION_TYPE_MOVE_VIEW)
   {
      # Do nothing, it is all in hand already by the rest of the module
   } elsif ($self->{'cgi_vars'}->{'action_type'} == ACTION_TYPE_SELECT_START) {
      return $self->selected_start($row,$column);
   } elsif ($self->{'cgi_vars'}->{'action_type'} == ACTION_TYPE_VIEW) {
      # We need to do is move the cgi variable
      $self->move_from_cgi_vars_to_tmpl_vars(['action_type'], 
         OVERWRITE_MOVE_ANYWAY);

      # Go to the module to deal with viewing a squares details
      return ('ViewSquare', {'no_check' => 1});
   }

   #   $self->move_from_cgi_vars_to_tmpl_vars(['row','column'], 
   #      OVERWRITE_MOVE_ANYWAY);
   
   return; 
}

#-----------------------------------------------------------------------------
# Function:    selected_start
#-----------------------------------------------------------------------------
# Description:
#              Used to check a starting sqaure is valid, and if so record it
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Next Action				OUT:0	The module name to run next or undef for none
# Next Actions ArgumentsOUT:1	The arguments to pass to the next modules new
# Row                   IN:0  The row to start in
# Column                IN:1  The column to start in
#-----------------------------------------------------------------------------
sub selected_start
{
   my $self    = shift;
   my $row     = $_[0];
   my $column  = $_[1];
   $self->debug(8, 'Board->selected_start');

   my $member_ID = $self->logged_on();
   my $game_ID = $self->{'cgi_vars'}->{'game_ID'} || 
      $self->throw_error(ERROR_RUNTIME_ERROR,
         'Start square picked with no game ID');
         
   my $player_ID = $self->get_player_ID($member_ID, $game_ID);

   # Check this is an open game
   my ($open_game, $my_game, $pending_game) = $self->check_game_details();
   unless($open_game || ($pending_game && $my_game))
   {
      # Not allowed to place a start, as the game is now closed
      $self->{'tmpl_vars'}->{'message'} = 
         'You cannot start in this closed game';
      return;
   }
   
   # Check square is valid for starting on
   unless(($row + $column) % 2)
   {
      # Only a major square can be the center of a starting point
      $self->{'tmpl_vars'}->{'message'} = 'You must start on a major square';
      return;
   }

   my $details = $self->get_game_details($game_ID);
   unless(defined($details))
   {
      $self->throw_error(ERROR_DB_RESULTS,
         'No squares in Board->generate_search for member ' .
         $self->logged_on());
   }
   $self->{'game_details'}->{'game_ID'} = $game_ID;
   $self->{'game_details'}->{'creator_ID'} = $details->{'creator_ID'};
   $self->{'game_details'}->{'board_rows'} = $details->{'height'};
   $self->{'game_details'}->{'board_columns'} = $details->{'width'};
   $self->{'game_details'}->{'players'} = $details->{'players'};
   $self->{'game_details'}->{'next_turn'} = $details->{'next_turn'};
   $self->{'game_details'}->{'start_date_time'} = $details->{'start_date_time'};
   $self->{'game_details'}->{'max_turns'} = $details->{'max_turns'};
   $self->{'game_details'}->{'turn'} = $details->{'turn'};
   $self->{'game_details'}->{'turn_frequency_hours'} = 
                                       $details->{'turn_frequency_hours'};
   $self->{'game_details'}->{'frequency_weekday_type_ID'} = 
                                       $details->{'frequency_weekday_type_ID'};
   $self->{'game_details'}->{'turn_start_time'} = $details->{'turn_start_time'};
   $self->{'game_details'}->{'turn_stop_time'} = $details->{'turn_stop_time'};
   $self->{'game_details'}->{'done'} = $details->{'done'};

   # We want to check this and the 4 surrounding squares are land
   my $board_width = $self->{'game_details'}->{'board_columns'};
   my $board_height = $self->{'game_details'}->{'board_rows'};
   my @cross = $self->get_cross_axis($row,$column,$board_height,$board_width);
   foreach my $axis (@cross)
   {
      if($self->land_type($game_ID,$axis->{'column'},$axis->{'row'}) == 
         LAND_TYPE_SEA)
      {
         # Not all land
         $self->{'tmpl_vars'}->{'message'} = 
            'You must start on a cross of land i.e. +';
         return;
      }
   }
   # And that we are at lease 6 squares from anyone else
   if($self->proximity_test($game_ID,$row,$column))
   {
      $self->{'tmpl_vars'}->{'message'} = 
         'That was too close to another player';
      return;
   }
   
   unless($player_ID)
   {
      $self->debug(8, "Adding player to game $game_ID for member $member_ID");
      $player_ID = $self->add_player_to_game($member_ID,$game_ID);
   }
   $self->debug(8, 'Valid Start Picked by player ' . $player_ID .
      " for game $game_ID, at row $row, column $column");
   $self->set_pending_start($game_ID, $player_ID, $row, $column);
      
   return;
}

#-----------------------------------------------------------------------------
# Function:    set_pending_start
#-----------------------------------------------------------------------------
# Description:
#              Used to set or move a players pending start location
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Game ID               IN:0  The game to set there start in
# Player ID             IN:1  The Player to set the start of
# Row                   IN:2  The row to start in
# Column                IN:3  The column to start in
#-----------------------------------------------------------------------------
sub set_pending_start
{
   my $self    = shift;
   my $game_ID    = $_[0];
   my $player_ID  = $_[1] || $self->throw_error(ERROR_MISSING_PARAMETER,'player_ID missing in Board->set_pending_start');
   my $row        = $_[2];
   my $column     = $_[3];
   $self->debug(8, 'Board->set_pending_start');
   $self->debug(8,"Game $game_ID,Player $player_ID,Row $row,Column $column");

   # Remove the players current starting location, there may be none
   my $error_code = $self->db_delete(
         $self->config('pending_game_player_start_table'),
         {'game_ID'        => $game_ID,
          'game_player_ID' => $player_ID}
      );
   if($error_code)
   {
      $self->throw_error($error_code,
         "Delete error in Board->set_pending_start");
   }
   
   # Add starting location
   my $insert_details = {
      'game_ID'            => $game_ID,
      'game_player_ID'     => $player_ID,
      'across'             => $column,
      'down'               => $row
   };
   my $pending_start_ID;
   ($error_code, $pending_start_ID) = $self->db_insert(
         $self->config('pending_game_player_start_table'), $insert_details);
   if($error_code)
   {
      $self->throw_error($error_code,
         "Insert error in Board->set_pending_start for pending start location");
   }

   # Now remove any own squares on the board
   my $update =
      {
         'owner_ID'  => 0
      };
   $error_code = $self->db_update($self->config('game_board_table'), $update,
      { 'game_ID'    => $game_ID,
        'owner_ID'   => $player_ID});
   
   if($error_code)
   {
      $self->throw_error($error_code,
         "Update error in Board->set_pending_start for remove old owner");
   }
   
   # And add own squares at there new start
   $update =
      {
         'owner_ID'  => $player_ID
      };
   my $board_width = $self->{'game_details'}->{'board_columns'};
   my $board_height = $self->{'game_details'}->{'board_rows'};
   my @cross = $self->get_cross_axis($row,$column,$board_height,$board_width);
   foreach my $axis (@cross)
   {
      $self->debug(9, 'Setting owner of row ' . $axis->{'row'} . ', column ' .
         $axis->{'column'} . " to $player_ID for game $game_ID");
      $error_code = $self->db_update($self->config('game_board_table'), $update,
         {  'game_ID'   => $game_ID,
            'down'      => $axis->{'row'},
            'across'    => $axis->{'column'}
         });
   
      if($error_code)
      {
         $self->throw_error($error_code,
            "Update error in Board->set_pending_start for add square owner " .
            $axis->{'row'} . ',' . $axis->{'column'});
      }
   }

   $update =
      {
         'start_across' => $column,
         'start_down'   => $row
      };
   $error_code = $self->db_update(
      $self->config('game_player_table'), $update, { 'ID'    => $player_ID});
   
   if($error_code)
   {
      $self->throw_error($error_code, "Update error in Board->set_pending_start for set owner start $row,$column for player $player_ID");
   }
   return;
}

#-----------------------------------------------------------------------------
# Function:    proximity_test
#-----------------------------------------------------------------------------
# Description:
#              Used to check that players start a set distance from each other
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Too Close             OUT:0 Not too close to any other players
# Game ID               IN:0  The game ID to look up
# Row                   IN:1  The row to look up
# Column                IN:2  The column to look up
#-----------------------------------------------------------------------------
sub proximity_test
{
   my $self = shift;
   my $game_ID = $_[0];
   my $row     = $_[1];
   my $column  = $_[2];
   $self->debug(8, 'Board->proximity_test');
   my $player_ID = $self->{'tmpl_vars'}->{'my_player_ID'} || 0;
   unless($player_ID > 0)
   {
      my $member_ID = $self->logged_on();
      $player_ID = $self->get_player_ID($member_ID, $game_ID);
   }

   my $board_width = $self->{'game_details'}->{'board_columns'};
   my $board_height = $self->{'game_details'}->{'board_rows'};
   my ($error_code, $details) = $self->db_select(
      'get_other_players_pending_start_locations',
      {'pending_game_player_start' => 
         $self->config('pending_game_player_start_table')},
      $game_ID,$player_ID);
   if($error_code)
   {
      $self->throw_error($error_code,
         "Select error in CommonTools->proximity_test");
   }
   
   my $too_close = 0;
   foreach my $start_details (@{$details})
   {
      if(((($start_details->{'across'} - $column + $board_width) % $board_width)
         + (($start_details->{'down'} - $row + $board_height) % $board_height))
         < $self->config('minimum_player_distance'))
      {
         # Too close
         $too_close ||= $start_details->{'game_player_ID'};
      }
   }
   
   # All ok, or too close
   return $too_close;
};

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
   $self->debug(8, 'Board::generate_search');

   my $game_ID = $self->{'cgi_vars'}->{'game_ID'} || 0;

   my ($error_code, $details) = $self->db_select('get_site_member_details',
      {'member_details' => $self->config('member_details_table')},
      $self->logged_on());
   if($error_code)
   {
      $self->throw_error($error_code,
         "Select error in Board->generate_search");
   }
   unless(defined($details) && @{$details} == 1)
   {
      $self->throw_error(ERROR_DB_RESULTS,
         'No site member details in Board->generate_search for member ' .
         $self->logged_on());
   }
   $show_rows = $details->[0]->{'show_rows'};
   $show_columns = $details->[0]->{'show_columns'};

   $details = $self->get_game_details($game_ID);
   unless(defined($details))
   {
      $self->debug(8, 'Get game details failure');
      $self->throw_error(ERROR_DB_RESULTS,
         'No squares in Board->generate_search for member ' .
         $self->logged_on());
   }
   $self->debug(8, 'Got game details ok');
   $self->{'game_details'}->{'game_ID'} = $game_ID;
   $self->{'game_details'}->{'creator_ID'} = $details->{'creator_ID'};
   $self->{'game_details'}->{'board_rows'} = $details->{'height'};
   $self->{'game_details'}->{'board_columns'} = $details->{'width'};
   $self->{'game_details'}->{'players'} = $details->{'players'};
   $self->{'game_details'}->{'next_turn'} = $details->{'next_turn'};
   $self->{'game_details'}->{'start_date_time'} = $details->{'start_date_time'};
   $self->{'game_details'}->{'max_turns'} = $details->{'max_turns'};
   $self->{'game_details'}->{'turn'} = $details->{'turn'};
   $self->{'game_details'}->{'turn_frequency_hours'} = $details->{'turn_frequency_hours'};
   $self->{'game_details'}->{'frequency_weekday_type_ID'} = $details->{'frequency_weekday_type_ID'};
   $self->{'game_details'}->{'turn_start_time'} = $details->{'turn_start_time'};
   $self->{'game_details'}->{'turn_stop_time'} = $details->{'turn_stop_time'};
   $self->{'game_details'}->{'done'} = $details->{'done'};
   
   my $player_details = {};
   my $member_ID = $self->logged_on();
   my $player_ID = $self->get_player_ID($member_ID, $game_ID);
   if($player_ID > 0)
   {
      $player_details = $self->get_player_details($game_ID, $player_ID);
   }
   
   my $row;
   if(exists($self->{'cgi_vars'}->{'row'}))
   {
      $row = $self->{'cgi_vars'}->{'row'};
   } else {
      if($player_ID > 0)
      {
         $row = $player_details->{'start_down'};
      } else {
         $row = $show_rows / 2;
      }
      $self->{'cgi_vars'}->{'row'} = $row;
   }
   my $column;
   if(exists($self->{'cgi_vars'}->{'column'}))
   {
      $column = $self->{'cgi_vars'}->{'column'};
   } else {
      if($player_ID > 0)
      {
         $column = $player_details->{'start_across'};
      } else {
         $column = $show_columns / 2;
      }
      $self->{'cgi_vars'}->{'column'} = $column;
   }
   $self->debug(9, "Row: $row, Show: $show_rows, Col: $column, Show:$show_columns");
   my $row_start = $row - ($show_rows / 2);
   my $row_finish = $row + ($show_rows / 2);
   my $row_finish_plus = 2 + $row + ($show_rows / 2);
   my $column_start = $column - ($show_columns / 2);
   my $column_finish = $column + ($show_columns / 2);
   my $column_finish_plus = 2 + $column + ($show_columns / 2);

   $self->debug(8, "Rows: $row_start to $row_finish ($row_finish_plus), Columns: $column_start to $column_finish ($column_finish_plus)");

   my ($handle,$variables,@params);
   $variables = {
      'game_board'            => $self->config('game_board_table'),
      'square_effect_details' => $self->config('square_effect_details_table')
   };
   $handle = 'get_board';
   push @params, $game_ID;
   $variables->{'additional_across'} = '';
   if($column_start < 0)
   {
      # Shift the start and finish and let the next if do all the work
      $column_start += $self->{'game_details'}->{'board_columns'};
      $column_finish += $self->{'game_details'}->{'board_columns'};
      $column_finish_plus += $self->{'game_details'}->{'board_columns'};
   }
   $self->{'tmpl_vars'}->{'column_start'} = $column_start;
   push @params, $column_start;
   if($column_finish >= $self->{'game_details'}->{'board_columns'})
   {
      $column_finish -= $self->{'game_details'}->{'board_columns'};
      $self->{'tmpl_vars'}->{'column_wrap'} = $self->{'game_details'}->{'board_columns'};
   }
   if($column_finish_plus >= $self->{'game_details'}->{'board_columns'})
   {
      push @params, $self->{'game_details'}->{'board_columns'} - 1;
      $variables->{'additional_across'} = 'OR (S.across BETWEEN ? AND ?)';
      push @params, 0;
      $column_finish_plus -= $self->{'game_details'}->{'board_columns'};
   }
   $self->{'tmpl_vars'}->{'column_finish'} = $column_finish;
   push @params, $column_finish_plus;
   if($row_start < 0)
   {
      # Shift the start and finish and let the next if do all the work
      $row_start += $self->{'game_details'}->{'board_rows'};
      $row_finish += $self->{'game_details'}->{'board_rows'};
      $row_finish_plus += $self->{'game_details'}->{'board_rows'};
   }
   $self->{'tmpl_vars'}->{'row_start'} = $row_start;
   push @params, $row_start;
   if($row_finish >= $self->{'game_details'}->{'board_rows'})
   {
      $row_finish -= $self->{'game_details'}->{'board_rows'};
      $self->{'tmpl_vars'}->{'row_wrap'} = $self->{'game_details'}->{'board_rows'};
   }
   if($row_finish_plus >= $self->{'game_details'}->{'board_rows'})
   {
      push @params, $self->{'game_details'}->{'board_rows'} - 1;
      $variables->{'additional_down'} = 'OR (S.down BETWEEN ? AND ?)';
      push @params, 0;
      $row_finish_plus -= $self->{'game_details'}->{'board_rows'};
   } else {
      $variables->{'additional_down'} = '';
   }
   $self->{'tmpl_vars'}->{'row_finish'} = $row_finish;
   push @params, $row_finish_plus;
   $self->debug(8, "Search handle: $handle, Variables: $variables");

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
   $self->debug(8, 'Board::empty_results');

   return 'No Board Found For Game';
}

#-----------------------------------------------------------------------------
# Function:    is_visable_by_player
#-----------------------------------------------------------------------------
# Description:
#              Used to calculate if the player is allowed to see the units 
#              and buildings on the square
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Visable               OUT:0 This square can be shown to the player
#
#-----------------------------------------------------------------------------
sub is_visable_by_player
{
   my $self          = shift;

   # Games that have either not started or not finished are completely visable
   if($self->{'game_details'}->{'done'})
   {
      return 1;
   }
   if($self->{'game_details'}->{'turn'} == 0)
   {
      return 1;
   }
   
   my $player_ID     = $_[0] || return 0; # Once a game starts, only players
                                          # can view, else people could cheat
   my $board         = $_[1] || $self->throw_error(ERROR_MISSING_PARAMETER, 
                                 'Board missing in is_visable_by_player');
   my $column_index  = $_[2];
   unless(defined($column_index))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER, 
         'Column missing in is_visable_by_player');
   }
   my $row_index     = $_[3];
   unless(defined($row_index))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER, 
         'Row missing in is_visable_by_player');
   }
   $self->debug(8, 'Board::is_visable_by_player');

   my $this_square = $board->{$row_index}->{$column_index};
   
   # The owner can see it
   return 1 if($this_square->{'owner_ID'} == $player_ID);
   
   # Check for owning or have scout on neighbour square
   if($self->check_neighbours_for_view(
         $player_ID,$board,$column_index,$row_index,1))
   {
      $self->debug(8, "Owner found next to $column_index,$row_index");
      return 1;
   }
   # Check for base within 2 squares
   if($self->check_neighbours_for_view(
         $player_ID,$board,$column_index,$row_index,2,EXPANSION_TYPE_BASE))
   {
      $self->debug(8, "Base found near to $column_index,$row_index");
      return 1;
   }
   # Check for tower within 4 squares
   if($self->check_neighbours_for_view(
         $player_ID,$board,$column_index,$row_index,4,EXPANSION_TYPE_TOWER))
   {
      $self->debug(8, "Fort found close to $column_index,$row_index");
      return 1;
   }
   
   # We can't see it then
   $self->debug(9, "Row $row_index Col $column_index not visible");
   return 0;
}

#-----------------------------------------------------------------------------
# Function:    check_neighbours_for_view
#-----------------------------------------------------------------------------
# Description:
#              Checks for a player owned square with in a certain range
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Visable               OUT:0 This square can be shown to the player
#-----------------------------------------------------------------------------
sub check_neighbours_for_view
{
   my $self          = shift;

   my $player_ID     = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER, 
                                 'Player ID missing in check_neighbours_for_view');
   my $board         = $_[1] || $self->throw_error(ERROR_MISSING_PARAMETER, 
                                 'Board missing in check_neighbours_for_view');
   my $column_index  = $_[2];
   unless(defined($column_index))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER, 
         'Column missing in check_neighbours_for_view');
   }
   my $row_index     = $_[3];
   unless(defined($row_index))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER, 
         'Row missing in check_neighbours_for_view');
   }
   my $distance      = $_[4] || 1;
   my $expansion_ID  = $_[5] || 0;
   
   $self->debug(8, 'Board::check_neighbours_for_view ' . join(',',@_));

   my $start_row = $row_index - $distance;  
   my $end_row = $row_index + $distance;  
   my $start_column = $column_index - $distance;  
   my $end_column = $column_index + $distance;  
   my $rows_in_board = $self->{'game_details'}->{'board_rows'};
   my $columns_in_board = $self->{'game_details'}->{'board_columns'};
   $self->debug(9, "Row $start_row to $end_row, Col $start_column to $end_column of $rows_in_board by $columns_in_board");

   for(my $row = $start_row; $row <= $end_row; $row++)
   {
      my $actual_row = $row;
      $actual_row += $rows_in_board if($actual_row < 0);
      $actual_row -= $rows_in_board if($actual_row >= $rows_in_board);
      for(my $column = $start_column; $column <= $end_column; $column++)
      {
         my $actual_column = $column;
         $actual_column += $columns_in_board if($actual_column < 0);
         if($actual_column >= $columns_in_board)
         {
            $actual_column -= $columns_in_board;
         }
         my $this_square = $board->{$actual_row}->{$actual_column};
         
         unless(exists($this_square->{'owner_ID'}) && 
            $this_square->{'owner_ID'} == $player_ID)
         {
            next;
         }
         if($expansion_ID)
         {
            if($expansion_ID == $this_square->{'expansion_type_ID'})
            {
               $self->debug(9, "Expansion $expansion_ID found at Row $actual_row Col $actual_column");
               return 1;
            }
         } else {
            $self->debug(9, "Owner $player_ID found at Row $actual_row Col $actual_column");
            return 1;
         }
      }
   }
   
   $self->debug(9, "Row $row_index Col $column_index not found");
   return 0;
}

1;
