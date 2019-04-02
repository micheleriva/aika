<img src="/src/aika_logo.png" align="center" />

**Aika** is a simple key-value in-memory database compatible with Redis.

```sh
sh redis-cli -p 9919
127.0.0.1:9919> set name John
127.0.0.1:9919> get name "John"
```

It aims to be an evolution of the database described in [this awesome blog post](https://honza.ca/2015/09/building-a-redis-clone-in-haskell). <br />
It's just a research project, not ready for production.

# License
Aika is [MIT](/LICENSE.md) licensed.