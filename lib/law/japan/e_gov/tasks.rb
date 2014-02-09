require "git"
require "logger"
require "mechanize"
require "cgi"

class Mechanize::Form
  def clear_buttons
    @clicked_buttons = []
  end
end

download_dir = "/tmp/law-japan-e_gov/download"
url_file = "url.txt"
repo_dir = File.expand_path("../../../../../", __FILE__)

task :save_html do
  g = Git.open(repo_dir, log: Logger.new(STDOUT))
  g.checkout "html"
  g.remove "html", recursive: true
  FileUtils.cp_r download_dir, "#{repo_dir}/html"
  g.add
  g.commit "Saved at #{Time.now}"
  g.checkout "master"
end

task :download do
  agent = Mechanize.new { |a| a.user_agent_alias = "Windows IE 9" }
  agent.log = Logger.new STDOUT
  agent.read_timeout = 3

  Dir.foreach(download_dir) do |category_dir|
    next if category_dir =~ /^[\.]+$/

    Dir.chdir("#{download_dir}/#{category_dir}") do
      category = File.basename(category_dir)
      url_list = File.read(url_file).split("\n")
      url_list.each do |url|
        file_name = File.basename(url)
        next if File.exists?(file_name)

        agent.download(url, file_name)
        sleep 2
      end
    end
  end
end

task :list_url do
  agent = Mechanize.new { |a| a.user_agent_alias = "Windows IE 9" }
  agent.log = Logger.new STDOUT
  index_page = agent.get("http://law.e-gov.go.jp/cgi-bin/idxsearch.cgi")

  category_form = index_page.forms_with(name: "index")[2]

  category_form.buttons.each do |button|
    category = button.node.next.text.gsub(/[ 　]+/, "")
    category_dir = "#{download_dir}/#{category}"
    FileUtils.mkdir_p(category_dir)
    Dir.chdir(category_dir) do
      category_form.clear_buttons
      list_page = agent.submit(category_form, button)
      File.open(url_file, "w") do |f|
        list_page.links.each do |link|
          uri = link.uri
          h_file_name = CGI.parse(uri.query)["H_FILE_NAME"].first
          if h_file_name =~ /^([MTSH]\d{2})/
            law_url = "http://law.e-gov.go.jp/htmldata/#{$1}/#{h_file_name}.html"
            f.puts law_url
          else
            warn "Invalid H_FILE_NAME #{h_file_name} for #{link.text}"
          end
        end
      end
    end
    sleep 2
  end
end
