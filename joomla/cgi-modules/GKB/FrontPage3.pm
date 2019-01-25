=head1 NAME

GKB::FrontPage3

=head1 SYNOPSIS

=head1 DESCRIPTION

Serves up the HTML elements that make up the front page for Reactome website 3.x.

=head1 SEE ALSO

=head1 AUTHOR

David Croft E<lt>croft@ebi.ac.ukE<gt>

Copyright (c) 2013 European Bioinformatics Institute and Cold Spring
Harbor Laboratory.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER for
disclaimers of warranty.

=cut

package GKB::FrontPage3;

use Data::Dumper;
use GKB::Utils;
use GKB::Config;
use GKB::HTMLUtils;
use GKB::FileUtils;
use GKB::Utils::Timer;
use Capture::Tiny ':all';
use strict;
use warnings;
use vars qw(@ISA $AUTOLOAD %ok_field);
use Bio::Root::Root;

@ISA = qw(Bio::Root::Root);

# List the object variables here, so that they can be checked
#
for my $attr
    (qw(
    title
    content
    ) ) { $ok_field{$attr}++; }

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
    my($pkg, $title) = @_;

    my $self = bless {}, $pkg;

    $self->clear_variables();
    $self->title($title);
    $self->content($self->get_index_html_content());

    return $self;
}

sub clear_variables {
    my ($self) = @_;

    $self->title(undef);
    $self->content(undef);
}

# Needed by subclasses to gain access to class variables defined in
# this class.
sub get_ok_field {
    return %ok_field;
}

sub get_header {
    my ($self) = @_;

    my $chunk = GKB::HTMLUtils->extract_chunk_from_html($self->content, '', '<!-- template-placeholder -->');
    my $title = $self->title;
    if ($title) {
        $chunk =~ s/<title>.*?<\/title>/<title>$title<\/title>/si;
    }
    my $stylesheet_url = "/stylesheet.css";
    if (defined $stylesheet_url && !($stylesheet_url eq '')) {
        my $stylesheet_html = "";
        #$stylesheet_html .= "<link rel=\"stylesheet\" type=\"text\/css\" href=\"$stylesheet_url\" />\n";
        $stylesheet_html .= "<style type=\"text/css\">\n";
        $stylesheet_html .= "TR.contents TD.sidebar {font-size: 100% !important; line-height: 120%;} UL.classhierarchy {line-height: 100%;} UL.classhierarchy LI A {font-size: 100% !important; padding: 0; line-height: 0;} TD.sidebar UL LI {margin-left: 3px;} A.sidebar:link {padding: 0px; margin: 0px; list-style-type: none; font-size: 100%;} A.DOI {font-size: 100% !important;}\n";
        $stylesheet_html .= "</style>\n";

        $chunk =~ s/(<\/head>)/$stylesheet_html$1/i;
    }

    return $chunk;
}

sub get_footer {
    my ($self) = @_;

    my $chunk = GKB::HTMLUtils->extract_chunk_from_html($self->content, '<!-- template-placeholder -->', '');

    return $chunk;
}

sub get_enclosing_div_start {
    my ($self) = @_;

    #return "\n\n<!--content-->\n<div id=\"content\" style=\"width=700; min-height=400;\">\n";
    return "\n\n<!--content-->\n<div id=\"r-responsive-table\" class=\"padding0 top30\">\n";
}

sub get_enclosing_div_end {
    my ($self) = @_;

    return "\n</div>\n<!--close content-->\n\n";
}

sub get_index_html_content {
    my ($self) = @_;
    # when running in a docker container, $host must always be localhost.
    # Otherwise, "joomla-sites" gets propagated to the "base" element of the template
    # and then none of the resources load properly.
    # my $host = 'localhost';
	my $host = $GKB::Config::HOST_NAME;
    chomp $host;
    my $content = `wget --no-check-certificate -qO- $host/template-cgi`;

    $content =~ s|http:\/\/|https:\/\/|g;
    $content =~ s/favth\-content\-block\s?//g;

	# Also need to remove the Google Analytics
	$content =~ s/'<script async src="https:\/\/www\.googletagmanager\.com\/.*"><\/script>'//g;
	$content =~ s/<script>\W+window\.dataLayer = window\.dataLayer \|\| \[\];\W+function gtag\(\)\{dataLayer\.push\(arguments\)\};\W+gtag\('js', new Date\(\)\);\W+gtag\('config', '.*'\);\W+<\/script>//g;

    return $content;
}

1;
