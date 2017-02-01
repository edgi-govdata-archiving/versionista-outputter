# Dependencies

- Ruby 2.2.3 (check out rbenv for a ruby version manager)
- phantomjs (assuming you have Hombrew, `brew install phantomjs`)
- bundler (`gem install bundler`)

# Getting started
1. Make sure you have up-to-date gems: `bundle`
2. Execute the script by running:
  `EMAIL=<your versionista email> PASSWORD=<your password> N=<number of hours back> INDEX=<starting index of csv> ruby capybara_script.rb`
3. If the script completes successfully, you will have new csvs written in the `output/` directory.
