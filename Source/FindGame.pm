#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		FindGame
#-----------------------------------------------------------------------------
# Description:
# 					This module is used to allow members to log on
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2004/09/05 17:03:21 $
# $Revision: 1.11 $
#-----------------------------------------------------------------------------
package TotalLeader::Source::FindGame;
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
      'find_game_name'     => {'type' => FIELD_TYPE_STRING, 'required' => 0,
                           'display_name' => 'Game Name'},
      'players'              => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 1,'maximum' => 16,'required' => 0,
                           'display_name' => 'Number of Players'},
      'board_width'        => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 50,'maximum'=> 2000,'required' => 0,
                           'display_name' => 'Board Width'},
      'board_height'       => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 50,'maximum'=> 2000,'required' => 0,
                           'display_name' => 'Board Height'},
      'turn_frequency'     => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 1,'maximum'=> 168,'required' => 0,
                           'display_name' => 'Turn Tick Frequency'},
      'turn_weekday_type_ID'=> {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 1,'maximum'=> 3,'required' => 0,
                           'display_name' => 'Turn Tick Frequency'},
      'start_hour'         => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 0,'maximum' => 23,
                           'display_name' => 'Turn Tick Start'},
      'stop_hour'          => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 0,'maximum' => 23,
                           'display_name' => 'Turn Tick Stop'},
      'start_day'            => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 1,'maximum' => 31,'required' => 0,
                           'display_name' => 'Start Day'},
      'start_month'          => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 1,'maximum' => 12,'required' => 0,
                           'display_name' => 'Start Month'},
      'start_year'           => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 2003,'maximum'=>2035,'required' => 0,
                           'display_name' => 'Start Year'},
      'max_turns'         => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 100,'maximum'=>10000,
                           'display_name' => 'Maximum Game Turns'},

   };
sub FIELDS() { $fields; };

sub TEMPLATE() { 'find_game.html' };

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
#   $self->debug(8, 'FindGame::check_cgi_vars');
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

   $self->debug(8, 'FindGame::setup_tmpl_vars');
   
   $self->create_numeric_drop_down(
      'players', ($self->{'cgi_vars'}->{'players'}||8),2,16,1,0,'Any');
   $self->create_numeric_drop_down(
      'board_width', ($self->{'cgi_vars'}->{'board_width'}||1000),50,2000,50,0,'Any');
   $self->create_numeric_drop_down(
      'board_height', ($self->{'cgi_vars'}->{'board_height'}||1000),50,2000,50,0,'Any');
   $self->create_drop_down_from_array(
      'turn_frequency', $self->{'cgi_vars'}->{'turn_frequency'},
         (
            {'ID' => -1, 'name' => 'Any'},
            {'ID' => 1, 'name' => '1 hour'},
            {'ID' => 2, 'name' => '2 hours'},
            {'ID' => 3, 'name' => '3 hours'},
            {'ID' => 6, 'name' => '6 hours'},
            {'ID' => 12, 'name' => '12 hours'},
            {'ID' => 24, 'name' => '1 day'},
            {'ID' => 48, 'name' => '2 days'},
            {'ID' => 72, 'name' => '3 days'},
            {'ID' => 96, 'name' => '4 days'},
            {'ID' => 120, 'name' => '5 days'},
            {'ID' => 144, 'name' => '6 days'},
            {'ID' => 168, 'name' => '1 week'}
         )
      );
   $self->create_drop_down_from_array(
      'turn_weekday_type_ID', $self->{'cgi_vars'}->{'turn_weekday_type_ID'},
         (
            {'ID' => 0,'name' => 'Any Type'},  
            {'ID' => FREQUENCY_TYPE_ALL,'name' => '7 Days a Week'},  
            {'ID' => FREQUENCY_TYPE_WEEKDAYS,'name' => 'Weekdays Only'},  
            {'ID' => FREQUENCY_TYPE_WEEKENDS,'name' => 'Weekends Only'}  
         )
      );
   $self->create_numeric_drop_down(
      'start_hour', $self->{'cgi_vars'}->{'start_hour'} || 9,0,23,1,0,'Any');
   $self->create_numeric_drop_down(
      'stop_hour', $self->{'cgi_vars'}->{'stop_hour'} || 17,0,23,1,0,'Any');
   $self->create_numeric_drop_down(
      'start_day', $self->{'cgi_vars'}->{'start_day'} || 1,1,31,1,1,'Any');
   $self->create_drop_down_from_array(
      'start_month', $self->{'cgi_vars'}->{'start_month'},
         (
            {'ID' => -1,'name' => 'Any'},
            {'ID' => 1, 'name' => 'January'},
            {'ID' => 2, 'name' => 'Febuary'},
            {'ID' => 3, 'name' => 'March'},
            {'ID' => 4, 'name' => 'April'},
            {'ID' => 5, 'name' => 'May'},
            {'ID' => 6, 'name' => 'June'},
            {'ID' => 7, 'name' => 'July'},
            {'ID' => 8, 'name' => 'August'},
            {'ID' => 9, 'name' => 'September'},
            {'ID' => 10, 'name' => 'October'},
            {'ID' => 11, 'name' => 'November'},
            {'ID' => 12, 'name' => 'December'}
         )
      );
   $self->create_numeric_drop_down(
      'start_year', ($self->{'cgi_vars'}->{'start_year'}||1975),2003,2004,1,0,'Any');

   # Clear this out or it appears in the state as plain text
   $self->move_from_cgi_vars_to_tmpl_vars(
      ['find_game_name','players','board_width','board_height','turn_frequence',
         'turn_weekday_type_ID','start_hour','stop_hour', 'started',
         'start_day','start_month','start_year','min_turns','max_turns'],
      OVERWRITE_MOVE_ANYWAY);
}

