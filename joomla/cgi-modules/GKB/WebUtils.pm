package GKB::WebUtils;
use strict;

use vars qw(@ISA $AUTOLOAD %ok_field %VALID_COMPARISON_OPERATOR @SIMPLE_QUERY_FORM_CLASSES %SIMPLE_QUERY_FORM_FORBIDDEN_ATTRIBUTES $FORMAT_POPULAR_SEARCH_ENGINE_FLAG);
use Bio::Root::Root;
use CGI;
use Carp;
use GKB::NamedInstance;
use GKB::InstanceCache;
use GKB::MatchingInstanceHandler::WebWriteBack;
use GKB::Ontology;
use GKB::Utils;
use File::Spec;
use File::Copy;
use File::Basename;
use GKB::ClipsAdaptor::ToBeUsedWithInstanceExtractor;
use GKB::PrettyInstance;
use GKB::URLMaker;
use GKB::Config;
use GKB::Render::HTML::SectionedView;
use GKB::Render::HTML::SectionedView::EventHierarchyInSideBar;
use GKB::ReactionMap;
use GKB::StableIdentifiers;
use GKB::SearchUtils;
use GKB::NavigationBar::Model;
use GKB::NavigationBar::View;

use Log::Log4perl qw/get_logger/;
Log::Log4perl->init(\$LOG_CONF);

@ISA = qw(Bio::Root::Root);

for my $attr
    (qw(
	dba
	hash_cache
	textBoxWidth
	is_stable_identifier
	cgi
        omit_view_switch_link
        in_html
	) ) { $ok_field{$attr}++; }

%VALID_COMPARISON_OPERATOR =
    (
     'REGEXP' => 'REGEXP',
     'LIKE' => 'LIKE',
     'MATCH' => 'MATCH',
     'IS NULL' => 'IS NULL',
     'IS NOT NULL' => 'IS NOT NULL',
     'IN' => 'IN',
     'MATCH IN BOOLEAN MODE' => 'MATCH IN BOOLEAN MODE',
     'REGEXP BINARY' => 'REGEXP BINARY'
     );

# Used to limit the classes and attributes that get searched with the simple
# query form - speeds things up a bit.
@SIMPLE_QUERY_FORM_CLASSES =
    (
     'CatalystActivity',
     'Event',
     'GO_BiologicalProcess',
     'GO_CellularComponent',
     'GO_MolecularFunction',
     'LiteratureReference',
     'ModifiedResidue',
     'PhysicalEntity',
     'ReferenceEntity',
	 'Regulation',
     'Summation',
     );
%SIMPLE_QUERY_FORM_FORBIDDEN_ATTRIBUTES =
    (
     '__is_ghost' => '__is_ghost',
     '_timestamp' => '_timestamp',
     '_doNotRelease' => '_doNotRelease',
     );
$FORMAT_POPULAR_SEARCH_ENGINE_FLAG = 1;

sub AUTOLOAD {
    my $self = shift;
    my $attr = $AUTOLOAD;
    $attr =~ s/.*:://;
    return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
    $self->throw("invalid attribute method: ->$attr()") unless $ok_field{$attr};
    $self->{$attr} = shift if @_;
    return $self->{$attr};
}

sub new {
    my($pkg, @args) = @_;
    my $self = bless {}, $pkg;
    my ($dba,$debug,$cgi,$urlmaker) = $self->_rearrange
	([qw(
	     DBA
	     DEBUG
	     CGI
	     URLMAKER
	     )], @args);
    $dba || $self->throw("Need dba.");
    $self->dba($dba);
    $self->debug($debug);
    $cgi && $self->cgi($cgi);
    if ($urlmaker) {
		$self->urlmaker($urlmaker);
    } elsif ($cgi) {
		$urlmaker = GKB::URLMaker->new(-SCRIPTNAME => $cgi->script_name,
					       'DB' => $cgi->param('DB'));
		$self->urlmaker($urlmaker);
    } else {
		$self->throw("Need URLMaker or CGI object.");
    }

    return $self;
}

# Takes the CGI as an argument, but does not throw an exception if it
# is undef.  This allows you to use the static methods.  Of course, if
# you try to use a method that needs CGI, you may run into problems, so
# take care.
sub new_nocheck {
    my($pkg, @args) = @_;

    my $self = bless {}, $pkg;

    my ($cgi) = $self->_rearrange
	([qw(
	     CGI
	     )], @args);
    $cgi && $self->cgi($cgi);

    return $self;
}

sub new_from_cgi {
    my($pkg, @args) = @_;
    my $self = bless {}, $pkg;
    my ($debug,$cgi) = $self->_rearrange
	([qw(
	     DEBUG
	     CGI
	     )], @args);
    $cgi ||= CGI->new();
    $self->cgi($cgi);
    my $dba = get_db_connection($cgi);
    $self->dba($dba);
    $self->debug($debug);
    my $urlmaker = GKB::URLMaker->new(-SCRIPTNAME => $cgi->script_name,
				      'DB' => scalar $cgi->param('DB'));
    $self->urlmaker($urlmaker);
    return $self;
}

sub debug {
    my $self = shift;
    if (@_) {
	$self->{'debug'} = shift;
    }
    return $self->{'debug'};
}

# Returns 1 if it is OK to use a G**gle-like view, 0 otherwise.
sub is_popular_search_engine_mode {
    my $self = shift;

    my $DB = $self->cgi->param('DB');

	# TODO: we explicitly exclude gk_central and slices because they can't be
	# searched in the "all terms" mode.  It would be better if
	# we directly tested the database to find out if it works
	# in the "all terms" mode.
    return $FORMAT_POPULAR_SEARCH_ENGINE_FLAG && !($DB =~ /gk_central/ || $DB =~ /_slice_/);
}



sub urlmaker {
    my $self = shift;
    if (@_) {
	$self->{'urlmaker'} = shift;
    }
    return $self->{'urlmaker'};
}

sub force_pwb_link {
    my $self = shift;
    my $link = shift;
    $self->{force_pwb_link} = 1 if $link;
    return $self->{force_pwb_link};
}

sub print_query_form {
    my ($self) = @_;
    my %classes;
#    warn "self = $self, dba = ",$self->dba,"\n";
    @classes{$self->dba->ontology->list_classes} = $self->dba->ontology->list_classes;
    $classes{''} = 'Any';
    my $class = $self->cgi->param('QUERY_CLASS') || $self->dba->ontology->root_class;

    my %attributes;
    my @attributes = grep {! /^_Protege_id$/} $self->dba->ontology->list_class_attributes($class);
    @attributes{@attributes} = @attributes;
    $attributes{$GKB::Ontology::DB_ID_NAME} = "Internal ID";
    $attributes{'_class'} = "class";
    $attributes{'_displayName'} = "display name";
    $attributes{''} = 'Any';

    my($s) = $self->cgi->path_info =~ /(\d+)/; $s++;
    print qq(<DIV CLASS="section">\n);
    print $self->cgi->start_multipart_form(-action => $self->cgi->script_name . "/$s");
    print $self->cgi->hidden(-name => 'DB',-value => $self->cgi->param('DB'));
    print $self->cgi->table({-border => 0, -cellpadding => 2, cellspacing => 0, -width => "$HTML_PAGE_WIDTH", class => 'search'},
			    $self->cgi->Tr({-valign => 'center', -align => 'center'},
			       [
				$self->cgi->td({-class => 'search'},
				   [
				    'Find class',
				    $self->cgi->popup_menu(-NAME => 'QUERY_CLASS',
							   -VALUES => [sort {$a cmp $b} keys %classes],
							   -LABELS => \%classes,
#							   -DEFAULT => $class,
							   -ONCHANGE => 'submit()'
							   ),
				    'instances containing ',
				    $self->cgi->textfield(-name => 'QUERY', -size => 40),
				    ]) . $self->cgi->td({-class => 'search', -rowspan => 2, -valign => 'center'},
					    [
					     $self->cgi->submit(-name => 'SUBMIT', -value => 'Search!')
					     ]),
				$self->cgi->td({-class => 'search'},
				   [
				    'in',
				    $self->cgi->popup_menu(-NAME => 'ATTRIBUTE',
							   -VALUES => [sort {$a cmp $b} keys %attributes],
							   -LABELS => \%attributes,
							   -DEFAULT => $self->cgi->param('ATTRIBUTE')
							   ),
				    'attribute as',
				    $self->_generic_query_form_popup_menu
				    ])
				]
			       )
			    );
    print $self->cgi->end_form;
    print qq(\n</DIV>\n);
}

sub get_simple_query_form_classes {
    my ($self) = @_;

    return @SIMPLE_QUERY_FORM_CLASSES;
}

# Prints a full simple query form, with selectors for result instance
# class and species as well as a text-entry slot and a Go button.
sub print_simple_query_form {
    my ($self) = @_;

    my $DB = $self->cgi->param('DB');

    if ($self->is_popular_search_engine_mode()) {
    	$self->print_simple_query_form_no_popups();
    	return;
    }

    print qq(<DIV CLASS="section">\n<TABLE WIDTH="$HTML_PAGE_WIDTH" CLASS="search" CELLSPACING="0" BORDER="0">);
#    print qq(<DIV>\n<TABLE WIDTH="$HTML_PAGE_WIDTH" CELLSPACING="0" BORDER="0">);
    print $self->cgi->start_form(-action => '/cgi-bin/search2', -method => 'GET');
    print $self->cgi->hidden(-name => 'DB',-value => $DB);
#    print qq(<TR><TD>Find</TD><TD>);
    print qq(<TR><TD CLASS="search">Find</TD><TD CLASS="search">);
#    print qq(<TR><TD CLASS="simplesearch">Find</TD><TD>);
    print $self->cgi->popup_menu
	(
	 -id => 'popup_1',
	 -name => 'CATEGORY',
	 -values => [
	      'everything',
	      'molecule',
	      'complex',
	      'reaction',
	      'pathway',
	      'summation'
	  ],
	 -labels => {
	     'everything' => "everything",
	     'molecule' => 'molecules',
	     'complex' => 'complexes',
	     'reaction' => 'reactions',
	     'pathway' => 'pathways',
	     'summation' => 'summations'
	 },
	 -default => 'everything'
	);
    print qq(</TD><TD CLASS="search">);
#    print qq(</TD><TD>);
    my $operators = _valid_operators_for_db($self->dba);
    @{$operators} = grep {$_ !~ /^(IS|!)/} @{$operators};
    print $self->cgi->popup_menu
	(
	 -id => 'popup_2',
	 -name => 'OPERATOR',
#	 -values => [
#		     'ALL',
#		     'PHRASE',
#		     'REGEXP',
#		     'ANY',
#		     'EXACT'
#		     ],
	 -values => $operators,
	 -labels => {
	     'EXACT' => "with the EXACT PHRASE ONLY",
	     'REGEXP' => 'matching REGULAR EXPRESSION',
	     'ALL' => 'with ALL of the words',
	     'ANY' => 'with ANY of the words',
	     'PHRASE' => 'with the EXACT PHRASE',
	 },
	 -default => 'ALL'
	);
   print qq(</TD><TD CLASS="search">);
#   print qq(</TD><TD>);
    print $self->cgi->textfield(-name => 'QUERY', -size => 25);

    my %sp;
    map {$sp{$_->db_id} = $_->displayName} @{$self->dba->fetch_all_class_instances_as_shells('Species')};
    my $default_sp_id;
    if (my $fs = $self->get_focus_species->[0]) {
	$default_sp_id = $fs->db_id;
    }
#    if (my $hs = $self->dba->fetch_instance_by_attribute('Species',[['name',['Homo sapiens']]])->[0]) {
#	$default_sp_id = $hs->db_id;
#    }
    my @sp_ids = sort {$sp{$a} cmp $sp{$b}} keys %sp;
    unshift @sp_ids, '';
    $sp{''} = 'All species';
    print qq(</TD><TD CLASS="search">in</TD><TD CLASS="search">);
#    print qq(</TD><TD>in</TD><TD>);
    print $self->cgi->popup_menu
	(
	 -id => 'popup_3',
	 -name => 'SPECIES',
	 -values => \@sp_ids,
	 -labels => \%sp,
	 -default => $default_sp_id
	);
    print qq(</TD><TD CLASS="search">);
#    print qq(</TD><TD>);
    print $self->cgi->submit(-name => 'SUBMIT', -value => 'Go!');
    print qq(</TD></TR>);
    print $self->cgi->end_form;
    print qq(</TABLE>\n</DIV>\n);
}

# Prints a cut-down query form, with just a selector for species, a
# text-entry slot and a Go button.
sub print_simple_query_form_no_popups {
    my ($self) = @_;

	my $html = '';

	# Use Javascript to detect browser type and decide
	# on that basis which search bar to present -
	# IE can't render mouseover in menus properly, so in this
	# case, use full species names.
	my $compact_query_form = $self->get_simple_query_form_no_popups(500, 25);
	my $full_query_form = $self->get_simple_query_form_no_popups(600);
	$compact_query_form =~ s/"/\\"/g;
	$compact_query_form =~ s/\n/ /g;
	$full_query_form =~ s/"/\\"/g;
	$full_query_form =~ s/\n/ /g;
    $html .= qq(<script language="JavaScript" type="text/javascript">\n);
    $html .= qq(var browser=navigator.appName;\n);
    $html .= qq(var nua=navigator.userAgent;\n);
    $html .= qq(var ie=(browser=="Microsoft Internet Explorer") || ((nua.indexOf('MSIE')!=-1)&&!op);\n);
    $html .= qq(if (ie) {\n);
    $html .= qq(document.write("$full_query_form")\n);
    $html .= qq(} else {\n);
    $html .= qq(document.write("$compact_query_form")\n);
    $html .= qq(}\n);
    $html .= qq(</script>\n);

	print $html;
}

# Creates a cut-down query form, with just a selector for species, a
# text-entry slot and a Go button.
sub get_simple_query_form_no_popups {
    my ($self, $total_width, $select_menu_width) = @_;

	# Use frontpage species, to maintain consistency with the species
	# selector on the Reactome home page.
    my %sp;
#    map {$sp{$_->db_id} = $_->displayName} @{$self->dba->fetch_all_class_instances_as_shells('Species')};
    map {$sp{$_->db_id} = $_->displayName} @{$self->dba->fetch_frontpage_species()};
    my $default_sp_id;
    my $previous_species = $self->cgi->param('SPECIES');
    if (defined $previous_species) {
		$default_sp_id = $previous_species;
    } elsif (my $fs = $self->get_focus_species->[0]) {
		$default_sp_id = $fs->db_id;
    }

    my @sp_ids = sort {$sp{$a} cmp $sp{$b}} keys %sp;
    if (scalar(@sp_ids)>1) {
    	# If there is a choice of more than one species, give
    	# the user the possibility to include all species in
    	# the search.
	    unshift @sp_ids, '';
	    $sp{''} = 'All species';
	}
    my $DB = $self->cgi->param('DB');

    my $html = '';
    $html .= qq(<DIV CLASS="search_no_popups">\n);
    $html .= qq(<TABLE ALIGN="center" WIDTH="$total_width" CLASS="search" CELLSPACING="0" BORDER="0">\n);
    $html .= qq(<FORM method="get" action="/cgi-bin/search2" enctype="application/x-www-form-urlencoded">\n);
    $html .= $self->cgi->hidden(-name => 'DB',-value => $DB) . "\n";
    $html .= $self->cgi->hidden(-name => 'OPERATOR',-value => 'ALL');
#    $html .= $self->cgi->hidden(-name => 'OPERATOR',-value => 'REGEXP');
    $html .= qq(\t<TR>\n);
    $html .= qq(\t\t<TD CLASS="search">Search for:</TD>\n);
    $html .= qq(\t\t<TD CLASS="search">) . $self->cgi->textfield(-name => 'QUERY', -size => '20') . qq(</TD>\n);
    $html .= qq(\t\t<TD CLASS="search">in</TD>\n);
    $html .= qq(\t\t<TD CLASS="search">);
	$html .= $self->get_select_menu('popup_3', 'SPECIES', $default_sp_id, \@sp_ids, \%sp, $select_menu_width);
    $html .= qq(</TD>\n);
    $html .= qq(\t\t<TD CLASS="search">) . $self->cgi->submit(-name => 'SUBMIT', -value => 'Go!') . qq(</TD>\n);
    $html .= qq(\t</TR>\n);
    $html .= qq(</FORM>\n);
    $html .= qq(</TABLE>\n);
    $html .= qq(</DIV>\n); # search_no_popups

    return $html;
}

# Gets HTML for a SELECT menu within a form.  Some arguments are optional
# and can be replaced with undef.
#
# id		(optional) provides ID for CSS
# name		Name of menu, will be passed to form
# default	(optional) default menu item key
# keys		A reference to an array of keys for menu items
# values	A reference to a hash of key/value pairs for menu items
# width		(optional) limit width in characters
sub get_select_menu {
    my ($self, $id, $name, $default, $keys, $values, $width) = @_;

    my $id_statement = '';
    if (defined $id && !($id eq '')) {
    	$id_statement = qq(id="$id");
    }
    my $html .= qq(<select name="$name" $id_statement>\n);
    my $key;
    my $value;
    my $selected_statement;
    my $value_statement;
    my $onmouse_statement;
    my $item_string;
    foreach $key (@{$keys}) {
    	$value = $values->{$key};
    	$selected_statement = '';
    	if (defined $default && $key eq $default) {
    		$selected_statement = qq(selected="selected");
    	}
    	$value_statement = "value=\"$key\"";
    	$item_string = $value;
    	$onmouse_statement = '';
    	if (defined $width && length($value)>$width) {
    		$item_string = substr($value, 0, $width - 3) . "...";
    		$onmouse_statement = qq(onMouseover="ddrivetip('$value','#DCDCDC', 250)" onMouseout="hideddrivetip()");
    	}
    	$html .= qq(<option $selected_statement $value_statement $onmouse_statement>$item_string</option>\n);
    }
    $html .= qq(</select>\n);

    return $html;
}

sub handle_simple_query_form{
    my ($self, $no_decoration) = @_;

    my $cgi = $self->cgi;
    my $cat =  lc($cgi->param('CATEGORY'));
    my $ar = $self->fetch_simple_query_form_instances;

    if (@{$ar} == 1 && !$self->is_popular_search_engine_mode()) {
    	# If only one result is returned, go straight to the web
    	# page for that result - this reduces the number of clicks
    	# for the user.
    	#
    	# This luxury isn't available for users of the G**gle
    	# emulation though.
    	if ($self->is_stable_identifier && $ar->[0]->is_valid_attribute('stableIdentifier') && $ar->[0]->stableIdentifier->[0]) {
    		# Treat anything that has been found as a
    		# result of a search with a string of the form
    		# REACTOME_XXX.YYY as a special case, and use
    		# eventbrowser_st_id to display it.  We do this
    		# because the instance may be out-of-date or
    		# even deleted, and the user needs to be warned
    		# about it.
			my $stable_identifier = $ar->[0]->stableIdentifier->[0];
			my $identifier = $stable_identifier->identifier->[0];
			my $version = $stable_identifier->identifierVersion->[0];
			print $cgi->redirect("/cgi-bin/eventbrowser_st_id?ST_ID=$identifier.$version");
    	} else {
			$ar->[0] = replace_StableIdentifier_instance_with_referrer($ar->[0]);
			print $cgi->redirect('/cgi-bin/eventbrowser?DB=' . $cgi->param('DB') . '&ID=' . $ar->[0]->db_id);
    	}
		exit;
    }
    if (!(defined $no_decoration)) {
        $self->print_simple_search_page_top;
    }
    if (! $cat) {
    } elsif ($cat ne 'everything') {
		$cgi->param('FORMAT','list');
    }
    $self->print_view($ar,1);
    if (!(defined $no_decoration)) {
        $self->print_simple_search_page_bottom;
    }
}

