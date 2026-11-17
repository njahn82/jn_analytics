# Validate a table against the jnanalytics schema

Checks that a data frame has exactly the columns of `table` in schema
order, that every column has the expected type, and that the key columns
are complete and unique. Identifier formats are checked where a rule
exists (`issn_l`, `issn`, `doi`, `ror`, `country_code`, `cc_license`,
`oa_model`, `oa_status`, `work_type`, OpenAlex IDs).

## Usage

``` r
jn_validate(x, table)
```

## Arguments

- x:

  A data frame.

- table:

  Table name, see
  [`jn_tables()`](https://njahn82.github.io/jn_analytics/reference/jn_tables.md).

## Value

`x`, invisibly. An error is raised listing every problem found.

## Examples

``` r
jn_validate(journals, "journals")
```
