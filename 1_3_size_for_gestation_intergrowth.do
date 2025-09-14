**================================================================
**  Size for gestational age based on INTERGROWTH 21st Centiles 
**===============================================================

* Cut-offs are from www.intergrowth21.ndog.ox.ac.uk 

gen $size4gestat = . 
label define size4gestat 0 "normal size" 1 "small for gestation" 2 "large for gestation" , replace 
label value $size4gestat size4gestat

replace $size4gestat=. if $birweit==. 

*==== BOYS 
* Boys newborn , <10th percentile 
replace $size4gestat=1 if $sex==1 & $birweit<1430 & $gestat==33 & $birweit!=. 
replace $size4gestat=1 if $sex==1 & $birweit<1710 & $gestat==34 & $birweit!=. 
replace $size4gestat=1 if $sex==1 & $birweit<1950 & $gestat==35 & $birweit!=. 
replace $size4gestat=1 if $sex==1 & $birweit<2180 & $gestat==36 & $birweit!=. 
replace $size4gestat=1 if $sex==1 & $birweit<2380 & $gestat==37 & $birweit!=. 
replace $size4gestat=1 if $sex==1 & $birweit<2570 & $gestat==38 & $birweit!=. 
replace $size4gestat=1 if $sex==1 & $birweit<2730 & $gestat==39 & $birweit!=. 
replace $size4gestat=1 if $sex==1 & $birweit<2880 & $gestat==40 & $birweit!=. 
replace $size4gestat=1 if $sex==1 & $birweit<3010 & $gestat==41 & $birweit!=. 
replace $size4gestat=1 if $sex==1 & $birweit<3120 & $gestat==42 & $birweit!=. 

* Boys very preterm (<33 weeks), <10th percentile 
replace $size4gestat=1 if $sex==1 & $birweit<500 & $gestat==24 & $birweit!=. 
replace $size4gestat=1 if $sex==1 & $birweit<570 & $gestat==25 & $birweit!=. 
replace $size4gestat=1 if $sex==1 & $birweit<650 & $gestat==26 & $birweit!=. 
replace $size4gestat=1 if $sex==1 & $birweit<740 & $gestat==27 & $birweit!=. 
replace $size4gestat=1 if $sex==1 & $birweit<840 & $gestat==28 & $birweit!=. 
replace $size4gestat=1 if $sex==1 & $birweit<950 & $gestat==29 & $birweit!=. 
replace $size4gestat=1 if $sex==1 & $birweit<1070 & $gestat==30 & $birweit!=. 
replace $size4gestat=1 if $sex==1 & $birweit<1210 & $gestat==31 & $birweit!=. 
replace $size4gestat=1 if $sex==1 & $birweit<1360 & $gestat==32 & $birweit!=. 

* Boys newborn , >90th percentile 
replace $size4gestat=2 if $sex==1 & $birweit>2520 & $gestat==33 & $birweit!=. 
replace $size4gestat=2 if $sex==1 & $birweit>2790 & $gestat==34 & $birweit!=. 
replace $size4gestat=2 if $sex==1 & $birweit>3030 & $gestat==35 & $birweit!=. 
replace $size4gestat=2 if $sex==1 & $birweit>3250 & $gestat==36 & $birweit!=. 
replace $size4gestat=2 if $sex==1 & $birweit>3450 & $gestat==37 & $birweit!=. 
replace $size4gestat=2 if $sex==1 & $birweit>3630 & $gestat==38 & $birweit!=. 
replace $size4gestat=2 if $sex==1 & $birweit>3790 & $gestat==39 & $birweit!=. 
replace $size4gestat=2 if $sex==1 & $birweit>3940 & $gestat==40 & $birweit!=. 
replace $size4gestat=2 if $sex==1 & $birweit>4060 & $gestat==41 & $birweit!=. 
replace $size4gestat=2 if $sex==1 & $birweit>4170 & $gestat==42 & $birweit!=. 

* Boys very preterm (<33 weeks), >90th percentile 
replace $size4gestat=2 if $sex==1 & $birweit>820 & $gestat==24 & $birweit!=. 
replace $size4gestat=2 if $sex==1 & $birweit>930 & $gestat==25 & $birweit!=. 
replace $size4gestat=2 if $sex==1 & $birweit>1060 & $gestat==26 & $birweit!=. 
replace $size4gestat=2 if $sex==1 & $birweit>1210 & $gestat==27 & $birweit!=. 
replace $size4gestat=2 if $sex==1 & $birweit>1370 & $gestat==28 & $birweit!=. 
replace $size4gestat=2 if $sex==1 & $birweit>1560 & $gestat==29 & $birweit!=. 
replace $size4gestat=2 if $sex==1 & $birweit>1760 & $gestat==30 & $birweit!=. 
replace $size4gestat=2 if $sex==1 & $birweit>1980 & $gestat==31 & $birweit!=. 
replace $size4gestat=2 if $sex==1 & $birweit>2230 & $gestat==32 & $birweit!=. 