sub fetch_simple_query_form_instances {
    my ($self) = @_;
    my $cgi = $self->cgi;
    my $qstr = $cgi->param('QUERY');
    my $cat =  lc($cgi->param('CATEGORY'));
    my $operator = $cgi->param('OPERATOR');
    # Special case: if the query string is enclosed in quotes, assume
    # the user wants to do an exact match.
    if ($qstr =~  /^"([^"]+)"$/) {
    	$qstr = $1;
    	$operator = 'PHRASE';
    }

    $cgi->param(-name=>'SEARCH_UTILS_OPERATOR', -value=>$operator);
    ($operator,$qstr) = $self->_ui_qstr_and_operator_2_mysql($operator,$qstr);

    my $sp_id = $cgi->param('SPECIES');
    if ($self->is_popular_search_engine_mode()) {
    	# For the G**gle-like search, search over all species
    	# and filter unwanted stuff out later
    	$sp_id = undef;
    }
    my %h;
    my $ar = [];

    # Unset stable ID flag, so that instances that were *not*
    # found by a search for REACT_XXX.YYY will get
    # displayed with eventbrowser, rather than with
    # eventbrowser_st_id
    $self->is_stable_identifier(undef);
    if ($qstr =~ /REACT_[0-9]+|R-[A-Z]{3}-\d+/) {
    	# Very special case: if we detect a query containing a
    	# stable ID (REACT_XXX), look in all releases, if necessary.
		$ar = $self->fetch_instance_by_stable_identifier($qstr, $operator);
    } elsif (! $cat || ($cat eq 'everything')) {
    	my $su = GKB::SearchUtils->new();
    	if (!$self->is_popular_search_engine_mode() || !($su->is_search_already_performed($cgi->param("DB"), $sp_id, $cgi->param('QUERY'), $operator))) {
			$ar = $self->dba->fetch_instance_by_string_type_attribute_and_species_db_id_by_class($qstr,$operator,$sp_id,\@SIMPLE_QUERY_FORM_CLASSES, \%SIMPLE_QUERY_FORM_FORBIDDEN_ATTRIBUTES);
    	}
    } elsif ($cat eq 'molecule') {
		map {$h{$_->db_id} = $_}
		@{$self->dba->fetch_class_instance_by_string_type_attribute
		      ('ReferenceMolecule',$qstr,$operator)};

		map {$h{$_->db_id} = $_}
		@{$self->dba->fetch_class_instance_by_string_type_attribute_and_species_db_id
		      ('ReferenceSequence',$qstr,$operator,$sp_id)};


		my $ar2 = $self->dba->fetch_class_instance_by_string_type_attribute_and_species_db_id
		    ('SimpleEntity',$qstr,$operator,$sp_id);
		my @tmp = map {$_->db_id} @{$ar2};
		map {$h{$_->db_id} = $_}
		@{$self->dba->fetch_instance_by_attribute
		      ('ReferenceMolecule',[['referenceEntity',\@tmp,'=','SimpleEntity']])};
		map {$h{$_->db_id} = $_}
		@{$self->dba->fetch_instance_by_attribute
		      ('ReferenceSequence',[['referenceEntity',\@tmp,'=','EntityWithAccessionedSequence']])};
		map {$h{$_->db_id} = $_} grep {! $_->ReferenceEntity->[0]} @{$ar2};

		$ar = [values %h];
    } elsif ($cat eq 'complex') {
		map {$h{$_->db_id} = $_}
		@{$self->dba->fetch_class_instance_by_string_type_attribute_and_species_db_id
		      ('Complex',$qstr,$operator,$sp_id)};

		$ar = [values %h];
    } elsif ($cat eq 'reaction') {
		map {$h{$_->db_id} = $_}
		@{$self->dba->fetch_class_instance_by_string_type_attribute_and_species_db_id
		      ('Reaction',$qstr,$operator,$sp_id)};

		my $ar2 = $self->dba->fetch_class_instance_by_string_type_attribute
		    ('GO_BiologicalProcess',$qstr,$operator);
		my @tmp = map {$_->db_id} @{$ar2};
	        my @q = (['goBiologicalProcess',\@tmp,'=']);
		push @q, ['species',[$sp_id],'='] if ($sp_id);
		map {$h{$_->db_id} = $_}
		@{$self->dba->fetch_instance_by_attribute('Reaction', \@q)};
		$ar2 = $self->dba->fetch_class_instance_by_string_type_attribute
		    ('GO_MolecularFunction',$qstr,$operator);
		@tmp = map {$_->db_id} @{$ar2};
	        @q = (['catalystActivity.activity','=',\@tmp]);
	        push @q, ['species','=',[$sp_id]] if ($sp_id);
		map {$h{$_->db_id} = $_}
		@{$self->dba->fetch_instance_by_remote_attribute('Event',\@q)};
		$ar = [values %h];
    } elsif ($cat eq 'pathway') {
		map {$h{$_->db_id} = $_}
		@{$self->dba->fetch_class_instance_by_string_type_attribute_and_species_db_id
		      ('Pathway',$qstr,$operator,$sp_id)};

		my $ar2 = $self->dba->fetch_class_instance_by_string_type_attribute
		    ('GO_BiologicalProcess',$qstr,$operator);
		my @tmp = map {$_->db_id} @{$ar2};
		my @q = (['goBiologicalProcess',\@tmp,'=']);
		push @q, ['species',[$sp_id],'='] if ($sp_id);
		map {$h{$_->db_id} = $_}
		@{$self->dba->fetch_instance_by_attribute('Pathway',\@q)};
		$ar = [values %h];
    } elsif ($cat eq 'summation') {
		map {$h{$_->db_id} = $_}
		@{$self->dba->fetch_class_instance_by_string_type_attribute
		      ('Summation',$qstr,$operator)};

		$ar = [values %h];
    }

    # If a species has been specified, filter the results by species
    # (insofar as it is possible).
    my @a;
    if ($sp_id) {
		foreach my $i (@{$ar}) {
		    if ($i->is_valid_attribute('species')) {
				if (! $i->Species->[0]) {
				    push @a, $i;
				} elsif ($i->Species->[0]->db_id == $sp_id) {
				    push @a, $i;
				}
		    } else {
				push @a, $i;
		    }
		}
		$ar = \@a;
    }

    return $ar;
}

# Uses stable ID information to retrieve an instance from
# the current release or another one, if not available.
sub fetch_instance_by_stable_identifier {
	my ($self, $qstr ,$operator) = @_;

	# Gives access to a whole bunch of methods for dealing with
	# previous releases and stable identifiers.
	my $si = GKB::StableIdentifiers->new($self->cgi);

	my ($identifier, $identifier_version) = $si->extract_identifier_and_version_from_string($qstr);

	# Run a search in the current release first.
	my $ar = undef;
	if (defined $identifier_version) {
		$ar = $self->dba->fetch_instance_by_remote_attribute('DatabaseObject', [['stableIdentifier.identifier','=',[$identifier]]], ['stableIdentifier.identifierVersion','=',[$identifier_version]]);
	} else {
		$ar = $self->dba->fetch_instance_by_remote_attribute('DatabaseObject', [['stableIdentifier.identifier','=',[$identifier]]]);
	}

	# If the search in the current release found something,
	# return it without further messing around.
	if ($ar && scalar(@{$ar})>0) {
		$si->close_all_dbas();
		return $ar;
	}

	# Tsk, things are more complicated, the stable ID
	# could not be found in the current release, check
	# to see if it can be found in previous releases.
	my @empty_array = ();

	# Get StableIdentifier instance
	my $stable_identifier = $si->get_stable_identifier($identifier);

	if (!$stable_identifier) {
		$si->close_all_dbas();
		return \@empty_array;
	}

	# If no explicit version has been specified, fetch
	# the highest.
	if (!(defined $identifier_version)) {
		$identifier_version = $si->get_max_version_num_from_stable_identifier($stable_identifier);
	}

	# If no version could be found, give up and return an
	# empty array.
	if (!(defined $identifier_version) || $identifier_version == (-1)) {
		$si->close_all_dbas();
		return \@empty_array;
	}

	my $release_dba = $si->get_release_dba($stable_identifier, $identifier_version);

	if (!$release_dba) {
		$si->close_all_dbas();
		return \@empty_array;
	}

	my $instances = $release_dba->fetch_instance_by_remote_attribute(
		'DatabaseObject',
		[['stableIdentifier.identifier','=',[$identifier]]]);

	# This should never happen!
	if (!$instances) {
		$si->close_all_dbas();
		return \@empty_array;
	}

	# TODO: Isn't there a cleaner way to do this?
	# Since the instance(s) that have been found come from
	# a different release from the original database, and
	# since code above this subroutine uses DB_ID, rather
	# than instance, to generate web pages, change the
	# DB at the CGI level, so that the correct instance gets
	# displayed.  This is a potentially vey unexpected
	# sideffect of this subroutine.
	my $db_name = $release_dba->db_name;
	$self->cgi->param(-name=>'DB',-value=>$db_name);

	# Set a flag to say that the instance(s) were generated
	# from stable IDs.  It forces the program to use
	# eventbrowser_st_id to display the instance, rather
	# than the default eventbrowser.
	# This is a somewhat ugly hack.
	$self->is_stable_identifier('true');

	$si->close_all_dbas();

	return $instances;
}

sub print_simple_search_page_top {
    my $self = shift;
    my $cgi = $self->cgi;
    print $cgi->header(-charset => 'UTF-8');
    print $cgi->start_html(
	# \-dtd => "-//IETF//DTD HTML//EN",
	-style => {-src => '/stylesheet.css'},
	-title => "$PROJECT_NAME (search)",
	);
    $self->in_html(1);
    print $self->navigation_bar;
    $self->print_simple_query_form;
}

sub print_simple_search_page_bottom {
    my $self = shift;
    print $self->make_footer;
    print $self->cgi->end_html;
    $self->in_html(undef);
}

