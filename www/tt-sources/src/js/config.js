/* no trailing slashes (especially for REST url) */

configTxt = {
    'REST':'[% json_root %]',
    'ROOT':'[% root %]',
    'VBROOT':'[% vb_root %]',
    'ROOT_STATIC':'[% root_static %]',
    'linkouts' : {
	'MR4 accession' : 'https://www.beiresources.org/Catalog/BEINucleicAcids/####.aspx',
	'BioSamples accession' : 'http://www.ebi.ac.uk/biosamples/sample/####',
        'UCDavis ID' : 'https://popi.ucdavis.edu/PopulationData/DataViews/indiv.php?id=####',
	'PubMed ID' : 'http://www.ncbi.nlm.nih.gov/pubmed/####',
	'GenBank ID' : 'http://www.ncbi.nlm.nih.gov/nuccore/####'
    }
};

var config = eval(configTxt);
