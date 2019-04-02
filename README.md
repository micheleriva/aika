<img src="/docs/aika_logo.png" align="center" />

**Aika** is a simple and high performance key-value in-memory database. <br />
You can test it using **redis-cli**:

```sh
sh redis-cli -p 9919
127.0.0.1:9919> set name John
127.0.0.1:9919> get name "John"
```

It aims to be an evolution of the database described in [this awesome blog post](https://honza.ca/2015/09/building-a-redis-clone-in-haskell). <br />
It's just a research project, not ready for production.

# Installation

You can build your own **Aika** version by cloning the repository and using Haskell **stack**:

```sh
git clone git@github.com:micheleriva/aika.git && cd aika
stack build && stack exec aika
```

# License
Aika is [MIT](/LICENSE.md) licensed.