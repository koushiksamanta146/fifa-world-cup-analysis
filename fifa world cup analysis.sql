-- FIFA WORLD CUP 2026 ANALYSIS

create database fifa_wc;
use fifa_wc;

create table fifa
( match_date date, match_id int, stage varchar(50), `group` varchar(50), team varchar(100), opponent varchar(100), venue varchar(100),
team_order int, goals_for int, goals_against int, result varchar(50), points int, clean_sheet int, goal_difference int, 
penalty_goals_for varchar(50), penalty_goals_against varchar(50), extra_time varchar(50), source_url varchar(500), retrieved_at datetime);
set sql_safe_updates = 0;
update fifa
SET match_date = STR_TO_DATE(match_date, '%d-%m-%y');

/* load data local infile 'C:\\DATA ANALYST\\SQL\\project\\fifa world cup 2026\\fifa_wc.csv'
into table fifa fields terminated by ','
enclosed by '"' lines terminated by '\r\n' IGNORE 1 ROWS; */

select * from fifa;

-- Tournament & Goal Performance

/* 1. Goal Distribution & Efficiency: What is the total number of goals scored across the tournament, 
and what is the average number of goals per match broken down by stage (Group Stage vs. Knockout Stage)?*/
with match_summary as (select match_id,
case
when stage = 'Group Stage' then 'Group Stage'
else 'Knockout Stage'
end as Stage_category,
sum(goals_for) as Match_goals
from fifa group by match_id, stage_category)

select stage_category, count(match_id) as total_matches,
sum(match_goals) as total_goals,
round(avg(match_goals), 2) as avg_goals_per_match
from match_summary
group by stage_category

union all

select 'Overall Tournament' as stage_category,
count(match_id) as total_matches,
sum(match_goals) as total_goals,
round(avg(match_goals), 2) as avg_goals_per_match
from match_summary;

/* 2. Top Scoring Teams: Which 5 teams scored the highest cumulative number of goals throughout the tournament,
and what was their average goal difference per match?*/
with team_stats as (select team,
count(distinct match_id) as matches_played,
sum(goals_for) as total_goals_scored,
sum(goals_against) as total_goals_conceded,
sum(goal_difference) as total_goal_differenece,
round(avg(goals_for), 2) as avg_goals_per_match,
round(avg(goal_difference), 2) as avg_goal_differenece_per_match
from fifa
group by team),

ranked_team as (select *,
dense_rank() over (order by total_goals_scored desc, total_goal_differenece desc) as goal_rank
from team_stats)

select goal_rank, team, matches_played, total_goals_scored, total_goals_conceded,
total_goal_differenece, avg_goals_per_match, avg_goal_differenece_per_match
from ranked_team
where goal_rank <= 5;

-- 3.Clean Sheet Leaders: Which teams maintained the highest clean sheet percentage across all matches played?
with team_clean_sheets as (select team,
count(distinct match_id) as matches_played,
sum(clean_sheet) as Total_clean_sheets,
sum(goals_against) as total_goals_conceded
from fifa
group by team),

clean_sheet_calc as (select *, 
ROUND((Total_clean_sheets * 100 / matches_played), 2) as clean_sheet_percentage
from team_clean_sheets),

rank_teams as (select *,
dense_rank() over (order by clean_sheet_percentage desc, total_clean_sheets desc) as cs_rank
from clean_sheet_calc)

select cs_rank, team, matches_played, Total_clean_sheets, total_goals_conceded, clean_sheet_percentage
from rank_teams
where cs_rank <= 5;

-- Defensive & Home/Away Advantage Analysis
/* 4. Venue Breakdown: Which venue hosted the highest-scoring matches, 
and which stadium recorded the most draws or extra-time finishes?*/


WITH match_level_venue AS (SELECT venue, match_id,
        SUM(goals_for) AS match_total_goals,
        MAX(CASE WHEN LOWER(result) = 'draw' THEN 1 ELSE 0 END) AS is_draw,
        MAX(CASE WHEN LOWER(extra_time) = 'yes' THEN 1 ELSE 0 END) AS is_extra_time
    FROM fifa
    GROUP BY venue, match_id
),
venue_summary AS (SELECT venue,
        COUNT(match_id) AS total_matches,
        SUM(match_total_goals) AS total_goals,
        ROUND(AVG(match_total_goals), 2) AS avg_goals_per_match,
        SUM(is_draw) AS total_draws,
        SUM(is_extra_time) AS total_extra_time,
        (SUM(is_draw) + SUM(is_extra_time)) AS total_tight_finishes
    FROM match_level_venue
    GROUP BY venue
),
ranked_venue AS (
    SELECT *,
        DENSE_RANK() OVER (ORDER BY total_goals DESC) AS rank_highest_scoring,
        DENSE_RANK() OVER (ORDER BY total_tight_finishes DESC) AS rank_most_draws_extratime
    FROM venue_summary
)
SELECT 
    venue, 
    total_matches, 
    total_goals, 
    avg_goals_per_match, 
    total_draws, 
    total_extra_time, 
    total_tight_finishes, 
    rank_highest_scoring, 
    rank_most_draws_extratime
