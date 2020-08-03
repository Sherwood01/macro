/************************************
Author: Denys Zinchuk
Parameters:  "indir" library path with SDTM- dataets
             "otdir" library path where to save output dataset
             
               

************************************/

options missing=' ';
%macro sdtm_ae_base(indir, otdir);
  %include _setup;
  options nomprint;

  libname in "&indir" inencoding=any outencoding = any extendobscounter=NO;
  libname out "&otdir" inencoding=any outencoding = any extendobscounter=NO;

  ods trace on;
  ods output Members=Members;
  proc datasets library=in memtype=data;run;
  ods trace off;

  proc sql noprint;		
	select 		
		name into :all_datasets separated by ' '
	from members
    having upcase(name) like 'AE_%';
 quit;

 %local dcount dname;
 %let dcount=0;
 %let dname = ;


%do %while(%qscan(&all_datasets,&dcount+1,%str( )) ne %str());
   %let dcount = %eval(&dcount+1);
%end;

* getting all SDTM- data related to AE;
data step1;
 set
%do i=1 %to &dcount;
   %let dname = %scan(&all_datasets,&i,%str( ));
     in.&dname
%end;
;
run;

data step2;
  length aeacnm $200;
  set step1;
  if ^missing(aeterm);

  *deriving AEACN if multiple options were specified;
  if missing(aeacn) and cmiss(AEACN_WT,AEACN_DNC,AEACN_INC,AEACN_RED,AEACN_INT,AEACN_DL,AEACN_NA)<7 then do;
    if AEACN_WT='Y' then aeacn='DRUG WITHDRAWN';
    if AEACN_DNC='Y' then aeacn='DOSE NOT CHANGED';
	if AEACN_INC='Y' then aeacn='DOSE INCREASED';
	if AEACN_RED='Y' then aeacn='DOSE REDUCED';
	if AEACN_INT='Y' then aeacn='DRUG INTERRUPTED';
	if AEACN_DL='Y' then aeacn='DOSE DELAYED';
	if AEACN_NA='Y' then aeacn='NOT APPLICABLE';
  end;

  aeacnm=catx('/',AEACN_WT,AEACN_DNC,AEACN_INC,AEACN_RED,AEACN_INT,AEACN_DL,AEACN_NA);
  k=length(compress(aeacnm,'N/'));
  if k>=2 then aeacn='MULTIPLE';
run;

%finalize(step2,AE,aestdtc,,,N,Y,N,,N,,);

ods select none;
ods output nlevels=want;

proc freq data=step2 nlevels;
  table _all_;
run;

ods select all;
proc sql noprint;
  *all variables which are empty for all records;
  select upcase(TableVar) into : missing_variables separated by ' '
  from want
  where NNonMissLevels=0;
quit;
proc sql noprint;
  *all available variables in raw data;
  select upcase(TableVar) into : all_variables separated by ' '
  from want;
quit;

*to keep all required and expected variables even if they are empty;
%let required_vars = STUDYID DOMAIN USUBJID AESEQ AETERM AELLT AELLTCD AEDECOD AEPTCD AEHLT AEHLTCD AEHLGT AEHLGTCD
                     AEBODSYS AEBDSYCD AESOC AESOCCD AESER AEACN AEREL AESTDTC AEENDTC;

*all possible variables in SDTM;
%let keepvars = STUDYID DOMAIN USUBJID AESEQ AEGRPID AEREFID AESPID AETERM AEMODIFY AELLT AELLTCD AEDECOD AEPTCD AEHLT AEHLTCD AEHLGT
				AEHLGTCD AECAT AESCAT AEPRESP AEBODSYS AEBDSYCD AESOC AESOCCD AELOC AESEV AESER AEACN AEACNOTH AEREL AERELNST AEPATT
				AEOUT AESCAN AESCONG AESDISAB AESDTH AESHOSP AESLIFE AESOD AESMIE AECONTRT AETOXGR AEDTC AESTDTC AEENDTC AEDY AESTDY
                AEENDY AEDUR AEENRF AEENRTPT AEENTPT EPOCH;

%let dcount=0;
%let dname = ;
%let dsid=%sysfunc(open(step2));


%do %while(%qscan(&all_variables,&dcount+1,%str( )) ne %str());
   %let dcount = %eval(&dcount+1);
%end;

data ae;
  set step2;

  *to strip all character variables;
  %do i=1 %to &dcount;
   %let dname = %scan(&all_variables,&i,%str( ));
   %if %sysfunc(index(%str( &missing_variables ),%str( &dname )))=0 and %sysfunc(index(%str( &keepvars ),%str( &dname )))^=0 %then %do; 
	%let varnum =  %sysfunc(varnum(&dsid,&dname));
    %if %sysfunc(vartype(%str(&dsid),&varnum))=C %then %do;&dname = strip(&dname);%end;
   %end;
  %end;

  *to drop all variables that are not needed in final SDTM;
  drop
  %do i=1 %to &dcount;
   %let dname = %scan(&all_variables,&i,%str( ));
   %if %sysfunc(index(%str( &missing_variables ),%str( &dname )))^=0 and %sysfunc(index(%str(&required_vars),%str(&dname)))=0 %then %do; &dname %end;
   %else %if %sysfunc(index(%str( &keepvars ),%str( &dname )))=0 %then %do; &dname %end;
  %end;
  ;
run;

%let rc=%sysfunc(close(&dsid)); 

*save final dataset;
data out.AE;
  set ae;
run;


%mend sdtm_ae_base;

%sdtm_ae_base(D:\Rave Demo\20190419_E7727-01_20190924\Mask\Rave_EDC\deliverables\sdtm_minus, D:\Rave Demo\20190419_E7727-01_20190924\Mask\Rave_EDC\deliverables\sdtm);
