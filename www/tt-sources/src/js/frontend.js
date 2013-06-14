/*
 * Dependencies:
 *
 * prototype >1.7.0.0
 *
 * (pretty JSON for sandbox only) json2.js (https://github.com/douglascrockford/JSON-js/blob/master/json2.js)
 *
 * phenovis >0.01
 *
 *
 */

    if (typeof console=="undefined") {
	console={log:function(message) { } }
    }

/*
 * renders sample info "full page" info into the div provided
 *
 * arg1: json object
 * arg2: Prototype Element
 *
 *
 * note: the (code within the) following two functions could go in
 * the actual HTML page source callbacks (although updateAssayFull() may
 * get quite large)
 *
 */

function updateSampleFull(stock, element) {
    fillInObjectValues(stock, element.down('#sample_info')).removeClassName('hide_on_load');

    var sprojects = element.down('#sample_projects');
    var url = 'sample/'+stock.id+'/projects/head';
    var spinner = sprojects.down('.vbpg_progress');


    // fill in field collections separately
    if (stock.field_collections.size()) {
	var scollections = element.down('#sample_collections');
	fillInListValues(stock.field_collections, scollections).removeClassName('hide_on_load');
    }

    // gather everything that is not a field collection
    var real_assays = stock.species_identification_assays.concat(stock.genotype_assays, stock.phenotype_assays, stock.sample_manipulations);
    if (real_assays.size()) {
	var sassays = element.down('#sample_assays');
	fillInListValues(real_assays, sassays).removeClassName('hide_on_load');
    }

    var limits = {
	offset: 0,
	limit: 20
    };

    getPagedObjects(url,
		    limits,
		    spinner,
		    function(page) {
			fillInPagedListValues(page, sprojects, url, limits).down('.hide_on_load').removeClassName('hide_on_load');
		    });

    // fill in assays' project provenance (at least the first 5)

    var assay_projects = $$('.list_row_instance .assay_projects');
    var max_projects = 4;
    var limits = { offset: 0, limit: max_projects };
    assay_projects.each(function(element) {
	var assay_id = element.id;
	getPagedObjects('assay/'+assay_id+'/projects/head', limits, null,
			function(projects) {
			    // console.log("got response for "+assay_id+" count = "+projects.count);
			    var ul = new Element('ul');
			    projects.records.each(function(project) {
				var li = new Element('li');
				li.insert(
				    { bottom: new Element('a', { href: config.ROOT+'project/?id='+project.id }).update(project.id) });
				ul.insert({ bottom: li });
			    });

			    if (projects.count > max_projects) {
				var li = new Element('li');
				li.insert({ bottom: new Element('a', { href: config.ROOT+'assay/?id='+assay_id }).addClassName('more_assay_projects').update('...') });
				ul.insert({ bottom: li });
			    }

			    element.insert({ bottom: ul });
			});
    });

    return element;
}

/*
 * renders assay info into the div provided
 *
 * arg1: json object
 * arg2: Prototype Element
 *
 *
 * 
 */

