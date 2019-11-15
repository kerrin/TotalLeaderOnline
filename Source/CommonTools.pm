#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		CommonTools
#-----------------------------------------------------------------------------
# Description:
# 					Multiple inherited, and supplies functionality used more than 
# 					once
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2004/09/04 21:28:17 $
# $Revision: 1.35 $
#-----------------------------------------------------------------------------
package TotalLeader::Source::CommonTools;
use strict;

use Time::Local;

BEGIN
{
	my $project_path;
	unless($project_path = $ENV{'PROJECT_PATH'})
	{
		confess('Set enviroment variable PROJECT_PATH to the project path');
	}
	eval "use lib '$project_path';";
	
	# And associated package defaults
	use vars qw(@ISA @EXPORT);
	@ISA = qw(Exporter);
	@EXPORT = qw();
}

use SWS::Source::Error;
use TotalLeader::Source::Constants;

#-----------------------------------------------------------------------------
# Function: 	all_screens_common
#-----------------------------------------------------------------------------
# Description:
# 					Does what needs to be done on all screen
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
#-----------------------------------------------------------------------------
sub all_screens_common
{
	my $self 		=	shift;

   $self->debug(9, 'TotalLeader::CommonTools->all_screens_common');
   if($self->logged_on())
   {
      $self->{'tmpl_vars'}->{'logged_on'} = 1;
      my $member_details = $self->member_details();
      $self->{'tmpl_vars'}->{'current_member_ID'} = 
         $member_details->{'ID'}; 
      $self->{'tmpl_vars'}->{'current_member_screen_name'} = 
         $member_details->{'screen_name'}; 
      $self->{'tmpl_vars'}->{'current_member_firstname'} = 
         $member_details->{'firstname'}; 
      $self->{'tmpl_vars'}->{'current_member_surname'} = 
         $member_details->{'surname'}; 
      $self->{'tmpl_vars'}->{'current_member_username'} = 
         $member_details->{'username'}; 
      $self->{'tmpl_vars'}->{'current_member_gender'} = 
         $self->gender($member_details->{'gender_ID'}); 
      $self->{'tmpl_vars'}->{'current_member_age'} = 
         $self->age($member_details->{'dob'});
      $self->{'tmpl_vars'}->{'current_member_registered'} = 
         $member_details->{'registered'};
      $self->{'tmpl_vars'}->{'current_member_last_logon'} = 
         $member_details->{'last_logon'};
      $self->{'tmpl_vars'}->{'current_member_paid_expire'} = 
         $member_details->{'paid_expire'};
      $self->{'tmpl_vars'}->{'current_member_expire'} = 
         $member_details->{'expire'};
      $self->check_new_messages($member_details->{'ID'});
   }
   if(exists($self->{'cgi_vars'}->{'game_ID'}))
   {
      $self->debug(9, 'Overriding game ID to ' .
         $self->{'cgi_vars'}->{'game_ID'});
      $self->{'tmpl_vars'}->{'game_ID'} = $self->{'cgi_vars'}->{'game_ID'};
      
      my $player_ID = $self->get_player_ID(
                              $self->{'tmpl_vars'}->{'current_member_ID'}, 
                              $self->{'tmpl_vars'}->{'game_ID'});
      $self->{'tmpl_vars'}->{'my_player_ID'} = $player_ID;
   }
}

