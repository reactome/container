package GKB::Config;
use strict;

use Cwd 'abs_path';
use GKB::Secrets;

use vars qw(
	@ISA
	@EXPORT
	$GK_DOCKBLASTER_USER
	$GK_DOCKBLASTER_PASS
	$GK_BRENDA_USER
	$GK_BRENDA_PASS
	$GK_COSMIC_USER
	$GK_COSMIC_PASS
    $GK_ORPHAN_USER
    $GK_ORPHAN_PASS
    $GK_SOLR_USER
    $GK_SOLR_PASS
	$GK_DB_NAME
	$GK_IDB_NAME
	$GK_DB_HOST
	$GK_DB_USER
	$GK_DB_PASS
	$GK_DB_PORT
	$GK_ENTITY_DB_NAME
	$REACTOME_ROOT_DIR
    $GK_ROOT_DIR
	$GK_JAVA_CODEBASE
	$GK_FETCH_SCRIPT
	$GK_TMP_IMG_DIR
	$COMPARA_DIR
	$ENSEMBL_API_DIR
	$HTML_PAGE_WIDTH
	$PROJECT_NAME
	$PROJECT_ABBREVIATION
	$PROJECT_LOGO_URL
	$PROJECT_HELP_URL
	$PROJECT_HELP_TITLE
	$PROJECT_FUNDING
	$PROJECT_LOGOS
	$PROJECT_TITLE
	$PROJECT_COPYRIGHT
	$SKY_REPLACEMENT_IMAGE
	$DEFAULT_IMAGE_FORMAT
	$FRONTPAGE_IMG_DIR
	$REACTIONMAP_WIDTH
	$SHOW_REACTIONMAP_IN_EVENTBROWSER
	$DB_BACKUP_DIR
	$NEWS_FILE
    $LAST_RELEASE_DATE
    $CONFIRMED_REACTION_COLOR
    $MANUALLY_INFERRED_REACTION_COLOR
    $ELECTRONICALLY_INFERRED_REACTION_COLOR
    $REACTION_CONNECTOR_COLOR
    $DEFAULT_REACTION_COLOR
	$LINK_TO_SURVEY
	$DEFAULT_VIEW_FORMAT
    $NO_SCHEMA_VALIDITY_CHECK
    $WARNING
	$CACHE_GENERATED_DOCUMENTS
    $JAVA_PATH
    $WWW_USER
	$MART_URL
	$MART_DB_NAME
	$WIKI_URL
	$USER_GUIDE_URL
	$LOG_DIR
	$WORDPRESS_ROOT_URL
	$DATA_MODEL_URL
	$NAVIGATION_BAR_MENUS
	$DISPLAY_VIEW_SWITCH_TOOLBAR
	$USE_REACTOME_GWT
	$REACTOME_VERSION
	$GLOBAL_META_TAGS
	$PATHWAY_OF_THE_MONTH
	$SERVLET_CONTAINER_DEPLOY_DIR
	$LIBSBML_LD_LIBRARY_PATH
	$LOG_CONF
	$HOST_NAME
);

use Exporter();
@ISA=qw(Exporter);

# Database info
##################################################################################
$GK_DB_HOST  = $GKB::Secrets::GK_DB_HOST;
$GK_DB_USER  = $GKB::Secrets::GK_DB_USER;
$GK_DB_PASS  = $GKB::Secrets::GK_DB_PASS;
$GK_DB_NAME  = $GKB::Secrets::GK_DB_NAME;
$GK_IDB_NAME = $GKB::Secrets::GK_IDB_NAME;
$GK_DB_PORT  = $GKB::Secrets::GK_DB_PORT;
$GK_ORPHAN_USER = $GKB::Secrets::GK_ORPHAN_USER;
$GK_ORPHAN_PASS = $GKB::Secrets::GK_ORPHAN_PASS;
$GK_DOCKBLASTER_USER = $GKB::Secrets::GK_DOCKBLASTER_USER;
$GK_DOCKBLASTER_PASS = $GKB::Secrets::GK_DOCKBLASTER_PASS;
$GK_BRENDA_USER = $GKB::Secrets::GK_BRENDA_USER;
$GK_BRENDA_PASS = $GKB::Secrets::GK_BRENDA_PASS;
$GK_COSMIC_USER = $GKB::Secrets::GK_COSMIC_USER;
$GK_COSMIC_PASS = $GKB::Secrets::GK_COSMIC_PASS;
$GK_SOLR_USER   = $GKB::Secrets::GK_SOLR_USER;
$GK_SOLR_PASS   = $GKB::Secrets::GK_SOLR_PASS;

