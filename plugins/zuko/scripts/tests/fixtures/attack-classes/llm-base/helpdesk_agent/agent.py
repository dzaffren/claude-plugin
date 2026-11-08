"""The tool loop: ask the model, run the tool it calls, hand back the result."""
from helpdesk_agent.tools import TOOLS


def run(question, model, max_steps=5):
    messages = [{"role": "user", "content": question}]
    for _ in range(max_steps):
        reply = model(messages)
        call = reply.get("tool_call")
        if call is None:
            return reply["content"]
        result = TOOLS[call["name"]](**call["arguments"])
        messages.append({"role": "tool", "name": call["name"], "content": result})
    return "stopped after %d steps" % max_steps
