require 'csv'

class CSVWriter

  attr_reader :headers, :pseudo_csv

  def initialize(filename_title:, headers:)
    @filename_title = filename_title
    @headers = headers
    @pseudo_csv = [headers]
  end

  def add_rows(url:, rows:)
    rows.each do |row|
      values = row.values_at(*headers)
      pseudo_csv << values
    end
  end

  def write!
    csv_text = pseudo_csv.map { |row| CSV.generate_line(row) }.join
    File.write(filepath, csv_text)
  end

  def copy_pseudo_csv(other_pseudo_csv)
    @pseudo_csv = other_pseudo_csv.clone
  end

  private

  def filepath
    "./output/#{@filename_title}.csv"
  end
end