# Name of the OS user running the web server
##################################################################################
# Choose the one appropriate on your system
$WWW_USER = 'nobody';
#$WWW_USER = 'www';

# Various paths
##################################################################################
$REACTOME_ROOT_DIR = '/var/www/html';
$GK_ROOT_DIR = '/usr/local/gkb';
$GK_JAVA_CODEBASE = "/jars";
$GK_TMP_IMG_DIR = "$REACTOME_ROOT_DIR/figures";
#$GK_TMP_IMG_DIR = "/opt/GKB/website/images";
# Place for frontpage images
$FRONTPAGE_IMG_DIR = "$REACTOME_ROOT_DIR/cgi-tmp/img-fp";
$NEWS_FILE = "$GK_ROOT_DIR/website/html/news.html";
$DB_BACKUP_DIR = "$GK_ROOT_DIR/database_backups";
$GK_FETCH_SCRIPT = "/cgi-bin/instance2text.pl";
$COMPARA_DIR = "$GK_ROOT_DIR/scripts/release/orthopairs";
$ENSEMBL_API_DIR = "$GK_ROOT_DIR/modules/ensembl_api";

# Various settings and switches
##################################################################################
$HTML_PAGE_WIDTH = '100%';
$REACTIONMAP_WIDTH = 1000;
$SHOW_REACTIONMAP_IN_EVENTBROWSER = 0;
$PROJECT_NAME = 'Reactome';
$PROJECT_ABBREVIATION = 'Reactome';
$PROJECT_FUNDING = 'a grant from the US National Institutes of Health (P41 HG003751), EU grant LSHG-CT-2005-518254 "ENFIN", Ontario Research Fund, and the EBI Industry Programme';
$PROJECT_LOGOS = [['images/logos/nih.png', 'http://www.nih.gov'], ['images/logos/enfin.png', 'http://www.enfin.org'], ['images/logos/ebi.png', 'http://www.ebi.ac.uk'], ['images/logos/oicr.png', 'http://www.oicr.on.ca'], ['images/logos/nyumc_som.png', 'http://www.med.nyu.edu'], ['images/logos/cshl.png', 'http://www.cshl.edu']];
$PROJECT_TITLE = 'Reactome - a curated pathway database';
$PROJECT_COPYRIGHT = '&#169 2003-2010 Cold Spring Harbor Laboratory (CSHL), Ontario Institute for Cancer Research (OICR) and the European Bioinformatics Institute (EBI).';
$PROJECT_LOGO_URL = '/icons/R-purple.png';
$PROJECT_HELP_URL = 'mailto:help@reactome.org';
$PROJECT_HELP_TITLE = 'Help';
$SKY_REPLACEMENT_IMAGE = undef;
$DEFAULT_IMAGE_FORMAT = 'png';

# format YYYYMMDD
$LAST_RELEASE_DATE = 20180927;

#$DEFAULT_VIEW_FORMAT = 'sidebarwithdynamichierarchy';
$DEFAULT_VIEW_FORMAT = 'elv';

# Reactionmap colours
$CONFIRMED_REACTION_COLOR = [0,102,204];
$MANUALLY_INFERRED_REACTION_COLOR = [254,0,254];
$ELECTRONICALLY_INFERRED_REACTION_COLOR = [51,204,0];
$REACTION_CONNECTOR_COLOR = [220,220,220];
$DEFAULT_REACTION_COLOR = [160,160,160];

