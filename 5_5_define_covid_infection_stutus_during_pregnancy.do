******************************************
** 5_5 Covid infection status during pregnancy 
**
** Define covid infection status during pregnancy based on 1) mother's covid tests during pregnancy; 2) mother's APC diagnoses during pregnancy
** 
******************************************

******************************************
* Based on covid test during pregnancy 
******************************************

*==== Birth whose mother did Covid tests during pregnancy but all tests are negative or unknown result
 
**---- load data 
use "$derived_data_path\5_4a_cvdtest_durpreg_person-day-level.dta" , clear 

**---- exclude births who had at least a positive test during pregnancy 
gen positive_test = (covidresult_final==1)

bysort tokenid : egen n_positive = total(positive_test)

gen ever_positive = (n_positive>=1)

tab ever_positive , m 

drop if ever_positive==1 

**---- identify births with any unknown test results  
gen unknown_test = (covidresult_final==9)
bysort tokenid : egen all_unknowntest = min(unknown_test)

**---- generate a variable flagging whether women are infected or not or unknwon during pregnacy 
gen covid_status_durpreg = . 
replace covid_status_durpreg = 9 if all_unknowntest==1 
replace covid_status_durpreg = 0 if ever_positive==0 & all_unknowntest!=1 

label variable covid_status_durpreg "covid infection status during pregnancy"
label define covid_status_durpreg 0 "negative" 1 "positive" 9 "tested unknown result" , replace 
label value covid_status_durpreg covid_status_durpreg

**---- one record per births 
duplicates drop tokenid , force 
keep tokenid bday doconception covid_status_durpreg 

**---- save data 
save "$derived_data_path\5_5a_covid_negative&unknowntest_birthlevel_forcombine.dta" , replace 


******************************************
* Merge covid pregnancy infection status based on tests and based on APC diagnosis
******************************************
clear 

*---- merge covid status data from two sources (covid tests and mother's apc)

* covid pregnancy infection status based on covid testing (SGSS+pillar 2)
append using "$derived_data_path\5_5a_covid_negative&unknowntest_birthlevel_forcombine.dta" 

* covid pregnancy infection status based on mother's APC diagnosis 
append using "$derived_data_path\5_4f_child-level_covid_infection_terms_variants.dta"

*---- some women have a negative/unknwon covid test but had a covid diagnosis during pregnancy, so they appear in both the negative/unknown and positive dataset, remove the record for negative covid status 

* flag covid positive test/diagnosis
gen tmp = (covid_status_durpreg==1)

* flag women ever had a positive test/diagnosis
bysort tokenid : egen tmp2 = max(tmp) 

* for women who appear in both negative/unknown dataset and positive dataset, remove the records with negative/unknown covid status 
drop if covid_status_durpreg!=1 & tmp2==1

drop tmp*

* remove duplicate records for children (here I don't think about when in the pregnancy did the mother had covid)
duplicates report tokenid // no duplicates 
*duplicates drop tokenid , force
 
** replace positiev_term* and infect_* variables for children whose mother tested negative/unknown during pregnancy 
* note: as long as the mother does not have a positive result and have a negative result (no matter these test is in which term or variant period), we consider this mother is negative for all pregnant terms and variant period 
label define positive_term 0 "negative" 1 "positive" 9 "tested unknown result" 10 "no test/diagnosis record"

foreach i in 1 2 3 { 
	replace positive_term`i' = 0 if covid_status_durpreg==0 
	replace positive_term`i' = 9 if covid_status_durpreg==9
	label value positive_term* positive_term
}

foreach i in wildtype alpha delta omicron { 
	replace infect_`i' = 0 if covid_status_durpreg==0 
	replace infect_`i' = 9 if covid_status_durpreg==9
	label value infect_`i' positive_term
}

label define infect_variant 0 "negative" 9 "tested unknown result" 10 "no test/diagnosis record" , add 
replace infect_variant = 0 if covid_status_durpreg==0 
replace infect_variant = 9 if covid_status_durpreg==9 

keep tokenid bday doconception covid_status_durpreg n_infection positive_term* date_infection* infect_* 

save "$derived_data_path\5_5c_covid_pregnancy_infection_test+apc.dta" , replace 