function updateAssayFull(assay, element) {
    var species_div = element.down('#species_results');

    // general props cleanup
    assay.props.each(function(prop) {
	if (prop.cvterms[0].name == 'species list') {
	    prop.cvterms[0] = { name: 'species assay result', accession: 'temp:hack' };
	}
	prop.cvterms[0].name = prop.cvterms[0].name.replace(/_/g, " "); // e.g. for reference_genome
    });

    fillInObjectValues(assay, element.down('#assay_info')).removeClassName('hide_on_load');

    if (assay.protocols.size()) {
	var protocols_div = element.down("#assay_protocols");
	fillInListValues(assay.protocols, protocols_div).removeClassName('hide_on_load');
	deactivate(protocols_div);
    }

    /***** field collection *****/
    if (assay.type == 'field collection') {
	var geoloc_div = element.down('#assay_geolocation_info');
	fillInObjectValues(assay.geolocation, geoloc_div).removeClassName('hide_on_load');

	var map_panel = $('mini_map_panel');
	if (map_panel) {
	    if (assay.geolocation &&
		assay.geolocation.latitude &&
		assay.geolocation.longitude &&
		assay.geolocation.name) {
		var vis = {
		    "type": "geoplot",
		    "x": "$.geolocation.latitude",
		    "y": "$.geolocation.longitude",
		    "z": "$.geolocation.name",
		    "e": "$.geolocation"
		};
		renderVisualisation(assay, vis, map_panel);
	    } else {
		map_panel.hide();
	    }
	}
    }

    // phenotypes
    if (assay.type == 'phenotype assay' && assay.phenotypes.size()) {
	var pheno_div = element.down('#assay_phenotypes');
	fillInListValues(assay.phenotypes, pheno_div).removeClassName('hide_on_load');
    }

    // genotypes
    if (assay.type == 'genotype assay' && assay.genotypes.size()) {
	var geno_div = element.down('#assay_genotypes');
	fillInListValues(assay.genotypes, geno_div).removeClassName('hide_on_load');
    }

    var estocks = element.down('#assay_stocks');
    var spinner = estocks.down('.vbpg_progress');
    var url = 'assay/'+assay.id+'/stocks/head';

    var eprojects =  element.down('#assay_projects');
    var spinner2 = eprojects.down('.vbpg_progress');
    var url2 = 'assay/'+assay.id+'/projects/head';

    var limits = {
	offset: 0,
	limit: 20
    };

    getPagedObjects(url2,
                    limits,
                    spinner2,
                    function(page) {
			fillInPagedListValues(page, eprojects, url2, limits).down('.hide_on_load').removeClassName('hide_on_load');
                    });

    getPagedObjects(url,
                    limits,
                    spinner,
                    function(page) {
			fillInPagedListValues(page, estocks, url, limits).down('.hide_on_load').removeClassName('hide_on_load');
                    });

    return element;
}


/*
 * renders project info into the div provided
 *
 * arg1: json header object
 * arg2: Prototype Element
 *
 *
 * 
 */

function updateProjectFull(project, element, sandbox) {
    if (sandbox && (sandbox == '0' || sandbox == 'false' || sandbox == 'no')) sandbox = 0;
    fillInObjectValues(project, element.down('#project_info')).removeClassName('hide_on_load');
    var index = 1;
    var vis_array = new Array();
    if (project.vis_configs && project.vis_configs.isJSON()) {
	vis_array = project.vis_configs.evalJSON();
	// TO DO: handle bad JSON better - it can cause a cryptic crash
    }

    if (sandbox) {
	vis_array.push({
	    "type": "geoplot",
	    "title": "default - change me",
	    "x": "$.stocks.*.field_collections.*.geolocation.latitude",
	    "y": "$.stocks.*.field_collections.*.geolocation.longitude",
	    "z": "$.stocks.*.species.name",
	    "e": "$.stocks.*.field_collections[?(@.geolocation.latitude && @.geolocation.longitude)]]"
	});

    }

    fillInListValues(vis_array, element.down('#project_visualisations'), 'no_shading').removeClassName('hide_on_load');


    if (vis_array.size())	assembleProject(project, $('project_load_status'));

    // fill in all textareas if we are in sandbox mode
    if (sandbox) {
	var textAreas = element.down('#project_visualisations').select('.list_row_instance textarea');
	vis_array.each(function(vis){ textAreas.shift().update(JSON.stringify(vis, null, 2)); });
    }

    var pstocks = element.down('#project_stocks');
    var spinner = pstocks.down('.vbpg_progress');
    var url = 'project/'+project.id+'/samples/head';
    var limits = {
	offset: 0,
	limit: 20,
    };

    getPagedObjects(url,
		    limits,
		    spinner,
		    function(page) {
			fillInPagedListValues(page, pstocks, url, limits).down('.hide_on_load').removeClassName('hide_on_load');
		    });

    // now check every 2s for the full project to be loaded before loading the visualisations.

    var tabnav = $('tabnav');

    if (vis_array.size()) {
	// first set up the tabs and titles etc
	var row_instances = $$('#project_visualisations .list_row_instance');
	var tabnum = 0;
	vis_array.each(function(vis) {
	    var row_instance = row_instances.shift();

	    // add the tab navigation item
	    var tab = new Element('li');
	    var tablink = new Element('a', { id: 'tab_'+tabnum, href:'#'+tabnum });
	    tablink.addClassName('tab');
	    tablink.update(vis.title);
	    tab.insert({ bottom: tablink });
	    tabnav.insert({ bottom: tab });
	    // add the correct id and class to the content panel for stereotabs
	    row_instance.writeAttribute('id', 'panel_'+tabnum).addClassName('panel');
	    tabnum++;
	});
	
	// activate the stereotabs
	var tabs = new tabset('project_visualisations'); // name of div to crawl for tabs and panels
	tabs.autoActivate($('tab_0')); // name of tab to auto-select if none exists in the url

	// then wait for the project to be loaded
	// and set up rendering handlers
	new PeriodicalExecuter(function(pe) {
  	    if (project.complete) {
		pe.stop();
		vis_panels = $$('.list_row_instance .vis_panel');
		if (vis_panels.size() == vis_array.size()) {
		    var tabnum = 0;
		    vis_array.each(function(vis) {
			var vis_panel = vis_panels.shift();
			var row_instance = vis_panel.up('.list_row_instance');
			if (vis.title != "default - change me") {
			    row_instance.observe('tab:selected', function(event) {
				if (!vis.rendered) renderVisualisation(project, vis, vis_panel);
				vis.rendered = true;
			    });
			}
			tabnum++;

			if (sandbox) {
			    // add the 'render' button
			    var textArea = row_instance.down('textarea');
			    var button = new Element('input', { style: 'margin-left: 10px;', type: 'button', value: 'render' });
			    textArea.up('div.sandbox').removeClassName('hide_on_load');

			    button.observe('click', function(event) {
				if (project.complete) {
				    var textArea = event.element().previous('textarea');
				    var vis = String.interpret(textArea.value).evalJSON();
				    var vis_panel = textArea.up('.list_row_instance').down('.vis_panel');
				    renderVisualisation(project, vis, vis_panel);
				    if (vis.title) vis_panel.up('.list_row_instance').down('#title').update(vis.title);
				}
			    } );
			    textArea.insert({ after: button });
			}
		    });

		    // artificially select the tab again to force rendering
		    var row_instances = $$('#project_visualisations .list_row_instance');
		    var active_tab_index = tabs.getHash() || 0;
		    row_instances[active_tab_index].fire('tab:selected');

		} else {
		    //console.log(vis_array);
		    //console.log(vis_panels);
		    console.log("different number of vis properties in project and vis_panels in page");
		}
	    }
	}, 1);
    }

}

