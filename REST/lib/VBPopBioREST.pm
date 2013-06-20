package VBPopBioREST;
use Dancer::Plugin::DBIC 'schema';
use Dancer ':syntax';
use lib '../api/Bio-Chado-VBPopBio/lib';
use Bio::Chado::VBPopBio;
use Dancer::Plugin::MemcachedFast;

our $VERSION = '0.1';

schema->storage->_use_join_optimizer(0);

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


# project/head
# special case NO CACHING (so editing vis_configs is less painful)
get qr{/project/(\w+)/head} => sub {
    my ($id) = splat;
    my $project = schema->projects->find_by_stable_id($id);
    if (defined $project) {
      return $project->as_data_structure(0);
    } else {
      return { error_message => "can't find project" };
    }
  };

# full project - hope nobody calls this (except maybe on things like MR4 collection)
get qr{/project/(\w+)} => sub {
    my ($id) = splat;
    memcached_get_or_set("project/$id", sub {
			   my $project = schema->projects->find_by_stable_id($id);
			   if (defined $project) {
			     return $project->as_data_structure(undef);
			   } else {
			     return { error_message => "can't find project" };
			   }
			 });
  };

# Projects
# not cached any more - at least while in development
# and until we can selectively flush parts of the cache
get qr{/projects/head} => sub {
    my $head = '/head'; # enforce this - or we kill the server
    my $l = params->{l} || 20;
    my $o = params->{o} || 0;

#    memcached_get_or_set("projects$head-$o-$l", sub {

                           # for ordering by submission date
                           my $sub_date_type = schema->types->submission_date;

			   my $results = schema->projects->search(
								  { 'projectprops.type_id' => $sub_date_type->id },
								  {
								   rows => $l,
								   offset => $o,
								   page => 1,
								   join => 'projectprops',
								   order_by => [ 'projectprops.value', 'me.name' ]
								  },
								 );
			   my $depth = $head ? 0 : undef;
			   return {
				   records => [ map { $_->as_data_structure($depth) } $results->all ],
				   records_info($o, $l, $results)
				  };
#			 });
  };

# Stocks
get qr{/(?:stocks|samples)(/head)?} => sub {
    my ($head) = splat;
    my $l = params->{l} || 20;
    my $o = params->{o} || 0;

    memcached_get_or_set("samples$head-$o-$l", sub {
			   my $results = schema->stocks->search(
								undef,
								{
								 rows => $l,
								 offset => $o,
								 page => 1,
								},
							       );
			   my $depth = $head ? 0 : undef;
			   return {
				   records => [ map { $_->as_data_structure($depth) } $results->all ],
				   records_info($o, $l, $results),
				  };
			 })
  };

# Stock
get qr{/(?:stock|sample)/(\w+)(/head)?} => sub {
    my ($id, $head) = splat;

    memcached_get_or_set("sample/$id$head", sub {
			   my $stock = schema->stocks->find_by_stable_id($id);

			   if (defined $stock) {
			     return $stock->as_data_structure(defined $head ? 0 : undef);
			   } else {
			     return { error_message => "can't find stock" };
			   }
			 });
  };

# Assay
get qr{/assay/(\w+)(/head)?} => sub {
    my ($id, $head) = splat;

    memcached_get_or_set("assay/$id$head", sub {
			   my $assay = schema->experiments->find_by_stable_id($id);

			   if (defined $assay) {
			     return $assay->as_data_structure(defined $head ? 0 : undef);
			   } else {
			     return { error_message => "can't find assay" };
			   }
			 });
  };

# Project/stocks
get qr{/project/(\w+)/(?:stocks|samples)(/head)?} => sub {
    my ($id, $head) = splat;
    my $l = params->{l} || 20;
    my $o = params->{o} || 0;

    memcached_get_or_set("project/$id/samples$head-$o-$l", sub {
			   my $project = schema->projects->find_by_stable_id($id);

			   my $stocks = $project->stocks->search(
								 undef,
								 {
								  rows => $l,
								  offset => $o,
								  page => 1,
								 },
								);

			   return {
				   records => [ map { $_->as_data_structure(defined $head ? 0 : undef, $project) } $stocks->all ],
				   records_info($o, $l, $stocks)
				  };
			 });
  };

# assay/stocks
get qr{/assay/(\w+)/(?:stocks|samples)(/head)?} => sub {
    my ($id, $head) = splat;
    my $l = params->{l} || 20;
    my $o = params->{o} || 0;

    memcached_get_or_set("assay/$id/samples$head-$o-$l", sub {
			   my $assay = schema->experiments->find_by_stable_id($id);

			   my $stocks = $assay->stocks->search(
							       undef,
							       {
								rows => $l,
								offset => $o,
								page => 1,
							       },
							      );

			   return {
				   records => [ map { $_->as_data_structure(defined $head ? 0 : undef) } $stocks->all ],
				   records_info($o, $l, $stocks)
				  };
			 });
};

# assay/projects
get qr{/assay/(\w+)/projects(/head)?} => sub {
    my ($id, $head) = splat;
    my $l = params->{l} || 20;
    my $o = params->{o} || 0;

    memcached_get_or_set("assay/$id/projects$head-$o-$l", sub {
			   my $assay = schema->experiments->find_by_stable_id($id);

			   my $projects = $assay->projects->search(
								   undef,
								   {
								    rows => $l,
								    offset => $o,
								    page => 1,
								   },
								  );

			   return {
				   records => [ map { $_->as_data_structure(defined $head ? 0 : undef) } $projects->all ],
				   records_info($o, $l, $projects)
				  };
			 });
  };

# Stock/projects
get qr{/(?:stock|sample)/(\w+)/projects(/head)?} => sub {
    my ($id, $head) = splat;
    my $l = params->{l} || 20;
    my $o = params->{o} || 0;

    memcached_get_or_set("stock/$id/projects$head-$o-$l", sub {
			   my $stock = schema->stocks->find_by_stable_id($id);
			   my $projects = $stock->projects->search(
								   undef,
								   {
								    rows => $l,
								    offset => $o,
								    page => 1,
								   },
								  );

			   return {
				   records => [ map { $_->as_data_structure(defined $head ? 0 : undef) } $projects->all ],
				   records_info($o, $l, $projects)
				  };
			 });
  };

# Stock/assays
get qr{/(?:stock|sample)/(\w+)/assays} => sub {
    my ($id) = splat;
    my $o = params->{o} || 0;
    my $l = params->{l} || 20;

    memcached_get_or_set("stock/$id/assays-$o-$l", sub {
			   my $stock = schema->stocks->find_by_stable_id($id);
			   my $experiments = $stock->experiments->search(
									 undef,
									 {
									  rows => $l,
									  offset => $o,
									  page => 1,
									 },
									);
			   return {
				   records => [ map { $_->as_data_structure } $experiments->all ],
				   records_info($o, $l, $experiments)
				  };
			 });
  };

# fall back 404
any qr{.*} => sub {
        warning "Cannot resolve request path '".request->path."'";
        return { not_found => request->path };
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


1;

