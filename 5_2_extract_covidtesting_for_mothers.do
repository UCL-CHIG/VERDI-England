******************************************
** 5_2 Extract mothers' covid test data 
**
** extract covid testing data (sgss and pillar 2) for mothers who had a birth between 2016 and 2023
** 
******************************************

******************************************
* Clean SGSS and find mothers' record 
****************************************** 
use "$covid_data_path\SGSS_data.dta" , replace 

*==== clean variables 

**---- year - all fine 
tab age_in_years , m 
rename age_in_years age_sgss
label variable age_sgss "age from SGSS"

**---- sex 
tab patient_sex , m 
gen sex_sgss = . 
label variable sex_sgss "sex from SGSS"

replace sex_sgss = 1 if patient_sex=="M" | patient_sex=="MALE" | patient_sex=="Male" 
replace sex_sgss = 2 if patient_sex=="F" | patient_sex=="FEMALE" | patient_sex=="Female" 
replace sex_sgss = . if patient_sex=="U" | patient_sex=="Unknown" | patient_sex==""

label define sex_sgss 1 "Male" 2 "Female" , replace 
label value sex_sgss sex_sgss
tab sex_sgss , m

**---- county 
tab county_description , m 

rename county_description county_sgss 

replace county_sgss = "Yorkshire E. Riding" if county_sgss=="Yorkshire, E. Riding" 
replace county_sgss = "Kingston upon Hull" if county_sgss=="Kingston upon Hull City of" | county_sgss=="Kingston upon Hull, City of"
replace county_sgss = "Herefordshire" if county_sgss=="Herefordshire, County of" | county_sgss == "Herefordshire County of" 
replace county_sgss = "Bristol" if county_sgss=="Bristol City of" | county_sgss == "Bristol, City of" 

**--- test date 

* specimen date 
codebook specimen_date 
gen tmp1 = date(specimen_date, "YMD")
format tmp1 %td 
drop specimen_date
rename tmp1 specimen_date

* lab_report_date
codebook lab_report_date 
gen tmp2 = date(lab_report_date , "YMD")
format tmp2 %td 
drop lab_report_date 
rename tmp2 lab_report_date

tab lab_report_date if specimen_date ==. 

local covidstartdate = date("12/01/2019" , "MDY")
tab lab_report_date if specimen_date <=`covidstartdate' 

* replace test date with plausible lab_report_date where specimen_date is missing or implausible, set the rest implausible test date to missing 
gen testdate=specimen_date
format testdate %d 

replace testdate = lab_report_date if specimen_date==. 
replace testdate = lab_report_date if specimen_date<`covidstartdate' & lab_report_date>=`covidstartdate' 
replace testdate = . if specimen_date<`covidstartdate' & lab_report_date<`covidstartdate' 

sum testdate , d  

**---- source of data 
gen pillar =1 

**---- test type - sgss are all PCR test 
gen testtype = 1 
label define testtype 1 "PCR" 2 "Antigen" , replace 
label value testtype testtype

**---- test results - all positive in sgss 
gen covidresult = 1 
label define covidresult 0 "negative" 1 "positive" 9 "unknown", replace 
label value covidresult covidresult 

*==== keep relevant variables 
keep tokenid pillar testtype testdate covidresult 
order tokenid pillar testtype testdate covidresult 

*==== drop duplicates records for tests on the same day 
duplicates drop tokenid testdate , force 

*==== save data 

**---- all children and mothers 
save "$derived_data_path\5_2a_sgss_mother_children.dta" , replace 

**---- sgss for mothers 
rename tokenid mtokenid 
merge m:1 mtokenid using "$derived_data_path\2_1c_unique_mother_tokenid_1623.dta" , keep(using match)

bysort mtokenid : gen n= _n 
tab _merge if n==1 

keep if _merge==3 
keep mtokenid pillar testtype testdate covidresult 

save "$derived_data_path\5_2b_sgss_mother_of_birth1623_jan16jan24.dta" , replace 
	
******************************************
* Clean pillar 2 and find mothers' record 
******************************************

*==== clean variables 
local filename_list "0-5y 6-10y 11-15y 16-20y 21-24y 25+y_p1 25+y_p2"
local j = 1

