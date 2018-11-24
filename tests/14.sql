--Test 14
--Each practice has only one entry in session.sail_gp_data..

--2) Run the procedure

call sail0286v.clean_gp_regs(
	--Use a unique table name so it doesn't clash with anyone else testing.
	target_table=>'sailx286v.test14',
	log_table=>'sailx286v.log', 	--Use this log for all.
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


insert into sailx286v.test_results
	with test_query as (
		--Test query here.
		select count(*) as num_gp_prac from (select count(*) from session.sail_gp_data
		group by prac_cd_e
		having count(*)>1)
	)
	select 
		--Enter the number of the test according to the spreadsheet here.
		14 as test_num,
		'Each practice has only one entry in session.sail_gp_data.' as description,
		--test condition that proves whether the test passed here
		case when num_gp_prac = 0 	
			then 'pass' else 'fail'
		end as result,
		--Always include these
		SAILX286V.TEST_VERSION,
		current user,
		current timestamp
		from test_query!

--Clean up: drop the table the procedure created, as well as any other tables
--you created for the test.
drop table sailx286v.test14!