*==== GIRLS 

* girls newborn , <10th percentile 
replace $size4gestat=1 if $sex==2 & $birweit<1410 & $gestat==33 & $birweit!=. 
replace $size4gestat=1 if $sex==2 & $birweit<1680 & $gestat==34 & $birweit!=. 
replace $size4gestat=1 if $sex==2 & $birweit<1920 & $gestat==35 & $birweit!=. 
replace $size4gestat=1 if $sex==2 & $birweit<2140 & $gestat==36 & $birweit!=. 
replace $size4gestat=1 if $sex==2 & $birweit<2330 & $gestat==37 & $birweit!=. 
replace $size4gestat=1 if $sex==2 & $birweit<2500 & $gestat==38 & $birweit!=. 
replace $size4gestat=1 if $sex==2 & $birweit<2650 & $gestat==39 & $birweit!=. 
replace $size4gestat=1 if $sex==2 & $birweit<2780 & $gestat==40 & $birweit!=. 
replace $size4gestat=1 if $sex==2 & $birweit<2890 & $gestat==41 & $birweit!=. 
replace $size4gestat=1 if $sex==2 & $birweit<2980 & $gestat==42 & $birweit!=. 

* girls very preterm (<33 weeks) , <10th percentile 
replace $size4gestat=1 if $sex==2 & $birweit<470 & $gestat==24 & $birweit!=. 
replace $size4gestat=1 if $sex==2 & $birweit<540 & $gestat==25 & $birweit!=. 
replace $size4gestat=1 if $sex==2 & $birweit<610 & $gestat==26 & $birweit!=. 
replace $size4gestat=1 if $sex==2 & $birweit<700 & $gestat==27 & $birweit!=. 
replace $size4gestat=1 if $sex==2 & $birweit<790 & $gestat==28 & $birweit!=. 
replace $size4gestat=1 if $sex==2 & $birweit<900 & $gestat==29 & $birweit!=. 
replace $size4gestat=1 if $sex==2 & $birweit<1010 & $gestat==30 & $birweit!=. 
replace $size4gestat=1 if $sex==2 & $birweit<1140 & $gestat==31 & $birweit!=. 
replace $size4gestat=1 if $sex==2 & $birweit<1280 & $gestat==32 & $birweit!=. 

* girls newborn , >90th percentile 
replace $size4gestat=2 if $sex==2 & $birweit>2350 & $gestat==33 & $birweit!=. 
replace $size4gestat=2 if $sex==2 & $birweit>2640 & $gestat==34 & $birweit!=. 
replace $size4gestat=2 if $sex==2 & $birweit>2890 & $gestat==35 & $birweit!=. 
replace $size4gestat=2 if $sex==2 & $birweit>3120 & $gestat==36 & $birweit!=. 
replace $size4gestat=2 if $sex==2 & $birweit>3320 & $gestat==37 & $birweit!=. 
replace $size4gestat=2 if $sex==2 & $birweit>3510 & $gestat==38 & $birweit!=. 
replace $size4gestat=2 if $sex==2 & $birweit>3660 & $gestat==39 & $birweit!=. 
replace $size4gestat=2 if $sex==2 & $birweit>3800 & $gestat==40 & $birweit!=. 
replace $size4gestat=2 if $sex==2 & $birweit>3920 & $gestat==41 & $birweit!=. 
replace $size4gestat=2 if $sex==2 & $birweit>4010 & $gestat==42 & $birweit!=. 

* girls very preterm (<33 weeks) , >90th percentile 
replace $size4gestat=2 if $sex==2 & $birweit>770 & $gestat==24 & $birweit!=. 
replace $size4gestat=2 if $sex==2 & $birweit>880 & $gestat==25 & $birweit!=. 
replace $size4gestat=2 if $sex==2 & $birweit>1010 & $gestat==26 & $birweit!=. 
replace $size4gestat=2 if $sex==2 & $birweit>1140 & $gestat==27 & $birweit!=. 
replace $size4gestat=2 if $sex==2 & $birweit>1300 & $gestat==28 & $birweit!=. 
replace $size4gestat=2 if $sex==2 & $birweit>1470 & $gestat==29 & $birweit!=. 
replace $size4gestat=2 if $sex==2 & $birweit>1660 & $gestat==30 & $birweit!=. 
replace $size4gestat=2 if $sex==2 & $birweit>1870 & $gestat==31 & $birweit!=. 
replace $size4gestat=2 if $sex==2 & $birweit>2110 & $gestat==32 & $birweit!=. 



*==== Boys and girls with gestation <24 weeks or > 42 weeks 

* normal size 
recode $size4gestat .=0 if $birweit!=. & $sex!=. & $gestat!=. 
