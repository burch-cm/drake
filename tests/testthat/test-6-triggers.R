drake_context("triggers")

test_with_dir("empty triggers return logical", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  config <- drake_config(drake_plan(x = 1))
  expect_identical(trigger_depend("x", list(), config), FALSE)
  expect_identical(trigger_command("x", list(), config), FALSE)
  expect_identical(trigger_file("x", list(), config), FALSE)
  expect_identical(trigger_format("x", NULL, config), FALSE)
  expect_identical(trigger_condition("x", list(), config), FALSE)
  expect_identical(trigger_change("x", list(), config), FALSE)
})

test_with_dir("triggers can be expressions", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  plan <- drake_plan(x = target(1, trigger = 123))
  plan$trigger[[1]] <- expression(trigger(condition = TRUE))
  for (i in 1:3) {
    cache <- storr::storr_environment()
    make(
      plan,
      session_info = FALSE,
      cache = cache
    )
    config <- drake_config(
      plan,
      session_info = FALSE,
      cache = cache
    )
    expect_equal(justbuilt(config), "x")
  }
})

test_with_dir("bad condition trigger", {
  plan <- drake_plan(x = 1)
  cache <- storr::storr_environment()
  make(
    plan, session_info = FALSE, cache = cache,
    trigger = trigger(condition = NULL)
  )
  expect_error(
    make(
      plan, session_info = FALSE, cache = cache,
      trigger = trigger(condition = NULL)
    ),
    regexp = "logical of length 1"
  )
})

test_with_dir("triggers in plan override make(trigger = whatever)", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  saveRDS(1, "file.rds")
  plan <- drake_plan(
    x = readRDS(file_in("file.rds")),
    y = target(
      readRDS(file_in("file.rds")),
      trigger = trigger(file = TRUE)
    )
  )
  make(plan, session_info = FALSE)
  config <- drake_config(plan, session_info = FALSE)
  expect_equal(sort(justbuilt(config)), c("x", "y"))
  saveRDS(2, "file.rds")
  expect_equal(sort(outdated_impl(config)), c("x", "y"))
  make(plan, trigger = trigger(file = FALSE), session_info = FALSE)
  config <- drake_config(
    plan, trigger = trigger(file = FALSE), session_info = FALSE)
  expect_equal(justbuilt(config), "y")
})

test_with_dir("change trigger on a fresh build", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  saveRDS(1, "file.rds")
  plan <- drake_plan(
    x = target(1 + 1, trigger = trigger(
      condition = FALSE,
      command = FALSE,
      depend = FALSE,
      file = FALSE,
      change = readRDS("file.rds"))
    )
  )
  make(plan, session_info = FALSE)
  config <- drake_config(plan, session_info = FALSE)
  expect_equal(justbuilt(config), "x")
  make(plan, session_info = FALSE)
  config <- drake_config(plan, session_info = FALSE)
  expect_equal(justbuilt(config), character(0))
  saveRDS(2, "file.rds")
  make(plan, session_info = FALSE)
  config <- drake_config(plan, session_info = FALSE)
  expect_equal(justbuilt(config), "x")
})

test_with_dir("trigger() function works", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  x <- 1
  y <- trigger(
    command = TRUE,
    depend = FALSE,
    file = FALSE,
    format = FALSE,
    condition = 1 + 1,
    change = sqrt(!!x)
  )
  z <- list(
    command = TRUE,
    depend = FALSE,
    file = FALSE,
    seed = TRUE,
    format = FALSE,
    condition = quote(1 + 1),
    change = quote(sqrt(1)),
    mode = "whitelist"
  )
  class(z) <- c("drake_triggers", "drake")
  expect_equal(y, z)
})

