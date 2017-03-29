# Dependencies

- Ruby 2.2.3 (check out rbenv for a ruby version manager)
- phantomjs (assuming you have Hombrew, `brew install phantomjs`)
- bundler (`gem install bundler`)

# Getting started
1. Make sure you have up-to-date gems: `bundle`
2. Execute the script by running:
  `EMAIL=<your versionista email> PASSWORD=<your password> N=<number of hours back> INDEX=<starting index of csv> ruby capybara_script.rb`
3. If the script completes successfully, you will have new csvs written in the `output/` directory.

# Extra
1. Sometimes the current page the script is scraping does not contain the expected
html it is seeking. In these cases, Capybara will wait a set amount of time
to see whether the content appears before giving up and throwing an error (
that we gracefully rescue for diff pages). The default time is 2 seconds.
This number of seconds can me modified by passing the ENV variable "PAGE_WAIT_TIME"
when executing the script. For example: `PAGE_WAIT_TIME='1.5'` or `PAGE_WAIT_TIME=10`
Beware that with too little a wait time, pages of the script besides the comparison
pages may start failing.

2. The script now scrapes both the source code diff and the text diff. This extra
step makes the script slower than before. To skip the scraping of the text diff,
add the optional ENV variable "SKIP_TEXT_DIFF", setting to any value (e.g. `SKIP_TEXT_DIFF=true`
or `SKIP_TEXT_DIFF=1`).
