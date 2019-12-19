/*
Creator: Maya Norman
Date last modified: 12/3/19 
Last modified by: Maya

Purpose: Make 3 x 3 Arrays and Array Overlays dose responsewith heterogeneity by climate and by income

*/

****** Set Model Specification Locals ******************************************

local model_main = "$model_main" // What is the main model for this plot?
local var = "$product" // What product's response function are we plotting?
local submodel_ov = "$submodel_ov" // What submodel is gettting overlayed on this plot?

****** Set Plotting Toggles ****************************************************

// plotting color for main specification and overlay

local col "black"
local col_ov "red"

// year to plot tech trend model:

local year = 2099
			
********************************************************************************
* Step 1: Load Data and Clean for Plotting
********************************************************************************
		
use "$root/data/GMFD_`model'_regsort.dta", clear

//Set up locals for plotting
local obs = 35 + abs(-5) + 1

//clean data for plotting
drop if _n > 0
set obs `obs'

replace temp1_GMFD = _n - 6

foreach k of num 1/2 {
	rename temp`k'_GMFD temp`k'
	replace temp`k' = temp1 ^ `k'
}

********************************************************************************
* Step 2: Set up for plotting by: 
	* a) finding knot location 
	* b) assigning whether to plot an overlay or not
********************************************************************************

* Get Income Spline Knot Location 
	
preserve
use "$root/data/break_data_`model_main'.dta", clear
summ maxInc_largegpid_`var' if largegpid_`var' == 1
local ibar_main = `r(max)'
restore

/* if the underlying dataset differs for a given robustness model, 
the income spline knot location will vary because the income decile
locations are different.*/

if ( "`submodel_ov'" == "EX"  )
	preserve
	use "$root/data/break_data_`model_main'_`submodel_ov'.dta", clear
	summ maxInc_largegpid_`var' if largegpid_`var' == 1
	local ibar_ov = `r(max)'
	restore
}
else {
	local ibar_ov = `ibar_main'
}

* Set plotting locals and name tags 

local colorGuide " Model Spec: `model_main' (`col') "
local plot_title "`main_model'"
local fig "fig1b"

// create list of model types to loop over
local type_list " _main "

if ( "`submodel_ov'" != "" ) {
	
	// add to list of model types to loop over
	local type_list " `type_list' _ov "
	
	// create colorguide to help viewer decipher between overlayed spec and non overlayed spec
	local colorGuide "`colorGuide' Overlay Spec: `model_main'_`submodel_ov' (`col_ov') "

	local plot_title "main_model_`plot_title'_overlay_model_`submodel_ov'"

	if "`submodel_ov'" == "decinter" {
		local fig "A14"
	}
	else if "`submodel_ov'" == "lininter" {
		local fig "A15b"
	}
	else if "`submodel_ov'" == "EX" {
		local fig "A13"
	}

}						

********************************************************************************
* Step 3: Plot, Plot, Plot
********************************************************************************

// create locals to populate with sub plots
local graphicM=""
local graphicM_noSE=""

