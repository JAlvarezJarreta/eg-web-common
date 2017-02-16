#!/usr/local/bin/perl

use strict;
use warnings;

use Cwd;
use File::Basename;
use File::Spec;
use Getopt::Long qw(GetOptions);
use Data::Dumper;
use List::MoreUtils qw(uniq);
use Algorithm::Permute;

BEGIN {

    my @dirname = File::Spec->splitdir( dirname( Cwd::realpath(__FILE__) ) );
    my $code_path = File::Spec->catdir( splice @dirname, 0, -2 );

    # Load SiteDefs
    unshift @INC, File::Spec->catdir( $code_path, qw(ensembl-webcode conf) );
    eval { require SiteDefs; };
    if ($@) {
        print "ERROR: Can't use SiteDefs - $@\n";
        exit 1;
    }

    # Include all code dirs
    unshift @INC, reverse @{SiteDefs::ENSEMBL_LIB_DIRS};
    $ENV{'PERL5LIB'} = join ':', $ENV{'PERL5LIB'} || (), @INC;
}

use EnsEMBL::Web::SpeciesDefs;

my $sd = EnsEMBL::Web::SpeciesDefs->new();

my $db = {
    'database' => $sd->multidb->{'DATABASE_WEB_TOOLS'}{'NAME'},
    'host'     => $sd->multidb->{'DATABASE_WEB_TOOLS'}{'HOST'},
    'port'     => $sd->multidb->{'DATABASE_WEB_TOOLS'}{'PORT'},
    'username' => $sd->multidb->{'DATABASE_WEB_TOOLS'}{'USER'}
      || $sd->DATABASE_WRITE_USER,
    'password' => $sd->multidb->{'DATABASE_WEB_TOOLS'}{'PASS'}
      || $sd->DATABASE_WRITE_PASS,
};

my $input = 'y';
while ( $input !~ m/^(y|n)$/i ) {
    print sprintf
"\nThis will run queries on the following DB. Continue? %s\@%s:%s\nConfirm (y/n):",
      $db->{'database'}, $db->{'host'}, $db->{'port'};
    $input = <STDIN>;
}

close STDIN;

chomp $input;

die "Script aborted.\n" if $input =~ /n/i;

my $dbh = DBI->connect(
    sprintf(
        'DBI:mysql:database=%s;host=%s;port=%s',
        $db->{'database'}, $db->{'host'}, $db->{'port'}
    ),
    $db->{'username'},
    $db->{'password'} || ''
) or die('Could not connect to the database');


our %skip_species_type = ('PomBase' => 1,'WormBase ParaSite' => 1,'1000 Genomes' => 1);

#get_overall_count($dbh);
#get_individual_count($dbh);
#get_popular_species($dbh);
#get_ticket_vs_job_frequencies($dbh);
get_popular_species_combinations($dbh);
#get_all_possible_combinations(['A','B','C','D']);


####################################################################################

sub get_overall_count {
    my ($dbh) = @_;

    my $ticket_count = $dbh->prepare(
        "select count(*) from ticket where ticket_type_name = 'Blast' and ticket.created_at >= DATE_SUB(NOW(),INTERVAL 1 YEAR)");
    $ticket_count->execute;

    my $jobs_count = $dbh->prepare(
	"select count(*) from ticket inner join job on ticket.ticket_id = job.ticket_id where ticket_type_name = 'Blast' and ticket.created_at >= DATE_SUB(NOW(),INTERVAL 1 YEAR)"
    );
    $jobs_count->execute;

    printf "\n\nTotal number of Blast tickets on this server are: %s\n",
      $ticket_count->fetchrow_array;
    printf "Total number of Blast jobs on this server are: %s\n\n\n",
      $jobs_count->fetchrow_array;
}

sub get_individual_count {

    my ($dbh) = @_;

    my $sth_tickets = $dbh->prepare(
	"select ticket.site_type, count(*) as count from ticket where ticket.ticket_type_name = 'Blast'  and ticket.created_at >= DATE_SUB(NOW(),INTERVAL 1 YEAR) group by ticket.site_type order by site_type"
    );
    $sth_tickets->execute;
    my $tickets_count = $sth_tickets->fetchall_hashref('site_type');

    my $sth_jobs = $dbh->prepare(
	"select ticket.site_type, count(*) as count from ticket inner join job on ticket.ticket_id = job.ticket_id where ticket.ticket_type_name = 'Blast' and ticket.created_at >= DATE_SUB(NOW(),INTERVAL 1 YEAR)  
	group by ticket.site_type order by count"
    );
    $sth_jobs->execute;
    my $jobs_count = $sth_jobs->fetchall_hashref('site_type');

    printf( "%-20s %-20s %-20s\n", "Site type", "Tickets", "Jobs" );
    print "------------------------------------------------\n";

    foreach my $each_site ( keys %{$tickets_count} ) {
        printf(
            "%-20s %-20s %-20s\n",
            $tickets_count->{$each_site}->{'site_type'},
            $tickets_count->{$each_site}->{'count'},
            $jobs_count->{$each_site}->{'count'}
        );
    }

}

