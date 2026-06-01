# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocumentChunk, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:document) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_presence_of(:chunk_index) }
    it { is_expected.to validate_numericality_of(:chunk_index).is_greater_than_or_equal_to(0) }
  end

  describe 'neighbor configuration' do
    it 'responds to nearest_neighbors' do
      expect(described_class).to respond_to(:nearest_neighbors)
    end
  end
end
