******************************************
** 8_1c cox regression 
**
** Cox regression 
******************************************

*==== define key date of wave 
global wave1 = date("15Dec2020" , "DMY" ) // when wild-type ends 
global wave2 = date("15May2021" , "DMY") // when alpha ends 
global wave3 = date("15Dec2021" , "DMY") // when delta ends

global lockdown1start = date("23Mar2020" , "DMY") // first lockdown starts
global lockdown1end = date("23Jun2020" , "DMY") // first lockdown ends 
global lockdown2start = date("31Oct2020" , "DMY") // second lockdown starts
global lockdown2end = date("2Dec2020" , "DMY") // second lockdown ends 

global cox_option "level(95)"
global cox_option2 "level(99)"

******************************************
* Planned admission 
******************************************

use "$derived_data_path\8_1a2_planned_admission_birth_conceived_feb2020jul2020.dta" , clear 

*==== keep the first planned admission only , look at time to the first admission 

* The dataset include only the first episode of each admission 

* flag the first planned admission for each child 
bysort tokenid (adm_no) : gen planadm_order = _n

keep if planadm_order==1 // keep only the first admission or the record of the child (if the child does not have admission) 

*==== clean birth day and date of death 
gen bday_raw = bday 
format bday_raw %td

capture drop tmp*

gen tmp1 = string(bday , "%td")

gen tmp2= substr(tmp1 , 1 , 2 )

gen tmp3 = mofd(admidate) // month of admission date 
format tmp3 %tm 

// some children died on the same day of birthday or before birthday, so have 0 follow-up time and would be excluded automatically from calculating rates and cox-regressions. For these children, change the date of death to one day after birthday, so that they will be included in the anlaysis 
gen tmp4 = mofd(dod)
format tmp4 %tm 

replace dod = bday+1 if dod==bday_raw & death==1 
replace bday = dod-1 if death==1 & dod<bday & tmp2=="15" & tmp4==month_bday 

capture drop tmp* 


*==== set survival analysis variable 
gen censordate = round(bday + 365.25*2.5 , 1) 
format censordate %td 

**---- end time point 
* date of the first admission 
gen finalcensor1=censordate
replace finalcensor1 = admidate if admidate!=. & admidate<=censordate
format finalcensor1 %td 
* date of death 
gen finalcensor2 = censordate
replace finalcensor2 = dod if dod!=. & dod<=censordate
format finalcensor2 %td 
* final censor date 
gen finalcensor = min(finalcensor1 , finalcensor2)
format finalcensor %td 
label variable finalcensor "2.5y birthday, first admission, death, whichever the earliest"

drop finalcensor1 finalcensor2 censordate

**---- outcome 
gen outcome=0
replace outcome=1 if admidate!=. & admidate<=finalcensor

**---- time to event (exposed time)
gen time_days=finalcensor-bday

**---- declaire 
stset time_days , failure(outcome) scale(365.25) id(tokenid)

* recode matage_compl to small groups 
recode matage_compl (min/24=1 "<25") (25/29=2 "25-29") (30/34=3 "30-34") (35/39=4 "35-39") (40/max=5 ">=40") (.=.) , gen(matage_catd) 

label variable matage_catd "maternal age"

**---- save data 
save "$derived_data_path/8_1c1_first_episode_first_non-birth_planned_admission.dta" , replace 

use "$derived_data_path/8_1c1_first_episode_first_non-birth_planned_admission.dta" , clear 

**==== KM curve

* England  
sts graph , by(infect_variant) failure legend(pos(6) row(1)) xtitle("Age in years") title("Planned admission") legend(label(1 "Negative") label(2 "Wild-type") label(3 "Alpha") label(4 "Untested")) plot1opts(lcolor(green)) plot2opts(lcolor(orange)) plot3opts(lcolor(red)) plot4opts(lcolor(blue)) name(planned , replace) saving(planned_england , replace) ylabel(0 0.05 0.1 ) ytitle("Proportion having a planned admission") 

graph export "$output_path\8_1c1_KM_planned_admission_2halfy_England.png" , replace 

*==== Main analysis - Cox regression

**---- models 
* sample size for cox regression 
count if ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. 

* crude model 
stcox i.infect_variant ///
	if ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. & londonres!=. , $cox_option2 
	
