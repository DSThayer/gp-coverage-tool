--Test 20
--If group_on_sail_data is set to 1 and group_on_practice is set to 1, keep_non_sail_records=0 no registrations within the period in session.sail_gp_data will be excluded.

--2) Run the procedure
call fnc.drop_if_exists ('sailx0286v.test20')

call sailx0286v.clean_gp_regs(
	--Use a unique table name so it doesn't clash with anyone else testing.
	target_table=>'sailx0286v.test20',
	log_table=>'sailx0286v.log', 	--Use this log for all.
	gp_data_extract=>'SAILWLGPV.GP_EVENT_CLEANSED_20170314',
	max_gap_to_fill=>1, 
	threshold=>.1,
	--medication_only=>0,
	group_on_sail_data=>1,
	group_on_practice=>1,
	keep_non_sail_recs=>0
)!

--3) Test the results and insert the test outcome into the test table.
--   You can add extra queries here if you need some preparatory steps.

--create a temp table to hold identified registrations with gap of one day


insert into sailx0286v.test_results
	with test_query as (
		--Test query here.
		select count(*) as row_count from (
		select * from sailx0286v.test20 test20 
			left outer join session.sail_gp_data gp
			on test20.prac_cd_e = gp.prac_cd_e
			and	test20.end_date >= gp.data_start
			and test20.start_date <=  gp.data_end 
					
		
	)
	)
	
	select 
		--Enter the number of the test according to the spreadsheet here.
		20 as test_num,
		'If group_on_sail_data is set to 1 and group_on_practice is set to 1, keep_non_sail_records=0 no registrations within the period in session.sail_gp_data will be excluded..' as description,
		--test condition that proves whether the test passed here
		case when row_count = (select count(*) as row_count from sailx0286v.test20 test20 where gp_data_flag = 1)  	
			then 'pass' else 'fail'
		end as result,
		--Always include these
		sailx0286V.TEST_VERSION,
		current user,
		current timestamp
		from test_query!

--Clean up: drop the table the procedure created, as well as any other tables
--you created for the test.
drop table sailx0286v.test20!

