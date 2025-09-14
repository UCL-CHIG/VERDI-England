******************************************
** 3_13 covaraites 
**
** clean covariate variables, including copy across episdoes and combine information from various data sources of the baby and mothers 
** Variables include: stillbirth, multiple birth, gestation, sex of the baby, birth weight, ethnicity of the baby, ethnicity of the mother, residence of the baby/mother, IMD04 decile, maternal age, 
** 
** Data sources and steps: 
** 1. children admissions under 1 month ("mode" across APC episdoes)
** 2. birth notification 
** 3. birth registration (sex of the baby)
** 4. Qi's mother-baby link 
** 5. for continuous variable (maternal age and gestation), mean across APC episodes 
** 6. mother's delivery records 
** 
******************************************

******************************************
* 1. Clean covariates in children APC admission under 1 month , if missing, replace with info in birth notification, birth registration, and mother-baby link (in 2_1b_combined_mother-baby_link_1623.dta)
******************************************
*==== Load data and merge with other datasets 

**---- load children APC admissions under 1 month (age at admission start is within 28 days)
use "$derived_data_path\3_3b_children_linked_admission_under1m_covariate.dta", clear 

gen ydob = year(dob_full)

**---- Merge with combined mother-baby link data 
merge m:1 tokenid using "$derived_data_path\2_1b_combined_mother-baby_link_1623.dta", gen(merge_mbls) 

label variable merge_mbls "merge birth admissions with mother-baby links"
label define merge_mbls 1 "birth admission only" 2 "mother-baby links only" 3 "both in birth admissions and mother-baby links" 
label values merge_mbls merge_mbls

drop if merge_mbls ==1 // delete admissions for children who are not included in the birth cohort 

**---- merge with birth registration that have baby sex 
merge m:1 tokenid using "$derived_data_path\3_0b_birth_registration.dta" , gen(merge_bregistration)

drop if merge_bregistration==2 // delete birth notification records for children who are not included in the birth cohort 

label variable babysex "baby sex from birth registration"

*==== date of birth 

**---- merge with birth admission number to get date of birth for births identified in HES 
merge m:1 tokenid using "$derived_data_path\3_4a_birth_admission_number_2016_Mar2024.dta" , gen(merge_birthnumber) 

gen bday = bday_hes if merge_birthnumber!=1 
replace bday = dob_mbl if merge_birthnumber==1 
format bday %td 

label variable bday "date of birth, admission date if found in HES, 15th of month of birth if found in MBL or birth notification"

*==== source of birth 
merge m:1 tokenid using "$derived_data_path\3_4b_source_of_birth.dta" , gen(merge_sourcebirth)

*==== multiple births

*** generate an indicator of multiple birth
gen multibirth=.

*** identify multiple births using diagnostic codes
foreach var of varlist diag_01-diag_20 {
	replace multibirth=1 if (substr(`var',1,4)=="Z383" | substr(`var',1,4)=="Z384" | substr(`var',1,4)=="Z385") 	/* twins */
	replace multibirth=1 if (substr(`var',1,4)=="Z372" | substr(`var',1,4)=="Z373" | substr(`var',1,4)=="Z374") 	/* twins */
	replace multibirth=1 if (substr(`var',1,4)=="Z386" | substr(`var',1,4)=="Z387" | substr(`var',1,4)=="Z388") 	/* other multiple birth */
	replace multibirth=1 if (substr(`var',1,4)=="Z375" | substr(`var',1,4)=="Z376" | substr(`var',1,4)=="Z377") 	/* other multiple birth */
}

*** identify multiple births using variables in the baby tail
replace multibirth=1 if birordr>1 & birordr!=. /*position in the sequence of births */
replace multibirth=1 if numbaby>1 & numbaby!=. /* number of babies delivered at the end of a single pregnancy */

*** tag all episodes of care for tokenID marked as multiple births
bysort tokenid: egen multibirth_id=max(multibirth)

*** count the number of multiple births
capture drop tmp
bysort tokenid: gen tmp=_n
tab ydob if tmp==1 & multibirth_id!=. 
drop tmp

*** drop variables associated with multiple births which we do not need anymore - keep multiple birth ID and rename multiple births

drop multibirth
rename multibirth_id multibirth

*==== stillbirths		       

*** generate an indicator for a stillbirth
gen stillbirth=.

