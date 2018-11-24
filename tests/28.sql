--Test 28
--Start date is always less than or equal to end date.

--2) Run the procedure
call fnc.drop_if_exists ('sailx0286v.test28')

call sailx0286v.clean_gp_regs(
	--Use a unique table name so it doesn't clash with anyone else testing.
	target_table=>'sailx0286v.test28',
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
 insert into sailx0286v.test_results
      select 
		--Enter the number of the test according to the spreadsheet here.
		'28' as test_num,
		'end_date is never before start_date' as description,
		--test condition that proves whether the test passed here
		case when 
			(
			select count(*)
			from sailx0286v.test28
			where start_date > end_date
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
drop table sailx0286v.test28!