forval lg=3(-1)1 {	//Income tercile
	forval tr=3(-1)1 {	//Tmean tercile

		// create cellid for labeling each subplot
		local cellid=`lg'+`tr'*100
		
		// grab income and climate covariates to trace out response for this cell
		preserve
		use "$root/data/break_data_`model_main'.dta", clear
		duplicates drop tpid tgpid, force
		sort tpid tgpid 
		local tr_index = `tr' * 3 // create index for grabbing the long run climate to plot in each cell
		local subCDD = avgCDD_tpid[`tr_index']
		local subHDD = avgHDD_tpid[`tr_index']
		local subInc = avgInc_tgpid[`lg']
		restore

			
		// set up plotting locals for sub plot
		loc SE ""
		loc noSE ""
		
		// assign fuel index to trace out proper dose response
		if "`var'"=="electricity" {
			local pg=1
		}
		else if "`var'"=="other_energy" {
			local pg=2
		}

		// loop over plotting models
		foreach type in `type_list' {
			
			// assign model to be plotted
			if (strpos("`type'", "ov") > 0) {
				local plot_model = "`model_main'_`submodel'"
			}
			else {
				local plot_model = "`model_main'"
			}
			
			// construct income spline
			local deltacut_subInc = `subInc' - `ibar`type''

			// assign the large income group based on the cell's income covariate
			
			if `subInc' > `ibar`type'' local ig = 2
			else if `subInc' <= `ibar`type'' local ig = 1
			
			// make local to plot last decade robustness model

			if (strpos("`plot_model'", "decinter") > 0) {
				local D = "D4"
			}
			
			// create dose response function equation

			local line ""
			local add ""
			
			foreach k of num 1/2 {
				
				local line = " `line' `add' _b[c.indp`pg'#c.indf1#c.FD_`D'temp`k'_GMFD] * (temp`k' - 20^`k')"
				local line = "`line' + above`midcut'*_b[c.indp`pg'#c.indf`fg'#c.FD_cdd20_TINVtemp`k'_GMFD]*`subCDD' * (temp`k' - 20^`k')"
				local line = "`line' + below`midcut'*_b[c.indp`pg'#c.indf`fg'#c.FD_hdd20_TINVtemp`k'_GMFD]*`subHDD' * (20^`k' - temp`k')"
				local line = "`line' + _b[c.indp`pg'#c.indf`fg'#c.FD_dc1_lgdppc_MA15I`ig'temp`k']*`deltacut_subInc'*(temp`k' - 20^`k')"

				if (strpos("`plot_model'", "lininter") > 0) {
					local line = "`line' + _b[c.indp`pg'#c.indf`fg'#c.FD_yeartemp`k'_GMFD] * (temp`k' - 20^`k')*`year'"
					local line = "`line' + _b[c.indp`pg'#c.indf`fg'#c.FD_dc1_lgdppc_MA15yearI`ig'temp`k']*`deltacut_subInc'*`year'*(temp`k' - 20^`k')"
				}

				local add " + "

			}
			
			// trace out does response equation and add to local for plotting 
			estimates use "`data'/`clim_data`type''/rationalized_code/`data_type'/sters/FD`FGLS`type''/`ster'"
			predictnl yhat`cellid'`type' = `line', se(se`cellid'`type') ci(lower`cellid'`type' upper`cellid'`type')

			loc SE = "`SE' rarea upper`cellid'`type' lower`cellid'`type' temp1, col(`col`type''%30) || line yhat`cellid'`type' temp1, lc (`col`type'') ||"
			loc noSE = "`noSE' line yhat`cellid'`type' temp1, lc (`col`type'') ||"
			
		}
		
		//plot with SE
		tw `SE' , yline(0, lwidth(vthin)) xlabel(-5(10)35, labsize(vsmall)) ///
		ylabel(, labsize(vsmall) nogrid) legend(off) ///
		subtitle("", size(vsmall) color(dkgreen)) ///
		ytitle("", size(vsmall)) xtitle("", size(small)) ///
		plotregion(color(white)) graphregion(color(white)) nodraw  ///
		name(Maddgraph`cellid', replace)
		//add graphic with SE
		local graphicM = "`graphicM' Maddgraph`cellid'"


		//plot with no SE
		tw `noSE' , yline(0, lwidth(vthin)) xlabel(-5(10)35, labsize(vsmall)) ///
		ylabel(, labsize(vsmall) nogrid) legend(off) ///
		subtitle("", size(vsmall) color(dkgreen)) ///
		ytitle("", size(vsmall)) xtitle("", size(small)) ///
		plotregion(color(white)) graphregion(color(white)) nodraw ///
		name(Maddgraph`cellid'_noSE, replace)			
		//add graphic no SE
		local graphicM_noSE="`graphicM_noSE' Maddgraph`cellid'_noSE"
	}
}


// Plot arrays and save

//combine cells with SE
graph combine `graphicM', imargin(zero) ycomm rows(3) ///
title("Split Degree Days Poly 2 Interaction Model `var'", size(small)) ///
subtitle("`colorGuide'", size(vsmall)) ///
plotregion(color(white)) graphregion(color(white)) name(comb, replace)
graph export "$root/figures/`fig'_`var'_interacted_`plot_title'_noSE.pdf", replace

//combine cells no SE
graph combine `graphicM_noSE', imargin(zero) ycomm rows(3) ///
title("Split Degree Days Poly 2 Interaction Model `var'", size(small)) ///
subtitle("`colorGuide'", size(vsmall)) ///
plotregion(color(white)) graphregion(color(white)) name(comb_nose, replace)
graph export "$root/figures/`fig'_`var'_interacted_`plot_title'_noSE.pdf", replace

graph drop _all	