#-----------------------------------------------------------------------------
# Function:    create_new_board
#-----------------------------------------------------------------------------
# Description:
#              Create a new board
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code   OUT:0 0 successful, or an error code
# width                 IN:0  The number of squares wide the board is
# height                IN:1  The number of squares height
# game_ID               IN:2  The game the board is for
#-----------------------------------------------------------------------------
sub create_new_board
{
   my $self    =  shift;
   my $width   = $_[0];
   my $height  = $_[1];
   my $game_ID = $_[2];

   my ($board,$column,$row);
   for($column = 0; $column < $width; $column++)
   {
      for($row = 0; $row < $height; $row++)
      {
         my $land_probabilty = 4; # chance in 10
         if($row > 0 && $board->[$row-1]->[$column]->{'type'} != LAND_TYPE_SEA)
         {
            # Not Sea above, so increase chance of land
            $land_probabilty += 2;
         }
         if($column > 0 && $board->[$row]->[$column-1]->{'type'} != LAND_TYPE_SEA)
         {
            # Not Sea to left, so increase chance of land
            $land_probabilty += 2;
         }
         if($column > 0 && $row > 0 && $board->[$row-1]->[$column-1]->{'type'} != LAND_TYPE_SEA)
         {
            # Not Sea to diagonly up and left, so increase chance of land
            $land_probabilty += 1;
         }
         my $random_number = int(rand(10));
         if($random_number < $land_probabilty)
         {
            # Land, now we just need to pick one, chance of each equal
            $random_number = int(rand(3));
            if($random_number == 0)
            {
               $board->[$row]->[$column]->{'type'} = LAND_TYPE_PLAINS;
            } elsif($random_number == 1) {
               $board->[$row]->[$column]->{'type'} = LAND_TYPE_MOUNTAIN;
            } else {
               $board->[$row]->[$column]->{'type'} = LAND_TYPE_FOREST;
            }
         } else {
            $board->[$row]->[$column]->{'type'} = LAND_TYPE_SEA;
         }
      }
   }
   for($column = 0; $column < $width; $column++)
   {
      for($row = 0; $row < $height; $row++)
      {
         my $units = ($board->[$row]->[$column]->{'type'} == LAND_TYPE_SEA?0:int(rand(10)));
         my $insert_details = {
            'game_ID'            => $game_ID,
            'across'             => $column,
            'down'               => $row,
            'owner_ID'           => 0,
            'units'              => $units,
            'land_type_ID'       => $board->[$row]->[$column]->{'type'},
            'expansion_type_ID'  => 0,
            'expansion_hp'       => 0,
            'expansion_to_build' => 0
         };
         my ($error_code, $board_ID) = $self->db_insert(
               $self->config('game_board_table'), $insert_details);
         return $error_code if($error_code);
      }
   }

   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function:    add_game
#-----------------------------------------------------------------------------
# Description:
#              Adds a basic member to the database, any additional data
#              associated with the member should be added with a separate
#              function
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code   OUT:0 0 successful, or an error code
# Game ID               OUT:1 The member identifier number of the member added
# Game Details          IN:0  A hash containing the game details
#-----------------------------------------------------------------------------
sub add_game
{
   my $self    =  shift;
   my $details = $_[0];

   $self->debug(8, 'CommonTools->add_game');
   unless(  exists($details->{'creator_ID'}) &&
            exists($details->{'players'}) &&
            exists($details->{'width'}) &&
            exists($details->{'height'}) &&
            exists($details->{'turn_frequency_hours'}) &&
            exists($details->{'frequency_weekday_type_ID'}) &&
            exists($details->{'turn_start_time'}) &&
            exists($details->{'turn_stop_time'}) &&
            exists($details->{'start_date_time'}) &&
            exists($details->{'max_turns'}) &&
            exists($details->{'next_turn'})
         )
   {
      $self->error(ERROR_SEVERITY_ERROR, ERROR_MISSING_PARAMETER,
         'Required parameter missing for add game');
      return ERROR_MISSING_PARAMETER;
   }

   my ($error_code, $game_ID) = 
      $self->db_insert($self->config('game_table'), $details);
   return ($error_code, $game_ID) if($error_code);

   $error_code = $self->create_new_board(
         $details->{'width'},$details->{'height'}, $game_ID);

   return ($error_code, $game_ID);
}

#-----------------------------------------------------------------------------
# Function:    get_player_ID
#-----------------------------------------------------------------------------
# Description:
#              Returns the player ID for the member in a game
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Player ID             OUT:0 The player identifier of the member in the game
# User ID               IN:0  The member ID to look up in the game
# Game ID               IN:1  The game ID to look up the player ID of member
#-----------------------------------------------------------------------------
sub get_player_ID
{
   my $self       =  shift;
   my $member_ID  = $_[0] || return 0;
   my $game_ID    = $_[1] || return 0;
   $self->debug(8, 'CommonTools->get_player_ID');

   my $player_ID = 0;
   my ($error_code, $details) = $self->db_select(
      'get_game_player_details_for_member',
      {'game_player' => $self->config('game_player_table')},
      $game_ID,$member_ID);
   if($error_code)
   {
      $self->throw_error($error_code,
         'Select error in CommonTools->get_player_ID');
   }
   if(defined($details))
   {
      $player_ID = $details->[0]->{'player_ID'};
   }

   return $player_ID;
}

#-----------------------------------------------------------------------------
# Function:    get_member_ID
#-----------------------------------------------------------------------------
# Description:
#              Returns the player ID for the member in a game
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Member ID             OUT:0 The member identifier of the member in the game
# Player ID             IN:0  The player ID to look up in the game
# Game ID               IN:1  The game ID to look up the player ID of member
#-----------------------------------------------------------------------------
sub get_member_ID
{
   my $self       =  shift;
   my $player_ID  = $_[0] || return 0;
   my $game_ID    = $_[1] || return 0;
   $self->debug(8, 'CommonTools->get_member_ID');

   my $member_ID = 0;
   my ($error_code, $details) = $self->db_select(
      'get_member_ID_for_game_player',
      {'game_player' => $self->config('game_player_table')},
      $game_ID,$player_ID);
   if($error_code)
   {
      $self->throw_error($error_code,
         'Select error in CommonTools->get_member_ID');
   }
   if(defined($details))
   {
      $member_ID = $details->[0]->{'member_ID'};
   }

   return $member_ID;
}

#-----------------------------------------------------------------------------
# Function:    get_player_details
#-----------------------------------------------------------------------------
# Description:
#              Returns the player details for the player ID
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Player Deatils        OUT:0 The player details
# Game ID               IN:0  The game ID to look up the player ID in
# Player ID             IN:1  The player ID to look up details of
#-----------------------------------------------------------------------------
sub get_player_details
{
   my $self       =  shift;
   my $game_ID    = $_[0] || return [];
   my $player_ID  = $_[1] || return [];
   $self->debug(8, 'CommonTools->get_player_details');

   my ($error_code, $details) = $self->db_select(
      'get_game_player_details_for_player_ID',
      {'game_player' => $self->config('game_player_table')},
      $game_ID,$player_ID);
   if($error_code)
   {
      $self->throw_error($error_code,
         'Select error in CommonTools->get_player_ID');
   }
   if(defined($details) && @{$details})
   {
      $details = $details->[0];
   }

   return $details;
}

#-----------------------------------------------------------------------------
# Function:    get_game_players_details
#-----------------------------------------------------------------------------
# Description:
#              Returns the player details for the player ID
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Player Deatils        OUT:0 The player details
# Game ID               IN:0  The game ID to look up the player ID in
# Player ID             IN:1  The player ID to look up details of
#-----------------------------------------------------------------------------
sub get_game_players_details
{
   my $self       =  shift;
   my $game_ID    = $_[0] || return [];
   $self->debug(8, 'CommonTools->get_player_details');

   my ($error_code, $details) = $self->db_select(
      'get_game_player_details',
      {'game_player' => $self->config('game_player_table')}, $game_ID);
   if($error_code)
   {
      $self->throw_error($error_code,
         'Select error in CommonTools->get_player_ID');
   }
   unless(defined($details))
   {
      $details = [];
   }

   return $details;
}

#-----------------------------------------------------------------------------
# Function:    add_player_to_game
#-----------------------------------------------------------------------------
# Description:
#              Returns the land type of a square in a game
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Player ID             OUT:0 The player identifier of the member in the game
# User ID               IN:0  The member ID to look up in the game
# Game ID               IN:1  The game ID to look up the player ID of member
#-----------------------------------------------------------------------------
sub add_player_to_game
{
   my $self       = shift;
   my $member_ID  = $_[0];
   my $game_ID    = $_[1];

   $self->debug(8, 'CommonTools->add_player_to_game');
   my $player_ID = $self->get_player_ID($member_ID, $game_ID);
   if($player_ID)
   {
      $self->debug(9, "Found player $player_ID for game $game_ID, member $member_ID");
      return $player_ID;
   }

   my $insert_details = {
      'member_ID' => $member_ID,
      'game_ID'   => $game_ID,
      'colour_ID' => $member_ID # Until the game starts there are no colours
   };
   my $error_code;
   ($error_code, $player_ID) = $self->db_insert(
               $self->config('game_player_table'), $insert_details);
   if($error_code)
   {
      $self->throw_error($error_code,
         'Insert error in CommonTools->add_player_to_game');
   }

   return $player_ID;
}

#-----------------------------------------------------------------------------
# Function:    get_game_details
#-----------------------------------------------------------------------------
# Description:
#              Returns the details of a game from it's ID
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Game Details          OUT:0 The player identifier of the member in the game
# Game ID               IN:0  The game ID to look up details of
#-----------------------------------------------------------------------------
sub get_game_details
{
   my $self       = shift;
   my $game_ID    = $_[0];

   $self->debug(8, 'CommonTools->get_game_details');
   my ($error_code, $details) = $self->db_select(
      'get_game_details',
      {'game' => $self->config('game_table')},
      $game_ID);
   if($error_code)
   {
      $self->throw_error($error_code,
         'Select error in CommonTools->get_game_details for ID ' . $game_ID);
   }
   if(defined($details))
   {
      $self->debug(8, 'Got game details');
      $self->debug(8, 'Found ' . @{$details});
   } else {
      $self->debug(8, 'Did not get game details');
      $details->[0] = undef;
   }

   return $details->[0];
}

#-----------------------------------------------------------------------------
# Function:    get_game_details
#-----------------------------------------------------------------------------
# Description:
#              Returns the details of a game from it's ID
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Game Details          OUT:0 The player identifier of the member in the game
# Game ID               IN:0  The game ID to look up details of
#-----------------------------------------------------------------------------
sub setup_game_details
{
   my $self       = shift;
   my $game_ID    = $_[0];

   $self->debug(8, 'CommonTools->setup_game_details');

   my $details = $self->get_game_details($game_ID);
   unless(defined($details))
   {
      $self->debug(8, 'Get game details failure');
      $self->throw_error(ERROR_DB_RESULTS,
         'No squares in CommonTools->setup_game_details for member ' .
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
   $self->{'game_details'}->{'turn_frequency_hours'} = $details->{'turn_frequenc
y_hours'};
   $self->{'game_details'}->{'frequency_weekday_type_ID'} = $details->{'frequenc
y_weekday_type_ID'};
   $self->{'game_details'}->{'turn_start_time'} = $details->{'turn_start_time'};
   $self->{'game_details'}->{'turn_stop_time'} = $details->{'turn_stop_time'};

   return;
}

#-----------------------------------------------------------------------------
# Function:    get_cross_axis
#-----------------------------------------------------------------------------
# Description:
#              Returns the co-ordinates of the start cross from the center 
#              co-ordinates
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Cross Array           OUT:0 Array of hashs containing the axis of the cross
# row                   IN:0  The row at the center
# column                IN:1  The column at the center
# height                IN:2  The board height
# width                 IN:3  The board width
#-----------------------------------------------------------------------------
sub get_cross_axis
{
   my $self    =  shift;
   my $row     = $_[0];
   my $column  = $_[1];
   my $height  = $_[2];
   my $width   = $_[3];
   $self->debug(8, 'CommonTools->get_cross_axis');

   my @cross =
   (
      {'row' => $row, 'column' => $column},
      {'row' => ($row + 1)% $height, 'column' => $column},
      {'row' => ($row - 1 + $height) % $height, 'column' => $column},
      {'row' => $row, 'column' => ($column+1) % $width},
      {'row' => $row, 'column' => ($column-1 + $width) % $width}
   );
   
   return @cross;
}

#-----------------------------------------------------------------------------
# Function:    get_technology_details
#-----------------------------------------------------------------------------
# Description:
#              Returns the details of a technology
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Tech Details          OUT:0 The details of the technology
# Tech ID               IN:0  The technology ID to look up
#-----------------------------------------------------------------------------
sub get_technology_details
{
   my $self       =  shift;
   my $tech_ID    = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'technology ID missing in get_technology_details');
   $self->debug(8, 'CommonTools->get_technology_details');

   my ($error_code, $details) = $self->db_select(
      'get_technology_details',
      {'technology_type_const' => $self->config('technology_type_const_table')},
      $tech_ID);
   if($error_code)
   {
      $self->throw_error($error_code,
         'Select error in CommonTools->get_technology_details for ID ' .
         $tech_ID);
   }
   unless(defined($details))
   {
      $details->[0] = undef;
   }

   return $details->[0];
}

#-----------------------------------------------------------------------------
# Function:    player_has_technology
#-----------------------------------------------------------------------------
# Description:
#              Returns true if the player has the technology in this game
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Has Tech              OUT:0 1 if the player has, 0 otherwise
# Player ID             IN:0  The player ID to look up
# Tech ID               IN:1  The technology ID to look up
#-----------------------------------------------------------------------------
sub player_has_technology
{
   my $self       =  shift;
   my $player_ID  = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'player ID missing in player_has_technology');
   my $tech_ID    = $_[1] || return 1; # No technology required
   $self->debug(8, 'CommonTools->player_has_technology');

   my ($error_code, $details) = $self->db_select(
      'check_player_technology',
      {'game_player_technology_link' => $self->config('game_player_technology_link_table')},
      $tech_ID, $player_ID);
   if($error_code)
   {
      $self->throw_error($error_code,
         'Select error in CommonTools->player_has_technology for tech ID ' .
         $tech_ID . ' player ID ' . $player_ID);
   }
   if(defined($details))
   {
      return 1;
   } else {
      return 0;
   }
}

#-----------------------------------------------------------------------------
# Function:    player_getting_technology
#-----------------------------------------------------------------------------
# Description:
#              Returns true if the player is currently researching the 
#              technology in this game
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Getting Tech          OUT:0 Tech ID if the player is getting, 0 otherwise
# Player ID             IN:0  The player ID to look up
# Tech ID               IN:1  The technology ID to look up (0 to find)
#-----------------------------------------------------------------------------
sub player_getting_technology
{
   my $self       =  shift;
   my $player_ID  = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'player ID missing in player_getting_technology');
   my $tech_ID    = $_[1] || 0;
   $self->debug(8, 'CommonTools->player_getting_technology');

   if($tech_ID)
   {
      my ($error_code, $details) = $self->db_select(
         'check_player_researching_technology',
         {'game_player_technology_link' => $self->config('game_player_technology_link_table')},
         $tech_ID, $player_ID);
      if($error_code)
      {
         $self->throw_error($error_code,
            'Select error in CommonTools->player_getting_technology for tech ID ' .
            $tech_ID . ' player ID ' . $player_ID);
      }
      unless(defined($details))
      {
         $tech_ID = 0;
      }
   } else {
      my ($error_code, $details) = $self->db_select(
         'find_player_researching_technology',
         {'game_player_technology_link' => $self->config('game_player_technology_link_table')},
         $player_ID);
      if($error_code)
      {
         $self->throw_error($error_code,
            'Select error in CommonTools->player_getting_technology for ' .
            "player ID $player_ID");
      }
      if(defined($details) && @{$details})
      {
           $tech_ID = $details->[0]->{'ID'};
      }
   }
   return $tech_ID;
}

#-----------------------------------------------------------------------------
# Function:    get_player_allowed_move_types
#-----------------------------------------------------------------------------
# Description:
#              Returns an array (ready for drop-down usage) of the moves
#              a player can make
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Valid Moves Array     OUT:0 Tech ID if the player is getting, 0 otherwise
# Player ID             IN:0  The player ID to look up
# Square Type           IN:1  The square type
# Major                 IN:2  This is a major square
# Units Available       IN:3  The number of units available to move
# Money Available       IN:4  The amount of money in the bank to spend
#-----------------------------------------------------------------------------
sub get_player_allowed_move_types
{
   my $self          =  shift;
   my $player_ID     = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'player ID missing in get_player_allowed_move_types');
   my $square_type   = $_[1] || 0;
   my $major         = $_[2] || 0;
   my $units         = $_[3];
   $units = -1 unless(defined($units));
   my $money         = $_[4];
   $money = -1 unless(defined($money));

   my @moves;
   my ($error_code, $move_details) = $self->db_select('get_move_details',
       {'move_type_const' => $self->config('move_type_const_table')});
   if($error_code)
   {
      $self->throw_error($error_code,
         "Select error in CommonTools->get_player_allowed_move_types");
   }
   unless(defined($move_details))
   {
      $self->throw_error(ERROR_DB_RESULTS,
         "Select returned no results in CommonTools->get_player_allowed_move_types");
   }

   foreach my $tech_map (@{$move_details})
   {
      if($tech_map->{'ID'} == MOVE_TYPE_BRIDGE)
      {
         # Bridges cannot be built from sea
         if($tech_map->{'require_land_ID'} > 0 &&
                     $tech_map->{'require_land_ID'} == $square_type)
         {
            # Is land type not allowed
            next;
         }
         if($tech_map->{'require_land_ID'} < 0 &&
                     $tech_map->{'require_land_ID'} != -$square_type)
         {
            # Not correct land type
            next;
         }
      } else {
         # We only check major square if it isn't a bridge
         if(!$major && $tech_map->{'ID'} < 10)
         {
            # Expansion, but not a major square
            next;
         }
         if($tech_map->{'require_land_ID'} > 0 && 
            $tech_map->{'require_land_ID'} != $square_type)
         {
            # Not correct land type
            next;
         }
         if($tech_map->{'require_land_ID'} < 0 && 
            $tech_map->{'require_land_ID'} == -$square_type)
         {
            # Is land type not allowed
            next;
         }
      }
      if($tech_map->{'require_tech_ID'} != 0 &&
         !$self->player_has_technology($player_ID,$tech_map->{'require_tech_ID'}))
      {
         next;
      }
      # Check the number of units
      if($tech_map->{'ID'} < 10)
      {
         my $expansion_details;
         if($units >= 0 || $money >= 0)
         {
            ($error_code, $expansion_details) = 
               $self->get_expansion_details($tech_map->{'ID'});
            if($error_code)
            {
               $self->throw_error($error_code,
                  "Select error in CommonTools->get_player_allowed_move_types");
            }
         }
         if($units >= 0 && $expansion_details->{'unit_cost'} > $units)
         {
            # Not enough units
            next;
         }
         if($money >= 0 && $expansion_details->{'money_cost'} > $money)
         {
            # Not enough money
            next;
         }
      }
      push @moves, { 'ID'           => $tech_map->{'ID'},
                     'name'         => $tech_map->{'name'},
                     'mouse_over'   => $tech_map->{'description'}};
   }

   $self->debug_dumper(8,\@moves);
   return \@moves;
}

#-----------------------------------------------------------------------------
# Function:    get_expansion_details
#-----------------------------------------------------------------------------
# Description:
#              Returns the details of an expansion
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Error Code            OUT:0 Return code
# Details               OUT:1 Expansion details
# Expansion Type ID     IN:0  The expansion type to look up
#-----------------------------------------------------------------------------
sub get_expansion_details
{
   my $self          =  shift;
   my $expansion_ID  = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Expansion ID missing in get_expansion_details');

   my ($error_code, $expansion_details) = $self->db_select(
      'get_expansion_details_from_ID',
      {'expansion_type_const' => $self->config('expansion_type_const_table')},
      $expansion_ID
      );
   if($error_code)
   {
      $self->error(ERROR_SEVERITY_WARNING, $error_code,
         "Select error in CommonTools->get_expansion_details");
      return ($error_code,undef);
   }
   if(defined($expansion_details) && @{$expansion_details})
   {
      return (ERROR_NONE,$expansion_details->[0]);
   } else {
      $self->error(ERROR_SEVERITY_WARNING, $error_code,
         "Select error in CommonTools->get_expansion_details");
      return (ERROR_DB_RESULTS, undef);
   }
}

#-----------------------------------------------------------------------------
# Function:    get_player_allowed_expansions
#-----------------------------------------------------------------------------
# Description:
#              Returns an array (ready for drop-down usage) of the expansions
#              a player can build on this square
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Valid Moves Array     OUT:0 Tech ID if the player is getting, 0 otherwise
# Player ID             IN:0  The player ID to look up
# Square Type           IN:1  The square type
#-----------------------------------------------------------------------------
sub get_player_allowed_expansions
{
   my $self       =  shift;
   my $player_ID  = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'player ID missing in get_player_allowed_expansions');
   my $square_type = $_[1] || 0;

   my @expansions;
   my ($error_code, $expansion_details) = $self->db_select('get_expansion_details',
       {'expansion_type_const' => $self->config('expansion_type_const_table')});
   if($error_code)
   {
      $self->throw_error($error_code,
         "Select error in CommonTools->get_player_allowed_expansions");
   }
   unless(defined($expansion_details))
   {
      return [];
   }

   foreach my $tech_map (@{$expansion_details})
   {
      if($tech_map->{'require_land_ID'} > 0 && 
         $tech_map->{'require_land_ID'} != $square_type)
      {
         # Not correct land type
         next;
      }
      if($tech_map->{'require_land_ID'} < 0 && 
         $tech_map->{'require_land_ID'} == $square_type)
      {
         # Is land type not allowed
         next;
      }
      if($tech_map->{'require_tech_ID'} == 0 ||
         $self->player_has_technology($player_ID,$tech_map->{'require_tech_ID'}))
      {
         push @expansions, { 'ID'           => $tech_map->{'ID'},
                        'name'         => $tech_map->{'name'},
                        'mouse_over'   => $tech_map->{'description'}};
      }
   }

   $self->debug_dumper(8,\@expansions);
   return \@expansions;
}

