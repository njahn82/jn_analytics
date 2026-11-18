# build_portfolios() lists the agreements of each publisher page

    Code
      build_portfolios(empty, agreements, links, NULL)
    Condition
      Error in `build_portfolios()`:
      ! Portfolio without agreements: "elsevier"

# institution corrections that no longer apply stop the build

    Code
      apply_institution_corrections(table, corrections, "a1")
    Condition
      Error:
      ! 'manual/institution_corrections.csv' does not fit the JCT institution lists.
      x Unknown action drop for a1 https://ror.org/00g2ypp58.
      x Unknown agreement gone.
      x a1 https://ror.org/02e2c7k09 (TU Delft) is listed already; remove the `add` row.
      x a1 https://ror.org/05gxyna29 (Not listed) is not listed; remove the `remove` row.

