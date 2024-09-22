CREATE TABLE IPL_Ball (
    match_id INT,
    inning INT,
	overs INT,
	ball int,
	batsman VARCHAR(100),
    non_striker VARCHAR(100),
    bowler VARCHAR(100),
	batsman_runs int,
	extra_runs int,
    total_runs int,
	is_wicket int,
	dismissal_kind VARCHAR(100),
	player_dismissed VARCHAR(100),
    fielder VARCHAR(100),
	extra_type VARCHAR(50),
	batting_team VARCHAR(100),
    bowling_team VARCHAR(100) 
);


CREATE TABLE IPL_matches (
    match_id INT PRIMARY KEY,
    city VARCHAR(100),
    date DATE,
	player_of_match VARCHAR(100),
	venue VARCHAR(100),
	neutral_venue int,
    team1 VARCHAR(100),
    team2 VARCHAR(100),
    toss_winner VARCHAR(100),
    toss_decision VARCHAR(50),
	winner VARCHAR(100),
    results VARCHAR(50),
    result_margin INT,
	eliminator varchar(50),
	methods varchar(50),
	umpire1 VARCHAR(100),
    umpire2 VARCHAR(100)   
);

Select batsman, sum(batsman_runs) as runs_scored,
Count(batsman_runs) as balls_faced,
Sum(batsman_runs*100)*1.0/count(batsman_runs) as batting_strike_rate
From ipl_ball where not extra_type = 'wides' group by batsman
Having count(batsman_runs)>500 order by batting_strike_rate desc limit 10;

create table batting_strike_rate as select batsman, sum (batsman_runs) as runs_scored, 
count (batsman_runs) as balls_faced, 
sum (batsman_runs*100) *1.0/count (batsman_runs) 
as batting_strike_rate from ipl_ball where not extra_type ='wides' group by batsman ;

SELECT*FROM batting_strike_rate;

Select batsman,sum(batsman_runs) as runs_scored,
Count(distinct match_id) as innings_batted,
Sum(is_wicket) as Number_of_times_dismissed, 
sum (batsman_runs)*1.0/sum(is_wicket) as batting_average
From ipl_ball group by batsman having count(distinct match_id)> 28 
	order by batting_average desc limit 10;


Create table Boundries as select batsman,sum (batsman_runs) 
	as runs_scored,count(distinct match_id) as innings_batted,
Count(case when batsman_runs =4 or batsman_runs = 6
Then 1 else null end) as runs_scored_boundries 
From ipl_ball group by batsman ;


Select *,(runs_scored_boundries*1./runs_scored)*100 
as percentage_of_boundries from Boundries where innings_batted > 28 
order by percentage_of_boundries desc limit 10 ;

SELECT 
batsman, 
ROUND(SUM(CASE WHEN batsman_runs in(4,6) 
	THEN batsman_runs else 0 END)*1.0 / SUM(batsman_runs)*100,2) AS boundary_percentage
FROM ipl_ball
WHERE
extra_type NOT IN ('wides')
GROUP BY
batsman
HAVING
COUNT(DISTINCT match_id) > 28
ORDER BY
boundary_percentage DESC
LIMIT 10;


create table B_strike_rate as select bowler,
sum(total_runs) as runs_got from ipl_ball
where not extra_type = 'legbyes' and not extra_type = 'penalty'
group by bowler order by runs_got desc;


Create table balls as select bowler, count(ball) 
as balls_bowled from ipl_ball where not extra_type ='wides' and not extra_type ='noballs' 
and not extra_type='penalty' group by bowler ;


create table Bowling_economy 
as select a.bowler, 
	a.runs_got, 
	b.balls_bowled
from B_strike_rate as a left join balls 
	as b on a.bowler=b.bowler order by bowler;

select*from Bowling_economy;


Select bowler,balls_bowled,runs_got,
balls_bowled/6 as over, (runs_got*6)*1.0/(balls_bowled) 
	as economy from bowling_economy where balls_bowled > 500 
	order by economy asc limit 10 ;


Create table bowling_strikerate as select bowler, count(ball) 
as balls_bowled,count(case when dismissal_kind='caught' or 
dismissal_kind='bowled' or dismissal_kind='caught and bowled' 
or dismissal_kind='Ibw' or dismissal_kind='hit wicket' or dismissal_kind='stumped' 
then 1 else null end) as total_wickets from ipl_ball
where not extra_type='wides'and not extra_type ='noballs' and not extra_type='penalty' 
	group by bowler;

select *, balls_bowled*1.0/nullif(total_wickets,0)
as bowling_strike_rate from bowling_strikerate where balls_bowled > 500 
	order by bowling_strike_rate asc limit 10;


create table allrounder as select 
a.batsman,
a.runs_scored, 
a.balls_faced, 
a.batting_strike_rate, 
b.balls_bowled, 
b.total_wickets
from batting_strike_rate as a 
left join bowling_strikerate as b 
	on a.batsman=b.bowler order by batsman;

alter table allrounder rename column batsman to player;

select *,balls_bowled*1./nullif(total_wickets,0)as bowling_strike_rate from allrounder 
where balls_faced > 500 and balls_bowled > 300
order by batting_strike_rate desc limit 10;

SELECT COUNT(DISTINCT city) AS city_count
FROM ipl_matches
WHERE city IS NOT NULL;


CREATE TABLE deliveries_v02 AS
SELECT *,
       CASE
           WHEN total_runs >= 4 THEN 'boundary'
           WHEN total_runs = 0 THEN 'dot'
           ELSE 'other'
       END AS ball_result
FROM ipl_ball;

SELECT*FROM deliveries_v02;

SELECT 
    SUM(CASE WHEN ball_result = 'boundary' THEN 1 ELSE 0 END) AS total_boundaries,
    SUM(CASE WHEN ball_result = 'dot' THEN 1 ELSE 0 END) AS total_dot_balls
FROM deliveries_v02;

SELECT 
    batting_team,
    COUNT(*) AS total_boundaries
FROM deliveries_v02
WHERE ball_result = 'boundary'
GROUP BY batting_team
ORDER BY total_boundaries DESC;

SELECT 
    bowling_team,
    COUNT(*) AS total_dot_balls
FROM deliveries_v02
WHERE ball_result = 'dot'
GROUP BY bowling_team
ORDER BY total_dot_balls DESC;

SELECT 
    dismissal_kind,
    COUNT(*) AS total_dismissals
FROM IPL_BALL
WHERE dismissal_kind IS NOT NULL AND dismissal_kind != 'NA'
GROUP BY dismissal_kind
ORDER BY total_dismissals DESC;

SELECT 
    bowler,
    SUM(extra_runs) AS total_extra_runs
FROM IPL_BALL
GROUP BY bowler
ORDER BY total_extra_runs DESC
LIMIT 5;

CREATE TABLE deliveries_v03 AS
SELECT 
    d.*,
    m.venue,
    m.date AS match_date
FROM deliveries_v02 d
JOIN IPL_matches m ON d.match_id = m.match_id;

SELECT*FROM deliveries_v03;

SELECT 
    venue,
    SUM(total_runs) AS total_runs
FROM deliveries_v03
GROUP BY venue
ORDER BY total_runs DESC;

SELECT 
    EXTRACT(YEAR FROM match_date) AS year,
    SUM(total_runs) AS total_runs
FROM deliveries_v03
WHERE venue = 'Eden Gardens'
GROUP BY year
ORDER BY total_runs DESC;