est store plan0 

* + mother ethnicity 
stcox i.infect_variant ///
	ib5.ethgroup_mother_compl /// 
	if ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. , $cox_option2
	
est store plan1 

* + baby imd04 decile 
stcox i.infect_variant ///
	ib5.ethgroup_mother_compl /// 
	i.imd04decile_mother_compl /// 
	if ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. , $cox_option2
	
est store plan2 

* + mother's chronic condition 
stcox i.infect_variant ///
	ib5.ethgroup_mother_compl /// 
	i.imd04decile_mother_compl /// 
	i.mcc_yorn ///
	if ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. , $cox_option2
	
est store plan3 


* + maternal age 
stcox i.infect_variant ///
	ib5.ethgroup_mother_compl /// 
	i.imd04decile_mother_compl /// 
	i.mcc_yorn ///
	i.matage_catd ///
	if ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=.  & matage_compl!=. , $cox_option2
	
est store plan4 

* + london residence 
stcox i.infect_variant ///
	ib5.ethgroup_mother_compl /// 
	i.imd04decile_mother_compl /// 
	i.mcc_yorn ///
	i.matage_catd ///
	i.londonres /// 
	if ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. &  matage_compl!=. , $cox_option2
est store plan5


* + month_conception
stcox i.infect_variant ///
	ib5.ethgroup_mother_compl /// 
	i.imd04decile_mother_compl /// 
	i.mcc_yorn ///
	i.matage_catd ///
	i.londonres /// 
	i.month_conception /// 
	if ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. , $cox_option2 cformat(%9.2f)
est store plan6

**---- proportional hazard assumption 

* time-dependent variant 
stcox i.infect_variant ///
	ib5.ethgroup_mother_compl /// 
	i.imd04decile_mother_compl /// 
	i.mcc_yorn ///
	i.matage_catd ///
	i.londonres /// 
	i.month_conception /// 
	if ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. , $cox_option2 nohr 

est store planned_notime 

stcox i.infect_variant ///
	ib5.ethgroup_mother_compl /// 
	i.imd04decile_mother_compl /// 
	i.mcc_yorn ///
	i.matage_catd ///
	i.londonres /// 
	i.month_conception /// 
	if ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. , $cox_option2 nohr tvc(i.infect_variant) texp(ln(_t))
	
est store planned_time

lrtest planned_notime planned_time 


*---- impact of trimester of infection on child admission 

gen tmp1 = (positive_term1==1)
gen tmp2 = (positive_term2==1)
gen tmp3 = (positive_term3==1)

gen tmp4 = tmp1 + tmp2 + tmp3 
gen positive_term = 1 if tmp1==1 
replace positive_term = 2 if tmp2==1 
replace positive_term = 3 if tmp3==1 
replace positive_term = . if tmp4>1 
capture drop tmp* 

stcox i.infect_variant ib2.positive_term if positive_term!=. & ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. , $cox_option2

est store tri_plan0 

stcox i.infect_variant ib2.positive_term ///
	ib5.ethgroup_mother_compl /// 
	i.imd04decile_mother_compl /// 
	i.mcc_yorn ///
	i.matage_catd ///
	i.londonres /// 
	i.month_conception /// 
	if positive_term!=. & ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. , $cox_option2
	
est store tri_plan1 


******************************************
* emergency admission 
******************************************

use "$derived_data_path\8_1a2_emergency_admission_birth_conceived_feb2020jul2020.dta" , clear 

*==== keep the first planned admission only , look at time to the first admission 

* The dataset include only the first episode of each admission 

* flag the first planned admission for each child 
bysort tokenid (adm_no) : gen emergency_order = _n 

keep if emergency_order==1 

*==== clean birth day and date of death 
gen bday_raw = bday 
format bday_raw %td
 
// some children with no birth admission were identified in HES APC, so the date of birth is recorded as the 15th of the month of birth, but there are admissions with a admission date earlier than the 15th of the month of birth. For these children, change the birthday to one day before the first admission date  

capture drop tmp*
gen tmp1 = string(bday , "%td")

gen tmp2= substr(tmp1 , 1 , 2 )

gen tmp3 = mofd(admidate) // month of admission date 
format tmp3 %tm 

