require 'date'
require 'fileutils'
require 'pry'
require 'yaml'

module Jekyll
  module Commands
    class BlogGen < Command
      class << self
        def init_with_program(prog)
          prog.command(:blog_gen) do |c|
            c.action do |args, options|
              @site = Jekyll::Site.new(configuration_from_options(options))
              @posts = []

              # Must be first
              generate_blog_posts

              generate_blog_home
            end
          end
        end

        def get_content_json(content_type)
          if content_type === 'assets'
            file_path = File.join(@site.config['source'], @site.config['data_dir'], 'assets/assets.json')
          else
            file_path = File.join(@site.config['source'], @site.config['data_dir'], "entries/#{content_type}/en-us.json")
          end

          if File.exist?(file_path)
            file_data = File.read(file_path)

            if file_data
              json_data = JSON.parse(file_data)

              if json_data
                return json_data
              end
            end
          end

          false
        end

        def generate_blog_home
          Jekyll.logger.info 'Generating blog home...'
          blog_home = get_content_json('blog_home').first

          if blog_home
            if blog_home['featured_post']
              featured_post = @posts.find { |post| post['uid'] === blog_home['featured_post'][0] }
            end

            front_matter = {
                'layout' => 'blog-listing',
                'permalink' => blog_home['url'],
                'title' => blog_home['seo']['meta_title'],
                'pagination' => {'enabled' => true},
                'seo' => {'meta_description' => blog_home['seo']['meta_description']},
                'featured_post' => featured_post
            }

            directory = File.join(@site.config['source'], '_pages/blog')
            FileUtils.mkdir_p(directory) unless File.exists?(directory)

            # Output the front matter and the raw post content into a Markdown file
            File.write(File.join(directory, 'index.md'), "#{front_matter.to_yaml}---\n")
          end

          false
        end

        def generate_blog_posts
          Jekyll.logger.info 'Generating blog posts...'

          # Fetch the posts, categories, authors, assets
          categories = get_content_json('categories')
          posts = get_content_json('posts')
          authors = get_content_json('authors')
          assets = get_content_json('assets')

          # Make '_posts' collection directory
          directory = File.join(@site.config['source'], '_posts')
          Dir.mkdir(directory) unless File.exists?(directory)

          posts.each do |post|
            # Overrides
            post['layout'] = 'blog/blog-post'
            # post['permalink'] = '/blog' + post['url']

            # Strip slashes out of URL to create slug
            filename_title = post['url'].gsub(/[\s\/]/, '')

            # Create standard filename expected for posts
            filename = Date.iso8601(post['date']).strftime + "-#{filename_title}"

            # Pull out the content
            content = post['full_description']
            post.delete('full_description')

            # Convert featured image UID to local file path
            if post.has_key?('featured_image')
              assetData = assets.find { |asset| asset['uid'] == post['featured_image'] }

              if assetData
                post['featured_image'] = "assets/images/#{post['featured_image']}/#{assetData['filename']}"
              end
            end

            # Set a search type for indexing
            post['search_type'] = 'blog_post'

            # Create an excerpt if the post doesn't have one set
            if !post.has_key?('excerpt') || post['excerpt'].strip == ''
              post['excerpt'] = truncatewords(strip_html(content), 35)
            end

            # Convert the category UIDs to their text equivalents
            if categories
              post['category'].each_with_index do |category, index|
                this_category = categories.find { |c| c['uid'] === category }
                post['category'][index] = this_category['title']
              end
            end

            # Convert the author UID into the actual author data
            if post['author'] && post['author'][0]
              this_author = authors.find { |c| c['uid'] === post['author'][0] }
              post['author'] = this_author
            end

            # Convert the data to front matter variables
            as_yaml = post.to_yaml

            # Add to collection
            @posts.push(post)

            # Output the front matter and the raw post content into a Markdown file
            File.write(File.join(directory, "#{filename}.md"), "#{as_yaml}---\n{% raw %}#{content}{% endraw %}")
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