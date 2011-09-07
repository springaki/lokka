module Lokka
  module Importer
    class WordPress
      def initialize(file)
        @file = file
      end

      def import
        doc = Nokogiri::XML(@file.read.gsub(//, ''))
        doc.xpath('/rss/channel',
        'content' => 'http://purl.org/rss/1.0/modules/content/',
        'wp' => 'http://wordpress.org/export/1.1/').each do |channel|
          Site.first.update(
            :title => channel.xpath('title').text,
            :description => channel.xpath('description').text
          )

          channel.xpath('wp:author').each do |author|
            User.first_or_create(
              :name  => author.xpath('wp:author_login').text,
              :email => author.xpath('wp:author_email').text
            )
          end

          channel.xpath('wp:category').each do |category|
            Category.first_or_create(
              :slug  => category.xpath('wp:cat_name').text,
              :title => category.xpath('wp:category_nicename').text
            )
          end

          channel.xpath('item').each do |item|
            model =
              case item.xpath('wp:post_type').text
              when 'post'
                Post
              when 'page'
                Page
              end

            puts item.xpath('content:encoded').text
            puts item.xpath('wp:post_date_gmt').text
            attrs = {
              :id    => item.xpath('wp:post_id').text.to_i,
              :title => item.xpath('title').text,
              :body  => item.xpath('content:encoded').text,
              :draft => item.xpath('wp:status').text == 'publish' ? false : true,
              :created_at => Time.parse(item.xpath('wp:post_date_gmt').text),
              :updated_at => Time.parse(item.xpath('wp:post_date_gmt').text)
            }

            if entry = model.get(attrs[:id])
              entry.update(attrs)
            else
              entry = model.create(attrs)
            end

            item.xpath("category[@domain='post_tag']").each do |tag|
              entry.tag_list << tag.text
            end

            item.xpath("category[@domain='category']").each do |category|
              if category = Category.first(:title => category.text)
                entry.category = category
              end
            end

            entry.comments.destroy

            item.xpath('wp:comment').each do |comment|
              comment = Comment.new(
                :name => comment.xpath('wp:comment_author').text,
                :email => comment.xpath('wp:comment_email').text,
                :body => comment.xpath('wp:comment_content').text,
                :created_at => comment.xpath('wp:comment_date').text,
                :status => comment.xpath('wp:comment_approvied').text == '1' ? 1 : 0
              )
              entry.comments << comment
            end

            entry.save
          end
        end
      end
    end
  end
end