$LINK_TO_SURVEY = '';
#$LINK_TO_SURVEY =
#qq(<DIV STYLE="text-align:center;padding-bottom:10px;color:red;">
#We appreciate your feedback and thoughts about Reactome.
#<b><a href="http://www.advancedsurvey.com/default.asp?SurveyID=27617" target="new">
#Please take a moment to take our online survey.
#</b></a></DIV>\n);

$NO_SCHEMA_VALIDITY_CHECK = 1;
$GK_ENTITY_DB_NAME = ${GK_DB_NAME};

$WARNING =
#qq{
#<DIV STYLE="font-size:9pt;font-weight:bold;text-align:center;color:red;padding-top:10px;">
#Due to a planned power outage, the Reactome website will not be accesible on September 22nd 2007 Saturday 7:00 am to 3:00 pm EST</DIV>
#<br><br>Sign up for our new <a href="http://mail.reactome.org/mailman/listinfo/reactome-announce">announcements mailing list!</a>

#qq{
#<DIV STYLE="font-size:9pt;font-weight:bold;text-align:center;color:red;padding-top:10px;">
#We are currently experienceing technical difficulties and you have been redirected to a backup website - some functionality may not be avaialble.
#</DIV>\n };

#qq{
#<DIV STYLE="font-size:9pt;font-weight:bold;text-align:center;color:red;padding-top:10px;">
#This is the Reactome internal repository. It includes data which have not been reviewed and released
#and is possibly incomplete. Our released data are at <A
#HREF="http://www.reactome.org">www.reactome.org</A>.
#</DIV>\n };

"";

# This caches autogenerated PDF and RTF, a reasonable
# thing to do for a live Reactome site visible to the
# public, where the database remains unchanged between
# releases.  For a dev site, it is probably better to
# set this to 0, because the database is in a state of
# flux, and curators will want to see the effects of
# database changes in the documents they generate.
$CACHE_GENERATED_DOCUMENTS = 0;


$MART_URL = 'http://reactomedev.oicr.on.ca:5555/biomart/martview';
$MART_DB_NAME = "test_reactome_mart";
$WIKI_URL = "http://wiki.reactome.org/index.php";
$USER_GUIDE_URL = "$WIKI_URL/Usersguide";
$LOG_DIR = "$GK_ROOT_DIR/logs";

$WORDPRESS_ROOT_URL = 'http://reactome.oicr.on.ca/static_wordpress';
$DATA_MODEL_URL = "http://www.reactome.org/pages/documentation/data-model";