#-----------------------------------------------------------------------------
# Function:    get_player_expansion_counts
#-----------------------------------------------------------------------------
# Description:
#              Returns an array (ready for drop-down usage) of the expansions
#              a player can build on this square
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Valid Moves Array     OUT:0 Tech ID if the player is getting, 0 otherwise
# Player ID             IN:0  The player ID to look up
#-----------------------------------------------------------------------------
sub get_player_expansion_counts
{
   my $self       =  shift;
   my $game_ID  = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Game ID missing in get_player_expansion_counts');
   my $player_ID  = $_[1] || $self->throw_error(ERROR_MISSING_PARAMETER,'player ID missing in get_player_expansion_counts');
   my $expansion_ID  = $_[2] || 0;

   my ($error_code, $expansion_counts);
   if($expansion_ID)
   {
      ($error_code, $expansion_counts) =
               $self->db_select('get_game_player_single_expansion_count',
                           {'game_board' => $self->config('game_board_table')},
                           $player_ID, $game_ID, $expansion_ID);
   } else {
      ($error_code, $expansion_counts) =
               $self->db_select('get_game_player_expansion_counts',
                           {'game_board' => $self->config('game_board_table')},
                           $player_ID, $game_ID);
   }
   if($error_code)
   {
      $self->throw_error($error_code,
         'Select error in CommonTools->get_player_expansion_counts');
   }
   my $count = 0;
   if(defined($expansion_counts) && @{$expansion_counts} > 0)
   {
      $count = $expansion_counts->[0]->{'number'};
   }
   
   return $count;
}

#-----------------------------------------------------------------------------
# Function:    get_player_units_on_expansion
#-----------------------------------------------------------------------------
# Description:
#              Returns the number of science points a playe is currently 
#              generating
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Units Count           OUT:0 The number of units player has on expansions
# Game ID               IN:0  The game ID to look up
# Player ID             IN:1  The player ID to look up
# Expansion Array       IN:2  The details on expansions to check
# points                IN:3  The starting points
#-----------------------------------------------------------------------------
sub get_player_units_on_expansion
{
   my $self       =  shift;
   my $game_ID  = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Game ID missing in get_player_units_on_expansion');
   my $player_ID  = $_[1] || $self->throw_error(ERROR_MISSING_PARAMETER,'player ID missing in get_player_units_on_expansion');
   my $expansion_multipliers = $_[2] || $self->throw_error(ERROR_MISSING_PARAMETER,'Multiplier array missing');
   my $points = $_[3] || 0;

   foreach my $expansion (@{$expansion_multipliers})
   {
      my ($error_code, $point_details) =
               $self->db_select('calculate_game_player_points',
                           {'game_board' => $self->config('game_board_table')},
                           $expansion->{'multiplier'},
                           $player_ID, $game_ID, $expansion->{'type_ID'});
      if($error_code)
      {
         $self->throw_error($error_code,
            'Select error in CommonTools->get_player_units_on_expansion');
      }
      if(defined($point_details) && @{$point_details})
      {
         my $new_points = $point_details->[0]->{'points'} || 0;
         $points += $new_points;
         $self->debug(8,"Player $player_ID got $points for expansion " .
            $expansion->{'type_ID'});
      }
   }
   
   return $points;
}

#-----------------------------------------------------------------------------
# Function:    get_player_science_points
#-----------------------------------------------------------------------------
# Description:
#              Returns the number of science points a playe is currently 
#              generating
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Science Points Count  OUT:0 The number of science points the player has gets
# Game ID               IN:0  The game ID to look up
# Player ID             IN:1  The player ID to look up
#-----------------------------------------------------------------------------
sub get_player_science_points
{
   my $self       =  shift;
   my $game_ID  = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Game ID missing in get_player_science_points');
   my $player_ID  = $_[1] || $self->throw_error(ERROR_MISSING_PARAMETER,'player ID missing in get_player_science_points');

   my $science_points = 1; # All players produce one science a turn
   my $science_expansions =
      [
         {'type_ID'  => EXPANSION_TYPE_RESEARCHCENTER,   'multiplier'  => 1},
         {'type_ID'  => EXPANSION_TYPE_SCHOOL,           'multiplier'  => 2},
         {'type_ID'  => EXPANSION_TYPE_UNIVERSITY,       'multiplier'  => 3}
      ];
   
   # First calculate the number of science points units in buildings create
   my $count = $self->get_player_units_on_expansion(
                  $game_ID,$player_ID,$science_expansions);
   $self->debug(8,"number of science points for units = $count / 9");
   
   $science_points += ($count / 9) if($count > 0);

   # Next calculate how many points come from just having the building
   foreach my $exp (@{$science_expansions})
   {
      $count = $self->get_player_expansion_counts(
            $game_ID,$player_ID,$exp->{'type_ID'});
      $self->debug(8,"number of science points for building = $count * " . 
         $exp->{'multiplier'});
      $count *= $exp->{'multiplier'};
      $science_points += $count;
   }
   $self->debug(8,"science points for player $player_ID = $science_points");
   return $science_points;
}