/*
 * renderVisualisation(project, vis, vis_panel)
 *
 *
 *
 */

function renderVisualisation(project, vis, vis_panel) {
    try {
	var hashJSP = getFilteredDataHash_jsp(project,vis);
	// console.log(vis);
	// console.log(hashJSP);
	

	vis_panel.identify();	// in case it has no id
	vis_panel.style.width = vis_panel.getWidth(); // in case the dimensions
	vis_panel.style.height = vis_panel.getHeight(); // are in stylesheet

	callPlot(vis.type, hashJSP, vis_panel, vis.args);
    } catch(err) {
	vis_panel.update("The visualisation config may be incorrect or not appropriate for this project.<br><pre>"+err+"</pre>");
    }
}

/*
 * getFilteredDataHash_jsp(project, vis)
 *
 * wrapper for getDataHash_jsp, applying front-end/VectorBase specific vis.filters to the results
 *
 */

function getFilteredDataHash_jsp(project, vis) {
    var hashJSP = getDataHash_jsp(project,vis.e,vis.x,vis.y,vis.z);

    if (vis.filters) {
	if (vis.filters.histogram) {
	    var counts = { };
	    hashJSP.each(function(hash) {
		var xval = hash.x !== false ? hash.x : 'no data';
		var zval = hash.z !== false ? hash.z : 'no data';
		if (!counts[xval]) counts[xval] = {};
		if (!counts[xval][zval]) counts[xval][zval] = 0;
		counts[xval][zval] += 1;
	    });

	    // new hash just using the number of times each combination of x and z is seen
	    // y input is ignored
	    hashJSP = new Array()
	    for (var xval in counts) {
		for (var zval in counts[xval]) {
		    var count = counts[xval][zval];
		    hashJSP.push({ x: xval, y: count, z: zval });
		}
	    }
	    
	}

	if (vis.filters.noFalseZ) {
	    /*
	     * we don't want to encourage filtering away points from the dataset
	     * because we will probably have more dynamic z labelling (by exptal factor radio buttone)
	     */
	    console.log("Advance warning: vis.filters.noFalseZ will be deprecated and is not recommended");
	    hashJSP = hashJSP.filter(function(hash){ return hash.z !== false; });
	}

    }

    // compulsory false -> "no data" filter on z
    hashJSP = hashJSP.each(function(hash){ if (hash.z === false) { hash.z = 'no data' } });

    return hashJSP;
}


