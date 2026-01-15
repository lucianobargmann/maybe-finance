class Provider::Anthropic::ChatParser
  Error = Class.new(StandardError)

  def initialize(response)
    @response = response
  end

  def parsed
    ChatResponse.new(
      id: response_id,
      model: response_model,
      messages: messages,
      function_requests: function_requests
    )
  end

  private
    attr_reader :response

    ChatResponse = Provider::LlmConcept::ChatResponse
    ChatMessage = Provider::LlmConcept::ChatMessage
    ChatFunctionRequest = Provider::LlmConcept::ChatFunctionRequest

    def response_id
      response["id"]
    end

    def response_model
      response["model"]
    end

    def messages
      text_content = response["content"]&.select { |c| c["type"] == "text" } || []

      return [] if text_content.empty?

      [
        ChatMessage.new(
          id: response_id,
          output_text: text_content.map { |c| c["text"] }.join("\n")
        )
      ]
    end

    def function_requests
      tool_use_content = response["content"]&.select { |c| c["type"] == "tool_use" } || []

      tool_use_content.map do |tool_use|
        ChatFunctionRequest.new(
          id: tool_use["id"],
          call_id: tool_use["id"],
          function_name: tool_use["name"],
          function_args: tool_use["input"].to_json
        )
      end
    end
end
