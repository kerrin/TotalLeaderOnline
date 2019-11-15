# On move, create pending move entry only
#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		ViewSquare
#-----------------------------------------------------------------------------
# Description:
# 					This module is used to allow members to log on
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2004/09/02 13:56:07 $
# $Revision: 1.16 $
#-----------------------------------------------------------------------------
package TotalLeader::Source::ViewSquare;
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

sub TEMPLATE() { 'view_square.html' };

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
# Function: 	pre_check_module_setup
#-----------------------------------------------------------------------------
# Description:
# 					Used to setup the module before any checks are performed
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# NONE
#-----------------------------------------------------------------------------
#sub pre_check_module_setup
#{
#	my $self 	=	shift;
#
#   $self->debug(8, 'ViewSquare::pre_check_module_setup');
#
#}

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
#   $self->debug(8, 'ViewSquare::check_cgi_vars');
#
#	return $self->SUPER::check_cgi_vars(@_); 
#}

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

   my $cgi_vars   = $self->{'cgi_vars'};
   my $tmpl_vars  = $self->{'tmpl_vars'};
   my $game_ID    = $cgi_vars->{'game_ID'};
   my $member_ID  = $cgi_vars->{'member_ID'};
   my $player_ID  = $self->get_player_ID($member_ID, $game_ID);
   my $row        = $cgi_vars->{'row'};
   my $column     = $cgi_vars->{'column'};
   if(($row + $column) % 2)
   {
      # A major square
      $tmpl_vars->{'major'} = 1;
   }
   
   my $error_code;
   ($error_code,$self->{'from_square_details'}) = 
      $self->get_square_details($game_ID,$column,$row);
   $tmpl_vars->{'land_type_ID'} = 
      $self->{'from_square_details'}->{'land_type_ID'};
   $tmpl_vars->{'land_type'} = 
      $self->land_type_name($tmpl_vars->{'land_type_ID'});
   $tmpl_vars->{'owner_ID'} = $self->{'from_square_details'}->{'owner_ID'};
   if($self->{'from_square_details'}->{'owner_ID'} == $player_ID)
   {
      $tmpl_vars->{'my_square'} = 1;
   }
   if($self->is_scout_owner($game_ID,$column,$row,$player_ID))
   {
      $tmpl_vars->{'my_scout'} = 1;
   }
   if($tmpl_vars->{'my_square'} || $tmpl_vars->{'my_scout'})
   {
      $tmpl_vars->{'my_square_or_scout'} = 1;
   }
   $tmpl_vars->{'units'} = $self->{'from_square_details'}->{'units'};
   if($tmpl_vars->{'major'})
   {
      $tmpl_vars->{'expansion_type_ID'} = 
         $self->{'from_square_details'}->{'expansion_type_ID'} || 0;
      $tmpl_vars->{'expansion_hp'} = 
         $self->{'from_square_details'}->{'expansion_hp'} || 0;
   }
   
   $self->{'player_details'} = $self->get_player_details($game_ID, $player_ID);
   $self->{'remaining_recruits'} = $self->{'player_details'}->{'recruits_left'};
   
   my $unused_units_0_9 = 0;
   my @area = $self->generate_area_array($row,$column);
   $self->{'used_units'} = 0;
   $self->{'assigned_recruits'} = 0;
   if($tmpl_vars->{'my_square_or_scout'})
   {
      $self->debug(9, 'My Square') if($tmpl_vars->{'my_square'});
      $self->debug(9, 'My Scout') if($tmpl_vars->{'my_scout'});
      $tmpl_vars->{'incoming_units'} = 0;
      my $moves;
      ($error_code, $moves) = 
         $self->get_square_moves($game_ID, $column, $row, $player_ID);
      if($error_code)
      {
         $self->error(ERROR_SEVERITY_WARNING,$error_code,
            "Failed to get square moves for game $game_ID, column $column, row $row, player $player_ID");
         $self->{'tmpl_vars'}->{'error_message'} = 
            'ViewSquare failed while getting moves';
         return $error_code;
      }
      $self->debug(9, 'Moves '. @{$moves}) if(defined($moves));
      
      # Calulate incoming and outgoing units
      foreach my $move (@{$moves})
      {
         $self->debug(9, 'Move Type '. $move->{'move_type_ID'});
         if($move->{'from_across'} == $column && $move->{'from_down'} == $row)
         {
            if($move->{'move_type_ID'} == MOVE_TYPE_RECRUIT)
            {
               $tmpl_vars->{'incoming_recruits'} += $move->{'units'};
               my ($across_mod, $down_mod, $direction) = 
                  $self->get_area_units($move,$column,$row);
               if($direction)
               {
                  $self->{'used_units'} += $move->{'units'};
                  $area[1 + $down_mod]->{'col'}->[1 + $across_mod]->{'units'} +=
                     $move->{'units'};
                  $self->debug(9, "D:$down_mod, A:$across_mod, U:" . 
                     $move->{'units'});
               } elsif ($move->{'move_type_ID'} == MOVE_TYPE_RECRUIT) {
                  $self->{'assigned_recruits'} += $move->{'units'};
               }
               $self->debug(9, 'incoming_recruits + '. $move->{'units'});
            } else {
               my ($across_mod, $down_mod, $direction) = 
                  $self->get_area_units($move,$column,$row);
               if($direction)
               {
                  $self->{'used_units'} += $move->{'units'};
                  $area[1 + $down_mod]->{'col'}->[1 + $across_mod]->{'units'} +=
                        $move->{'units'};
                  $self->debug(9, "D:$down_mod, A:$across_mod, U:" . 
                     $move->{'units'});
               } elsif ($move->{'move_type_ID'} == MOVE_TYPE_RECRUIT) {
                  $self->{'assigned_recruits'} += $move->{'units'};
               } elsif($self->move_type_expansion($move->{'move_type_ID'}) ||
                     $self->move_type_effect($move->{'move_type_ID'},1)) {
                  $area[1]->{'col'}->[1]->{'units'} -= $move->{'units'};
                  $self->{'used_units'} += $move->{'units'};
                  $self->debug(8, "Center adjust, U:" . $move->{'units'});
               }
               $self->debug(9, "From $column,$row");
            }
         } elsif($move->{'to_across'} == $column && $move->{'to_down'} == $row) {
            # To this square
            $tmpl_vars->{'incoming_units'} += $move->{'units'};
            $self->debug(9, 'incoming_units + '. $move->{'units'});
         } else {
            # Error
            $self->error(ERROR_SEVERITY_WARNING,ERROR_INVALID_PARAMETER,
                        "$column,$row doesn't match to or from of move");
         }
      }
      $self->{'unused_units'} = $tmpl_vars->{'units'} - $self->{'used_units'};

      $self->{'spare_units'} = 9 - ($self->{'from_square_details'}->{'units'} - 
         $self->{'used_units'}) - $self->{'assigned_recruits'};
      $self->{'max_recruits'} = $self->{'spare_units'};
      if($self->{'max_recruits'} > $self->{'remaining_recruits'})
      {
         $self->{'max_recruits'} = $self->{'remaining_recruits'};
      }

      $area[1]->{'col'}->[1]->{'units'} += $self->{'unused_units'};
   }
   $tmpl_vars->{'area'} = \@area;
   $self->debug(9, 'Used units = ' . $self->{'used_units'} || 0);
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

   $self->debug(8, 'ViewSquare::setup_tmpl_vars');
   my $cgi_vars   = $self->{'cgi_vars'};
   my $tmpl_vars  = $self->{'tmpl_vars'};
   my $game_ID    = $cgi_vars->{'game_ID'};
   my $member_ID  = $cgi_vars->{'member_ID'};
   my $player_ID  = $self->get_player_ID($member_ID, $game_ID);
   my $row        = $cgi_vars->{'row'};
   my $column     = $cgi_vars->{'column'};

   my $error_code;

   if($tmpl_vars->{'my_square'})
   {
      # Calculate the units required to make up to 9 after moves happen
      $self->create_numeric_drop_down(
         'units', $self->{'unused_units'},0,$self->{'unused_units'});
      if($tmpl_vars->{'major'})
      {
         $self->create_drop_down_from_array(
            'direction', $self->{'cgi_vars'}->{'direction'},
               (
                  {'ID' => DIRECTION_NORTH,     'name' => 'North'},
                  {'ID' => DIRECTION_NORTHEAST, 'name' => 'North East'},
                  {'ID' => DIRECTION_EAST,      'name' => 'East'},
                  {'ID' => DIRECTION_SOUTHEAST, 'name' => 'South East'},
                  {'ID' => DIRECTION_SOUTH,     'name' => 'South'},
                  {'ID' => DIRECTION_SOUTHWEST, 'name' => 'South West'},
                  {'ID' => DIRECTION_WEST,      'name' => 'West'},
                  {'ID' => DIRECTION_NORTHWEST, 'name' => 'North West'}
               )
            );
      } else {
         $self->create_drop_down_from_array(
            'direction', $self->{'cgi_vars'}->{'direction'},
               (
                  {'ID' => DIRECTION_NORTH,     'name' => 'North'},
                  {'ID' => DIRECTION_EAST,      'name' => 'East'},
                  {'ID' => DIRECTION_SOUTH,     'name' => 'South'},
                  {'ID' => DIRECTION_WEST,      'name' => 'West'}
               )
            );
      }
      $self->debug(9, 'Created direction drop down');
      $self->debug(9, 'Exp Type = ' . $self->{'from_square_details'}->{'expansion_type_ID'});

      if($self->{'from_square_details'}->{'expansion_type_ID'} == 
         EXPANSION_TYPE_BASE)
      {
         $tmpl_vars->{'is_base'} = 1;
         $self->create_numeric_drop_down(
            'recruits', $self->{'max_recruits'},0,$self->{'max_recruits'});
      }

      # Create the special moves drop-down
      my $special_moves = $self->get_player_allowed_move_types(
            $player_ID, $tmpl_vars->{'land_type_ID'},
            $tmpl_vars->{'major'} && 
               (!$self->{'from_square_details'}->{'expansion_type_ID'}),
            $self->{'unused_units'} #, $money
         );
      $self->create_drop_down_from_array(
         'move_type', $self->{'cgi_vars'}->{'move_type_ID'},
            @{$special_moves}
         );
   }
   
   my $square_effects;
   ($error_code, $square_effects) = $self->get_square_effects($game_ID,$column,$row,1);
   if(@{$square_effects})
   {
      my $owners_details;
      ($error_code, $owners_details) = $self->db_select('get_owner_details',
         {'game_player'    => $self->config('game_player_table'),
         'player_colour'  => $self->config('player_colour_table')},
         $game_ID);
      
      foreach  my $effect (@{$square_effects})
      {
         if($effect->{'effect_type_ID'} == EFFECT_TYPE_SCOUT ||
            $effect->{'effect_type_ID'} == EFFECT_TYPE_SUICIDAL_SCOUT ||
            $effect->{'effect_type_ID'} == EFFECT_TYPE_KAMIKAZE_SCOUT)
         {
            $tmpl_vars->{'scouts'} .= $effect->{'turns_left'} . ' <img src="' . 
               '/Images/' . $effect->{'image'} . '" alt="' . 
               $effect->{'name'} . '" /> ';
            my $i = 0;
            while($i < @{$owners_details} && 
               $owners_details->[$i]->{'ID'} != $effect->{'effect_owner_ID'})
            {
               $i++;
            }
            if($owners_details->[$i]->{'ID'} == $effect->{'effect_owner_ID'})
            {
               $tmpl_vars->{'scouts'} .= $owners_details->[$i]->{'name'};
            } else {
               $tmpl_vars->{'scouts'} .= 'Unknown';
            }
            $tmpl_vars->{'scouts'} .= '&nbsp;';
         } else {
            $tmpl_vars->{'effects'} .= '<img src="' . '/Images/' . 
               $effect->{'image'} . 
               '" alt="' . $effect->{'name'} . '" />&nbsp;';
         }
      }
   }
   if(!exists($tmpl_vars->{'effects'}) || $tmpl_vars->{'effects'} eq '')
   {
      $tmpl_vars->{'effects'} = 'None';
   }
   if(!exists($tmpl_vars->{'scouts'}) || $tmpl_vars->{'scouts'} eq '')
   {
      $tmpl_vars->{'scouts'} = 'None';
   }
   
   for(my $row_count = 0; $row_count < 3;$row_count++)
   {
      for(my $column_count = 0; $column_count < 3;$column_count++)
      {
         if($tmpl_vars->{'area'}->[$row_count]->{'col'}->[$column_count]->{'units'} > 0)
         {
            $tmpl_vars->{'area'}->[$row_count]->{'col'}->[$column_count]->{'units_image'} = 
               '/Images/units_' . 
               $tmpl_vars->{'area'}[$row_count]->{'col'}->[$column_count]->{'units'} . 
               '.gif';
         }
      }
   }
   $self->debug_dumper(9,$tmpl_vars->{'area'});
   # Clear this out or it appears in the state as plain text
   $self->move_from_cgi_vars_to_tmpl_vars(
      ['row', 'column'],
      OVERWRITE_MOVE_ANYWAY);
}

