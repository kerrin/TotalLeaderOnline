#-----------------------------------------------------------------------------
# Module: 		CreateGame
#-----------------------------------------------------------------------------
# Description:
# 					This module is used to allow members to create a new game
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2004/09/04 21:28:17 $
# $Revision: 1.11 $
#-----------------------------------------------------------------------------
package TotalLeader::Source::CreateGame;
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
      'game_name'          => {'type' => FIELD_TYPE_STRING,'required' => 1,
                              'display_name' => 'Game Name'},
      'players'            => {'type' => FIELD_TYPE_NUMBER,'required' => 1,
                           'minimum' => 2,'maximum' => 16,
                           'display_name' => 'Players'},
      'board_width'        => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 20,'maximum'=> 100,'required' => 1,
                           'display_name' => 'Board Width'},
      'board_height'       => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 20,'maximum'=> 100,'required' => 1,
                           'display_name' => 'Board Height'},
      'turn_frequency'     => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 1,'maximum'=> 168,'required' => 1,
                           'display_name' => 'Turn Tick Frequency'},
      'turn_weekday_type_ID'=> {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 1,'maximum'=> 3,'required' => 1,
                           'display_name' => 'Turn Tick Frequency'},
      'start_hour'         => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 0,'maximum' => 23,
                           'display_name' => 'Turn Tick Start'},
      'stop_hour'          => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 0,'maximum' => 23,
                           'display_name' => 'Turn Tick Stop'},
      'start_day'          => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 1,'maximum' => 31,'required' => 1,
                           'display_name' => 'Game Start Day'},
      'start_month'        => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 1,'maximum' => 12,'required' => 1,
                           'display_name' => 'Game Start Month'},
      'start_year'         => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 1880,'maximum'=>2035,'required' => 1,
                           'display_name' => 'Game Start Year'},
      'game_turns'         => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 100,'maximum'=>10000,
                           'display_name' => 'Maximum Game Turns'},

   };
sub FIELDS() { $fields; };

sub TEMPLATE() { 'create_game.html' };

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
sub check_cgi_vars
{
	my $self 	=	shift;

   $self->debug(8, 'CreateGame::check_cgi_vars');

   unless($self->logged_on())
   {
      return ERROR_CHECK_FAIL;
   }
   
	return $self->SUPER::check_cgi_vars(@_); 
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

   $self->debug(8, 'CreateGame::setup_tmpl_vars');
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = gmtime(time);
   $mon++;
   $year += 1900;
   $self->debug(9, "$sec,$min,$hour,$mday,$mon,$year,$wday,$yday");
   
   $self->create_numeric_drop_down(
      'players', ($self->{'cgi_vars'}->{'players'}||8),2,16);
   $self->create_numeric_drop_down(
      'board_width', ($self->{'cgi_vars'}->{'board_width'}||50),20,100,20);
   $self->create_numeric_drop_down(
      'board_height', ($self->{'cgi_vars'}->{'board_height'}||50),20,100,20);
   $self->create_drop_down_from_array(
      'turn_frequency', $self->{'cgi_vars'}->{'turn_frequency'},
         (
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
            {'ID' => FREQUENCY_TYPE_ALL,'name' => '7 Days a Week'},  
            {'ID' => FREQUENCY_TYPE_WEEKDAYS,'name' => 'Weekdays Only'},  
            {'ID' => FREQUENCY_TYPE_WEEKENDS,'name' => 'Weekends Only'}  
         )
      );
   $self->create_numeric_drop_down(
      'start_hour', $self->{'cgi_vars'}->{'start_hour'} || 9,0,23,1);
   $self->create_numeric_drop_down(
      'stop_hour', $self->{'cgi_vars'}->{'stop_hour'} || 17,0,23,1);
   $self->create_numeric_drop_down(
      'start_day', $self->{'cgi_vars'}->{'start_day'} || 
         $self->make_valid_month_day($mday+1,$mon,$year), 1,31,1,1);
   $self->create_drop_down_from_array(
      'start_month', $self->{'cgi_vars'}->{'start_month'} || $mon,
         (
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
      'start_year', ($self->{'cgi_vars'}->{'start_year'}||$year),$year,$year+1);

   # Clear this out or it appears in the state as plain text
   $self->move_from_cgi_vars_to_tmpl_vars(
      ['game_name','players','board_width','board_height','turn_frequency',
         'turn_weekday_type_ID','start_hour','stop_hour',
         'start_day','start_month','start_year','game_turns'],
      OVERWRITE_MOVE_ANYWAY);
}

#-----------------------------------------------------------------------------
# Function: 	event_CreateGame
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
sub event_CreateGame
{
	my $self 	=	shift;

   $self->debug(8, 'CreateGame::event_CreateGame');

   my $game_name  = $self->{'cgi_vars'}->{'game_name'} || '';
   my $players = $self->{'cgi_vars'}->{'players'} || 8;
   my $board_width = $self->{'cgi_vars'}->{'board_width'} || 20;
   my $board_height = $self->{'cgi_vars'}->{'board_height'} || 20;
   my $turn_frequency = $self->{'cgi_vars'}->{'turn_frequency'} || 1;
   my $turn_weekday_type_ID = $self->{'cgi_vars'}->{'turn_weekday_type_ID'} || 1;
   my $start_hour = $self->{'cgi_vars'}->{'start_hour'} || 0;
   my $stop_hour = $self->{'cgi_vars'}->{'stop_hour'} || 0;
   my $start_day = $self->{'cgi_vars'}->{'start_day'};
   my $start_month = $self->{'cgi_vars'}->{'start_month'};
   my $start_year = $self->{'cgi_vars'}->{'start_year'};
   my $game_turns = $self->{'cgi_vars'}->{'game_turns'} || 1000;

   $self->debug(8, "Create Game by member " . 
      $self->{'cgi_vars'}->{'member_ID'});

   my $start_date = 
      sprintf("%04d-%02d-%02d %02d:00:00", 
         $start_year, $start_month, $start_day,$start_hour);
   my ($error_code, $game_ID) = $self->add_game(
         {  'creator_ID'                  => $self->{'cgi_vars'}->{'member_ID'},
            'players'                     => $players,
            'name'                        => $game_name,
            'width'                       => $board_width,
            'height'                      => $board_height,
            'turn_frequency_hours'        => $turn_frequency,
            'frequency_weekday_type_ID'   => $turn_weekday_type_ID,
            'turn_start_time'             => $start_hour.':00:00',
            'turn_stop_time'              => $stop_hour.':00:00',
            'start_date_time'             => $start_date,
            'max_turns'                   => $game_turns,
            'next_turn'                   => $start_date
         }
      );
   $self->debug(8, "Results $error_code," . ($game_ID||'none'));
   
   if($error_code)
   {
      $self->event('Game add failed for member' . 
         $self->{'cgi_vars'}->{'member_ID'});
      $self->{'cgi_vars'}->{'error_message'} = 'Add Game Failed';
      return;
   }
   
   return ('FoundGames',{'my_games' => 1, 'no_check' => 1});
}

1;