foreach i in 0-5y_minimised 6-10y_minimised 11-15y_minimised 16-20y_minimised 21-24y_minimised 25+y_mothers_minimised_updated 25+y_mothers_minimised_updated_part2 {
	
	* save file name 
	local filename : word `j' of `filename_list'
	
	* load data 
	use "$covid_data_path\Pillar2_`i'.dta" , clear 

	**--- test date 
	gen testdate=appointmentdate 
	format testdate %d 
	drop appointmentdate

	* drop other dates with all missing values 
	drop recordcreateddate samplecreationdate specimenprocesseddate testenddate teststartdate vaccinationdate

	**---- symptomatic 
	encode covidsymptomatic, gen(symptomatic)
	drop covidsymptomatic 

	**---- test location 
	encode testlocation, gen(test_location)

	**---- test type 
	tab testresult , m 

	gen testtype = . 
	label define testtype 1 "PCR" 2 "antigen" 
	label val testtype testtype

	replace testtype = 1 if inlist(testresult, "SCT:1240581000000104", "SCT:1240591000000102", "SCT:1321691000000102")
	replace testtype = 2 if inlist(testresult, "SCT:1322781000000102", "SCT:1322791000000100", "SCT:1322821000000105")

	**---- test results 
	gen covidresult = . 
	label define covidresult 0 "negative" 1 "positive" 9 "unknown", replace 
	label value covidresult covidresult 

	replace covidresult = 1 if inlist(testresult, "SCT:1240581000000104", "SCT:1322781000000102")
	replace covidresult = 0 if inlist(testresult, "SCT:1240591000000102", "SCT:1322791000000100")
	replace covidresult = 9 if inlist(testresult, "SCT:1321691000000102", "SCT:1322821000000105")

	**---- sex 
	tab gender , m  

	gen sex_pillar2 = . 
	label variable sex_pillar2 "sex from pillar2"

	replace sex_pillar2 = 1 if gender=="M" | gender=="MALE" | gender=="Male" 
	replace sex_pillar2 = 2 if gender=="F" | gender=="FEMALE" | gender=="Female" 
	replace sex_pillar2 = . if gender=="U" | gender=="Unknown" | gender=="unknown" | gender==""

	label define sex_pillar2 1 "Male" 2 "Female" , replace 
	label value sex_pillar2 sex_pillar2
	tab sex_pillar2 , m

	**---- vaccination status 
	gen vaccinestat = "" 
	replace vaccinestat = "1" if vaccinationstatus == "type-a-one-dose" 
	replace vaccinestat = "2" if vaccinationstatus == "type-a-two-dose" 
	replace vaccinestat = "3" if vaccinationstatus == "type-a-three-dose" 
	replace vaccinationstatus = "0" if vaccinationstatus == "none"

	**---- vaccination period
	* keep original variable as don't know if the values in each datasets are the same 

	**---- source of data 
	gen pillar = 2 

	**---- keep relevant variables 
	keep tokenid sex_pillar2 pillar testtype testdate covidresult symptomatic specimenid testlocation vaccinestat vaccinationperiod 

	order tokenid pillar testtype testdate covidresult 

	*==== save pillar 2 data 
	
	**---- pillar 2 data for children (udner 25) and mothers 
	save "$derived_data_path\5_2c_pillar2_all_child&mother_`filename'.dta" , replace 
	
	**---- pillar 2 data for mothers, keep variables to be combined with pillar 1 
	* keep same variables as pillar 1 data 
	keep tokenid pillar testtype testdate covidresult 
	order tokenid pillar testtype testdate covidresult 
	
	rename tokenid mtokenid 
	
	* keep mothers records 
	merge m:1 mtokenid using "$derived_data_path\2_2c_unique_mother_tokenid_1623.dta" , keep( match) 
	
	* save 
	save "$derived_data_path\5_2d_pillar2_mother_of_birth1623_jan16jan24_`filename'.dta" , replace 
	
	local j = `j' + 1 
} 

******************************************
* Combine SGSS and pillar 2 for mothers 
******************************************

clear 
* SGSS 
append using "$derived_data_path\5_2b_sgss_mother_of_birth1623_jan16jan24.dta" 

* pillar 2 
foreach i in 0-5y 6-10y 11-15y 16-20y 21-24y 25+y_p1 25+y_p2 {
	append using "$derived_data_path\5_2d_pillar2_mother_of_birth1623_jan16jan24_`i'.dta"
}

format testdate %d 
label variable testdate "covid test date"

* save 
save "$derived_data_path\5_2e_sgss&pillar2_mother_of_birth1623_jan16jan24_testlevel.dta" , replace 


******************************************
* Plot the distribution of tests from pillar 1 and pillar 2 for mothers 
******************************************
use "$derived_data_path\5_2e_sgss&pillar2_mother_of_birth1623_jan16jan24_testlevel.dta" , clear 

label define pillar 1 "Pillar 1" 2 "Pillar 2" , replace 
label values pillar pillar 

hist testdate if  testdate>=21915, xlabel( 21915 "01Jan2020" 22097 "01Jul" 22281 "01Jan2021" 22462 "01Jul" 22646 "01Jan2022" 23011 "01Jan2023" 23376 "01Jan2024" 23589 " " ) freq yla( , format("%1.0f") ang(h)) xscale(range(21915 23589)) by(pillar , col(1) )  


twoway ( hist testdate if covidresult==0 & testdate>=21915 , color(green*0.4) width(1) freq ) ///
	(hist testdate if covidresult==1 & testdate>=21915 , color(red*0.4) width(1) freq ) ///
	, xlabel( 21915 "01Jan2020" 22097 "01Jul" 22281 "01Jan2021" 22462 "01Jul" 22646 "01Jan2022" 23011 "01Jan2023" 23376 "01Jan2024" 23589 " " , labsize(small)) ///
	legend(pos(6) ring(0) label(1 "Negative tests") label(2 "Positive tests") ) ///
	yla( , format("%1.0f") ang(h)) xscale(range(21915 23589)) by(pillar , col(1) )  ///
	ytitle("Number of tests daily") 
	
graph export "$output_path/5_2a_distribution_tests_overtime.png" , replace 
