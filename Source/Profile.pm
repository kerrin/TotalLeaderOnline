#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		Profile
#-----------------------------------------------------------------------------
# Description:
# 					This module is used to allow members to log on
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2004/09/04 17:00:37 $
# $Revision: 1.1 $
#-----------------------------------------------------------------------------
package TotalLeader::Source::Profile;
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
      'password'           => {'type' => FIELD_TYPE_PASSWORD,
                           'display_name' => 'Password'},
      'confirm_password'   => {'type' => FIELD_TYPE_PASSWORD,
                           'display_name' => 'Confirm Password'},
      'screen_name'        => {'type' => FIELD_TYPE_STRING,'required' => 1,
                           'display_name' => 'Screen Name'},
      'firstname'          => {'type' => FIELD_TYPE_STRING,'required' => 1,
                           'display_name' => 'First Name'},
      'surname'            => {'type' => FIELD_TYPE_STRING,'required' => 1,
                           'display_name' => 'Surname'},
      'gender_ID'          => {'type' => FIELD_TYPE_NUMBER,
                           'minimum' => 1,'maximum'=> 2,'required' => 1,
                           'display_name' => 'Gender'},
      'size_across'        => {'type' => FIELD_TYPE_NUMBER,'required' => 1,
                           'minimum' => 1,'maximum'=> 15,
                           'display_name' => 'Board Size Across'},
      'size_down'          => {'type' => FIELD_TYPE_NUMBER,'required' => 1,
                           'minimum' => 1,'maximum'=> 10,
                           'display_name' => 'Board Size Down'},

   };
sub FIELDS() { $fields; };

sub TEMPLATE() { 'profile.html' };

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
#   $self->debug(8, 'Profile::check_cgi_vars');
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

   my $tmpl_vars = $self->{'tmpl_vars'};
   
   $self->debug(8, 'Profile::setup_tmpl_vars');
   
   my $member_details = $self->member_details();

   $self->create_drop_down_from_array(
      'gender', $self->{'cgi_vars'}->{'gender_ID'} || $member_details->{'gender_ID'},
         (
            #            {'ID' => 1, 'name' => 'None'},
            {'ID' => 2, 'name' => 'Male'},
            {'ID' => 3, 'name' => 'Female'}
         )
      );
   
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
   my $show_rows = $details->[0]->{'show_rows'};
   my $show_columns = $details->[0]->{'show_columns'};

   $self->create_numeric_drop_down(
      'size_across', $self->{'cgi_vars'}->{'size_across'}||$show_columns,1,15);
   $self->create_numeric_drop_down(
      'size_down', $self->{'cgi_vars'}->{'size_down'}||$show_rows,1,10);
   
   $tmpl_vars->{'username'} = $member_details->{'username'};
   $tmpl_vars->{'screen_name'} = $member_details->{'screen_name'};
   $tmpl_vars->{'firstname'} = $member_details->{'firstname'};
   $tmpl_vars->{'surname'} = $member_details->{'surname'};
   if($member_details->{'dob'} =~ /^(\d{4})-(\d{2})-(\d{2})$/)
   {
      $tmpl_vars->{'dob_day'} = $3;
      $tmpl_vars->{'dob_month'} = $2;
      $tmpl_vars->{'dob_year'} = $1;
   }
      
   # Clear this out or it appears in the state as plain text
   $self->move_from_cgi_vars_to_tmpl_vars(
      ['password','confirm_password','screen_name',
      'firstname','surname','gender_ID', 'size_across', 'size_down'],
      OVERWRITE_DELETE_ONLY);
}

