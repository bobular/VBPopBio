#!/usr/bin/env perl

#
# usage bin/irbase-isatab2phenote.pl ../../data/IRbaseToISAtab/study23/a_phenotypes.old > ../../data/IRbaseToISAtab/study23/p_ir_assay_results.tab
#
#
# foreach file ( ../../data/IRbaseToISAtab-XXXXX/study*/a_phenotypes.txt )
#   perl -npe 's/Mortat?lity percentage|Percentage mortality|%mortality/% mortality/g' $file | bin/irbase-isatab2phenote.pl > $file:h/p_ir_assay_results.tab
#   perl -i.old -nlpe 's/[^\t]+$/$x++ ? "p_ir_assay_results.tab" : "Raw Data File"/e' $file
# end
#
#


use strict;
use Text::CSV_XS;
use lib 'bin';
use IRTypes;

print join("\t",
	   'Sample',
	   'Assay',
	   'prop?',
	   'Name',
	   'Entity ID',
	   'Entity Name',
	   'Attribute ID',
	   'Attribute Name',
	   'Quality ID',
	   'Quality Name',
	   'Value',
	   'Unit ID',
	   'Unit Name',
	   'Date Created'
)."\n";


my $tsv_parser = Text::CSV_XS->new ({ binary => 1,
				      eol => $/,
				      sep_char => "\t"
				    });



my $headers = $tsv_parser->getline(*ARGV);
$tsv_parser->column_names($headers);


while (my $row = $tsv_parser->getline_hr(*ARGV)) {
  my $sample = $row->{'Sample Name'};
  my $assay = $row->{'Assay Name'};
  my $phenotypes = $row->{'Characteristics [phenotypes]'};

  unless (defined $sample && defined $assay && defined $phenotypes) {
    warn "col data undefined - probable rogue newline";
    next;
  }

  foreach my $phenotype (split /\s*;\s*/, $phenotypes) {
    my ($type, $value) = split /\s*:\s*/, $phenotype;
    next unless (defined $type && defined $value); # there are some double semicolons e.g. study23
    $type =~ s/^\s+//;
    $value =~ s/\s+$//;

    my $onto_acc = $IRTypes::name2acc{$type};
    print join("\t",
	       $sample,   # 'Sample',
	       $assay,    # 'Assay',
	       0,         # 'prop?',
	       '',        # 'Name',
	       $onto_acc, # 'Entity ID',
	       $type,     # 'Entity Name',
	       '',        # 'Attribute ID',
	       '',        # 'Attribute Name',
	       '',        # 'Quality ID',
	       '',        # 'Quality Name',
	       $value,    # 'Value',
	       '',        # 'Unit ID',
	       '',        # 'Unit Name',
	       '',        # 'Date Created'
	      )."\n";
  }
}
