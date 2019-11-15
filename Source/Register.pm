#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		Register
#-----------------------------------------------------------------------------
# Description:
# 					This module is used to allow members to log on
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2004/09/04 17:00:37 $
# $Revision: 1.12 $
#-----------------------------------------------------------------------------
package TotalLeader::Source::Register;
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

my $fields =
   {
      'username'           => {'type' => FIELD_TYPE_EMAIL,'required' => 1,
                           'display_name' => 'E-Mail'},
      'password'           => {'type' => FIELD_TYPE_PASSWORD,'required' => 1,
                           'display_name' => 'Password'},
      'confirm_password'   => {'type' => FIELD_TYPE_PASSWORD,'required' => 1,
                           'display_name' => 'Confirm Password'},
      'screen_name'        => {'type' => FIELD_TYPE_STRING,'required' => 1,
                           'display_name' => 'Screen Name'},
      'firstname'          => {'type' => FIELD_TYPE_STRING,'required' => 1,
                           'display_name' => 'First Name'},
      'surname'            => {'type' => FIELD_TYPE_STRING,'required' => 1,
                           'display_name' => 'Surname'},
      'dob_day'            => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 1,'maximum' => 31,'required' => 1,
                           'display_name' => 'Date Of Birth Day'},
      'dob_month'          => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 1,'maximum' => 12,'required' => 1,
                           'display_name' => 'Date Of Birth Month'},
      'dob_year'           => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 1880,'maximum'=>2035,'required' => 1,
                           'display_name' => 'Date OF Birth Year'},
      'gender_ID'          => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 1,'maximum'=> 2,'required' => 1,
                           'display_name' => 'Gender'},
      'resolution'         => {'type' => FIELD_TYPE_STRING,'required' => 1,
                           'display_name' => 'Resolution'},

   };
sub FIELDS() { $fields; };

sub TEMPLATE() { 'register.html' };

my $resolution_map = {
   '800by600' => [5,8],
   '1024by768' => [6,10],
   '1200by1024' => [7,12],
   '1600by1200' => [8,14]
};

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
#   $self->debug(8, 'Register::check_cgi_vars');
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

   $self->debug(8, 'Register::setup_tmpl_vars');
   
   $self->create_numeric_drop_down(
      'dob_day', $self->{'cgi_vars'}->{'dob_day'},1,31,1,1);
   $self->create_drop_down_from_array(
      'dob_month', $self->{'cgi_vars'}->{'dob_month'},
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
      'dob_year', ($self->{'cgi_vars'}->{'dob_year'}||1975),1880,2003);

   $self->create_drop_down_from_array(
      'gender', $self->{'cgi_vars'}->{'gender_ID'},
         (
            #            {'ID' => 1, 'name' => 'None'},
            {'ID' => 2, 'name' => 'Male'},
            {'ID' => 3, 'name' => 'Female'}
         )
      );
   
   my @resolution_array;
   foreach (keys %{$resolution_map})
   {
      push @resolution_array, {'ID' => $_, 'name' => $_};
   }
   $self->create_drop_down_from_array(
      'resolution', $self->{'cgi_vars'}->{'resolution'},
         @resolution_array
      );
   
   # Clear this out or it appears in the state as plain text
   $self->move_from_cgi_vars_to_tmpl_vars(
      ['username','password','confirm_password','screen_name',
      'firstname','surname','dob_day','dob_month','dob_year','gender_ID',
      'resolution'],
      OVERWRITE_MOVE_ANYWAY);
}

