// please make sure that the 2 .csv source files and the STATA .do 
// file are in the same folder on your computer for the code to run properly
////////////////////////////////////////////////////////////////////////
// 1. Cleaning imdb.csv (master file)
clear
cd "C:\Users\Raouf\Desktop\S040\Final"

import delimited imdb.csv

// keeping only type == movies (not episodes or tv series)
drop if type != "video.movie"

// dropping unrequired columns
drop url type fn tid title

// drop missing values
drop v45 v46 v47 v48

foreach v of var * {
drop if missing(`v')
}

// renaming title column
rename wordsintitle new_title

// capitalizing each word of movie titles to ease integration with second file
replace new_title = proper(new_title)

// saving as .dta
save imdb.dta, replace

////////////////////////////////////////////////////////////////////////
// 2. Cleaning popculture-imdb-5000-movie-dataset.csv (second file)
clear

cd "C:\Users\Raouf\Desktop\S040\Final"

import delimited popculture-imdb-5000-movie-dataset.csv

// keeping only required variables
keep num_critic_for_reviews gross movie_title num_voted_users facenumber_in_poster country budget

// drop missing values
foreach v of var * { 
	drop if missing(`v') 
}

// removing text error in "movie_title" names
replace movie_title = substr(movie_title,1,length(movie_title)-4)

// capitalizing each word of movie titles to ease integration with master file
replace movie_title = proper(movie_title)
rename movie_title new_title

// saving as .dta
save popculture-imdb-5000-movie-dataset.dta, replace

////////////////////////////////////////////////////////////////////////
// 3. combining both files by "new_title"
clear

cd "C:\Users\Raouf\Desktop\S040\Final"

local myfilelist : dir . files "*.dta"
use imdb

merge m:m new_title using popculture-imdb-5000-movie-dataset.dta
drop _merge
save imdb_combine, replace

////////////////////////////////////////////////////////////////////////
// 4. Using the combined file to conduct analysis
clear

cd "C:\Users\Raouf\Desktop\S040\Final"

use imdb_combine.dta

// removing all NA values
foreach v of var * { 
	drop if missing(`v') 
}

// dropping moives outside of the USA because some figures were reported in non USD currencies
drop if country != "USA"
drop country

// converting string variables to numeric
destring imdbrating nrofwins nrofnominations nrofphotos nrofnewsarticles nrofuserreviews nrofgenre duration ratingcount, replace

// dropping redundant variable between two datasets
drop num_voted_users

// renaming long variable names for convenience
rename nrofwins wins
rename nrofnominations nominations
rename nrofphotos photos
rename nrofnewsarticles news_articles
rename nrofuserreviews reviews
rename nrofgenre genres
rename num_critic_for_reviews critic
rename facenumber_in_poster faces

// adding labels
label variable duration "run time in minutes"
label variable critic "number of critic reviews"
label variable faces "number of faces on official movie poster"
label variable year "year movie released"

// converting year from string to numeric then dropping year<2005
destring year, replace
drop if year <2005

// exploring all variables by regressing everything
regress imdbrating ratingcount duration wins nominations photos news_articles reviews genre action adult adventure animation biography comedy crime documentary drama family fantasy filmnoir gameshow history horror music musical mystery news realitytv romance scifi short sport talkshow thriller war western critic gross faces budget

// dropping vairables identified as collinear by Stata
drop adult filmnoir gameshow news realitytv talkshow

// exploring gross and budget
summ budget gross, detail
twoway (scatter gross budget,yline(0))

// generating a profit variable
generate profit = gross - budget
label variable profit "gross - budget"

// log transforming for better representation
generate l2gross = log(gross)/log(2)
generate l2budget = log(budget)/log(2)
generate l2reviews = log(reviews)/log(2)
generate l2wins = log(wins)/log(2)
label variable l2wins "log transformed number of awards won"
generate l2news = log(news_articles)/log(2)
label variable l2news "log transformed number of news articles written about title"

// generating a composite of action or adventure
generate act_adv = 0
replace act_adv = 1 if action==1 | adventure==1
label variable act_adv "binary variable for either action or adventure (0= not action nor adventure, 1= is action or adventure or both)"
browse action adventure act_adv

// examining the plot of L2gross L2budget
twoway (scatter l2gross l2budget,yline(0))(lfit l2gross l2budget)

// R.1 for low(25%) 1 and high (75%)4 l2wins
regress l2gross l2news l2budget l2wins act_adv
twoway (scatter l2gross l2news)(function y = _b[_cons] + _b[l2news]*x + _b[l2budget]*24.2 + _b[l2wins]*1 + _b[act_adv]*1, range(l2news))(function y = _b[_cons] + _b[l2news]*x + _b[l2budget]*24.2 + _b[l2wins]*3.81 + _b[act_adv]*1, range(l2news)), legend(order(2 "Low wins" 3 "high wins"))ytitle("l2gross")xtitle("l2news")

// R.2 including critic (25% and 75%iles)
regress l2gross l2news l2budget l2wins critic act_adv
twoway (scatter l2gross l2news)(function y = _b[_cons] + _b[l2news]*x + _b[l2budget]*24.2 + _b[l2wins]*2.4 + _b[critic]*100 + _b[act_adv]*1, range(l2news))(function y = _b[_cons] + _b[l2news]*x + _b[l2budget]*24.2 + _b[l2wins]*2.4 + _b[critic]*267 + _b[act_adv]*1, range(l2news)), legend(order(2 "Low wins" 3 "high wins"))ytitle("l2gross")xtitle("l2news")

// R.3 introducing and experimenting with l2rxc
generate rxc = imdbrating * ratingcount
label variable rxc "ratingcount x imdbrating"
generate l2rxc = log(rxc)/log(2)
label variable l2rxc "log2 of ratingcount x imdbrating"

regress l2gross l2news l2budget l2rxc act_adv
twoway (scatter l2gross l2news)(function y = _b[_cons] + _b[l2news]*x + _b[l2budget]*24.2 + _b[l2rxc]*17.08 + _b[act_adv]*1, range(l2news))(function y = _b[_cons] + _b[l2news]*x + _b[l2budget]*24.2 + _b[l2rxc]*17.08 + _b[act_adv]*1, range(l2news)), legend(order(2 "Low l2rxc" 3 "high l2rxc"))ytitle("l2gross")xtitle("l2news")

// R.4 including and varying critic (25% and 75%iles) instead of l2rxc
regress l2gross l2news l2budget l2rxc critic act_adv
twoway (scatter l2gross l2news)(function y = _b[_cons] + _b[l2news]*x + _b[l2budget]*24.2 + _b[l2rxc]*18.21 + _b[critic]*100 + _b[act_adv]*1, range(l2news))(function y = _b[_cons] + _b[l2news]*x + _b[l2budget]*24.2 + _b[l2rxc]*18.21 + _b[critic]*267 + _b[act_adv]*1, range(l2news)), legend(order(2 "Low critic" 3 "high critic"))ytitle("l2gross")xtitle("l2news")

// R.5 introducing controversial
//generate controversy = critic * news
//label variable controversy "interaction between news and critic used to proxy for how controversial a movie is"
//generate l2cnvs = log(controversy)/log(2)
//label variable l2cnvs = log2 "transformation of controversy"

sum gross if action ==1
sum gross if adventure ==1

// Exploring correlations
pwcorr l2gross duration photos genres action adventure animation biography comedy crime documentary drama family fantasy history horror music musical mystery romance scifi short sport thriller war western critic faces l2budget l2reviews l2wins l2news rxc

// correlation matrix
pwcorr l2news l2budget l2wins critic act_adv, star(0.05) sig

// Correlation matrix graph
graph matrix l2gross l2news l2budget l2wins act_adv

// producing taxonomy table
eststo: regress l2gross l2news l2budget l2wins act_adv
est sto M1
eststo: regress l2gross l2news l2budget act_adv
est sto M2
eststo: regress l2gross l2news
est sto M3
eststo: regress gross news
est sto M4
esttab M1 M2 M3 M4 using "taxonomy_table2.rtf", replace cells(b(star fmt(2)) se(par fmt(2)) t(fmt(2))) scalars(r2 F df_m df_r rmse p) legend

// residuals and assumptions testing on final model predictors and yhat
regress l2gross l2news l2budget l2wins act_adv
predict yhatl2gross, xb 
predict stdres, rstandard
twoway (scatter stdres l2news, yline(0))(lowess stdres l2news)
twoway (scatter stdres l2budget, yline(0))(lowess stdres l2budget)
twoway (scatter stdres l2wins, yline(0))(lowess stdres l2wins)
twoway (scatter stdres act_adv, yline(0))(lowess stdres act_adv)
twoway (scatter stdres yhatl2gross, yline(0))(lowess stdres yhatl2gross)
hist stdres

// examining act_adv
bysort act_adv: summarize stdres
hist stdres, by(act_adv) bin(100)

// Including prototypical lines for act_adv low budget (10th pctl) and high budget (90th pctl) movies
regress l2gross l2news l2budget l2wins act_adv
twoway (scatter l2gross l2news)(lfit l2gross l2news)(function y = _b[_cons] + _b[l2news]*x + _b[l2budget]*21.25 + _b[l2wins]*2 + _b[act_adv]*1, range(l2news))(function y = _b[_cons] + _b[l2news]*x + _b[l2budget]*26.90 + _b[l2wins]*2 + _b[act_adv]*1, range(l2news)), legend(order(2 "Regression Fitted Line" 3 "Low Budget" 4 "High Budget"))ytitle("l2gross")xtitle("l2news")
