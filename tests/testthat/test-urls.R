test_that("url_encode/url_decode/parse_url emit deprecation warnings", {
  expect_warning(url_encode("https://example.com"), "deprecated")
  expect_warning(url_decode("https://example.com"), "deprecated")
  expect_warning(parse_url("https://example.com"), "deprecated")

  # The warning is the standard base-R .Deprecated() condition and points
  # callers at the replacement surface.
  w <- tryCatch(
    url_encode("https://example.com"),
    warning = function(w) w
  )
  expect_s3_class(w, "deprecatedWarning")
  expect_match(conditionMessage(w), "rurl")
  expect_match(conditionMessage(w), "puny_encode")

  w_dec <- tryCatch(
    url_decode("https://example.com"),
    warning = function(w) w
  )
  expect_match(conditionMessage(w_dec), "puny_decode")
})

test_that("url_encode handles simple URLs", suppress_url_deprecation({
  expect_identical(
    url_encode("https://example.com/path"),
    "https://example.com/path"
  )
  expect_identical(url_encode("http://test.org"), "http://test.org")
}))

test_that("url_encode encodes Unicode host names", suppress_url_deprecation({
  expect_identical(
    url_encode("https://café.example.com/path?query=value"),
    "https://xn--caf-dma.example.com/path?query=value"
  )
  expect_identical(
    url_encode("https://παράδειγμα.ελ"),
    "https://xn--hxajbheg2az3al.xn--qxam"
  )
}))

test_that("url_encode validates input", suppress_url_deprecation({
  expect_rejects_non_character(url_encode)
}))

test_that("url_encode handles NA values", suppress_url_deprecation({
  expect_warning(
    result <- url_encode(c("https://example.com", NA, "http://test.org"))
  )
  expect_identical(result[1], "https://example.com")
  expect_true(is.na(result[2]))
  expect_identical(result[3], "http://test.org")
}))

test_that("url_decode handles simple URLs", suppress_url_deprecation({
  expect_identical(
    url_decode("https://example.com/path"),
    "https://example.com/path"
  )
  expect_identical(url_decode("http://test.org"), "http://test.org")
}))

test_that("url_decode decodes punycode host names", suppress_url_deprecation({
  expect_identical(
    url_decode("https://xn--caf-dma.example.com/path"),
    "https://café.example.com/path"
  )
  expect_identical(
    url_decode("https://xn--hxajbheg2az3al.xn--qxam"),
    "https://παράδειγμα.ελ"
  )
}))

test_that("url_decode validates input", suppress_url_deprecation({
  expect_rejects_non_character(url_decode)
}))

test_that("url_decode handles NA values", suppress_url_deprecation({
  expect_warning(
    result <- url_decode(c("https://example.com", NA, "http://test.org"))
  )
  expect_identical(result[1], "https://example.com")
  expect_true(is.na(result[2]))
  expect_identical(result[3], "http://test.org")
}))

test_that("parse_url returns proper structure", suppress_url_deprecation({
  result <- parse_url("https://example.com/path?query=value#fragment")

  expect_type(result, "list")
  expect_s3_class(result, "punycoder_parsed_url")
  expect_named(
    result,
    c("scheme", "domain", "port", "path", "query", "fragment")
  )
  expect_identical(result$scheme[[1]], "https")
  expect_identical(result$domain[[1]], "example.com")
  expect_identical(result$path[[1]], "/path")
  expect_identical(result$query[[1]], "query=value")
  expect_identical(result$fragment[[1]], "fragment")
}))

test_that(
  "print method for parsed URLs renders optional components",
  suppress_url_deprecation({
    parsed <- parse_url(c(
      "https://example.com/path?query=value#fragment",
      "mailto:user@example.com",
      "https://example.com"
    ))

    output <- capture.output(returned <- print(parsed))
    expect_identical(returned, parsed)
    expect_true(any(grepl(
      "Punycoder Parsed URL Results", output, fixed = TRUE
    )))
    expect_true(any(grepl("URL 1", output, fixed = TRUE)))
    expect_true(any(grepl("Scheme:   https", output, fixed = TRUE)))
    expect_true(any(grepl("Domain:   example.com", output, fixed = TRUE)))
    expect_true(any(grepl("Path:     /path", output, fixed = TRUE)))
    expect_true(any(grepl("Query:    query=value", output, fixed = TRUE)))
    expect_true(any(grepl("Fragment: fragment", output, fixed = TRUE)))
    expect_true(any(grepl("Scheme:   mailto", output, fixed = TRUE)))
    expect_true(any(grepl("Domain:   <NA>", output, fixed = TRUE)))
    expect_true(any(grepl("Path:     user@example.com", output, fixed = TRUE)))
  })
)

