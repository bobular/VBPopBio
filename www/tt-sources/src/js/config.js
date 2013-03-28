/* no trailing slashes (especially for REST url) */

configTxt = {
	'REST':'[% json_root %]',
  'ROOT':'[% root %]',
'ROOT_STATIC':'[% root_static %]'
};

var config = eval(configTxt);
