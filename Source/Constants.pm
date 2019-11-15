#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		Constants
#-----------------------------------------------------------------------------
# Description:
# 					This module contains all the core code constants
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2004/09/04 21:28:17 $
# $Revision: 1.17 $
#-----------------------------------------------------------------------------
package TotalLeader::Source::Constants;
use strict;

BEGIN
{
	my $project_path;
	unless($project_path = $ENV{'PROJECT_PATH'})
	{
		die('Set enviroment variable PROJECT_PATH to the project path');
	}
	eval "use lib '$project_path';";
	
	# And associated package defaults
	use vars qw(@ISA @EXPORT);
	@ISA = qw(Exporter);
	@EXPORT = qw(
         ADMIN_USER
      
         LAND_TYPE_SEA LAND_TYPE_PLAINS LAND_TYPE_MOUNTAIN LAND_TYPE_FOREST
         LAND_TYPE_ANY

         ACTION_TYPE_MOVE_VIEW ACTION_TYPE_SELECT_START ACTION_TYPE_VIEW

         EXPANSION_TYPE_BASE EXPANSION_TYPE_FORT EXPANSION_TYPE_IRRAGATION
         EXPANSION_TYPE_BRIDGE EXPANSION_TYPE_PORT EXPANSION_TYPE_SCHOOL
         EXPANSION_TYPE_UNIVERSITY EXPANSION_TYPE_RESEARCHCENTER
         EXPANSION_TYPE_TOWER

         EFFECT_TYPE_FIRE EFFECT_TYPE_STORM EFFECT_TYPE_SCOUT 
         EFFECT_TYPE_SUICIDAL_SCOUT EFFECT_TYPE_KAMIKAZE_SCOUT 
         EFFECT_TYPE_PLAGUE EFFECT_TYPE_CELEBRATION EFFECT_TYPE_PEACE

         TECH_BASIC_WEAPONS TECH_GUN_POWDER TECH_TANKS TECH_ARMOUR
         TECH_MASONRY TECH_TALL_CONSTRUCTION TECH_BRICKS TECH_ENGINEERING
         TECH_FARMING TECH_BASIC_SCIENCE TECH_TEACHING TECH_ADVANCED_TEACHING
         TECH_BASIC_DIPLOMACY TECH_ADVANCED_DIPLOMACY TECH_DISEASE 
         TECH_MEDICINE TECH_SPYING TECH_ESPIONAGE TECH_FANATICS 
         TECH_ENTERTAINMENT TECH_RESEARCH
         
         TECH_TREE

         MOVE_TYPE_MOVE MOVE_TYPE_BASE MOVE_TYPE_FORT MOVE_TYPE_IRRAGATE 
         MOVE_TYPE_BRIDGE MOVE_TYPE_PORT MOVE_TYPE_SCHOOL 
         MOVE_TYPE_UNIVERSITY MOVE_TYPE_RESEARCHCENTER MOVE_TYPE_TOWER 
         MOVE_TYPE_FIRE MOVE_TYPE_SCOUT MOVE_TYPE_SUICIDE MOVE_TYPE_KAMIKAZE 
         MOVE_TYPE_PLAGUE MOVE_TYPE_CELEBRATION MOVE_TYPE_PEACE
         MOVE_TYPE_RECRUIT
         
         FREQUENCY_TYPE_WEEKENDS FREQUENCY_TYPE_WEEKDAYS FREQUENCY_TYPE_ALL

         DIRECTION_NORTH DIRECTION_NORTHEAST DIRECTION_EAST DIRECTION_SOUTHEAST
         DIRECTION_SOUTH DIRECTION_SOUTHWEST DIRECTION_WEST DIRECTION_NORTHWEST

         PROCESS_STAGE_NONE PROCESS_STAGE_MOVING_PENDING_UNITS
         PROCESS_STAGE_UPDATED_EFFECTS
         PROCESS_STAGE_MOVED_PENDING_UNITS PROCESS_STAGE_MOVED_UNITS
         PROCESS_STAGE_CALCULATED_RANDOM_EVENTS 
         PROCESS_STAGE_UPDATED_PLAYER_DETAILS PROCESS_STAGE_CLEANUP

         BUILDING_IMAGE
      );
}

use constant ADMIN_USER          => 1;