test_that("parse_url handles vectorized input", suppress_url_deprecation({
  urls <- c("https://example.com", "http://test.org:8080")
  result <- parse_url(urls)

  expect_type(result, "list")
  expect_s3_class(result, "punycoder_parsed_url")
  expect_identical(result$domain[[2]], "test.org")
  expect_identical(result$port[[2]], 8080L)
}))

test_that("parse_url validates input", suppress_url_deprecation({
  expect_rejects_non_character(parse_url)
}))

test_that("parse_url handles NA values", suppress_url_deprecation({
  expect_warning(result <- parse_url(c("https://example.com", NA)))
  expect_type(result, "list")
}))

test_that("URL functions return character vectors", suppress_url_deprecation({
  result_encode <- url_encode("https://example.com")
  expect_type(result_encode, "character")

  result_decode <- url_decode("https://example.com")
  expect_type(result_decode, "character")
}))

test_that("strict parameter works for URL functions", suppress_url_deprecation({
  expect_no_error(url_encode("https://example.com", strict = TRUE))
  expect_no_error(url_encode("https://example.com", strict = FALSE))
  expect_no_error(url_decode("https://example.com", strict = TRUE))
  expect_no_error(url_decode("https://example.com", strict = FALSE))
  expect_identical(
    url_encode("http://127.0.0.1/path", strict = TRUE),
    "http://127.0.0.1/path"
  )
  expect_identical(
    url_decode("http://127.0.0.1/path", strict = TRUE),
    "http://127.0.0.1/path"
  )

  expect_error(url_encode("https://[::1/path", strict = TRUE))
  expect_true(is.na(url_encode("https://[::1/path", strict = FALSE)))
}))

test_that(
  "url encode/decode handle userinfo, ports, and malformed authorities",
  suppress_url_deprecation({
    encoded <- url_encode(
      "https://user:pass@café.example.com:8443/path?q=1#frag"
    )
    expect_identical(
      encoded,
      "https://user:pass@xn--caf-dma.example.com:8443/path?q=1#frag"
    )
    expect_identical(
      url_decode(encoded),
      "https://user:pass@café.example.com:8443/path?q=1#frag"
    )

    expect_error(
      url_decode("https://xn--.example.com", strict = TRUE),
      "Error decoding URL"
    )
    expect_true(is.na(url_decode("https://xn--.example.com", strict = FALSE)))
  })
)

test_that(
  "parse_url supports domain encoding and invalid inputs",
  suppress_url_deprecation({
    parsed <- parse_url(
      "https://café.example.com:8080/path",
      encode_domains = TRUE
    )
    expect_identical(parsed$domain[[1]], "xn--caf-dma.example.com")
    expect_identical(parsed$port[[1]], 8080L)

    invalid <- parse_url("https://[::1/path")
    expect_true(is.na(invalid$domain[[1]]))
    expect_true(is.na(invalid$scheme[[1]]))
  })
)

test_that("url helpers cover authority edge cases", suppress_url_deprecation({
  expect_identical(
    url_encode("mailto:user@example.com"), "mailto:user@example.com"
  )
  expect_identical(
    url_decode("mailto:user@example.com"), "mailto:user@example.com"
  )
  expect_identical(url_encode("http://@/path"), "http://@/path")
  expect_identical(
    url_encode("//café.example/path"), "//xn--caf-dma.example/path"
  )
  expect_identical(
    url_decode("//xn--caf-dma.example/path"), "//café.example/path"
  )
  expect_identical(url_encode("https://user@/path"), "https://user@/path")
  expect_identical(url_decode("https://user@/path"), "https://user@/path")
  expect_identical(
    url_encode("http://[::1]:8080/path", strict = FALSE),
    "http://[::1]:8080/path"
  )
  expect_identical(
    url_encode("http://[::1]/path", strict = FALSE),
    "http://[::1]/path"
  )
  expect_identical(
    url_encode("http://[::1]/path", strict = TRUE),
    "http://[::1]/path"
  )
  expect_identical(
    url_decode("http://[::1]/path", strict = FALSE),
    "http://[::1]/path"
  )
  expect_identical(
    url_decode("http://[::1]/path", strict = TRUE),
    "http://[::1]/path"
  )
  expect_error(url_decode("", strict = TRUE), "Error decoding URL")
  expect_true(is.na(url_decode("", strict = FALSE)))

  expect_identical(
    url_encode("http://example.com:abc/path", strict = FALSE),
    "http://example.com:abc/path"
  )
  expect_error(
    url_encode("http://[::1]x/path", strict = TRUE),
    "Invalid authority"
  )
  expect_true(is.na(url_encode("http://[::1]x/path", strict = FALSE)))
  expect_error(
    url_encode("http://[2001:db8:::1]/path", strict = TRUE),
    "Invalid IPv6 authority"
  )
  expect_true(is.na(url_encode(
    "http://[2001:db8:::1]/path",
    strict = FALSE
  )))
  expect_true(is.na(url_encode("", strict = FALSE)))
  expect_error(url_encode("", strict = TRUE), "Empty URL")
}))

