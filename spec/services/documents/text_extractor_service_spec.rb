# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Documents::TextExtractorService do
  subject(:result) { described_class.call(document: document) }

  let(:document) { create(:document) }

  describe '.call' do
    context 'with a PDF document' do
      before do
        document.file.attach(
          io: StringIO.new('%PDF-1.4 fake content'),
          filename: 'test.pdf',
          content_type: 'application/pdf'
        )

        fake_page = instance_double(PDF::Reader::Page, text: 'Extracted text from PDF')
        fake_reader = instance_double(PDF::Reader, pages: [fake_page])
        allow(PDF::Reader).to receive(:new).and_return(fake_reader)
      end

      it 'returns success with extracted text' do
        expect(result).to be_success
        expect(result.text).to eq('Extracted text from PDF')
      end
    end

    context 'with a DOCX document' do
      before do
        document.file.attach(
          io: StringIO.new('fake docx content'),
          filename: 'test.docx',
          content_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        )

        # rubocop:disable RSpec/VerifiedDoubles
        fake_paragraph = double('paragraph', text: 'Paragraph 1')
        fake_doc = double('doc', paragraphs: [fake_paragraph])
        # rubocop:enable RSpec/VerifiedDoubles
        allow(Docx::Document).to receive(:open).and_return(fake_doc)
      end

      it 'returns success with extracted text' do
        expect(result).to be_success
        expect(result.text).to eq('Paragraph 1')
      end
    end

    context 'with a TXT document' do
      before do
        document.file.attach(
          io: StringIO.new("Hello world\nThis is a text file."),
          filename: 'test.txt',
          content_type: 'text/plain'
        )
      end

      it 'returns success with raw text content' do
        expect(result).to be_success
        expect(result.text).to eq("Hello world\nThis is a text file.")
      end
    end

    context 'when no file is attached' do
      let(:document) { create(:document) }

      it 'returns failure with a descriptive error' do
        expect(result).not_to be_success
        expect(result.error).to eq('No file attached to document')
      end
    end

    context 'with an unsupported file type' do
      before do
        document.file.attach(
          io: StringIO.new('some image data'),
          filename: 'test.png',
          content_type: 'image/png'
        )
      end

      it 'returns failure with a content type error' do
        expect(result).not_to be_success
        expect(result.error).to include('Unsupported file type')
      end
    end

    context 'when pdf-reader raises an exception' do
      before do
        document.file.attach(
          io: StringIO.new('%PDF-1.4 corrupt'),
          filename: 'test.pdf',
          content_type: 'application/pdf'
        )

        allow(PDF::Reader).to receive(:new).and_raise(PDF::Reader::MalformedPDFError, 'invalid xref table')
      end

      it 'returns failure with the exception message' do
        expect(result).not_to be_success
        expect(result.error).to eq('invalid xref table')
      end

      it 'does not raise' do
        expect { result }.not_to raise_error
      end
    end

    context 'with text containing null bytes and control characters' do
      before do
        document.file.attach(
          io: StringIO.new("Hello\x00World\x01Test\x02Done"),
          filename: 'test.txt',
          content_type: 'text/plain'
        )
      end

      it 'strips null bytes and control characters from extracted text' do
        expect(result).to be_success
        expect(result.text).to eq('HelloWorldTestDone')
      end

      it 'removes all null bytes from extracted text' do
        expect(result.text).not_to include("\x00")
      end
    end
  end
end