#-----------------------------------------------------------------------------
# Function: 	event_Register
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
sub event_Register
{
	my $self 	=	shift;

   $self->debug(8, 'Register::event_Register');

   my $username      = $self->{'cgi_vars'}->{'username'};
   my $password      = $self->{'cgi_vars'}->{'password'};
   my $confirm_password = $self->{'cgi_vars'}->{'confirm_password'};
   my $screen_name   = $self->{'cgi_vars'}->{'screen_name'};
   my $firstname     = $self->{'cgi_vars'}->{'firstname'};
   my $surname       = $self->{'cgi_vars'}->{'surname'};
   my $dob_day       = $self->{'cgi_vars'}->{'dob_day'};
   my $dob_month     = $self->{'cgi_vars'}->{'dob_month'};
   my $dob_year      = $self->{'cgi_vars'}->{'dob_year'};
   my $gender_ID     = $self->{'cgi_vars'}->{'gender_ID'};
   my $resolution    = $self->{'cgi_vars'}->{'resolution'};

   $self->debug(8, "Register member " . $username);

   if($password ne $confirm_password)
   {
      $self->{'tmpl_vars'}->{'need_password'} = 1;
      $self->{'tmpl_vars'}->{'error_message'} = 'Passwords do not match'; 
      return;
   }
   
   my $dob = sprintf("%04d-%02d-%02d", $dob_year,$dob_month,$dob_day);
   my ($error_code, $member_ID) = $self->add_member(
         {  'username'     => $username,
            'password'     => $password,
            'screen_name'  => $screen_name,
            'firstname'    => $firstname,
            'surname'      => $surname,
            'dob'          => $dob,
            'gender_ID'    => $gender_ID,
            'state_ID'     => MEMBER_STATE_REGISTERED
         }
      );
   $self->debug(8, "Results Error:$error_code, Member ID:" . ($member_ID||'none'));
   
   if($error_code)
   {
      $self->event('User add failed for member ' . $username);
      $self->{'cgi_vars'}->{'error_message'} = 'Register failed';
      return;
   }

   
   my ($show_rows,$show_columns) = @{$resolution_map->{$resolution}};
   # Add the member to member details table
   my $member_detail_ID;
   ($error_code, $member_detail_ID) = $self->add_member_site_details(
         {  'member_ID'    => $member_ID,
            'show_rows'    => $show_rows,
            'show_columns' => $show_columns
         }
      );
   if($error_code)
   {
      $self->event('User add failed for member ' . $username);
      $self->{'cgi_vars'}->{'error_message'} = 'Register failed';
      return;
   }

   $self->send_activation_email($member_ID,$username,$firstname,$surname);
   
   # HACK!!
   return ('Welcome',{'message' => $self->{'hack_macros'}});
   # END HACK!

   
   return ('Welcome',{'message' => 
      'Registration complete, please wait for your account activation email'});
}

#-----------------------------------------------------------------------------
# Function: 	add_member_site_details
#-----------------------------------------------------------------------------
# Description:
# 					Adds the site specific member details to the database
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# User Details          IN:0  A hash containing the member details to add
#-----------------------------------------------------------------------------
sub add_member_site_details
{
	my $self 	=	shift;
	my $details = $_[0];

   $self->debug(8, 'Register->add_member_site_details');
   unless(  exists($details->{'member_ID'}) &&
            exists($details->{'show_rows'}) &&
            exists($details->{'show_columns'})
         )
   {
      $self->error(ERROR_SEVERITY_ERROR, ERROR_MISSING_PARAMETER, 
         'Required parameter missing for add member site details');
      return ERROR_MISSING_PARAMETER;
   }

   return $self->db_insert($self->config('member_details_table'), $details);
}

#-----------------------------------------------------------------------------
# Function: 	send_activation_email
#-----------------------------------------------------------------------------
# Description:
# 					sends out an email to the new user, with an activation link
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# NONE
#-----------------------------------------------------------------------------
sub send_activation_email
{
	my $self 	      =	shift;
   my $member_ID     = $_[0];
   my $email_address = $_[1];
   my $firstname     = $_[2];
   my $surname       = $_[3];
   
   $self->debug(8, 'Register::send_activation_email');
   # Create the activation checksum. We will check this later to ensure the
   # user is unique 
   my ($error_code, $md5_member_ID) = $self->generate_md5($member_ID);

   my $template = $self->config('activation_email_template');
   my $name = $firstname . " " . $surname;
   my $sender = $self->config('activation_email_from');
   my $subject = $self->config('activation_email_subject');
   my $content_type = $self->config('activation_email_content_type');
   
   my $message; 
   #check to see if the file is readable
   if (-r $template)
   {
     $self->debug(8, "getting the email template");
     open (FILE,$template);
     my $line = "";

     $self->debug(8, "opened template");
     while (<FILE>)
     {
        $line = $_;
        chomp ($line);
        $message .=$line;
     }
     close (FILE);  
     $self->debug(8, "read template");
   }
   else
   {
      $self->throw_error(ERROR_IO_FILE_OPEN,
         "The email template does not exist ($template)");
   }   

   # This is the link that will be send to the user.
   # It contains the activation key and the user id
   my $system_url = $self->config('system_url');

   my $email_details ={ 'name'         => $name,
                        'system_url'   => $system_url,
                        'member_ID'    => $member_ID,
                        'checksum'     => $md5_member_ID,
                        'sender'       => $sender
                  };

   my ($parsed_message) = $self->parse_string($message,$email_details);

   $self->debug(8, "The email template is $message which became $parsed_message");

   # generating the email to send out to the user
   $self->send_email({  'subject'      => $subject,
                        'to'           => $email_address,
                        'from'         => $sender,
                        'content-type' => $content_type,
                        'message'      => $parsed_message
                     });
   # HACK!!! 
   $self->{'hack_macros'} = $parsed_message;
                     
   return;
}

1;