test_with_dir("can detect trigger deps without reacting to them", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  skip_if_not_installed("knitr")
  writeLines("123", "knitr.Rmd")
  saveRDS(0, "file.rds")
  f <- function(x) {
    identity(x)
  }
  plan <- drake_plan(
    x = target(
      command = 1 + 1,
      trigger = trigger(
        condition = {
          knitr_in("knitr.Rmd")
          f(0) + readRDS(file_in("file.rds"))
        },
        command = FALSE,
        file = FALSE,
        depend = TRUE,
        change = NULL
      )
    )
  )
  config <- drake_config(
    plan, session_info = FALSE, cache = storr::storr_environment(),
    log_progress = TRUE)
  deps <- c(reencode_path(c("file.rds", "knitr.Rmd")), "f")
  expect_true(all(deps %in% igraph::V(config$graph)$name))
  expect_equal(sort(deps_graph("x", config$graph)), sort(deps))
  expect_equal(outdated_impl(config), "x")
  make_impl(config = config)
  expect_equal(justbuilt(config), "x")
  expect_equal(outdated_impl(config), character(0))
  make_impl(config = config)
  nobuild(config)
  f <- function(x) {
    identity(x) || FALSE
  }
  expect_equal(outdated_impl(config), character(0))
  make_impl(config = config)
  nobuild(config)
})

test_with_dir("same, but with global trigger", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  skip_if_not_installed("knitr")
  writeLines("123", "knitr.Rmd")
  saveRDS(0, "file.rds")
  f <- function(x) {
    identity(x)
  }
  plan <- drake_plan(x = 1 + 1)
  config <- drake_config(
    plan, session_info = FALSE, cache = storr::storr_environment(),
    log_progress = TRUE, trigger = trigger(
      condition = {
        knitr_in("knitr.Rmd")
        f(0) + readRDS(file_in("file.rds"))
      },
      command = FALSE,
      file = FALSE,
      depend = TRUE,
      change = NULL
    )
  )
  deps <- c(reencode_path(c("file.rds", "knitr.Rmd")), "f")
  expect_true(all(deps %in% igraph::V(config$graph)$name))
  expect_equal(sort(deps_graph("x", config$graph)), sort(deps))
  expect_equal(outdated_impl(config), "x")
  make_impl(config = config)
  expect_equal(justbuilt(config), "x")
  expect_equal(outdated_impl(config), character(0))
  make_impl(config = config)
  nobuild(config)
  f <- function(x) {
    identity(x) || FALSE
  }
  expect_equal(outdated_impl(config), character(0))
  make_impl(config = config)
  nobuild(config)
})

test_with_dir("trigger does not block out command deps", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  skip_if_not_installed("knitr")
  writeLines("123", "knitr.Rmd")
  saveRDS(0, "file.rds")
  f <- function(x) {
    identity(x)
  }
  plan <- drake_plan(
    x = target(
      command = {
        knitr_in("knitr.Rmd")
        f(0) + readRDS(file_in("file.rds"))
      },
      trigger = trigger(
        condition = {
          knitr_in("knitr.Rmd")
          f(FALSE) + readRDS(file_in("file.rds"))
        },
        command = FALSE,
        file = TRUE,
        depend = TRUE,
        change = NULL
      )
    )
  )
  config <- drake_config(
    plan, session_info = FALSE, cache = storr::storr_environment(),
    log_progress = TRUE)
  deps <- c(reencode_path("file.rds"), reencode_path("knitr.Rmd"), "f")
  expect_true(all(deps %in% igraph::V(config$graph)$name))
  expect_equal(sort(deps_graph("x", config$graph)), sort(deps))
  expect_equal(outdated_impl(config), "x")
  make(
    plan, session_info = FALSE,
    cache = config$cache,
    log_progress = TRUE,
    memory_strategy = "preclean"
  )
  expect_equal(justbuilt(config), "x")
  expect_equal(outdated_impl(config), character(0))
  make_impl(config = config)
  nobuild(config)
  f <- function(x) {
    identity(x) || FALSE
  }
  expect_equal(outdated_impl(config), "x")
  make_impl(config = config)
  expect_equal(justbuilt(config), "x")
  writeLines("456", "knitr.Rmd")
  expect_equal(outdated_impl(config), "x")
  make_impl(config = config)
  expect_equal(justbuilt(config), "x")
  saveRDS(2, "file.rds")
  expect_equal(outdated_impl(config), "x")
  make_impl(config = config)
  expect_equal(justbuilt(config), "x")
})

