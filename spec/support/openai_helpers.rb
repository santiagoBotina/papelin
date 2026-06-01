# frozen_string_literal: true

# Shared helpers for stubbing OpenAI API calls in specs.
# All OpenAI calls must be stubbed — never hit the real API in tests.
# Include this module in spec/rails_helper.rb (already wired via glob).

module OpenAIHelpers
  FAKE_EMBEDDING = Array.new(1536) { rand(-1.0..1.0) }.freeze

  # Stubs POST /v1/embeddings with a fake 1536-dim embedding response.
  def stub_openai_embedding(text: anything, embedding: FAKE_EMBEDDING)
    stub_request(:post, 'https://api.openai.com/v1/embeddings')
      .with(body: hash_including(input: text))
      .to_return(
        status: 200,
        body: {
          data: [{ embedding: embedding, index: 0 }],
          model: 'text-embedding-3-small',
          usage: { prompt_tokens: 10, total_tokens: 10 }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Stubs POST /v1/chat/completions with a fake assistant response.
  # The `content` param is the assistant message content to return.
  # When `stream` is true, yields tokens via the stream proc.
  def stub_openai_chat(content: 'Mocked assistant response', stream: false)
    body = chat_response_body(content, stream)
    stub_request(:post, 'https://api.openai.com/v1/chat/completions')
      .to_return(
        status: 200,
        body: body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  private

  def chat_response_body(content, stream)
    if stream
      {
        choices: [{ delta: { role: 'assistant', content: content }, finish_reason: 'stop' }],
        usage: { prompt_tokens: 100, completion_tokens: 50, total_tokens: 150 }
      }
    else
      {
        choices: [{ message: { role: 'assistant', content: content }, finish_reason: 'stop' }],
        usage: { prompt_tokens: 100, completion_tokens: 50, total_tokens: 150 }
      }
    end
  end

  # Stubs the OpenAI::Client.chat method at the object level.
  # This bypasses the HTTP layer entirely — useful when streaming is used.
  # Returns a hash that mirrors the OpenAI API response.
  def stub_openai_chat_client(content: 'Mocked assistant response')
    response = {
      'choices' => [{ 'message' => { 'role' => 'assistant', 'content' => content },
                      'finish_reason' => 'stop' }],
      'usage' => { 'prompt_tokens' => 100, 'completion_tokens' => 50, 'total_tokens' => 150 }
    }

    client_instance = instance_double(OpenAI::Client)
    allow(OpenAI::Client).to receive(:new).and_return(client_instance)
    allow(client_instance).to receive(:chat).and_return(response)
  end

  # Stubs POST /v1/chat/completions to return an error.
  def stub_openai_error(status: 500, body: nil)
    body ||= { error: { message: 'Internal Server Error', type: 'server_error' } }.to_json
    stub_request(:post, 'https://api.openai.com/v1/chat/completions')
      .to_return(status: status, body: body, headers: { 'Content-Type' => 'application/json' })
  end

  # Stubs POST /v1/embeddings to return an error.
  def stub_openai_embedding_error(status: 500, body: nil)
    body ||= { error: { message: 'Internal Server Error', type: 'server_error' } }.to_json
    stub_request(:post, 'https://api.openai.com/v1/embeddings')
      .to_return(status: status, body: body, headers: { 'Content-Type' => 'application/json' })
  end
end
