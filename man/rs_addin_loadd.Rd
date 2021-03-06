% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/rstudio.R
\name{rs_addin_loadd}
\alias{rs_addin_loadd}
\title{Loadd target at cursor into global environment
\lifecycle{stable}}
\usage{
rs_addin_loadd(context = NULL)
}
\arguments{
\item{context}{an RStudio document context.
Read from the active document if not supplied.
This is used for testing purposes.}
}
\value{
Nothing.
}
\description{
This function provides an RStudio addin that will
load the target at the
current cursor location from the cache into the global environment.
This is convenient during pipeline development when building off
established targets.
}
\details{
If you are using a non-standard \code{drake} cache,
you must supply it to the \code{"rstudio_drake_cache"} global option,
e.g. \code{options(rstudio_drake_cache = storr::storr_rds("my_cache"))}.
}
\keyword{internal}