#-----------------------------------------------------------------------------
# Function:    get_player_irragation_units
#-----------------------------------------------------------------------------
# Description:
#              Returns the number of science points a playe is currently 
#              generating
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Units Count           OUT:0 The number of units player has on irragation
# Game ID               IN:0  The game ID to look up
# Player ID             IN:1  The player ID to look up
#-----------------------------------------------------------------------------
sub get_player_irragation_units
{
   my $self       =  shift;
   my $game_ID  = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Game ID missing in get_player_irragation_units');
   my $player_ID  = $_[1] || $self->throw_error(ERROR_MISSING_PARAMETER,'player ID missing in get_player_irragation_units');

   my $units = 0; # All players produce one science a turn
   my $irragation_expansions =
      [
         {'type_ID'  => EXPANSION_TYPE_IRRAGATION,   'multiplier'  => 1}
      ];
   
   return $self->get_player_units_on_expansion(
                  $game_ID,$player_ID,$irragation_expansions,$units);
}

#-----------------------------------------------------------------------------
# Function:    get_square_details
#-----------------------------------------------------------------------------
# Description:
#              Returns the details of a square
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# details               OUT:1 Number of units on square
# Game ID               IN:0  The game ID to get it from
# Column                IN:1  The column it is of
# Row                   IN:2  The row it is of
#-----------------------------------------------------------------------------
sub get_square_details
{
   my $self    =  shift;
   my $game_ID = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Game ID missing in get_square_details');
   my $column  = $_[1];
   unless(defined($column))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER,'Column missing in get_square_details');
   }
   my $row     = $_[2];
   unless(defined($row))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER,'Row missing in get_square_details');
   }

   my ($error_code, $details) = $self->db_select('get_square_details',
       {'game_board' => $self->config('game_board_table')},
      $game_ID,$column,$row);
   if($error_code)
   {
      $self->throw_error($error_code,
         "Select error in CommonTools->get_square_details");
   }
   unless(defined($details))
   {
      $self->throw_error(ERROR_DB_RESULTS,
         "Select returned no results in CommonTools->get_square_details");
   }

   return (ERROR_NONE,$details->[0]);
}

#-----------------------------------------------------------------------------
# Function:    get_square_effects
#-----------------------------------------------------------------------------
# Description:
#              Returns the effects on a square
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# details               OUT:1 Number of units on square
# Game ID               IN:0  The game ID to get it from
# Column                IN:1  The column it is of
# Row                   IN:2  The row it is of
#-----------------------------------------------------------------------------
sub get_square_effects
{
   my $self       =  shift;
   my $game_ID    = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Game ID missing in get_square_effects');
   my $column     = $_[1];
   my $with_names = $_[2] || 0;
   unless(defined($column))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER,'Column missing in get_square_effects');
   }
   my $row     = $_[2];
   unless(defined($row))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER,'Row missing in get_square_effects');
   }

   my ($error_code, $details);
   if($with_names)
   {
      ($error_code, $details) = $self->db_select(
          'get_square_effects_with_names',
         {'game_board'           => $self->config('game_board_table'),
          'square_effect_details'=> $self->config('square_effect_details_table'),
          'effect_type_const'    => $self->config('effect_type_const_table')
         },
         $game_ID,$column,$row);
   } else {
      ($error_code, $details) = $self->db_select('get_square_effects',
         {'game_board'             => $self->config('game_board_table'),
          'square_effect_details'  => $self->config('square_effect_details_table')
         },
         $game_ID,$column,$row);
   }
   if($error_code)
   {
      $self->throw_error($error_code,
         "Select error in CommonTools->get_square_effects");
   }
   unless(defined($details))
   {
      $details = [];
   }

   return (ERROR_NONE,$details);
}

#-----------------------------------------------------------------------------
# Function:    get_effect_squares
#-----------------------------------------------------------------------------
# Description:
#              Returns the square details for squares with an effect on
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# details               OUT:1 Array of squares with effect on
# Game ID               IN:0  The game ID to get it from
# Effect ID             IN:1  The effect to look for
#-----------------------------------------------------------------------------
sub get_effect_squares
{
   my $self    =  shift;
   my $game_ID = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Game ID missing in get_effect_squares');
   my $effect_ID = $_[1];

   my ($error_code, $details) = $self->db_select('get_all_square_effects',
      {'game_board'             => $self->config('game_board_table'),
       'square_effect_details'  => $self->config('square_effect_details_table')
      },
      $game_ID,$effect_ID);
   if($error_code)
   {
      $self->throw_error($error_code,
         "Select error in CommonTools->get_effect_squares");
   }
   unless(defined($details))
   {
      $details = [];
   }

   return (ERROR_NONE,$details);
}

#-----------------------------------------------------------------------------
# Function:    get_effect_count
#-----------------------------------------------------------------------------
# Description:
#              Returns the effects on a square
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# Squares count         OUT:1 Number of square with the effect on
# units count           OUT:2 Number of units on the effect squares
# Game ID               IN:0  The game ID to get it from
# Player ID             IN:1  The player ID to get it from
# Effect Type ID        IN:2  The effect to count
#-----------------------------------------------------------------------------
sub get_effect_count
{
   my $self    =  shift;
   my $game_ID = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Game ID missing in get_effect_count');
   my $player_ID = $_[1] || $self->throw_error(ERROR_MISSING_PARAMETER,'Player ID missing in get_effect_count');
   my $effect_type_ID = $_[2] || $self->throw_error(ERROR_MISSING_PARAMETER,'Effect Type ID missing in get_effect_count');

   my ($error_code, $details) = $self->db_select('get_player_effect_count',
      {'game_board'             => $self->config('game_board_table'),
       'square_effect_details'  => $self->config('square_effect_details_table')
      },
      $game_ID,$player_ID,$effect_type_ID);
   if($error_code)
   {
      $self->throw_error($error_code,
         "Select error in CommonTools->get_effect_count");
   }
   my ($square_count,$unit_count) = (0,0);
   if(defined($details) && @{$details})
   {
      $square_count = $details->[0]->{'square_number'};
      $unit_count = $details->[0]->{'unit_number'};
   }

   return (ERROR_NONE,$square_count,$unit_count);
}

#-----------------------------------------------------------------------------
# Function:    adjust_units_with_effect
#-----------------------------------------------------------------------------
# Description:
#              Modifys all squares units in game that have appropriate effect
#              Units can never leave the range 0 - 9
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Owner                 OUT:0 True if owner of a scout on this square
# Game ID               IN:0  The game ID to look up
# Column                IN:1  The column to look up
# Row                   IN:2  The row to look up
# Owner ID              IN:3  The owner to check for
#-----------------------------------------------------------------------------
sub adjust_units_with_effect
{
   my $self       =  shift;
   my $game_ID    = $_[0];
   my $effect_ID  = $_[1];
   my $adjust     = $_[2];

   my $details = $self->get_effect_squares($game_ID,$effect_ID);
   foreach my $square (@{$details})
   {
      my $error_code = $self->db_update($self->config('game_board_table'), 
                           {'#units'   => "units - $adjust"},
                           {'game_ID'  => $game_ID,
                            'row'      => $square->{'row'},
                            'column'   => $square->{'column'}
                           }
                          );
      if($error_code)
      {
         $self->error(ERROR_SEVERITY_WARNING,$error_code,'Update failed');
      }
      $error_code = $self->db_update($self->config('game_board_table'), 
                           {'units'    => 0},
                           {'game_ID'  => $game_ID,
                            'row'      => $square->{'row'},
                            'column'   => $square->{'column'},
                            '<units'   => 0
                           }
                          );
      if($error_code)
      {
         $self->error(ERROR_SEVERITY_WARNING,$error_code,'Update failed');
      }
      $error_code = $self->db_update($self->config('game_board_table'), 
                           {'units'    => 9},
                           {'game_ID'  => $game_ID,
                            'row'      => $square->{'row'},
                            'column'   => $square->{'column'},
                            '>units'   => 9
                           }
                          );
      if($error_code)
      {
         $self->error(ERROR_SEVERITY_WARNING,$error_code,'Update failed');
      }
   }
}

#-----------------------------------------------------------------------------
# Function:    is_scout_owner
#-----------------------------------------------------------------------------
# Description:
#              Returns if this square contains a scout owned by owner passed in
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Owner                 OUT:0 True if owner of a scout on this square
# Game ID               IN:0  The game ID to look up
# Column                IN:1  The column to look up
# Row                   IN:2  The row to look up
# Owner ID              IN:3  The owner to check for
#-----------------------------------------------------------------------------
sub is_scout_owner
{
   my $self       =  shift;
   my $game_ID    = $_[0];
   my $column     = $_[1];
   my $row        = $_[2];
   my $owner_ID   = $_[3];
   $self->debug(8, 'CommonTools->is_scout_owner ' . 
      "$game_ID,$row,$column,$owner_ID");

   my ($error_code,$square_effects) = 
      $self->get_square_effects($game_ID,$column,$row);
   if($error_code)
   {
      $self->throw_error($error_code,
         "Select error in CommonTools->is_scout_owner");
   }
   unless(defined($square_effects))
   {
      $self->throw_error(ERROR_DB_RESULTS,
         "Select returned no results in CommonTools->is_scout_owner");
   }

   my $found = 0;
   foreach my $effect (@{$square_effects})
   {
      if($effect->{'effect_type_ID'} == EFFECT_TYPE_SCOUT ||
         $effect->{'effect_type_ID'} == EFFECT_TYPE_SUICIDAL_SCOUT ||
         $effect->{'effect_type_ID'} == EFFECT_TYPE_KAMIKAZE_SCOUT)
      {
         $found ||= $effect->{'effect_owner_ID'} == $owner_ID;
      }
   }
   $self->debug(8, 'is_scout_owner ' . $found?'Yes':'No');
   
   return $found;
}