replace bday = admidate-1 if admidate!=. & tmp3==month_bday & tmp2=="15" & admidate<bday_raw


replace bday = admidate-1 if admidate==bday_raw & month_bday==tmp3 

// some children died on the same day of birthday or before birthday, so have 0 follow-up time and would be excluded automatically from calculating rates and cox-regressions. For these children, change the date of death to one day after birthday, so they will be included in the anlaysis 
gen tmp4 = mofd(dod)
format tmp4 %tm 

replace dod = bday+1 if dod==bday_raw & death==1 
replace bday = dod-1 if death==1 & dod<bday & tmp2=="15" & tmp4==month_bday

capture drop tmp* 

*==== set survival analysis variable 
gen censordate = bday + 365.25*2.5 
format censordate %td 

**---- end time point 
* date of the first admission 
gen finalcensor1=censordate
replace finalcensor1 = admidate if admidate!=. & admidate<=censordate
format finalcensor1 %td 
* date of death 
gen finalcensor2 = censordate
replace finalcensor2 = dod if dod!=. & dod<=censordate
format finalcensor2 %td 
* final censor date 
gen finalcensor = min(finalcensor1 , finalcensor2)
format finalcensor %td 
label variable finalcensor "2.5y birthday, first admission, death, whichever the earliest"

drop finalcensor1 finalcensor2 censordate

**---- outcome 
gen outcome=0
replace outcome=1 if admidate!=. & admidate<=finalcensor

**---- time to event (exposed time)
gen time_days=finalcensor-bday

**---- declaire 
stset time_days , failure(outcome) scale(365.25) id(tokenid)

** categorise maternal age to small groups 
recode matage_compl (min/24=1 "<25") (25/29=2 "25-29") (30/34=3 "30-34") (35/39=4 "35-39") (40/max=5 ">=40") (.=.) , gen(matage_catd) 

label variable matage_catd "maternal age"

**---- save data 
save "$derived_data_path/8_1c2_first_episode_first_non-birth_emergency_admission.dta" , replace 

*==== Hospital admission rate 
use "$derived_data_path/8_1c2_first_episode_first_non-birth_emergency_admission.dta" , clear 

**---- KM curve

* England  
sts graph , by(infect_variant) failure legend(pos(6) row(1)) xtitle("Age in years") title("Emergency admission") legend(label(1 "Negative") label(2 "Wild-type") label(3 "Alpha") label(4 "Untested")) plot1opts(lcolor(green)) plot2opts(lcolor(orange)) plot3opts(lcolor(red)) plot4opts(lcolor(blue)) name(planned , replace) saving(emergency_england , replace) ylabel(0 0.1 0.2 0.3 0.4) ytitle("Proportion having an emergency admission") 

graph export "$output_path\8_1c1_KM_emergency_admission_2halfy_England.png" , replace 

*==== Main analysis: Cox regression 

**---- models 
* sample size for cox regression 
count if ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. 

* crude model 
stcox i.infect_variant ///
	if ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. , $cox_option2
	
est store emergency0 

* + mother ethnicity 
stcox i.infect_variant ///
	ib5.ethgroup_mother_compl /// 
	if ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. , $cox_option2
	
est store emergency1 

* + baby imd04 decile 
stcox i.infect_variant ///
	ib5.ethgroup_mother_compl /// 
	i.imd04decile_mother_compl /// 
	if ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=.  & matage_compl!=. , $cox_option2
	
est store emergency2 

* + mother's chronic condition 
stcox i.infect_variant ///
	ib5.ethgroup_mother_compl /// 
	i.imd04decile_mother_compl /// 
	i.mcc_yorn ///
	if ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. , $cox_option2
	
est store emergency3 

* + maternal age 
stcox i.infect_variant ///
	ib5.ethgroup_mother_compl /// 
	i.imd04decile_mother_compl /// 
	i.mcc_yorn ///
	i.matage_catd ///
	if ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. , $cox_option2
	
est store emergency4

* + london residence 
stcox i.infect_variant ///
	ib5.ethgroup_mother_compl /// 
	i.imd04decile_mother_compl /// 
	i.mcc_yorn ///
	i.matage_catd ///
	i.londonres ///
	if ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. , $cox_option2

est store emergency5 

