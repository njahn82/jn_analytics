# Normalise ROR IDs

Brings ROR IDs into the canonical form `https://ror.org/0xxxxxxNN`
(lowercase, full URL) and drops values that are not ROR IDs.

## Usage

``` r
normalize_ror(x)
```

## Arguments

- x:

  Character vector.

## Value

Character vector of the same length; invalid IDs become `NA`.

## Examples

``` r
normalize_ror(c("ror.org/05gxyna29", "https://ror.org/02E2C7K09", "v"))
#> [1] "https://ror.org/05gxyna29" "https://ror.org/02e2c7k09"
#> [3] NA                         
```
