# Normalise ISSNs

Brings ISSNs into the canonical form `NNNN-NNNC` with an uppercase check
character and drops values whose check digit is wrong.

## Usage

``` r
normalize_issn(x)
```

## Arguments

- x:

  Character vector.

## Value

Character vector of the same length; invalid ISSNs become `NA`.

## Examples

``` r
normalize_issn(c("0021-843x", "0027 -4224", "1031-461I", "yyyy-yyyy"))
#> [1] "0021-843X" "0027-4224" NA          NA         
```
