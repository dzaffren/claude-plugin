"""helpdesk: command-line entry point."""
import argparse
import json

from helpdesk_agent.agent import run


def replay_model(path):
    """A model stand-in that gives back recorded replies in order, offline."""
    with open(path) as handle:
        replies = json.load(handle)

    def model(messages):
        return replies.pop(0)

    return model


def main(argv=None):
    parser = argparse.ArgumentParser(prog="helpdesk")
    parser.add_argument("question")
    parser.add_argument("--replay", required=True, help="a JSON list of recorded model replies")
    args = parser.parse_args(argv)
    print(run(args.question, replay_model(args.replay)))


if __name__ == "__main__":
    main()
