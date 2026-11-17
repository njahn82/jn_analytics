#' Normalise ISSNs
#'
#' Brings ISSNs into the canonical form `NNNN-NNNC` with an uppercase check
#' character and drops values whose check digit is wrong.
#'
#' @param x Character vector.
#' @return Character vector of the same length; invalid ISSNs become `NA`.
#' @export
#' @examples
#' normalize_issn(c("0021-843x", "0027 -4224", "1031-461I", "yyyy-yyyy"))
normalize_issn <- function(x) {
  x <- toupper(gsub("[^0-9Xx]", "", as.character(x)))
  ok <- !is.na(x) & grepl("^[0-9]{7}[0-9X]$", x)
  ok[ok] <- issn_check_digit(substr(x[ok], 1, 7)) == substr(x[ok], 8, 8)
  out <- rep(NA_character_, length(x))
  out[ok] <- paste0(substr(x[ok], 1, 4), "-", substr(x[ok], 5, 8))
  out
}

issn_check_digit <- function(first7) {
  digits <- do.call(rbind, lapply(strsplit(first7, ""), as.integer))
  if (length(digits) == 0) return(character())
  total <- as.vector(digits %*% (8:2))
  check <- (11 - total %% 11) %% 11
  ifelse(check == 10, "X", as.character(check))
}

#' Normalise publisher names
#'
#' Replaces `&` with `and`, squishes whitespace and applies a lookup of known
#' variants, so that `journals` and `agreements` use one name per publisher.
#'
#' @param x Character vector of publisher names.
#' @param lookup Data frame with columns `name` (variant) and `publisher`
#'   (normalised name). Lookups are matched after `&` has been replaced.
#' @return Character vector.
#' @export
#' @examples
#' normalize_publisher(c("Taylor & Francis", "CSIRO"),
#'   lookup = data.frame(name = "CSIRO", publisher = "CSIRO Publishing"))
normalize_publisher <- function(x, lookup = NULL) {
  x <- gsub("\\s+", " ", trimws(gsub("&", "and", x, fixed = TRUE)))
  if (!is.null(lookup) && nrow(lookup) > 0) {
    i <- match(x, lookup$name)
    x[!is.na(i)] <- lookup$publisher[i[!is.na(i)]]
  }
  x
}

# URL-safe slug, e.g. for portfolio IDs
slugify <- function(x) {
  # German umlauts, written as code points to keep the source ASCII
  umlauts <- c(
    "ae" = 228, "oe" = 246, "ue" = 252, "Ae" = 196, "Oe" = 214, "Ue" = 220, "ss" = 223
  )
  for (i in seq_along(umlauts)) {
    x <- gsub(intToUtf8(umlauts[[i]]), names(umlauts)[i], x, fixed = TRUE)
  }
  # Transliteration differs between platforms (macOS writes `"e` for an e
  # with diaeresis), so drop everything that is not a letter or digit after
  x <- iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT", sub = "")
  x <- gsub("[\"'`^~]", "", x)
  x <- tolower(gsub("[^A-Za-z0-9]+", "-", x))
  gsub("^-+|-+$", "", x)
}

# ISO-2 code for a single country name
#
# Returns `NA` when `x` lists several countries (comma-separated), because
# `agreements.country` is only set for national agreements.
country_iso2 <- function(x) {
  single <- !is.na(x) & !grepl(",", x)
  out <- rep(NA_character_, length(x))
  out[single] <- suppressWarnings(countrycode::countrycode(
    x[single], "country.name", "iso2c",
    custom_match = c("Chinese Taipei" = "TW", "Kosovo" = "XK")
  ))
  out
}

# Most frequent value, ties broken alphabetically
mode_value <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) return(NA_character_)
  counts <- table(x)
  top <- names(counts)[counts == max(counts)]
  sort(top)[1]
}

#' Normalise ROR IDs
#'
#' Brings ROR IDs into the canonical form `https://ror.org/0xxxxxxNN`
#' (lowercase, full URL) and drops values that are not ROR IDs.
#'
#' @param x Character vector.
#' @return Character vector of the same length; invalid IDs become `NA`.
#' @export
#' @examples
#' normalize_ror(c("ror.org/05gxyna29", "https://ror.org/02E2C7K09", "v"))
normalize_ror <- function(x) {
  id <- sub("^(https?://)?(www\\.)?ror\\.org/", "", tolower(trimws(x)))
  ifelse(!is.na(id) & grepl("^0[a-z0-9]{6}[0-9]{2}$", id), paste0("https://ror.org/", id), NA_character_)
}