FROM ranked_venue
ORDER BY total_goals DESC;

/*5. Team Order Impact: Does playing as team_order = 1 vs. team_order = 2 show a statistically 
significant difference in win rates or points earned?*/

SELECT 
    team_order,
    COUNT(match_id) AS total_matches,
    ROUND(SUM(CASE WHEN LOWER(result) = 'win' THEN 1 ELSE 0 END) * 100.0 / COUNT(match_id), 2) AS win_percentage,
    ROUND(SUM(CASE WHEN LOWER(result) = 'draw' THEN 1 ELSE 0 END) * 100.0 / COUNT(match_id), 2) AS draw_percentage,
    ROUND(SUM(CASE WHEN LOWER(result) = 'loss' THEN 1 ELSE 0 END) * 100.0 / COUNT(match_id), 2) AS loss_percentage,
    ROUND(AVG(points), 2) AS avg_points_per_match
FROM fifa
WHERE team_order IN (1, 2)
GROUP BY team_order;

-- Knockout & Match Intensity Dynamics
/* 6.Extra Time & Penalty Shootout Frequency: What percentage of knockout stage matches went into extra time, 
and what proportion of those were decided by penalty shootouts?*/

WITH knockout_matches AS (
    SELECT 
        COUNT(DISTINCT match_id) AS total_knockout_matches,
        COUNT(DISTINCT CASE 
            WHEN LOWER(extra_time) = 'yes' THEN match_id 
        END) AS matches_with_extra_time,
        COUNT(DISTINCT CASE 
            WHEN LOWER(extra_time) = 'yes' 
             AND penalty_goals_for IS NOT NULL 
             AND penalty_goals_for != 'NA' 
             AND (CAST(penalty_goals_for AS UNSIGNED) > 0 OR CAST(penalty_goals_against AS UNSIGNED) > 0)
            THEN match_id 
        END) AS matches_with_penalties
    FROM fifa
    WHERE LOWER(stage) NOT LIKE '%group%'
)
SELECT 
    total_knockout_matches,
    matches_with_extra_time,
    matches_with_penalties,
    ROUND((matches_with_extra_time * 100.0 / total_knockout_matches), 2) AS extra_time_percentage,
    ROUND((matches_with_penalties * 100.0 / NULLIF(matches_with_extra_time, 0)), 2) AS penalty_shootout_proportion_of_et
FROM knockout_matches;

/* 7.Penalty Clutch Performance: Among matches that reached a penalty shootout, what was the average 
conversion rate or margin of victory in shootout goals?*/

WITH shootout_matches AS (
    SELECT 
        match_id,
        SUM(CAST(penalty_goals_for AS UNSIGNED)) AS total_shootout_goals,
        MAX(CAST(penalty_goals_for AS UNSIGNED)) - MIN(CAST(penalty_goals_for AS UNSIGNED)) AS shootout_margin_of_victory
    FROM fifa
    WHERE (LOWER(extra_time) = 'yes' OR LOWER(stage) NOT LIKE '%group%')
      AND penalty_goals_for IS NOT NULL 
      AND penalty_goals_for != 'NA'
    GROUP BY match_id
    HAVING SUM(CAST(penalty_goals_for AS UNSIGNED)) > 0
)
SELECT 
    COUNT(match_id) AS total_penalty_shootout_matches,
    ROUND(AVG(total_shootout_goals), 2) AS avg_total_shootout_goals,
    ROUND(AVG(total_shootout_goals) / 2.0, 2) AS avg_goals_per_team,
    ROUND(AVG(shootout_margin_of_victory), 2) AS avg_shootout_margin_of_victory,
    MAX(shootout_margin_of_victory) AS max_shootout_margin,
    MIN(shootout_margin_of_victory) AS min_shootout_margin
FROM shootout_matches;

-- Group Stage Progression Analysis
/* 8.Group Competitiveness: Which group had the tightest goal difference spread among its 4 teams,
 and which group generated the highest cumulative goals?*/
WITH team_group_stats AS (
    SELECT 
        `group`,
        team,
        SUM(goals_for) AS total_goals_scored,
        SUM(goal_difference) AS team_gd
    FROM fifa
    WHERE LOWER(stage) LIKE '%group%'
    GROUP BY `group`, team
),
group_summary AS (
    SELECT 
        `group`,
        (MAX(team_gd) - MIN(team_gd)) AS gd_spread,
        SUM(total_goals_scored) AS cumulative_goals
    FROM team_group_stats
    GROUP BY `group`
)
SELECT 
    `group`,
    gd_spread,
    cumulative_goals
FROM group_summary
ORDER BY gd_spread ASC, cumulative_goals DESC;
