# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationPolicy, type: :policy do
  subject(:policy) { described_class }

  let(:user) { create(:user) }
  let(:record) { :any_record }

  describe '#initialize' do
    context 'when the user is nil' do
      it 'raises Pundit::NotAuthorizedError so controllers fail loudly' do
        expect { described_class.new(nil, record) }
          .to raise_error(Pundit::NotAuthorizedError, /must be logged in/)
      end
    end

    context 'when a user is provided' do
      it 'exposes the user via #user' do
        instance = described_class.new(user, record)
        expect(instance.user).to eq(user)
      end

      it 'exposes the record via #record' do
        instance = described_class.new(user, record)
        expect(instance.record).to eq(record)
      end
    end
  end

  # ApplicationPolicy is the default-deny base. Every action must return false
  # until a subclass opts in. We assert this with `not_to permit` over the
  # full permission set, so any future action that accidentally returns true
  # here will fail the spec.
  permissions :index?, :show?, :create?, :update?, :destroy? do
    it 'denies every action by default' do
      expect(policy).not_to permit(user, record)
    end
  end

  describe ApplicationPolicy::Scope do
    let(:scope) { instance_double(ActiveRecord::Relation) }

    describe '#initialize' do
      it 'raises Pundit::NotAuthorizedError when user is nil' do
        expect { described_class.new(nil, scope) }
          .to raise_error(Pundit::NotAuthorizedError, /must be logged in/)
      end
    end

    describe '#resolve' do
      it 'raises NotImplementedError on the base Scope' do
        expect { described_class.new(user, scope).resolve }
          .to raise_error(NotImplementedError, /has not been implemented/)
      end
    end
  end
end