#-----------------------------------------------------------------------------
# Function:    land_type
#-----------------------------------------------------------------------------
# Description:
#              Returns the land type of a square in a game
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Land Type ID          OUT:0 The land type identifier of the square
# Game ID               IN:0  The game ID to look up
# Column                IN:1  The column to look up
# Row                   IN:2  The row to look up
#-----------------------------------------------------------------------------
sub land_type
{
   my $self    =  shift;
   my $game_ID = $_[0];
   my $column  = $_[1];
   my $row     = $_[2];
   $self->debug(8, 'CommonTools->land_type ' . "$game_ID,$row,$column");

   my ($error_code, $details) = $self->db_select('get_square_details',
       {'game_board' => $self->config('game_board_table')},
      $game_ID,$column,$row);
   if($error_code)
   {
      $self->throw_error($error_code,
         "Select error in CommonTools->land_type");
   }
   unless(defined($details))
   {
      $self->throw_error(ERROR_DB_RESULTS,
         "Select returned no results in CommonTools->land_type");
   }

   return $details->[0]->{'land_type'};
}

#-----------------------------------------------------------------------------
# Function:    land_type_name
#-----------------------------------------------------------------------------
# Description:
#              Returns the land type name for a land type ID
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Land Type Name        OUT:0 The land type name
# Land Type ID          IN:0  The land type ID to look up
#-----------------------------------------------------------------------------
sub land_type_name
{
   my $self          =  shift;
   my $land_type_ID  = $_[0];
   $self->debug(8, 'CommonTools->land_type_name ' . "$land_type_ID");

   my $name = '';
   if($land_type_ID < 0)
   {
      $name = 'Not ';
      $land_type_ID = -$land_type_ID;
   }
   if($land_type_ID == LAND_TYPE_SEA)
   {
      $name .= 'Sea';
   } elsif($land_type_ID == LAND_TYPE_PLAINS) {
      $name .= 'Plains';
   } elsif($land_type_ID == LAND_TYPE_MOUNTAIN) {
      $name .= 'Mountain';
   } elsif($land_type_ID == LAND_TYPE_FOREST) {
      $name .= 'Forest';
   } elsif($land_type_ID == LAND_TYPE_ANY) {
      $name .= 'Any';
   } else {
      $name .= '?';
   }
   
   return $name;
}

#-----------------------------------------------------------------------------
# Function:    player_moved_units_for_square
#-----------------------------------------------------------------------------
# Description:
#              Returns the land type name for a land type ID
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# All Units Moved       OUT:0 The land type name
# Game ID               IN:0  
# Player ID             IN:1  
# Column                IN:2  
# Row                   IN:3  
# Required Units Moved  IN:4
#-----------------------------------------------------------------------------
sub player_moved_units_for_square
{
   my $self       =  shift;
   my $game_ID    = $_[0];
   my $player_ID  = $_[1];
   my $column     = $_[2];
   my $row        = $_[3];
   my $move_units = $_[4] || return 1; # No required amount, so we pass

   $self->debug(8, 'CommonTools->player_moved_units_for_square ' . "$game_ID,$player_ID,$column,$row,$move_units");

   my ($error_code, $used_units, $incoming_recruits, $incoming_units) =
      $self->get_square_move_breakdown($game_ID, $column, $row, $player_ID);

   if($used_units >= $move_units)
   {
      return 1;
   } else {
      return 0;
   }
}

#-----------------------------------------------------------------------------
# Function:    get_units
#-----------------------------------------------------------------------------
# Description:
#              Returns the number of units, and player ID of the square
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# units                 OUT:1 Number of units on square
# player_ID             OUT:2 Player ID of square owner (0 is not owned)
# Game ID               IN:0  The game ID to get it from
# Column                IN:1  The column it is of
# Row                   IN:2  The row it is of
# Modifier              IN:3  If set, adjusts for defensive modifiers
# Pending Board         IN:4  If set, gets the pending board units instead
#-----------------------------------------------------------------------------
sub get_units
{
   my $self    =  shift;
   my $game_ID = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Game ID missing in get_units');
   my $column  = $_[1];
   unless(defined($column))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER,'Column missing in get_units');
   }
   my $row     = $_[2];
   unless(defined($row))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER,'Row missing in get_units');
   }
   my $modifier   = $_[3] || 0;
   my $pending_board = $_[4] || 0;

   $self->debug(8, "CommonTools->get_units $game_ID,$column,$row,$modifier,$pending_board");

   my ($error_code, $details);
   if($pending_board)
   {
      ($error_code, $details) = $self->db_select('get_processing_board_details',
          {'processing_board' => $self->config('processing_board_table')},
         $column,$row);
   } else {
      ($error_code, $details) = $self->db_select('get_square_details',
          {'game_board' => $self->config('game_board_table')},
         $game_ID,$column,$row);
   }
   if($error_code)
   {
      $self->throw_error($error_code,
         "Select error in CommonTools->get_units");
   }
   unless(defined($details))
   {
      $self->throw_error(ERROR_DB_RESULTS,
         "Select returned no results in CommonTools->get_units");
   }

   my $units = $details->[0]->{'units'};
   my $owner_ID = 0;
   unless($pending_board)
   {
      $owner_ID = $details->[0]->{'owner_ID'};

      if($modifier)
      {
         # Adjust for defensive modifier
         # ....
      }
   }
   
   $self->debug(8, "get_units returns $units units belonging to $owner_ID");
   return (ERROR_NONE,$units, $owner_ID);
}

#-----------------------------------------------------------------------------
# Function:    set_units
#-----------------------------------------------------------------------------
# Description:
#              Sets the units on a game square (or in the pending move)
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# Game ID               IN:0  The game ID to set it in
# Number                IN:1  The number to set it to
# Column                IN:2  The column it is on
# Row                   IN:3  The row it is on
# Pending Board         IN:4  If set, sets the pending board units instead
#-----------------------------------------------------------------------------
sub set_units
{
   my $self    =  shift;
   my $game_ID = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Game ID missing in set_units');
   my $units   = $_[1];
   unless(defined($units))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER,'Units missing in set_units');
   }
   my $column  = $_[2];
   unless(defined($column))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER,'Column missing in set_units');
   }
   my $row     = $_[3];
   unless(defined($row))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER,'Row missing in set_units');
   }

   my $pending_board = $_[4] || 0;
   $self->debug(8, "CommonTools->set_units $game_ID,$units,$column,$row,$pending_board");

   if($units < 0)
   {
      # Not a valid number of units
      $self->error(ERROR_SEVERITY_ERROR, ERROR_INVALID_PARAMETER,
         "Number of units invalid $units, at $column, $row, game $game_ID");
      return (ERROR_INVALID_PARAMETER, $units);
   }
   if($units > 9)
   {
      $units = 9;
   }
   
   my $update =
       {
          'units'  => $units
       };
   my $search =
      {  
         'across'    => $column,
         'down'      => $row
      };
   my $table_name;
   if($pending_board)
   {
      $table_name = $self->config('processing_board_table');
   } else {
      $table_name = $self->config('game_board_table');
      $search->{'game_ID'} = $game_ID;
   }
   my $error_code = $self->db_update($table_name, $update, $search);
   if($error_code)
   {
       $self->throw_error($error_code,
          "Update error in CommonTools->set_units");
   }
   
   return (ERROR_NONE,$units);
}

#-----------------------------------------------------------------------------
# Function:    clear_ownerships
#-----------------------------------------------------------------------------
# Description:
#              Resets ownership of squares that need resetting. e.g. Sea
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# Game ID               IN:0  The game ID to set it in
#-----------------------------------------------------------------------------
sub clear_ownerships
{
   my $self    =  shift;
   my $game_ID = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Game ID missing in clear_ownerships');
   
   my $update =
       {
          'owner_ID'  => 0
       };
   my $search =
      {  
         'game_ID'            => $game_ID,
         'expansion_type_ID'  => 0,
         'units'              => 0,
         'land_type_ID'       => LAND_TYPE_SEA
      };
   my $table_name = $self->config('game_board_table');
   my $error_code = $self->db_update($table_name, $update, $search);
   if($error_code)
   {
       $self->throw_error($error_code,
          "Update error in CommonTools->clear_ownerships");
   }
   
   return (ERROR_NONE);
}

#-----------------------------------------------------------------------------
# Function:   decrease_recruits 
#-----------------------------------------------------------------------------
# Description:
#              Decreases the number of recruits a player has
#              Can be used to increase with a negative unit value
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# Game ID               IN:0  The game ID to set it in
# Number                IN:1  The number to set it to
# Column                IN:2  The column it is on
# Row                   IN:3  The row it is on
# Pending Board         IN:4  If set, sets the pending board units instead
#-----------------------------------------------------------------------------
sub decrease_recruits
{
   my $self    =  shift;
   my $player_ID = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'player ID missing in decrease_recruits');
   my $units   = $_[1];
   unless(defined($units))
   {
      $self->error(ERROR_SEVERITY_WARNING,ERROR_MISSING_PARAMETER,
         'No units passed in to decrease_recruits');
      return ERROR_MISSING_PARAMETER;
   } 
   $self->debug(9, "Decreasing recruits for player $player_ID by $units");
   
   my $error_code = $self->db_update($self->config('game_player_table'), 
                           {'#recruits_left'  => "recruits_left - $units"},
                           {'ID'    => $player_ID}
                          );
   if($error_code)
   {
      $self->error(ERROR_SEVERITY_WARNING,$error_code,'Update failed');
   }
   return $error_code;
}

