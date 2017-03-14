require 'date'
require 'reverse_markdown'

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
                  # content = current['full_description']
                  # current.delete('full_description')

                  # Convert the HTML content to markdown
                  # content_md = ReverseMarkdown.convert(content).strip

                  # Create an excerpt
                  # excerpt, _, _after = content_md.partition('<!-- more -->')
                  # if excerpt.empty?
                  #   excerpt, _, _after = content_md.partition("\n\n")
                  # end
                  # current['excerpt'] = excerpt

                  as_yaml = current.to_yaml

                  File.write(File.join(directory, "#{filename}.md"), "#{as_yaml}---") # "\n#{content}"
                end

                # Loop
              else
                puts "File does not exist: #{file_path}"
              end
            end
          end
        end
      end
    end
  end
end