# This is where you can modify the default naviagtion
# bar menus for your site.  If you are happy with
# the defaults, just leave $NAVIGATION_BAR_MENUS
# set to undef, there is no need to change it.
#
# Navigation bar menus can be split into items and subitems;
# items are what you actually see on the top of the page
# without actually needing to do anything.  Subitems are
# the lists of things that appear when you mouse over an
# item.
#
# Items are specified as a hash, with titles as keys.  A
# value of undef will remove the item from the navigation
# bar.  A value can also be a reference to a list of
# subitems.  E.g.:
#
my $wordpress_root = 'http://reactomedev.oicr.on.ca/static_wordpress';
$NAVIGATION_BAR_MENUS =
{
	'About'=>
	{
		'url' => "$wordpress_root/about",
		'subitems_hash' =>
		{
			'About Reactome'=>{'title' => 'About Reactome', 'url' => "$WORDPRESS_ROOT_URL/about"},
			'News'=>{'title' => 'News', 'url' => $WORDPRESS_ROOT_URL},
			'Other Reactomes'=>{'title' => 'Other Reactomes', 'url' => "$WORDPRESS_ROOT_URL/other-reactomes"},
			'Reactome Group'=>{'title' => 'Reactome Group', 'url' => "$WORDPRESS_ROOT_URL/reactome-team"},
			'SAB Members'=>{'title' => 'SAB Members', 'url' => "$WORDPRESS_ROOT_URL/reactome-scientific-advisory-board"},
			'Disclaimer'=>{'title' => 'Disclaimer', 'url' => "$WORDPRESS_ROOT_URL/reactome-disclaimer"},
			'License Agreement'=>{'title' => 'License Agreement', 'url' => "$WORDPRESS_ROOT_URL/license-agreement"},
		}
	},
	'Documentation'=>
	{
		'subitems_hash' =>
		{
			'Data Model'=>{'title' => 'Data Model', 'url' => "$wordpress_root/data-model"},
			'Orthology Prediction'=>{'title' => 'Orthology Prediction', 'url' => "$wordpress_root/electronically-inferred-events"},
			'Object/Relational mapping'=>{'title' => 'Object/Relational mapping', 'url' => "$wordpress_root/objectrelational-mapping"},
			'Linking to Reactome'=>{'title' => 'Linking to Reactome', 'url' => "$wordpress_root/linking-to-reactome"},
		}
	},
	'Tools'=>{'subitems_hash' => {'SkyPainter'=>undef, 'User Interface II (beta)'=>undef, 'FI Cytoscape Plugin'=>{'title' => 'FI Cytoscape Plugin', 'url' => 'http://wiki.reactome.org/index.php/Reactome_FI_Cytoscape_Plugin'}, 'SBML Generator'=>{'title' => 'SBML Generator', 'url' => '/Analysis/entrypoint.html#SBMLRetrievalPage'}}},
	'Contact Us'=>{'url' => "$wordpress_root/contact-us"},
};

# If set to 1, this variable enables the semi-transparent black
# bar that appears at the top of event pages, allowing you to
# select your view, e.g. eventbrowser, etc.  Set this to 0 if
# you do not want to use this feature.
$DISPLAY_VIEW_SWITCH_TOOLBAR = 1;

# The entry point into Reactome can either be via the traditional
# CGI or via the newer GWT route.  Set this variable to 1 if you#
# would like the latter behavior to be the default.
$USE_REACTOME_GWT = 1;

$REACTOME_VERSION = "3.0";

# An array of arrays, which is used in web pages to generate META tags
# which give search engines broad hints about what Reactome is all
# about.  The inner arrays each contain just two terms, corresponding
# to the "name" and "content" parts of a META tag respectively.
$GLOBAL_META_TAGS = [["description", "Reactome is an open-source and manually curated pathway database that provides pathway analysis tools for life science researchers."],
					 ["keywords", "reactome, pathway, pathways, pathway database, pathway analysis, pathways analysis, bioinformatics software, genomics, proteomics, metabolomics, data mining, gene expression"]];

# This changes the sample pathway displayed on the frontpage in the new web interface.
$PATHWAY_OF_THE_MONTH = 1433557;
#$PATHWAY_OF_THE_MONTH = 199991;
#$PATHWAY_OF_THE_MONTH = 168898;

# The directory into which war files are deployed in your servlet container.
# e.g. /usr/local/apache-tomcat/webapps.  This is needed if you are using
# either the ELV or GWT.
$SERVLET_CONTAINER_DEPLOY_DIR = "$GK_ROOT_DIR/../apache-tomcat/webapps";

$LIBSBML_LD_LIBRARY_PATH = "/usr/local/lib";

############################################################
# A simple root logger with a Log::Log4perl::Appender::File
# file appender in Perl.
############################################################
$LOG_CONF = 'log4perl.rootLogger=TRACE, FullLog, ErrorLog

log4perl.appender.FullLog=Log::Log4perl::Appender::File
log4perl.appender.FullLog.filename='.get_name().'.log
log4perl.appender.FullLog.create_at_logtime=1
log4perl.appender.FullLog.mode=append
log4perl.appender.FullLog.layout=PatternLayout
log4perl.appender.FullLog.layout.ConversionPattern=%p %l %d - %m%n
log4perl.appender.FullLog.utf8=1

