--Test 6
--When an alf_e table is not specified, every practice that has events in sailwlgpv.gp_event is included 

--2) Run the procedure
CALL fnc.drop_if_exists('sailx0286v.test6')

call sailx0286v.clean_gp_regs(
	--Use a unique table name so it doesn't clash with anyone else testing.
	target_table=>'sailx0286v.test6',
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
		/*select count(t1.prac_cd_e) as num_gp_prac from sailx0286v.test6 t1
		left outer join  "SAILWLGPV"."PATIENT_ALF_20140718" t2
		on t1.prac_cd_e = t2.prac_cd_e
		where t2.prac_cd_e is null*/
		
		--fetch first 10 rows only
select count(distinct prac_cd_e) as num_gp_prac from sailx0286v.test6
		)
		
	
	select 
		--When an alf_e table is not specified, every practice that has events in sailwlgpv.gp_event is included 
		6 as test_num,
		'When an alf_e table is not specified, every practice that has events in sailwlgpv.gp_event is included ' as description,
		--test condition that proves whether the test passed here
		case when num_gp_prac =  (select count(distinct prac_cd_e) from sailwlgpv.gp_event)	
			then 'pass' else 'fail'
		end as result,
		--Always include these
		--sailx0286V.TEST_VERSION,  REMOVE TEMPORARILY (PYTHON will use later)
		current user,
		current timestamp
		from test_query!

--Clean up: drop the table the procedure created, as well as any other tables
--you created for the test.
drop table sailx0286v.test6!

