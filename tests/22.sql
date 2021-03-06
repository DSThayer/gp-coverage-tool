--Test 22
--If group_on_sail_data is 1, a GP registration that overlaps the end of a good data period is broken into two registrations: one with GP data and one without GP data (set keep_non_sail_recs to 1 to test).

--2) Run the procedure
call fnc.drop_if_exists ('sailx0286v.test22')

call sailx0286v.clean_gp_regs(
	--Use a unique table name so it doesn't clash with anyone else testing.
	target_table=>'sailx0286v.test22',
	log_table=>'sailx0286v.log', 	--Use this log for all.
	gp_data_extract=>'SAILWLGPV.GP_EVENT_CLEANSED_20170314',
	max_gap_to_fill=>1, 
	threshold=>.1,
	--medication_only=>0,
	group_on_sail_data=>1,
	group_on_practice=>1,
	keep_non_sail_recs=>1
)!

--3) Test the results and insert the test outcome into the test table.
--   You can add extra queries here if you need some preparatory steps.

--create a temp table to hold identified registrations with gap of one day


insert into sailx0286v.test_results
	with test_query as (
		--Test query here.
		select count(*) as num_gp_fail from(
			select count(*), alf_e from sailx0286v.test22
			where alf_e in (		
			select alf_e from sailhnarv.ar_pers_gp gp
			join
			sailhnarv.ar_pers person
			on gp.pers_id_e = person.pers_id_e
			where alf_e in (		
				select alf_e from sailhnarv.ar_pers_gp gp2
				join
				session.sail_gp_data sail
				on gp2.prac_cd_e = sail.prac_cd_e
				join
				sailhnarv.ar_pers person2
				on gp2.pers_id_e = person2.pers_id_e
				where to_dt > data_end
				and from_dt > data_start and from_dt < data_end
				and dod is null
			)
			group by alf_e	
			having count(*)=1
			)
		group by alf_e
		having count(*)<2
		)
			
	)
	
	select 
		--Enter the number of the test according to the spreadsheet here.
		22 as test_num,
		'If group_on_sail_data is 1, a GP registration that overlaps the end of a good data period is broken into two registrations: one with GP data and one without GP data (set keep_non_sail_recs to 1 to test).' as description,
		--test condition that proves whether the test passed here
		case when num_gp_fail = 0  	
			then 'pass' else 'fail'
		end as result,
		--Always include these
		sailx0286V.TEST_VERSION,
		current user,
		current timestamp
		from test_query!

--Clean up: drop the table the procedure created, as well as any other tables
--you created for the test.
drop table sailx0286v.test22!

