# $Id: Contig.pm,v 1.6 2013-09-24 12:24:46 jh15 Exp $

package EnsEMBL::Web::ZMenu::Contig;

use strict;

use base qw(EnsEMBL::Web::ZMenu);
use Data::Dumper;

sub content {
  my $self            = shift;
  my $hub             = $self->hub;
  my $threshold       = 1000100 * ($hub->species_defs->ENSEMBL_GENOME_SIZE||1);
  my $slice_name      = $hub->param('region');
  my $db_adaptor      = $hub->database('core');
  my $slice           = $db_adaptor->get_SliceAdaptor->fetch_by_region('seqlevel', $slice_name);
  my $slice_type      = $slice->coord_system_name;
  my $top_level_slice = $slice->project('toplevel')->[0]->to_Slice;
  my $action          = $slice->length > $threshold ? 'Overview' : 'View';
  
  $self->caption($slice_name);
  
  $self->add_entry({
    label => "Center on $slice_type $slice_name",
    link  => $hub->url({ 
      type   => 'Location', 
      action => $action, 
      region => $slice_name 
    })
  });
  
  $self->add_entry({
    label => "Export $slice_type sequence/features",
    link_class => 'modal_link',
    link  => $hub->url({ 
      type   => 'Export',
      action => 'Configure', 
      function => 'Location',
      r      => sprintf '%s:%s-%s', map $top_level_slice->$_, qw(seq_region_name start end)
    })
  });

  foreach my $cs (@{$db_adaptor->get_CoordSystemAdaptor->fetch_all || []}) {
# in EG we want to get 

    next if $cs->name =~ /^chromosome|plasmid$/; # don't allow breaking of site by exporting all chromosome features
    
    my $path;
    eval { $path = $slice->project($cs->name); };
    
    next unless $path && scalar @$path == 1;

    my $new_slice        = $path->[0]->to_Slice->seq_region_Slice;
    my $new_slice_type   = $new_slice->coord_system_name;
    my $new_slice_name   = $new_slice->seq_region_name;
    my $new_slice_length = $new_slice->seq_region_length;

    $action = $new_slice_length > $threshold ? 'Overview' : 'View';

 # in EG we want these links for contigs as well   

    if (my $attrs = $new_slice->get_all_Attributes('external_db')) {
	foreach my $attr (@$attrs) {
#	    warn "A: $attrs \n";
#	    warn Dumper $attrs;

	    my $ext_db = $attr->value;

	    if( my $link = $hub->get_ExtURL($ext_db, $new_slice_name)) {
		$self->add_entry({
		    type  => $ext_db,
		    label => $new_slice_name,
		    link  => $link, 
		extra => { external => 1 }
		});
		
		(my $short_name = $new_slice_name) =~ s/\.[\d\.]+$//;
		
		$self->add_entry({
		    type  => "$ext_db (latest version)",
		    label => $short_name,
		    link  => $hub->get_ExtURL($ext_db, $short_name),
		    extra => { external => 1 }
		});
	    }
	}
	next;
    }


    if (0 && $cs->name eq 'contig') {
#      (my $short_name = $new_slice_name) =~ s/\.\d+$//;
      (my $short_name = $new_slice_name) =~ s/\.[\d\.]+$//;
      
      $self->add_entry({
        type  => 'ENA',
        label => $new_slice_name,
        link  => $hub->get_ExtURL('EMBL', $new_slice_name),
        extra => { external => 1 }
      });
      
      $self->add_entry({
        type  => 'ENA (latest version)',
        label => $short_name,
        link  => $hub->get_ExtURL('EMBL', $short_name),
        extra => { external => 1 }
      });
      next;
    }

    next if $cs->name eq $slice_type;  # don't show the slice coord system twice    

    $self->add_entry({
      label => "Center on $new_slice_type $new_slice_name",
      link  => $hub->url({
        type   => 'Location', 
        action => $action, 
        region => $new_slice_name
      })
    });

    # would be nice if exportview could work with the region parameter, either in the referer or in the real URL
    # since it doesn't we have to explicitly calculate the locations of all regions on top level
    $top_level_slice = $new_slice->project('toplevel')->[0]->to_Slice;


    $self->add_entry({
      label => "Export $new_slice_type sequence/features",
      link_class => 'modal_link',
      link  => $hub->url({
        type   => 'Export',
        action => "Location/$action",
        r      => sprintf '%s:%s-%s', map $top_level_slice->$_, qw(seq_region_name start end)
      })
    });
 # in EG we want these links for contigs as well   


    if ($cs->name eq 'clone') {
      (my $short_name = $new_slice_name) =~ s/\.\d+$//;
      
      $self->add_entry({
        type  => 'EMBL',
        label => $new_slice_name,
        link  => $hub->get_ExtURL('EMBL', $new_slice_name),
        extra => { external => 1 }
      });
      
      $self->add_entry({
        type  => 'EMBL (latest version)',
        label => $short_name,
        link  => $hub->get_ExtURL('EMBL', $short_name),
        extra => { external => 1 }
      });
    }
  }
}

1;