test_with_dir("same, but with global change trigger", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  skip_if_not_installed("knitr")
  writeLines("123", "knitr.Rmd")
  saveRDS(0, "file.rds")
  f <- function(x) {
    identity(x)
  }
  plan <- drake_plan(
    x = {
      knitr_in("knitr.Rmd")
      f(0) + readRDS(file_in("file.rds"))
    }
  )
  config <- drake_config(
    plan, session_info = FALSE, cache = storr::storr_environment(),
    log_progress = TRUE, trigger = trigger(
      change = {
        knitr_in("knitr.Rmd")
        f(FALSE) + readRDS(file_in("file.rds"))
      },
      command = FALSE,
      file = TRUE,
      depend = TRUE,
      condition = FALSE
    )
  )
  deps <- c(file_store("file.rds"), file_store("knitr.Rmd"), "f")
  expect_true(all(deps %in% igraph::V(config$graph)$name))
  expect_equal(sort(deps_graph("x", config$graph)), sort(deps))
  expect_equal(outdated_impl(config), "x")
  make(
    plan,
    session_info = FALSE,
    cache = config$cache,
    log_progress = TRUE, trigger = trigger(
      change = {
        knitr_in("knitr.Rmd")
        f(FALSE) + readRDS(file_in("file.rds"))
      },
      command = FALSE,
      file = TRUE,
      depend = TRUE,
      condition = FALSE
    ),
    memory_strategy = "preclean"
  )
  expect_equal(justbuilt(config), "x")
  expect_equal(outdated_impl(config), character(0))
  make(
    plan,
    session_info = FALSE,
    cache = config$cache,
    log_progress = TRUE, trigger = trigger(
      change = {
        knitr_in("knitr.Rmd")
        f(FALSE) + readRDS(file_in("file.rds"))
      },
      command = FALSE,
      file = TRUE,
      depend = TRUE,
      condition = FALSE
    ),
    memory_strategy = "preclean"
  )
  nobuild(config)
  f <- function(x) {
    identity(x) || FALSE
  }
  expect_equal(outdated_impl(config), "x")
  make_impl(config = config)
  expect_equal(justbuilt(config), "x")
  writeLines("456", "knitr.Rmd")
  expect_equal(outdated_impl(config), "x")
  make_impl(config = config)
  expect_equal(justbuilt(config), "x")
  saveRDS(2, "file.rds")
  expect_equal(outdated_impl(config), "x")
  make_impl(config = config)
  expect_equal(justbuilt(config), "x")
})

test_with_dir("triggers can be NA in the plan", {
  skip_on_cran()
  cache <- storr::storr_environment()
  expect_silent(
    make(
      drake_plan(x = target(1, trigger = NA)),
      session_info = FALSE,
      cache = cache,
      verbose = 0L
    )
  )
  config <- drake_config(
    drake_plan(x = target(1, trigger = NA)),
    session_info = FALSE,
    cache = cache,
    verbose = 0L
  )
  expect_equal(justbuilt(config), "x")
})

test_with_dir("deps load into memory for complex triggers", {
  skip_on_cran()
  scenario <- get_testing_scenario()
  e <- eval(parse(text = scenario$envir))
  jobs <- scenario$jobs
  parallelism <- scenario$parallelism
  caching <- scenario$caching
  plan <- drake_plan(
    psi_1 = (sqrt(5) + 1) / 2,
    psi_2 = target(
      command = (sqrt(5) - 1) / 2,
      trigger = trigger(condition = psi_1 > 0)
    ),
    psi_3 = target(
      command = 1,
      trigger = trigger(change = psi_2)
    )
  )
  for (i in 1:3) {
    make(
      plan, envir = e, jobs = jobs, parallelism = parallelism,
      verbose = 0L, caching = caching, session_info = FALSE
    )
    expect_true(all(plan$target %in% cached()))
  }
  config <- drake_config(plan)
  expect_equal(config$spec[["psi_2"]]$deps_condition$memory, "psi_1")
  expect_equal(config$spec[["psi_3"]]$deps_change$memory, "psi_2")
})

