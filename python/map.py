"""
Every project needs a "Map" class - it allows you to "dot" into dict.
This saves a lot of annoyance in typing and makes things easier to work with
"""


class Map(dict):
    """
    Acts like a dict and can also be dotted-into
    Adapted from a few StackOverflow Q&As

    Example:
    my_instance = Map(foo="a")
    my_instance["bar"] = "b"
    print(myinstance.foo)
    print(myinstance.bar)
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    def __getattr__(self, attr):
        return self.get(attr)

    def __setattr__(self, key, value):
        self.__setitem__(key, value)

    def __setitem__(self, key, value):
        super().__setitem__(key, value)
        self.__dict__.update({key: value})

    def __delattr__(self, item):
        self.__delitem__(item)

    def __delitem__(self, key):
        super().__delitem__(key)
        del self.__dict__[key]
