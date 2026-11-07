"""Tools the model may call. Each takes the keyword arguments the model chose."""


def word_count(text):
    return str(len(text.split()))


TOOLS = {"word_count": word_count}
