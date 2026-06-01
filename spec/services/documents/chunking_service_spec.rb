# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Documents::ChunkingService do
  let(:document) { create(:document) }
  let(:text) { 'A' * 5000 }
  let(:chunk_size) { described_class::CHUNK_SIZE }
  let(:chunk_overlap) { described_class::CHUNK_OVERLAP }

  describe '.call' do
    subject(:chunks) { described_class.call(text: text, document: document) }

    context 'with a normal-length text' do
      # 5000 chars, CHUNK_SIZE=2000, overlap=200 → step=1800
      # chunks at: 0..2000, 1800..3800, 3600..5000 → 3 chunks
      it 'returns multiple chunks' do
        expect(chunks.length).to eq(3)
      end

      it 'assigns sequential chunk_index values starting at 0' do
        indexes = chunks.pluck(:chunk_index)
        expect(indexes).to eq([0, 1, 2])
      end

      it 'includes the document_id in every chunk' do
        chunks.each { |c| expect(c[:document_id]).to eq(document.id) }
      end

      it 'overlaps adjacent chunks by CHUNK_OVERLAP characters' do
        chunk0_end = chunks[0][:content][-chunk_overlap..]
        chunk1_start = chunks[1][:content][0...chunk_overlap]
        expect(chunk0_end).to eq(chunk1_start)
      end

      it 'includes char_start and char_end in metadata JSON' do
        meta0 = JSON.parse(chunks[0][:metadata])
        expect(meta0).to have_key('char_start')
        expect(meta0).to have_key('char_end')
        expect(meta0['char_start']).to eq(0)
        expect(meta0['char_end']).to eq(2000)
      end
    end

    context 'with text shorter than CHUNK_SIZE' do
      let(:text) { 'Short text' }

      it 'returns exactly one chunk' do
        expect(chunks.length).to eq(1)
      end

      it 'assigns chunk_index 0 to the single chunk' do
        expect(chunks.first[:chunk_index]).to eq(0)
      end
    end

    context 'with empty text' do
      let(:text) { '' }

      it 'returns an empty array' do
        expect(chunks).to eq([])
      end
    end

    context 'with text containing only whitespace' do
      let(:text) { '   ' }

      it 'returns an empty array' do
        expect(chunks).to eq([])
      end
    end

    context 'with chunk boundary verification' do
      let(:text) { 'A' * 5000 }

      it 'the last chunk ends at or before the end of the text' do
        last = chunks.last
        meta = JSON.parse(last[:metadata])
        expect(meta['char_end']).to eq(text.length)
      end

      it 'every chunk has content present' do
        chunks.each { |c| expect(c[:content]).to be_present }
      end
    end

    describe 'returned hash structure' do
      let(:text) { 'Hello world' }

      it 'has the correct keys' do
        expected_keys = %i[document_id content chunk_index metadata created_at updated_at]
        expect(chunks.first.keys).to match_array(expected_keys)
      end
    end
  end
end
