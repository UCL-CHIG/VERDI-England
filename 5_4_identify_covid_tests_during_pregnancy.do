******************************************
** 5_4 Identify covid tests during pregnancy and define episode of infections 
**
** Identify and keep covid test during pregnancy and define episode/period of infection based on covid test 
** 
******************************************

*==== define key date of wave 
global wave1 = date("15Dec2020" , "DMY" ) // when wild-type ends 
global wave2 = date("15May2021" , "DMY") // when alpha ends 
global wave3 = date("15Dec2021" , "DMY") // when delta ends

global lockdown1start = date("23Mar2020" , "DMY") // first lockdown starts
global lockdown1end = date("23Jun2020" , "DMY") // first lockdown ends 
global lockdown2start = date("31Oct2020" , "DMY") // second lockdown starts
global lockdown2end = date("2Dec2020" , "DMY") // second lockdown ends 

******************************************
* Identify covid tests during pregnancy 
******************************************

*==== load data 
use "$derived_data_path\5_3a_covid_result_mother_of birth1623_jan16jan24_person-day-level.dta" , clear 

*==== merge with mother-baby pair data with date of birth and gestational age 
merge m:m mtokenid using "$derived_data_path\3_13d_covariates.dta" , keepusing(tokenid bday gestat_compl gestation0 doconception) gen(merge_mbl) 

tab merge_mbl , m 
*==== determine whether covid test were done during pregnancy 
gen cvdtst_durpreg = .  
label variable cvdtst_durpreg "whether covid test was done during pregnancy"
label define yon 0 "no" 1 "yes" , replace 
label value cvdtst_durpreg yon 

replace cvdtst_durpreg = 1 if testdate>=doconception & testdate<=bday & testdate!=. 
replace cvdtst_durpreg = 0 if (testdate<doconception | testdate>bday) & testdate!=. 

tab cvdtst_durpreg if merge_mbl==3 , m 

*==== only keep covid test that were done during pregnancy (women without a covid test are excluded)
keep if cvdtst_durpreg==1 

*==== save data 
save "$derived_data_path\5_4a_cvdtest_durpreg_person-day-level.dta" , replace 


******************************************
* Save data on positive Covid test during pregnancy 
******************************************

use "$derived_data_path\5_4a_cvdtest_durpreg_person-day-level.dta" , clear 

*==== keep positive results 

* keep positive test only 
keep if covidresult_final == 1 

* create a covid test variable that can be merged with covid diagnosis positive date
gen covidpositive_date = testdate 
format covidpositive_date %d 

* flag source is covid test 
gen testordiag = 1 
label variable testordiag "1=test, 2=diagnosis"

* keep key variables 
keep tokenid mtokenid covidpositive_date testordiag testsource bday gestat_compl gestation0 doconception 

save "$derived_data_path\5_4b_positive_cvdtest_durpreg.dta" , replace 


******************************************
* Save data on positive Covid diagnosis during pregnancy 
* Based on mother's APC test during pregnancy 
******************************************
*==== identify and keep APC records with a covid diagnosis 

* load APC data for women who had a birth between 1997-Oct 2022

use "$derived_data_path\4_3b_APC_mother_of_birth1623_linked_admission_1721.dta" , clear 

* identify diagnosis for covid 

gen diag_concat=diag_01 + "."+diag_02 + "." + diag_03 + "."+ diag_04 + "."+ diag_05 + "."+ diag_06 + "."+ diag_07 + "."+ diag_08 + "."+ diag_09 + "."+ diag_10 + "."+ diag_11 + "."+ diag_12 + "."+ diag_13 + "."+ diag_14 + "."+ diag_15 + "."+ diag_16 + "."+ diag_17 + "."+ diag_18 + "."+ diag_19 + "."+ diag_20

gen coviddiag = 0
label variable coviddiag "the episode has a covid diagnosis"

foreach code in U071 U072 {
	replace coviddiag = 1 if strpos(diag_concat,"`code'")>0
}
	
drop diag_concat

* keep covid diagnosis record 
keep if coviddiag == 1 

*==== identify and keep covid diagnosis during pregnancy  

* merge with birth cohort data and get duration of pregnancy 
merge m:m mtokenid using "$derived_data_path\3_13d_covariates.dta" , keep(match) nogen 

* flag if the episodes with covid diagnosis is during pregnancy or not - assume epistart day is the day of diagnosis 

* covid diagnosis date 
gen coviddiag_date =epistart  
format coviddiag_date %d 

gen coviddiag_durpreg = 0 
label variable coviddiag_durpreg "the episode with a covid diagnosis is during pregnancy"

