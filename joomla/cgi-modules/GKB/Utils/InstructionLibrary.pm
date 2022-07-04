package GKB::Utils::InstructionLibrary;

use strict;
use vars qw(@ISA @EXPORT $XML_FORCEARRAY);
use Exporter;
use Carp;
use GKB::Config;
use XML::Simple;
use Data::Dumper;
use Carp;
@ISA = qw(Exporter);

$XML_FORCEARRAY = [qw(attributes reverse_attributes INSTRUCTION CLASS FOLLOWINGINSTRUCTION OUTPUTCLASS OUTPUTINSTRUCTION OUTPUTCONDITION)];

@EXPORT = qw($XML_FORCEARRAY);

sub get_instruction_id_and_desc_for_class {
    my ($cls) = @_;
    my $library = get_library_file();
    my @libraryresults;
    my $h = XMLin($library, ForceArray => $XML_FORCEARRAY);
    foreach my $elem (@{$h->{'INSTRUCTION'}}){
	foreach my $class (@{$elem->{CLASS}}){
	    if($class eq $cls){
		push @libraryresults, [$elem->{'ID'}, $elem->{DESCRIPTION}];

	    }
	}
    }
    return \@libraryresults;
}

sub get_instructions_for_class {
    my ($cls) = @_;
    my $library = get_library_file();
    my @out;
    my $h = XMLin($library, ForceArray => $XML_FORCEARRAY);
    foreach my $elem (@{$h->{'INSTRUCTION'}}){
	foreach my $class (@{$elem->{CLASS}}){
	    if($class eq $cls){
		push @out, $elem;
	    }
	}
    }
    return \@out;
}

sub get_instructions_for_classes {
    my (@clss) = @_;
    my %classes;
    map {$classes{$_}++} @clss;
    my $library = get_library_file();
    my @out;
    my $h = XMLin($library, ForceArray => $XML_FORCEARRAY);
    foreach my $elem (@{$h->{'INSTRUCTION'}}){
	foreach my $class (@{$elem->{CLASS}}){
	    if($classes{$class}){
		push @out, $elem;
	    }
	}
    }
    return \@out;
}

sub get_instruction_by_id {
    my $id = shift;
    my $library = get_library_file();
    my $h = XMLin($library, ForceArray => $XML_FORCEARRAY);
    foreach my $elem (@{$h->{'INSTRUCTION'}}){
	if ($elem->{'ID'} eq $id) {
	    return $elem;
	}
    }
    return;
}

sub get_instruction_from_string {
    my $str = shift;
    my $h = XMLin($str, ForceArray => $XML_FORCEARRAY);
    return $h;
}

sub check_instruction {
    my $instruction = shift;

    if (!(defined $instruction)) {
		die("Undefined instruction\n");
    }

    # No instructions should not be a failure condition
    if (scalar(keys(%{$instruction}))==0) {
    	return;
    }

    unless ($instruction->{'FOLLOWINGINSTRUCTION'} ||
	    $instruction->{'OUTPUTCLASS'} ||
	    $instruction->{'OUTPUTINSTRUCTION'} ||
	    $instruction->{'OUTPUTCONDITION'}
	) {
		die("Badly formed instruction:\n" . Dumper($instruction));
    }
}

sub get_library_file
{
    # When Reactome runs in a container, *this* is the correct path to the instructionlibrary
    return '/var/www/html/cgi-modules/instructionlibrary.xml';
}

sub taboutputter_popup_form1 {
    my $i = shift;
    my $instructions = get_instructions_for_class($i->class);
    @{$instructions} || return '';
    my $form_name = 'taboutputter_form_' . $i->db_id;
    # This is a truely twisted way of doing things. The problem is that forms for some reason get a "newline"
    # inserted before and after them. Hence they won't be on the same line with teh preceding text, which is
    # what I want. Hence the trickery of using an "orphan" popup menu with invisible form followwing it.
    # Not nice. Should be replaced with js menu.
    my $out = qq(\n<select onchange="document.$form_name.INSTRUCTIONID.value=value;document.$form_name.submit();">\n);
    $out .= qq(\t<option selected="selected" value=""> List ...</option>\n);
    foreach my $instr (@{$instructions}) {
		$out .= qq(\t<option value=") . $instr->{'ID'} . qq(">) . $instr->{'LABEL'} . qq(</option>\n);
    }
    $out .= qq(</select>\n\n);
    $out .=
	qq(<form method="get" action="/cgi-bin/taboutputter" enctype="application/x-www-form-urlencoded" name="$form_name">\n) .
	qq(<input type="hidden" name="DB" value=") . $i->dba->db_name . qq("  />\n).
	qq(<input type="hidden" name="INSTRUCTIONID" value=""  />\n) .
	qq(<input type="hidden" name="ID" value=") . $i->db_id . qq("  />) .
	qq(</form>\n);
    return $out;
}

sub taboutputter_popup_form {
    my @a = @_;
    my %seen;
    map {$seen{$_->class}++} @a;
    my $instructions = get_instructions_for_classes(keys %seen);
    @{$instructions} || return '';
    my $form_name = 'taboutputter_form_' . $a[0]->db_id;
    # This is a truely twisted way of doing things. The problem is that forms for some reason get a "newline"
    # inserted before and after them. Hence they won't be on the same line with teh preceding text, which is
    # what I want. Hence the trickery of using an "orphan" popup menu with invisible form followwing it.
    # Not nice. Should be replaced with js menu.
    my $out = qq(\n<select onchange="document.$form_name.INSTRUCTIONID.value=value;document.$form_name.submit();">\n);
	$out .= qq(\t<option selected="selected" value=""> List...</option>\n);
    foreach my $instr (@{$instructions}) {
		$out .= qq(\t<option value=") . $instr->{'ID'} . qq(">) . $instr->{'LABEL'} . qq(</option>\n);
    }
    $out .= qq(</select>\n\n);
    $out .=
	qq(<form method="get" action="/cgi-bin/taboutputter" enctype="application/x-www-form-urlencoded" name="$form_name">\n) .
	qq(<input type="hidden" name="DB" value=") . $a[0]->dba->db_name . qq("  />\n).
	qq(<input type="hidden" name="INSTRUCTIONID" value=""  />\n);
    foreach my $i (@a) {
		$out .= qq(<input type="hidden" name="ID" value=") . $i->db_id . qq("  />);
    }
    $out .= qq(</form>\n);
    return $out;
}


1;
