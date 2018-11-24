---------------------------------------------------------------------------------------------------
--calculate_event_rates.sql
--
--Dan Thayer
--
--Copyright 2018 Swansea University
--
--Licensed under the Apache License, Version 2.0 (the "License");
--you may not use this file except in compliance with the License.
--You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
--Unless required by applicable law or agreed to in writing, software
--distributed under the License is distributed on an "AS IS" BASIS,
--WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--See the License for the specific language governing permissions and
--limitations under the License.
--
---------------------------------------------------------------------------------------------------
--
--A procedure that calculates monthly event rates in the SAIL GP dataset (www.saildatabank.com).
--This is a supporting process for the GP coverage tool. It must be run once for each new version
--of the dataset, and it populates a table that is used to then measure GP coverage.

call fnc.drop_specific_proc_if_exists('sail0286v.median_gp_event_rates')!
create procedure sail0286v.median_gp_event_rates(
    good_year integer,
    output_table        varchar(250),
    gp_event_table      varchar(250),
    registrant_table    varchar(250),
    log_table           varchar(250)
)
specific sail0286v.median_gp_event_rates
MODIFIES SQL DATA
language SQL
begin
    call fnc.log_start('sail0286v.median_gp_event_rates',log_table);    

    begin
        declare table_existed integer;
        declare table_already_exists condition for sqlstate '42710';  --Attempt was made to create or rename table that already exist
        declare continue handler for table_already_exists set table_existed = 1;
    
        execute immediate '
            create table '||output_table||' (
                prac_cd_e               integer,
                event_yr                integer, 
                event_mo                integer,
                registrants             integer,
                median_events           integer,
                median_events_per_cap   float,
                relative_event_rate     float,
                avail_from_dt           timestamp
            )
        ';
        
        if table_existed = 1 then
            call fnc.log_msg('Emptying existing table '||output_table);
            execute immediate 'delete from '||output_table;
        else
            call fnc.log_msg('Created new table '||output_table);
        end if;
    end;

    declare global temporary table session.events_per_weekday (
        prac_cd_e   int,
        event_dt    date,
        event_yr    int,
        event_mo    int,
        events      int
    ) with replace on commit preserve rows;

    declare global temporary table session.good_years (
        prac_cd_e int,
        good_year int
    ) with replace on commit preserve rows;

    execute immediate '
        insert into session.good_years
            with years (yr) as (
                select '||good_year||' yr from sysibm.sysdummy1
                union all
                select yr + 1 from years where yr < year(current timestamp)-1
            ),
            year_regs as (
                select yr,prac_cd_e,count(*) recs from '||registrant_table||'
                    join years on
                        yr||''-01-01'' between start_date and end_date
                group by yr,prac_cd_e
                having count(*) >= 100
                order by prac_cd_e,yr
            )
            select prac_cd_e,min(yr) good_year from year_regs
                group by prac_cd_e
    ';    
    
    execute immediate '
        insert into session.events_per_weekday
            select  prac_cd_e,
                    full_date, 
                    cal_year,
                    month_no,
                    count(*)
                from sailukhdv.ref_dates dates
                left join '||gp_event_table||' gp on
                    event_yr = cal_year and
                    gp.event_dt = full_date and
                    event_yr >= 1970
                where weekday_no between 1 and 5 and cal_year between 1970 and year(current timestamp)
                group by prac_cd_e,full_date,cal_year,month_no
    ';
    
    --Calculate the median events per weekday for each month at each practice.
    --For median we take the middle value if there is an odd number of values, or average the two
    --middle values if there is an even number.  The median_events part of the query below does this.
    --
    --This expression in the where clause returns a single row for a month with an odd number of rows,
    --or two rows for a month with an even number of rows:
    --    month_rank between (month_days+1)/2 and (month_days+2)/2
    --This expression averages the two rows if there are two.  If there is only one, it just gets 
    --used:
    --    avg(events) median
    
    execute immediate '
        insert into '||output_table||' 
    with ranked as (
    select  prac_cd_e,event_yr,event_mo,
            events,
            row_number() over (partition by prac_cd_e,event_yr,event_mo order by events) as month_rank,
            count(*) over (partition by prac_cd_e,event_yr,event_mo) as month_days
       from session.events_per_weekday
    ), 
    median_events as (
        select  prac_cd_e,event_yr,event_mo,
                avg(events) median 
            from ranked 
            where month_rank between (month_days+1)/2 and (month_days+2)/2
            group by prac_cd_e,event_yr,event_mo
    )
    select  median_events.prac_cd_e,median_events.event_yr,median_events.event_mo,
            count(*),
            median,
            case when count(*) > 5 then cast(median as float)/count(*) else 0 end,
            null,
            current timestamp
       from median_events
       join '||registrant_table||' reg_table on
            reg_table.prac_cd_e = median_events.prac_cd_e and
            lpad(median_events.event_yr,4,''0'')||''-''||median_events.event_mo||''-15'' between start_date and end_date
       group by median_events.prac_cd_e,median_events.event_yr,median_events.event_mo,median';
    
    execute immediate 'merge into '||output_table||' outp
        using (
            select ot.prac_cd_e,avg(median_events_per_cap) avg_good_year from '||output_table||' ot
                join session.good_years gy on 
                    gy.prac_cd_e = ot.prac_cd_e and
                    event_yr = good_year
                group by ot.prac_cd_e
        ) good
        on outp.prac_cd_e = good.prac_cd_e
        when matched then update set
            outp.relative_event_rate = median_events_per_cap/avg_good_year';
          
    call fnc.log_finish();
end!

