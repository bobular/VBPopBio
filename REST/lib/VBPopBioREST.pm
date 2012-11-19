package VBPopBioREST;
use Dancer::Plugin::DBIC 'schema';
use Dancer ':syntax';
use lib '../api/Bio-Chado-VBPopBio/lib';
use Bio::Chado::VBPopBio;

our $VERSION = '0.1';



### JUST FOR DEMO/TESTING
get '/project/:id/depth/:depth' => sub {
    my $project = schema->projects->find_by_stable_id(params->{id});
    if (defined $project) {
	return $project->as_data_structure(params->{depth});
    } else {
	return { error_message => "can't find project" };
    }
};

get '/' => sub{
    return {message => "Testing Dancer for VBPopBio REST service"};
};

get '/project/:id' => sub {
    my $project = schema->projects->find_by_stable_id(params->{id});
    if (defined $project) {
	return $project->as_data_structure(); # warning - returns EVERYTHING
    } else {
	return { error_message => "can't find project" };
    }
};

get '/project/:id/head' => sub {
    my $project = schema->projects->find_by_stable_id(params->{id});
    if (defined $project) {
	return $project->as_data_structure(0);
    } else {
	return { error_message => "can't find project" };
    }
};


get qr{/projects(/head)?} => sub {

    my ($head) = splat;
    my $l = params->{l} || 20;
    my $o = params->{o} || 0;    


    my $result = schema->projects->search(
	undef,
	{
	    rows => $l,
	    offset => $o,	
	},
	);
   
    my $count = $result->count;
    
    if (defined $result) {
	return $result->as_data_structure(defined $head ? 0 : undef);
    }else{
	return {
	    records => [ map { $_->as_data_structure } $result->all ],
	    records_info($o, $l, $count)
	};
    }
};



get qr{/stocks(/head)?} => sub {
    my ($head) = splat;
    my $l = params->{l} || 20;
    my $o = params->{o} || 0;    

    my $result = schema->stocks->search(
	undef,
	{
	    
	    rows => $l,
	    offset => $o,
	},
	);
   
    my $count = $result->count;
    if (defined $result) {
	return $result->as_data_structure(defined $head ? 0 : undef);
    }else{
	return {
	    records => [ map { $_->as_data_structure } $result->all ],
	    records_info($o, $l, $count)
	};
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


get '/assay/:id' => sub {
    my $assay = schema->experiments->find_by_stable_id(params->{id});
    if (defined $assay) {
	return $assay->as_data_structure;
    } else {
	return { error_message => "can't find assay" };
    }
};


get '/assay/:id/head' => sub {
    my $assay = schema->experiments->find_by_stable_id(params->{id});
    if (defined $assay) {
	return $assay->as_data_structure(0);
    } else {
	return { error_message => "can't find assay" };
    }
};


get qr{/project/(\w+)(/stocks)?} => sub {
    my ($id, $head) = splat;
    my $project = schema->projects->find_by_stable_id(params($id));
    if (defined $project) {
	return $project = schema->stocks->as_data_structure(defined $head ? 0 : undef);
    } else {
	return { error_message => "can't find project" };
    }
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

get qr{/stock/(\w+)(/projects)?} => sub {
    my ($id, $head) = splat;
    my $stock = schema->stocks->find_by_stable_id(params->{id});

    my $l = params->{l} || 20;
    my $o = params->{o} || 0;

 
    my $projects = $stock->projects->search(
      undef,
	{
	    rows => $l,
	    offset => $o,	
	},
	);

    my $count = $projects->count;
   
    return {
	records => [ map { $_->as_data_structure } $projects->all ],
	records_info($o, $l, $count)
    };

};


get '/stock/:id/assays' => sub {
    my $stock = schema->stocks->find_by_stable_id(params->{id});

  
    my $o = params->{o} || 0; 
    my $l = params->{l} || 20;


    my $experiments = $stock->experiments->search(
	undef,
	{
	    rows => $l,
	    offset => $o,	  
	},
	);

    my $count = $experiments->count;
  
 
    return {
	records => [ map { $_->as_data_structure } $experiments->all ],
	records_info($o, $l, $count)
    };
};


#####################
# utility subroutines

sub records_info {
    my ($o, $l, $count) = @_;

    return (
	start => $o + 1,
	end => $l,
	count => $count,
	);
}

true;

