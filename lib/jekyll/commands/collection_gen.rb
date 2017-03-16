require 'date'
# require 'reverse_markdown'

module Jekyll
  module Commands
    class CollectionGen < Command
      class << self
        def init_with_program(prog)
          prog.command(:collection_gen) do |c|
            c.action do |args, options|
              Jekyll.logger.info "Generating blog posts..."

              site = Jekyll::Site.new(configuration_from_options(options))

              collection_name = 'posts'
              data_file = 'entries/posts/en-us.json'

              file_path = File.join(site.config['source'], site.config['data_dir'], data_file)

              if File.exist?(file_path)
                file = File.read(file_path)
                items = JSON.parse(file)
                directory = File.join(site.config['source'], "_#{collection_name}")

                Dir.mkdir(directory) unless File.exists?(directory)

                items.each_index do |item|
                  current = items[item]

                  # Overrides
                  current['layout'] = 'blog/blog-post'
                  # current['permalink'] = '/blog' + current['url']

                  # Strip slashes out of URL to create slug
                  filename_title = current['url'].gsub(/[\s\/]/, '')

                  # Create standard filename expected for posts
                  filename = Date.iso8601(current['date']).strftime + "-#{filename_title}"

                  # Pull out the content
                  content = current['full_description']
                  current.delete('full_description')

                  # Set a search type for indexing
                  current['search_type'] = 'blog_post'

                  # TODO: Build excerpt generator based on the first <hr> present in the blog post body

                  # Convert the HTML content to markdown
                  # content_md = ReverseMarkdown.convert(content).strip
                  # Create an excerpt
                  # excerpt, _, _after = content_md.partition('<!-- more -->')
                  # if excerpt.empty?
                  #   excerpt, _, _after = content_md.partition("\n\n")
                  # end
                  # current['excerpt'] = excerpt
                  # Partition to <hr>
                  # If no <hr>, grab the first X words with an ellipsis like we currently do
                  # Set as the "excerpt" front matter variable

                  current['excerpt'] = truncatewords(strip_html(content), 35)

                  as_yaml = current.to_yaml

                  File.write(File.join(directory, "#{filename}.md"), "#{as_yaml}---\n{% raw %}#{content}{% endraw %}")
                end

                # Loop
              else
                puts "File does not exist: #{file_path}"
              end
            end
          end
        end

        # From Liquid
        def strip_html(input)
          empty = ''.freeze
          input.to_s.gsub(/<script.*?<\/script>/m, empty).gsub(/<!--.*?-->/m, empty).gsub(/<style.*?<\/style>/m, empty).gsub(/<.*?>/m, empty)
        end

        # From Liquid
        def truncatewords(input, words = 15, truncate_string = "...".freeze)
          if input.nil? then
            return
          end
          wordlist = input.to_s.split
          l = words.to_i - 1
          l = 0 if l < 0
          wordlist.length > l ? wordlist[0..l].join(" ".freeze) + truncate_string : input
        end
      end
    end
  end
end