* + month of conception 
stcox i.infect_variant ///
	ib5.ethgroup_mother_compl /// 
	i.imd04decile_mother_compl /// 
	i.mcc_yorn ///
	i.matage_catd ///
	i.londonres ///
	i.month_conception /// 
	if ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. , $cox_option2 cformat(%9.2f)

est store emergency6

**---- propotional hazard assumption 

stcox i.infect_variant ///
	ib5.ethgroup_mother_compl /// 
	i.imd04decile_mother_compl /// 
	i.mcc_yorn ///
	i.matage_catd ///
	i.londonres ///
	i.month_conception /// 
	if ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. , $cox_option2
	
est store emergency_notime 
	
stcox i.infect_variant ///
	ib5.ethgroup_mother_compl /// 
	i.imd04decile_mother_compl /// 
	i.mcc_yorn ///
	i.matage_catd ///
	i.londonres ///
	i.month_conception /// 
	if ethgroup_mother_compl!=. & imd04decile_baby_compl!=. & mcc_yorn!=. & matage_compl!=. , $cox_option2 tvc(i.infect_variant) texp(ln(_t))

est store emergency_time	
lrtest emergency_time emergency_notime 

*---- impact of trimester of infection on child admission 
gen tmp1 = (positive_term1==1)
gen tmp2 = (positive_term2==1)
gen tmp3 = (positive_term3==1)

gen tmp4 = tmp1 + tmp2 + tmp3 
gen positive_term = 1 if tmp1==1 
replace positive_term = 2 if tmp2==1 
replace positive_term = 3 if tmp3==1 
replace positive_term = . if tmp4>1 

catpure drip tmp*
 
stcox i.infect_variant ib2.positive_term if positive_term!=. & ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. , $cox_option2

est store tri_emergency0 

stcox i.infect_variant ib2.positive_term ///
	ib5.ethgroup_mother_compl /// 
	i.imd04decile_mother_compl /// 
	i.mcc_yorn ///
	i.matage_catd ///
	i.londonres /// 
	i.month_conception /// 
	if positive_term!=. & ethgroup_mother_compl!=. & imd04decile_mother_compl!=. & mcc_yorn!=. & matage_compl!=. , $cox_option2
	
est store tri_emergency1 


******************************************
* plots of hazard ratio 
******************************************

* exposure groups 
coefplot ( emergency0  , label(Crude)) ( emergency6, label(Adjusted)) , bylabel("Emergency admission") || plan0 plan6 , bylabel("Planned admission") drop(_cons) byopt(row(1) legend(pos(6))) xline(1) keep(*.infect_variant)  mlabel mlabsize(*1.35) mlabposition(2) format(%4.3f) ci(99 box) xlabel(0.8 "0.8" 1 "1" 1.2 "1.2") eform rename(0.infect_variant = "Test-negative" 1.infect_variant = "Positive: Wild-type" 2.infect_variant="Positive: Alpha" 10.infect_variant = "No-recorded-result") coeflabels(, labsize(medlarge)) legend(row(1)) baselevels 

graph export "$output_path\8_1c2_coxreg_planned_emergency_2halfy_99ci.png" , replace width(1600) height(900) 

*---- trimester and exposure groups 
* plot coefficients 	
label define positive_term 1 "First trimester" 2  "Second trimester"  3 "Third trimester" , replace 
label value positive_term positive_term 

coefplot ( tri_emergency0  , label(Crude)) ( tri_emergency1, label(Adjusted)) , bylabel("Emergency admission") || tri_plan0 tri_plan1 , bylabel("Planned admission") ///
	drop(_cons) byopt(row(1) legend(pos(6))) xline(1) ///
	keep(*.infect_variant *.positive_term)  ///
	mlabel mlabsize(*1.35) mlabposition(2) format(%4.3f) ci(99 box) ///
	xlabel(0.8 "0.8" 1 "1" 1.2 "1.2") eform ///
	headings(1.infect_variant = "{bf:Variant of in utero exposure}" ///
	1.positive_term = "{bf: Trimester at in utero exposure}" , nogap labsize(*0.9)) ///
	coeflabels(, labsize(medlarge)) legend(row(1)) baselevels 

graph export "$output_path\8_1c3_coxreg_trimester_planned_emergency_2halfy.png" , replace width(1600) height(900) 
