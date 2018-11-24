--If group_on_practice is 0, two records from different practices are combined.
--Test 25
----------------------------------------------------------------------------------------------------------------------------------------------
/*The idea is create a customized table where there are all the alf_e but not the one with same practice and two from_dt with a 'delay' of 1 day
  Doing that and set the max_gap_to_fill=>1 we will forecast to have the same alf_es in the outputtable.*/  
   
   declare global temporary table session.Duplicate_alf_no_overlapping_test25(
 	alf_e integer
 ) with replace on commit preserve rows!
 
--To do: make sure the two registrations don't completely overlap. 
 insert into session.Duplicate_alf_no_overlapping_test25
    select alf_e
    from (
    select
     ar.alf_e,
    count(*) num_registrations,
     count(distinct prac_cd_e) num_practices,
     min(to_dt)	first_end,
     max(from_dt) last_start
     from sailhnarv.ar_pers_gp gp
        inner join "SAILHNARV"."AR_PERS" ar
          on gp.PERS_ID_E = ar.PERS_ID_E
     group by alf_e,dod
     having dod >= max(from_dt) or dod is null
      )    
      where num_registrations = 2 
      	and num_practices = 2
      	and first_end < last_start!
   
   call fnc.drop_if_exists ('sailx0286v.test25')
   
   call sailx0286v.clean_gp_regs(
	--Use a unique table name so it doesn't clash with anyone else testing.
	target_table=>'sailx0286v.test25',
	log_table=>'sailx0286v.log', 	--Use this log for all.
	alf_e_table=>'session.Duplicate_alf_no_overlapping_test25', 
	gp_data_extract=>'SAILWLGPV.GP_EVENT_CLEANSED_20170314',
	max_gap_to_fill=>1, 
	threshold=>.1,
	--medication_only=>0,
	group_on_sail_data=>0,
	group_on_practice=>0,
	keep_non_sail_recs=>0
)!

--Use the same query as 24.
--Check that the output does not have two records within 1 day of each other for the same ALF_E

--3) Test the results and insert the test outcome into the test table.
--You can add extra queries here if you need some preparatory steps.
 insert into sailx0286v.test_results   
      select 
		--Enter the number of the test according to the spreadsheet here.
		'25' as test_num,
		'If group_on_practice is 0, two records from different practices are combined' as description,
		--test condition that proves whether the test passed here
		case when 
		    (select count(*)
			    from (
			    select
			      count(*) num_registrations,
			     count(distinct prac_cd_e) num_practices
			     from sailx0286v.test25
			     group by alf_e
			      )    
			      where num_practices = 2  and num_registrations = 1
			)        
          = 0
			then 'pass' else 'fail'
		end as result,
		--Always include these
		sailx0286V.TEST_VERSION,
		current user,
		current timestamp
		from sysibm.sysdummy1!
		
 drop table sailx0286v.test25!