#-----------------------------------------------------------------------------
# Function:    add_expansion_to_square
#-----------------------------------------------------------------------------
# Description:
#              Adds an expansion in a game for a player on a major square
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# Game ID               IN:0  The game ID to set it in
# Expansion ID          IN:1  The expansion to assign
# Column                IN:2  The column it is on
# Row                   IN:3  The row it is on
# Build Time            IN:4  The turns left to build
# Hit Points            IN:5  The hit points left util destrucion
#-----------------------------------------------------------------------------
sub add_expansion_to_square
{
   my $self          =  shift;
   my $game_ID       = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Game ID missing in add_expansion_to_square');
   my $expansion_ID  = $_[1] || $self->throw_error(ERROR_MISSING_PARAMETER,'Expansion ID missing in add_expansion_to_square');
   my $column        = $_[2];
   unless(defined($column))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER,'Column missing in add_expansion_to_square');
   }
   my $row           = $_[3];
   unless(defined($row))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER,'Row missing in add_expansion_to_square');
   }
   my $to_build      = $_[4] || 0;
   my $hp            = $_[5];
   $hp = $self->config('expansion_hp') unless(defined($hp));
   my $set_player    = $_[6] || 0;

   $self->debug(8, "add_expansion_to_square ($game_ID,$expansion_ID,$column,$row,$to_build,$hp,$set_player)");
   
   unless(($row + $column) % 2)
   {
      # Not a major square
      $self->error(ERROR_SEVERITY_ERROR,ERROR_INVALID_PARAMETER,
            "add_expansion_to_square: Not a major square");
      return ERROR_INVALID_PARAMETER;
   }

   my ($error_code, $details) = 
      $self->get_square_details($game_ID,$column,$row);
   return $error_code if($error_code);
   if($details->{'expansion_type_ID'} != 0)
   {
      # Already has an expansion
      $self->error(ERROR_SEVERITY_ERROR,ERROR_INVALID_PARAMETER,
            "add_expansion_to_square: Already has expansion");
      return ERROR_INVALID_PARAMETER;
   }
   
   my $update =
       {
          'expansion_type_ID' => $expansion_ID,
          'expansion_hp'      => $hp,
          'expansion_to_build'=> $to_build
       };
   if($set_player > 0)
   {
      $update->{'owner_ID'} = $set_player;
   }
   $error_code = $self->db_update($self->config('game_board_table'), 
                                    $update,
                                    {  'game_ID'   => $game_ID,
                                       'across'    => $column,
                                       'down'      => $row
                                    });
   if($error_code)
   {
       $self->throw_error($error_code,
          "Update error in CommonTools->add_expansion_to_square");
   }
   
   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function:    damage_expansion_on_square
#-----------------------------------------------------------------------------
# Description:
#              Damages th expansion on the square
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# Game ID               IN:0  The game ID to set it in
# Expansion ID          IN:1  The expansion to assign
# Column                IN:2  The column it is on
# Row                   IN:3  The row it is on
#-----------------------------------------------------------------------------
sub damage_expansion_on_square
{
   my $self          =  shift;
   my $game_ID       = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Game ID missing in damage_expansion_on_square');
   my $damage        = $_[1] || return ERROR_NONE;
   my $column        = $_[2];
   unless(defined($column))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER,'Column missing in damage_expansion_on_square');
   }
   my $row           = $_[3];
   unless(defined($row))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER,'Row missing in damage_expansion_on_square');
   }

   unless(($row + $column) % 2)
   {
      # Not a major square
      return ERROR_INVALID_PARAMETER;
   }
   
   my ($error_code, $details) = 
      $self->get_square_details($game_ID,$column,$row);
   return $error_code if($error_code);

   return ERROR_NONE unless($details->{'expansion_type_ID'});
   
   my $hp = $details->{'expansion_hp'};
   $hp -= $damage;
   $hp = 0 if($hp <= 0);
   
   my $update =
       {
          'expansion_hp'  => $hp
       };
   if($hp == 0)
   {
      # Remove the expansion too
      $update->{'expansion_type_ID'} = 0;
   }
   $error_code = $self->db_update($self->config('game_board_table'), 
                                    $update,
                                    {  'game_ID'   => $game_ID,
                                       'across'    => $column,
                                       'down'      => $row
                                    });
   if($error_code)
   {
       $self->throw_error($error_code,
          "Update error in CommonTools->damage_expansion_on_square");
   }
   
   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function:    add_effect_to_square
#-----------------------------------------------------------------------------
# Description:
#              Adds an effect in a game for a player
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# Game ID               IN:0  The game ID to set it in
# Effect ID             IN:1  The effect to assign
# Column                IN:2  The column it is on
# Row                   IN:3  The row it is on
# Owner                 IN:4  The owner of the effect
# Turns                 IN:5  The number of turns the effect lasts for
#-----------------------------------------------------------------------------
sub add_effect_to_square
{
   my $self          =  shift;
   my $game_ID       = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Game ID missing in add_effect_to_square');
   my $effect_ID  = $_[1] || $self->throw_error(ERROR_MISSING_PARAMETER,'Expansion ID missing in add_effect_to_square');
   my $column        = $_[2];
   unless(defined($column))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER,'Column missing in add_effect_to_square');
   }
   my $row           = $_[3];
   unless(defined($row))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER,'Row missing in add_effect_to_square');
   }
   my $owner_ID      = $_[4];
   my $turns_left    = $_[5];

   my ($error_code, $details) = 
      $self->get_square_details($game_ID,$column,$row);
   if($error_code)
   {
       $self->throw_error($error_code,
          "Error in CommonTools->add_effect_to_square getting square details");
   }
   
   ($error_code,undef) = $self->db_insert(
                                 $self->config('square_effect_details_table'), 
                                 {  'game_ID'         => $game_ID,
                                    'game_board_ID'   => $details->{'ID'},
                                    'effect_type_ID'  => $effect_ID,
                                    'turns_left'      => $turns_left,
                                    'owner_ID'        => $owner_ID
                                 });
   if($error_code)
   {
       $self->throw_error($error_code,
          "Insert error in CommonTools->add_effect_to_square");
   }
   
   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function:    get_square_moves
#-----------------------------------------------------------------------------
# Description:
#              Gets all the incoming units, outgoing units,
#              and other moves that are to occur on the square
#              Optionally limited to a player
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# Move List             OUT:1 An array of moves
# Game ID               IN:0  The game ID to set it in
# Column                IN:1  The column to get the moves of
# Row                   IN:2  The Row to get the moves of
# Player                IN:3  The optional player to restrict the results to
#-----------------------------------------------------------------------------
sub get_square_moves
{
   my $self          =  shift;
   my $game_ID       = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Game ID missing in get_square_moves');
   my $column        = $_[1];
   unless(defined($column))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER,'Column missing in get_square_moves');
   }
   my $row           = $_[2];
   unless(defined($row))
   {
      $self->throw_error(ERROR_MISSING_PARAMETER,'Row missing in get_square_moves');
   }
   my $player_ID     = $_[3] || 0;
   $self->debug(9, 'CommonTools->get_square_moves');

   my ($error_code, $moves);
   if($player_ID)
   {
      ($error_code, $moves) = 
         $self->db_select('get_game_square_moves_for_player',
            {'game_board_move' => $self->config('game_board_move_table')},
            $game_ID, $player_ID, $column, $row, $column, $row);
   } else {
      ($error_code, $moves) = 
         $self->db_select('get_game_square_moves',
            {'game_board_move' => $self->config('game_board_move_table')},
            $game_ID, $column, $row, $column, $row);
   }
   if($error_code)
   {
      $self->throw_error($error_code,
         'Select error in CommonTools->get_square_moves');
   }
   
   return ($error_code, $moves);
}

#-----------------------------------------------------------------------------
# Function:    check_new_messages
#-----------------------------------------------------------------------------
# Description:
#              Sets the units on a game square (or in the pending move)
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# Game ID               IN:0  The game ID to set it in
# Number                IN:1  The number to set it to
# Column                IN:2  The column it is on
# Row                   IN:3  The row it is on
# Pending Board         IN:4  If set, sets the pending board units instead
#-----------------------------------------------------------------------------
sub check_new_messages
{
   my $self    =  shift;
   my $member_ID = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Member ID missing in check_new_messages');
   $self->debug(8, "CommonTools->check_new_messages $member_ID");

   my ($error_code,$details) = $self->db_select('check_for_new_messages',
         {'message' => $self->config('message_table')},
         $member_ID);
      
   if($error_code)
   {
       $self->throw_error($error_code,
          "Update error in CommonTools->check_new_messages");
   }
   if($details->[0]->{'number'} > 0)
   {
      $self->{'tmpl_vars'}->{'new_messages'} = $details->[0]->{'number'};
      $self->debug(8, "Member $member_ID has " . $details->[0]->{'number'} . " messages unread");
   }
   
   return (ERROR_NONE);
}

#-----------------------------------------------------------------------------
# Function:    set_read_message
#-----------------------------------------------------------------------------
# Description:
#              Sets the units on a game square (or in the pending move)
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# Game ID               IN:0  The game ID to set it in
# Number                IN:1  The number to set it to
# Column                IN:2  The column it is on
# Row                   IN:3  The row it is on
# Pending Board         IN:4  If set, sets the pending board units instead
#-----------------------------------------------------------------------------
sub set_read_message
{
   my $self    =  shift;
   my $message_ID = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Message ID missing in set_read_message');
   $self->debug(8, "CommonTools->set_read_message $message_ID");

   my $update =
       {
          'been_read'  => '1',
          '#read_date_time' => 'NOW()'
       };
   my $search =
      {  
         'ID'    => $message_ID
      };
   my $error_code = $self->db_update($self->config('message_table'),
      $update, $search);
   if($error_code)
   {
       $self->throw_error($error_code,
          "Update error in CommonTools->set_read_message");
   }
   
   return (ERROR_NONE);
}

#-----------------------------------------------------------------------------
# Function:    set_replied_message
#-----------------------------------------------------------------------------
# Description:
#              Sets the units on a game square (or in the pending move)
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# Game ID               IN:0  The game ID to set it in
# Number                IN:1  The number to set it to
# Column                IN:2  The column it is on
# Row                   IN:3  The row it is on
# Pending Board         IN:4  If set, sets the pending board units instead
#-----------------------------------------------------------------------------
sub set_replied_message
{
   my $self    =  shift;
   my $message_ID = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Message ID missing in set_replied_message');
   $self->debug(8, "CommonTools->set_replied_message $message_ID");

   my $update =
       {
          'replied'  => '1'
       };
   my $search =
      {  
         'ID'    => $message_ID
      };
   my $error_code = $self->db_update($self->config('message_table'),
      $update, $search);
   if($error_code)
   {
       $self->throw_error($error_code,
          "Update error in CommonTools->set_replied_message");
   }
   
   return (ERROR_NONE);
}