sub get_popular_species {

    my ($dbh) = @_;

    print "\n\n\n------------------------------------------------\n";
    print "Popular species in each site type\n";
    print "------------------------------------------------\n";
    my $sth_site_type = $dbh->prepare("select distinct site_type from ticket");
    $sth_site_type->execute;

    my $site_types = $sth_site_type->fetchall_arrayref( {} );

    #warn Data::Dumper::Dumper($site_types);

    foreach my $site_type (@$site_types) {

next if exists($skip_species_type{$site_type->{'site_type'}});

        printf "\n\nSite type: %s\n", $site_type->{'site_type'};
        print "------------------------------\n";

        my $sth_jobs = $dbh->prepare(
	"select job.species, count(*) as count from ticket inner join job on ticket.ticket_id = job.ticket_id where ticket.ticket_type_name = 'Blast' and ticket.site_type=		       ?  and ticket.created_at >= DATE_SUB(NOW(),INTERVAL 1 YEAR) group by job.species order by count"
        );

        $sth_jobs->bind_param( 1, $site_type->{'site_type'} );

        $sth_jobs->execute;
        my $jobs_count = $sth_jobs->fetchall_arrayref( {} );

        #warn Data::Dumper::Dumper($jobs_count);
        my $count = 1;
        foreach my $species_count ( reverse @$jobs_count ) {

            printf( "%-40s %-40s\n",
                $species_count->{'species'},
                $species_count->{'count'} );
            $count > 5 ? last : $count++;

        }
    }

}

sub get_ticket_vs_job_frequencies {

    my ($dbh) = @_;

    print "\n\n\n------------------------------------------------\n";
    print "Jobs per ticket in each site type\n";
    print "------------------------------------------------\n";
#    printf(
#        "%-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s\n",
#        "One", "Two",   "Three", "Four", "Five",
#        "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen", "Seventeen", "Eighteen", "Nineteen", "Twenty"
 #   );

    printf(
        "%-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-8s\n",
        "1", "2",   "3", "4", "5",
        "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30"
    );
    my $sth_site_type = $dbh->prepare("select distinct site_type from ticket");
    $sth_site_type->execute;

    my $site_types = $sth_site_type->fetchall_arrayref( {} );

    #warn Data::Dumper::Dumper($site_types);

    foreach my $site_type (@$site_types) {

next if exists($skip_species_type{$site_type->{'site_type'}});
        # printf "\n\nSite type: %s\n", $site_type->{'site_type'};
        printf "\n%s\n", $site_type->{'site_type'};

        print "------------------\n";

        my $sth_tickets_jobs = $dbh->prepare(
	"select ticket.ticket_id, count(*) as jobs_count from ticket inner join job on ticket.ticket_id = job.ticket_id where 
	 ticket.ticket_type_name = 'Blast' and ticket.site_type=?  and ticket.created_at >= DATE_SUB(NOW(),INTERVAL 1 YEAR) group by ticket.ticket_id order by jobs_count"
        );

        $sth_tickets_jobs->bind_param( 1, $site_type->{'site_type'} );

        $sth_tickets_jobs->execute;
        my $tickets_jobs_count = $sth_tickets_jobs->fetchall_arrayref( {} );

        #warn Data::Dumper::Dumper($tickets_jobs_count);

        my @ticket_job_stat;

        for ( my $frequency = 1 ; $frequency <= 30 ; $frequency++ ) {
            my $count = 0;

            foreach my $ticket (@$tickets_jobs_count) {

                if ( $frequency == $ticket->{'jobs_count'} ) {

                    $ticket_job_stat[$frequency] = ++$count;

                }

            }

        }

        for ( my $frequency = 1 ; $frequency <= 30 ; $frequency++ ) {
            printf( "%-8s ",
                $ticket_job_stat[$frequency] ? $ticket_job_stat[$frequency] : 0 );
        }
        print "\n";

        #warn Data::Dumper::Dumper(@ticket_job_stat);
    }

}




