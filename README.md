# NAME

Async::Timeouts - A library of tools for managing timeouts and retries

# SYNOPSIS

```perl6
use Async::Timeouts;
Timeout(:retry(
	Retry.new(
		:mode(RetryMode::exponential),
		:max-attempts=5)).timeout({
			get("http://example.com/") or die;
	});
```

... much more to come ...

# DESCRIPTION

`Async::Timeouts` is designed to be an easy-to-use wrapper around
timing out both synchronous and asynchronous execution of either
code within your program or external programs/interfaces.

## Retry

`Retry` is a class that implements various retry
strategies by providing a `pause` method that returns the "next"
time increment to pause before retrying the action. Retry doesn't
actually implement the retry mechanism itself, it just encapsulates
the strategy / algorithm for determining the next pause or end of
retry sequence.

## Timeout

TBD...

# AUTHOR

(c) 2019 by Aaron Sherman `<ajs@ajs.com>`

# LICENSE

Artistic License 2.0, see LICENSE for details.
