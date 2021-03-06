# Dependencies:
# phantomjs - `brew install phantomjs` (this assumes you have Homebrew)
# gems and Ruby 2.2.3 from Gemfile - `bundle install` (assuming you have the `bundler` gem)

# Login and visit the relevant pages
require 'capybara/poltergeist'
require 'date'
require 'pry'
require 'chronic'
require 'securerandom'
require 'zlib'

class Browser
  def self.new_session
    Capybara.register_driver :poltergeist do |app|
      Capybara::Poltergeist::Driver.new(app, js_errors: false)
    end

    # Configure Capybara to use Poltergeist as the driver
    Capybara.default_driver = :poltergeist

    if wait_time = ENV["PAGE_WAIT_TIME"]
      Capybara.default_max_wait_time = wait_time.to_f
    end

    Capybara.current_session
  end
end

class PageDiff
  attr_accessor :diff_text

  def length
    if diff_text.nil?
      -1
    else
      diff_text.length
    end
  end

  def hash
    if diff_text.nil?
      -1
    else
      Zlib.crc32(diff_text)
    end
  end
end

class VersionistaBrowser
  attr_reader :session, :cutoff_time

  def initialize(cutoff_hours)
    @session = Browser.new_session
    @cutoff_time = DateTime.now - (cutoff_hours.to_i / 24.0)
  end

  def log_in(email:, password:)
    puts "Logging in..."

    session.visit(log_in_url)
    session.fill_in("E-mail", with: email)
    session.fill_in("Password", with: password)
    session.click_button("Log in")

    puts "-- Logging in complete!"
  end

  def scrape_each_page_version
    website_rows = scrape_website_hrefs

    website_rows.map do |name, href, change_time|
      next if change_time < cutoff_time
      [name, scrape_archived_page_data(href)]
    end.compact
  end

  def headers
    [
      'Index',
      "UUID",
      "Output Date/Time",
      'Agency',
      "Site Name",
      'Page name',
      'URL',
      'Page View URL',
      "Last Two - Side by Side",
      "Latest to Base - Side by Side",
      "Date Found - Latest",
      "Date Found - Base",
      "Diff Length",
      "Diff Hash",
    ]
  end

  private

  def log_in_url
    "https://versionista.com/login"
  end

  def scrape_website_hrefs
    session.find(:xpath, "//a[contains(text(), 'Show all')]").click
    site_rows = session.all(:xpath, "//th[contains(text(), 'Sites')]/../../following-sibling::tbody/tr")

    site_rows.map do |row|
      link = row.find(:xpath, "./td[a]/a")
      change_time = parsed_website_change_time(row.find(:xpath, "./td[5]").text)

      [link.text, link[:href], change_time]
    end
  end

  def parsed_website_change_time(time_ago)
    DateTime.parse(Chronic.parse("#{time_ago} ago").to_s)
  end

  def recent_page_hrefs
    all_page_rows = session.all(:xpath, "//div[contains(text(), 'URL')]/../../../following-sibling::tbody/tr")
    recent_page_rows = all_page_rows.select { |row| happened_in_last_n_hours?(row) }
    recent_page_rows.map { |row| row.find(:xpath, "./td[a][2]/a")[:href] }
  end

  def happened_in_last_n_hours?(row)
    last_new_time_cell = row.all(:xpath, "./td[9]").first

    if last_new_time_cell.nil?
      false
    else
      est_adjustment = (5.0/24)
      begin
        DateTime.strptime(last_new_time_cell.text, "%b %d %Y %I:%M %p") + est_adjustment >= cutoff_time
      rescue ArgumentError #invalid date
        false
      end
    end
  end

  def scrape_archived_page_data(href)
    puts "Visiting #{href}"
    session.visit(href)
    puts "-- Successful visit!"

    site_name = session.all(:xpath, "//i[contains(text(), 'Custom:')]").first.text.sub("Custom: ", "")

    page_hrefs = []
    page_hrefs.concat(recent_page_hrefs)

    i = 2
    while((next_link = session.all(:xpath, "//li[not(@class='disabled')]/a[contains(text(), 'Next')]").first) && i <= 20)
      puts "Clicking Next to visit page #{i} of list of archived pages..."
      next_link.click
      i += 1
      puts "-- Successful visit!"

      page_hrefs.concat(recent_page_hrefs)
    end

    page_hrefs.map do |href|
      puts "Visiting #{href}"
      session.visit(href)
      puts "-- Successful visit!"

      page_name = session.all(:xpath, "//div[@class='panel-heading']//h3").first.text
      page_url = session.all(:xpath, "//div[@class='panel-heading']//h3/following-sibling::a[1]").first.text
      comparison_links = session.all(:xpath, "//*[@id='pageTableBody']/tr/td[a][1]/a")
      comparison_data = parse_comparison_data(comparison_links)
      latest_diff = comparison_diff(comparison_data[:latest_comparison_url])

      [
        href,
        data_row(
          page_view_url: href,
          site_name: site_name,
          page_name: page_name,
          page_url: page_url,
          latest_comparison_date: comparison_data[:latest_comparison_date],
          oldest_comparison_date: comparison_data[:oldest_comparison_date],
          latest_comparison_url: comparison_data[:latest_comparison_url],
          total_comparison_url: comparison_data[:total_comparison_url],
          latest_diff: latest_diff,
        )
      ]
    end
  end

  def parse_comparison_data(comparison_links)
    latest_link = comparison_links.first
    oldest_link = comparison_links.last
    return {} if latest_link.nil? || oldest_link.nil?

    {
      latest_comparison_date: latest_link.text,
      oldest_comparison_date: oldest_link.text,
      latest_comparison_url: generated_latest_comparison_url(latest_link),
      total_comparison_url: generated_total_comparison_url(latest_link, oldest_link),
    }
  end

  def generated_latest_comparison_url(latest_link)
    latest_link[:href].sub(/\/?$/, ":0/")
  end

  def generated_total_comparison_url(latest_link, oldest_link)
    oldest_version_id = oldest_link[:href].slice(/\d+\/?$/).sub('/', '')
    latest_link[:href].sub(/\/?$/, ":#{oldest_version_id}/")
  end

  def comparison_diff(url)
    page_diff = PageDiff.new

    begin
      puts "Visiting the comparison url: #{url}"
      session.visit(url)
      puts "-- Successful visit!"
      page_diff.diff_text = source_changes_only_diff
    rescue Capybara::ExpectationNotMet,
        Capybara::ElementNotFound,
        Capybara::Poltergeist::StatusFailError

      puts "__Error getting diff from: #{url}"
      puts "-" * 80
    end

    page_diff
  end

  def source_changes_only_diff
    session.within_frame(0) do
      unless session.find("#viewer_chooser").value == "only"
        session.select("source: changes only", from: "viewer_chooser")
      end
    end

    session.within_frame(1) do
      session.has_selector?("body s")
      session.find("body")[:innerHTML]
    end
  end

  def data_row(page_view_url:, site_name:, page_name:,
               page_url:, latest_comparison_url:, total_comparison_url:,
               latest_comparison_date:, oldest_comparison_date:, latest_diff:)
    
    headers.zip([
      nil,                         #'Index' - to be filled in later
      SecureRandom.uuid,           # UUID
      Time.now.to_s,               #"Output Date/Time"
      tokenized_agency(site_name), #'Agency'
      site_name,                   #"Site Name"
      page_name,                   #'Page name'
      page_url,                    #'URL'
      page_view_url,               #'Page View URL'
      latest_comparison_url,       #"Last Two - Side by Side"
      total_comparison_url,        #"Latest to Base - Side by Side"
      latest_comparison_date,      #"Date Found - Latest"
      oldest_comparison_date,      #"Date Found - Base"
      latest_diff.length,          # Diff length
      latest_diff.hash,            # Diff hash
    ]).to_h
  end

  def tokenized_agency(site_name)
    site_name.split("-").first.strip
  end
end

browser = VersionistaBrowser.new(ENV.fetch("N"))
row_index = ENV["INDEX"].to_i || 0

browser.log_in(email: ENV.fetch("EMAIL"), password: ENV.fetch("PASSWORD"))
websites_data = browser.scrape_each_page_version

puts "Writing the csv..."

# Write the CSV
require_relative 'csv_writer'

def filename(website_name)
  "#{website_name}_#{Time.now.strftime("%FT%T")}".gsub(":", "_").gsub("/", "_")
end

websites_data.each do |website_name, data|
  csv_writer = CSVWriter.new(filename_title: filename(website_name), headers: browser.headers)
  data.sort_by do |url, scraped_data_hash|
    [scraped_data_hash["Diff Length"], scraped_data_hash["Diff Hash"]]
  end.each do |url, scraped_data_hash|
    row_index += 1
    scraped_data_hash["Index"] = row_index
    csv_writer.add_rows(url: url, rows: [scraped_data_hash])
  end

  csv_writer.write!
end

puts "-- Successful write!"
