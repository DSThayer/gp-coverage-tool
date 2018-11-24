--Test 5
--Each practice has only one entry in session.sail_gp_data..
declare global temporary table session.Duplicate_alf_test5(
 	alf_e bigint
 ) with replace on commit preserve ROWS!
 
 
 insert into session.Duplicate_alf_test5
   select alf_e
   from "SAILHNARV"."AR_PERS"
   fetch first 10000 rows ONLY!
   
 insert into session.Duplicate_alf_test5
   select alf_e
   from "SAILHNARV"."AR_PERS"
   fetch first 10000 rows ONLY!
  
   
 /* Double check if the insert works
   select count(*)
   from session.Duplicate_alf_test5*/
  
 --Checl if there are duplicate  
  /*select count(*),alf_e 
    from session.Duplicate_alf_test5
    group by alf_e
    having count(*) = 2 */
   
SELECT * FROM SAILWLGPV.PATIENT_ALF_CLEANSED_20170314 

--2) Run the procedure
call fnc.drop_if_exists ('sailx0286v.test5')!

call sailx0286v.clean_gp_regs(
	--Use a unique table name so it doesn't clash with anyone else testing.
	target_table=>'sailx0286v.test5',
	log_table=>'sailx0286v.log', 	--Use this log for all.
	alf_e_table=>'session.Duplicate_alf_test5', 
	gp_data_extract=>'SAILWLGPV.GP_EVENT_CLEANSED_20170314',
	max_gap_to_fill=>1, 
	threshold=>.1,
	--medication_only=>0,
	group_on_sail_data=>0,
	group_on_practice=>1,
	keep_non_sail_recs=>0,
	ignore_practices_with_missing_data=>1,
	birth_correction=>1,
	use_median_event_rates=>1
)!






--3) Test the results and insert the test outcome into the test table.
--   You can add extra queries here if you need some preparatory steps.

--create a temp table to hold identified registrations with gap of one day


 insert into sailx0286v.test_results
      select 
		--Enter the number of the test according to the spreadsheet here.
		'5' as test_num,
		'When an alf_e table has duplicate alf_es, the output contains no duplicates.' as description,
		--test condition that proves whether the test passed here
		case when 
			(select count(*) 
			from(
		          select count(*),alf_e, start_date
		          from sailx0286v.test5
                  group by alf_e, start_date
                  having count(*) > 1)
             )
           = 0	
			then 'pass' else 'fail'
		end as result,
		--Always include these
		sailx0286V.TEST_VERSION,
		current user,
		current timestamp
		from sysibm.sysdummy1!
		
		
--Clean up: drop the table the procedure created, as well as any other tables
--you created for the test.
drop table sailx0286v.test5!