replace coviddiag_durpreg = 1 if coviddiag_date>=doconception & coviddiag_date<=bday & coviddiag_date!=. 

* keep APC episodes where the covid diagnosis is during pregnancy 
keep if coviddiag_durpreg == 1 

* remove covid diagnoses on the same day 
duplicates report tokenid coviddiag_date  
duplicates drop tokenid coviddiag_date , force 

* create a covid diagnosis variable that can be merged with covid test positive date 
gen covidpositive_date = coviddiag_date
format covidpositive_date %d 

* flag source is covid diagnosis 
gen testordiag = 2 
label variable testordiag "1=test, 2=diagnosis"

* keep key variables 
keep tokenid mtokenid covidpositive_date bday gestat_compl gestation0 doconception 

save "$derived_data_path\5_4c_covid_positivediagnosis_durpreg.dta" , replace 


******************************************
* define episode of infection 
******************************************

*==== merge covid positive test and diagnosis 
clear
append using "$derived_data_path\5_4b_positive_cvdtest_durpreg.dta" 
append using "$derived_data_path\5_4c_covid_positivediagnosis_durpreg.dta"

*==== if there is a covid positive test, remove the covid diagnosis on the same day 

duplicates report tokenid covidpositive_date 

sort tokenid covidpositive_date testordiag 

duplicates drop tokenid covidpositive_date , force

*==== define infection 

* sort data 
sort mtokenid tokenid covidpositive_date

* generate the order of positive test within one pregnancy 
by mtokenid tokenid (covidpositive_date) : gen cvdpos_order = _n 
label variable cvdpos_order "order of positive test/diagnosis within the index pregnancy"

*==== deal with order of tests 

**---- assign the date of the first positive test in one pregnancy to every covid test during this pregnancy 

sort mtokenid tokenid covidpositive_date

by mtokenid tokenid : gen date_infection1 = covidpositive_date[_n- cvdpos_order +1]

label variable date_infection1 "date of the first infection (first positive test during pregnancy)"

**---- date of the last positive test 
gsort mtokenid tokenid -covidpositive_date 

bysort mtokenid tokenid : gen date_finalpostst = covidpositive_date[_n - (_n-1)]

label variable date_finalpostst "date of the final positive test during pregnancy"

format date_infection1 date_finalpostst %td 

*==== determine each episode of infection

*---- maximum possible episode of infection 

* calculate the gap in days between the first and the last positive test 
gen days_fstlstpos = date_finalpostst - date_infection1
label variable days_fstlstpos "number of days between the first and last positive test"

* check the maximum gap 
sum days_fstlstpos 

* check the maximum possible episode of infection a woman may have 
dis `r(max)'/90 

*----  first episode of infection  

* create a variable indicating the episode of infection 
gen infection = . 
label variable infection "in which episode of infection"
label define infection 1 "first infection" 2 "second infection" 3 "third infection" 4 "fourth infection"
label value infection infection 

* date when we count the second episode of infection (90 days after the first positive test)
gen cutoff_infection2 = date_infection1 + 90 
label variable cutoff_infection2 "cutoff for the second infection (90 days after the first infection)"


* flag tests within the first episode of infection 
replace infection = 1 if covidpositive_date >= date_infection1 & covidpositive_date <= cutoff_infection2

*---- second episode of infection 
* the date of the second infection 
sort mtokenid tokenid covidpositive_date 
bysort mtokenid tokenid : egen date_infection2 = min(covidpositive_date) if infection==. 
label variable date_infection2 "date of the second infection"

* cutoff for the third infection 
gen cutoff_infection3 = date_infection2 + 90 
label variable cutoff_infection3 "cutoff for the third infection (90 days after the second infection)"

* flag tests within the second infection 
replace infection = 2 if covidpositive_date >= date_infection2 & covidpositive_date <= cutoff_infection3

*---- third episode of infection 
* the date of the third infection 
sort mtokenid tokenid covidpositive_date 
bysort mtokenid tokenid : egen date_infection3 = min(covidpositive_date) if infection==. 
label variable date_infection3 "date of the third infection"


* cutoff for the forth infection 
gen cutoff_infection4 = date_infection3 + 90 
label variable cutoff_infection4 "cutoff for the fourth infection (90 days after the third infection)"

* flag tests within the third infection 
replace infection = 3 if covidpositive_date >= date_infection3 & covidpositive_date <= cutoff_infection4

* format dates 
format cutoff_infection* date_infection* %td 

**---- summary 
tab infection , m 

**==== gestational days of testing and trimester when doing the test  
gen cvdpos_gestdays = covidpositive_date - doconception 
label variable cvdpos_gestdays "gestational days when covid positive"

recode cvdpos_gestdays (min/84=1 "First trimester") (85/182=2 "Second trimester") (183/max=3 "Third trimester") (.=.) , gen(cvdpos_term) 
label variable cvdpos_term "trimester when doing the test/diagnosis"

tab cvdpos_term , m 

**==== dummy variables indicating whether women of this child had covid in each trimester 
foreach i in 1 2 3 {
	gen tmp`i' = (cvdpos_term==`i')
	
	bysort mtokenid tokenid : egen positive_term`i' = max(tmp`i')
	label variable positive_term`i' "covid positive in trimester `i'"
	drop tmp*
}

