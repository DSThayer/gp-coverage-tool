--Test 29
--There are never overlapping periods in the output for any single individual..




--2) Run the procedure
call fnc.drop_if_exists ('sailx0286v.test29')
call sail0286v.clean_gp_regs(
	--Use a unique table name so it doesn't clash with anyone else testing.
	target_table=>'sailx286v.test29',
	log_table=>'sailx286v.log', 	--Use this log for all.
	gp_data_extract=>'SAILWLGPV.GP_EVENT_CLEANSED_20170314',
	max_gap_to_fill=>30, 
	threshold=>.1,
	--medication_only=>0,
	group_on_sail_data=>1,
	group_on_practice=>0,
	keep_non_sail_recs=>1
)!

--3) Test the results and insert the test outcome into the test table.
--   You can add extra queries here if you need some preparatory steps.

insert into sailx286v.test_results
	with test_query as (
		--Test query here.
		select count(*) as unmatched_records 
 			from (
 			select 	count(*) as unmatched_records, 
				test29_2.alf_e  
 			from sailx286v.test29 test29_1 				
			inner join sailx286v.test29 test29_2 on
				test29_2.alf_e = test29_1.alf_e and
				(
				
					test29_2.end_date >= test29_1.start_date
					and test29_2.start_date <=  test29_1.end_date 
					 
				)  
				and test29_1.start_date <> test29_2.start_date
	
	group by test29_2.alf_e  
HAVING count(*) > 0
 			
 			)
	)
	select 
		--Enter the number of the test according to the spreadsheet here.
		29 as test_num,
		'There are never overlapping periods in the output for any single individual..' as description,
		--test condition that proves whether the test passed here
		case when unmatched_records = 0 	
			then 'pass' else 'fail'
		end as result,
		--Always include these
		SAILX286V.TEST_VERSION,
		current user,
		current timestamp
		from test_query!

--Clean up: drop the table the procedure created, as well as any other tables
--you created for the test.
drop table sailx286v.test29!

