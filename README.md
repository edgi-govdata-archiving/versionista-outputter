![Healthify logo](https://raw.githubusercontent.com/healthify/healthify/master/app/assets/images/healthify_logotype.jpg?token=AEXE6o0_Ei_2n_f2US_nmZD84ozmHXKSks5W_uDmwA%3D%3D)

Healthify pulls a large amount of data from publicly available repositories. This is a repository for maintaining all of those webscrapers.

##Getting Started:
Most of our repo is based upon the techniques described in [this Ruby Webscraping tutorial](http://ruby.bastardsbook.com/chapters/web-scraping/) from Ruby Bastards.

1. Install [nokogiri](https://github.com/sparklemotion/nokogiri)

2. Make sure you have gdbm installed (details below in Dependencies)


## Writing a new scraper
1. Identify the BASE_URL of the site you're scraping. E.g. 'http://www.211centralohio.org'

2. Execute `rake new URL=<YOUR BASE URL>`. This will create a new adapter appropriately named from your BASE_URL.

3. If your scraper requires any extra fixtures, create a subdirectory for those files in the fixtures/ directory, giving your new subdirectory the the same name as the adapter filename (minus the `.rb` extension).

4. Make any necessary customizations to that generated scraper. These will probably include customizing the fields and field_xpaths of your scraper, and possibly including
specifying whether there is a specified number of pages `num_pages` that the HelperScraper needs to scrape.

5. Begin the scrape by running `ruby <adapter_name>.rb`.

Once the scrape has finished (this may take a few hours), commence cleanup:

1. Save the scraped csv file somewhere else (e.g. Trello) so you can use it as needed.

2. Delete the scraped csv from this repo.

3. Delete all contents of the `gdbm_databases` directory.

4. Commit your changes in a new branch and push to the remote. Make a new pull request on the webscraping repo.

### Writing a Referweb scraper
It may be useful to get a sense of the general strategy of how we scrape Referweb sites. See 'Notes on the general strategy for scraping Referweb sites' below for that.

Perform the same steps as in 'Writing a new scraper' except instead of performing the above steps 2,3 do the following:

2. Execute `rake new_referweb URL=<YOUR BASE URL>`. This will create a new referweb-templated adapter appropriately named from your BASE URL as well as an empty categories_page.html fixture.

3. Fill your categories_page.html. Go to the website that you want to scrape. This should be the base page with all the category links that lead to pages with resource sites. Make sure that all category links are visible on the page (i.e. all category links for A through Z should be displayed) and that the URL is not location specific. Now save the page as categories_page.html in the directory you just created within the fixtures directory.

Note: In many cases, you will not have to perform *any further customizations to the adapter*. You can just run it as is. Magical, I know :)

## Dependencies

We use GDBM binary database store to make it possible to modularize the process of webscraping by splitting the step of accessing info from remote servers from the step of parsing through that info to identify the relevant fields (read more about using GDBM [here](http://ngauthier.com/2014/06/scraping-the-web-with-ruby.html)).

In order to use 'gdbm', we must not only include the `gdbm` gem in our Gemfile, but we must also execute:
`brew install gdbm`

Further, an odd idiosyncracy of the `gdbm` gem is that it has an unmanaged dependency on the 'ffi' gem.

## Notes on the general strategy for scraping Referweb sites
 (1) Scrape service index page to get links to result pages
 (2) Scrape each result page to get agency show page urls
 (3) Scrape each agency show pages. This will also scrape related program show page urls.
 (4) Scrape the program show pages.
 (5) Combine the scraped agency data and program data into a single csv