use constant LAND_TYPE_ANY       => 0;
use constant LAND_TYPE_SEA       => 1;
use constant LAND_TYPE_PLAINS    => 2;
use constant LAND_TYPE_MOUNTAIN  => 3;
use constant LAND_TYPE_FOREST    => 4;

use constant ACTION_TYPE_MOVE_VIEW     => 1;
use constant ACTION_TYPE_SELECT_START  => 2;
use constant ACTION_TYPE_VIEW          => 3;

use constant EXPANSION_TYPE_BASE             => 1;
use constant EXPANSION_TYPE_FORT             => 2;
use constant EXPANSION_TYPE_IRRAGATION       => 3;
use constant EXPANSION_TYPE_BRIDGE           => 4;
use constant EXPANSION_TYPE_PORT             => 5;
use constant EXPANSION_TYPE_SCHOOL           => 6;
use constant EXPANSION_TYPE_UNIVERSITY       => 7;
use constant EXPANSION_TYPE_RESEARCHCENTER   => 8;
use constant EXPANSION_TYPE_TOWER            => 9;

use constant EFFECT_TYPE_FIRE             => 1;
use constant EFFECT_TYPE_STORM            => 2;
use constant EFFECT_TYPE_SCOUT            => 3;
use constant EFFECT_TYPE_SUICIDAL_SCOUT   => 4;
use constant EFFECT_TYPE_KAMIKAZE_SCOUT   => 5;
use constant EFFECT_TYPE_PLAGUE           => 6;
use constant EFFECT_TYPE_CELEBRATION      => 7;
use constant EFFECT_TYPE_PEACE            => 8;

use constant TECH_BASIC_WEAPONS     => 1;
use constant TECH_GUN_POWDER        => 2;
use constant TECH_TANKS             => 3;
use constant TECH_ARMOUR            => 4;
use constant TECH_MASONRY           => 5;
use constant TECH_TALL_CONSTRUCTION => 6;
use constant TECH_BRICKS            => 7;
use constant TECH_ENGINEERING       => 8;
use constant TECH_FARMING           => 9;
use constant TECH_BASIC_SCIENCE     => 10;
use constant TECH_TEACHING          => 11;
use constant TECH_ADVANCED_TEACHING => 12;
use constant TECH_BASIC_DIPLOMACY   => 13;
use constant TECH_ADVANCED_DIPLOMACY=> 14;
use constant TECH_DISEASE           => 15;
use constant TECH_MEDICINE          => 16;
use constant TECH_SPYING            => 17;
use constant TECH_ESPIONAGE         => 18;
use constant TECH_FANATICS          => 19;
use constant TECH_ENTERTAINMENT     => 20;
use constant TECH_RESEARCH          => 21;

