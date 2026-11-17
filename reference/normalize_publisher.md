# Normalise publisher names

Replaces `&` with `and`, squishes whitespace and applies a lookup of
known variants, so that `journals` and `agreements` use one name per
publisher.

## Usage

``` r
normalize_publisher(x, lookup = NULL)
```

## Arguments

- x:

  Character vector of publisher names.

- lookup:

  Data frame with columns `name` (variant) and `publisher` (normalised
  name). Lookups are matched after `&` has been replaced.

## Value

Character vector.

## Examples

``` r
normalize_publisher(c("Taylor & Francis", "CSIRO"),
  lookup = data.frame(name = "CSIRO", publisher = "CSIRO Publishing"))
#> [1] "Taylor and Francis" "CSIRO Publishing"  
```
