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

              generate_press_releases
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
          blog_home = get_content_json('blog_home')

          if blog_home
            blog_home = blog_home.first

            if blog_home['featured_post'].length == 1
              featured_post = @posts.find {|post| post['uid'] === blog_home['featured_post'][0]}
            else
              featured_post = @posts.sort {|a, b| b['date'] <=> a['date']}.first
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

          unless posts
            Jekyll.logger.info 'No new blog posts found'
            return
          end

          # Make '_posts' collection directory
          directory = File.join(@site.config['source'], '_posts')
          Dir.mkdir(directory) unless File.exists?(directory)

          posts.each do |post|
            # Overrides
            post['layout'] = 'article'

            # Set permalink from url value
            post['permalink'] = post['url']

            # Strip slashes out of URL to create slug
            filename_title = post['url'].gsub(/[\s\/]/, '')

            # Create standard filename expected for posts
            filename = Date.iso8601(post['date']).strftime + "-#{filename_title}"
            # Jekyll.logger.info "Generating #{filename}..."

            # Pull out the content
            content = post['full_description']
            post.delete('full_description')

            # Convert featured image UID to local file path
            if post.has_key?('featured_image')
              assetData = assets.find {|asset| asset['uid'] == post['featured_image']}

              if assetData
                post['featured_image'] = "assets/images/#{post['featured_image']}/#{assetData['filename']}"
              end
            end

            # Set a search type for indexing
            post['search_type'] = 'blog_post'

            # Create an excerpt if the post doesn't have one set
            if !post.has_key?('excerpt') || post['excerpt'].strip == ''
              post['excerpt'] = truncatechars(strip_html(content), 240)
            end

            # Convert the category UIDs to their text equivalents
            if categories
              post['category'].each_with_index do |category, index|
                this_category = categories.find {|c| c['uid'] === category}

                if this_category
                  post['category'][index] = this_category['title']
                end
              end
            end

            # Convert the author UID into the actual author data
            if post['author'] && post['author'][0]
              post['authorData'] = []
              
              post['author'].each do |author|
                this_author = authors.find {|c| c['uid'] === author}

                if this_author
                  post['author'] = this_author['title']
                  post['authorData'].shift(this_author)
                end
              end
            end

            # Convert the data to front matter variables
            as_yaml = post.to_yaml

            # Add to collection
            @posts.push(post)

            # Output the front matter and the raw post content into a Markdown file
            File.write(File.join(directory, "#{filename}.md"), "#{as_yaml}---\n{% raw %}#{content}{% endraw %}")
          end
        end

        def generate_press_releases
          Jekyll.logger.info 'Generating press releases...'

          # Fetch them
          press_releases = get_content_json('press_releases')

          unless press_releases
            Jekyll.logger.info 'No new press releases found'
            return
          end

          # Make '_press_releases' collection directory
          directory = File.join(@site.config['source'], '_press_releases')
          Dir.mkdir(directory) unless File.exists?(directory)

          press_releases.each do |press_release|
            # Strip slashes out of URL to create slug
            filename_title = press_release['url'].gsub(/[\s\/]/, '')

            # Create standard filename expected for press_releases
            filename = Date.iso8601(press_release['date']).strftime + "-#{filename_title}"
            # Jekyll.logger.info "Generating #{filename}..."

            # Pull out the content
            content = press_release['body']
            press_release.delete('body')

            # Switch URL field to be permalink
            press_release['permalink'] = press_release['url'] + '/'
            press_release.delete('url')

            # Set a search type for indexing
            press_release['search_type'] = 'press_release'

            # Convert the data to front matter variables
            as_yaml = press_release.to_yaml

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

        # Truncate to the number of characters without splitting words
        def truncatechars(input, limit = 300, truncate_string = '...'.freeze)

          if input.nil? then
            return
          end

          if input.length > limit
            # Split string into words
            input_words = input.to_s.split

            # Count characters used
            chars_count = 0
            output_words = []

            input_words.each do |word|
              if chars_count + word.length >= limit
                return output_words.join(' ') + truncate_string
              else
                chars_count += word.length + 1
                output_words.push(word)
              end
            end

          else
            return input
          end
        end
      end
    end
  end
end