/*
 * automagically fills in data to a div
 *
 * elements with class==object_value and one of [scalar, cvterm] and id="xxx" will
 * have their content replaced with object.xxx
 * there's a further 'action' called 'clear_if_missing' - see code comments below for details
 *
 * elements with class=="object_id href" will do a s/####/object.id/e on the href
 * attribute of the element.
 *
 * elements with class=="object_id id" will do a s/####/object.id/e on the id
 * attribute of the element.
 *
 * elements with class=="auto_link" will have the element.href =~ s/####/element.innerHTML.stripTags/e
 *
 * elements with class==capitalize will capitalize the content after it has been injected (strips HTML tags!)
 *
 * ditto class=="nested_object_list" id=="xxxs" will populate a list template using the list returned by object.xxxs
 *
 * it's the caller's responsibility to manage spinners and make it visible afterwards
 *
 * note: call this on inner-most nested (in terms of DOM) elements FIRST
 *       as all elements are cleared of the object_value and object_id classes
 *       to avoid being overwritten
 */

function fillInObjectValues(object, element) {

    // first do any nested lists (only one level guaranteed to work)
    element.select('.nested_object_list').each(function(e){
	var items = jsonPath(object, '$.'+e.id).first();
	fillInListValues(items, e);
	deactivate(e);
    });

    element.select('.nested_props_list').each(function(e){
	fillInProps(object.props, e, e.hasClassName('no_shading'));
	deactivate(e);
    });

    // now dow the non-list expansions
    element.select('.object_value.scalar').each(function(e){
	e.update(jsonPath(object, '$.'+e.id) || '');
    });

    element.select('.object_value.comma_separated').each(function(e){
        items = jsonPath(object, '$.'+e.id);
	// console.log(Object.prototype.toString.call( items )+' and '+Object.prototype.toString.call( items.first() )); // it was a 2D array [['item1', 'item2']]
	if (items != null) {
	    // if the first element is another array we'll join that instead
	    if (Object.prototype.toString.call(items.first()) === '[object Array]') {
		items = items.first();
	    }
	    e.update(items.join(', '));
	}
    });

    element.select('.object_value.cvterm').each(function(e){
	e.update(renderCvterm(jsonPath(object, '$.'+e.id).first())); // renderCvterm can't handle a list of one
    });
    
    // this one only does s/####/object.id/e on the element's href attribute
    // the <a ...> element does not need an id attribute
    element.select('.object_id.href').each(function(e){
	var href = e.readAttribute('href');
	e.writeAttribute('href', href.sub(/####/, object.id));
    });

    // this one is more general purpose
    element.select('.object_value.href').each(function(e){
	var href = e.readAttribute('href');
	e.writeAttribute('href', href.sub(/####/, jsonPath(object, '$.'+e.id) || ''));
    });


    element.select('.object_id.id').each(function(e){
	var id = e.readAttribute('id');
	e.writeAttribute('id', id.sub(/####/, object.id));
    });

    element.select('.auto_link').each(function(e){
	var href = e.readAttribute('href');
	e.writeAttribute('href', href.sub(/####/, e.innerHTML.stripTags()));
    });

    element.select('.object_value.capitalize').each(function(e){
	e.update(e.innerHTML.stripTags().capitalize());
    });

    // this one clears an element if the specified field is missing
    // initial use case: geo coords are displayed with a comma between spans for lat and long
    // however, when geo coords are missing you just see the comma
    // if you wrap those spans in a clear_if_missing element for, say, latitude, all is well
    element.select('.object_value.clear_if_missing').each(function(e){
	var value = jsonPath(object, '$.'+e.id);
	if (!value || Object.toHTML(value).blank()) e.update();
    });


    // add n/a if empty
    element.select('.na_if_empty').each(function(e){if (e.empty()) { e.update('n/a'); }});

    // add <br> after if NOT empty
    element.select('.linebreak_after').each(function(e){if (!e.empty()) { e.insert({ after: "<br />"}) }});

    // now clear the element classes so that the updated content cannot be overwritten
    return element;
}

/*
 * removes auto-fill classes from element
 *
 *
 */

function deactivate(element) {
    element.select('.object_value').each(function(e){ e.removeClassName('object_value'); });
    element.select('.object_id').each(function(e){ e.removeClassName('object_id'); });
    element.select('.auto_link').each(function(e){ e.removeClassName('auto_link'); });
    return element;
}

/*
 * looks for list_row_template and duplicates it with
 * each item of list
 *
 *
 */

function fillInListValues(list, element, no_even_odd_shading) {
    // remove any existing list_row_instances
    element.select('.list_row_instance').each(function(row){ row.remove() });

    var list_row_template = element.select('.list_row_template').first();  // shouldn't be >1!
    var last_row = list_row_template;
    var row_num = 0;
    if (list && list.size()) {
	list.each(function(item) {
	    var new_row = list_row_template.clone(true).removeClassName('list_row_template').addClassName('list_row_instance');
	    if (!no_even_odd_shading) new_row.addClassName(row_num % 2 == 0 ? 'even_row' : 'odd_row');
	    last_row.insert({ after: fillInObjectValues(item, new_row) });
	    last_row = new_row;
	    row_num++;
	});
    } else {
	// blank out if no items
	element.update();
    }
    return element;
}

/*
 * looks for list_row_template and duplicates it with
 * each item of list rendered as a multiprop
 * 
 *
 */

function fillInProps(list, element, no_even_odd_shading) {
    // remove any existing list_row_instances
    element.select('.list_row_instance').each(function(row){ row.remove() });

    var list_row_template = element.select('.list_row_template').first();  // shouldn't be >1!
    var last_row = list_row_template;
    var row_num = 0;
    if (list && list.size()) {
	list.each(function(item) {
	    var new_row = list_row_template.clone(true).removeClassName('list_row_template').addClassName('list_row_instance');
	    if (!no_even_odd_shading) new_row.addClassName(row_num++ % 2 == 0 ? 'even_row' : 'odd_row');

	    last_row.insert({ after: fillInProp(item, new_row) });
	    last_row = new_row;
	});
    } else {
	// blank out if no items
	element.update();
    }
    return element;
}

/*
 * takes an element and updates the content of the child element of class 'prop'
 * with specially formatted multiprop information
 * (e.g. handling units)
 *
 * two sub-elements are filled in:
 *   class=prop_type holds the type of information (column heading from isa-tab)
 *   class=prop_value holds the value
 * the prop_type element can have attribute delimiter="xx"
 */

function fillInProp(prop, element) {
    var type_element = element.down('.prop_type');
    var value_element = element.down('.prop_value');
    // separate the units cvterms away from the normal terms
    var units = prop.cvterms.filter(function(term){return term.accession.match(/^UO:/)});
    var cvterms = prop.cvterms.reject(function(term){return term.accession.match(/^UO:/)});
    var delimiter = type_element.readAttribute('delimiter') || ', ';
    // now build the text to be displayed

    var comment_type;
    if (prop.value) {
	if (units.size()) {
	    value_element.update(prop.value + " ("+renderCvterm(units.first())+")");
	} else {
	    if (cvterms.first().name == 'comment') {
		// special treatment for comments
		// save the content of square brackets for the left hand side
		var match=prop.value.match(/\[(.+?)\]/);
		if (match.size() > 1) {
		    comment_type = match[1];
		}
		var comment_text = prop.value.replace(/\[.+?\]\s+/, "");
		if (comment_type && config.linkouts[comment_type]) {
		    var url = config.linkouts[comment_type];
		    url = url.replace(/####/, comment_text);
		    value_element.update(); // empty any pre-existing content
		    var link = new Element('a', { href: url });
		    link.addClassName('external_link').update(comment_text);
		    // and add the new link
		    value_element.insert({ top: link });
		} else {
		    value_element.update(comment_text);
		}
	    } else {
		value_element.update(prop.value);
	    }
	}
    } else if (cvterms.size() > 1) {
	// display the last cvterm as the value
	value_element.update(renderCvterm(cvterms.pop()));
    }
    // now fill in the type element
    if (comment_type != null) {
	type_element.update("comment ["+comment_type+"]");
    } else {
	type_element.update(cvterms.collect(function(term){return renderCvterm(term)}).join(delimiter));
    }
    return element;
}

/*
 * processes the page object and updates the pager info
 * before populating the list as with fillInListValues()
 *
 */

function fillInPagedListValues(page, element, url, limits) {

    // update the pager div(s) (don't have to be divs)
    var pagers = element.select('.vbpg_pager');
    var spinner = element.down('.vbpg_progress');

    if (page.count > limits.limit) {
	pagers.each(function(pager){ 
	    fillInObjectValues(page, pager);
	    pager.removeClassName('hide_unless_paging');
	    var next = pager.down('.vbpg_pager_next');
	    var last = pager.down('.vbpg_pager_last');
	    if (page.end == page.count) {
		next.purge(); // remove event handlers
		next.addClassName('vbpg_pager_inactive');
		last.purge(); last.addClassName('vbpg_pager_inactive');
	    } else {
		var next_callback = function(event) {
		    element.down('.hide_on_update').addClassName('vbpg_pager_pending');
		    getPagedObjects(url,
				    {
					offset: page.start+limits.limit-1,
					limit: limits.limit
				    },
				    spinner && spinner.show(),
				    function(p) { // p is for page
					fillInPagedListValues(p, element, url, limits).down('.hide_on_update').removeClassName('vbpg_pager_pending');
				    });
		};
		next.purge();
		next.observe('click', next_callback);
		next.removeClassName('vbpg_pager_inactive');

		var last_callback = function(event) {
		    element.down('.hide_on_update').addClassName('vbpg_pager_pending');
		    var last_offset = 0; // might be quicker with int or floor and division!
		    while (last_offset < page.count-limits.limit) { last_offset += limits.limit; }
		    console.log("setting last_offset "+last_offset);
		    getPagedObjects(url,
				    {
					offset: last_offset,
					limit: limits.limit
				    },
				    spinner && spinner.show(),
				    function(p) { // p is for page
					fillInPagedListValues(p, element, url, limits).down('.hide_on_update').removeClassName('vbpg_pager_pending');
				    });
		};
		last.purge();
		last.observe('click', last_callback);
		last.removeClassName('vbpg_pager_inactive');
	    }
	    var prev = pager.down('.vbpg_pager_prev');
	    var first = pager.down('.vbpg_pager_first');
	    if (page.start == 1) {
		prev.addClassName('vbpg_pager_inactive');
		prev.purge();
	    } else {
		var prev_callback = function(event) {
		    element.down('.hide_on_update').addClassName('vbpg_pager_pending');
		    getPagedObjects(url,
				    {
					offset: page.start-limits.limit-1,
					limit: limits.limit
				    },
				    spinner && spinner.show(),
				    function(p) { // p is for page
					fillInPagedListValues(p, element, url, limits).down('.hide_on_update').removeClassName('vbpg_pager_pending');
				    });
		};
		prev.purge();
		prev.observe('click', prev_callback);
		prev.removeClassName('vbpg_pager_inactive');

		var first_callback = function(event) {
		    element.down('.hide_on_update').addClassName('vbpg_pager_pending');
		    getPagedObjects(url,
				    {
					offset: 0,
					limit: limits.limit
				    },
				    spinner && spinner.show(),
				    function(p) { // p is for page
					fillInPagedListValues(p, element, url, limits).down('.hide_on_update').removeClassName('vbpg_pager_pending');
				    });
		};
		first.purge();
		first.observe('click', first_callback);
		first.removeClassName('vbpg_pager_inactive');

	    }
	    
	});
    }
    
    if (page.records && page.records.size()) {
	fillInListValues(page.records, element);
    } else {
	// blank out if no items
	element.update();
    }
    return element;
}

/*****
 * will probably return a smart span (with accession info and some suitable class) for a general javascript mouseover action
 * if non-numeric accession, just show plain text.
 */

function renderCvterm(term) {
    if (term != null) {
	if (term.accession.match(/^\w+:\d+$/)) {
	    if (term.accession.match(/^VBsp:/)) { // !!warning: copy and paste next two lines!!
		return '<span class="cvterm species_name" title="Ontology term '+term.accession+'" accession="'+term.accession+'">'+term.name+'</span>';
	    } else {
		return '<span class="cvterm" title="Ontology term '+term.accession+'" accession="'+term.accession+'">'+term.name+'</span>';
	    }
	} else {
	    return term.name;
	}
    } else {
	return '';
    }
}


/*
 * AJAX wrapper of a wrapper to get just one object by its url (NO app root; NO leading slash)
 *
 * e.g. project/123
 *
 */

function getObject(url, spinner, callback) {

    if (spinner) spinner.update(new Element('img', { src: config.ROOT_STATIC+'vbpg_images/bigrotation2.gif' }));

    new Ajax.Request(config.REST+url, {
	method:'get',
	requestHeaders: {Accept: 'application/json'},
	onSuccess: handleResponse,
	onFailure: function(t){alert('Sorry, an error occurred. '+url+' did not load.')},
    });
    
    function handleResponse(response) {

	// nasty hack to clean up eupathdb bug (IsolateByTaxon.json error message tacked on at the end of JSON)
	// response.responseText = response.responseText.sub(/]{.+/, ']}]}}}');
	
	var object = response.responseText.evalJSON();
	if (object) {
	    if (spinner) spinner.hide();
	    callback(object);
	} else {
	    console.log("problem evalling json from "+url);
	}
    }

}

/*
 * fills in project object sequentially called object array
 * 
 * Nb: this will fire of a set of ajax requests to build the object
 * it is up to you to check it is complete & in memory
 * 
 * to do: put object in dom storage rather than passing in scope
 */
function assembleProject (project, progress_div) {
    project.complete = 0;
    console.log("assembling project " + project.id);

    var spinner = null;
    //  var i = 0;
    var maxStocks = 1000; //any large number
    var stocks = new Array();
    //  alert(stocks.length);
    var limits = { 'offset': 0, 'limit': 50 };
    getPagedObjects('project/'+project.id+'/stocks', limits, null, addToProject);
    if (progress_div) progress_div.update("Loading samples...");

    function addToProject(response) {
	maxStocks = response.count;
	/*
	  i++;
	  console.log(i+" "+response.start+" ADDING: "+response.records.length+" stocks to "+stocks.length);
	  console.log(i+" "+response.start+" "+response.records);
	  console.log(i+" "+stocks.length+" + "+response.records.length);
	*/
	//newStocks = new Array(response.records);   
	stocks = stocks.concat(response.records);
	//    console.log(" = "+stocks.length);
	//    console.log(Object.toJSON(response.records));

	if (progress_div) progress_div.update(stocks.size()+" of "+maxStocks+" samples loaded");

	if(stocks.length < maxStocks) {
	    //      console.log("more!");
	    limits.offset = limits.offset+limits.limit;
	    getPagedObjects('project/'+project.id+'/stocks', limits, spinner, addToProject);
	}
	if(stocks.length == maxStocks) {
	    project.stocks = stocks;
	    project.complete = 1;
	    if (progress_div) {
		progress_div.update("All project data has loaded.");
		setTimeout(function(){ progress_div.hide() }, 1500);
	    }
	    console.log("project "+project.id+" all "+project.stocks.length+" stocks loaded");
	}
    }
}
/*
 * request objects that we know might come back in a pager wrapper
 *
 * bug: ignores spinner
 * to do: remove spinner arg or do something with it
 *
 */

function getPagedObjects(url, limits, spinner, callback) {

    if (spinner) spinner.update(new Element('img', { src: config.ROOT_STATIC+'vbpg_images/bigrotation2.gif' }));

    // should process limits into url params here:
    var params = '?o='+limits.offset+'&l='+limits.limit;

    new Ajax.Request(config.REST+url+params, {
	method:'get',
	requestHeaders: {Accept: 'application/json'},
	onSuccess: function(response) {
	    var page = response.responseText.evalJSON();
	    if (spinner) spinner.hide();
	    callback(page);
	},
	onFailure: function(t){alert('Sorry, an error occurred. '+url+' did not load')},
    });
}
