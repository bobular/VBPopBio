package VBPopBioREST;
use Dancer::Plugin::DBIC 'schema';
use Dancer ':syntax';
use lib '../api/Bio-Chado-VBPopBio/lib';
use Bio::Chado::VBPopBio;

our $VERSION = '0.1';



### JUST FOR DEMO/TESTING ###
# don't need /depth routes but maybe one day...
#get '/project/:id/depth/:depth' => sub {
#    my $project = schema->projects->find_by_stable_id(params->{id});
#    if (defined $project) {
#	return $project->as_data_structure(params->{depth});
#    } else {
#	return { error_message => "can't find project" };
#    }
#};
##############################


get '/' => sub{
    return {message => "Testing Dancer for VBPopBio REST service"};
};


# Project
get qr{/project/(\w+)(/head)?} => sub {
    my ($id, $head) = splat;
    my $project = schema->projects->find_by_stable_id($id);

    if (defined $project) {
	return $project->as_data_structure(defined $head ? 0 : undef);
    } else {
	return { error_message => "can't find project" };
    }
};

#Projects
get qr{/projects(/head)?} => sub {
    
    my ($head) = splat;
    my $depth = $head ? 0 : undef;
    my $l = params->{l} || 20;
    my $o = params->{o} || 0;    
    
    
    my $results = schema->projects->search(
	undef,
	{
	    rows => $l,
	    offset => $o,
	    page => 1,
	},
	);
    
    my $count = $results->count;
    
    return {
	    records => [ map { $_->as_data_structure($depth) } $results->all ],
	    records_info($o, $l, $results)
    }
    
};


#Stocks
get qr{/(?:stocks|samples)(/head)?} => sub {
    my ($head) = splat;
    my $depth = $head ? 0 : undef;
    my $l = params->{l} || 20;
    my $o = params->{o} || 0;    
    
    my $results = schema->stocks->search(
	undef,
	{
	    rows => $l,
	    offset => $o,
	    page => 1,
	},
	);
    
    return {
	records => [ map { $_->as_data_structure($depth) } $results->all ],
	records_info($o, $l, $results),
    }
};

#Stock
get qr{/(?:stock|sample)/(\w+)(/head)?} => sub {
    my ($id, $head) = splat;
    my $stock = schema->stocks->find_by_stable_id($id);

    if (defined $stock) {
	return $stock->as_data_structure(defined $head ? 0 : undef);
    } else {
	return { error_message => "can't find stock" };
    }
    
    
};

#Assay
get qr{/assay/(\w+)(/head)?} => sub {
    my ($id, $head) = splat;
    my $assay = schema->experiments->find_by_stable_id($id);

    if (defined $assay) {
	return $assay->as_data_structure(defined $head ? 0 : undef);
    } else {
	return { error_message => "can't find assay" };
    }
};

#Project/stocks
get qr{/project/(\w+)/(?:stocks|samples)(/head)?} => sub {
    my ($id, $head) = splat;
    my $project = schema->projects->find_by_stable_id($id);
    
    my $l = params->{l} || 20;
    my $o = params->{o} || 0;
    
    
    my $stocks = $project->stocks->search(
	undef,
	{
	    rows => $l,
	    offset => $o,
	    page => 1,
	},
	);
    
    my $count = $stocks->count;
    
    return {
	records => [ map { $_->as_data_structure(defined $head ? 0 : undef) } $stocks->all ],
	records_info($o, $l, $stocks)
    };
    
};

## JUST FOR DEMO/TESTING
#get '/organisms' => sub {
#
#    my $result = schema->organisms->search(
#	undef,
#	{ 
#	    rows => params->{l} || 20,
#	    offset => params->{o} || 0,
#   
#        },
#	);
#
#    return { records => [ map { $_->as_data_structure } $result->all ] };   
#
#};

#Stock/projects
get qr{/(?:stock|sample)/(\w+)/projects(/head)?} => sub {
    my ($id, $head) = splat;
    my $stock = schema->stocks->find_by_stable_id($id);
    
    my $l = params->{l} || 20;
    my $o = params->{o} || 0;
    
    
    my $projects = $stock->projects->search(
	undef,
	{
	    rows => $l,
	    offset => $o,
	    page => 1,
	},
	);
    
    my $count = $projects->count;
    
    return {
	records => [ map { $_->as_data_structure } $projects->all ],
	records_info($o, $l, $projects)
    };
    
};

#Stock/assays
get qr{/(?:stock|sample)/(\w+)/assays} => sub {
    my ($id) = splat;
    my $stock = schema->stocks->find_by_stable_id($id);
    
    
    my $o = params->{o} || 0; 
    my $l = params->{l} || 20;
    
    
    my $experiments = $stock->experiments->search(
	undef,
	{
	    rows => $l,
	    offset => $o,
	    page => 1,
	},
	);
    
    my $count = $experiments->count;
    
    
    return {
	records => [ map { $_->as_data_structure } $experiments->all ],
	records_info($o, $l, $experiments)
    };
};


#####################
# utility subroutines

sub records_info {
    my ($o, $l, $page) = @_;
    my $end = $o + $page->count;
    
    return (
	start => $o + 1, 
	end => $end,
	
	# have to do the following because $page->count returns page size
	count => $page->pager->total_entries,
	);
}

true;

