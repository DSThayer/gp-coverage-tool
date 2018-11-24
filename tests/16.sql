--Test 16
--If group_on_sail_data is set to 0, the output includes everyone from the input who had at least one GP registration in sailhnarv.ar_pers_gp 
--(link to alf_e using sailhnarv.ar_pers)

--2) Run the procedure
caLL fnc.drop_if_exists ('sailx0286v.test16')

call sailx0286v.clean_gp_regs(
	--Use a unique table name so it doesn't clash with anyone else testing.
	target_table=>'sailx0286v.test16',
	log_table=>'sailx0286v.log', 	--Use this log for all.
	gp_data_extract=>'SAILWLGPV.GP_EVENT_CLEANSED_20170314',
	max_gap_to_fill=>1, 
	threshold=>.1,
	--medication_only=>0,
	group_on_sail_data=>0,
	group_on_practice=>1,
	keep_non_sail_recs=>0
	
	
	
	
)!







--3) Test the results and insert the test outcome into the test table.
--   You can add extra queries here if you need some preparatory steps.

--create a temp table to hold identified registrations with gap of one day


 insert into sailx0286v.test_results
      select 
		--Enter the number of the test according to the spreadsheet here.
		'16' as test_num,
		'If group_on_sail_data is set to 0, the output includes everyone from the input who had at least one GP registration in sailhnarv.ar_pers_gp' as description,
		--test condition that proves whether the test passed here
		case when 
			
			(select count(distinct b.alf_e)
			from sailhnarv.ar_pers_gp a 
			inner join sailhnarv.ar_pers b
			 on  a.pers_id_e = b.pers_id_e
			left outer join sailx0286v.test16 o
			  on b.alf_e = o.alf_e 
			where b.alf_e is null ) 
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

--select * from sailx0286v.test_results
drop table sailx0286v.test16!