sub _ui_qstr_and_operator_2_mysql {
    my ($self,$operator,@query) = @_;
    $operator = uc($operator);
    if ($operator eq 'EXACT') {
	$operator = '=';
    } elsif ($operator eq 'REGEXP') {

    } elsif ($operator eq 'ALL') {
	$operator = 'MATCH IN BOOLEAN MODE';
	foreach (@query) {
	    if (defined $_) {
		s/ (\w+)/ \+$1/g;
		s/^(\w+)/\+$1/g;
	    }
	}
#	$query =~ s/ (\w+)/ \+$1/g;
#	$query =~ s/^(\w+)/\+$1/g;
    } elsif ($operator eq 'ANY') {
	$operator = 'MATCH IN BOOLEAN MODE';
    } elsif ($operator eq 'PHRASE') {
	$operator = 'MATCH IN BOOLEAN MODE';
	foreach (@query) {
	    if (defined $_) {
		unless (/^\"/) {
		    $_ = '"' . $_;
		}
		unless ((/\"$/) && (! /\\\"$/)) {
		    $_ .= '"';
		}
	    }
	}
#	unless ($query =~ /^\"/) {
#	    $query = '"' . $query;
#	}
#	unless (($query =~ /\"$/) && ($query !~ /\\\"$/)) {
#	    $query .= '"';
#	}
    } elsif ($operator eq 'IS NULL') {

    } elsif ($operator eq 'IS NOT NULL') {

    } elsif ($operator eq '!=') {

    } else {
	$self->throw("Don't know what to do with operator '$operator'.");
    }
    return ($operator,@query);
}

sub simple_query_box {
    my ($self) = @_;
#    return '&nbsp;';
    return
	qq(<form method="get" action="/cgi-bin/eventbrowser" enctype="application/x-www-form-urlencoded">) .
	qq(<input type="hidden" name="DB" value=\") . $self->cgi->param('DB') . qq(\" />) .
	qq(<input type="hidden" name="OPERATOR" value="ALL" />) .
	qq(<input type="text" name="QUERY" size="20" />) .
	qq(</form>)
	;
}

sub is_decorated {
    my ($self) = @_;
    my $undecorated = $self->cgi->param('UNDECORATED');
    if (defined $undecorated && $undecorated == 1) {
        return 0;
    }
    return 1;
}

sub print_big_query_form {
    my ($self) = @_;
    my($s) = $self->cgi->path_info =~ /(\d+)/; $s++;

    print $self->cgi->start_multipart_form(-action => $self->cgi->script_name . "/$s", -method => 'POST');
    print $self->cgi->hidden(-name => 'DB',-value => $self->cgi->param('DB'));
    if (!$self->is_decorated()) {
        print $self->cgi->hidden(-name => 'UNDECORATED',-value => '1');
    }
    print qq(<DIV CLASS="section">\n<TABLE cellspacing="0" WIDTH="$HTML_PAGE_WIDTH" CLASS="search2"><TR><TD COLSPAN="4" STYLE="background:white;"><P>This form allows searching for records (instances) in the database by multiple field (attribute) values. Queries are combined together with <STRONG>AND</STRONG>. For example, selecting class <I>Reaction</I>, then selecting field name <I>input</I> and entering <TT>ADP</TT> into the query box, then selecting field name <I>output</I> on the next row and entering <TT>ATP</TT> would retrieve all reactions which consume ADP and produce ATP.</P></TD></TR>\n);

    my %classes;
    @classes{$self->dba->ontology->list_classes} = $self->dba->ontology->list_classes;
    my $class = $self->cgi->param('QUERY_CLASS');
    $class ||= $self->dba->ontology->root_class;

    print qq(<TR><TD>);
    print "Restrict search to a class";
    print qq(</TD><TD COLSPAN="2">);
    print $self->cgi->popup_menu(-NAME => 'QUERY_CLASS',
			   -VALUES => [sort {$a cmp $b} keys %classes],
			   -LABELS => \%classes,
			   -DEFAULT => $class,
			   -ONCHANGE => 'submit()'
			   );
    print qq(</TD></TR>);

    print qq(<TR><TH ALIGN="center" CLASS="search2center" COLSPAN="3">);
    print $self->cgi->submit(-name => 'SUBMIT', -value => 'Search');
    print qq(</TH></TR>);

    print qq(<TR><TD>Field name</TD><TD>&nbsp;</TD><TD>&nbsp;</TD></TR>\n);

    my %attributes;
    my @attributes = $self->dba->ontology->list_class_attributes($class);
#    @attributes = grep {! /_(id|class|displayName)$/} @attributes;
    @attributes{@attributes} = @attributes;
    $attributes{$DB_ID_NAME} = "Internal ID";
    $attributes{""} = "";

#    $self->cgi->delete_all;

    my $c = 0;
#    foreach (keys %attributes) {
    my $operators = _valid_operators_for_db($self->dba);
    foreach (1 .. 4) {
	print
	    qq(<TR><TD>),
	    $self->cgi->popup_menu(-NAME => "ATTRIBUTE#$c",
				   -VALUES => [sort {$a cmp $b} keys %attributes],
				   -LABELS => \%attributes,
				   -DEFAULT => ""
				   ),
	    qq(</TD><TD>),
	    $self->cgi->popup_menu(-name => "OPERATOR#$c",
				   -values => $operators,
#				   -values => [
#					       'ALL',
#					       'PHRASE',
#					       'REGEXP',
#					       'ANY',
#					       'EXACT',
#					       '!=',
#					       'IS NULL',
#					       'IS NOT NULL'
#					       ],
				   -labels => {
				       'EXACT' => "with the EXACT PHRASE ONLY",
				       'REGEXP' => 'matching REGULAR EXPRESSION',
				       'ALL' => 'with ALL of the words',
				       'ANY' => 'with ANY of the words',
				       'PHRASE' => 'with the EXACT PHRASE',
				       '!=' => '!=',
				       'IS NULL' => 'with no value',
				       'IS NOT NULL' => 'with any value',
				   },
				   -default => 'EXACT'
				   ),
	    qq(</TD><TD>),
	    $self->cgi->textarea(-name => "VALUE#$c",
				 -rows => 2,
				 -columns => 50,
		                 -default => ""),
	    qq(</TD></TR>\n);
	$c++;
    }

    print qq(<TR><TH ALIGN="center" CLASS="search2center" COLSPAN="3">);
    print $self->cgi->submit(-name => 'SUBMIT', -value => 'Search');
    print qq(</TH></TR>);

    print qq(</TABLE>\n</DIV>\n);
#    print qq(<HR>\n);
    print $self->cgi->end_form;
}

sub print_remote_attribute_query_form {
    my ($self) = @_;
    my($s) = $self->cgi->path_info =~ /(\d+)/; $s++;
    print $self->cgi->start_form(-action => $self->cgi->script_name . "/$s", -method => 'GET');
    print $self->cgi->hidden(-name => 'DB',-value => $self->cgi->param('DB'));

    print qq(<DIV CLASS="section padding0 top30">\n<TABLE cellspacing="0" style="background-color:rgb(88, 195, 229);padding: 10px;border-collapse: inherit;"  WIDTH="$HTML_PAGE_WIDTH">);
    my %classes;
    @classes{$self->dba->ontology->list_classes} = $self->dba->ontology->list_classes;
    my $class = $self->cgi->param('QUERY_CLASS');
    $class ||= $self->dba->ontology->root_class;

    print qq(<TR><TD>);
    print "Restrict search to a class";
    print qq(</TD><TD COLSPAN="2">);
    print $self->cgi->popup_menu(-NAME => 'QUERY_CLASS',
			   -VALUES => [sort {$a cmp $b} keys %classes],
			   -LABELS => \%classes,
			   -DEFAULT => $class
#			   -ONCHANGE => 'submit()'
			   );
    print qq(</TD></TR>);

    print qq(<TR><TH ALIGN="center" CLASS="search2center" COLSPAN="3">);
    print $self->cgi->submit(-name => 'SUBMIT', -value => 'Search');
    print qq(</TH></TR>);

    print qq(<TR><TD>Field name</TD><TD>&nbsp;</TD><TD>&nbsp;</TD></TR>\n);

    my %attributes;
    my @attributes = $self->dba->ontology->list_class_attributes($class);
#    @attributes = grep {! /_(id|class|displayName)$/} @attributes;
    @attributes{@attributes} = @attributes;
    $attributes{$DB_ID_NAME} = "Internal ID";
    $attributes{""} = "";

#    $self->cgi->delete_all;

    my $c = 0;
#    foreach (keys %attributes) {
    my $operators = _valid_operators_for_db($self->dba);
    foreach (1 .. 6) {
	print
	    qq(<TR><TD>),
	    $self->cgi->textfield(-name => "ATTRIBUTE#$c", -size => 40),
	    qq(</TD><TD>),
	    $self->cgi->popup_menu(-name => "OPERATOR#$c",
				   -values => $operators,
#				   -values => [
#					       'ALL',
#					       'PHRASE',
#					       'REGEXP',
#					       'ANY',
#					       'EXACT',
#					       '!=',
#					       'IS NULL',
#					       'IS NOT NULL'
#					       ],
				   -labels => {
				       'EXACT' => "with the EXACT PHRASE ONLY",
				       'REGEXP' => 'matching REGULAR EXPRESSION',
				       'ALL' => 'with ALL of the words',
				       'ANY' => 'with ANY of the words',
				       'PHRASE' => 'with the EXACT PHRASE',
				       '!=' => '!=',
				       'IS NULL' => 'with no value',
				       'IS NOT NULL' => 'with any value',
				   },
				   -default => 'EXACT'
				   ),
	    qq(</TD><TD>),
	    $self->cgi->textarea(-name => "VALUE#$c",
				 -rows => 2,
				 -columns => 50,
		                 -default => ""),
	    qq(</TD></TR>\n);
	$c++;
    }
    print
	qq(<TR><TD COLSPAN="2">Output</TD><TD>),
	$self->cgi->textarea(-name => 'OUTPUTINSTRUCTIONS',
			     -rows => 3,
			     -columns => 50,
			     -default => ""),
	qq(</TD></TR>\n);
    print qq(<TR><TH ALIGN="center" CLASS="search2center" COLSPAN="3">);
    print $self->cgi->submit(-name => 'SUBMIT', -value => 'Search');
    print qq(</TH></TR>);

    print qq(</TABLE>\n</DIV>);
#    print qq(<HR>\n);
    print $self->cgi->end_form;
}

sub handle_big_query_form {
    my ($self) = @_;
    my @query;
    foreach my $a (grep {$self->cgi->param($_)} grep {/^ATTRIBUTE\#\d+$/} $self->cgi->param){
	my ($c) = $a =~ /^ATTRIBUTE\#(\d+)$/;
	my @vals = split(/\r\n|\n\r|\r|\n/,$self->cgi->param("VALUE#$c"));
	@vals = (undef) unless (@vals);
	my $operator = $self->cgi->param("OPERATOR#$c");
	($operator,@vals) = $self->_ui_qstr_and_operator_2_mysql($operator,@vals);
	push @query, [$self->cgi->param($a),
		      \@vals,
		      $operator];
    }
    @query || return [];
    my $class = $self->cgi->param('QUERY_CLASS');
    $self->dba->replace_strings_with_db_ids_where_appropriate($class,\@query);
#    print qq(<PRE>\n), $self->dba->debug(1);
    my $ar = $self->dba->fetch_instance_by_attribute($class,\@query);
#    print qq(</PRE>\n), $self->dba->debug(undef);
    return $ar;
}

sub handle_remote_attribute_query_form {
    my ($self) = @_;
    my @query;
    foreach my $a (grep {$self->cgi->param($_)} grep {/^ATTRIBUTE\#\d+$/} $self->cgi->param){
	my ($c) = $a =~ /^ATTRIBUTE\#(\d+)$/;
	my @vals = split(/\r\n|\n\r|\r|\n/,$self->cgi->param("VALUE#$c"));
	@vals = (undef) unless (@vals);
	my $operator = $self->cgi->param("OPERATOR#$c");
	($operator,@vals) = $self->_ui_qstr_and_operator_2_mysql($operator,@vals);
	push @query, [$self->cgi->param($a),
		      $operator,
		      \@vals];
    }
    @query || return [];
    my $class = $self->cgi->param('QUERY_CLASS');
#    print qq(<PRE>\n), $self->dba->debug(1);
    my $ar = $self->dba->fetch_instance_by_remote_attribute($class,\@query);
#    print qq(</PRE>\n), $self->dba->debug(undef);
    return $ar;
}

# routine to handle the map being clicked.
sub handle_mouse_click {
    my ($self) = @_;
    my $cgi = $self->cgi;
    if ($cgi->param('MOVE_L') || $cgi->param('MOVE_L.x') ||
	$cgi->param('MOVE_R') || $cgi->param('MOVE_R.x') ||
	$cgi->param('MOVE_U') || $cgi->param('MOVE_U.x') ||
	$cgi->param('MOVE_D') || $cgi->param('MOVE_D.x') ||
	($cgi->param('ZOOM') and $cgi->param('ZOOM') != 1)) {
	#retain previous focus
#	print qq(<PRE>handle_mouse_click</PRE>\n);
	return  $self->dba->fetch_instance_by_db_id($cgi->param('FOCUS'));
    } elsif (my $db_id = $cgi->param('ID')) {
	#shift focus
	return  $self->dba->fetch_instance_by_db_id($db_id);
    } else {
	#find closest by coordinate
        # parameters of x and y co-ords passed to vars
	my $x_mapclick = $self->cgi->param('REACTIONMAP.x');
	my $y_mapclick = $self->cgi->param('REACTIONMAP.y');
        # parameters of x and y magnification passed to vars
	my $x_mag = $self->cgi->param('X_MAG') || 1;
	my $y_mag = $self->cgi->param('Y_MAG') || 1;
        # conversion of map to our window size
	my $x_offset = $self->cgi->param('X_OFFSET') || 0;
	my $y_offset = $self->cgi->param('Y_OFFSET') || 0;
	my $x_real = int($x_offset + $x_mapclick / $x_mag);
	my $y_real = int($y_offset + $y_mapclick / $y_mag);
	return $self->dba->fetch_Reaction_by_location_xy($x_real,$y_real);
    }
}

sub look_for_deleted {
    my $self = shift;
    my $ar = shift;
    my @ids = $self->cgi->param('ID');
    my $deleted = $self->dba->fetch_instance( -CLASS => '_Deleted',
				    -QUERY => [['deletedInstanceDB_ID',\@ids]]);
    if ($deleted) {
	push @$ar, @$deleted;
    }
}

sub handle_query_form {
    my ($self) = @_;
    $self->debug && print qq(<PRE>), (caller(0))[3], qq(</PRE>\n);
    my $ar = [];
    if (my @ids = $self->cgi->param('ID')) {
#	print_cgi_params($self->cgi);
	$self->dba->fetch_instance_by_attribute($self->dba->ontology->root_class,
						[[$DB_ID_NAME,\@ids]]);
	foreach (@ids) {
	    if (my $i = $self->dba->instance_cache->fetch($_)) {
		push @{$ar}, $i;
	    }
	}

	if (@$ar == 0) {
	    $self->look_for_deleted($ar);
	}

	return $ar;
    }
    my @query = $self->cgi->param('QUERY');
    my $attribute = $self->cgi->param('ATTRIBUTE');
    my $class = $self->cgi->param('QUERY_CLASS');
    my $operator = $self->_query_operator;
#    print qq(<PRE>\n);$self->dba->debug(1);
    if ($attribute eq $DB_ID_NAME) {
	$self->dba->fetch_instance_by_attribute($class || $self->dba->ontology->root_class,
						[[$DB_ID_NAME,\@query]]);
	foreach (@query) {
	    if (my $i = $self->dba->instance_cache->fetch($_)) {
		push @{$ar}, $i;
	    }
	}
    } elsif ($operator =~ /^IS.+NULL$/) {
	if ($attribute && $class) {
	    $ar = $self->dba->fetch_instance_by_attribute($class,[[$attribute, \@query, $operator]]);
	}
    } else {
	if ($attribute && $class) {
	    if ($self->dba->ontology->is_primitive_class_attribute($class,$attribute) ||
		(($operator eq '=') && ($query[0] =~ /^\d+$/))) {
		$ar = $self->dba->fetch_instance_by_attribute($class,[[$attribute, \@query, $operator]]);
	    } else {
	       my @tmp;
	       foreach my $cls ($self->dba->ontology->list_allowed_classes($class,$attribute)) {
		   push @tmp, map {$_->db_id} @{$self->dba->fetch_instance
						    ($cls,[[undef,\@query,$operator]])};
	       }
	       if (@tmp) {
		   $ar = $self->dba->fetch_instance_by_attribute($class,[[$attribute, \@tmp]]);
	       }
	   }
	} elsif ($class && ! $attribute && @query) {
            my $query = [[$attribute, \@query, $operator]];
	    $ar = $self->dba->fetch_instance($class,$query);
	} elsif ($class && ! $attribute && ! @query) {
	    $ar = $self->dba->fetch_all_class_instances_as_shells($class);
	} else {
	    my $query = [[$attribute, \@query, $operator]];
	    $ar = $self->dba->fetch_instance($class,$query);
	}
    }
#    print qq(</PRE>\n);$self->dba->debug(undef);
    return $ar;
}

# Shows the results of a query
sub print_view {
    my ($self,$ar,$subclassify) = @_;

    $self->debug && print "<PRE>", (caller(0))[3], "</PRE>\n";

    if ($self->is_popular_search_engine_mode() && defined $self->cgi->param('SEARCH_UTILS_OPERATOR')) {
		# Format the results to make it look as though they had
		# been produced by a well-known search engine.
		my $query = $self->cgi->param('QUERY');
	    my $operator = $self->cgi->param('SEARCH_UTILS_OPERATOR');
		my $species_db_id = $self->cgi->param('SPECIES');
		my $su = GKB::SearchUtils->new($self->dba);
		$su->paginate_query_results($self->cgi, $ar, $query, $operator, $species_db_id);
		return;
    }

    if (! @{$ar}) {
    	my @query = $self->cgi->param('QUERY');
		print "<P />Your query did not match anything.\n";
		print "<P /><A HREF=\"" . $PROJECT_HELP_URL . "?subject=Can you help with a $PROJECT_NAME query\%3F&body=Hi\%2C\%0D\%0A\%0D\%0AI tried to run the query\%3A\%0D\%0A\%0D\%0A@query\%0D\%0A\%0D\%0A...but it produced no results\%2C can you help\%3F\"><B>BUT:</B> if you let us know what you want to find, maybe we can help! (click here)</A>\n";
		print "<HR>\n";
		return;
    }

    my $classic = $self->cgi->param('CLASSIC');
    if (!(defined $classic && $classic =~ /1/)) {
	$classic = $self->cgi->cookie('ClassicView');
    }

# For some reason, if this code is present, IE7 always breaks when
# displaying fly pathways under the fly server.  TODO: find out why!
    # nasty hack to avoid view siwtch link to be printed on pages with multiple instances since
    # javascrpt reload, which just reloads the url, of those pages would not reload the page contents
    if (@{$ar} > 1) {
		$self->omit_view_switch_link(1);
    }

    $DB::single=1;
    if ($self->cgi->param('OUTPUTINSTRUCTIONS')) {
		print "<PRE>\n";
		$self->print_userdefined_view($ar);
		print "</PRE>\n";
    } elsif (my $format = $self->cgi->param('FORMAT')) {
    	if (lc($format) eq 'elv' && scalar(@{$ar})==1 && !($self->is_in_diagram($ar->[0]))) {
    		$format = 'sidebarwithdynamichierarchy';
    	}

 		if (lc($format) eq 'list') {
	    	$self->print_instance_name_list($ar,$subclassify);
		} elsif (lc($format) eq 'eventbrowser') {
		    my $urlmaker = $self->urlmaker;
		    my $o_script_name = $urlmaker->script_name;
		    $urlmaker->script_name('/cgi-bin/eventbrowser');
		    #print GKB::PrettyInstance::reactionmap_js;
		    foreach (@{$ar}) {
			$_ = replace_StableIdentifier_instance_with_referrer($_);
			print GKB::PrettyInstance->new(-INSTANCE => $_,
						       -URLMAKER => $urlmaker,
						       -SUBCLASSIFY => 1,
#						       -DEBUG => $self->debug,
						       -WEBUTILS => $self
						       )->html_table;
		    }
		    $urlmaker->script_name($o_script_name);
		} elsif (lc($format) eq 'instancebrowser') {
		    foreach (@{$ar}) {
			print GKB::PrettyInstance->new(-INSTANCE => $_,
						       -URLMAKER => $self->urlmaker,
						       -SUBCLASSIFY => 0,
						       -DEBUG => $self->debug,
						       -WEBUTILS => $self
						       )->html_table2;
		    }
		} elsif (lc($format) eq 'htmltable') {
		    $self->print_instance_attribute_value_table($ar);
		} elsif (lc($format) eq 'sidebarwithdynamichierarchyold') {
		    my $urlmaker = $self->urlmaker;
		    my $o_script_name = $urlmaker->script_name;
		    $urlmaker->script_name('/cgi-bin/eventbrowser');
		    #print GKB::PrettyInstance::reactionmap_js;
		    foreach (@{$ar}) {
			$_ = replace_StableIdentifier_instance_with_referrer($_);
			print GKB::PrettyInstance->new(-INSTANCE => $_,
						       -URLMAKER => $urlmaker,
						       -SUBCLASSIFY => 1,
						       -DEBUG => $self->debug,
						       -WEBUTILS => $self
						       )->html_table_w_dynamic_eventhierarchy;
		    }
		    $urlmaker->script_name($o_script_name);
		} elsif (lc($format) eq 'sectioned' || (defined $classic && $classic =~ /1/ && lc($format) eq 'elv')) {
                    $DB::single=1;
		    my $swr = GKB::Render::HTML::SectionedView->new(-WEBUTILS => $self);
		    foreach (@{$ar}) {
			$_ = replace_StableIdentifier_instance_with_referrer($_);
			print $swr->render($_);
		    }
		} elsif (lc($format) eq 'sidebarwithdynamichierarchy') {
		    my $swr = GKB::Render::HTML::SectionedView::EventHierarchyInSideBar->new(-WEBUTILS => $self);
		    foreach (@{$ar}) {
			$_ = replace_StableIdentifier_instance_with_referrer($_);
			print $swr->render($_);
		    }
		} elsif (lc($format) eq 'elv' && scalar(@{$ar})==1 && $self->is_in_diagram($ar->[0])) {
			my $url = $self->build_pathway_browser_url($ar->[0]);
		    print $self->form_redirect($url);
		} else {
		    $self->print_category_count($ar);
		}
    } else {
		$self->print_category_count($ar);
    }
}

sub build_pathway_browser_url {
    my ($self, $instance) = @_;

    my $logger = get_logger(__PACKAGE__);

    # when running in containers, the hostname should be localhost!
    my $hostname = $GKB::Config::HOST_NAME;
    if (!$hostname || $hostname !~ /reactomecurator/) {
        croak if (!$instance->stableIdentifier->[0] || !$instance->stableIdentifier->[0]->identifier->[0]);
        my $stable_identifier = $instance->stableIdentifier->[0]->identifier->[0];

        my $url = "/PathwayBrowser/#/$stable_identifier";

        $logger->info("url=$url\n");

        return $url;
    }

    my $db = $self->cgi->param('DB');

    my $db_id = $instance->db_id();

    $self->find_db_id_of_deepest_pathway_with_diagram($instance);


    my $focus_pathway_db_id = $self->cgi->param('FOCUS_PATHWAY_ID')
	|| $self->find_db_id_of_deepest_pathway_with_diagram($instance);

    my $db_element = "";
    if (defined $db && !($db eq "")) {
	$db_element = "DB=$db&";
    }

    my $focus_pathway_db_id_element = "";
    if (defined $focus_pathway_db_id && !($focus_pathway_db_id eq "")) {
	$focus_pathway_db_id_element = "FOCUS_PATHWAY_ID=$focus_pathway_db_id&";
    }

    my $species_db_id = $self->cgi->param('FOCUS_SPECIES_ID');
# The old way of doing things uses the focus species from the
# page's URL to decide the new focus species.
#	if (!(defined $species_db_id)) {
#		$species_db_id = $self->cgi->param('SPECIES');
#	}
#	if (!(defined $species_db_id)) {
#		$species_db_id = $self->get_focus_species_db_id_from_instance($instance);
#	}
# Another way to get the species is from the instance itself.
# Assume that the first species in the list is the one to
# use.  Mostly not a problem if there is only one species,
# could be a problem for multi-species events.
    if ($instance->is_valid_attribute("species") && scalar(@{$instance->species}) > 0) {
    	$species_db_id = $instance->species->[0]->db_id();
    }
    my $species_db_id_element = "";
    if (defined $species_db_id && !($species_db_id eq "")) {
    	$species_db_id_element = "FOCUS_SPECIES_ID=$species_db_id&";
    }

    my $db_id_element = "";
    if (defined $db_id) {
	$db_id_element = "ID=$db_id&";
    }

    my $other_args = "";
    my $data_type = $self->cgi->param('DATA_TYPE');
    if (defined $data_type && !($data_type eq "")) {
	$other_args .= "DATA_TYPE=$data_type&";
    }
    my $reactome_gwt = $self->cgi->param('REACTOME_GWT');
    if (defined $reactome_gwt && !($reactome_gwt eq "")) {
	$other_args .= "REACTOME_GWT=$reactome_gwt&";
    }
    my $data_table_name = $self->cgi->param('DATA_TABLE_NAME');
    if (defined $data_table_name && !($data_table_name eq "")) {
	$other_args .= "DATA_TABLE_NAME=$data_table_name&";
    }
    my $other_species_db_id = $self->cgi->param('OTHER_SPECIES_DB_ID');
    if (defined $other_species_db_id && !($other_species_db_id eq "")) {
	$other_args .= "OTHER_SPECIES_DB_ID=$other_species_db_id&";
    }

    my $url = "/PathwayBrowser/#$db_element$species_db_id_element$focus_pathway_db_id_element$db_id_element$other_args";
    $url =~ s/\&$//;

    $logger->info("url=$url\n");

    return $url;
}

# Return true if the instance is present in a diagram
sub is_in_diagram {
    my ($self, $instance) = @_;

    my $db = $self->cgi->param('DB');
    if ($self->has_diagram($db, $instance)) {
    	return 1;
    }

    if (defined $self->find_db_id_of_deepest_pathway_with_diagram($instance)) {
    	return 1;
    }

    return 0;
}

# Return true if there is a diagram corresponding specifically to this instance
sub has_diagram {
    my ($self, $db, $instance) = @_;

    my $logger = get_logger(__PACKAGE__);

    if (!(defined $instance)) {
    	$logger->warn("instance is undef!!\n");
    	return 0;
    }

    if ($self->has_diagram_instance($instance)) {
    	if (defined $REACTOME_VERSION && $REACTOME_VERSION =~ /^[3-9]\..+$/) {
    	    return 1;
    	}
    	if ($self->has_diagram_on_disk($db, $instance)) {
    	    return 1;
    	}
    }

    return 0;
}

sub has_diagram_instance {
    my ($self, $instance) = @_;

    my $logger = get_logger(__PACKAGE__);

    if (!(defined $instance)) {
    	$logger->warn("instance is undef!!\n");
    	return 0;
    }

    my $instances = $instance->reverse_attribute_value('representedPathway');
    foreach my $instance (@{$instances}) {
    	if (defined $instance &&
    		$instance->is_a("PathwayDiagram") &&
    		scalar(@{$instance->storedATXML}) > 0 &&
    		defined $instance->storedATXML->[0] &&
    		!($instance->storedATXML->[0] eq "")) {
    		return 1;
    	}
    }

    return 0;
}

sub has_diagram_on_disk {
    my ($self, $db, $instance) = @_;

    my $logger = get_logger(__PACKAGE__);

    if (!(defined $instance)) {
    	$logger->warn("instance is undef!!\n");
    	return 0;
    }

    my $focus_pathway_db_id = $instance->db_id();
    if (!(defined $focus_pathway_db_id)) {
    	$logger->warn("supplied instance has no DB_ID!\n");
	return 0;
    }

    my $focus_species_db_id = $self->get_focus_species_db_id_from_instance($instance);

    if (defined $GK_ROOT_DIR && !($GK_ROOT_DIR eq "") && defined $db && !($db eq "") && defined $focus_species_db_id && !($focus_species_db_id eq "") && defined $focus_pathway_db_id && !($focus_pathway_db_id eq "")) {
	my $pathway_diagram_db = $db;
	my $static_files_dir = "$GK_ROOT_DIR/website/html/entitylevelview/pathway_diagram_statics/$pathway_diagram_db/$focus_species_db_id/$focus_pathway_db_id";
	if (-e $static_files_dir) {
	    return 1;
	}
    }

    return 0;
}

sub get_focus_species_db_id_from_instance {
    my ($self, $instance) = @_;

    # This could be a rather dodgy heuristic in cases where there is more than one species.
    my $focus_species_db_id = undef;
    foreach my $species (@{$instance->species}) {
    	if ($species->name->[0] eq "Homo sapiens") {
    	    $focus_species_db_id = $species->db_id();
	    last;
	}
    }
    if (!(defined $focus_species_db_id)) {
	if ($instance->is_valid_attribute("species") && scalar(@{$instance->species}) > 0) {
	    $focus_species_db_id = $instance->species->[0]->db_id();
	}
    }

    return $focus_species_db_id;
}

sub find_top_level_pathway_db_id {
    my ($self, $instance) = @_;

    my $focus_pathway = $self->find_parent_pathway($instance);
    my $focus_pathway_db_id = undef;

    if (defined $focus_pathway) {
	$focus_pathway_db_id = $focus_pathway->db_id();
    }

    return $focus_pathway_db_id;
}

sub find_parent_pathway {
    my ($self, $instance) = @_;

    my $focus_pathway;

    my $ar = $instance->follow_class_attributes
	(-INSTRUCTIONS => {'PhysicalEntity' => {'reverse_attributes' => [qw(hasComponent hasMember hasCandidate repeatedUnit input output physicalEntity)]},
			   'Event' => {'reverse_attributes' => [qw(hasComponent hasMember hasSpecialisedForm hasEvent)]},
			   'CatalystActivity' => {'reverse_attributes' => [qw(catalystActivity)]}
	 },
                 -OUT_CLASSES => ['Pathway']
	);

    @$ar = grep {$_->db_id != $instance->db_id } @$ar;
    $focus_pathway = shift @$ar || $instance;

    return $focus_pathway;
}


sub find_db_id_of_deepest_pathway_with_diagram {
    my ($self, $instance) = @_;

    my $deepest_pathway = $self->find_deepest_pathway_with_diagram($instance);
    my $db_id = undef;
    if (defined $deepest_pathway) {
	$db_id = $deepest_pathway->db_id();
    }

    return $db_id;
}

sub find_deepest_pathway_with_diagram {
    my ($self, $instance) = @_;

    # Search upwards in the instance hierarchy to get to the first
    # pathway with a diagram.
    my $ar = $instance->follow_class_attributes
	(-INSTRUCTIONS => {'PhysicalEntity' => {'reverse_attributes' => [qw(hasComponent hasMember hasCandidate repeatedUnit input output physicalEntity)]},
			   'Event' => {'reverse_attributes' => [qw(hasComponent hasMember hasSpecialisedForm hasEvent)]},
			   'CatalystActivity' => {'reverse_attributes' => [qw(catalystActivity)]}
	 },
	 -OUT_CLASSES => ['Pathway']
	);
    my $focus_pathway = undef;
    if (scalar(@{$ar})>0) {
	# It seems that the pathways are ordered according to depth in the hierarchy.
	my $db = $self->cgi->param('DB');
	for my $pathway (@{$ar}) {
	    if ($self->has_diagram($db, $pathway)) {
		$focus_pathway = $pathway;
		last;
	    }
	}
    }
    if (!(defined $focus_pathway) && $instance->is_a("Pathway")) {
	$focus_pathway = $instance;
    }

    return $focus_pathway;
}

sub replace_StableIdentifier_instance_with_referrer {
    if ($_[0]->is_a('StableIdentifier')) {
	if (my $r = $_[0]->reverse_attribute_value('stableIdentifier')->[0]) {
	    return $r;
	}
    }
    return $_[0];
}

sub print_view1 {
    my ($self,$ar,$subclassify) = @_;
    $self->debug && print "", (caller(0))[3], "\n";
    if (! @{$ar}) {
	print "<P />Your query did not match anything.<HR>\n";
    } elsif (@{$ar} == 1) {
	$ar->[0]->debug($self->debug);
	$ar->[0] = GKB::PrettyInstance->new(-INSTANCE => $ar->[0],
					    -URLMAKER => $self->urlmaker,
					    -SUBCLASSIFY => $subclassify,
					    -DEBUG => $self->debug,
					    -WEBUTILS => $self
#					    -CGI => $self->cgi,
					    );
	print $ar->[0]->html_table;
    } else {
	print "<P />Found ". scalar(@{$ar}) . " matches.<HR>\n";
	$self->print_grouped_instances($ar);
#	print "<P />Found ". scalar(@{$ar}) . " matches.<HR>\n" .
#	    qq(<TABLE WIDTH="$HTML_PAGE_WIDTH">\n) .
#	    join('',map {"<TR><TD>$_</TD></TR>\n"}
#	         map {$_->prettyfy(
#				   -URLMAKER => $self->urlmaker,
#				   -SUBCLASSIFY => $subclassify,
#				   -WEBUTILS => $self
#				   )->soft_displayName} @{$ar}
#		 ) .
#	    "</TABLE>\n";
    }
}

sub instance_view {
    my ($self,$ar,$subclassify) = @_;
    my $out;
    $self->debug && print "", (caller(0))[3], "\n";
    if (! @{$ar}) {
	$out =  "<P />Your query did not match anything.<HR>\n";
    } elsif (@{$ar} == 1) {
	$ar->[0]->debug($self->debug);
	$ar->[0] = GKB::PrettyInstance->new(-INSTANCE => $ar->[0],
					    -URLMAKER => $self->urlmaker,
					    -SUBCLASSIFY => $subclassify,
					    -DEBUG => $self->debug,
					    -WEBUTILS => $self
#					    -CGI => $self->cgi,
					    );
	$out = $ar->[0]->html_table;
    } else {
	$out = "<P />Found ". scalar(@{$ar}) . " matches.<HR>\n" .
	    qq(<TABLE WIDTH="$HTML_PAGE_WIDTH">\n) .
	    join('',map {"<TR><TD>$_</TD></TR>\n"}
	         map {$_->prettyfy(
				   -URLMAKER => $self->urlmaker,
				   -SUBCLASSIFY => $subclassify,
				   -WEBUTILS => $self
#				   -CGI => $self->cgi
				   )->hyperlinked_extended_displayName} @{$ar}
		 ) .
	    "</TABLE>\n";
    }
    return \$out;
}

sub print_view2 {
    my $self = shift;
    print $ {$self->instance_view2(@_)};
}

sub instance_view2 {
    my ($self,$ar,$subclassify) = @_;
    $self->debug && print "", (caller(0))[3], "\n";
    my $out;
    if (! @{$ar}) {
	$out =  "<P />Your query did not match anything.<HR>\n";
    } else {
	if (@{$ar} > 1) {
	    $out =  "<P />Found ". scalar(@{$ar}) . " matches.<HR>\n",
	}
	if (@{$ar} > 100) {
	    foreach (@{$ar}) {
		$_->isa("GKB::PrettyInstance") || $_->prettyfy(
							       -URLMAKER => $self->urlmaker,
							       -SUBCLASSIFY => $subclassify,
							       -DEBUG => $self->debug,
							       -WEBUTILS => $self
#							       -CGI => $self->cgi
							       );
		$out .= $_->hyperlinked_extended_displayName . "<BR />\n";
	    }
	} else {
	    foreach (@{$ar}) {
		$_->isa("GKB::PrettyInstance") || $_->prettyfy(
							       -URLMAKER => $self->urlmaker,
							       -SUBCLASSIFY => $subclassify,
							       -DEBUG => $self->debug,
							       -WEBUTILS => $self
#							       -CGI => $self->cgi
							       );
		$out .= $_->html_table2 . "<P />\n";
	    }
	}
    }
    return \$out;
}

sub print_compact_view {
    my ($self,$ar) = @_;
    $self->debug && print "", (caller(0))[3], "\n";
    print "<P />Found ". scalar(@{$ar}) . " matches.<HR>\n";
    print '<TABLE WIDTH="$TABLEWIDTH">';
    foreach my $i (@{$ar}) {
	print qq(<TR><TD CLASS="databody">),
	$i->prettyfy(-URLMAKER => $self->urlmaker)->hyperlinked_extended_displayName,
	qq(</TD></TR>\n);
    }
    print qq(</TABLE>\n);
    print "<HR>\n";
}

sub print_cgi_params {
    my ($cgi) = @_;
    print "<PRE>\n";
    foreach ($cgi->param){
	print "$_:\t'",join("', '",$cgi->param($_)), "'\n";
    }
    print "</PRE>\n";
}

sub navigation_bar2 {
    my $self = shift;
    my $dbstring = "";
    if ($self && $self->cgi && $self->cgi->param('DB')) {
	$dbstring = "?DB=" . $self->cgi->param('DB');
    }
    return <<_END_;

<div id="dhtmltooltip" class="dhtmltooltip"></div><script language="javascript" src="/javascript/tooltip.js"></script>

<style type="text/css">
TABLE.navigation { border: thin solid #B0C4DE; }
TABLE.navigation TD { background-color:  #DCDCDC; }
TABLE.submenu { border: thin solid #B0C4DE; }
TABLE.submenu TD { background-color:  #DCDCDC; padding-top: 5px; padding-bottom: 5px; border-bottom: thin solid #B0C4DE; z-index:100;}
</style>

<script language="JavaScript" src="/javascript/topmenu.js"></script>

<script language="JavaScript">
menu = new Menu();
menu.addItem("logo", '<IMG SRC="' . $PROJECT_LOGO_URL . '" WIDTH="30" HEIGHT="30" BORDER="0">', "Home",  "/cgi-bin/frontpage$dbstring", null);
menu.addItem("home", "Home", "Home",  "/cgi-bin/frontpage$dbstring", null);
menu.addItem("news", "News", "News",  null, null);
menu.addItem("toc", "TOC", "TOC",  "/cgi-bin/toc$dbstring", null);
menu.addItem("docs", "Documents", "Documents", null, null);
menu.addItem("tools", "Tools", "Tools", null, null);
menu.addItem("download", "Download", "Download", "/download", null);
menu.addItem("misc", "How to...", "How to...", null, null);
menu.addItem("ecal", "Editorial calendar", "",  "/editorial_calendar_public.htm", null);
menu.addItem("contact", "<A HREF='" . $PROJECT_HELP_URL . "'>Contact</A>", $PROJECT_HELP_URL, null, null);

menu.addSubItem("news", "HTML", "",  "/news.html", "");
menu.addSubItem("news", "RSS", "",  "/xml/Reactome.rss", "");

menu.addSubItem("docs", "About Reactome", "",  "/about.html", "");
menu.addSubItem("docs", "Data model introduction", "",  "/data_model.html", "");
menu.addSubItem("docs", "Data model details", "",  "/cgi-bin/classbrowser$dbstring", "");
menu.addSubItem("docs", "Description of electronic inference", "",  "/electronic_inference.html", "");
menu.addSubItem("docs", "User guide", "",  $USER_GUIDE_URL, "userguide");
//menu.addSubItem("docs", "News", "",  "/news.html", "");
menu.addSubItem("docs", "Disclaimer", "",  "/disclaimer.html", "");

menu.addSubItem("tools", "Extended search", "",  "/cgi-bin/extendedsearch$dbstring", "");
menu.addSubItem("tools", "SkyPainter", "",  "/cgi-bin/skypainter2$dbstring", "");
menu.addSubItem("tools", "PathFinder", "",  "/cgi-bin/pathfinder$dbstring", "");

menu.addSubItem("misc", "...cite Reactome", "",  "/citation.html", "");
menu.addSubItem("misc", "...link to Reactome", "",  "/referring2GK.html", "");

menu.showMenu();
</script>
_END_
}

# Creates a link to an eventbrowser_st_id CGI that you can
# put onto a web page.  Needs stable ID, version number and
# release number (can be empty string). Additionally, link
# text is needed.  You can specify "other_text" that will be
# placed on the same line after the link.  If you don't want
# to do this, set this argument to an empty string.
sub link_to_eventbrowser_st_id {
	my ($self, $style, $identifier, $version, $release_num, $link_text, $other_text) = @_;

	my $form_name = $self->form_name_for_eventbrowser_st_id($identifier, $version, $release_num);
	my $out = $self->form_for_eventbrowser_st_id($form_name, $identifier, $version, $release_num);
	$out .= $self->onclick_for_eventbrowser_st_id($style, $form_name, $link_text, $other_text);

	return $out;
}

# Creates a form name for an eventbrowser_st_id CGI.
# Needs stable ID, version number and
# release number (can be empty string).
sub form_name_for_eventbrowser_st_id {
	my ($self, $identifier, $version, $release_num) = @_;

	my $form_name = "outdated_instance_form_$identifier";
	# Add extra stuff to the name, to make it unique, otherwise
	# you will get javascript errors.
	if (defined $version && !($version eq '')) {
		# Use underscore - full-stop confuses javascript
		$form_name .= "_$version";
	}
	if (defined $release_num && !($release_num eq '')) {
		# Use underscore - full-stop confuses javascript
		$form_name .= "_$release_num";
	}

	return $form_name;
}

# Creates a form for an eventbrowser_st_id CGI that you can
# put onto a web page.  Needs stable ID, version number and
# release number (can be empty string).
sub form_for_eventbrowser_st_id {
	my ($self, $form_name, $identifier, $version, $release_num) = @_;

	# The ST_ID is redundant, because it is not needed for the POST
	# operation, but it is needed if the user bookmarks this URL.
	my $action = "/cgi-bin/eventbrowser_st_id?ST_ID=$identifier";
	if (defined $version && !($version eq '')) {
		$action .= ".$version";
	}
	my $out .= $self->cgi->start_form(-name => $form_name, -method => 'POST', -action => $action);

	# Send these parameter, but hidden, so that if the user
	# bookmarks it, it won't show.  The 'FROM_REACTOME' flag
	# forces eventbrowser_st_id to show a regular eventbrowser
	# page even if, for example, the instance has been deleted.
	$out .= $self->cgi->hidden(-name => 'ST_ID', -value => $identifier . '.' . $version);
	$out .= $self->cgi->hidden(-name => 'FORMAT', -value => $self->cgi->param('FORMAT'));
	$out .= $self->cgi->hidden(-name => 'FROM_REACTOME', -value => 'true');
	if (defined $release_num && !($release_num eq '')) {
		$out .= $self->cgi->hidden(-name => 'RELEASE_NUM', -value => $release_num);
	}

	$out .= $self->cgi->end_form;

	return $out;
}

# Creates a link to an eventbrowser_st_id CGI that you can
# put onto a web page.  Needs  lin text.  You can specify
# "other_text" that will be
# placed on the same line after the link.  If you don't want
# to do this, set this argument to an empty string.
sub onclick_for_eventbrowser_st_id {
	my ($self, $style, $form_name, $link_text, $other_text) = @_;

	if (defined $style && !($style eq '')) {
		$style = qq{STYLE="$style"};
	}

	# Creates the link
	my $out .= qq{<A $style ONCLICK="document.$form_name.submit(); return false">$link_text</A>$other_text};

	return $out;
}

# If the user is perusing an instance that is not part of the
# most recent release (e.g. because he/she has followed a link
# on the stable identifier history page) then give a little
# warning at the head of the page.  However, we don't want this
# happen for all commands, so check the current URL first, to
# make sure we arn't running a command where the warning would
# be inappropriate.
sub release_warning {
    my $self = shift;

    my $logger = get_logger(__PACKAGE__);

    my $release_warning = '';
    if (defined $WARNING && !($WARNING eq '')) {
    	$release_warning = $WARNING;
    }
    if (defined $self) {
    	# Only run this chunk of code in non-static mode, otherwise
    	# it will break.
    	my $cgi = $self->cgi;
    	if (!(defined $cgi)) {
	    $logger->warn("CGI in not defined!!\n");
    	    return $release_warning;
	}

	my $url = $cgi->url();

	if (!$url || !($url =~ /control_panel_st_id/ || $url =~ /bookmarker_st_id/)) {
	    my $current_release_db_name = $cgi->param('DB');

	    # Gives access to a whole bunch of methods for dealing with
	    # previous releases and stable identifiers.
	    my $si = GKB::StableIdentifiers->new($cgi);

	    if ($si->is_known_release_name($current_release_db_name)) {
	        my $most_recent_release_db_name = $si->get_most_recent_release_db_name();
	        my $return_page = "frontpage?DB=$most_recent_release_db_name";
	        if (!($current_release_db_name eq $most_recent_release_db_name)) {
		    my ($identifier, $version) = $si->get_identifier_and_version_in_most_recent_release();
		    if ($identifier) {
		        $return_page = "eventbrowser_st_id?ST_ID=$identifier";
		    }
		    my $current_release_num = $si->get_release_num_from_db_name($current_release_db_name);
		    $release_warning .=
		    qq{<DIV STYLE="font-size:9pt;font-weight:bold;text-align:center;color:red;padding-top:10px;">
		    The currently displayed page is from release $current_release_num.  To return to the most
		    recent release, click <A HREF="$return_page">here</A>.</DIV>\n};
		}
	    }
	    $si->close_all_dbas();
	}
    }

    return $release_warning;
}

## Supplies any warning messages that should be presented to
## the user.  Note, this should not be called from any method
## that is likely to be used statically, e.g. navigation_bar.
#sub warnings {
#    my $self = shift;
#
#	return $WARNING . $self->release_warning();
#}

# Creates the navigation bar that goes at the top of most Reactome
# web pages.
sub navigation_bar {
    my $self = shift;

    my $db_name = undef;
    my $dbstring = "";
    if ($self && $self->cgi && $self->cgi->param('DB')) {
    	$db_name = $self->cgi->param('DB');
		$dbstring = "?DB=$db_name";
    }

#    my $use_reactome_icon = 1;
#    if ($self && $self->cgi && $self->cgi->param('NO_ICON')) {
#		$use_reactome_icon = 0;
#    }
    my $use_reactome_icon = 0;

    my $launch_new_page_flag = 0;
    if ($self && $self->cgi && $self->cgi->param('NEW_PAGE')) {
		$launch_new_page_flag = 1;
    }

	my $old_release_flag = 0;
	if (defined $self && defined $self->cgi) {
		# Only run this chunk of code in non-static mode, otherwise
		# it will break.

		my $si = GKB::StableIdentifiers->new($self->cgi);
		$old_release_flag = $si->is_old_release();
		$si->close_all_dbas();
	}

	my $release_warning = release_warning();
	if ($self) {
		$release_warning = $self->release_warning();
	}

	my $display_banner = "true";
    if ($self && $self->cgi && $self->cgi->param('NO_BANNER')) {
		$display_banner = undef;
    }

	my $view = GKB::NavigationBar::View->new(GKB::NavigationBar::Model->new($db_name, $old_release_flag, $use_reactome_icon, $launch_new_page_flag), $release_warning, $display_banner);
	my $out = $view->generate();
	return $out;
}

sub top_navigation_box {
    navigation_bar(@_);
}

sub navigation_bar_with_query_box {
    navigation_bar(@_);
}

sub reactome_logo {
    my $self = shift;

	return qq(<IMG SRC="$PROJECT_LOGO_URL" HEIGHT="30" WIDTH="30">\n);
}

sub print_TOC {
    my ($self) = @_;
    print qq(<TABLE WIDTH="$HTML_PAGE_WIDTH" CLASS="reactome" BORDER="0" CELLPADDING="0" CELLSPACING="0">\n);
    print qq(<THEAD><TR><TH scope="col">Topic</TH><TH scope="col" WIDTH="20%">Authors</TH><TH scope="col">&nbsp;&nbsp;&nbsp;Released&nbsp;&nbsp;&nbsp;</TH><TH scope="col">&nbsp;&nbsp;&nbsp;Revised&nbsp;&nbsp;&nbsp;</TH><TH scope="col" WIDTH="20%">Reviewers</TH><TH scope="col" WIDTH="20%">Editors</TH></TR></THEAD>\n);
    my @fpis;
    foreach my $fp (@{$self->dba->fetch_all_class_instances_as_shells('FrontPage')}) {
		push @fpis, @{$fp->FrontPageItem};
    }
    my @curated_orthologues;
	foreach my $fp (@fpis) {
		push @curated_orthologues, grep {! $_->EvidenceType->[0]} @{$fp->OrthologousEvent};
    }
    push @fpis, @curated_orthologues;
    # order alphabetically
    @fpis = sort {uc($a->displayName) cmp uc($b->displayName)} @fpis;

    foreach my $fp (@fpis) {
		#$self->urlmaker || $self->throw("Need URLMaker object.");
		print $fp->prettyfy(
                -WEBUTILS => $self,
                -URLMAKER => $self->urlmaker,
			    -SUBCLASSIFY => 1,
			    -CGI => $self->cgi)->top_browsing_view();
    }
    print qq(</TABLE>\n);
}

# Table of contents specifically for pathways with a DOI
sub print_DOI_TOC {
    my ($self) = @_;

    print qq(<TABLE WIDTH="$HTML_PAGE_WIDTH" CLASS="reactome" BORDER="0" CELLPADDING="0" CELLSPACING="0">\n);
    print qq(<THEAD><TR><TH scope="col">Topic</TH><TH scope="col">DOI</TH><TH scope="col" WIDTH="20%">Authors</TH><TH scope="col">&nbsp;&nbsp;&nbsp;Released&nbsp;&nbsp;&nbsp;</TH><TH scope="col">&nbsp;&nbsp;&nbsp;Revised&nbsp;&nbsp;&nbsp;</TH><TH scope="col" WIDTH="20%">Reviewers</TH><TH scope="col" WIDTH="20%">Editors</TH></TR></THEAD>\n);

	# Get all pathways with a DOI
    my @pathways = @{$self->dba->fetch_instance_by_remote_attribute('Pathway', [['doi', 'IS NOT NULL', []]])};

    # order alphabetically
    @pathways = sort {uc($a->displayName) cmp uc($b->displayName)} @pathways;

    # Create table rows, one per pathway
    foreach my $pathway (@pathways) {
		#$self->urlmaker || $self->throw("Need URLMaker object.");
		print $pathway->prettyfy(
                #-URLMAKER => $self->urlmaker,
                -WEBUTILS => $self,
			    -SUBCLASSIFY => 1,
			    -CGI => $self->cgi)->top_browsing_view(1);
    }

    print qq(</TABLE>\n);
}

# Prints information about pathways according to the number
# of Reactions or PhysicalEntities that they contain.
sub print_suggested_canonical_pathways {
    my ($self, $reaction_limit, $entity_limit) = @_;

    my @pathways = ();
    my $frontpages = $self->dba->fetch_all_class_instances_as_shells('FrontPage');
    if (defined $entity_limit && !($entity_limit eq "")) {
	    foreach my $pathway (@{$frontpages->[0]->frontPageItem}) {
	    	$self->find_pathways_with_fewer_entities($pathway, $entity_limit, \@pathways);
	    }
    } else {
	    if (!(defined $reaction_limit) || $reaction_limit eq "") {
	    	$reaction_limit = 80;
	    }
	    foreach my $pathway (@{$frontpages->[0]->frontPageItem}) {
	    	$self->find_pathways_with_fewer_reactions($pathway, $reaction_limit, \@pathways);
	    }
    }

    $self->print_pathway_size_table(\@pathways);
}

sub print_pathway_size_table {
    my ($self, $pathways) = @_;

    # order alphabetically
    my @sorted_pathways = sort {uc($a->displayName) cmp uc($b->displayName)} @{$pathways};

    print "<br>Found a total of " . scalar(@sorted_pathways) . " potential canonical pathways:<br><br>\n";

	my $db = $self->cgi->param("DB");
	my $db_param_string = "";
	if (defined $db || !($db eq "")) {
		$db_param_string = "&DB=$db"
	}

    # Create table rows, one per pathway
    print qq(<TABLE WIDTH="$HTML_PAGE_WIDTH" CLASS="contents" BORDER="0" CELLPADDING="0" CELLSPACING="0">\n);
    print qq(<TR CLASS="contents"><TH>Topic</TH><TH>Reaction count</TH><TH>Entity count</TH></TR>\n);
    foreach my $pathway (@sorted_pathways) {
    	print qq(<TR CLASS="contents">);

    	# _displayName
    	print qq(<TD CLASS="sidebar" WIDTH="33%">);
    	print "<A HREF=\"/cgi-bin/eventbrowser?ID=" . $pathway->db_id() . "$db_param_string\">" . $pathway->_displayName->[0] . "</A>";
    	print qq(</TD>);


    	# Reaction count
    	print qq(<TD CLASS="sidebar" WIDTH="33%">);
    	print $self->count_reactions_in_pathway($pathway);
    	print qq(</TD>);

    	# Entity count
    	print qq(<TD CLASS="sidebar" WIDTH="33%">);
    	print $self->count_entities_in_pathway($pathway);
    	print qq(</TD>);

    	print qq(</TR>);
    }
    print qq(</TABLE>\n);
}

# Finds all pathways below the given pathway with less than
# the given number of component reactions.  Matching pathways
# are appended to the pathways list provided as an argument.
sub find_pathways_with_fewer_reactions {
    my ($self, $pathway, $reaction_limit, $pathways) = @_;

    my $logger = get_logger(__PACKAGE__);

    if (!(defined $pathway)) {
    	$logger->warn("pathway is null!\n");
    	return;
    }
    if (!($pathway->is_a('Pathway'))) {
    	$logger->warn("you must supply a Pathway instance; you have supplied an instance of type: " . $pathway->class() . "\n");
    	return;
    }
    if (!(defined $pathways)) {
    	$pathways = [];
    }

    if ($self->count_reactions_in_pathway($pathway)<=$reaction_limit) {
    	# Terminate recursion
    	push(@{$pathways}, $pathway);
    	return;
    } else {
    	foreach my $event (@{$pathway->hasEvent}) {
    		if ($event->is_a('Pathway')) {
    			# Recursively explore sub-pathways
    			$self->find_pathways_with_fewer_reactions($event, $reaction_limit, $pathways)
    		}
    	}
    }
}

# Finds all pathways below the given pathway with less than
# the given number of component PhysicalEntities.  Matching pathways
# are appended to the pathways list provided as an argument.
sub find_pathways_with_fewer_entities {
    my ($self, $pathway, $entity_limit, $pathways) = @_;

    my $logger = get_logger(__PACKAGE__);

    if (!(defined $pathway)) {
    	$logger->warn("pathway is null!\n");
    	return;
    }
    if (!($pathway->is_a('Pathway'))) {
    	$logger->warn("you must supply a Pathway instance; you have supplied an instance of type: " . $pathway->class() . "\n");
    	return;
    }
    if (!(defined $pathways)) {
    	$pathways = [];
    }

    if ($self->count_entities_in_pathway($pathway)<=$entity_limit) {
    	# Terminate recursion
    	push(@{$pathways}, $pathway);
    	return;
    } else {
    	foreach my $event (@{$pathway->hasEvent}) {
    		if ($event->is_a('Pathway')) {
    			# Recursively explore sub-pathways
    			$self->find_pathways_with_fewer_entities($event, $entity_limit, $pathways)
    		}
    	}
    }
}

# Returns a count of the number of reactions in the given pathway.
sub count_reactions_in_pathway {
    my ($self, $pathway) = @_;

    if (!(defined $pathway)) {
    	return 0;
    }

    my %instructions = (-INSTRUCTIONS =>
				{
				    'Pathway' => {'attributes' => [qw(hasComponent hasEvent)]}, # hasComponent needed for backward compatibility
				},
				 -OUT_CLASSES => ['ReactionlikeEvent']
				);

    my $instances = $pathway->follow_class_attributes(%instructions);

    return scalar(@{$instances});
}

# Returns a count of the number of PhysicalEntities in the given pathway.
sub count_entities_in_pathway {
    my ($self, $pathway) = @_;

    if (!(defined $pathway)) {
    	return 0;
    }

    my $instances = GKB::PrettyInstance::Event::get_participating_molecules($pathway);

    if (!(defined $instances)) {
    	return 0;
    }

    return scalar(@{$instances});
}

sub make_footer {
	my $copyright_renderer = '';
	if (defined $PROJECT_COPYRIGHT && !($PROJECT_COPYRIGHT eq '')) {
		my $copyright = $PROJECT_COPYRIGHT;
		if (!(defined $GK_ROOT_DIR) || -e "$GK_ROOT_DIR/website/html/copyright.html") {
			$copyright = "<A HREF=\"/copyright.html\">$copyright</A>.";
		}
		$copyright_renderer = qq(<TR CLASS="footer"><TD COLSPAN="2" CLASS="footer">$copyright  All rights reserved.</TD></TR>);
	}
	my $project_help_renderer = '';
	if (defined $PROJECT_HELP_URL && !($PROJECT_HELP_URL eq '')) {
		$project_help_renderer = qq(<ADDRESS><A HREF="$PROJECT_HELP_URL">$PROJECT_HELP_TITLE</A></ADDRESS>);
	}
	qq(<TABLE WIDTH="$HTML_PAGE_WIDTH">) .
	$copyright_renderer .
	qq(<TR CLASS="footer"><TD><I>Date: ) .
	&format_date .
	qq(</I></TD><TD ALIGN="right">) .
	$project_help_renderer .
	qq(</TD></TR></TABLE>\n) .
	qq(<!-- FOOTER END -->\n);
}

# Returns a scrap of Javascript for your HTML that creates
# a bookmarkable link.  You must supply the text that will
# appear in the bookmark, plus the URL.
sub create_bookmark {
	my ($self, $style, $text, $url) = @_;

	if (defined $style && !($style eq '')) {
		$style = qq{STYLE="$style"};
	}

	my $bookmark = <<__END__;
<script LANGUAGE="Javascript">

document.write('<A $style HREF="');
if (window.external) {
    document.write("javascript:window.external.AddFavorite('$url','$text')");
} else if (window.sidebar) {
    document.write("javascript:window.sidebar.addPanel('$text','$url','')");
} else {
    document.write("javascript:alert('Bookmarking not available for your browser')");
}
document.write('">Bookmark</A>');
</script>
__END__

	# Doing this to make it cross-browser compatible
	# is hard, so for the time being, give up.
	$bookmark = '';

	return $bookmark;
}

sub format_date {
    my ($sec, $min, $hour, $day, $month, $year) = localtime();
    $year  += 1900;
    $month += 1;
        return sprintf( "%04d-%02d-%02d %02d:%02d:%02d", $year, $month, $day, $hour, $min, $sec );
}

sub print_protege2mysql_form {
    my $self = shift;
    my ($s) = $self->cgi->path_info =~ /(\d+)/; $s++;
    print $self->cgi->start_multipart_form(-action => $self->cgi->script_name . "/$s");
    print $self->cgi->hidden(-name => 'DB',-value => $self->cgi->param('DB'));
    print $self->cgi->table({-border => 1, -cellpadding => 2, cellspacing => 0, -width => "$HTML_PAGE_WIDTH", class => ''},
			    $self->cgi->Tr
			    ($self->cgi->td({-colspan => 3},
					    "Your project's pins file",
					    $self->cgi->filefield
					    (-name => 'FILE',
					     -size => 30
					     ),
#					    $self->cgi->checkbox
#					    (-name => 'IGNORE_DB_ID',
#					     -label => 'Ignore DB_IDs'
#					     )
					    )
			      ),
			    $self->cgi->Tr
			    ($self->cgi->td([
					     $self->cgi->submit
					     (-name=>'CHECK',
					      -value=>'Check'
					      ),
					     $self->cgi->submit
					     (-name=>'SUBMIT',
					      -value=>'Submit',
					      -label=>'Submit'
					      ),
					     $self->cgi->reset
					     (-name=>'Reset')
					     ])
			     )
			    );
    print $self->cgi->end_form, "\n";
}

sub handle_protege2mysql_form {
    my $self = shift;
#    print qq(<PRE>\n);
#    $self->dba->debug(1);
    if ($self->cgi->param('TMPDB')) {
	$self->_handle_tmp_db;
    } elsif ($self->cgi->param('SUBMIT') || $self->cgi->param('CHECK')) {
	$self->_handle_new_protege_upload;
    } else {
	$self->print_protege2mysql_form;
    }
#    print qq(</PRE>\n);
}

sub _handle_tmp_db {
    my $self = shift;
    $self->dba->matching_instance_handler
	(GKB::MatchingInstanceHandler::WebWriteBack->new
	 (-CGI => $self->cgi,
	  -WEBUTILS => $self
	  )
	 );
    #$self->dba->debug(1);$self->dba->matching_instance_handler->debug(1);
    eval {
	my $ar = $self->dba->matching_instance_handler->handle_temporarily_stored_instances($self->dba);
	foreach my $i (grep {$_->class ne 'InstanceEdit'} @{$ar}) {
	    #print qq(<PRE>) . (caller(0))[3] . "\t" . $i->id_string . qq(</PRE>\n);
	    $self->dba->store_if_necessary($i);
	}
    };
    if ($@) {
	if ($@ !~ /have to handle the matching instance/) {
	    $self->throw($@);
	}
	$self->dba->matching_instance_handler->print_report;
    } else {
	$self->dba->matching_instance_handler->tmp_dba->drop_database;
	$self->dba->matching_instance_handler->print_final_report;
    }
}

sub _handle_new_protege_upload {
    my $self = shift;
#    print qq(<PRE>Uploading file.</PRE>\n);
    my $fh = $self->cgi->upload('FILE');
    unless ($fh) {
	print "<BR />Please go back and click the <B>Browse...</B> button to select the file to be uploaded.";
	return;
    }
    my $filename = $self->cgi->param('FILE');
    if ($filename =~ /\.(pont|pprj)$/) {
	die("<STRONG>Try uploading .pins file ;-).</STRONG>\n");
    }
    my $tmpfilename = $self->cgi->tmpFileName($filename);
#    print qq(<PRE>Sanitizing pins file.</PRE>\n);
    sanitize_uploaded_file($tmpfilename);
#    print qq(<PRE>Parsing pins file.</PRE>\n);
    my $clptr = GKB::ClipsAdaptor->new(-FILE => $tmpfilename, -ONTOLOGY => $self->dba->ontology);
    my $cache = $clptr->fetch_instances;
#    print qq(<PRE>Finding default InstanceEdit.</PRE>\n);
    my $default_ie = GKB::Utils::find_default_InstanceEdit([$cache->instances]);
    $self->dba->default_InstanceEdit($default_ie);
    $self->dba->matching_instance_handler(GKB::MatchingInstanceHandler::WebWriteBack->new(-CACHE => $cache, -CGI => $self->cgi, -WEBUTILS => $self));
    #$self->dba->debug(1);$self->dba->matching_instance_handler->debug(1);
    if ($self->cgi->param('IGNORE_DB_ID')) {
#	foreach my $i ($clptr->instances) {
	foreach my $i ($cache->instances) {
	    $i->attribute_value($GKB::Ontology::DB_ID_NAME,undef);
	}
    }
# FOR DEBUGGING
#    $Data::Dumper::Maxdepth = 2;
#    foreach my $i ($cache->instances) {
#	my $o = $i->ontology;
#	$i->ontology(undef);
#	print '<PRE>', Data::Dumper->Dumpxs([$i],["$i"]), "</PRE>\n";
#	$i->ontology($o);
#	$i->is_ghost;
#    }
    # Load ghost instances' displayNames from db since they may have
    # changed during the time from extraction.
#    print qq(<PRE>Loading ghosts\' displaynames.</PRE\n);
    foreach my $i (grep {$_->attribute_value($DB_ID_NAME)->[0]} grep {$_->is_ghost} $cache->instances) {
	$i->dba($self->dba);
	$i->db_id($i->attribute_value($DB_ID_NAME)->[0]);
	$i->load_single_attribute_values('_displayName');
	$i->db_id(undef);
	$i->dba(undef);
    }
    # Have to unset them 1st since some instance's displayName may require
    # some other instance's displayName which may not be set properly yet.
    # However, it is important not to delete shallowly extracted (ghost)
    # instances' displayNames.
#    print qq(<PRE>Unsetting non-ghosts\s displaynames.</PRE>\n);
    foreach my $i (grep {! $_->is_ghost} $cache->instances) {
	$i->attribute_value('_displayName', undef);
    }
    # Don't try to re-set displayNames of ghosts
#    print qq(<PRE>Setting non-ghosts\s displaynames.</PRE>\n);
    foreach my $i (grep {! $_->is_ghost} $cache->instances) {
	$i->namedInstance;
    }
#    $self->dba->debug(1);
    if ($self->cgi->param('SUBMIT')) {
	unless ($default_ie) {
	    print "<P>Can't commit since the project lacks default InstanceEdit.</P>\n";
	    return;
	}
	my $deleted = $self->dba->check_if_instances_have_been_deleted([$cache->instances]);
	if (@{$deleted}) {
	    print "<PRE><B>Can't commit since the project contains " . scalar(@{$deleted}) . " instance(s) which have been deleted from the db:</B>\n";
	    print join("\n", map {$_->extended_displayName} @{$deleted}), "\n</PRE>\n";
	    return;
	}
	if ($self->_check_and_report_cyclicals([$cache->instances])) {
	    return;
	}
	#print qq(<PRE>\n);
	$self->dba->back_up_db;
#        # fire off a script to backup db via mysqlhotcopy
#	!system("/usr/bin/sudo /usr/local/sbin/gk_dbdump") || die "Cannot backup database!\n";
	my $no_final_report;
	# Skip InstanceEdits here, they should be stored by virtue of being attached to
	# another instance.
	foreach my $i ($cache->instances) {
	    if (($i->class eq 'InstanceEdit') &&
		(! $i->attribute_value($DB_ID_NAME)->[0])) {
		next;
	    }
#	    print qq(<PRE>) . (caller(0))[3] . "\t" . $i->id_string . qq(</PRE>\n);
	    eval {
		$self->dba->store_if_necessary($i);
	    };
	    if ($@) {
		if ($@ =~ /have to handle the matching instance/) {
		    $self->dba->matching_instance_handler->print_report;
		    $no_final_report = 1;
		    last;
		} else {
		    $self->throw($@);
		}
	    }
	}
	#print qq(</PRE>\n);
	$no_final_report || $self->dba->matching_instance_handler->print_final_report;
    } else {
	print qq(<HR /><STRONG>Got ) . scalar($cache->instances) . qq( instances</STRONG>\n);
#	my $devnull = File::Spec->devnull;
#	local *DEVNULL;
#	open DEVNULL, ">$devnull" || $self->throw($!);
#	$self->dba->matching_instance_handler->_fh(*DEVNULL);
#	print qq(<PRE>\n);
	$default_ie || print "<PRE>No default InstanceEdit specified.</PRE>\n";
#	$self->dba->debug(1);
	unless ($self->_check_and_report_cyclicals([$cache->instances])) {
	    print qq(<PRE>\n);
	    foreach my $i ($cache->instances) {
#		foreach my $i (grep {! $_->attribute_value($DB_ID_NAME)->[0]} grep {! $_->is_ghost} $cache->instances) {
#		print "<BR />", $i->extended_displayName, "\n";
		$self->dba->check_for_identical_instances_in_db($i);
	    }
	    print qq(</PRE>\n);
	    $self->_report_internal_duplicates($cache);
	}
#	$self->dba->debug(undef);
#	close DEVNULL;
#	print qq(</PRE>\n);
	$self->_report_internal_duplicates($cache);
	print "<PRE>Checking completed!</PRE>\n";
    }
}

sub _check_and_report_cyclicals {
    my ($self,$ar) = @_;
    my @cyclicals = &GKB::Utils::check_for_cyclic_defining_attribute_values($ar);
    if (@cyclicals) {
	print "<P /><STRONG>Your project contains following instance(s) which refer to iteself in defining attributes. These cycles will ahve to be removed before the project can be submitted:</STRONG>\n";
	foreach my $i (@cyclicals) {
	    print "<P />", $i->extended_displayName, "\n";
	}
	print qq(<BR />\n);
	return 1;
    }
    return undef;
}

sub _report_internal_duplicates {
    my ($self,$cache) = @_;
    my %h;
    foreach my $i ($cache->instances) {
	if ($i->attribute_value($DB_ID_NAME)->[0]) {
	    $h{$i->attribute_value($DB_ID_NAME)->[0]} ? push(@{$h{$i->attribute_value($DB_ID_NAME)->[0]}}, $i)
		: ($h{$i->attribute_value($DB_ID_NAME)->[0]} = [$i]);
	} elsif ($i->identical_instances_in_db) {
	    map {$h{$_->db_id} ? push(@{$h{$_->db_id}}, $i) : ($h{$_->db_id} = [$i])} @{$i->identical_instances_in_db};
	}
    }
    print qq(<PRE>\n);
    foreach my $ar (grep {@{$_} > 1} values %h) {
	print qq(<STRONG>Internal duplicate set:</STRONG>\n) . join("\n", map {$_->extended_displayName} @{$ar}) . "\n";
    }
    print qq(</PRE>\n);
}

sub sanitize_uploaded_file {
    my ($path) = shift;
    $path || die "Need path.";
    ($path) = $path =~ /^(.+)$/;
    my $tmp = "$path.tmp";
    local *IN;
    open IN, $path || die "Cannot read $path: $!";
    local *OUT;
    open OUT, ">$tmp" || die "Cannot create $tmp: $!";
    while(<IN>) {
	s/\0//g;
	print OUT $_;
    }
    close IN;
    close OUT;
    move($tmp,$path) || die "Move failed: $!";
}

sub print_keyword_search_form {
    my $self = shift;
    print $self->cgi->start_form();
    print $self->cgi->hidden(-name => 'DB',-value => $self->cgi->param('DB')), "\n";
    $self->_print_query_boxes;
    print $self->cgi->end_form, "\n";
    print $self->cgi->p(qq(Please note that the the instances that you eventually download are not only the ones that you have selected but also the ones which are the attribute values of the selected instances and attribute values of those etc etc. However, instances which refer to a selected instance are not included unless they themselves are attribute values of some instance which is downloaded.)), "\n";
}

sub handle_keyword_search_form {
    my $self = shift;
    # Get the values 1st so that the param values can be deleted
    my $query = $self->cgi->param('QUERY');
    $self->cgi->delete('QUERY');
    $query =~ s/\r/\n/g;
    $query =~ s/\n+/\n/g;
    my $db_id_list = $self->cgi->param('DB_ID_LIST');
    $self->cgi->delete('DB_ID_LIST');
    $db_id_list =~ s/\r/\n/g;
    $db_id_list =~ s/\n+/\n/g;
    my @db_ids = $self->cgi->param('DB_ID');
    $self->cgi->delete('DB_ID');

    print qq(<TABLE CELLPADDING="2" WIDTH="$HTML_PAGE_WIDTH" CELLSPACING="2" BORDER="0">\n);
    print $self->cgi->start_form;
    print $self->cgi->hidden(-name => 'DB',-value => $self->cgi->param('DB')), "\n";
    print qq(<TR><TD COLSPAN="2">Check the instances you want to download. Check 'Shallow extraction' (below) if you wish to download in full only the selected instances. The instances referred by the selected instances will be downloaded as "ghosts" with just DB_ID and display name set. Those instances should not be edited in Protege. If you leave 'Shallow extraction' unchecked all the instances, i.e. both the ones checked as well as the ones referred by any other downloaded instance will be extracted in full.<BR /><BR /></TD></TR>\n);

    foreach my $str (grep {! /^\s*$/} split /\n/, $query) {
	my $ar = $self->_analyse_query_and_fetch_instances(\$str);
	print qq(<TR><TH>$str</TH>\n<TD>);
	my %seen;
	foreach my $i (@{$ar}) {
	    $seen{$i->db_id} = $i;
	    map {$seen{$_->db_id} = $_} @{$self->_relevant_refering_instances($i)};
	}
	print join("<BR />\n", map {$self->_checkbox_and_displayName($_,undef,$str)} values %seen);
	print qq(</TD></TR>\n);
    }
    foreach my $db_id ((grep {defined $_} map {/^\D*(\d+)/} split /\n/, $db_id_list), @db_ids) {
	print qq(<TR><TH>$db_id</TH>\n<TD>);
	if (my $i = $self->dba->fetch_instance_by_db_id($db_id)->[0]) {
	    print $self->_checkbox_and_displayName($i,1);
	}
	print qq(</TD></TR>\n);
    }
    print qq(</TABLE>\n);
    print
	qq(<TABLE WIDTH="$HTML_PAGE_WIDTH"><TR><TD>),
	$self->cgi->checkbox(-name => 'SHALLOW', -label => 'Shallow extraction'),
	qq(</TD>\n<TD>),
	$self->cgi->submit(-name => "DOWNLOAD", -value => 'Create project'),
	qq(</TD>\n<TD>),
	$self->cgi->submit(-name => "PINSONLY", -value => 'Create .pins file'),
	qq(</TD>\n<TD>),
	$self->cgi->submit(-name => "COUNT", -value => 'Count instances'),
	qq(</TD>\n<TD>),
	$self->cgi->reset,
	qq(</TD></TR>\n),
	qq(</TABLE>\n);
    $self->_reverse_attribute_to_be_followed_box;
    $self->_print_query_boxes;
    print $self->cgi->p(qq(Instances which have been checked above will be carried forward to the results of this search.));
    print $self->cgi->end_form, "\n";
}

sub _relevant_refering_instances {
    my ($self,$i) = @_;
    if ($i->is_a('SequenceDatabaseIdentifier')) {
	return [grep {! $_->is_a('ModifiedResidue')} @{$i->reverse_attribute_value('databaseIdentifier')}];
    } elsif ($i->is_a('DatabaseIdentifier')) {
	return $i->reverse_attribute_value('crossReference');
    } elsif ($i->is_a('AccessionedEntity')) {
	if ($i->DatabaseIdentifier->[0]) {
	    return [grep {! $_->is_a('ModifiedResidue')} @{$i->DatabaseIdentifier->[0]->reverse_attribute_value('databaseIdentifier')}];
	}
    } elsif ($i->is_a('SimpleEntity')) {
	if ($i->CrossReference->[0]) {
	    return $i->CrossReference->[0]->reverse_attribute_value('crossReference');
	}
    }
    return [];
}

sub _checkbox_and_displayName {
    my ($self,$i,$isChecked,$str) = @_;
    return
	$self->cgi->checkbox(-name => 'DB_ID', -value => $i->db_id, -checked => ($isChecked ? 'checked' : undef), -label => '') .
	$self->_instance_displayName($i,$str);
}

sub _reverse_attribute_to_be_followed_box {
	# TODO: Regulation.regulatedEvent will soon be removed! It will be replaced with ReactionlikeEvent.regulatedBy (1:N).
    my $self = shift;
    print
	qq(<TABLE WIDTH="$HTML_PAGE_WIDTH" CELLPADDING="2" CELLSPACING="0"><TR><TD>),
	qq(List classes and reverse attributes (as pairs) for which you want to extract also the referering instances. E.g. <I>GenericReaction instanceOf</I> would extract all the Reactions which are instances of the selected GenericReactions. Please note that refering instances will not be extracted if you check 'Shallow extraction'.),
	qq(</TD>\n<TD>),
	$self->cgi->textarea(-NAME => 'REVERSE_ATTRIBUTES_TO_BE_FOLLOWED',
			     -ROWS => 3,
			     -COLUMNS => 60,
			     -DEFAULT => "Event\tconcurrentEvents\nEvent precedingEvent\nEvent regulator\nEvent regulatedEntity\nCatalystActivity regulator\nCatalystActivity regulatedEntity\nPhysicalEntity physicalEntity"
#			     -DEFAULT => "Event\tconcurrentEvents\nEvent precedingEvent\nGenericSimpleEntity instanceOf\nEvent regulator\nEvent regulatedEntity\nCatalystActivity regulator\nCatalystActivity regulatedEntity\nSequenceDatabaseIdentifier databaseIdentifier\nPhysicalEntity physicalEntity"
			     ),
	qq(</TD></TR>\n),
	qq(</TABLE>\n<BR />\n);
}

sub _handle_reverse_attribute_to_be_followed {
    my $self = shift;
    my @out;
    if (my $str = $self->cgi->param('REVERSE_ATTRIBUTES_TO_BE_FOLLOWED')) {
	foreach my $r (split /\n/, $str) {
	    if (my ($cl,$at) = $r =~ /^(\S+)\s+(\S+)/) {
		if ($self->dba->ontology->is_valid_class_reverse_attribute($cl,$at)) {
		    push @out, [$cl, $at];
		}
	    }
	}
    }
    return \@out;
}

sub _instance_displayName {
    my ($self,$i,$str) = @_;
    my $tmp = $i->prettyfy(-URLMAKER => $self->urlmaker, -SUBCLASSIFY => 1)->hyperlinked_extended_displayName;
    $str =~ s/[.*+\-\"%]/ /g;
    if (defined $str) {
	foreach (sort {length($a) <=> length($b)} grep {length($_) > 2}split /\s+/, $str) {
	    $tmp =~ s/($_)/<STRONG>$1<\/STRONG>/gi;
	}
    }
    return $tmp;
}

sub _print_query_boxes {
    my $self = shift;
    print $self->cgi->table({-border => 0,
			     -cellpadding => 2,
			     -cellspacing => 0,
			     -width => "$HTML_PAGE_WIDTH",
			     -class => 'search2'},
			    $self->cgi->Tr(
					   [
					    $self->cgi->td({-class => 'search2'},
							   [
							    qq(Enter the terms that you want to use to find instances of interest. Each line in the box is used separately as a query string in searching all text fields in all classes. You can restrict the search to a certain class by prepending the class name and a whitespace to your query term. You can also restrict the search to single attribute by prepending both class name and attribute name.<BR />) .
							    qq(Use the pop-up menu to specify how your query string should be used for searching.<BR />) .
							    qq{For example a query <TT>PhysicalEntity name phosphate</TT> searched as
								   <UL>
								   <LI><I>Exact match</I> would find only instances of class <I>PhysicalEntity</I> with attribute <I>name</I> being exactly <TT>phosphate</TT>.</LI>
								   <LI><I>Full-text in boolean mode</I> would retrieve all <I>PhysicalEntities</I> with attribute <I>name</I> containing <STRONG>word</STRONG> <TT>phosphate</TT> (but not bisphosphate).</LI>
								   <LI><I>Regular expression</I> would yield all <I>PhysicalEntities</I> with attribute <I>name</I> containing <TT>phosphate</TT> even as a <STRONG>substring</STRONG>, i.e. <TT>bisphosphate</TT> would match.</LI>
								   </UL>
								   <!--<I>Full-text in boolean mode</I> syntax is actually fairly complex:<BR /><TT>glucose phospate</TT> matches records containing <TT>glucose</TT> <STRONG>or</STRONG> <TT>phospate</TT>.<BR /><TT>+glucose +phospate</TT> matches records containing <TT>glucose</TT> <STRONG>and</STRONG> <TT>phospate</TT>.<BR /><TT>+glucose -phospate</TT> matches records containing <TT>glucose</TT> <STRONG>but not</STRONG> <TT>phospate</TT>.<BR /><TT>"glucose phospate"</TT> matches records containing <STRONG>phrase</STRONG> <TT>glucose phospate</TT>.<BR />-->},
							    $self->cgi->textarea(-name => 'QUERY',
										 -rows => 15,
										 -columns => 60) .
							    "<BR />Search type: " .
							    $self->cgi->popup_menu(-name => 'OPERATOR',
										   -values => [
											       'REGEXP',
#											       'LIKE',
											       'MATCH',
											       'MATCH IN BOOLEAN MODE',
											       '=',
											       ],
										   -labels => {
										       'REGEXP' => 'Regular expression',
#										       'LIKE' => '',
										       'MATCH' => 'Full-text',
										       'MATCH IN BOOLEAN MODE' => 'Full-text in boolean mode',
										       '=' => 'Exact match'
										   },
										   -default => 'MATCH IN BOOLEAN MODE'
										   )
							    ]
							   ),
#					    $self->cgi->td({-colspan => 2}, ['<HR />']),
					    $self->cgi->th({-class => 'search2center', -colspan => 2, -align => 'center'},
							   [
							    $self->cgi->submit(-name => "SUBMIT",
									       -value => 'Submit')
							    ]
							   ),
					    $self->cgi->td({-class => 'search2'},
							   [
							    qq(Enter the internal database identifiers (DB_ID) for specifying instances of interest. Each DB_ID has to be on a separate line and the 1st run of numbers on the line is considered DB_ID. I.e. if you paste into this box something like <I>[SequenceDatabaseIdentifier:58613] SPTREMBL:Q13415</I>, <I>58613</I> is going to be used as DB_ID.) .
							    qq(<BR />Please note that the search boxes <STRONG>are not mutually exclusive</STRONG>, i.e. you can enter queries in to both of them.),
							    $self->cgi->textarea(-name => 'DB_ID_LIST',
										   -rows => 15,
										   -columns => 60),
							    ]
							   )

					    ]
					   )
			    );
}

sub create_protege_project {
    my $self = shift;
    my @DB_IDs = $self->cgi->param('DB_ID');
    my $instances = $self->dba->fetch_instance_by_attribute($self->dba->ontology->root_class,
							    [[$DB_ID_NAME, \@DB_IDs]]);
    my $ca;
    if ($self->cgi->param('SHALLOW')) {
	$ca = GKB::ClipsAdaptor->new;
    } else {
	my $ar = $self->_handle_reverse_attribute_to_be_followed;
	$ca = GKB::ClipsAdaptor::ToBeUsedWithInstanceExtractor->new(-CLASS_X_REVERSE_ATTRIBUTE => $ar);
    }
    $ca->create_protege_project(-BASENAME => "PROJECT_$$",
				-TGZ => 1,
				-OUTFH => \*STDOUT,
				-INSTANCES => $instances,
				-SHALLOW => ($self->cgi->param('SHALLOW') || undef),
				-DBA => $self->dba
				);
}

sub create_protege_project_wo_orthologues {
    my ($self,$basename,$ar) = @_;

    my $logger = get_logger(__PACKAGE__);

    my $instances = $self->dba->fetch_instance_by_attribute($self->dba->ontology->root_class,
							    [[$DB_ID_NAME, $ar]]);

	return unless @$instances;

    $logger->info($instances->[0]->extended_displayName, "\n");
    my $ca = GKB::ClipsAdaptor->new(
	-ONTOLOGY => $self->dba->ontology,
	-EXCLUDE_CLASS_ATTRIBUTES => {
	    'Event' => [qw(inferredFrom orthologousEvent)],
	    'PhysicalEntity' => [qw(inferredFrom)],
	    'ReferenceEntity' => [qw(atomicConnectivity referenceGroupCount)],
	    'DatabaseObject' => [qw(modified created)],
	}
	);
    $ca->create_protege_project(-BASENAME => $basename,
				-TGZ => 1,
				-INSTANCES => $instances,
				-DBA => $self->dba,
				);
}

sub create_pins_dump_only {
    my $self = shift;
    # Empty line is CLIPS record separator (?). By prepending a newline to this pins file
    # one can safely just append it to the end of an exiting pins file which doesn't
    # necessarily end with an empty line.
    print "\n";
    my @DB_IDs = $self->cgi->param('DB_ID');
    my $instances = $self->dba->fetch_instance_by_attribute($self->dba->ontology->root_class,
							    [[$DB_ID_NAME, \@DB_IDs]]);
    my $ca;
    if ($self->cgi->param('SHALLOW')) {
	$ca = GKB::ClipsAdaptor->new;
	$ca->store_instances_shallow($instances);
    } else {
	my $ar = $self->_handle_reverse_attribute_to_be_followed;
	$ca = GKB::ClipsAdaptor::ToBeUsedWithInstanceExtractor->new(-CLASS_X_REVERSE_ATTRIBUTE => $ar);
	$ca->store_instances($instances);
    }
#    foreach ($self->cgi->param('DB_ID')) {
#	foreach my $i (@{$self->dba->fetch_instance_by_db_id($_)}) {
#	    $ca->store($i);
#	}
#    }
}

sub report_instance_to_be_extracted {
    my $self = shift;
    my @DB_IDs = $self->cgi->param('DB_ID');
    my $instances = $self->dba->fetch_instance_by_attribute($self->dba->ontology->root_class,
							    [[$DB_ID_NAME, \@DB_IDs]]);
    my $ca;
    if ($self->cgi->param('SHALLOW')) {
	$ca = GKB::ClipsAdaptor->new(-FILE => "/dev/null");
	$ca->store_instances_shallow($instances);
    } else {
	my $ar = $self->_handle_reverse_attribute_to_be_followed;
	$ca = GKB::ClipsAdaptor::ToBeUsedWithInstanceExtractor->new(-CLASS_X_REVERSE_ATTRIBUTE => $ar,
								    -FILE => "/dev/null");
	$ca->store_instances($instances);
    }
    my @a = $self->dba->instance_cache->values;
    print "<P>You would extract " . scalar(@a) . " instances:</P>\n";
    foreach my $i (sort {$a->displayName cmp $b->displayName} @a) {
	print $i->prettyfy(-URLMAKER => $self->urlmaker,
			   -CGI => $self->cgi)->hyperlinked_extended_displayName, "<BR/>\n";
    }
}

sub _analyse_query_and_fetch_instances {
    my ($self,$str_r) = @_;
    my $operator = $self->_query_operator;
    if (($ {$str_r} =~ /^(\S+)\s+(.+)$/) &&
	$self->dba->ontology->is_valid_class($1)) {
	my $class = $1;
	$ {$str_r} = $2;
	if (($ {$str_r} =~ /^(\S+)\s+(.+)$/) &&
	    $self->dba->ontology->is_valid_class_attribute($class,$1)){
	    $ {$str_r} = $2;
	    return $self->dba->fetch_instance_by_attribute($class,[[$1,[$2],$operator]]);
	}
	return $self->dba->fetch_class_instance_by_string_type_attribute($class,$ {$str_r},$operator);
    }
    return $self->dba->fetch_instance_by_string_type_attribute($ {$str_r},$operator);
}

sub _query_operator {
    my $self = shift;
    return $VALID_COMPARISON_OPERATOR{$self->cgi->param('OPERATOR')} || '=';
}

sub _search_page_operator_popup_menu {
    my ($self) = @_;
    return $self->cgi->popup_menu(-name => 'OPERATOR',
				  -values => [
					      'REGEXP',
					      'MATCH IN BOOLEAN MODE',
					      '=',
					      ],
				  -labels => {
				      'REGEXP' => 'Regular expression',
				      'MATCH IN BOOLEAN MODE' => 'Full-text in boolean mode',
				      '=' => 'Exact match'
				      },
				  -default => 'MATCH IN BOOLEAN MODE'
				  )
    }
sub _generic_query_form_popup_menu {
    my ($self) = @_;
    return $self->cgi->popup_menu(-name => 'OPERATOR',
				  -values => [
					      'REGEXP',
					      'MATCH IN BOOLEAN MODE',
					      '=',
					      'IS NULL',
					      'IS NOT NULL',
					      'REGEXP BINARY',
					      ],
				  -labels => {
				      'REGEXP' => 'Regular expression',
				      'MATCH IN BOOLEAN MODE' => 'Full-text in boolean mode',
				      '=' => 'Exact match',
				      'IS NULL' => 'IS NULL',
				      'IS NOT NULL' => 'IS NOT NULL',
				      'REGEXP BINARY' => 'Case sensitive regular expression'
				      },
				  -default => 'MATCH IN BOOLEAN MODE'
				  )
}

sub print_pathfinder_form {
    my ($self) = @_;
    print qq(<DIV CLASS="section"><TABLE  CELLPADDING="2" WIDTH="$HTML_PAGE_WIDTH" CELLSPACING="2" BORDER="0" CLASS="search2">);
    print $self->cgi->start_form(-method => 'POST');
    print $self->cgi->hidden(-name => 'DB',-value => $self->cgi->param('DB')), "\n";

    my $labels_hr = {};
    my $values_ar = [];
    my $filter_function = sub {return 1;};
    my $taxon;
    if (my $val = $self->cgi->param('TAXON')) {
	if ($taxon = $self->dba->fetch_instance_by_db_id($val)->[0]) {
	    $filter_function = sub {
		return (!($_[0]->is_valid_attribute('species') &&
			  $_[0]->attribute_value('species')->[0] &&
			  $_[0]->attribute_value('species')->[0] != $taxon));
	    };
	}
    }
#    my $taxa_ar = $self->dba->fetch_all_class_instances_as_shells('Species');
    my $taxa_ar = $self->dba->fetch_instance_by_attribute('Species',[['name',['Homo sapiens','Mus musculus']]]);
    map {$labels_hr->{$_->db_id} = $_->displayName} @{$taxa_ar};
    $values_ar = [map {$_->db_id} sort {lc($a->displayName) cmp lc($b->displayName)} @{$taxa_ar}];
#    unshift @{$values_ar}, '';
#    $labels_hr->{''} = 'Any species';
    print qq(<TR><TD>Species</TD><TD>);
    print $self->cgi->popup_menu(-NAME => 'TAXON',
				 -VALUES => $values_ar,
				 -LABELS => $labels_hr,
				 -DEFAULT => $taxa_ar->[0]->db_id
				 );
#    print "<BR />\n";
    print qq(</TD></TR>\n<TR><TD>Start compound or event name</TD><TD>);

    my $from_ar = [];
    $labels_hr = {};
    $values_ar = [];
    my $default;
    my ($from_str,$from_op);
    my $op = (lc($self->dba->table_type) eq 'innodb') ? 'REGEXP' : 'PHRASE';
    if (my $val = $self->cgi->param('FROM')) {
	$from_str = $val;
	($from_op, $val) = $self->_ui_qstr_and_operator_2_mysql($op,$val);

	my %seen;

	@{$from_ar} =
	grep {! $seen{$_->db_id}++}
	grep {&{$filter_function}($_)}
	@{$self->dba->fetch_instance_by_remote_attribute('PhysicalEntity',[['name',$from_op,[$val]],
									   ['input:ReactionlikeEvent','IS NOT NULL',[]]])};

	push @{$from_ar},
	grep {! $seen{$_->db_id}++}
	grep {&{$filter_function}($_)}
	@{$self->dba->fetch_instance_by_remote_attribute('PhysicalEntity',[['_displayName',$from_op,[$val]],
									   ['physicalEntity:CatalystActivity','IS NOT NULL',[]]])};

	push @{$from_ar},
	grep {! $seen{$_->db_id}++}
	grep {&{$filter_function}($_)}
	@{$self->dba->fetch_instance_by_remote_attribute('PhysicalEntity',[['_displayName','=',[$from_str]],
									   ['input:ReactionlikeEvent','IS NOT NULL',[]]])};

	push @{$from_ar},
	grep {! $seen{$_->db_id}++}
	grep {&{$filter_function}($_)}
	@{$self->dba->fetch_instance_by_remote_attribute('PhysicalEntity',[['_displayName','=',[$from_str]],
									   ['physicalEntity:CatalystActivity','IS NOT NULL',[]]])};

	push @{$from_ar},
	grep {! $seen{$_->db_id}++}
	grep {&{$filter_function}($_)}
	@{$self->dba->fetch_instance_by_attribute('ReactionlikeEvent',[['name',[$val],$from_op],
							   ['output',[],'IS NOT NULL']])};

	push @{$from_ar},
	grep {! $seen{$_->db_id}++}
	grep {&{$filter_function}($_)}
	@{$self->dba->fetch_instance_by_attribute('ReactionlikeEvent',[['_displayName',[$from_str],'='],
							   ['output',[],'IS NOT NULL']])};

	@{$from_ar} ? $self->cgi->delete('FROM') : $self->cgi->param('FROM', "not found");
    } elsif ($val = $self->cgi->param('FROM_MENU')) {
	@{$from_ar} = grep {&{$filter_function}($_)} @{$self->dba->fetch_instance_by_db_id($val)};
    }
#    map {$labels_hr->{$_->db_id} = $_->extended_displayName} @{$from_ar};
    map {$labels_hr->{$_->db_id} = substr($_->extended_displayName,0,100)} @{$from_ar};
#    $values_ar = [map {$_->db_id} sort {length($a->displayName) <=> length($b->displayName)} @{$from_ar}];
    $values_ar = [map {$_->db_id} sort {$a->displayName cmp $b->displayName} @{$from_ar}];
    if ($from_str && (@{$from_ar} > 1)) {
	foreach (@{$from_ar}) {
	    if (lc($_->displayName) eq lc($from_str)) {
		$default = $_->db_id;
		last;
	    }
	}
	unless ($default) {
	    foreach (@{$from_ar}) {
		if ($_->displayName =~ /$from_str/i) {
		    $default = $_->db_id;
		    last;
		}
	    }
	}
    }
    print $self->cgi->textfield(-name => 'FROM', -size => 40);
    if (@{$values_ar}) {
	print $self->cgi->br,
	$self->cgi->popup_menu(-NAME => 'FROM_MENU',
			       -VALUES => $values_ar,
			       -LABELS => $labels_hr,
			       -DEFAULT => $default
			       );
    }
#    print "<BR />\n";
    print qq(</TD></TR>\n<TR><TD>End compound or event name(s)</TD><TD>);

    my $to_ar = [];
    $labels_hr = {};
    $values_ar = [];
    $labels_hr = {};
    $default = undef;
    my ($to_str,$to_op,$to_flag);
    if (my $val = $self->cgi->param('TO')) {
	$to_str = $val;
	($to_op, $val) = $self->_ui_qstr_and_operator_2_mysql($op,$val);

	my %seen;
	@{$to_ar} =
	grep {! $seen{$_->db_id}++}
	grep {&{$filter_function}($_)}
	@{$self->dba->fetch_instance_by_remote_attribute('PhysicalEntity',[['name',$to_op,[$val]],
									   ['output:ReactionlikeEvent','IS NOT NULL',[]]])};

	push @{$to_ar},
	grep {! $seen{$_->db_id}++}
	grep {&{$filter_function}($_)}
	@{$self->dba->fetch_instance_by_remote_attribute('PhysicalEntity',[['_displayName','=',[$to_str]],
									   ['output:ReactionlikeEvent','IS NOT NULL',[]]])};

	push @{$to_ar},
	grep {! $seen{$_->db_id}++}
	grep {&{$filter_function}($_)}
	@{$self->dba->fetch_instance_by_attribute('ReactionlikeEvent',[['name',[$val],$to_op],
							   ['input',[],'IS NOT NULL']])};

	push @{$to_ar},
	grep {! $seen{$_->db_id}++}
	grep {&{$filter_function}($_)}
	@{$self->dba->fetch_instance_by_attribute('ReactionlikeEvent',[['_displayName',[$to_str],'='],
							   ['input',[],'IS NOT NULL']])};

	@{$to_ar} ? $self->cgi->delete('TO') : $self->cgi->param('TO', "not found");

#    } elsif ($val = $self->cgi->param('TO_MENU')) {
#	@{$to_ar} = grep {&{$filter_function}($_)} @{$self->dba->fetch_instance_by_db_id($val)};
    } elsif (my @vals = $self->cgi->param('TO_MENU')) {
	@{$to_ar} = grep {&{$filter_function}($_)}
	@{$self->dba->fetch_instance_by_attribute($self->dba->ontology->root_class, [[$DB_ID_NAME,\@vals]])};
	$to_flag = 1;
    }
#    map {$labels_hr->{$_->db_id} = $_->extended_displayName} @{$to_ar};
    map {$labels_hr->{$_->db_id} = substr($_->extended_displayName,0,100)} @{$to_ar};
#    $values_ar = [map {$_->db_id} sort {length($a->displayName) <=> length($b->displayName)} @{$to_ar}];
    $values_ar = [map {$_->db_id} sort {$a->displayName cmp $b->displayName} @{$to_ar}];
    if ($to_str && (@{$to_ar} > 1)) {
	foreach (@{$to_ar}) {
	    if (lc($_->displayName) eq lc($to_str)) {
		$default = $_->db_id;
		last;
	    }
	}
    }
    print $self->cgi->textfield(-name => 'TO', -size => 40);
#    print $self->cgi->popup_menu(-NAME => 'TO_MENU',
#				 -VALUES => $values_ar,
#				 -LABELS => $labels_hr,
#				 -DEFAULT => $default
#				 );
    if (@{$values_ar}) {
	print $self->cgi->br,
	$self->cgi->scrolling_list(-NAME => 'TO_MENU',
				   -VALUES => $values_ar,
				   -LABELS => $labels_hr,
				   -DEFAULT => $default,
				   -MULTIPLE=> 'true',
				   -SIZE => 5
				   );
    }
    print qq(</TD></TR>\n<TR><TD>Non-connecting compounds and reactions</TD><TD>);

    unless (defined $self->cgi->param('KILL_LIST')) {
	my @default_kill_list = qw(H+ ATP ADP CO2 CoA AMP orthophosphate NAD+ NADH NADP+ NADPH FAD FADH2 H2O GTP GDP UTP);
	my $ar = $self->dba->fetch_instance_by_attribute
	    ('PhysicalEntity',
	     [['name',\@default_kill_list]]);
	$self->cgi->param('KILL_LIST',join("\n", sort {lc($a) cmp lc($b)} map {$_->displayName} @{$ar}));
    }
    my @tmp = $self->cgi->param('KILL_LIST');
    $self->cgi->delete('KILL_LIST');
    $self->cgi->param('KILL_LIST',join("\n",@tmp));
    print $self->cgi->textarea(-NAME => 'KILL_LIST',
			       -ROWS => 5,
			       -COLUMNS => 40,
			       );
    print qq(</TD></TR>\n<TR><TD COLSPAN="2" ALIGN="center">);

    if (!$self->is_decorated()) {
        print $self->cgi->hidden(-name => 'UNDECORATED',-value => '1');
    }
    print $self->cgi->submit(-NAME => 'SUBMIT', -VALUE => 'Go!');
    print qq(</TD></TR>\n</TABLE></DIV>\n);

#    print $self->cgi->end_form();
    if (@{$from_ar} == 1 and (@{$to_ar} == 1 or $to_flag)) {
	my $kill_list = [];
	my (@name_list,@db_id_list);
	my @tmp = $self->cgi->param('KILL_LIST');
	foreach (map {split /\n+/, $_} @tmp) {
	    s/(^\s+|\s+$)//g;
	    if (/^\d+$/) {
		#print qq(<PRE>id\t$_</PRE>\n);
		push @db_id_list, $_;
	    } else {
		#print qq(<PRE>name\t$_</PRE>\n);
		push @name_list, $_;
	    }
	}
	if (@name_list) {
	    $kill_list = $self->dba->fetch_instance_by_attribute($self->dba->ontology->root_class,
								 [['_displayName',\@name_list]]);
	}
	if (@db_id_list) {
	    push @{$kill_list}, @{$self->dba->fetch_instance_by_attribute($self->dba->ontology->root_class,
									  [['DB_ID',\@db_id_list]])};
	}
	my ($path,$instructions) = $self->dba->find_1_directed_path_between_instances
	    (-FROM => $from_ar->[0],
	     -TO => $to_ar,
#	     -TO => $to_ar->[0],
	     -KILL_LIST => $kill_list,
	     -FILTER_FUNCTION => $filter_function);
	if (@{$path}) {
#	    $self->_pathfinder_reactionmap($path);
	    print qq(<DIV CLASS="section">\n<TABLE CELLPADDING="0" WIDTH="$HTML_PAGE_WIDTH" CELLSPACING="2" BORDER="0">\n);
	    print qq(<TR><TH>Found path:</TH></TR>\n);
	    foreach (@{$path}) {
#		my $tmp = '';
#		if ($_->is_a('PhysicalEntity')) {
#		    $tmp = ' CLASS="even"';
#		} elsif ($_->is_a('CatalystActivity')) {
#		    $tmp = ' CLASS="odd"';
#		}
		print
#		    qq(<TR$tmp><TD ID="h_) . $_->db_id . qq(">),
		    qq(<TR CLASS="even"><TD ID="h_) . $_->db_id . qq(">),
		    $self->cgi->checkbox(-name => 'KILL_LIST', -value => $_->db_id, -label => '', -style => 'height:10px;width:10px;'),
		    $_->prettyfy(-URLMAKER => $self->urlmaker,
				 -SUBCLASSIFY => 1,
				 -CGI => $self->cgi)->hyperlinked_extended_displayName,
		    "</TD></TR>\n";
	    }
	    print qq(</TABLE>\n);
	    print $self->cgi->end_form();
	    print qq(</DIV>\n);
	    $self->_pathfinder_reactionmap($path);
	    my @events = grep {$_->is_a('Event')} @{$path};
	    print qq(<DIV CLASS="section"><TABLE CELLPADDING="0" WIDTH="$HTML_PAGE_WIDTH" CELLSPACING="2" BORDER="0"><TR><TD CLASS="viewswitch">) . GKB::Utils::InstructionLibrary::taboutputter_popup_form(@events) . qq(</TD></TR></TABLE></DIV>\n);
#	    print qq(</TABLE>\n);
#	    my @events = grep {$_->is_a('Event')} @{$path};
#	    $self->_print_applet_tag(\@events,$kill_list,$taxon);
	} else {
	    print $self->cgi->end_form();
	    print qq(</DIV>\n);
	    print qq(<DIV CLASS="section">\n<DIV CLASS="nothingfound">No path found</DIV>\n);
	}
    }
}

sub _pathfinder_reactionmap {
    my ($self,$ar) = @_;
    my $cgi = $self->cgi;
    my @reactions = grep {$_->is_a('Event')} @{$ar};
    my $rm = new GKB::ReactionMap(-DBA => $self->dba,-CGI => $cgi);
    $rm->set_reaction_color(200,0,0,\@reactions);
    my %reaction2connector;
    foreach my $j (0 .. $#{$ar}) {
	my $i = $ar->[$j];
	if ($i->is_a('Event') && ($j < $#{$ar})) {
	    $reaction2connector{$i->db_id} = $ar->[$j + 1];
	}
    }
    my %instructions =
	(-INSTRUCTIONS =>
	 {'Reaction' => {'attributes' => [qw(orthologousEvent)], 'reverse_attributes' => [qw(locatedEvent)]}},
	 -OUT_CLASSES => ['ReactionCoordinates']
	);
    my @coordinates;
    my $connector;
    foreach my $r (@reactions) {
	my $rcs = $r->follow_class_attributes(%instructions);
	@{$rcs} || next;
	if (@coordinates) {
	    if ($connector) {
		push @{$coordinates[-1]}, ($rcs->[0]->SourceX->[0], $rcs->[0]->SourceY->[0], $connector->db_id, $connector->displayName);
	    } else {
		push @{$coordinates[-1]}, ($rcs->[0]->SourceX->[0], $rcs->[0]->SourceY->[0]);
	    }
#	    push @{$coordinates[-1]}, ($rcs->[0]->SourceX->[0], $rcs->[0]->SourceY->[0], $reaction2connector{$r->db_id}->db_id, $reaction2connector{$r->db_id}->displayName);
	}
	push @coordinates, [$rcs->[0]->TargetX->[0], $rcs->[0]->TargetY->[0]];
	$connector = $reaction2connector{$r->db_id}
    }
    pop @coordinates;
    $rm->create_usemap(\@coordinates);
    if (lc($reactions[0]->Species->[0]->displayName) eq 'homo sapiens') {
	$rm->create_image;
    } else {
	$rm->create_image_for_species($reactions[0]->Species->[0]);
    }
    $rm->draw_as_lines(\@coordinates, $rm->get_rgb_color(0,255,0));
    my $name = rand() * 1000 . $$ . '.png';
    open(OUT, ">$GK_TMP_IMG_DIR/$name") || $self->throw("Can't create '$GK_TMP_IMG_DIR/$name': $!");
    binmode OUT;
    print OUT $rm->image->png;
    close OUT;
    $rm->create_usemap;
    print <<__END__;
<script language="JavaScript">
<!--
var previousBg;
var currentInstanceId;

function handleClick2(form_id,id,e) {
    if (id) {
	document.reactionmap.ID.value = id;
    }
    document.reactionmap.submit();
    return false;
}

function handleMouseOver(instance_id,tip_label,tip_bg,tip_width) {
    ddrivetip(tip_label,tip_bg,tip_width);
    currentInstanceId = instance_id;
    var el;
    if (el = document.getElementById("h_" + instance_id)) {
	previousBg = el.style.backgroundColor;
	el.style.backgroundColor = "#DCDCDC";
    }
}

function handleMouseOut() {
    hideddrivetip();
    if (currentInstanceId) {
	var el;
	if (el = document.getElementById("h_" + currentInstanceId)) {
	    el.style.backgroundColor = previousBg;
	}
    }
}
-->
</script>
__END__
    print
	qq(<DIV CLASS="section">\n<TABLE CLASS="reactionmap" ALIGN="center" CELLSPACING="0">) .
	$cgi->start_form(-method =>'POST',-name =>"reactionmap",-action=>'/cgi-bin/eventbrowser') .
	$cgi->hidden(-name => 'DB',-value => $cgi->param('DB')) .
	qq(<INPUT TYPE="hidden" NAME="ZOOM" VALUE="2" />) .
	qq(<INPUT TYPE="hidden" NAME="ID" VALUE="" />) .
	qq(<TR><TD>) .
	qq(<MAP NAME="img_map">) . $rm->usemap . qq(</MAP>) .
	qq(<IMG ID="rm_image" USEMAP="\#img_map" BORDER="0" SRC="/img-tmp/$name">) .
	qq(</TD></TR>) .
        $cgi->end_form .
	qq(</TABLE>\n</DIV>\n);
}

sub _print_applet_tag {
    my ($self,$instances,$kill_list,$taxon) = @_;
    my $kill_list_str = join(",", map {$_->db_id} @{$kill_list});
    my $instances_str = join(",", map {$_->class . ':' . $_->db_id} @{$instances});
    my $taxon_str = ($taxon) ? qq( TAXON=") . $taxon->db_id . qq(") : '';
    my $db = $self->cgi->param('DB');
    my $servername = ($self->cgi->remote_addr eq '127.0.0.1')
	? '127.0.0.1'
	: $self->cgi->server_name;
#    my $fetch_script_url = "http://" . $self->cgi->server_name . ":" . $self->cgi->server_port . "$GKB::Config::GK_FETCH_SCRIPT";
    my $fetch_script_url = "http://$servername:" . $self->cgi->server_port . "$GKB::Config::GK_FETCH_SCRIPT";
#    my $fetch_script_url = "http://127.0.0.1:" . $self->cgi->server_port . "$GKB::Config::GK_FETCH_SCRIPT";
    print qq(<APPLET CODE="ViewerAppButtonApplet" WIDTH="800" HEIGHT="20" CODEBASE="/jars" ARCHIVE="viewerapp.jar,jgraph.jar" INSTANCES="$instances_str" DATABASE="$db" UBIQUITOUS="$kill_list_str" FETCHSCRIPTURL="$fetch_script_url"$taxon_str>"Sorry, your browser can't display applets"</APPLET>);

    print qq(<P><SMALL>The graphical display of the path requires your browser to have a java (version 1.3) plugin and does not work with Netscape 4.x.</SMALL></P>\n);

}

=head
sub find_focus_species {
    my ($self,$instance) = @_;
#    if (exists $self->{'focus_species'}) {
#	return $self->{'focus_species'};
#    }
    my $focus;
    if ($instance->is_valid_attribute('taxon') && $instance->Taxon->[0]) {
	$focus = $instance->Taxon->[0];
    }
    elsif ($instance->is_valid_attribute('species') && $instance->Species->[0]) {
	$focus = $instance->Species->[0];
    }
    elsif (my $name = $self->cgi->param('FOCUS_SPECIES')) {
	if (my $i = $self->dba->fetch_instance_by_attribute('Species',[['name',[$name]]])->[0]) {
	    $focus = $i;
	}
    }
#    return $self->{'focus_species'} = $focus;
    return $focus;
}
=cut

sub get_focus_species {
    my $self = shift;
    my $focus_species = GKB::Utils::find_focus_species_or_default($self->dba,$self->cgi,@_);

    # If $focus_species is not in the list of species known to the frontpage,
    # we need to find a plausible alternative.
    eval {
	    my @frontpage_species_names = map {$_->displayName} @{$self->dba->fetch_frontpage_species()};
	    if (scalar(@frontpage_species_names)>0) {
		    my $focus_species_in_frontpage = 0;
		    foreach my $species_name (@frontpage_species_names) {
		    	if ($species_name eq $focus_species->[0]->_displayName->[0]) {
		    		$focus_species_in_frontpage = 1;
		    		last;
		    	}
		    }
		    if (!$focus_species_in_frontpage) {
		    	$focus_species = $self->dba->fetch_frontpage_species();
		    }
	    }
    };

    return $focus_species;
# Shouldn't cache the value for the time being.
#    unless (exists $self->{'focus_species'}) {
#	$self->{'focus_species'} = GKB::Utils::find_focus_species_or_default($self->dba,$self->cgi,@_);
#    }
#    return $self->{'focus_species'};
}

sub get_focus_species_by_id {
    my $self = shift;
    return GKB::Utils::find_focus_species_by_id($self->dba,$self->cgi,@_);
}

sub categorise_instances {
    my ($self,$ar) = @_;
    my (@groups,%h);
    my $qc = $self->cgi->param('QUERY_CLASS');
    if ($qc && ($qc ne $self->dba->ontology->root_class)) {
	push @groups, $qc, $self->dba->ontology->descendants($qc);
	foreach my $c (@groups) {
	    my @tmp = ();
	    $h{$c} = \@tmp;
	}
    } else {
	@groups = sort {$a cmp $b}
#    grep {$_ !~ /^_/}
#    grep {$_ ne 'InstanceEdit'}
	grep {$_ ne 'Event'}
	$self->dba->ontology->children($self->dba->ontology->root_class);
	if ($self->dba->ontology->is_valid_class('Event')) {
	    push @groups, $self->dba->ontology->children('Event');
	}
	foreach my $c (@groups) {
	    my @tmp = ();
	    $h{$c} = \@tmp;
	    foreach my $d ($self->dba->ontology->descendants($c)) {
		$h{$d} = \@tmp;
	    }
	}
    }
    foreach my $i (@{$ar}) {
	push @{$h{$i->class}}, $i;
    }
    @groups  = grep {@{$h{$_}}} @groups;
    my %tmp; map {$tmp{$_}++} @groups;
    foreach my $k (keys %h) {
	unless ($tmp{$k}) {
	    delete $h{$k};
	}
    }
    return \%h;
}

sub print_category_count {
    my ($self,$ar) = @_;
    my $hr = $self->categorise_instances($ar);
    my @groups = keys %{$hr};
    print qq(<TABLE WIDTH="$HTML_PAGE_WIDTH" CLASS="categorycount" CELLSPACING="0">\n);
    my $j = 0;
    my $cols = 3;
    my $icount = scalar(@{$ar});
    if ($cols > @groups) {
	$cols = scalar(@groups);
    }
    print qq(<TR><TH COLSPAN="$cols">Found <B>$icount</B> matches in following categories:</TH></TR>\n);

    my $form_action;
    if ($self->urlmaker->script_name eq '/cgi-bin/instancebrowser') {
	$form_action = '/cgi-bin/instancebrowser';
    } else {
	$form_action = '/cgi-bin/eventbrowser';
    }
    for (my $n = 0; $n < @groups; $n += $cols) {
	print qq(<TR>\n);
	foreach my $m (0 .. $cols - 1) {
	    print qq(<TD>);
	    if (my $gname = $groups[$n + $m]) {
		my $group_members = $hr->{$gname};
#		if (scalar(@{$group_members}) == 1) {
#		    print $gname, ': ', $group_members->[0]->prettyfy(-URLMAKER => $self->urlmaker)->hyperlinked_string(1);
#		} else {
		    my $form_name = 'form_' . ($n + $m);
		    print $self->cgi->start_form(-action => $form_action, -method => 'POST', -name => $form_name, -target => "_blank");
		    print $self->cgi->hidden(-name => 'DB', -value => $self->dba->db_name('DB'));
		    my $format = (scalar(@{$group_members}) > 1) ? 'list' : '';
		    print $self->cgi->hidden(-name => 'FORMAT', -value => $format);
		    $self->cgi->delete('ID');
		    print $self->cgi->hidden(-name => 'ID', -value => [map {$_->db_id} @{$group_members}]);
		    print $gname, ': ', qq(<A ONCLICK="document.$form_name.submit(); return false">),  scalar(@{$group_members}), qq(</A>);
		    print $self->cgi->end_form;
#		}
	    } else {
		print '&nbsp;';
	    }
	    print qq(</TD>\n);
	}
	print qq(</TR>\n\n);
    }

    print qq(</TABLE>\n);
}

sub print_category_count_as_text {
    my ($self,$ar) = @_;
    $ar ||= $self->fetch_simple_query_form_instances;
    my $hr = $self->categorise_instances($ar);
    while (my ($category, $group_members) = each %{$hr}) {
	print join("\t", ($category, scalar(@{$group_members}), join(',', map {$_->db_id} @{$group_members}))), "\n";
    }
}

=head
sub fetch_Events_by_identifiers_from_dn_db {
    my ($self,$ar) = @_;
    eval {
	require GKB::Config;
	require GKB::ReactomeDBAdaptor;
	$dndba = GKB::DBAdaptor->new
	    (
	     -dbname => $self->dba->db_name . '_newdn',
	     -user   => $GK_DB_USER,
	     -host   => $GK_DB_HOST,
	     -pass   => $GK_DB_PASS,
	     -port   => $GK_DB_PORT,
	    );
	foreach my $i (@{$ar}) {

	}
    };
    if ($@) {
	print qq(<PRE>$@</PRE>\n);
    }
    return $ar;
}
=cut

sub print_instance_name_list {
    my ($self,$ar,$subclassify) = @_;
#    my $out;
#    require IO::String;
#    my $io = IO::String->new($out);
#    my $current_fh = select($io);
    print qq(<DIV CLASS="section"><TABLE WIDTH="$HTML_PAGE_WIDTH" CLASS="instancebrowser" CELLSPACING="0">\n);
    my $icount = scalar(@{$ar});
    print qq(<TR><TH>Found <B>$icount</B> matches:</TH></TR>\n<TR><TD>);
    print $self->cgi->start_form(-action => '/cgi-bin/eventbrowser', -name => 'checklist');
    print $self->cgi->hidden(-name => 'DB',-value => $self->cgi->param('DB')), "\n";
#    foreach my $i (sort {lc($a->displayName) cmp lc($b->displayName)} @{$ar}) {
    $self->cgi->delete('ID');
    print check_uncheck_javascript();
    print
	$self->cgi->button(-value => 'Check all', -onClick => 'checkAll(document.checklist.ID)'),
	$self->cgi->button(-value => 'Uncheck all', -onClick => 'uncheckAll(document.checklist.ID)'),
	$self->cgi->button(-value => 'View selected instances', -onClick => 'checkFormAndSubmit(document.checklist, document.checklist.ID)');
#	$self->cgi->submit(-name => "SUBMIT", -value => 'View selected instances');
    print " as ";
    $self->cgi->delete('FORMAT');
    my $default_format = $self->cgi->cookie('format') || 'list';
    print $self->cgi->popup_menu
	(-name => 'FORMAT',
	 -values => [
#	             'eventbrowser',
		     'instancebrowser',
		     'htmltable',
		     'sectioned',
	             'sidebarwithdynamichierarchy',
		     'list',
	             'custom'
		     ],
	 -labels => {
	     'list' => 'list of display names',
	     'instancebrowser' => 'attribute <-> value pairs',
	     'eventbrowser' => 'seen in original eventbrowser',
	     'htmltable' => 'one big table',
	     'sectioned' => 'seen on a sectioned page',
	     'sidebarwithdynamichierarchy' => 'event hierarchy in the side bar',
	     'custom' => 'custom table'
	     },
	 -default => $default_format,
	 -onChange => 'setOutputInstructionsVisibility(document.checklist)'
	 );
    print qq(<DIV ID="outputinstructions" STYLE="display:none;">),
    qq(Specify the the attributes, one per line, the values of which you want included in the output. Values which are instances are reported as class name:internal identifier (DB_ID) pairs, e.g. <TT>ReferenceDatabase:2</TT>. Attribute values of those instances can be accessed by appending dot and attribute name to the 1st attribute name, e.g. <TT>input._displayName</TT>. Multiple values of the same attribute are concatenated with <TT>|</TT> in TSV and with <TT>&lt;BR \/&gt;</TT> in HTML format. If you want to access only a single value of a multi-value attribute, append the index of this value in square brackets to the attribute name, e.g. <TT>name[0]</TT>.<BR />),
    $self->cgi->textarea(-name => 'OUTPUTINSTRUCTION',
			 -rows => 3,
			 -columns => 50,
			 -default => ""),
    '<BR />',
    'Results table in ', $self->cgi->popup_menu(-NAME => 'TABLEFORMAT', -VALUES => ['TSV','HTML'], -DEFAULT => 'TSV'), ' format'.
    qq(</DIV>\n);
#    print qq(<script language="JavaScript">\nsetOutputInstructionsVisibility(document.checklist)\n</script>\n);
    foreach my $i (@{$ar}) {
	print
	    qq(<BR />),
	    $self->cgi->checkbox(-name => 'ID', -value => $i->db_id, -label => '') .
	    $i->prettyfy(
			 -URLMAKER => $self->urlmaker,
			 -SUBCLASSIFY => $subclassify,
			 -WEBUTILS => $self
			 )->hyperlinked_displayName, qq(\n);
    }
    print $self->cgi->end_form, "\n";
    print qq(</TD></TR></TABLE></DIV>\n);
#    select($current_fh);
#    print $out;
}

sub print_instance_attribute_value_table {
    my ($self,$ar) = @_;
    my (%classes,%atts,%rev_atts);
    foreach my $i (@{$ar}) {
	next if ($classes{$i->class}++);
	map {$atts{$_}++} $i->list_valid_attributes;
	map {$rev_atts{$_}++} $i->list_valid_reverse_attributes;
    }
    delete $atts{'DB_ID'};
    my @atts = sort {$a cmp $b} grep {$_ !~ /^_/} keys %atts;
    my @rev_atts = sort {$a cmp $b} keys %rev_atts;
    print qq(<TABLE CLASS="instancebrowser">\n);
    print qq(<TR>), join('', map {qq(<TH>$_</TH>)} ('Display name','Class','DB_ID',@atts,map {"($_)"} @rev_atts)), qq(</TR>\n);
#    foreach my $i (sort {lc($a->displayName) cmp lc($b->displayName)} @{$ar}) {
    foreach my $i (@{$ar}) {
	print
	    qq(<TR><TD>),
	    $i->prettyfy(-URLMAKER => $self->urlmaker,
			 -SUBCLASSIFY => 1,
			 -WEBUTILS => $self)->hyperlinked_displayName,
	    qq(</TD><TD>),
	    $i->class,
	    qq(</TD><TD>),
	    $i->db_id,
	    qq(</TD>);
	foreach my $att (@atts) {
	    print qq(<TD>);
	    if ($i->is_valid_attribute($att)) {
		if (my @v = @{$i->attribute_value($att)}) {
		    if ($i->is_instance_type_attribute($att)) {
			print join('<P />',
				   map {$_->prettyfy(-URLMAKER => $self->urlmaker,
						     -WEBUTILS => $self)->hyperlinked_displayName}
				   @v);
		    } else {
			print join('<BR />', @v);
		    }

		} else {
		    print '&nbsp;'
		    }
	    } else {
#		print '&nbsp;'
	    }
	    print qq(</TD>);
	}
	foreach my $rev_att (@rev_atts) {
	    print qq(<TD>);
	    if ($i->is_valid_reverse_attribute($rev_att)) {
		if (my @v = @{$i->reverse_attribute_value($rev_att)}) {
		    print join('<P />',
			       map {$_->prettyfy(-URLMAKER => $self->urlmaker,
						 -WEBUTILS => $self)->hyperlinked_displayName}
			       @v);
		} else {
		    print '&nbsp;'
		    }
	    } else {
#		print '&nbsp;'
	    }
	    print qq(</TD>);
	}
	print qq(</TR>\n);
    }
    print qq(</TABLE>\n);
}

sub check_uncheck_javascript {
return <<__END__;
<script language="JavaScript">

    function checkAll(field) {
	if (field.length) {
	    for (var i = 0; i < field.length; i++) {
		field[i].checked = true;
	    }
	} else {
	    field.checked = true;
	}
    }

    function uncheckAll(field) {
	if (field.length) {
	    for (var i = 0; i < field.length; i++) {
		field[i].checked = false ;
	    }
	} else {
	    field.checked = false ;
	}
    }

    function checkFormAndSubmit(form,field) {
	var checked = false;
	if (field.length) {
	    for (var i = 0; i < field.length; i++) {
		if (field[i].checked) {
		    checked = true;
		    break;
		}
	    }
	} else {
	    if (field.checked) {
		checked = true;
	    }
	}
	if (checked) {
	    if (form.FORMAT.value == "custom") {
		form.action = "/cgi-bin/taboutputter";
//		form.method = "GET";
	    } else if (form.FORMAT.value == "instancebrowser") {
		form.action = "/cgi-bin/instancebrowser";
	    }
	    form.submit();
	} else {
	    alert("You haven't chosen any records to display.");
	}
    }

    function setOutputInstructionsVisibility(form) {
	if (form.FORMAT.value == "custom") {
	    div = document.getElementById("outputinstructions");
	    div.style.display = 'block';
	} else {
	    div = document.getElementById("outputinstructions");
	    div.style.display = 'none';
	}
    }
</script>
__END__
}

sub get_db_connection {
    my $cgi = shift || confess("Need CGI");

    require GKB::ReactomeDBAdaptor;
    my $db = $cgi->param('DB') || $GKB::Config::GK_DB_NAME;
    $db =~ /^(\w+)$/;
    $db = $1;
    $cgi->param('DB',$db);

    return GKB::ReactomeDBAdaptor->new
	(
	 -dbname => $db,
	 -user   => $GK_DB_USER,
	 -host   => $GK_DB_HOST,
	 -pass   => $GK_DB_PASS,
	 -port   => $GK_DB_PORT,
	 -debug  => $cgi->param('DEBUG') ? $cgi->param('DEBUG') : undef
	);
}

sub untaint_DB_and_ID {
    my $cgi = shift;
    my $db = $cgi->param('DB') || $GKB::Config::GK_DB_NAME;
    if ($db =~ /^(\w+)$/) {
	$db = $1;
	$cgi->param('DB',$db);
    } else {
	confess("The value - $db - of parameter DB is not kosher.");
    }
    if (my @ids = $cgi->param('ID')) {
	my @tmp;
	foreach my $id (@ids) {
	    if ($id =~ /^(\d+)$/) {
		push @tmp, $1;
	    } else {
		confess("The value - $id - of parameter ID is not kosher.");
	    }
	}
	$cgi->param('ID',@tmp);
    }
}

# returns open handle and path relative to server document root.
sub get_tmp_img_file {
    my $self = shift;
    my $name = rand() * 1000 . $$ . '.png';
    open(OUT, ">$GK_TMP_IMG_DIR/$name") || $self->throw("Can't create '$GK_TMP_IMG_DIR/$name': $!");
    binmode OUT;
    return \*OUT, "/img-tmp/$name";
}

sub get_format_from_cookie {
    my $cgi = shift;
    if (my $format = $cgi->cookie('format')) {
	return $format;
    }
    return;
}

sub get_format {
    my $cgi = shift;
    my $cgi_format = $cgi->param('FORMAT');
    my $cookie_format = get_format_from_cookie($cgi);
    my $config_format = $GKB::Config::DEFAULT_VIEW_FORMAT;
    my $format = $cgi_format || $cookie_format || $config_format;

#    # Diagnostics
#    if (!(defined $cgi_format)){
#    	$cgi_format = "";
#    }
#    if (!(defined $cookie_format)){
#    	$cookie_format = "";
#    }
#    if (!(defined $config_format)){
#    	$config_format = "";
#    }
#    print STDERR "WebUtils.get_format: cgi_format=$cgi_format, cookie_format=$cookie_format, config_format=$config_format, format=$format\n";

    return $format;
}

sub set_cgi_format_parameter_if_unset {
    my $cgi = shift;
    unless ($cgi->param('FORMAT')) {
	my $format = get_format_from_cookie($cgi) || $GKB::Config::DEFAULT_VIEW_FORMAT;
	$cgi->param('FORMAT',$format);
    }
}

sub print_userdefined_view {
    my ($self,$ar) = @_;
    my @instructions = split(/\r\n|\n\r|\r|\n|,/,$self->cgi->param('OUTPUTINSTRUCTIONS'));
#    print "<PRE>\n";
    GKB::Utils::print_values_according_to_instructions($ar,\@instructions);
#    print "</PRE>\n";
}

sub _valid_operators_for_db {
    my $dba = shift;
    if ($dba->fetch_root_class_table_type eq 'innodb') {
	return [
	    'EXACT',
	    'REGEXP',
	    '!=',
	    'IS NULL',
	    'IS NOT NULL'
	];
    } else {
	return [
	    'EXACT',
	    'REGEXP',
	    'ALL',
	    'ANY',
	    'PHRASE',
	    '!=',
	    'IS NULL',
	    'IS NOT NULL'
	    ];
    }
}

sub focus_species_changes1 {
    my ($self, $i) = @_;
    if ($i->is_a("Event")) {
	my $current_fs = GKB::Utils::find_focus_species($self->dba,$self->cgi);
	foreach my $sp (@{$current_fs}) {
	    if (grep {$sp == $_} @{$i->Species}) {
		return undef;
	    }
	}
	return 1;
    }
    return undef;
}

sub focus_species_changes {
    my ($self, $i) = @_;
    if ($i->is_valid_attribute('species') && $i->Species->[0]) {
	my $current_fs = GKB::Utils::find_focus_species_by_id($self->dba,$self->cgi);
	if ($current_fs == $i->Species->[0]) {
	    return undef;
	}
	my %ins = (
	    -INSTRUCTIONS => {
		'Event' => {'reverse_attributes' => [qw(hasEvent)]},
		'PhysicalEntity' => {'reverse_attributes' => [qw(hasComponent hasMember hasCandidate repeatedUnit input output physicalEntity regulator)]},
		'CatalystActivity' => {'reverse_attributes' => [qw(catalystActivity)]},
		'Regulation' => {'reverse_attributes' => [qw(regulatedBy)]}
	    },
	    -OUT_CLASSES => [qw(Event)]
	    );
	my $ar = $i->follow_class_attributed(%ins);
	foreach my $e (@{$ar}) {
	    if ($current_fs == $e->Species->[0]) {
		return undef;
	    }
	}
	return 1;
    }
    return undef;
}

# Uses an HTML form to force a new page to open with the given
# URL.  This has the advantage over CGI->redirect() that it will
# work even if it is used when a page header has already been
# written.  It relies on the user's browser supporting Javascript.
sub form_redirect {
    my ($self, $url) = @_;

	my $tool = "WebUtils";
    my $form = <<__HERE__;
<form target="_top" id="$tool" name="$tool" enctype="multipart/form-data" action="$url" method="post"></form>
<script type="text/javascript">
	document.forms['$tool'].submit('Check in');
</script>

__HERE__

    print $form;
}

sub form_redirect_debug {
    my ($self, $url) = @_;

        my $tool = "WebUtils";
    my $form = <<__HERE__;
<form target="_blank" id="$tool" name="$tool" enctype="multipart/form-data" action="$url" method="post"></form>
<script type="text/javascript">
        document.forms['$tool'].submit('Check in');
</script>

__HERE__

    return $form;
}


# Takes an array of arrays of META tag descriptions (see Config->$GLOBAL_META_TAGS
# for an example of what these look like).  Returns an array of CGI compliant
# meta objects, that can be directly implanted into CGI->start_html(-head => [...])
sub meta_tag_builder {
    my ($self, $meta_tag_array) = @_;

    my $logger = get_logger(__PACKAGE__);

    my @cgi_meta_descriptors = ();
    if (!(defined $meta_tag_array)) {
    	return @cgi_meta_descriptors;
    }

    my $cgi = $self->cgi;
    if (!(defined $cgi)) {
    	return @cgi_meta_descriptors;
    }

    foreach my $meta_descriptor_pair (@{$meta_tag_array}) {
    	if (!(defined $meta_descriptor_pair)) {
    	    $logger->warn("META tag description pair is undefined, skipping!!\n");
    	    next;
    	}
	if (scalar(@{$meta_descriptor_pair}) != 2) {
	    $logger->warn("malformed META tag description pair, contains " . scalar(@{$meta_descriptor_pair}) . " elements, expected 2, skipping!!\n");
	    next;
	}
	my $name = $meta_descriptor_pair->[0];
	my $content = $meta_descriptor_pair->[1];
	my $cgi_meta_descriptor = $cgi->meta({'name'=>$name, 'content'=>$content});

	push(@cgi_meta_descriptors, $cgi_meta_descriptor);
    }

    return @cgi_meta_descriptors;
}

# Creates an array of CGI compliant
# meta objects, that can be directly implanted into CGI->start_html(-head => [...])
# for the instance with the given DB_ID.
sub instance_meta_tag_builder {
    my ($self, $db_id) = @_;

    my @cgi_meta_descriptors = ();
    if (!(defined $db_id)) {
	return @cgi_meta_descriptors;
    }

    my $cgi = $self->cgi;
    my $dba = $self->dba;
    if (!(defined $cgi) || !(defined $dba)) {
	return @cgi_meta_descriptors;
    }

    my $instances = $dba->fetch_instance_by_db_id($db_id);
    if (scalar(@{$instances}) == 0) {
	return @cgi_meta_descriptors;
    }
    my $instance = $instances->[0];
    if (!(defined $instance)) {
	return @cgi_meta_descriptors;
    }

    my $description_cgi_meta_descriptor = $cgi->meta({'name'=>"description", 'content'=>$instance->displayName()});
    push(@cgi_meta_descriptors, $description_cgi_meta_descriptor);

    # Get the keywords from the appropriate attribute, if it exists.
    if ($instance->is_valid_attribute("keywords")) {
	my $keywordss = $instance->attribute_value("keywords");
	if (scalar(@{$keywordss}) > 0) {
	    my $keywords = $keywordss->[0];
	    if (defined $keywords && !($keywords eq "")) {
		my $keywords_cgi_meta_descriptor = $cgi->meta({'name'=>"keywords", 'content'=>$keywords});
		push(@cgi_meta_descriptors, $keywords_cgi_meta_descriptor);
	    }
	}
    }

    # Only allow crawlers to index this instance if it is an Event.
    # Don't allow crawlers to index non-human events
    if (!($instance->is_a("Event")) || scalar(@{$instance->inferredFrom})>0) {
	my $robots_noindex_meta_descriptor = $cgi->meta({'name'=>"robots", 'content'=>'noindex,nofollow'});
	push(@cgi_meta_descriptors, $robots_noindex_meta_descriptor);
    }

#	# Emergency hack to stop search engines from indexing eventbrowser pages
#	my $robots_noindex_meta_descriptor = $cgi->meta({'name'=>"robots", 'content'=>'noindex,nofollow'});
#	push(@cgi_meta_descriptors, $robots_noindex_meta_descriptor);

    return @cgi_meta_descriptors;
}

# Check to see if it is OK for a caller to access the current web page.
# If it is OK, then return undef.  If it is not OK, return a string
# containing HTML that can be printed to provide a warning.
sub forbid_page_access {
    my ($self) = @_;

    my $logger = get_logger(__PACKAGE__);

    my $dba = $self->dba;
    if (!(defined $self->cgi) || !(defined $dba)) {
	return "Cannot access page data or database\n";
    }

    # Get the number of open database connections.  This uses the MySQL
    # "status" command; use the number of "threads".
    my ($sth,$res) = $dba->execute("show status like 'Threads_connected'");
    my $connections = $sth->fetchall_arrayref->[0]->[1];
    if (!(defined $connections)) {
	$connections = 1;
    }

    my $error_message = "Sorry, there is a temporary technical problem (too many database connections: $connections), please refresh this page again in a few minutes.";
    my $out = qq(<h1 CLASS="frontpage"><FONT COLOR="RED">Internal error</FONT></h1>\n);
    $out .= qq(<PRE>\n\n\n$error_message\n\n</PRE>\n);

    if ($connections > 145) {
	# We are getting close to the default upper limit of 150 database
	# connections in MySQL, don't allow any more.
	$logger->warn("WebUtils.forbid_page_access: connections=$connections, forbidding server=" . $self->cgi->remote_host() . "\n");
	return $out;
    } elsif ($connections > 120 && $self->remote_host_isa_search_indexer()) {
	# A lot of database connections have now been used up, so stop crawlers
	# from accessing this web page.  Allow normal users to do what they
	# want.
	$logger->warn("WebUtils.forbid_page_access: connections=$connections, forbidding crawler=" . $self->cgi->remote_host() . "\n");
	return $out;
    } elsif ($connections > 50 && $self->remote_host_isa_search_indexer()) {
	# There are still enough database connections to serve crawlers, but it looks
	# like a lot have been used already, so put in a delay to slow the crawler
	# down.
	$logger->warn("WebUtils.forbid_page_access: connections=$connections, delaying crawler=" . $self->cgi->remote_host() . "\n");
	sleep(5);
    }

    # The "everything is fine" return value
    return undef;
}

sub remote_host_isa_search_indexer {
    my ($self) = @_;

    my $cgi = $self->cgi;
    my $remote_host = $cgi->remote_host();

    # Google
    if	($remote_host =~ /google/i || $remote_host =~ /^66.249.6[56]/) {
    	return 1;
    }

    # MSN
    if	($remote_host =~ /msn/i || $remote_host =~ /^65.5[45]/) {
    	return 1;
    }

    # Yahoo
    if	($remote_host =~ /slurp/i || $remote_host =~ /yahoo/i || $remote_host =~ /inktomi/i) {
    	return 1;
    }

    # Altavista
    if	($remote_host =~ /scooter/i || $remote_host =~ /alta-*vista/i) {
    	return 1;
    }

    # Excite
    if	($remote_host =~ /excite/i) {
    	return 1;
    }

    # Lycos
    if	($remote_host =~ /lycos/i) {
    	return 1;
    }

    # Dotnet
    if	($remote_host =~ /dotnetdotcom/i) {
	return 1;
    }

    # PHONOSCOPE
    if ($remote_host =~ /PHONOSCOPE/i || $remote_host =~ /^72.20.139/) {
	return 1;
    }

    return 0;
}

1;
