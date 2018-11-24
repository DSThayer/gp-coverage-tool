--Test 27
--If keep_non_sail_recs is 0 and group_on_practice is 1, none of the output falls outside the ranges of session.sail_gp_data.

--2) Run the procedure

call sail0286v.clean_gp_regs(
	--Use a unique table name so it doesn't clash with anyone else testing.
	target_table=>'sailx286v.test27',
	log_table=>'sailx286v.log', 	--Use this log for all.
	gp_data_extract=>'SAILWLGPV.GP_EVENT_CLEANSED_20170314',
	max_gap_to_fill=>1, 
	threshold=>.25,
	--medication_only=>0,
	group_on_sail_data=>1,
	group_on_practice=>1,
	keep_non_sail_recs=>0
)!

--3) Test the results and insert the test outcome into the test table.
--   You can add extra queries here if you need some preparatory steps.

insert into sailx286v.test_results
	with test_query as (
		select count(*) as num_non_gp_regs from sailx286v.test27 a
		inner join
		session.sail_gp_data b
		on a.prac_cd_e = b.prac_cd_e
		where not(start_date<=data_end and end_date>=data_start)
)
	select 
		--Enter the number of the test according to the spreadsheet here.
		27 as test_num,
		'If keep_non_sail_recs is 0 and group_on_practice is 1, none of the output falls outside the ranges of session.sail_gp_data.' as description,
		--test condition that proves whether the test passed here
		case when num_non_gp_regs = 0 	
			then 'pass' else 'fail'
		end as result,
		--Always include these
		SAILX286V.TEST_VERSION,
		current user,
		current timestamp
		from test_query!


--Clean up: drop the table the procedure created, as well as any other tables
--you created for the test.
drop table sailx286v.test27!