# This outlines the layout of the tech tree on the screen
# It does not effect the dependacies, this is just a easy way to do this
# instead of writing some clever code to do it dynamically
use constant TECH_TREE =>
   [
      {'tech_event' => 'armour', 'label' => 'Armour', 'ID' => TECH_ARMOUR},
      {'tech_event' => 'basic_weapons', 'label' => 'Basic Weapon', 
         'ID' => TECH_BASIC_WEAPONS, 'left' => 1, 'right' => 1, 'down' => 1},
      {'tech_event' => 'gun_powder', 'label' => 'Gun Powder', 
         'ID' => TECH_GUN_POWDER, 'right' => 1},
      {'tech_event' => 'tanks', 'label' => 'Tanks', 'ID' => TECH_TANKS},
      {'tech_event' => 'entertainment', 'label' => 'Entertainment',
         'ID' => TECH_ENTERTAINMENT, 'up' => 1, 'new_row' => 1},

      {'tech_event' => 'spying', 'label' => 'Spying', 'ID' => TECH_SPYING, 
         'down' => 1},
      {'tech_event' => 'basic_diplomacy', 'label' => 'Basic Diplomacy', 
         'ID' => TECH_BASIC_DIPLOMACY, 'left' => 1, 'down' => 1},
      {'tech_event' => 'medicine', 'label' => 'Medicine', 
         'ID' => TECH_MEDICINE},
      {'tech_event' => 'advanced_teaching', 'label' => 'Advanced Teaching', 
         'ID' => TECH_ADVANCED_TEACHING,  'left' => 1, 'down' => 1},
      {'tech_event' => 'teaching', 'label' => 'Teaching', 
         'ID' => TECH_TEACHING, 'left' => 1, 'down' => 1, 'new_row' => 1},

      {'tech_event' => 'espionage', 'label' => 'Espionage', 
         'ID' => TECH_ESPIONAGE, 'down' => 1},
      {'tech_event' => 'advanced_diplomacy', 'label' => 'Advance Diplomacy', 
         'ID' => TECH_ADVANCED_DIPLOMACY},
      {},
      {'tech_event' => 'research', 'label' => 'Research', 
         'ID' => TECH_RESEARCH},
      {'tech_event' => 'basic_science', 'label' => 'Basic Science', 
         'ID' => TECH_BASIC_SCIENCE, 'down' => 1, 'new_row' => 1},
         
      {'tech_event' => 'fanatics', 'label' => 'Fanatics', 
         'ID' => TECH_FANATICS}, 
      {'tech_event' => 'masonry', 'label' => 'Masonry', 'ID' => TECH_MASONRY,
         'right' => 1},
      {'tech_event' => 'bricks', 'label' => 'Bricks', 'ID' => TECH_BRICKS,
         'right' => 1},
      {'tech_event' => 'engineering', 'label' => 'Engineering', 
         'ID' => TECH_ENGINEERING, 'down' => 1},
      {'tech_event' => 'disease', 'label' => 'Disease',
         'ID' => TECH_DISEASE, 'new_row' => 1},

      {},
      {'tech_event' => 'farming', 'label' => 'Farming', 'ID' => TECH_FARMING},
      {},
      {'tech_event' => 'tall_constructions', 'label' => 'Tall Constructions',
         'ID' => TECH_TALL_CONSTRUCTION},
      {}
   ];

# Note, the order IS important, as this is the order the move occur in
use constant MOVE_TYPE_BASE              => 1;
use constant MOVE_TYPE_FORT              => 2;
use constant MOVE_TYPE_IRRAGATE          => 3;
use constant MOVE_TYPE_BRIDGE            => 4;
use constant MOVE_TYPE_PORT              => 5;
use constant MOVE_TYPE_SCHOOL            => 6;
use constant MOVE_TYPE_UNIVERSITY        => 7;
use constant MOVE_TYPE_RESEARCHCENTER    => 8;
use constant MOVE_TYPE_TOWER             => 9;
use constant MOVE_TYPE_FIRE              => 10;
use constant MOVE_TYPE_SCOUT             => 12;

use constant MOVE_TYPE_SUICIDE           => 13;
use constant MOVE_TYPE_KAMIKAZE          => 14;
use constant MOVE_TYPE_PLAGUE            => 15;
use constant MOVE_TYPE_CELEBRATION       => 16;
use constant MOVE_TYPE_PEACE             => 17;

use constant MOVE_TYPE_RECRUIT           => 19;
use constant MOVE_TYPE_MOVE              => 20;

use constant FREQUENCY_TYPE_ALL        => 1;
use constant FREQUENCY_TYPE_WEEKDAYS   => 2;
use constant FREQUENCY_TYPE_WEEKENDS   => 3; 

use constant DIRECTION_NORTH           => 1;
use constant DIRECTION_NORTHEAST       => 3;
use constant DIRECTION_EAST            => 2;
use constant DIRECTION_SOUTHEAST       => 6;
use constant DIRECTION_SOUTH           => 4;
use constant DIRECTION_SOUTHWEST       => 12;
use constant DIRECTION_WEST            => 8;
use constant DIRECTION_NORTHWEST       => 9;

use constant PROCESS_STAGE_NONE                    => 0;
use constant PROCESS_STAGE_MOVING_PENDING_UNITS    => 1;
use constant PROCESS_STAGE_UPDATED_EFFECTS         => 2;
use constant PROCESS_STAGE_MOVED_PENDING_UNITS     => 3;
use constant PROCESS_STAGE_MOVED_UNITS             => 4;
use constant PROCESS_STAGE_CALCULATED_RANDOM_EVENTS=> 5;
use constant PROCESS_STAGE_UPDATED_PLAYER_DETAILS  => 6;
use constant PROCESS_STAGE_CLEANUP                 => 7;

use constant BUILDING_IMAGE      => "building.gif";

1;