test_with_dir("trigger components react appropriately", {
  skip_on_cran()
  skip_if_not_installed("knitr")
  scenario <- get_testing_scenario()
  e <- eval(parse(text = scenario$envir))
  jobs <- scenario$jobs
  parallelism <- scenario$parallelism
  caching <- scenario$caching
  eval(
    quote(f <- function(x) {
      1 + x
    }),
    envir = e
  )
  writeLines("1234", "report.Rmd")
  saveRDS(1, "file.rds")
  saveRDS(1, "change.rds")
  saveRDS(TRUE, "condition.rds")
  plan <- drake_plan(
    missing = target(
      NULL,
      trigger = trigger(command = FALSE, depend = FALSE, file = FALSE)
    ),
    condition = target(
      NULL,
      trigger = trigger(
        condition = readRDS("condition.rds"),
        command = FALSE, depend = FALSE, file = FALSE
      )
    ),
    command = target(
      NULL,
      trigger = trigger(command = TRUE, depend = FALSE, file = FALSE)
    ),
    depend = target(
      NULL,
      trigger = trigger(command = FALSE, depend = TRUE, file = FALSE)
    ),
    file = target(
      NULL,
      trigger = trigger(command = FALSE, depend = FALSE, file = TRUE)
    ),
    change = target(
      NULL,
      trigger = trigger(
        change = readRDS("change.rds"),
        command = FALSE, depend = FALSE, file = FALSE
      )
    )
  )
  commands <- paste0("{
    knitr_in(\"report.Rmd\")
    out <- f(readRDS(file_in(\"file.rds\")))
    saveRDS(out, file_out(\"out_", plan$target, ".rds\"))
    out
  }")
  commands <- lapply(commands, safe_parse)
  plan$command <- commands
  make(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE
  )
  config <- drake_config(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    log_progress = TRUE
  )
  expect_equal(sort(justbuilt(config)), sort(plan$target))
  expect_equal(outdated_impl(config), "condition")
  simple_plan <- plan
  simple_plan$trigger <- NULL
  make(
    simple_plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 0L, caching = caching, session_info = FALSE
  )
  simple_config <- drake_config(
    simple_plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 0L, caching = caching, session_info = FALSE,
    log_progress = TRUE
  )

  # Condition trigger
  for (i in 1:2) {
    expect_equal(sort(outdated_impl(config)), "condition")
    make_impl(config = config)
    expect_equal(sort(justbuilt(config)), "condition")
  }
  saveRDS(FALSE, "condition.rds")
  expect_equal(outdated_impl(simple_config), character(0))
  expect_equal(outdated_impl(config), character(0))
  for (i in 1:2) {
    make_impl(config = config)
    nobuild(config)
  }

  # Change trigger
  saveRDS(2, "change.rds")
  expect_equal(sort(outdated_impl(config)), "change")
  expect_equal(outdated_impl(simple_config), character(0))
  make_impl(config = config)
  expect_equal(sort(justbuilt(config)), "change")
  expect_equal(outdated_impl(config), character(0))
  expect_equal(outdated_impl(simple_config), character(0))

  # File trigger: input files
  saveRDS(2, "file.rds")
  expect_equal(sort(outdated_impl(config)), "file")
  make_impl(config = config)
  expect_equal(sort(justbuilt(config)), "file")
  expect_equal(
    sort(outdated_impl(simple_config)),
    sort(setdiff(plan$target, "file"))
  )
  expect_equal(outdated_impl(config), character(0))

  # File trigger: knitr files
  writeLines("5678", "report.Rmd")
  expect_equal(sort(outdated_impl(config)), "file")
  make_impl(config = config)
  expect_equal(sort(justbuilt(config)), "file")
  expect_equal(
    sort(outdated_impl(simple_config)),
    sort(setdiff(plan$target, "file"))
  )
  expect_equal(outdated_impl(config), character(0))

  # File trigger: output files
  for (target in plan$target) {
    saveRDS("1234", paste0("out_", target, ".rds"))
  }
  expect_equal(sort(outdated_impl(config)), "file")
  make_impl(config = config)
  expect_equal(sort(justbuilt(config)), "file")
  expect_equal(
    sort(outdated_impl(simple_config)),
    sort(setdiff(plan$target, "file"))
  )
  expect_equal(outdated_impl(config), character(0))

  # Done with the change trigger
  plan <- plan[1:5, ]
  config <- drake_config(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 0L, caching = caching, log_progress = TRUE,
    session_info = FALSE
  )
  simple_plan <- simple_plan[1:5, ]
  simple_config <- drake_config(
    simple_plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 0L, caching = caching, log_progress = TRUE,
    session_info = FALSE
  )
  make_impl(config = simple_config)

  # Command trigger
  new_commands <- paste0("{
    knitr_in(\"report.Rmd\")
    out <- f(1 + readRDS(file_in(\"file.rds\")))
    saveRDS(out, file_out(\"out_", plan$target, ".rds\"))
    out
  }")
  new_commands <- lapply(new_commands, safe_parse)
  plan$command <- simple_plan$command <- new_commands
  config <- drake_config(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 0L, caching = caching, log_progress = TRUE,
    session_info = FALSE
  )
  simple_config <- drake_config(
    simple_plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 0L, caching = caching, log_progress = TRUE,
    session_info = FALSE
  )
  expect_equal(sort(outdated_impl(config)), "command")
  make_impl(config = config)
  expect_equal(sort(justbuilt(config)), "command")
  expect_equal(
    sort(outdated_impl(simple_config)),
    sort(setdiff(plan$target, "command"))
  )
  expect_equal(outdated_impl(config), character(0))
  make_impl(config = simple_config)
  expect_equal(outdated_impl(config), character(0))

  # Depend trigger
  eval(
    quote(f <- function(x) {
      2 + x
    }),
    envir = e
  )
  expect_equal(sort(outdated_impl(config)), "depend")
  make_impl(config = config)
  expect_equal(sort(justbuilt(config)), "depend")
  expect_equal(
    sort(outdated_impl(simple_config)),
    sort(setdiff(plan$target, "depend"))
  )
  expect_equal(outdated_impl(config), character(0))
  make_impl(config = simple_config)
  expect_equal(outdated_impl(config), character(0))
})

test_with_dir("trigger whitelist mode", {
  skip_on_cran()
  scenario <- get_testing_scenario()
  e <- eval(parse(text = scenario$envir))
  jobs <- scenario$jobs
  parallelism <- scenario$parallelism
  caching <- scenario$caching
  eval(
    quote(f <- function(x) {
      1 + x
    }),
    envir = e
  )
  plan <- drake_plan(y = f(1))
  make(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE
  )
  config <- drake_config(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE
  )
  expect_equal(justbuilt(config), "y")
  expect_equal(outdated_impl(config), character(0))
  make(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = FALSE, mode = "whitelist")
  )
  config <- drake_config(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = FALSE, mode = "whitelist")
  )
  expect_equal(justbuilt(config), character(0))
  make(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = TRUE, mode = "whitelist")
  )
  config <- drake_config(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = TRUE, mode = "whitelist")
  )
  expect_equal(justbuilt(config), "y")
  eval(
    quote(f <- function(x) {
      2 + x
    }),
    envir = e
  )
  make(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = FALSE, mode = "whitelist")
  )
  config <- drake_config(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = FALSE, mode = "whitelist")
  )
  expect_equal(justbuilt(config), "y")
  eval(
    quote(f <- function(x) {
      3 + x
    }),
    envir = e
  )
  make(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = TRUE, mode = "whitelist")
  )
  config <- drake_config(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = TRUE, mode = "whitelist")
  )
  expect_equal(justbuilt(config), "y")
})

test_with_dir("trigger blacklist mode", {
  skip_on_cran()
  scenario <- get_testing_scenario()
  e <- eval(parse(text = scenario$envir))
  jobs <- scenario$jobs
  parallelism <- scenario$parallelism
  caching <- scenario$caching
  eval(
    quote(f <- function(x) {
      1 + x
    }),
    envir = e
  )
  plan <- drake_plan(y = f(1))
  make(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE
  )
  config <- drake_config(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE
  )
  expect_equal(justbuilt(config), "y")
  expect_equal(outdated_impl(config), character(0))
  make(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = FALSE, mode = "blacklist")
  )
  config <- drake_config(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = FALSE, mode = "blacklist")
  )
  expect_equal(justbuilt(config), character(0))
  make(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = TRUE, mode = "blacklist")
  )
  config <- drake_config(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = TRUE, mode = "blacklist")
  )
  expect_equal(justbuilt(config), character(0))
  eval(
    quote(f <- function(x) {
      2 + x
    }),
    envir = e
  )
  make(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = FALSE, mode = "blacklist")
  )
  config <- drake_config(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = FALSE, mode = "blacklist")
  )
  expect_equal(justbuilt(config), character(0))
  eval(
    quote(f <- function(x) {
      3 + x
    }),
    envir = e
  )
  make(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = TRUE, mode = "blacklist")
  )
  config <- drake_config(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = TRUE, mode = "blacklist")
  )
  expect_equal(justbuilt(config), "y")
})