#-----------------------------------------------------------------------------
# Function: 	event_Update
#-----------------------------------------------------------------------------
# Description:
# 					Updates a user
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Next Action				OUT:0	The module name to run next or undef for none
# Next Actions ArgumentsOUT:1	The arguments to pass to the next modules new
#-----------------------------------------------------------------------------
sub event_Update
{
	my $self 	=	shift;

   $self->debug(8, 'Profile::event_Update');

   my $member_details = $self->member_details();
   my $member_ID     = $member_details->{'ID'};
   my $username      = $member_details->{'username'};
   my $password      = $self->{'cgi_vars'}->{'password'};
   my $confirm_password = $self->{'cgi_vars'}->{'confirm_password'};
   my $screen_name   = $self->{'cgi_vars'}->{'screen_name'};
   my $firstname     = $self->{'cgi_vars'}->{'firstname'};
   my $surname       = $self->{'cgi_vars'}->{'surname'};
   my $gender_ID     = $self->{'cgi_vars'}->{'gender_ID'};
   my $size_across    = $self->{'cgi_vars'}->{'size_across'};
   my $size_down    = $self->{'cgi_vars'}->{'size_down'};

   $self->debug(8, "Profile member " . $username);

   if($password ne $confirm_password)
   {
      $self->{'tmpl_vars'}->{'need_password'} = 1;
      $self->{'tmpl_vars'}->{'error_message'} = 'Passwords do not match'; 
      return;
   }
   
   my $update =
         {  
            'screen_name'  => $screen_name,
            'firstname'    => $firstname,
            'surname'      => $surname,
            'gender_ID'    => $gender_ID
         };
   if($password ne '')
   {
      $update->{'password'} = $password;
   }
   my ($error_code) = $self->update_member($member_ID, $update);
   
   if($error_code)
   {
      $self->event('Update user failed for member ' . $member_ID);
      $self->{'cgi_vars'}->{'error_message'} = 'Update Profile failed';
      return;
   }

   
   # Add the member to member details table
   my $member_detail_ID;
   ($error_code, $member_detail_ID) = $self->update_member_site_details(
         {  'member_ID'    => $member_ID,
            'show_rows'    => $size_down,
            'show_columns' => $size_across
         }
      );
   if($error_code)
   {
      $self->event('User update failed for member ' . $member_ID);
      $self->{'cgi_vars'}->{'error_message'} = 'Update Site Profile failed';
      return;
   }

   if($password ne '')
   {
      $self->send_password_email(
         $member_ID, $username, $firstname, $surname, $password);
   }

   return ('Welcome',{'message' => 'Update complete'});
}

#-----------------------------------------------------------------------------
# Function: 	update_member_site_details
#-----------------------------------------------------------------------------
# Description:
# 					Adds the site specific member details to the database
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# User Details          IN:0  A hash containing the member details to update
#-----------------------------------------------------------------------------
sub update_member_site_details
{
	my $self 	=	shift;
	my $details = $_[0];

   $self->debug(8, 'Profile->update_member_site_details');
   unless(  exists($details->{'member_ID'}) &&
            exists($details->{'show_rows'}) &&
            exists($details->{'show_columns'})
         )
   {
      $self->error(ERROR_SEVERITY_ERROR, ERROR_MISSING_PARAMETER, 
         'Required parameter missing for update member site details');
      return ERROR_MISSING_PARAMETER;
   }

   my $search = {'ID' => $details->{'member_ID'} };
   delete $details->{'member_ID'};
   
   return $self->db_update($self->config('member_details_table'), 
               $details, 
               $search);
}

#-----------------------------------------------------------------------------
# Function: 	send_password_email
#-----------------------------------------------------------------------------
# Description:
# 					sends out an email to the user, with the password
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# NONE
#-----------------------------------------------------------------------------
sub send_password_email
{
	my $self 	      =	shift;
   my $member_ID     = $_[0];
   my $email_address = $_[1];
   my $firstname     = $_[2];
   my $surname       = $_[3];
   my $password      = $_[4];
   
   $self->debug(8, 'Profile::send_password_email');
   # Create the password checksum. We will check this later to ensure the
   # user is unique 

   my $template = $self->config('password_email_template');
   my $name = $firstname . " " . $surname;
   my $sender = $self->config('password_email_from');
   my $subject = $self->config('password_email_subject');
   my $content_type = $self->config('password_email_content_type');
   
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
                        'username'     => $email_address,
                        'password'     => $password,
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
                     
   return;
}

1;
