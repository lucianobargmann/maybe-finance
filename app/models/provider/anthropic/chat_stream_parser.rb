class Provider::Anthropic::ChatStreamParser
  Error = Class.new(StandardError)

  def initialize(event)
    @event = event
  end

  def parsed
    type = event["type"]

    case type
    when "content_block_delta"
      delta = event.dig("delta")
      if delta["type"] == "text_delta"
        Chunk.new(type: "output_text", data: delta["text"])
      end
    when "message_stop"
      # Final response will be built by the main provider
      nil
    end
  end

  private
    attr_reader :event

    Chunk = Provider::LlmConcept::ChatStreamChunk
end