test_with_dir("trigger condition mode", {
  skip_on_cran()
  scenario <- get_testing_scenario()
  e <- eval(parse(text = scenario$envir))
  jobs <- scenario$jobs
  parallelism <- scenario$parallelism
  caching <- scenario$caching
  eval(
    quote(f <- function(x) {
      1 + x
    }),
    envir = e
  )
  plan <- drake_plan(y = f(1))
  make(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE
  )
  config <- drake_config(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE
  )
  expect_equal(justbuilt(config), "y")
  expect_equal(outdated_impl(config), character(0))
  make(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = FALSE, mode = "condition")
  )
  config <- drake_config(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = FALSE, mode = "condition")
  )
  expect_equal(justbuilt(config), character(0))
  make(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = TRUE, mode = "condition")
  )
  config <- drake_config(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = TRUE, mode = "condition")
  )
  expect_equal(justbuilt(config), "y")
  eval(
    quote(f <- function(x) {
      2 + x
    }),
    envir = e
  )
  make(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = FALSE, mode = "condition")
  )
  config <- drake_config(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = FALSE, mode = "condition")
  )
  expect_equal(justbuilt(config), character(0))
  eval(
    quote(f <- function(x) {
      3 + x
    }),
    envir = e
  )
  make(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = TRUE, mode = "condition")
  )
  config <- drake_config(
    plan, envir = e, jobs = jobs, parallelism = parallelism,
    verbose = 1L, caching = caching, session_info = FALSE,
    trigger = trigger(condition = TRUE, mode = "condition")
  )
  expect_equal(justbuilt(config), "y")
})

