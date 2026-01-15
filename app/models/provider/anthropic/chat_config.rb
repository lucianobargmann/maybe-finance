class Provider::Anthropic::ChatConfig
  def initialize(functions: [], function_results: [])
    @functions = functions
    @function_results = function_results
  end

  def tools
    return [] if functions.empty?

    functions.map do |fn|
      {
        name: fn[:name],
        description: fn[:description],
        input_schema: fn[:params_schema]
      }
    end
  end

  def build_messages(prompt)
    messages = []

    # Add the user prompt
    messages << { role: "user", content: prompt }

    # Add function results if any
    function_results.each do |fn_result|
      messages << {
        role: "assistant",
        content: [
          {
            type: "tool_use",
            id: fn_result[:call_id],
            name: fn_result[:function_name] || "function",
            input: {}
          }
        ]
      }
      messages << {
        role: "user",
        content: [
          {
            type: "tool_result",
            tool_use_id: fn_result[:call_id],
            content: fn_result[:output].to_json
          }
        ]
      }
    end

    messages
  end

  private
    attr_reader :functions, :function_results
end
