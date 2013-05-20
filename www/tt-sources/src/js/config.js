/* no trailing slashes (especially for REST url) */

configTxt = {
    'REST':'[% json_root %]',
    'ROOT':'[% root %]',
    'ROOT_STATIC':'[% root_static %]',
    'linkouts' : {
	'MR4 accession' : 'http://www.mr4.org/MR4ReagentsSearch/Results.aspx?BEINum=####&Template=livingMosquitoes',
	'BioSamples accession' : 'http://www.ebi.ac.uk/biosamples/sample/####'
    }
};

var config = eval(configTxt);
