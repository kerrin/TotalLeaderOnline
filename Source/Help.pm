#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		Help
#-----------------------------------------------------------------------------
# Description:
# 					This module encompasses access to all the other modules. 
# 					All non-core modules will inherit from this.
# 					This provides debug, error, and event logs, with access to 
# 					creating additional logs
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2004/09/05 11:43:25 $
# $Revision: 1.1 $
#-----------------------------------------------------------------------------
package TotalLeader::Source::Help;
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

sub TEMPLATE() { 'help.html' };

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
# 					Sets up any tmpl vars required
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
#-----------------------------------------------------------------------------
sub setup_tmpl_vars
{
	my $self 	=	shift;

}

1;
