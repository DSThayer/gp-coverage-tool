--Test 39
--The start date of a record cannot be before birth (according to sailhnarv.ar_pers birth date), even if such a record exists in sailhnarv.ar_pers_gp.

--2) Run the procedure
call fnc.drop_if_exists ('sailx0286v.test39')
call sail0286v.clean_gp_regs(
	--Use a unique table name so it doesn't clash with anyone else testing.
	target_table=>'sailx286v.test39',
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
	select count (*) row_count from( 
		select wob, start_date from sailx286v.test39 test39
		inner join sailhnarv.ar_pers person
			on  test39.alf_e = person.alf_e
		where wob > start_date) dtable		
		
	)
	select 
		--Enter the number of the test according to the spreadsheet here.
		39 as test_num,
		'The start date of a record cannot be before birth (according to sailhnarv.ar_pers birth date), even if such a record exists in sailhnarv.ar_pers_gp.' as description,
		--test condition that proves whether the test passed here
		case when row_count = 0 	
			then 'pass' else 'fail'
		end as result,
		--Always include these
		SAILX286V.TEST_VERSION,
		current user,
		current timestamp
		from test_query!

--Clean up: drop the table the procedure created, as well as any other tables
--you created for the test.
drop table sailx286v.test39!

