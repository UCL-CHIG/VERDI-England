******************************************
** 5_3 clean multiple covid test on the same day 
**
** Reduce multiple tests on the same day to person-day-level covid test data, where one person has only one covid result/status on one day 
** 
** For women who had a birth between 2016 and 2023 
**
******************************************

*==== load data 
use "$derived_data_path\5_2e_sgss&pillar2_mother_of_birth1623_jan16jan24_testlevel.dta" , clear  

*==== Check multiple Covid tests for the same person on the same day 
codebook mtokenid 

* check duplicates records for all tests on the same day 
duplicates report mtokenid testdate 

duplicates tag mtokenid testdate , gen(multitest)
codebook mtokenid if multitest!=0  & multitest!=. 

bysort mtokenid testdate : egen average_result = mean(covidresult) 
gen same_result = . 
replace same_result = 1 if covidresult == average_result & covidresult!=.
replace same_result = 0 if covidresult != average_result & covidresult!=. 

tab same_result , m 
codebook mtokenid if same_result==0  

* check duplicates records for PCR tests on the same day
duplicates report mtokenid testdate if testtype==1 

duplicates tag mtokenid testdate if testtype==1 , gen(multipcr) 
codebook mtokenid if multipcr!=0 & multipcr!=. 
 
bysort mtokenid testdate : egen average_pcrresult = mean(covidresult) if testtype==1 

gen same_pcrresult = . 
replace same_pcrresult = 1 if covidresult == average_pcrresult & testtype==1 & covidresult != . 
replace same_pcrresult = 0 if covidresult != average_pcrresult & testtype==1 & covidresult!=. 

tab same_pcrresult if testtype==1 , m 
codebook mtokenid if same_pcrresult==0 & testtype==1 

*==== generate flags for women with different scenario of Covid testing 

gen test_sameday = . 
label variable test_sameday "Scenario of same-day Covid tests"

* senario 1 : one test or multiple tests with consistent results -> [use the consistent result]
replace test_sameday = 1 if same_result==1 