test_that(
  "parse_url covers invalid inputs and encoding fallbacks",
  suppress_url_deprecation({
    expect_true(is.na(parse_url("")$scheme[[1]]))

    bad_host <- rawToChar(as.raw(c(0xC2, 0x20)))
    Encoding(bad_host) <- "bytes"
    bad_url <- paste0("http://", bad_host, ".com/path")
    parsed <- parse_url(bad_url, encode_domains = TRUE)
    expect_true(is.na(parsed$domain[[1]]))
  })
)

test_that(
  "parse_url leaves IP literals unchanged with encode_domains",
  suppress_url_deprecation({
    ipv4 <- parse_url("http://127.0.0.1:8080/path", encode_domains = TRUE)
    expect_identical(ipv4$domain[[1]], "127.0.0.1")
    expect_identical(ipv4$port[[1]], 8080L)

    ipv6 <- parse_url("http://[2001:db8::1]:8080/path", encode_domains = TRUE)
    expect_identical(ipv6$domain[[1]], "2001:db8::1")
    expect_identical(ipv6$port[[1]], 8080L)
  })
)

test_that(
  "url_encode non-strict catches malformed byte domains",
  suppress_url_deprecation({
    bad_host <- rawToChar(as.raw(c(0xC2, 0x20)))
    Encoding(bad_host) <- "bytes"
    bad_url <- paste0("http://", bad_host, ".com/path")

    expect_error(url_encode(bad_url, strict = TRUE), "Error encoding URL")
    expect_true(is.na(url_encode(bad_url, strict = FALSE)))
  })
)

test_that("parse_url handles port boundary values", suppress_url_deprecation({
  p0 <- parse_url("http://example.com:0/path")
  expect_identical(p0$port[[1]], 0L)

  p65535 <- parse_url("http://example.com:65535/path")
  expect_identical(p65535$port[[1]], 65535L)

  pmax <- parse_url("http://example.com:99999/path")
  expect_identical(pmax$port[[1]], 99999L)
}))

test_that(
  "parse_url handles empty URL components and empty hosts",
  suppress_url_deprecation({
    empty_parts <- parse_url("https://example.com?#")
    expect_identical(empty_parts$scheme[[1]], "https")
    expect_identical(empty_parts$domain[[1]], "example.com")
    expect_identical(empty_parts$path[[1]], "")
    expect_identical(empty_parts$query[[1]], "")
    expect_identical(empty_parts$fragment[[1]], "")

    userinfo_without_host <- parse_url("https://user:pass@/path")
    expect_identical(userinfo_without_host$scheme[[1]], "https")
    expect_true(is.na(userinfo_without_host$domain[[1]]))
    expect_identical(userinfo_without_host$path[[1]], "/path")

    non_numeric_port <- parse_url("http://example.com:abc/path")
    expect_identical(non_numeric_port$domain[[1]], "example.com:abc")
    expect_true(is.na(non_numeric_port$port[[1]]))
  })
)

test_that(
  "IPv6 URLs pass through in non-strict mode",
  suppress_url_deprecation({
    expect_identical(
      url_encode("http://[::1]:8080/path", strict = FALSE),
      "http://[::1]:8080/path"
    )
    expect_identical(
      url_decode("http://[::1]:8080/path", strict = FALSE),
      "http://[::1]:8080/path"
    )
    expect_identical(
      url_encode("http://[2001:db8::1]/path", strict = FALSE),
      "http://[2001:db8::1]/path"
    )
    expect_identical(
      url_encode("http://[2001:db8::1]/path", strict = TRUE),
      "http://[2001:db8::1]/path"
    )
    expect_identical(
      url_decode("http://[2001:db8::1]/path", strict = TRUE),
      "http://[2001:db8::1]/path"
    )
  })
)