*===== define covid status and the number of infections 
gen covid_status_durpreg = 1 

label variable covid_status_durpreg "covid infection status during pregnancy"
label define covid_status_durpreg 0 "negative" 1 "positive" 9 "tested unknown result" , replace 
label value covid_status_durpreg covid_status_durpreg

**---- how many episode of infection woman had: women in this study "sample" had a maximum of three episode of infection 

bysort tokenid : egen n_infection = max(infection)
label variable n_infection "the number of infection the birth has"
tab n_infection , m 

*---- save data 
keep mtokenid testsource tokenid bday gestat_compl gestation0 doconception covidpositive_date testordiag cvdpos_gestdays cvdpos_term cvdpos_term cvdpos_order infection date_infection1 date_infection2 date_infection3 cutoff_infection2 cutoff_infection3 cutoff_infection4 covid_status_durpreg n_infection positive_term* 

save "$derived_data_path\5_4d_covid_positive_infection_wi_date.dta" , replace 


********************************************
** The first test/diagnosis of a infection 
********************************************
use "$derived_data_path\5_4d_covid_positive_infection_wi_date.dta" , clear 

* keep the first positive test/diagnosis in each infection 
bysort mtokenid tokenid infection (covidpositive_date) : gen tmp = _n 

keep if tmp==1 // only keep the first positive test/diagnosis in each infection 

drop tmp 

* drop variables that are test/diagnosis-specific. 
drop covidpositive_date testordiag cvdpos_order cutoff_infection2 cutoff_infection3 cutoff_infection4 cvdpos_gestdays cvdpos_term

tab infection , m 

tab positive_term1 , m 
tab positive_term2 , m 
tab positive_term3 , m 

save "$derived_data_path\5_4e_covid_infection-level_wi_date.dta" , replace 

********************************************
** Variant period and Infection terms (in which term is the mother tested positive for COVID)
********************************************

use "$derived_data_path\5_4e_covid_infection-level_wi_date.dta" , clear 

* keep the last infection of each child (the record for the last infection contains infection dates of all previous infections)
gsort tokenid -infection

duplicates drop tokenid, force 

*==== define variant period when positive 
gen infect_wildtype = 0
gen infect_alpha = 0 
gen infect_delta = 0 
gen infect_omicron = 0 

label variable infect_wildtype "SARS-CoV-2 infection in wildtype period"
label variable infect_alpha "SARS-CoV-2 infection in alpha period"
label variable infect_delta "SARS-CoV-2 infection in delta period"
label variable infect_omicron "SARS-CoV-2 infection in omicron period"

foreach i in 1 2 3 {
	replace infect_wildtype = 1 if date_infection`i' <=$wave1 & date_infection`i'!=. 
	replace infect_alpha = 1 if date_infection`i'>$wave1 & date_infection`i'<=$wave2 & date_infection`i' !=. 
	replace infect_delta = 1 if date_infection`i' >$wave2 & date_infection`i'<=$wave3 & date_infection`i'!=. 
	replace infect_omicron = 1 if date_infection`i' >$wave3 & date_infection`i'!=. 
}

tab infect_wildtype , m 
tab infect_alpha , m 
tab infect_delta , m 
tab infect_omicron , m 

*==== one categorical variable indicating variant period when positive 
gen infect_variant = . 

replace infect_variant = 1 if infect_wildtype==1 
replace infect_variant = 2 if infect_alpha==1 
replace infect_variant = 3 if infect_delta==1 
replace infect_variant = 4 if infect_omicron==1 
replace infect_variant = 5 if (infect_wildtype + infect_alpha +infect_delta + infect_omicron)>=2 

label define infect_variant 1 "wild-type" 2 "alpha" 3 "delta" 4 "omicron" 5 "infected in more than one variant period" , replace 

label value infect_variant infect_variant

keep tokenid bday doconception positive_term* date_infection* infect_* covid_status_durpreg n_infection 

save "$derived_data_path\5_4f_child-level_covid_infection_terms_variants.dta" , replace 