* senario 2 : multiple tests with inconsistent results but consistent PCR -> [take PCR's result]
bysort mtokenid testdate : egen consistent_pcr = total(same_pcrresult) , missing 

replace test_sameday = 2 if same_result==0 & consistent_pcr>=1 & consistent_pcr!=. 

* senario 3 : multiple LTR tests with inconsistent results and no PCR -> [if any is positive, treat as positive ; if negative + unknown, treat as negative]
replace test_sameday = 3 if same_result==0 & consistent_pcr==. 

* senario 4 : inconsistent PCR -> [if any is positive, treat as positive; if negative + unknown, treat as negative]
replace test_sameday = 4 if same_result==0 & consistent_pcr==0 

label define test_sameday 1 "one test or consistent results" 2 "inconsistent results but consistent PCR results" 3 "inconsistent LTR results no PCR" 4 "inconsistent PCR" , replace 
label value test_sameday test_sameday

* check the number of women in each senario 
codebook mtokenid if test_sameday==1 
codebook mtokenid if test_sameday==2  
codebook mtokenid if test_sameday==3 
codebook mtokenid if test_sameday==4 

* check if the four Covid testing scenarios are exclusive  
gen scenario1 = (same_result==1)
gen scenario2 = (same_result==0 & consistent_pcr>=1 & consistent_pcr!=. )
gen scenario3 = (same_result==0 & consistent_pcr==. )
gen scenario4 = (same_result==0 & consistent_pcr==0 )
gen sum_scenario = scenario1 + scenario2 + scenario3 + scenario4 
tab sum_scenario , m  
drop scenario1 scenario2 scenario3 scenario4 sum_scenario 

*==== determine test results for each person-day 

**---- create final covid test result variable 
gen covidresult_final = . 

label variable covidresult_final "Final covid test result (after cleaning multiple tests on the same day)"
label define covidresult_final 0 "Negative" 1 "Positive" 9 "Unknown" , replace 
label value covidresult_final covidresult_final

**---- senario 1 : one test or multiple tests with consistent results -> [use the consistent result]
bysort mtokenid testdate : egen s1result = mean(covidresult) if test_sameday==1 

replace covidresult_final = s1result if test_sameday==1 

**---- scenario2 : multiple tests with inconsistent results but consistent PCR -> [take PCR's result, when PCR is unknow, use results from LTR (positive if any LTR is positive, negative is all LTR is negative or unknown, unknown if all is unknown)] 

*** get the consistent result of PCR tests 
bysort mtokenid testdate : egen s2result = mean(covidresult) if testtype==1 & test_sameday==2 

*** for LTR tests on the same day, assign results from PCR tests 
bysort mtokenid testdate : egen s2result2 = mean(s2result) if test_sameday==2 

replace covidresult_final = s2result2 if test_sameday==2 

*** when PCR test is unknown, use results from LTR tests 
tab covidresult_final if test_sameday==2 , m 

*** flag tests where PCR is unknown for later determining the source of covid test results 
gen senario2_pcrresult = covidresult_final if test_sameday==2 

****. get results from LTR tests and give positive results the maximum value 
gen ltrresult = covidresult if test_sameday==2 & covidresult_final==9 

****. identify person-testday where all PCR tests have unknown results and any of the LTR tests is positive 
replace ltrresult = 100 if covidresult==1 & testtype==2 & test_sameday==2 & covidresult_final==9 

****. identify person-testday where all PCR tests have unknown resutls and all of the LTR tests is negative or unknown 
bysort mtokenid testdate : egen ltrresult_positive = max(ltrresult) if test_sameday==2 & covidresult_final==9 

bysort mtokenid testdate : egen ltrresult_negative = min(ltrresult) if test_sameday==2 & covidresult_final==9 & ltrresult_positive!=100  

****. if any of the LTR tests is positive (ltrresult==100), change the final test result to positive 
replace covidresult_final = 1 if ltrresult_positive == 100 

****. if none of the LTR tests is positive and any of the LTR tests is negative (ltrresult==0) , change the final test result to negative 
replace covidresult_final = 0 if ltrresult_negative== 0 & ltrresult_positive!=100 

****. if all of the LTR tests are unknown (ltrresult==9), change the final test result to unknown 
replace covidresult_final = 9 if ltrresult_negative==9 & ltrresult_positive!=100 

****. check the distribution of final covid test in senario 2 
tab covidresult_final if test_sameday==2 , m // none test have unknown result 

**---- scenario3 : multiple LTR tests with inconsistent results and no PCR -> [if any is positive, treat as positive ; if negative + unknown, treat as negative]
recode covidresult (0=0 "negative") (1=1 "positive") (9=-1 "unknown") , gen(result_4s3) 

bysort mtokenid testdate : egen s3result = max(result_4s3) if test_sameday==3 

replace covidresult_final = s3result if test_sameday==3 

* scenario 4 : inconsistent PCR -> [if any is positive, treat as positive; if negative + unknown, treat as negative]
recode covidresult (0=0 "negative") (1=1 "positive") (9=-1 "unknown") if testtype==1 , gen(result_4s4)

bysort mtokenid testdate : egen s4result = max(result_4s4) if test_sameday==4  

replace covidresult_final = s4result if test_sameday==4 

**---- check if tests for the same person on the same day have the consistent final result 
bysort mtokenid testdate : egen average_finalresult = mean(covidresult_final) 
gen consistent_finalresult = (covidresult_final == average_finalresult)
tab consistent_finalresult , m // final result for the same person on the same day are consistent 

**---- Source of covid test 
gen testsource = . 
label variable testsource "Source of covid test result"
label define testsource 1 "PCR" 2 "Antigen" , replace 
label values testsource testsource 

*** scenario 1 : if had PCR (testtype==1), source is PCR; if no PCR, source is LTR 
bysort mtokenid testdate : egen s1testsource = min(testtype) if test_sameday==1 

replace testsource = s1testsource if test_sameday==1 

*** scenario 2 

****. if PCR is not unknown results, from PCR 
replace testsource = 1 if test_sameday==2 & senario2_pcrresult != 9 

****. if PCR is unknown results, from LTR 
replace testsource = 2 if test_sameday==2 & senario2_pcrresult == 9 

*** scenario 3 : from LTR 
replace testsource = 2 if test_sameday==3  

*** scenario 4 : from PCR 
replace testsource = 1 if test_sameday==4 

*** check the distribution of source of test result 
tab testsource , m 

* delete variables 
drop average_result same_result average_pcrresult same_pcrresult consistent_pcr s1result s2result s2result2 senario2_pcrresult  ltrresult ltrresult_positive ltrresult_negative result_4s3 s3result result_4s4 s4result average_finalresult consistent_finalresult  s1testsource 

**---- drop duplicates tests for the same person on the same day 
duplicates drop mtokenid testdate , force 

tab testsource , m 

drop testtype pillar covidresult multitest multipcr
capture drop _merge 

* save data
save "$derived_data_path\5_3a_covid_result_mother_of birth1623_jan16jan24_person-day-level.dta" , replace 