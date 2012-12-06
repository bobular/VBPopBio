package VBPopBioREST;
use Dancer::Plugin::DBIC 'schema';
use Dancer ':syntax';
#use lib '/home/maccallr/vectorbase/popgen/api-devel/Bio-Chado-Schema-git/Bio-Chado-Schema-0.10010/lib';
use lib '../api/Bio-Chado-VBPopBio/lib';
use Bio::Chado::VBPopBio;

our $VERSION = '0.1';



### JUST FOR DEMO/TESTING ###
# don't need /depth routes but maybe one day...
get '/project/:id/depth/:depth' => sub {
    my $project = schema->projects->find_by_stable_id(params->{id});
    if (defined $project) {
	return $project->as_data_structure(params->{depth});
    } else {
	return { error_message => "can't find project" };
    }
};
##############################

get '/' => sub{
    return {message => "Testing Dancer for VBPopBio REST service"};
};

get qr{/project/(\w+)} => sub {
    my ($id) = splat;
    my $project = schema->projects->find_by_stable_id($id);
    if (defined $project) {
	return $project->as_data_structure(); # warning - returns EVERYTHING
    } else {
	return { error_message => "can't find project" };
    }
};

get qr{/project/(\w+)/head} => sub {
    my ($id) = splat;
    my $project = schema->projects->find_by_stable_id($id);
    if (defined $project) {
	return $project->as_data_structure(0);
    } else {
	return { error_message => "can't find project" };
    }
};


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



get qr{/stocks(/head)?} => sub {
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

get qr{/stock/(\w+)(/head)?} => sub {
    my ($id, $head) = splat;
 

my $stock = schema->stocks->find_by_stable_id($id);
if (defined $stock) {
	return $stock->as_data_structure(defined $head ? 0 : undef);
    } else {
	return { error_message => "can't find stock" };
    }

 
};


get qr{/assay/(\w+)(/head)?} => sub {
    my ($id, $head) = splat;
    my $assay = schema->experiments->find_by_stable_id($id);
    if (defined $assay) {
	return $assay->as_data_structure(defined $head ? 0 : undef);
    } else {
	return { error_message => "can't find assay" };
    }
};

# Modified for the 005_stock.t test
get qr{/project/(\w+)/stocks(/head)?} => sub {
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

get qr{/stock/(\w+)/projects(/head)?} => sub {
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


get qr{/stock/(\w+)/assays} => sub {
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

    return (
	start => $o + 1,
	end => $o + $l, 
	
	# have to do the following because $page->count returns page size
	count => $page->pager->total_entries,
	);
}

true;

