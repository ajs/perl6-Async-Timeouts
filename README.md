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

### Construction

You can instantiate a Retry objet using the exported enums,
`RetryMode` and `RetryRandom` or by using their string equivalents
like so:

    Retry.new(:mode<exponential>, :random<none>)

The parameters are:

* `:mode` - The backoff mode (enumeration in `RetryMode`. Can be any of:
  * `immediate` - No pause between retries
  * `constant` - Pause `:basis` time units between retries
  * `linear` - Increase the pause by `:basis` each retry
  * `exponential` - Raise `:basis` to the number of retries
  * `polynomial` - Raise number of retries to `:basis`
  * `custom` - Provided `:sequence` is used
  * `fibonacci` - Returned pause values are the Fibbonacci sequence
* `:random` - How/if to randomly modify the backoff (enumeration in
  `RetryRandom`). Can be any of:
  * `none` - No randomness
  * `always` - Returned value will be in the range of 0 to the
    non-random value.
  * `increasing` - Returned value will be randomized, but will be
    larger than the previous returned value.
  * `first` - Only randomize the first returned value.
* `:max-attempts` - Maximum number of retries, after which the `pause`
  method will return a failure of type `X::RetryLimit`.
* `:max-elapsed` - If a returned pause would increase the total elapsed
  retry pauses to be greater than this value (if defined) then a failure
  of type `X::RetryLimit` is returned instead.
* `:basis` - The constant value whose use is `:mode`-dependant.
* `:scale` - Scaling factor for returned `pause` values. Defaults to 1.
* `:sequence` -If `:mode` is `custom`, then this parameter is required
  and must contain a sequence or list of pause values.

## Timeout

TBD...

# AUTHOR

(c) 2019 by Aaron Sherman `<ajs@ajs.com>`

# LICENSE

Artistic License 2.0, see LICENSE for details.
