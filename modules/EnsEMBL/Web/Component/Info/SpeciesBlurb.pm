# $Id: SpeciesBlurb.pm,v 1.14 2013-09-06 15:30:15 jh15 Exp $

package EnsEMBL::Web::Component::Info::SpeciesBlurb;

use strict;

use EnsEMBL::Web::Controller::SSI;
use Data::Dumper;

use base qw(EnsEMBL::Web::Component);

sub content {
  my $self              = shift;
  my $hub               = $self->hub;
  my $species_defs      = $hub->species_defs;
  my $species           = $hub->species;

# # $self->wheatHomePage found in eg-plugins/plants
# if ($species eq 'Triticum_aestivum' && $self->can('wheatHomePage')){
#   return $self->wheatHomePage();
# }

  my $common_name       = $species_defs->SPECIES_COMMON_NAME;
  my $display_name      = $species_defs->SPECIES_SCIENTIFIC_NAME;
  my $ensembl_version   = $species_defs->ENSEMBL_VERSION;
  my $current_assembly  = $species_defs->ASSEMBLY_NAME;
  my $accession         = $species_defs->ASSEMBLY_ACCESSION;
  my $source            = $species_defs->ASSEMBLY_ACCESSION_SOURCE || 'NCBI';
  my $source_type       = $species_defs->ASSEMBLY_ACCESSION_TYPE;
  my %archive           = %{$species_defs->get_config($species, 'ENSEMBL_ARCHIVES') || {}};
  my %assemblies        = %{$species_defs->get_config($species, 'ASSEMBLIES')       || {}};
  my $previous          = $current_assembly;

  my $html = qq(
<div class="column-wrapper">  
  <div class="column-one">
    <div class="column-padding no-left-margin">
      <img src="/i/species/48/$species.png" class="species-img float-left" alt="" />
      <h1 style="margin-bottom:0">$common_name Assembly and Gene Annotation</h1>
    </div>
  </div>
</div>
          );

  $html .= '
<div class="column-wrapper">  
  <div class="column-two">
    <div class="column-padding no-left-margin">';
## EG START
# We use the old pages named about_{species}.html - maybe we should replace them later
#### ASSEMBLY
# $html .= '<h2 id="assembly">Assembly</h2>';
# $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/species/${species}_assembly.html");

# $html .= '<h2 id="genebuild">Gene annotation</h2>';
# $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/species/${species}_annotation.html");
## ....EG....
  $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/species/about_${species}.html");
# $self->cut_tagged_section(\$html,'about');
## EG END

  $html .= '
    </div>
  </div>
  <div class="column-two">
    <div class="column-padding" style="margin-left:16px">';

  ## ASSEMBLY STATS 
  my $file = '/ssi/species/stats_' . $self->hub->species . '.html';
  $html .= '<h2>Statistics</h2>';
  $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, $file);

  my $interpro = $self->hub->url({'action' => 'IPtop500'});
  $html .= qq(<h3>InterPro Hits</h3>
<ul>
  <li><a href="$interpro">Table of top 500 InterPro hits</a></li>
</ul>);

  $html .= '
    </div>
  </div>
</div>';

# process any subs
  my @scripts = $html =~ /\{\{sub_([^\}]+)\}\}/;
  foreach my $script (@scripts){
    if($self->can($script)){
      my $output = $self->$script;
      $html =~ s/\{\{sub_$script\}\}/$output/;
    }
  }
#
  return $html;  
}

=head2 cut_tagged_section
  Arg [1]:     string pointer
  Arg [2]:     tag name
  Example:     cut_by_tag(\$html, 'about')
  Description: Remove sections of the page demarcated by <!-- {tagname} -->
  Meta:        ENSEMBL-1881

=cut

sub cut_tagged_section{
  my ($self,$ptr,$tag) = @_;
  $$ptr =~ s/^(.*?)<!--\s*\{$tag\}\s*-->(.*)<!--\s*\{$tag\}\s*-->(.*)$/\1\3/msg;
  return 1; 
}
1;
