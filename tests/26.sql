--If keep_non_sail_recs is 1, the output covers all of the registrations for the input list of alf_es.  
--Test 26
----------------------------------------------------------------------------------------------------------------------------------------------

--Call the procedure 
   call fnc.drop_if_exists ('sailx0286v.test26')

   call sailx0286v.clean_gp_regs(
	--Use a unique table name so it doesn't clash with anyone else testing.
	target_table=>'sailx0286v.test26',
	log_table=>'sailx0286v.log', 	--Use this log for all.
	gp_data_extract=>'SAILWLGPV.GP_EVENT_CLEANSED_20170314',
	--alf_e_table=>'session.Registration_alf_test26', 
	max_gap_to_fill=>1, 
	threshold=>.1,
	--medication_only=>0,
	group_on_sail_data=>1,
	group_on_practice=>0,
	keep_non_sail_recs=>1
)!

--3) Test the results and insert the test outcome into the test table.
--You can add extra queries here if you need some preparatory steps.
 insert into sailx0286v.test_results   
      select 
		--Enter the number of the test according to the spreadsheet here.
		'26' as test_num,
		'If keep_non_sail_recs is 1, the output covers all of the registrations for the input list of alf_es' as description,
		--test condition that proves whether the test passed here
		case when 
		  (select count(*)
		  from
		   (
		   		select * from sailwdsdv.ar_pers_gp gp 
		   			join sailwdsdv.ar_pers person on 
		   				gp.pers_id_e = person.pers_id_e
		   			left join sailx0286v.test26 test on
		   				test.alf_e = person.alf_e 
		   			where test.alf_e is null
		   			and (dod is null or dod between from_dt and to_dt)	
		   )) 	   
          = 0
			then 'pass' else 'fail'
		end as result,
		--Always include these
		--sailx0286V.TEST_VERSION,
		current user,
		current timestamp
		from sysibm.sysdummy1!
		
drop table sailx0286v.test26!