sub get_popular_species_combinations {

    my ($dbh) = @_;

    print "\n\n\n------------------------------------------------\n";
    print "Popular species combinations in each site type\n";
    print "------------------------------------------------\n";
    my $sth_site_type = $dbh->prepare("select distinct site_type from ticket");
    $sth_site_type->execute;

    my $site_types = $sth_site_type->fetchall_arrayref( {} );

    #warn Data::Dumper::Dumper($site_types);

    foreach my $site_type (@$site_types) {
next if exists($skip_species_type{$site_type->{'site_type'}});
#warn $skip_species_type{$site_type->{'site_type'}};
#next if $site_type ne 'Ensembl Fungi';

        printf "\n\nSite type: %s\n", $site_type->{'site_type'};
        print "------------------------------\n";

        my $sth_tickets = $dbh->prepare(
        "select ticket_id from ticket where ticket_type_name = 'Blast' and ticket.site_type=? and ticket.created_at >= DATE_SUB(NOW(),INTERVAL 1 YEAR) order by 	ticket_id"
        );

        $sth_tickets->bind_param( 1, $site_type->{'site_type'} );

        $sth_tickets->execute;

        my $tickets = $sth_tickets->fetchall_arrayref({}  );

	my $direct_combinations = {};
	my $subset_combinations = {};
       # warn Data::Dumper::Dumper($tickets);
        foreach my $ticket (  @$tickets ) {


	 my $sth_jobs = $dbh->prepare(
        "select species from job where ticket_id = ?"
        );

        $sth_jobs->bind_param( 1, $ticket->{'ticket_id'} );

        $sth_jobs->execute;

        my $jobs = $sth_jobs->fetchall_arrayref({} );

	my @species_combination;
	push @species_combination, $_->{'species'} foreach @$jobs;


	$direct_combinations = build_data_structure($direct_combinations, \@species_combination);


#warn "Species combinations\n";	
#warn Data::Dumper::Dumper(@species_combination);	

if (scalar @species_combination> 2 && scalar @species_combination < 20 ){
	$subset_combinations = get_all_possible_combinations($subset_combinations, \@species_combination);	
}

        }


	my @positioned = sort { $direct_combinations->{$a}{'count'} <=> $direct_combinations->{$b}{'count'} }  keys %$direct_combinations;



	my @positioned_test = sort { $subset_combinations->{$a}{'count'} <=> $subset_combinations->{$b}{'count'} }  keys %$subset_combinations;




#	warn Data::Dumper::Dumper(@positioned);
	printf ("%-5s %s\n",$direct_combinations->{$_}->{'count'}, $_) foreach reverse @positioned;

warn "******************\n";
#       warn Data::Dumper::Dumper(@positioned);
if (defined %$subset_combinations){

       printf ("%-5s %s\n",$subset_combinations->{$_}->{'count'}, $_) foreach reverse @positioned_test;
}
    }

}




sub build_data_structure{

   my ($data_structure, $species_combination) = @_;

   $data_structure->{join(' ', sort @$species_combination)}->{'species_list'} =  [sort @$species_combination];
   $data_structure->{join(' ', sort @$species_combination)}->{'species_string'} = join(' ', sort @$species_combination);
   $data_structure->{join(' ', sort @$species_combination)}->{'no_of_species'} = @$species_combination;
   $data_structure->{join(' ', sort @$species_combination)}->{'count'}++;
  

#       $data_structure->{join(' ', sort @$species_combination)} = { 
#                                       'species_list' =>  [sorti @$species_combination],
#                                       'species_string' => join(' ', sort @$species_combination)
#                                               };
#       $data_structure->{join(' ', sort @$species_combination)}->{'count'}++;

 
   return $data_structure;

}


sub get_all_possible_combinations{
  
    my ($subset_combinations, $parent_species_combination) = @_;

my $test = {};

    for(my $length =2 ; $length <= (scalar @$parent_species_combination) -1; $length++){
#	warn $length;
	my $p = new Algorithm::Permute($parent_species_combination, $length);
	while (my @combination =  sort $p->next) {
	
	$test->{join(' ', sort @combination)} = 1;


	}}

#warn Data::Dumper::Dumper($test);
my @test1 = keys %$test;
#warn Data::Dumper::Dumper(@test1);
#warn Data::Dumper::Dumper(@test1);

foreach my $test_combination(@test1){

my @test_combination_species = split / /, $test_combination;

$subset_combinations = build_data_structure($subset_combinations, \@test_combination_species);

#$subset_combinations = build_data_structure($subset_combinations, \@test1);
#warn "******************\n";
#warn "Possible combinations\n";
#warn "******************\n"; 
#warn Data::Dumper::Dumper(@$parent_species_combination);
#warn Data::Dumper::Dumper($subset_combinations);
#warn "\n\n\n";
}
#$subset_combinations = build_data_structure($subset_combinations, \@test_combination_species);

return $subset_combinations;
}

