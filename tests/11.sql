--Test 11
--When threshold is set to .001,  longest continuous period of months with event_rate >= .001 are counted as having GP data.

--2) Run the procedure

call sail0286v.clean_gp_regs(
	--Use a unique table name so it doesn't clash with anyone else testing.
	target_table=>'sailx286v.test11',
	log_table=>'sailx286v.log', 	--Use this log for all.
	gp_data_extract=>'SAILWLGPV.GP_EVENT_CLEANSED_20170314',
	max_gap_to_fill=>1, 
	threshold=>.001,
	--medication_only=>0,
	group_on_sail_data=>0,
	group_on_practice=>1,
	keep_non_sail_recs=>0
)!

--3) Test the results and insert the test outcome into the test table.
--   You can add extra queries here if you need some preparatory steps.

--create a temp table to hold identified registrations with threshold of >=.001


declare global temporary table session.gptest11table
(prac_cd_e integer, 
data_start date,
data_end date,
length_of_continuous_events integer, 
data_group integer,
period_length_rank integer)with replace on commit preserve rows! 


insert into session.gptest11table
select prac_cd_e, 
		min(month_start) as data_start, 
		max(month_end) as data_end, 
		days(max(month_end)) - days(min(month_start)) as length_of_continuous_events, 
		data_group, 
		row_number() over 
			( 	partition by prac_cd_e,
				case when year(max(month_end)) >= 2008 then 1 
				else 0 
				end 
				order by days(max(month_end)) - days(min(month_start)) desc ) as period_length_rank 
from (
	select prac_cd_e, 
			relative_event_rate as event_rate, 
			date(event_yr || '-' || event_mo || '-' || '01') as month_start, 
			date(event_yr || '-' || event_mo || '-' || '01') + 1 month - 1 day as month_end, 
			(row_number() over 
				( 	partition by prac_cd_e 
					order by prac_cd_e, event_yr, event_mo) 
			) - 
			(row_number() over 
				( 	partition by prac_cd_e, 
					case when relative_event_rate >= .001 then 1 
					else 0 
					end 
					order by prac_cd_e, event_yr, event_mo) 
			) as data_group, 
			case when relative_event_rate >= .001 then 1 
			else 0 
			end as good_data 
	from sail0286v.gp_event_rates_20140718 
	) 
where good_data = 1 
group by prac_cd_e, data_group!



insert into sailx286v.test_results
	with test_query as (
		select count (*) as count_of_matches
		from (	select a.prac_cd_e, 
						a.data_start,
						a.data_end
				from session.gptest11table a
				left join
				session.sail_gp_data b
				on a.prac_cd_e = b.prac_cd_e
				and a.data_start = b.data_start
				and a.data_end = b.data_end
				where period_length_rank = 1
				and b.prac_cd_e is null
				group by a.prac_cd_e, 
							a.data_start,
							a.data_end
				having  year(max(a.data_end)) >= 2008
				order by a.prac_cd_e)
				
		UNION
		select count (*)
		from (	select a.prac_cd_e, 
						a.data_start,
						a.data_end
				from session.gptest11table a
				right join
				session.sail_gp_data b
				on a.prac_cd_e = b.prac_cd_e
				and a.data_start = b.data_start
				and a.data_end = b.data_end
				where period_length_rank = 1
				and a.prac_cd_e is null
				group by a.prac_cd_e, 
							a.data_start,
							a.data_end
				having  year(max(a.data_end)) >= 2008
				order by a.prac_cd_e)
)
	select 
		--Enter the number of the test according to the spreadsheet here.
		11 as test_num,
		'When threshold is set to .001,  longest continuous period of months with event_rate >= .001 are counted as having GP data.' as description,
		--test condition that proves whether the test passed here
		case when sum(count_of_matches) = 0 	
			then 'pass' else 'fail'
		end as result,
		--Always include these
		SAILX286V.TEST_VERSION,
		current user,
		current timestamp
		from test_query!


--Clean up: drop the table the procedure created, as well as any other tables
--you created for the test.
drop table sailx286v.test11!