*** indicate stillbirths based on diagnostic codes
foreach var of varlist diag_01-diag_20 {
	replace stillbirth=1 if substr(`var',1,4)=="Z371" | substr(`var',1,3)=="P95" 
	replace stillbirth=1 if substr(`var',1,4)=="Z373" | substr(`var',1,4)=="Z374" | substr(`var',1,4)=="Z376"  | substr(`var',1,4)=="Z377" // i.e. remove stillborn multiples - Z373, Z374, Z376, Z377
}

*** indicate stillbirths based on HES specific fields
replace stillbirth=1 if dismeth==5				/* discharge method */
replace stillbirth=1 if birstat==2 | birstat==3 | birstat==4  /* birth status */

*** tag all episodes of care for tokenids marked as stillbirths
bysort tokenid: egen stillbirth_id=min(stillbirth)

*** calculate the number of identified stillbirths
capture drop tmp
bysort tokenid: gen tmp=_n
tab ydob if stillbirth_id==1 & tmp==1, mi 

drop stillbirth
rename stillbirth_id stillbirth

*==== gestational age

*** set implausible values to missing 
tab gestat // length of gestation

foreach var of varlist gestat gestation gestat_clean {
	replace `var'=. if `var'>45 
	replace `var'=. if `var'<22 
}

*** copy mode of gestational age between episodes of the same tokenid
bysort tokenid: egen gestat_compl=mode(gestat) /* get mode of gestational age for episodes under the same tokenids*/ 

*** replace with gestation from birth notificaiton if missing 
replace gestat_compl = gestation if gestat_compl==. 

*** replace with gestation from Qi's mother-baby link if missing 
replace gestat_compl = gestat_clean if gestat_compl==. 

*** if missing, replace with the rounded mean across episdoes 
count if gestat_compl==. & gestat!=. 

bysort tokenid : egen tmp = mean(gestat) if gestat!=. & gestat_compl==. 
gen tmp2 = round(tmp , 1)
replace gestat_compl = tmp2 if gestat!=. & gestat_compl==.

drop tmp* 

*==== preterm birth 
recode gestat_compl (min/36=1 "preterm birth (<37)") (37/42=2 "term birth (37-42)") (43/max=3 "postterm birth (>42)"), gen(termbirth) 

label variable termbirth "preterm, term, or post term" 

*==== date of conception
gen gestation0 = bday - gestat_compl*7 

label variable gestation0 "gestation 0 week"
gen doconception = gestation0 + 14 // date of conception is gestation week 2 
label variable doconception "date of conception"
format gestation0 doconception %td 
	
*==== sex 

**---- copy sex from other records for records with missing sex 
bysort tokenid : egen sex_compl = mode(sex) 

* replace with sex from birth notification if missing 
replace sex_compl = baby_sex if sex_compl==. 

* replace with sex from birth registration if missing 
replace sex_compl = babysex if sex_compl==. 

* replace with sex from mother-baby link if missing 
replace sex_compl = sexbaby_clean if sex_compl==. 

replace sex_compl = . if sex_compl==0 | sex_compl==9 

label define sex_compl 1 "Male" 2 "Female" 0 "Not known" 9 "Not specified"
label value sex_compl sex_compl 


*********** birthweight **************

**==== set implausible birthweight to missing 

global implaus bw_implaus
global sex sex_compl 
global gestat gestat_compl

foreach var of varlist birweit birthweight birweit_clean {
	
	*---- implausible extreme values 
	replace `var'=. if `var'<200  
	replace `var'=. if `var'>7000 
	
	*---- implausible values according to Tim Cole's centiles 
	
	global birweit `var'
	
	* run Ania's code of implausible birthweight for gestation age and sex 
	do "$do_file_path\1_2_implausible_birthweight_Tim.do"
	
	* set implausible values to missing 
	tab $implaus , m 
	codebook tokenid if $implaus ==1 
	replace $birweit = . if $implaus==1
	drop $implaus 
	
}

*** copy mode of birth weight between episodes of the same tokenid
bysort tokenid: egen birweit_compl=mode(birweit) /* get mode of birthweight for each tokenid*/

*** replace plausible birthweight from birth notification if missing 
replace birweit_compl = birthweight if birweit_compl==. 

*** replace plausible birthweight from mother-baby link if missing 
replace birweit_compl = birweit_clean if birweit_compl==. 

*** if still missing, replace with the mean across episodes (under 1 month) 
count if birweit_compl==. & birweit!=. 

bysort tokenid : egen tmp = mean(birweit) if birweit_compl==. & birweit!=. 
gen tmp2 = round(tmp , 1) 
replace birweit_compl = tmp2 if birweit_compl==. & birweit!=. 

drop tmp* 

*==== absolute birthweight categories 

**** five categories 
gen birthw_cat5=.
replace birthw_cat5=0 if birweit_compl<1000 & birweit_compl!=.
replace birthw_cat5=1 if birweit_compl>=1000 & birweit_compl<1500 & birweit_compl!=.
replace birthw_cat5=2 if birweit_compl>=1500 & birweit_compl<2500 & birweit_compl!=.
replace birthw_cat5=3 if birweit_compl>=2500 & birweit_compl<=4000 & birweit_compl!=.
replace birthw_cat5=4 if birweit_compl>4000 & birweit_compl!=.
label define birthw_cat5 0 "ELBW (<1000g)" 1 "VLBW (1000g-1500g)" 2 "LBW (1500g-2500g)" 3 "NBW (2500g-4000g)" 4 "HBW (>4000g)" , replace 
label values birthw_cat5 birthw_cat5

**** three categories 
gen birthw_cat3 = . 
replace birthw_cat3 = 0 if birweit_compl<2500 & birweit_compl!=.
replace birthw_cat3 = 1 if birweit_compl>=2500 & birweit_compl<=4000 & birweit_compl!=.
replace birthw_cat3 = 2 if birweit_compl>4000 & birweit_compl!=.
label define birthw_cat3 0 "Low birthweight" 1 "Normal birthweight" 2 "High birthweight" , replace 
label values birthw_cat3 birthw_cat3
tab birthw_cat5 birthw_cat3, m 

*==== size for gestation based on INTERGROWTH 21 
global size4gestat size_ig 
global sex sex_compl 
global birweit birweit_compl 
global gestat gestat_compl 

* run code to determine size of gestation based on Intergrowth 21st 
do "$do_file_path\1_3_size_for_gestation_intergrowth.do" 

label variable size_ig "size for gestation based on Intergrowth 21st"

tab size_ig , m 

*==== ethnicity group 

**---- ethnicity in the birth notification 
* get the first letter of ethnicity code (because some births have two letters, and the second letter contains letters that are not used in the code list: T U V W Y)
gen eth_bn = substr(baby_ethnicity , 1 , 1)
gen ethgroup_bn = . 
label variable ethgroup_bn "ethnicity group in birth notification" 

**---- ethnicity in HES APC 
gen ethgroup_hes = . 
label variable ethgroup_hes "ethnicity group in HES" 

gen eth_hes = ethnos 

foreach var in bn hes {
	replace ethgroup_`var' = 1 if inlist(eth_`var', "A", "B", "C") 
	replace ethgroup_`var' = 2 if inlist(eth_`var', "H", "J", "K", "L", "R")
	replace ethgroup_`var' = 3 if inlist(eth_`var', "M", "N", "P")
	replace ethgroup_`var' = 4 if inlist(eth_`var', "D", "E", "F", "G") 
	replace ethgroup_`var' = 5 if inlist(eth_`var', "S" , "Z")
	
	label define ethgroup_`var' 1 "White" 2 "Asian" 3 "Black" 4 "Mixed" 5 "Other" , replace 
	
	label value ethgroup_`var' ethgroup_`var'
}

**---- combine ethnicity groups from HES and birth notii
bysort tokenid : egen ethgroup_compl_tmp = mode(ethgroup_hes) 
replace ethgroup_compl_tmp = ethgroup_bn if ethgroup_compl==. & ethgroup_bn!=. 

label value ethgroup_compl_tmp ethgroup_hes

* inconsistent ethnicity group in HES and missing ethnicity group in birth notification 
count if ethgroup_compl_tmp==. & ethgroup_bn!=.  

decode ethgroup_compl_tmp , gen(ethgroup_compl) 

label variable ethgroup_compl "baby ethnicity group (after copying across episodes under 1 month and fill with info in birth notification)"

drop ethgroup_compl_tmp

encode ethgroup_compl , gen(ethgroup_baby_compl)

*==== maternal age 
*** additional cleaning
destring matage, replace
tab matage, mi

foreach var of varlist matage matage_clean {
	replace `var'=. if `var'>60
	replace `var'=. if `var'<10
}

*** copy mode of maternal age between episodes of the same tokenid
bysort tokenid: egen matage_compl=mode(matage) /* get mode of maternal age */

*** replace with maternal age from mother-baby link if missing 
replace matage_compl = matage_clean if matage_compl==. 

*** if still missing, replace with the mean across episdoes 
count if matage_compl==. & matage!=. 
codebook tokenid if matage_compl==. & matage!=. 

capture drop tmp* 

bysort tokenid : egen tmp = mean(matage) if matage_compl==. & matage!=. 
gen tmp2 = round(matage , 1 )

replace matage_compl =tmp2 if matage_compl==. & matage!=. 

drop tmp*

*==== residence area 

**---- England or non-England 

* resgor , government office region of residence 
bysort tokenid : egen resgor_compl = mode(resgor )

* resgor_ons , government office region of residence recommended to use from 2011-12 onwards 
bysort tokenid : egen resgor_ons_compl = mode(resgor_ons )

* rescty , county of residence 
bysort tokenid : egen rescty_compl = mode(rescty )
bysort tokenid : egen rescty_ons_compl = mode(rescty_ons )

*==== London or non-London 
* lsoa01 , lower super output area of residence 2001 
bysort tokenid : egen lsoa01_compl = mode(lsoa01)

* lsoa11 , lower super output area of residence 2011 
bysort tokenid : egen lsoa11_compl = mode(lsoa11)

* resladst , local authority district of residence (resladst_ons is completely missing)
bysort tokenid : egen resladst_compl = mode(resladst) 
bysort tokenid : egen resladst_ons_compl = mode(resladst_ons) 

* postdist , postcode district 
bysort tokenid : egen postdist_compl = mode(postdist)

* resro , regional office of residence: missing when resladst is missing 

*==== imd04 decile 
bysort tokenid : egen imd_decile_baby = mode(imd04rk_decile)

replace imd_decile_baby =  imd04_decile_cat_clean if imd_decile_baby==. 

label variable imd_decile_baby "IMD decile based on children's records under 1 month and Qi's mother-baby link"

*==== keep one line per child 
duplicates drop tokenid , force 

***************************************
* Covariate from mother's delivery records 
***************************************
gen year_dob = year(dob_mbl) 

*==== merge with mother's do-not-change-overtime variables from delivery records: age at first birth, ethnicity, number of children under 18 in the family by Feb 2020 
merge m:1 mtokenid using "$derived_data_path\3_12a_mother_age1stbirth_ethnicity_nchildprefeb2020.dta" , gen(merge_mother)

* check source of births (birth notification or Qi's mother baby link )
tab merge_Qimbl if merge_mother==1 

tab year_dob if merge_mother==1 & merge_Qimbl==1 

**---- mother's ethnicity 
* If mother's ethnicity is misisng, replace with children's ethnicity 
gen mother_ethnicity_compl = mother_ethnicity 

replace mother_ethnicity_compl = ethgroup_compl if mother_ethnicity=="" & ethgroup_compl!= ""

label variable mother_ethnicity_compl "Mother's ethnicity, filled with child's ethnicity if mother's ethnicity is missing"

encode mother_ethnicity_compl , gen(ethgroup_mother_compl)

**---- age at the first birth 
sum ageatfirstbirth , d 
count if ageatfirstbirth==. 

**---- number of children under 18 in the family by Feb 2020 
tab nchild_preFeb2020 , m 

recode nchild_preFeb2020 (0=0 "no") (1/max=1 "yes") , gen(otherchild) 
label variable otherchild "other children under 18 in the family by Feb 2020"

*==== merge with mother's change-over-time variables from delivery cohort: mothers who had only one delivery since 2016 
merge m:1 mtokenid using "$derived_data_path\3_12b_mother_maternalage_imd_residence_onedelivery" , gen(merge_mother_onedelivery) 

**---- fill residence area variables if missing 
foreach var in resgor resladst lsoa11 postdist {
	replace `var'_compl = `var'_m if `var'_compl=="" 
}

**---- fill maternal age if missing 
replace matage_compl = maternalage_atdelivery if matage_compl==. 

**---- imd04 decile of the mother 
gen imd04decile_mother_compl = imd04_decile_mother 

**---- delete variables 
drop  maternalage_atdelivery imd04_decile_mother lsoa11_m msoa11_m la_name_m la_cd_m region_name_m region_cd_m region_name_postdist_m postdist_m rescty_m resladst_m resladst_currward resgor_m ccg_residence_m merge_mother_onedelivery 

*==== merge with deliveries to mothers who had more than one delivery since 2016, but only have one delivery in one year

merge m:1 mtokenid year_dob using "$derived_data_path\3_12c_mother_maternalage_imd_residence_onedelivery_inoneyear" , gen(merge_mother_onedeliveryinayear)

drop if merge_mother_onedeliveryinayear==2 // delete delivery of children that are not in the birth cohort (possibly because of no mother-baby link available) 

* fill residence area variables if missing 
foreach var in resgor resladst lsoa11 postdist {
	replace `var'_compl = `var'_m if `var'_compl=="" 
}

**---- fill maternal age if missing 
replace matage_compl = maternalage_atdelivery if matage_compl==. 

**---- imd04 decile of the mother 
replace imd04decile_mother_compl = imd04_decile_mother if imd04decile_mother_compl==. 

drop maternalage_atdelivery imd04_decile_mother lsoa11_m msoa11_m la_name_m la_cd_m region_name_m region_cd_m region_name_postdist_m postdist_m rescty_m resladst_m resladst_currward resgor_m ccg_residence_m merge_mother_onedeliveryinayear

*==== merge with deliveries to mothers who had more than one delivery since 2016, and have multiple delivery in one year

**---- generate variable indicating whether the delivery is in the first half of the year or the second half of the year
gen month_dob = month(dob_mbl) 
gen halfofyear_dob = . 
replace halfofyear_dob = 1 if month_dob <=6 
replace halfofyear_dob = 2 if month_dob >6 
label define halfofyear_dob 1 "birthday is in the first half of the year" 2 "birthday is in the second half of the year"
label value halfofyear_dob halfofyear_dob

drop month_dob  

merge m:1 mtokenid year_dob halfofyear_dob using "$derived_data_path\3_12d_mother_maternalage_imd_residence_multipledeliveryoneyear.dta" , gen(merge_mother_multipledelivery) 

drop if merge_mother_multipledelivery==2 // delete delivery of children that are not in the birth cohort (possibly because of no mother-baby link available) 

* fill residence area variables if missing 
foreach var in resgor resladst lsoa11 postdist {
	replace `var'_compl = `var'_m if `var'_compl=="" 
}

**---- fill maternal age if missing 
replace matage_compl = maternalage_atdelivery if matage_compl==. 

**---- imd04 decile of the mother 
replace imd04decile_mother_compl = imd04_decile_mother if imd04decile_mother_compl==. 

tab imd04decile_mother_compl , m 

* if imd04decile_mother_compl is missing from mother's delivery records, replace with information from children's records 
replace imd04decile_mother_compl = imd_decile_baby if imd04decile_mother_compl==. 

**---- imd04 decile of the baby, fill with imd04 decile of the mother if missing 
gen imd04decile_baby_compl = imd_decile_baby 
replace imd04decile_baby_compl = imd04decile_mother_compl if imd04decile_baby_compl==. 

label define imd04_decile 1 "Most deprived 10%" 2 "More deprived 10-20%" 3 "More deprived 20-30%" ///
	4 "More deprived 30-40%" 5 "More deprived 40-50%" 6 "Less deprived 40-50%" ///
	7 "Less deprived 30-40%" 8 "Less deprived 20-30%" 9 "Less deprived 10-20%" ///
	10 "Least deprived 10%" , replace

label value imd04decile_baby_compl imd_decile_baby imd04decile_mother_compl imd04_decile

**---- delete variables 
drop maternalage_atdelivery imd04_decile_mother lsoa11_m msoa11_m la_name_m la_cd_m region_name_m region_cd_m region_name_postdist_m postdist_m rescty_m resladst_m resladst_currward resgor_m ccg_residence_m merge_mother_multipledelivery 

*==== categorise residential areas 

**---- government office region of residence (resgor) residential within births
gen resgor_tmp = ""
replace resgor_tmp = "" if resgor=="Y"
replace resgor_tmp = "North East" if resgor_compl=="A"
replace resgor_tmp = "North West" if resgor_compl=="B"
replace resgor_tmp = "North West" if resgor_compl=="C"
replace resgor_tmp = "Yorkshire and The Humber" if resgor_compl=="D"
replace resgor_tmp = "East Midlands" if resgor_compl=="E"
replace resgor_tmp = "West Midlands" if resgor_compl=="F"
replace resgor_tmp = "East of England" if resgor_compl=="G"
replace resgor_tmp = "London" if resgor_compl=="H"
replace resgor_tmp = "South East" if resgor_compl=="J"
replace resgor_tmp = "South West" if resgor_compl=="K"
replace resgor_tmp = "Scotland" if resgor_compl=="S"
replace resgor_tmp = "" if resgor_compl=="U"
replace resgor_tmp = "Wales" if resgor_compl=="W"
replace resgor_tmp = "Foreign" if resgor_compl=="X"
replace resgor_tmp = "Northern Ireland" if resgor_compl=="Z"

replace resgor_tmp = "North East" if resgor_ons_compl=="E12000001" & resgor_tmp==""
replace resgor_tmp = "North West" if resgor_ons_compl=="E12000002" & resgor_tmp==""
replace resgor_tmp = "Yorkshire and The Humber" if resgor_ons_compl=="E12000003" & resgor_tmp==""
replace resgor_tmp = "East Midlands" if resgor_ons_compl=="E12000004" & resgor_tmp==""
replace resgor_tmp = "West Midlands" if resgor_ons_compl=="E12000005" & resgor_tmp==""
replace resgor_tmp = "East of England" if resgor_ons_compl=="E12000006" & resgor_tmp==""
replace resgor_tmp = "London" if resgor_ons_compl=="E12000007" & resgor_tmp==""
replace resgor_tmp = "South East" if resgor_ons_compl=="E12000008" & resgor_tmp==""
replace resgor_tmp = "South West" if resgor_ons_compl=="E12000009" & resgor_tmp==""
replace resgor_tmp = "Scotland" if resgor_ons_compl=="S99999999" & resgor_tmp==""
replace resgor_tmp = "" if (resgor_ons_compl=="U" | resgor_ons_compl=="L99999999" | resgor_ons_compl=="E99999999")  & resgor_tmp==""
replace resgor_tmp = "Wales" if resgor_ons_compl=="W99999999" & resgor_tmp==""
replace resgor_tmp = "Foreign" if resgor_ons_compl=="X" & resgor_tmp==""
replace resgor_tmp = "Northern Ireland" if resgor_ons_compl=="N99999999" & resgor_tmp==""

**---- prepare geographic area link : lsoa11 and postdist to region 
preserve 
	* lsoa11 to region 
	import delimited using "$raw_data_path\lsoa11_lad11_rgn.csv" , clear 
	keep lsoa11cd lsoa11nm lad11cd lad11nm rgn11cd rgn11nm 
	rename lsoa11cd lsoa11_compl 
	save "$derived_data_path\3_13a_lsoa11_lad11_rgn.dta" , replace 

	* lad11 to region 
	keep lad11cd rgn11cd rgn11nm
	duplicates drop lad11cd , force 
	save "$derived_data_path\3_13b_lad11_rgn.dta" , replace 

	* postcode to region 
	import delimited using "$raw_data_path\postcode_lad11.csv" , clear varn(1)
	gen postdist_compl = substr(pcd7 , 1, 4) 
	keep postdist_compl lad11cd
	duplicates drop postdist_compl  , force 

	merge m:1 lad11cd using "$derived_data_path\3_13b_lad11_rgn.dta" , gen(merge_lad11) keep(match)

	keep postdist_compl rgn11cd rgn11nm 

	save "$derived_data_path\3_13c_postdist_rgn.dta" , replace 
restore 
	
**---- convert lsoa11 to region 
merge m:1 lsoa11_compl using "$derived_data_path\3_13a_lsoa11_lad11_rgn.dta" , keepusing(rgn11cd rgn11nm) keep(master match) nogenerate

rename rgn11cd rgncd_from_lsoa 
rename rgn11nm rgnnm_from_lsoa

**---- convert postdist to region 
merge m:1 postdist_compl using "$derived_data_path\3_13c_postdist_rgn.dta" , nogenerate keep(master match)

rename rgn11cd rgncd_from_postdist
rename rgn11nm rgnnm_from_postdist

*==== combine region derived from resgor_compl, lsoa11_compl and postdist_compl 
gen region_compl = resgor_tmp
replace region_compl = rgnnm_from_lsoa if region_compl=="" 
replace region_compl = rgnnm_from_postdist if region_compl=="" 

tab region_compl ,m 

**==== England and non-England 
gen englandres=. 
replace englandres = 1 if region_compl== "East Midlands" | region_compl=="East of England" | region_compl=="North East" | region_compl=="North West" | region_compl=="South East" | region_compl=="South West" | region_compl=="West Midlands" | region_compl=="Yorkshire and The Humber" | region_compl=="London"

replace englandres = 0 if region_compl=="Wales" | region_compl=="Scotland" | region_compl=="Foreign" | region_compl=="Northern Ireland" 

tab englandres , m 

**==== London and non-London 
gen londonres=. 

replace londonres=1 if region_compl== "London"

replace londonres=0 if region_compl== "East Midlands" | region_compl=="East of England" | region_compl=="North East" | region_compl=="North West" | region_compl=="South East" | region_compl=="South West" | region_compl=="West Midlands" | region_compl=="Yorkshire and The Humber"


*********************************
* Merge with death 
*********************************	
merge 1:1 tokenid using "$derived_data_path\3_11c_mortality_ONS+HES_2015_2024.dta" , gen(merge_death) keepusing(underlying_cause source_death dod)

gen death= (merge_death==3)

* drop death records that are not for children in the birth cohort 
drop if merge_death==2 
drop merge_death 

* define variable lables 
label variable source_death "source where death information come from"
label variable underlying_cause "underlying cause of death"
label variable dod "date of death"

*********************************
* merge with mother's chronic condition
********************************* 
merge 1:1 tokenid using "$derived_data_path\4_5a_mother_chroniccondition_3yprior_conception.dta" , gen(merge_mchronic)

* for children whose mother do not have an admission three years before conception, replace their mother chronic condition variables to "0-no"
foreach var of varlist mcc_* {
	replace `var' = 0 if merge_mchronic==1 & `var'==. 
}

*==== month of conception and birth 
**---- month of conception 
gen month_conception = mofd(doconception)
format month_conception %tm 

**---- month of birth 
gen month_bday = mofd(bday) 
format month_bday %tm 

recode month_bday (min/731=1 "born in 2020") (732/max=2 "born in 2021") , gen(month_bday_cat)

*==== save data 
misstable summarize *_compl ageatfirstbirth englandres londonres nchild_preFeb2020 bday gestation0 birthw_cat5 birthw_cat3 size_ig source_birth source_death mcc_total mcc_yorn 

duplicates report tokenid 

rename merge_Qimbl mbl_source 
label variable mbl_source "source of the baby-mother pair"

**---- save full data 
save "$derived_data_path\3_13z_covariates_full.dta" , replace 

**---- save covariates 
keep tokenid mtokenid dob_mbl bday year_dob stillbirth multibirth sex_compl gestat_compl termbirth birweit_compl birthw_cat5 birthw_cat3 size_ig ethgroup_baby_compl ethgroup_mother_compl ageatfirstbirth matage_compl nchild_preFeb2020 otherchild imd_decile_baby imd04decile_mother_compl imd04decile_baby_compl region_compl englandres londonres underlying_cause source_death source_birth mbl_source dod death gestation0 doconception mcc_* month_conception

save "$derived_data_path\3_13d_covariates.dta" , replace 

*==== merge with in-utero covid infection 
use "$derived_data_path\3_13d_covariates.dta" , clear 

merge m:1 tokenid using "$derived_data_path\5_6a_birthcohort_wi_covidstatus.dta" , gen(merge_covid) keepusing(covid_status_durpreg n_infection infect_wildtype infect_alpha infect_delta infect_omicron infect_variant positive_term* date_infection*)

* drop covid testing data for children not included in the birth cohort 
drop if merge_covid==2 

save "$derived_data_path\3_13e_covariates_covidstatus.dta" , replace 