test_with_dir("files are collected/encoded from all triggers", {
  skip_on_cran()
  skip_if_not_installed("knitr")
  exp <- sort(c(
    paste0(
      rep(c("command_", "condition_", "change_"), times = 3),
      rep(c("in", "out", "knitr_in"), each = 3)
    )
  ))
  exp <- setdiff(exp, c("condition_out", "change_out"))
  file.create(exp)
  plan <- drake_plan(
    x = target(
      command = {
        file_in("command_in")
        file_out("command_out")
        knitr_in("command_knitr_in")
      },
      trigger = trigger(
        condition = {
          file_in("condition_in")
          file_out("condition_out")
          knitr_in("condition_knitr_in")
        },
        change = {
          file_in("change_in")
          file_out("change_out")
          knitr_in("change_knitr_in")
        }
      )
    )
  )
  config <- drake_config(plan)
  deps_build <- redecode_path(unlist(config$spec[["x"]]$deps_build))
  deps_condition <- redecode_path(
    unlist(config$spec[["x"]]$deps_condition))
  deps_change <- redecode_path(unlist(config$spec[["x"]]$deps_change))
  expect_equal(
    sort(deps_build),
    sort(c("command_in", "command_out", "command_knitr_in"))
  )
  expect_equal(
    sort(deps_condition),
    sort(c("condition_in", "condition_knitr_in"))
  )
  expect_equal(
    sort(deps_change),
    sort(c("change_in", "change_knitr_in"))
  )
})

test_with_dir("GitHub issue #704", {
  add <- function(a, b) {
    a + b
  }
  square <- function(x) {
    x ^ 2
  }
  rand_is_even <- function(samp_size) {
    num <- sample(samp_size, 1)
    if (num %% 2 == 0) {
      TRUE
    } else {
      FALSE
    }
  }
  check_plan <- function(plan) {
    cache <- storr::storr_environment()
    make(plan, cache = cache, session_info = FALSE)
    expect_true(is.numeric(cache$get("first")))
    expect_true(is.numeric(cache$get("second")))
  }
  plan <- drake_plan(
    first = add(2, 3),
    second = target(
      command = square(first),
      trigger = trigger(
        condition = rand_is_even(first)
      )
    )
  )
  check_plan(plan)
  plan <- drake_plan(
    first = add(2, 3),
    second = target(
      command = square(first),
      trigger = trigger(
        change = rand_is_even(first)
      )
    )
  )
  check_plan(plan)
})
