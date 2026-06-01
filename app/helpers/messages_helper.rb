# frozen_string_literal: true

module MessagesHelper
  def render_markdown(text)
    return '' if text.blank?

    renderer = Redcarpet::Render::HTML.new(
      hard_wrap: true,
      safe_links_only: true,
      no_images: true,
      filter_html: true
    )
    markdown = Redcarpet::Markdown.new(renderer,
                                       autolink: true,
                                       tables: true,
                                       fenced_code_blocks: true,
                                       strikethrough: true)
    # rubocop:disable Rails/OutputSafety
    content_tag(:div, markdown.render(text).html_safe, class: 'prose prose-sm max-w-none')
    # rubocop:enable Rails/OutputSafety
  end
end
