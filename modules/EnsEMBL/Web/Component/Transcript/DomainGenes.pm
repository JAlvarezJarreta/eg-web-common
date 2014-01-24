# $Id: DomainGenes.pm,v 1.2 2013-07-15 14:39:41 nl2 Exp $

package EnsEMBL::Web::Component::Transcript::DomainGenes;

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $species = $hub->species;
  
  return unless $hub->param('domain');
  
  my $object = $self->object;
  my $genes  = $object->get_domain_genes;
  
  return unless @$genes;
  
  my $html;

  ## Karyotype showing genes associated with this domain (optional)
  my $gene_stable_id = $object->gene ? $object->gene->stable_id : 'xx';
  
  if (@{$hub->species_defs->ENSEMBL_CHROMOSOMES}) {
    $hub->param('aggregate_colour', 'red'); ## Fake CGI param - easiest way to pass this parameter
    
    my $wuc   = $hub->get_imageconfig('Vkaryotype');
    my $image = $self->new_karyotype_image($wuc);
    
    $image->image_type = 'domain';
    $image->image_name = "$species-" . $hub->param('domain');
    $image->imagemap   = 'yes';
    
    my %high = ( style => 'arrow' );
    
    foreach my $gene (@$genes) {
      my $stable_id = $gene->stable_id;
      my $chr       = $gene->seq_region_name;
      my $colour    = $gene_stable_id eq $stable_id ? 'red' : 'blue';
      my $point     = {
        start => $gene->seq_region_start,
        end   => $gene->seq_region_end,
        col   => $colour,
        href  => $hub->url({ type => 'Gene', action => 'Summary', g => $stable_id })
      };
      
      if (exists $high{$chr}) {
        push @{$high{$chr}}, $point;
      } else {
        $high{$chr} = [ $point ];
      }
    }
    
    $image->set_button('drag');
    $image->karyotype($hub, $object, [ \%high ]);
    $html .= sprintf '<div style="margin-top:10px">%s</div>', $image->render;
  }

  ## Now do table
  my $table = $self->new_table([], [], { data_table => 'no_sort' });

  $table->add_columns(
    { key => 'id',   title => 'Gene',                   width => '30%', align => 'center' },
    { key => 'loc',  title => 'Genome Location',        width => '20%', align => 'left'   },
    { key => 'desc', title => 'Description (if known)', width => '50%', align => 'left'   }
  );
  
  foreach my $gene (sort { $object->seq_region_sort($a->seq_region_name, $b->seq_region_name) || $a->seq_region_start <=> $b->seq_region_start } @$genes) {
    my $row       = {};
    my $xref_id   = $gene->display_xref ? $gene->display_xref->display_id : '-novel-';
    my $stable_id = $gene->stable_id;
    
    $row->{'id'} = sprintf '<a href="%s">%s</a><br />(%s)', $hub->url({ type => 'Gene', action => 'Summery', g => $stable_id }), $stable_id, $xref_id;

    my $readable_location = sprintf(
      '%s: %s-%s',
      $self->neat_sr_name($gene->slice->coord_system->name, $gene->slice->seq_region_name),
      $gene->start,
      $gene->end
    );

    $row->{'loc'}= sprintf '<a href="%s">%s</a>', $hub->url({ type => 'Location', action => 'View', g => $stable_id, __clear => 1 }), $readable_location;
   
    my %description_by_type = ( bacterial_contaminant => 'Probable bacterial contaminant' );
   
    $row->{'desc'} = $gene->description || $description_by_type{$gene->biotype} || 'No description';
    
    $table->add_row($row);
  }
  
  $html .= $table->render;

  return $html;
}

1;