#-----------------------------------------------------------------------------
# Function:    next_turn
#-----------------------------------------------------------------------------
# Description:
#              Moves the game on one turn
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# Game ID               IN:0  The game ID to set it in
#-----------------------------------------------------------------------------
sub next_turn
{
   my $self          =  shift;
   my $game_ID       = $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER,'Game ID missing in next_turn');
   $self->debug(9, 'CommonTools->next_turn');

   my $game_details = $self->get_game_details($game_ID);
   unless(defined($game_details))
   {
      $self->error(ERROR_SEVERITY_ERROR, ERROR_MISSING_PARAMETER,
         'Invalid game ID ' . $game_ID);
      return ERROR_INVALID_PARAMETER;
   }
   
   my @time = gmtime(time + ($game_details->{'turn_frequency_hours'} * 3600));
   my $error_code = $self->calculate_next_turn(\@time,
               $game_details->{'frequency_weekday_type_ID'},
               $game_details->{'turn_start_time'},
               $game_details->{'turn_stop_time'},
            );
   return $error_code if($error_code);
   
   my $next_turn = sprintf("%04d-%02d-%02d %02d:%02d:%02d",
               $time[5]+1900,$time[4]+1,$time[3],$time[2],$time[1],$time[0]);
   
   my $update =
      {
         'turn'     => $game_details->{'turn'} + 1,
         'next_turn' => $next_turn
      };
   if($game_details->{'max_turns'} && 
      $game_details->{'turn'} >= $game_details->{'max_turns'})
   {
      $update->{'done'} = 1;
   }

   $error_code = $self->db_update($self->config('game_table'),
                                      $update,
                                      {   'ID'  => $game_ID});
   
   return $error_code;
}

#-----------------------------------------------------------------------------
# Function:    calculate_next_turn
#-----------------------------------------------------------------------------
# Description:
#              Calucates when the next turn will be
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# Time Array            IN:0  The game ID to set it in
# Frequency Type        IN:1  The type of frequency (w/days,w/ends,all)
# Start Time            IN:2  The time turns start
# End Time              IN:3  The time turns end
#-----------------------------------------------------------------------------
sub calculate_next_turn
{
   my $self                      =  shift;
   my $time                      = $_[0];
   my $frequency_weekday_type_ID = $_[1];
   my $turn_start_time           = $_[2];
   my $turn_stop_time            = $_[3];
   $self->debug(9, 'CommonTools->calculate_next_turn');

   my $non_stop = 0;
   $non_stop = 1 if($turn_start_time eq $turn_stop_time);

   # Check for 24/7, if so, always return
   if($non_stop && $frequency_weekday_type_ID == FREQUENCY_TYPE_ALL)
   {
      return ERROR_NONE;
   }

   # Check times and days
   return $self->check_times_and_day($time, 
      $turn_start_time, $turn_stop_time, $frequency_weekday_type_ID);
}

