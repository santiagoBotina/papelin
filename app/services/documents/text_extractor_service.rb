# frozen_string_literal: true

module Documents
  # Extracts plain text from an uploaded Document's attached file.
  #
  # Supported formats: PDF, DOCX, TXT.
  # Strips null bytes and control characters from extracted text.
  class TextExtractorService
    Result = Struct.new(:success?, :text, :error, keyword_init: true)

    SUPPORTED_CONTENT_TYPES = %w[
      application/pdf
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
      text/plain
      text/markdown
    ].freeze

    # Matches common Unicode emoji ranges (pictographs, emoticons, symbols,
    # and supplemental pictographs).  Stripping them before chunking/embedding
    # removes semantic noise so the vector better represents the actual text.
    EMOJI_REGEX = /[\u{2600}-\u{27BF}\u{1F300}-\u{1F9FF}\u{1FA00}-\u{1FAFF}\u{FE00}-\u{FE0F}]/

    def self.call(document:)
      new(document: document).call
    end

    def initialize(document:)
      @document = document
    end

    def call
      no_file_result = Result.new(success?: false, error: 'No file attached to document', text: nil)
      return no_file_result unless file_attached?

      bad_type_result = Result.new(success?: false, error: "Unsupported file type: #{content_type}", text: nil)
      return bad_type_result unless supported_type?

      text = extract_text
      cleaned = strip_control_characters(text)
      Result.new(success?: true, text: cleaned, error: nil)
    rescue StandardError => e
      Result.new(success?: false, text: nil, error: e.message)
    end

    private

    def file_attached?
      @document.file.attached?
    end

    def content_type
      @document.file.content_type
    end

    def supported_type?
      SUPPORTED_CONTENT_TYPES.include?(content_type)
    end

    def extract_text
      case content_type
      when 'application/pdf'
        extract_pdf
      when 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        extract_docx
      when 'text/plain'
        extract_txt
      when 'text/markdown'
        extract_markdown
      end
    end

    def extract_pdf
      io = StringIO.new(@document.file.download)
      reader = PDF::Reader.new(io)
      reader.pages.map(&:text).join("\n")
    end

    def extract_docx
      Tempfile.open(%w[docx .docx]) do |tempfile|
        tempfile.binmode
        tempfile.write(@document.file.download)
        tempfile.rewind

        doc = Docx::Document.open(tempfile.path)
        doc.paragraphs.map(&:text).join("\n")
      end
    end

    def extract_txt
      raw = @document.file.download
      # ActiveStorage downloads as ASCII-8BIT; force UTF-8 for downstream use
      raw.force_encoding('UTF-8')
      strip_markdown_syntax(raw)
    end

    def extract_markdown
      raw = @document.file.download
      raw.force_encoding('UTF-8')
      strip_markdown_syntax(raw)
    end

    # Removes common Markdown formatting syntax so the plain text fed to the
    # embedding model produces semantically clean vectors without noise from
    # formatting tokens (#, **, [], (), backticks, emojis, etc.).
    def strip_markdown_syntax(text)
      text
        .gsub(/^\#{1,6}\s+/, '') # headings: ## text → text
        .gsub(/\[([^\[\]]*)\]\([^()]*\)/, '\1') # [text](url) → text
        .gsub(/[*_]{1,3}/, '')             # bold/italic: **text** → text
        .gsub(/`{1,3}([^`]*)`{1,3}/, '\1') # inline code: `code` → code
        .gsub(/~~(.+?)~~/, '\1')           # strikethrough
        .gsub(/^\s*[-*+]{1,3}\s/, '')      # unordered list markers
        .gsub(/^\s*\d+\.\s/, '')           # ordered list markers
        .gsub(/>\s/, '')                   # blockquotes
        .delete('|')                       # table pipes
        .gsub(/^---+$/, '')                # horizontal rules
        .gsub(EMOJI_REGEX, '')             # emojis to reduce embedding noise
        .gsub(/\n{3,}/, "\n\n")            # collapse excessive blank lines
        .strip
    end

    # Strip null bytes and non-whitespace control characters that would
    # corrupt the database or confuse the embedding API.
    # Preserves newlines (\n), carriage returns (\r), and tabs (\t).
    def strip_control_characters(text)
      text.gsub(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/, '')
    end
  end
end