#-----------------------------------------------------------------------------
# Function: 	event_FindGame
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
sub event_FindGame
{
	my $self 	=	shift;

   $self->debug(8, 'FindGame::event_FindGame');

   my $game_name = $self->{'cgi_vars'}->{'find_game_name'};
   my $players = $self->{'cgi_vars'}->{'players'};
   my $board_width = $self->{'cgi_vars'}->{'board_width'};
   my $board_height = $self->{'cgi_vars'}->{'board_height'};
   my $turn_frequency = $self->{'cgi_vars'}->{'turn_frequency'};
   my $turn_weekday_type_ID = $self->{'cgi_vars'}->{'turn_weekday_type_ID'};
   my $start_hour = $self->{'cgi_vars'}->{'start_hour'};
   my $stop_hour = $self->{'cgi_vars'}->{'stop_hour'};
   my $start_day = $self->{'cgi_vars'}->{'start_day'};
   my $start_month = $self->{'cgi_vars'}->{'start_month'};
   my $start_year = $self->{'cgi_vars'}->{'start_year'};
   my $min_turns = $self->{'cgi_vars'}->{'min_turns'};
   my $max_turns = $self->{'cgi_vars'}->{'max_turns'};
   my $started = $self->{'cgi_vars'}->{'started'};
   my $done = $self->{'cgi_vars'}->{'done'};

   my $where;
   my @params;
   my $and = '';
   if(defined($started))
   {
      if($started != 0)
      {
         $where .= "$and turn > 0";
      } else {
         $where .= "$and turn = 0";
      }
      $and = ' AND ';
      $done = 0;
   }
   if(defined($done))
   {
      $where .= "$and done = $done";
      $and = ' AND ';
   }
   if($game_name && $game_name ne '')
   {
      $where .= "$and name = ?";
      push @params, $game_name;
      $and = ' AND ';
   }
   if($players && $players != -1)
   {
      $where .= "$and players = ?";
      push @params, $players;
      $and = ' AND ';
   }
   if($board_width && $board_width != -1)
   {
      $where .= "$and width = ?";
      push @params, $board_width;
      $and = ' AND ';
   }
   if($board_height && $board_height != -1)
   {
      $where .= "$and height = ?";
      push @params, $board_height;
      $and = ' AND ';
   }
   if($turn_frequency && $turn_frequency != -1)
   {
      $where .= "$and turn_frequency_hours = ?";
      push @params, $turn_frequency;
      $and = ' AND ';
   }
   if($turn_weekday_type_ID && $turn_weekday_type_ID != -1)
   {
      $where .= "$and turn_weekday_type_ID = ?";
      push @params, $turn_weekday_type_ID;
      $and = ' AND ';
   }
   if($start_hour && $start_hour != -1)
   {
      $where .= "$and start_hour = ?";
      push @params, $start_hour;
      $and = ' AND ';
   }
   if($stop_hour && $stop_hour != -1)
   {
      $where .= "$and stop_hour = ?";
      push @params, $stop_hour;
      $and = ' AND ';
   }
   my $start_date;
   if($start_day && $start_month && $start_year && 
      $start_day != -1 && $start_month != -1 && $start_year != -1)
   {
      $start_date = 
         sprintf("%04d-%02d-%02d", $start_year, $start_month, $start_day);
   }
   if($start_date)
   {
      $where .= "$and start_date = ?";
      push @params, $start_date;
      $and = ' AND ';
   }
   if($min_turns && $min_turns != -1)
   {
      $where .= "$and max_turns >= ?";
      push @params, $min_turns;
      $and = ' AND ';
   }
   if($max_turns && $max_turns != -1)
   {
      $where .= "$and max_turns <= ?";
      push @params, $max_turns;
      $and = ' AND ';
   }
   $where ||= '1'; # If nothing to search for, search for everything
   
   my $search_string = 'find_games::game=>' . $self->config('game_table');
   $search_string .= ';;search_params=>' . $where;
   if(@params)
   {
      $search_string .= '::' . join('::', @params);
   }
   
   $self->debug(8, "Search string: $search_string");
   
   return ('FoundGames',{'search_string' => $search_string});
}

1;
