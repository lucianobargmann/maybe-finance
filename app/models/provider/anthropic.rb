class Provider::Anthropic < Provider
  include LlmConcept

  # Subclass so errors caught in this provider are raised as Provider::Anthropic::Error
  Error = Class.new(Provider::Error)

  MODELS = %w[claude-sonnet-4-20250514 claude-3-5-sonnet-20241022 claude-3-haiku-20240307]

  def initialize(api_key)
    @client = ::Anthropic::Client.new(api_key: api_key)
  end

  def supports_model?(model)
    MODELS.include?(model)
  end

  def auto_categorize(transactions: [], user_categories: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-categorize. Max is 25 per request." if transactions.size > 25

      AutoCategorizer.new(
        client,
        transactions: transactions,
        user_categories: user_categories
      ).auto_categorize
    end
  end

  def auto_detect_merchants(transactions: [], user_merchants: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-detect merchants. Max is 25 per request." if transactions.size > 25

      AutoMerchantDetector.new(
        client,
        transactions: transactions,
        user_merchants: user_merchants
      ).auto_detect_merchants
    end
  end

  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, previous_response_id: nil)
    with_provider_response do
      chat_config = ChatConfig.new(
        functions: functions,
        function_results: function_results
      )

      collected_chunks = []

      messages = chat_config.build_messages(prompt)

      if streamer.present?
        # Streaming response
        response_id = SecureRandom.uuid
        full_text = ""
        tool_use_blocks = []

        client.messages.create(
          model: model,
          max_tokens: 4096,
          system: instructions,
          messages: messages,
          tools: chat_config.tools,
          stream: proc do |event|
            case event["type"]
            when "content_block_delta"
              delta = event.dig("delta")
              if delta["type"] == "text_delta"
                text = delta["text"]
                full_text += text
                parsed_chunk = ChatStreamChunk.new(type: "output_text", data: text)
                streamer.call(parsed_chunk)
                collected_chunks << parsed_chunk
              end
            when "content_block_start"
              block = event.dig("content_block")
              if block["type"] == "tool_use"
                tool_use_blocks << {
                  id: block["id"],
                  name: block["name"],
                  input: ""
                }
              end
            when "content_block_delta"
              delta = event.dig("delta")
              if delta["type"] == "input_json_delta" && tool_use_blocks.any?
                tool_use_blocks.last[:input] += delta["partial_json"]
              end
            when "message_stop"
              # Build final response
              function_requests = tool_use_blocks.map do |tool|
                ChatFunctionRequest.new(
                  id: tool[:id],
                  call_id: tool[:id],
                  function_name: tool[:name],
                  function_args: tool[:input]
                )
              end

              messages = [ ChatMessage.new(id: response_id, output_text: full_text) ]
              final_response = ChatResponse.new(
                id: response_id,
                model: model,
                messages: messages,
                function_requests: function_requests
              )

              response_chunk = ChatStreamChunk.new(type: "response", data: final_response)
              streamer.call(response_chunk)
              collected_chunks << response_chunk
            end
          end
        )

        # Return the final response from collected chunks
        response_chunk = collected_chunks.find { |chunk| chunk.type == "response" }
        response_chunk&.data
      else
        # Non-streaming response
        raw_response = client.messages.create(
          model: model,
          max_tokens: 4096,
          system: instructions,
          messages: messages,
          tools: chat_config.tools
        )

        ChatParser.new(raw_response).parsed
      end
    end
  end

  private
    attr_reader :client
end
