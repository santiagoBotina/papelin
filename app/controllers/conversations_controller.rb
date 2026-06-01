# frozen_string_literal: true

class ConversationsController < ApplicationController
  def index
    @conversations = policy_scope(Conversation).recent
    render plain: 'placeholder'
  end

  def show
    @conversation = Conversation.find(params[:id])
    authorize @conversation
    render plain: 'placeholder'
  end

  def create
    @conversation = current_user.conversations.create!
    authorize @conversation
    redirect_to @conversation, notice: 'Conversation created.'
  end

  def destroy
    @conversation = Conversation.find(params[:id])
    authorize @conversation
    @conversation.destroy!
    redirect_to conversations_path, notice: 'Conversation deleted.'
  end
end