#-----------------------------------------------------------------------------
# Function: 	generate_area_array
#-----------------------------------------------------------------------------
# Description:
# 					
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Area Array            OUT:0 The area array
# Row                   IN:0  The row of the center square
# Column                IN:1  The column of the center square
#-----------------------------------------------------------------------------
sub generate_area_array
{
	my $self 	=	shift;
   my $row     = $_[0];
   my $column  = $_[1];

   my $cgi_vars   = $self->{'cgi_vars'};
   my $game_ID = $cgi_vars->{'game_ID'};

   $self->setup_game_details($game_ID);
   
   my @area = (
      {'col' => [
         {'units' => 0,'column' => 0, 'row' => 0},
         {'units' => 0,'column' => 1, 'row' => 0},
         {'units' => 0,'column' => 2, 'row' => 0}
      ]},
      {'col' => [
         {'units' => 0,'column' => 0, 'row' => 1},
         {'units' => 0,'column' => 1, 'row' => 1},
         {'units' => 0,'column' => 2, 'row' => 1}
      ]},
      {'col' => [
         {'units' => 0,'column' => 0, 'row' => 2},
         {'units' => 0,'column' => 1, 'row' => 2},
         {'units' => 0,'column' => 2, 'row' => 2}
      ]},
   );

   my $row_start = $row - 1;
   my $row_finish = $row + 2; # Finish one pasted
   my $column_start = $column - 1;
   my $column_finish = $column + 2;
   my $row_wrap = $self->{'game_details'}->{'board_rows'};
   my $column_wrap = $self->{'game_details'}->{'board_columns'};
   my $land_type;
   my $effect_type;
   my $expansion_type;
   my $owner;

   my ($error_code, $details) = $self->db_select('get_land_details',
      {'land_type_const' => $self->config('land_type_const_table')});
   if($error_code)
   {
      $self->throw_error($error_code,
         "Select error in Board->setup_tmpl_vars");
   }
   foreach my $this_row (@{$details})
   {
      my $temp = {'major' => $this_row->{'image'},
                  'minor' => 'small_' . $this_row->{'image'}};
      $land_type->{$this_row->{'ID'}} = $temp;
   }
   $self->debug(8,'Land Types');
   $self->debug_dumper(8,$land_type);

   ($error_code, $details) = $self->db_select('get_owner_details',
      {'game_player'    => $self->config('game_player_table'),
       'player_colour'  => $self->config('player_colour_table')},
      $game_ID);
   if($error_code)
   {
      $self->throw_error($error_code,
         "Select error in Board->setup_tmpl_vars");
   }
   foreach my $this_row (@{$details})
   {
      $self->debug(9,
         'Setting owner ' . $this_row->{'ID'} . ' to colour ' . $this_row->{'image'});
      $owner->{$this_row->{'ID'}} = {'image' => $this_row->{'image'},
                                     'name'  => $this_row->{'name'}};
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
   foreach my $this_row (@{$details})
   {
      $expansion_type->{$this_row->{'ID'}} = {'image' => $this_row->{'image'},
                                              'name'  => $this_row->{'name'}};
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
   foreach my $this_row (@{$details})
   {
      $effect_type->{$this_row->{'ID'}} = {'image' => $this_row->{'image'},
                                           'name'  => $this_row->{'name'}};
   }
   $self->debug(8,'Effect Types');
   $self->debug_dumper(8,$effect_type);


   $self->debug(8, "Rows: $row_start to $row_finish, Columns: $column_start to $column_finish");

   my ($variables,@params);
   $variables = {
      'game_board'            => $self->config('game_board_table'),
      'square_effect_details' => $self->config('square_effect_details_table')
   };
   push @params, $game_ID;
   $variables->{'additional_across'} = '';
   if($column_start < 0)
   {
      # Shift the start and finish and let the next if do all the work
      $column_start += $self->{'game_details'}->{'board_columns'};
      $column_finish += $self->{'game_details'}->{'board_columns'};
   }
   push @params, $column_start;
   if($column_finish >= $self->{'game_details'}->{'board_columns'})
   {
      push @params, $self->{'game_details'}->{'board_columns'};
      $variables->{'additional_across'} = 'OR (S.across BETWEEN ? AND ?)';
      push @params, 0;
      $column_finish -= $self->{'game_details'}->{'board_columns'};
   }
   push @params, $column_finish;
   if($row_start < 0)
   {
      # Shift the start and finish and let the next if do all the work
      $row_start += $self->{'game_details'}->{'board_rows'};
      $row_finish += $self->{'game_details'}->{'board_rows'};
   }
   $self->{'tmpl_vars'}->{'row_start'} = $row_start;
   push @params, $row_start;
   if($row_finish >= $self->{'game_details'}->{'board_rows'})
   {
      push @params, $self->{'game_details'}->{'board_rows'};
      $variables->{'additional_down'} = 'OR (S.down BETWEEN ? AND ?)';
      push @params, 0;
      $row_finish -= $self->{'game_details'}->{'board_rows'};
   } else {
      $variables->{'additional_down'} = '';
   }
   push @params, $row_finish;
   $self->debug(8, "Adjusted Rows: $row_start to $row_finish, Columns: $column_start to $column_finish");

   my $results;
   ($error_code, $results) =
      $self->db_select('get_board', $variables, @params);
   if($error_code)
   {
      $self->throw_error($error_code, 'Failed to search in generate_area_array');
   }
   unless(defined($results))
   {
      # This time we want an empty array
      $results = [];
   }

   my $temp_board = {};
   foreach my $square (@{$results})
   {
      $self->debug(9, 'Generating Row ' . $square->{'down'} . ' column ' .
                                       $square->{'across'});
      my $this_row = $temp_board->{$square->{'down'}} || {};

      $this_row->{$square->{'across'}} = $square;
      $temp_board->{$square->{'down'}} = $this_row;
   }

   my $row_index = $row_start;
   my $row_count = 0;
   while($row_index != $row_finish)
   {
      $self->debug(9, 'New Row ' . $row_index);
      my $column_index = $column_start;
      my $column_count = 0;
      while($column_index != $column_finish)
      {
         $self->debug(9, "Setting up Row $row_index column $column_index");
#         $self->debug(9, "$column_index != $column_finish");
         if(($row_index + $column_index) % 2)
         {
            # Major
            $area[$row_count]->{'col'}->[$column_count]->{'top'} = 
                                                   $row_count * 87;
            $area[$row_count]->{'col'}->[$column_count]->{'left'} = 
                                                   $column_count * 87;
            $area[$row_count]->{'col'}->[$column_count]->{'center_left'} = 
                                                   ($column_count * 87) + 37;
            $area[$row_count]->{'col'}->[$column_count]->{'center_top'} = 
                                                   ($row_count * 87) + 37;
            $area[$row_count]->{'col'}->[$column_count]->{'major'} = 1;
            $area[$row_count]->{'col'}->[$column_count]->{'land_image'} = 
               '/Images/' . $land_type->{$temp_board->{$row_index}->{$column_index}->{'land_type_ID'}}->{'major'};
         } else {
            # Minor
            $area[$row_count]->{'col'}->[$column_count]->{'left'} = 
                                                ($column_count * 87) + 37;
            $area[$row_count]->{'col'}->[$column_count]->{'top'} = 
                                                ($row_count * 87) + 37;
            $area[$row_count]->{'col'}->[$column_count]->{'center_left'} = 
                                                ($column_count * 87) + 37;
            $area[$row_count]->{'col'}->[$column_count]->{'center_top'} = 
                                                ($row_count * 87) + 37;
            $area[$row_count]->{'col'}->[$column_count]->{'land_image'} = 
               '/Images/' . $land_type->{$temp_board->{$row_index}->{$column_index}->{'land_type_ID'}}->{'minor'};
         }
         if($temp_board->{$row_index}->{$column_index}->{'owner_ID'} > 0)
         {
            $area[$row_count]->{'col'}->[$column_count]->{'owner'} =
               $owner->{
                  $temp_board->{$row_index}->{$column_index}->{'owner_ID'}}->{'name'};
            $area[$row_count]->{'col'}->[$column_count]->{'owner_image'} = 
               '/Images/' . $owner->{$temp_board->{$row_index}->{$column_index}->{'owner_ID'}}->{'image'};
         } else {
            $area[$row_count]->{'col'}->[$column_count]->{'owner'} = 'Natives';
         }
         if($temp_board->{$row_index}->{$column_index}->{'expansion_type_ID'} > 0)
         {
            $area[$row_count]->{'col'}->[$column_count]->{'expansion_name'} = 
               $expansion_type->{$temp_board->{$row_index}->{$column_index}->{'expansion_type_ID'}}->{'name'};
            $area[$row_count]->{'col'}->[$column_count]->{'exp_image'} = 
               '/Images/' .
               $expansion_type->{$temp_board->{$row_index}->{$column_index}->{'expansion_type_ID'}}->{'image'};
            if($temp_board->{$row_index}->{$column_index}->{'expansion_to_build'} > 0)
            {
               $area[$row_count]->{'col'}->[$column_count]->{'building_image'} = 
                  '/Images/' .
                  BUILDING_IMAGE
            }
         }
         if(exists($temp_board->{$row_index}->{$column_index}->{'effect_type_ID'}) && defined($temp_board->{$row_index}->{$column_index}->{'effect_type_ID'}) && $temp_board->{$row_index}->{$column_index}->{'effect_type_ID'} > 0)
         {
            $area[$row_count]->{'col'}->[$column_count]->{'effect'} =
               $effect_type->{$temp_board->{$row_index}->{$column_index}->{'effect_type_ID'}}->{'name'};
            $area[$row_count]->{'col'}->[$column_count]->{'effect_image'} =
               '/Images/' .
               $effect_type->{$temp_board->{$row_index}->{$column_index}->{'effect_type_ID'}}->{'image'};
         }
         $area[$row_count]->{'col'}->[$column_count]->{'occupied_units'} =
               $temp_board->{$row_index}->{$column_index}->{'units'};
         if($temp_board->{$row_index}->{$column_index}->{'units'} > 0)
         {
            $area[$row_count]->{'col'}->[$column_count]->{'occupied_units_image'} =
               '/Images/units_' .
               $temp_board->{$row_index}->{$column_index}->{'units'} . '.gif';
         } else {
            $area[$row_count]->{'col'}->[$column_count]->{'occupied_units_image'} =
               '/Images/units_none.gif';
         }

         # Now move on to the next column
         $column_index++;
         $column_count++;
         if($column_index == ($column_wrap || 0))
         {
            $column_index = 0;
         }
      }
      # Now move on to the next row
      $row_index++;
      $row_count++;
      if($row_index == ($row_wrap || 0))
      {
         $row_index = 0;
      }
   }
   
   return @area;
}

#-----------------------------------------------------------------------------
# Function: 	event_Move
#-----------------------------------------------------------------------------
# Description:
# 					Checks the move selection, and adds to pending moves
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Next Action				OUT:0	The module name to run next or undef for none
# Next Actions ArgumentsOUT:1	The arguments to pass to the next modules new
#-----------------------------------------------------------------------------
sub event_Move
{
	my $self 	=	shift;

   $self->debug(8, 'ViewSquare::event_Move');

   my $cgi_vars      = $self->{'cgi_vars'};
   my $tmpl_vars     = $self->{'tmpl_vars'};
   my $game_ID       = $cgi_vars->{'game_ID'};
   my $units         = $cgi_vars->{'units'};
   my $direction     = $cgi_vars->{'direction'};
   my $move_type_ID  = $cgi_vars->{'move_type_ID'};
   my $member_ID     = $cgi_vars->{'member_ID'};
   my $player_ID     = $self->get_player_ID($member_ID, $game_ID);
   my $row           = $cgi_vars->{'row'};
   my $column        = $cgi_vars->{'column'};

   $self->setup_game_details($game_ID);
   my $row_wrap = $self->{'game_details'}->{'board_rows'};
   my $column_wrap = $self->{'game_details'}->{'board_columns'};

   my $column_offset = 0;
   my $row_offset = 0;
   if($direction >= DIRECTION_WEST)
   {
      $column_offset--;
      $direction -= DIRECTION_WEST;
   }
   if($direction >= DIRECTION_SOUTH)
   {
      $row_offset++;
      $direction -= DIRECTION_SOUTH;
   }
   if($direction >= DIRECTION_EAST)
   {
      $column_offset++;
      $direction -= DIRECTION_EAST;
   }
   if($direction >= DIRECTION_NORTH)
   {
      $row_offset--;
      $direction -= DIRECTION_NORTH;
   }
   if($move_type_ID == MOVE_TYPE_FIRE && $units > 1)
   {
      $units = 1;
   }
   my $to_column = $column + $column_offset;
   my $to_row = $row + $row_offset;
   if($to_row >= $row_wrap)
   {
      $to_row -= $row_wrap;
   }
   if($to_row < 0)
   {
      $to_row += $row_wrap;
   }
   if($to_column >= $column_wrap)
   {
      $to_column -= $column_wrap;
   }
   if($to_column < 0)
   {
      $to_column += $column_wrap;
   }

   # Check for existing move
   my ($error_code, $move) = $self->db_select('get_game_square_move',
      {'game_board_move' => $self->config('game_board_move_table')},
      $game_ID, $column, $row, $to_column, $to_row, $move_type_ID, $player_ID);
   if($error_code)
   {
      $self->throw_error($error_code,
                         "Select error in ViewSquare->event_Move");
   }
   my $exists = 0;
   my $current_move_ID = 0;
   my $current_move_units = 0;
   if(defined($move) && @{$move})
   {
      $exists = 1;
      $current_move_ID = $move->[0]->{'ID'};
      $current_move_units = $move->[0]->{'units'};
      $move = $move->[0];
   }
   
   # Validate move
   my $to_square_details = 
         $self->get_square_details($game_ID,$to_column,$to_row);
   if($move_type_ID == MOVE_TYPE_MOVE)
   {
      if($column_offset == 0 && $row_offset == 0)
      {
         # Move without direction
         $tmpl_vars->{'error_message'} = 
            'You must select a direction to move in';
         return;
      } elsif ($to_square_details->{'land_type_ID'} == LAND_TYPE_SEA) {
         # Moved in to water
         unless(( $to_square_details->{'expansion_type_ID'} == 
                     EXPANSION_TYPE_BRIDGE && 
                  $to_square_details->{'expansion_to_build'} == 0) ||
               (  $self->{'from_square_details'}->{'expansion_type_ID'} ==
                     EXPANSION_TYPE_PORT &&
                  $self->{'from_square_details'}->{'expansion_to_build'} == 0) ||
               ($self->{'from_square_details'}->{'land_type_ID'} == 
                  LAND_TYPE_SEA && 
                $self->{'from_square_details'}->{'expansion_type_ID'} != 
                  EXPANSION_TYPE_BRIDGE))
               
         {
            $tmpl_vars->{'error_message'} = 
               'You cannot move in to sea squares without bridges, or a port';
            return;
         }
      }
   }
   if($move_type_ID == MOVE_TYPE_BASE || $move_type_ID == MOVE_TYPE_FORT || 
      $move_type_ID == MOVE_TYPE_IRRAGATE || $move_type_ID == MOVE_TYPE_PORT || 
      $move_type_ID == MOVE_TYPE_SCHOOL || 
      $move_type_ID == MOVE_TYPE_UNIVERSITY || 
      $move_type_ID == MOVE_TYPE_RESEARCHCENTER || 
      $move_type_ID == MOVE_TYPE_TOWER ||
      $move_type_ID == MOVE_TYPE_CELEBRATION ||
      $move_type_ID == MOVE_TYPE_PEACE
      )
   {
      # Ignore the direction
      $column_offset = 0;
      $row_offset = 0;
      $direction = 0;
      $to_row = $row;
      $to_column = $column;
   }
   my $check_square = $self->{'from_square_details'};
   my $check_column = $column;
   my $check_row = $row;
   if($move_type_ID == MOVE_TYPE_BRIDGE)
   {
      $check_column = $to_column;
      $check_row = $to_row;
      $check_square = $to_square_details;
   }
   if(($move_type_ID == MOVE_TYPE_BASE || $move_type_ID == MOVE_TYPE_FORT || 
      $move_type_ID == MOVE_TYPE_IRRAGATE || $move_type_ID == MOVE_TYPE_PORT || 
      $move_type_ID == MOVE_TYPE_SCHOOL || 
      $move_type_ID == MOVE_TYPE_UNIVERSITY || 
      $move_type_ID == MOVE_TYPE_RESEARCHCENTER || 
      $move_type_ID == MOVE_TYPE_BRIDGE ||
      $move_type_ID == MOVE_TYPE_TOWER) && 
      (($check_column + $check_row) % 2 == 0))
   {
      # Expansion in minor square
      $tmpl_vars->{'error_message'} = 'You can only build expansions on major squares';
      return;
   }

   if(($move_type_ID == MOVE_TYPE_BASE || $move_type_ID == MOVE_TYPE_FORT || 
      $move_type_ID == MOVE_TYPE_IRRAGATE || $move_type_ID == MOVE_TYPE_PORT || 
      $move_type_ID == MOVE_TYPE_SCHOOL || 
      $move_type_ID == MOVE_TYPE_UNIVERSITY || 
      $move_type_ID == MOVE_TYPE_RESEARCHCENTER || 
      $move_type_ID == MOVE_TYPE_TOWER || 
      $move_type_ID == MOVE_TYPE_BRIDGE ||
      $move_type_ID == MOVE_TYPE_CELEBRATION ||
      $move_type_ID == MOVE_TYPE_FIRE ||
      $move_type_ID == MOVE_TYPE_SUICIDE ||
      $move_type_ID == MOVE_TYPE_KAMIKAZE ||
      $move_type_ID == MOVE_TYPE_PLAGUE ||
      $move_type_ID == MOVE_TYPE_PEACE))
   {
      # Check for other pending buildings
      my $pending;
      my $building_moves = MOVE_TYPE_BASE . ',' . MOVE_TYPE_FORT . ',' . 
         MOVE_TYPE_IRRAGATE. ',' . MOVE_TYPE_PORT . ',' . MOVE_TYPE_SCHOOL . 
         ',' . MOVE_TYPE_UNIVERSITY . ',' . MOVE_TYPE_RESEARCHCENTER . ',' . 
         MOVE_TYPE_TOWER . ',' . MOVE_TYPE_BRIDGE . ',' .
         MOVE_TYPE_FIRE . ',' . MOVE_TYPE_SUICIDE . ',' . 
         MOVE_TYPE_KAMIKAZE . ',' . MOVE_TYPE_PLAGUE . ',' . 
         MOVE_TYPE_PEACE . ',' . MOVE_TYPE_CELEBRATION; 
      ($error_code, $pending) = $self->db_select(
            'get_game_square_building_moves',
            {'game_board_move'   => $self->config('game_board_move_table'),
             'buildings'         => $building_moves},
            $game_ID, $to_column, $to_row);
      if($error_code)
      {
         $self->throw_error($error_code,
                            "Select error in ViewSquare->effect_Move");
      }
      if(defined($pending) && @{$pending})
      {
         $tmpl_vars->{'error_message'} = 
         'This square already has a building or effect in progress';
         return;
      }
   }

   # Check costs and deduct
   if($move_type_ID == MOVE_TYPE_BASE || $move_type_ID == MOVE_TYPE_FORT ||
      $move_type_ID == MOVE_TYPE_IRRAGATE || $move_type_ID == MOVE_TYPE_PORT ||
      $move_type_ID == MOVE_TYPE_SCHOOL ||
      $move_type_ID == MOVE_TYPE_UNIVERSITY ||
      $move_type_ID == MOVE_TYPE_RESEARCHCENTER ||
      $move_type_ID == MOVE_TYPE_TOWER ||
      $move_type_ID == MOVE_TYPE_BRIDGE ||
      $move_type_ID == MOVE_TYPE_CELEBRATION ||
      $move_type_ID == MOVE_TYPE_FIRE ||
      $move_type_ID == MOVE_TYPE_SUICIDE ||
      $move_type_ID == MOVE_TYPE_KAMIKAZE ||
      $move_type_ID == MOVE_TYPE_PLAGUE ||
      $move_type_ID == MOVE_TYPE_PEACE)
   {
      # Get Expansion Details for selected expansion
      my $expansion_ID = 0;
      $expansion_ID = EXPANSION_TYPE_BASE if($move_type_ID == MOVE_TYPE_BASE);
      $expansion_ID = EXPANSION_TYPE_FORT if($move_type_ID == MOVE_TYPE_FORT);
      $expansion_ID = EXPANSION_TYPE_IRRAGATION if($move_type_ID == MOVE_TYPE_IRRAGATE);
      $expansion_ID = EXPANSION_TYPE_BRIDGE if($move_type_ID == MOVE_TYPE_BRIDGE);
      $expansion_ID = EXPANSION_TYPE_PORT if($move_type_ID == MOVE_TYPE_PORT);
      $expansion_ID = EXPANSION_TYPE_SCHOOL if($move_type_ID == MOVE_TYPE_SCHOOL);
      $expansion_ID = EXPANSION_TYPE_UNIVERSITY if($move_type_ID == MOVE_TYPE_UNIVERSITY);
      $expansion_ID = EXPANSION_TYPE_RESEARCHCENTER if($move_type_ID == MOVE_TYPE_RESEARCHCENTER);
      $expansion_ID = EXPANSION_TYPE_TOWER if($move_type_ID == MOVE_TYPE_TOWER);
      $expansion_ID = EXPANSION_TYPE_BRIDGE if($move_type_ID == MOVE_TYPE_BRIDGE);
      my $details;
      if($expansion_ID)
      {
         ($error_code, $details) = $self->db_select(
            'get_expansion_details_from_ID',
            {'expansion_type_const' => 
               $self->config('expansion_type_const_table')},
            $expansion_ID);
      } else {
         # Must be an effect then
         my $effect_ID = 0;
         $effect_ID = EFFECT_TYPE_FIRE if($move_type_ID == MOVE_TYPE_FIRE);
         $effect_ID = EFFECT_TYPE_SUICIDAL_SCOUT if($move_type_ID == MOVE_TYPE_SUICIDE);
         $effect_ID = EFFECT_TYPE_KAMIKAZE_SCOUT if($move_type_ID == MOVE_TYPE_KAMIKAZE);
         $effect_ID = EFFECT_TYPE_PLAGUE if($move_type_ID == MOVE_TYPE_PLAGUE);
         $effect_ID = EFFECT_TYPE_PEACE if($move_type_ID == MOVE_TYPE_PEACE);
         $effect_ID = EFFECT_TYPE_CELEBRATION if($move_type_ID == MOVE_TYPE_CELEBRATION);
         ($error_code, $details) = $self->db_select('get_effect_details_from_ID',
            {'effect_type_const' => $self->config('effect_type_const_table')},
            $effect_ID);
      }
      if($error_code)
      {
         $self->throw_error($error_code,
                         "Select error in ViewSquare->event_Move");
      }
      if(defined($details) && @{$details})
      {
         $details = $details->[0];
      } else {
         $self->throw_error(ERROR_DB_RESULTS,
            "Select returned no results in CommonTools->get_square_details");
      }

      # Check for units, money, land, technology and ownership
      if($self->{'unused_units'} < $details->{'unit_cost'})
      {
         $tmpl_vars->{'error_message'} = 'You do not have enough units to build this expansion, you require ' . $details->{'unit_cost'} . ' and only have ' . $self->{'unused_units'};
         return;
      }
      if($self->{'player_details'}->{'money'} < $details->{'money_cost'})
      {
         $tmpl_vars->{'error_message'} = 'You do not have enough money to build this expansion, you require ' . $details->{'money_cost'};
         return;
      }
      unless($self->player_has_technology($player_ID,$details->{'require_tech_ID'})) {
         $tmpl_vars->{'error_message'} = 'You do not have the required technology to build this expansion';
         return;
      }
      if($details->{'require_land_ID'} != 0)
      {
         if($details->{'require_land_ID'} < 0)
         {
            # Anywhere execept this land type
            if($check_square->{'land_type_ID'} == -$details->{'require_land_ID'})
            {
               $tmpl_vars->{'error_message'} = 'This expansion cannot be built on ' . $self->land_type_name($self->{'from_square_details'}->{'land_type_ID'});
               return;
            }
         } else {
            unless($check_square->{'land_type_ID'} == $details->{'require_land_ID'})
            {
               $tmpl_vars->{'error_message'} = 'This expansion cannot be built on ' . $self->land_type_name($self->{'from_square_details'}->{'land_type_ID'}) . ' only on ' . $self->land_type_name($details->{'require_land_ID'});
               return;
            }
         }
      }
      unless($self->{'from_square_details'}->{'owner_ID'} == $player_ID)
      {
         $tmpl_vars->{'error_message'} = 'You can only build expansions on sqaures you own';
         return;
      }

      # Remove money
      my $update =
      {
         'money'  => $self->{'player_details'}->{'money'} - $details->{'money_cost'}
      };
      $error_code = $self->db_update($self->config('game_player_table'),
                                        $update,
                                        {'game_ID'       => $game_ID,
                                         'ID'            => $player_ID
                                        });
      if($error_code)
      {
         $self->throw_error($error_code,
                            "Update error in ViewSquare->set_money");
      }
   }
   
   # Store move
   
   # If exist modify
   if($exists)
   {
      if(($current_move_units - $units) <= $self->{'spare_units'})
      {
         $self->debug(9,"$current_move_units - $units <= $self->{'spare_units'}");
         my $owner_ID = $to_square_details->{'owner_ID'};
#         if ($to_square_details->{'land_type_ID'} != LAND_TYPE_SEA)
#         {
            $owner_ID = $player_ID;
#         }
         if($move_type_ID != MOVE_TYPE_CELEBRATION &&
            $move_type_ID != MOVE_TYPE_PEACE && $units == 0)
         {
            # Cancel the move
            # Note because celebration and peace require no units, they cannot
            # be cancelled this way
            $error_code = $self->db_delete(
                                       $self->config('game_board_move_table'),
                                       {'ID' => $current_move_ID});
         } else {
            # Modify existing
            my $update =
            {
               'units'  => $units
            };
            $error_code = $self->db_update($self->config('game_board_move_table'),
                                              $update,
                                              {'game_ID'      => $game_ID,
                                               'owner_ID'     => $owner_ID,
                                               'from_across'  => $column,
                                               'from_down'    => $row,
                                               'to_across'    => $to_column,
                                               'to_down'      => $to_row,
                                               'move_type_ID' => $move_type_ID
                                              });
         }
         if($error_code)
         {
            $self->throw_error($error_code,
                               "Update error in ViewSquare->update_units");
         }
         $self->{'spare_units'} -= $current_move_units - $units;
         $self->{'max_recruits'} -= $current_move_units - $units;
         $self->{'unused_units'} += $current_move_units - $units;
         $self->{'used_units'} -= $current_move_units - $units;
         $self->debug(9,"U;S:$self->{'spare_units'},MR:$self->{'max_recruits'},UU:$self->{'unused_units'},U:$self->{'used_units'}");
         $move =
         {
            'game_ID'      => $game_ID,
            'owner_ID'     => $owner_ID,
            'from_across'  => $column,
            'from_down'    => $row,
            'to_across'    => $to_column,
            'to_down'      => $to_row,
            'units'        => $units,
            'move_type_ID' => $move_type_ID
         };
         my ($across_mod, $down_mod, $direction) = 
            $self->get_area_units($move,$column,$row);

         # We must now adjust the area array
         $tmpl_vars->{'area'}->[1]->{'col'}->[1]->{'units'} += $current_move_units - $units;
         if($direction)
         {
            $tmpl_vars->{'area'}->[1 + $down_mod]->{'col'}->[1 + $across_mod]->{'units'} -= $current_move_units - $units;
         }

      } else {
         $self->debug(9,"Not $current_move_units - $units <= $self->{'spare_units'}");
         $tmpl_vars->{'error_message'} = 'That move cannot be reduced, unless you assign less recruits';
         $error_code = ERROR_NONE;
      }
   } else {
      # insert new
      my $owner_ID = $to_square_details->{'owner_ID'};
#      if ($to_square_details->{'land_type_ID'} != LAND_TYPE_SEA)
#      {
         $owner_ID = $player_ID;
#      }
      my $insert =
      {
         'game_ID'      => $game_ID,
         'owner_ID'     => $owner_ID,
         'from_across'  => $column,
         'from_down'    => $row,
         'to_across'    => $to_column,
         'to_down'      => $to_row,
         'units'        => $units,
         'move_type_ID' => $move_type_ID
      };
      my ($error_code, $board_ID) = $self->db_insert(
                         $self->config('game_board_move_table'), $insert);
      if($error_code)
      {
         $self->throw_error($error_code,
                            "Select error in ViewSquare->event_Move");
      }
      $self->{'spare_units'} += $units;
      $self->{'max_recruits'} += $units;
      if($self->{'max_recruits'} > $self->{'remaining_recruits'})
      {
         $self->{'max_recruits'} = $self->{'remaining_recruits'};
      }
      $self->{'unused_units'} -= $units;
      $self->{'used_units'} += $units;
      $self->debug(9,"I;S:$self->{'spare_units'},MR:$self->{'max_recruits'},UU:$self->{'unused_units'},U:$self->{'used_units'}");
      $move =
      {
         'game_ID'      => $game_ID,
         'owner_ID'     => $owner_ID,
         'from_across'  => $column,
         'from_down'    => $row,
         'to_across'    => $to_column,
         'to_down'      => $to_row,
         'units'        => $units,
         'move_type_ID' => $move_type_ID
      };
      my ($across_mod, $down_mod, $direction) = 
         $self->get_area_units($move,$column,$row);
      $tmpl_vars->{'area'}->[1]->{'col'}->[1]->{'units'} -= $units;
      if($direction)
      {
         $tmpl_vars->{'area'}->[1 + $down_mod]->{'col'}->[1 + $across_mod]->{'units'} += $units;
      }
   }
   
   # Clear this out or it appears in the state as plain text
   $self->move_from_cgi_vars_to_tmpl_vars(
      ['move_type_ID','direction','units'],
      OVERWRITE_MOVE_ANYWAY);
   return; 
}

#-----------------------------------------------------------------------------
# Function: 	event_Recruits
#-----------------------------------------------------------------------------
# Description:
# 					Checks the move selection, and adds to pending moves
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Next Action				OUT:0	The module name to run next or undef for none
# Next Actions ArgumentsOUT:1	The arguments to pass to the next modules new
#-----------------------------------------------------------------------------
sub event_Recruits
{
	my $self 	=	shift;

   $self->debug(8, 'ViewSquare::event_Recruits');

   my $cgi_vars      = $self->{'cgi_vars'};
   my $tmpl_vars     = $self->{'tmpl_vars'};
   my $game_ID       = $cgi_vars->{'game_ID'};
   my $member_ID     = $cgi_vars->{'member_ID'};
   my $player_ID     = $self->get_player_ID($member_ID, $game_ID);
   my $row           = $cgi_vars->{'row'};
   my $column        = $cgi_vars->{'column'};
   my $units         = $cgi_vars->{'recruits'};

   # Check we are a base
   unless($self->{'from_square_details'}->{'expansion_type_ID'} == EXPANSION_TYPE_BASE)
   {
       $tmpl_vars->{'error_message'} = 'Recruits can only be assigned to your bases';
       return;
   }

   # Check the player has enough recruits
   if($units > $self->{'remaining_recruits'})
   {
       $tmpl_vars->{'error_message'} = "You don't have that many recruits left";
       return;
   }
   
   # Check for existing move
   my ($error_code, $move) = $self->db_select('get_game_square_move',
      {'game_board_move' => $self->config('game_board_move_table')},
      $game_ID, $column, $row, $column, $row, MOVE_TYPE_RECRUIT, $player_ID);
   if($error_code)
   {
      $self->throw_error($error_code,
                         "Select error in ViewSquare->event_Recruit");
   }
   my $exists = 0;
   my $current_move_ID = 0;
   my $current_move_units = 0;
   if(defined($move) && @{$move})
   {
      # Move exists, so replace it
      $exists = 1;
      $current_move_ID = $move->[0]->{'ID'};
      $current_move_units = $move->[0]->{'units'};
      $move = $move->[0];
   }

   # Check we aren't going to over populate the square
   if($self->{'unused_units'} + $units > 9)
   {
      $tmpl_vars->{'error_message'} = 'You cannot assign that many recruits to this sqaure, you can only assign ' . (9 - $self->{'max_recruits'});
      return;
   }
   
   # Store Recruits
   
   # If exist modify
   if($exists)
   {
      if($units == 0)
      {
         # Cancel the assignment of recruits
         $error_code = $self->db_delete($self->config('game_board_move_table'),
                                          {'ID' => $current_move_ID});
      } else {
         # Modify existing
         my $update =
         {
            'units'  => $units
         };
         $error_code = $self->db_update($self->config('game_board_move_table'),
                                           $update,
                                           {'game_ID'      => $game_ID,
                                            'owner_ID'     => $player_ID,
                                            'from_across'  => $column,
                                            'from_down'    => $row,
                                            'to_across'    => $column,
                                            'to_down'      => $row,
                                            'move_type_ID' => MOVE_TYPE_RECRUIT
                                           });
      }
      if($error_code)
      {
         $self->throw_error($error_code,
                            "Update error in ViewSquare->update_units");
      }
      $self->{'spare_units'} += $current_move_units - $units;
      $self->{'max_recruits'} += $current_move_units - $units;
      $self->{'remaining_recruits'} -= $units - $current_move_units;
      if($self->{'max_recruits'} > $self->{'remaining_recruits'})
      {
         $self->{'max_recruits'} = $self->{'remaining_recruits'};
      }
      $tmpl_vars->{'incoming_recruits'} -= $current_move_units - $units;
      $self->{'assigned_recruits'} -= $current_move_units - $units;
      $self->decrease_recruits($player_ID, $units - $current_move_units);
#      my ($across_mod, $down_mod, $direction) = 
#         $self->get_area_units($move,$column,$row);
   } elsif($units > 0) {
      # insert new
      $move =
      {
         'game_ID'      => $game_ID,
         'owner_ID'     => $player_ID,
         'from_across'  => $column,
         'from_down'    => $row,
         'to_across'    => $column,
         'to_down'      => $row,
         'units'        => $units,
         'move_type_ID' => MOVE_TYPE_RECRUIT
      };
      my ($error_code, $board_ID) = $self->db_insert(
                         $self->config('game_board_move_table'), $move);
      if($error_code)
      {
         $self->throw_error($error_code,
                            "Select error in ViewSquare->event_Recruits");
      }
      $self->{'spare_units'} -= $units;
      $self->{'max_recruits'} -= $units;
      $tmpl_vars->{'incoming_recruits'} += $units;
      $self->{'assigned_recruits'} += $units;
      $self->{'remaining_recruits'} -= $units;
      $self->decrease_recruits($player_ID, $units);
#      my ($across_mod, $down_mod, $direction) = 
#         $self->get_area_units($move,$column,$row);
   }
   
   # Clear this out or it appears in the state as plain text
   $self->move_from_cgi_vars_to_tmpl_vars(
      ['recruits'],
      OVERWRITE_MOVE_ANYWAY);
   return; 
}

1;