#-----------------------------------------------------------------------------
# Function:    make_turn_day
#-----------------------------------------------------------------------------
# Description:
#              Forces the day, to a turn day, if it isn't already
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# Time Array            IN:0  The game ID to set it in
# Frequency Type        IN:1  The type of frequency (w/days,w/ends,all)
#-----------------------------------------------------------------------------
sub make_turn_day
{
   my $self                      =  shift;
   my $time                      = $_[0];
   my $frequency_weekday_type_ID = $_[1];
   $self->debug(9, 'CommonTools->make_turn_day');

   return ERROR_NONE if($frequency_weekday_type_ID == FREQUENCY_TYPE_ALL);

   if($frequency_weekday_type_ID == FREQUENCY_TYPE_WEEKENDS)
   {
      if($time->[6] == 0 || $time->[6] == 6)
      {
         # Weekend
         $self->debug(8,"Day already moved to a valid weekend day");
         return ERROR_NONE;
      } else {
         # Weekday
         $self->debug(8,"Day moving to a valid weekend day");
         return $self->increase_to_day(6,$time);
      }
   } elsif($frequency_weekday_type_ID == FREQUENCY_TYPE_WEEKDAYS) {
      if($time->[6] == 0 || $time->[6] == 6)
      {
         # Weekend
         $self->debug(8,"Day moving to a valid week day");
         return $self->increase_to_day(1,$time);
      } else {
         # Weekday
         $self->debug(8,"Day already moved to a valid week day");
         return ERROR_NONE;
      }
   }
   
   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function:    increase_to_day
#-----------------------------------------------------------------------------
# Description:
#              Forces the day, to a turn day, if it isn't already
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# Day                   IN:0  The day to increase to (0 Sunday)
# Time Array            IN:1  The game ID to set it in
# --------------------- ----- ------------------------------------------------
sub increase_to_day
{
   my $self   =  shift;
   my $day    = $_[0];
   my $time   = $_[1];
   $self->debug(9, 'CommonTools->increase_to_day');

   return ERROR_INVALID_PARAMETER if($day < 0 || $day > 6);
   
   my $int_time = timelocal(@{$time});
   my $temp_days = $time->[6];
   my $inc_days = 0;
   while($temp_days != $day)
   {
      $temp_days++;
      $inc_days++;
      $temp_days = 0 if($temp_days > 6);
   }
   $int_time = $int_time + ($inc_days * 60 * 60 * 24);
    
   @{$time} = localtime($int_time);
   # And set to midnight
   $time->[0] = $time->[1] = $time->[2] = 0;
   
   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function:    check_times_and_day
#-----------------------------------------------------------------------------
# Description:
#              Forces the time to be before stop time or after start
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# Time Array            IN:0  The game ID to set it in
# Start Time            IN:1  The time that time must be after
# Stop Time             IN:2  The time that time must be before
# Frequency Type        IN:3  The day type that is allowed
#-----------------------------------------------------------------------------
sub check_times_and_day
{
   my $self                      =  shift;
   my $time                      = $_[0];
   my $start_time                = $_[1];
   my $stop_time                 = $_[2];
   my $frequency_weekday_type_ID = $_[3];
   $self->debug(9, 'CommonTools->check_times_and_day');

   unless($start_time =~ /(\d{1,2}):(\d{1,2}):(\d{1,2})/)
   {
      $self->error(ERROR_SEVERITY_ERROR, ERROR_INVALID_PARAMETER,
         "Invalid time one '$start_time' in time_compare");
      return ERROR_INVALID_PARAMETER;
   }
   my ($start_time_hour, $start_time_min, $start_time_sec) = ($1,$2,$3);
   unless($stop_time =~ /(\d{1,2}):(\d{1,2}):(\d{1,2})/)
   {
      $self->error(ERROR_SEVERITY_ERROR, ERROR_INVALID_PARAMETER,
         "Invalid time two '$stop_time' in time_compare");
      return ERROR_INVALID_PARAMETER;
   }
   my ($stop_time_hour, $stop_time_min, $stop_time_sec) = ($1,$2,$3);

   my $int_start_time = ($start_time_hour * 3600) + 
                        ($start_time_min * 60) + $start_time_sec;
   my $int_stop_time = ($stop_time_hour * 3600) + 
                        ($stop_time_min * 60) + $stop_time_sec;
   my $time_compare = $int_start_time - $int_stop_time;
   
   if($time_compare == 0)
   {
      # Times are the same, so just check the day
      $self->debug(8,"Continous turn in time");
      return $self->make_turn_day($time, $frequency_weekday_type_ID);
   }
   my $int_next_time = ($time->[2] * 3600) + ($time->[1] * 60) + $time->[0];
   if($time_compare < 0)
   {
      $self->debug(8,"Start time ($int_start_time) before end time ($int_stop_time), Next Time ($int_next_time)");
      # Times same day
      if($int_next_time < $int_start_time)
      {
         $self->debug(8,"Setting time to start time and check day valid");
         $self->make_turn_day($time, $frequency_weekday_type_ID);
         $time->[2] = $start_time_hour;
         $time->[1] = $start_time_min;
         $time->[0] = $start_time_sec;
      } elsif($int_next_time > $int_stop_time) {
         # move the day on one day
         $self->debug(8,"Moving day on");
         $self->increase_to_day(($time->[6] + 1) % 7,$time);
         # Make sure we are a valid day
         $self->debug(8,"Checking valid day");
         $self->make_turn_day($time, $frequency_weekday_type_ID);
         # Move the time to the start time
         $self->debug(8,"Setting time to start time on selected day");
         $time->[2] = $start_time_hour;
         $time->[1] = $start_time_min;
         $time->[0] = $start_time_sec;
      }
   } else {
      $self->debug(8,"Start time ($int_start_time) after end time ($int_stop_time) (over midnight)");
      # Times over midnight
      unless($int_next_time > $int_start_time || 
               $int_next_time < $int_stop_time)
      {
         # Outside time range, so move the time to the start time
         $self->debug(8,"Setting time to start time, assiming day correct");
         $time->[2] = $start_time_hour;
         $time->[1] = $start_time_min;
         $time->[0] = $start_time_sec;
      }
   }
   
   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function:    time_compare
#-----------------------------------------------------------------------------
# Description:
#              Returns the comparison of two times
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Comparison            OUT:0 0 => same, -ve time1 before, +ve time1 after
# time 1                IN:0  First time to compare
# time 2                IN:1  Second time to compare
# --------------------- ----- ------------------------------------------------
sub time_compare
{
   my $self    =  shift;
   my $time1   = $_[0];
   my $time2   = $_[1];
   $self->debug(9, 'CommonTools->time_compare');

   unless($time1 =~ /(\d{1,2}):(\d{1,2}):(\d{1,2})/)
   {
      $self->error(ERROR_SEVERITY_ERROR, ERROR_INVALID_PARAMETER,
         "Invalid time one '$time1' in time_compare");
      return 0;
   }
   my ($t1_hour, $t1_min, $t1_sec) = ($1,$2,$3);
   unless($time2 =~ /(\d{1,2}):(\d{1,2}):(\d{1,2})/)
   {
      $self->error(ERROR_SEVERITY_ERROR, ERROR_INVALID_PARAMETER,
         "Invalid time two '$time2' in time_compare");
      return 0;
   }
   my ($t2_hour, $t2_min, $t2_sec) = ($2,$2,$3);

   my $int_time1 = ($t1_hour * 3600) + ($t1_min * 60) + $t1_sec;
   my $int_time2 = ($t2_hour * 3600) + ($t2_min * 60) + $t2_sec;
   
   return ($int_time1 - $int_time2);
}

#-----------------------------------------------------------------------------
# Function:    get_square_move_breakdown
#-----------------------------------------------------------------------------
# Description:
#              Returns the comparison of two times
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 if no error, error code otherwise
# Used Units            OUT:1 Units on this square that have been used
# Incoming Recruits     OUT:2 Incoming recruits
# Incoming Units        OUT:3 Incoming firendly units from adjecent squares
# Game ID               IN:0  The game
# Column                IN:1  The column to look up
# Row                   IN:2  The row to look up
# Player ID             IN:3  The player to get moves of
# --------------------- ----- ------------------------------------------------
sub get_square_move_breakdown
{
   my $self       = shift;
   my $game_ID    = $_[0];
   my $column     = $_[1];
   my $row        = $_[2];
   my $player_ID  = $_[3];

   my ($error_code, $moves) = 
      $self->get_square_moves($game_ID, $column, $row, $player_ID);
   if($error_code)
   {
      $self->error(ERROR_SEVERITY_WARNING,$error_code,
         "Failed to get square moves for game $game_ID, column $column, row $row, player $player_ID");
      $self->{'tmpl_vars'}->{'error_message'} = 
         'ViewSquare failed while getting moves';
      return $error_code;
   }
   $self->debug(9, 'Moves '. @{$moves}) if(defined($moves));;
   
   # Calulate incoming and outgoing units
   my $used_units = 0;
   my $incoming_recruits = 0;
   my $incoming_units = 0;
   foreach my $move (@{$moves})
   {
      $self->debug(9, 'Move Type '. $move->{'move_type_ID'});
      if($move->{'from_across'} == $column && $move->{'from_down'} == $row)
      {
         if($move->{'move_type_ID'} == MOVE_TYPE_RECRUIT)
         {
            $incoming_recruits += $move->{'units'};
            my ($across_mod, $down_mod, $direction) = 
               $self->get_area_units($move,$column,$row);
            if($direction)
            {
               $used_units += $move->{'units'};
            }
            $self->debug(9, 'incoming_recruits + '. $move->{'units'});
         } elsif ($self->move_type_expansion($move->{'move_type_ID'}) ||
                     $self->move_type_effect($move->{'move_type_ID'},1)) {
            $used_units += $move->{'units'};
         } else {
            my ($across_mod, $down_mod, $direction) = 
               $self->get_area_units($move,$column,$row);
            if($direction)
            {
               $used_units += $move->{'units'};
            }
            $self->debug(9, "From $column,$row");
         }
      } elsif($move->{'to_across'} == $column && $move->{'to_down'} == $row) {
         # To this square
         $incoming_units += $move->{'units'};
         $self->debug(9, 'incoming_units + '. $move->{'units'});
      } else {
         # Error
         $self->error(ERROR_SEVERITY_WARNING,ERROR_INVALID_PARAMETER,
                     "$column,$row doesn't match to or from of move");
      }
   }
   return (ERROR_NONE, $used_units, $incoming_recruits, $incoming_units);
}

#-----------------------------------------------------------------------------
# Function: 	get_area_units
#-----------------------------------------------------------------------------
# Description:
# 					Gets the unit placement, for units that have been moved from
# 					this square to an adjacent square
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Across Modifier       OUT:0	Shortcut modifier to get across adjustment
# Down Modifier         OUT:1 Shortcut modifier to get up/down adjustment
# Direction             OUT:2 Direction type
# Move                  IN:0  Move details
# Column                IN:1  Column to adjust (Full index)
# Row                   IN:2  Row to adjust (Full index)
#-----------------------------------------------------------------------------
sub get_area_units
{
   my $self    = shift;
   my $move    = $_[0];
   my $column  = $_[1];
   my $row     = $_[2];

   $self->debug(8, "ViewSquare::get_area_units $column,$row");
   $self->debug_dumper(9,$move);

   # From this square
   my $direction = 0;
   my $across_mod = 0;
   my $down_mod = 0;
   if($move->{'to_across'} - $column > 1)
   {
      # We must be going west over a border
      $direction += DIRECTION_WEST;
      $across_mod--;
   } elsif($move->{'to_across'} - $column < -1) {
      # We must be going east over a border
      $direction += DIRECTION_EAST;
      $across_mod++;
   } else {
      if($move->{'to_across'} < $column)
      {
         $direction += DIRECTION_WEST;
         $across_mod--;
      } elsif($move->{'to_across'} > $column) {
         $direction += DIRECTION_EAST;
         $across_mod++;
      }
   }
   if($move->{'to_down'} - $row > 1)
   {
      # We must be going north over a border
      $direction += DIRECTION_NORTH;
      $down_mod--;
   } elsif($move->{'to_down'} - $row < -1) {
      # We must be going south over a border
      $direction += DIRECTION_SOUTH;
      $down_mod++;
   } else {
      if($move->{'to_down'} < $row)
      {
         $direction += DIRECTION_NORTH;
         $down_mod--;
      } elsif($move->{'to_down'} > $row) {
         $direction += DIRECTION_SOUTH;
         $down_mod++;
      }
   }
   $self->debug(8, "$down_mod,$across_mod,$direction");
   return ($across_mod,$down_mod,$direction);
}

sub make_valid_month_day
{
   my $self    = shift;
   my $mday    = $_[0];
   my $month   = $_[1];
   my $year    = $_[2];
   
   return $mday if($mday <= 28);
   if($month == 1 || $month == 3 || $month == 5 || $month == 7 || 
      $month == 8 || $month == 10 || $month == 12)
   {
      return $mday if($mday <= 31);
      $mday %= 31;
      $month++;
   } elsif ($month == 4 || $month == 6 || $month == 9 || $month == 11) {
      return $mday if($mday <= 30);
      $mday %= 30;
      $month++;
   } elsif(($year % 4) == 0 && (($year % 100) != 0 || ($year % 1000) == 0)) {
      # Leap year
      return $mday if($mday <= 29);
      $mday %= 29;
      $month++;
   } else {
      # Not Leap year
      $mday %= 28;
      $month++;
   }
   if($month > 12)
   {
      $month %= 12;
      $year++;
   }
   
   return $mday;
}

#-----------------------------------------------------------------------------
# Function: 	move_type_expansion
#-----------------------------------------------------------------------------
# Description:
# 					Returns true if the passed in move type is an expansion
# 					False otherwise
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Across Modifier       OUT:0	True if Expansion, False otherwise
# Move Type             IN:0  Move type ID
#-----------------------------------------------------------------------------
sub move_type_expansion
{
   my $self          = shift;
   my $move_type_ID  = int($_[0]);
   
   if($move_type_ID == MOVE_TYPE_BASE ||
      $move_type_ID == MOVE_TYPE_IRRAGATE ||
      $move_type_ID == MOVE_TYPE_BRIDGE ||
      $move_type_ID == MOVE_TYPE_FORT ||
      $move_type_ID == MOVE_TYPE_PORT ||
      $move_type_ID == MOVE_TYPE_SCHOOL ||
      $move_type_ID == MOVE_TYPE_UNIVERSITY ||
      $move_type_ID == MOVE_TYPE_RESEARCHCENTER ||
      $move_type_ID == MOVE_TYPE_TOWER)
   {
      $self->debug(8, "move_type_expansion ($move_type_ID) true");
      return 1;
   } else {
      $self->debug(8, "move_type_expansion ($move_type_ID) false");
      return 0;
   }
}

#-----------------------------------------------------------------------------
# Function: 	move_type_effect
#-----------------------------------------------------------------------------
# Description:
# 					Returns true if the passed in move type is an effect
# 					False otherwise
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Across Modifier       OUT:0	True if Expansion, False otherwise
# Move Type             IN:0  Move type ID
#-----------------------------------------------------------------------------
sub move_type_effect
{
   my $self          = shift;
   my $move_type_ID  = $_[0];
   my $same_square_only = $_[1] || 0;
   
   if((!$same_square_only && ($move_type_ID == MOVE_TYPE_FIRE ||
         $move_type_ID == MOVE_TYPE_SCOUT ||
         $move_type_ID == MOVE_TYPE_SUICIDE  ||
         $move_type_ID == MOVE_TYPE_KAMIKAZE ||
         $move_type_ID == MOVE_TYPE_PLAGUE)) ||
      $move_type_ID == MOVE_TYPE_CELEBRATION ||
      $move_type_ID == MOVE_TYPE_PEACE)
   {
      $self->debug(8, "move_type_effect ($move_type_ID) true");
      return 1;
   } else {
      $self->debug(8, "move_type_effect ($move_type_ID) false");
      return 0;
   }
}

#-----------------------------------------------------------------------------
# Function: 	calcualte_fight_modifiers
#-----------------------------------------------------------------------------
# Description:
# 					Returns the modifiers for a fight
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Attack Modifier       OUT:0	Attacker Modifier
# Defense Modifier      OUT:1	Defender Modifier
# Attacker              IN:0  Attacking Player ID
# Defender              IN:1  Defending Player ID
# Attack Modifier       IN:2	Attacker Modifier
# Defense Modifier      IN:3	Defender Modifier
#-----------------------------------------------------------------------------
sub calcualte_fight_modifiers
{
   my $self                = shift;
   my $attacker            = $_[0];
   my $defender            = $_[1] || 0;
   my $attacker_modifier   = $_[2] || 0;
   my $defender_modifier   = $_[3] || 0;
   $self->debug(8, 'calcualte_fight_modifiers');

   # Technology
   my @tech_mods = 
      (
         {'tech_ID' => TECH_BASIC_WEAPONS, 
            'attacker_mod' => 1, 'defender_mod' => 1},
         {'tech_ID' => TECH_GUN_POWDER, 
            'attacker_mod' => 1, 'defender_mod' => 1},
         {'tech_ID' => TECH_TANKS, 
            'attacker_mod' => 1, 'defender_mod' => 1},
         {'tech_ID' => TECH_ARMOUR, 
            'attacker_mod' => 0, 'defender_mod' => 1}
      );
   $self->debug(9, "Attacker $attacker, Defender $defender");
   foreach my $tech (@tech_mods)
   {
      $self->debug(9, "Checking Tech $tech->{'tech_ID'}");
      if($defender > 0)
      {
         # Not a native being attacked
         if($self->player_has_technology(
               $defender,$tech->{'tech_ID'}))
         {
            $self->debug(9, "Player $defender has tech " . 
               $tech->{'tech_ID'});
            $defender_modifier += $tech->{'defender_mod'};
         }
      }
      if($self->player_has_technology(
            $attacker,$tech->{'tech_ID'}))
      {
         $self->debug(9, "Player $attacker has tech " . 
            $tech->{'tech_ID'});
         $attacker_modifier += $tech->{'attacker_mod'};
      }
   }

   return ($attacker_modifier, $defender_modifier);
}

1;