log4perl.appender.ErrorLog=Log::Log4perl::Appender::File
log4perl.appender.ErrorLog.filename='.get_name().'.err
log4perl.appender.ErrorLog.create_at_logtime=1
log4perl.appender.ErrorLog.mode=append
log4perl.appender.ErrorLog.layout=PatternLayout
log4perl.appender.ErrorLog.layout.ConversionPattern=%p %l %d - %m%n
log4perl.appender.ErrorLog.Threshold = WARN
log4perl.appender.ErrorLog.utf8=1';

$LOG_CONF = 'log4perl.rootLogger = OFF, Screen
log4perl.threshold = OFF

log4perl.appender.Screen = Log::Log4perl::Appender::Screen
log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout' if abs_path($0) =~ /cgi-bin/;

sub get_name {
    my ($name) = $0 =~ /(.*)\./;
    return $name;
}

# When running Reactome in containers, test locally, with HOST_NAME=localhost.
# If you want to deploy on a server, change this to the *publicly* accessible URL!
$HOST_NAME='localhost';

##################################################################################
@EXPORT = qw(
	     $GK_DB_NAME
	     $GK_IDB_NAME
	     $GK_DB_HOST
	     $GK_DB_USER
	     $GK_DB_PASS
	     $GK_DB_PORT
		 	$GK_DOCKBLASTER_USER
	$GK_DOCKBLASTER_PASS
	$GK_BRENDA_USER
	$GK_BRENDA_PASS
	$GK_COSMIC_USER
	$GK_COSMIC_PASS
	$GK_ORPHAN_USER
	$GK_ORPHAN_PASS
	     $GK_ENTITY_DB_NAME
             $GK_ROOT_DIR
	     $GK_JAVA_CODEBASE
	     $GK_FETCH_SCRIPT
	     $GK_TMP_IMG_DIR
	     $COMPARA_DIR
	     $ENSEMBL_API_DIR
	     $HTML_PAGE_WIDTH
	     $PROJECT_NAME
	     $PROJECT_ABBREVIATION
	     $PROJECT_LOGO_URL
	     $PROJECT_HELP_URL
	     $PROJECT_HELP_TITLE
	     $PROJECT_FUNDING
	     $PROJECT_LOGOS
	     $PROJECT_TITLE
	     $PROJECT_COPYRIGHT
	     $SKY_REPLACEMENT_IMAGE
	     $DEFAULT_IMAGE_FORMAT
	     $FRONTPAGE_IMG_DIR
	     $REACTIONMAP_WIDTH
	     $SHOW_REACTIONMAP_IN_EVENTBROWSER
	     $DB_BACKUP_DIR
	     $NEWS_FILE
             $LAST_RELEASE_DATE
             $CONFIRMED_REACTION_COLOR
             $MANUALLY_INFERRED_REACTION_COLOR
             $ELECTRONICALLY_INFERRED_REACTION_COLOR
             $REACTION_CONNECTOR_COLOR
             $DEFAULT_REACTION_COLOR
	     $LINK_TO_SURVEY
	     $DEFAULT_VIEW_FORMAT
	     $NO_SCHEMA_VALIDITY_CHECK
             $WARNING
	     $CACHE_GENERATED_DOCUMENTS
             $JAVA_PATH
             $WWW_USER
	     $MART_URL
	     $MART_DB_NAME
	     $WIKI_URL
	     $USER_GUIDE_URL
	     $LOG_DIR
	     $WORDPRESS_ROOT_URL
	     $DATA_MODEL_URL
	     $NAVIGATION_BAR_MENUS
	     $DISPLAY_VIEW_SWITCH_TOOLBAR
	     $USE_REACTOME_GWT
	     $REACTOME_VERSION
	     $GLOBAL_META_TAGS
	     $PATHWAY_OF_THE_MONTH
	     $SERVLET_CONTAINER_DEPLOY_DIR
	     $LIBSBML_LD_LIBRARY_PATH
	     $LOG_CONF
	     $HOST_NAME
	     );
1;
